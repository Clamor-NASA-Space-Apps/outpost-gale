extends Node
## The cinematics (design/plans/next-lanes.md section 3, design/plans/event-ready.md row C): the sleep time-lapse, the
## rover-trip skip and the launch, one method each. They move the look clock, the camera and what you see, and count
## nothing (hard rule 1): the rules listen to `slept` and `arrived` and do their own counting. Knobs: data/cine.json.
## Text is ids only (story words come on 14 Nov). Lane P owns `cine/beats*`; this file is lane C's.

signal slept(kind: StringName, hours: float)  # the lapse is over: the sim counts the hours (lane S)
signal show_card(ledger: Dictionary)  # at the wake, for the ledger card (lane H)
signal arrived(landmark: String)
signal launched

const HouseStyle := preload("res://addons/forge/house_style.gd")
const Hud := preload("res://ui/hud.gd")

var game: Node3D
var world: Node3D
var player: Node3D
var clock: Node
var audio: Node
var cfg: Dictionary
var cam := Camera3D.new()
var picker: Control
var shot := ""  # the beat on screen ("" when none): sleep_drone, wake, trip_drive, trip_title, launch_*
var t := 0.0  # seconds into the current beat
var _black := ColorRect.new()
var _title: Label
var _prev: Camera3D  # the camera in use before a shot, given back after it
var _holding := false
var _was_driven := false
var _frozen := {}  # node -> its process_mode before a shot froze it


func setup(g: Node3D) -> void:
	game = g
	world = g.world
	player = g.player
	clock = g.clock
	audio = g.audio
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/cine.json"))
	cam.name = "CineCam"
	cam.fov = float(cfg.fov)
	cam.far = 8000.0
	add_child(cam)
	var layer := CanvasLayer.new()
	layer.layer = 100  # under the cover (128), over the HUD
	add_child(layer)
	picker = load("res://ui/components/sleep_picker.tscn").instantiate()
	layer.add_child(picker)
	picker.hide()
	picker.chosen.connect(sleep)
	picker.cancelled.connect(_give_clock)
	_black.color = Color(0, 0, 0, 0)  # no picture, not a palette colour
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.hide()
	layer.add_child(_black)
	_title = Hud.label("", "Heading")
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.hide()
	layer.add_child(_title)
	g.interactions.used.connect(_used)


## True while the picker is open or a shot plays: the root ignores E and the clock waits.
func busy() -> bool:
	return picker.visible or shot != ""


func state() -> Dictionary:
	return {"cine": {"shot": shot, "t": snappedf(t, 0.01), "picker": picker.visible}}


## A bed spot (data/world.json `uses`, kind `bed`, no clip: it reports at once) used: the picker, with the clock held
## while it is open.
func _used(what: String, _pos: Vector3) -> void:
	if what == "bed" and not busy():
		_take_clock()
		picker.open()


## The sleep time-lapse: a night to the fixed wake hour, or a nap of `nap_h`. Lights out, a drone shot of the base
## while the look clock runs on, then the wake in HAB 1: the hero on the bench by the hatch, the lights up.
func sleep(kind: StringName) -> void:
	if shot != "":
		return
	var c: Dictionary = cfg.sleep
	_take_clock()
	var from: float = clock.hours
	var span: float = float(c.nap_h) if kind == &"nap" else fposmod(float(c.wake_h) - clock.hour(), 24.0)
	if span < 0.01:
		span = 24.0  # already the wake hour: the next one
	var lapse := clampf(float(c.lapse_per_h) * span, float(c.lapse_s[0]), float(c.lapse_s[1]))
	_begin("sleep_drone")
	var hab: Node3D = world.items.hab1
	audio.play("curtain", player.body.global_position)
	audio.duck(true)
	audio.music("sleep", true)
	await _fade(1.0, float(cfg.fade_out_s))
	_room_light(float(c.room_light))
	_freeze([player, game.pip])  # a robot creeping at real speed in a time-lapse reads wrong (skills/day-cycle 3)
	var sun := _sun()
	var reach := sun.directional_shadow_max_distance if sun else 0.0
	if sun:
		sun.directional_shadow_max_distance = maxf(reach, float(c.shadow_range))
	# ponytail: the probes hold still for the lapse (no redraw happens without a last blend to compare with), and are
	# redrawn once under the black; swap for the contract's `clock.hold_probes` when the merge adds it
	clock._probe_w.clear()
	drone(0.0)
	cam.make_current()
	_fade(0.0, float(cfg.fade_in_s))
	await _run(lapse, func(k: float) -> void:
		var e := smoothstep(0.0, 1.0, k)
		clock.set_hour(from + span * e)
		drone(e))
	await _fade(1.0, float(cfg.fade_out_s))
	audio.stop_music()
	if sun:
		sun.directional_shadow_max_distance = reach
	_thaw()
	_give_clock()
	clock.refresh()
	slept.emit(kind, span)
	_seat()
	var sitting := get_tree().create_timer(float(player.model.clips.sit_down.length) + 0.2)
	# under the black, from inside the outdoor probe: the sky changed by hours, and a stale reflection would pop
	await HouseStyle._redraw_probes(game, Transform3D(Basis(), world.get_node("Probe").global_position))
	if sitting.time_left > 0.0:
		await sitting.timeout
	shot = "wake"
	var w: Array = c.wake_cam
	cam.look_at_from_position(hab.to_global(_v(w[0])), hab.to_global(_v(w[1])))
	cam.make_current()
	audio.duck(false)
	audio.play("curtain", player.body.global_position)  # the curtain opens and the crew's lights come up (row 189)
	_room_light(1.0)
	show_card.emit({"kind": kind, "hours": span})
	await _fade(0.0, float(cfg.fade_in_s))
	await _wait(float(c.wake_hold_s))
	player.sit(false)
	await _wait(float(player.model.clips.sit_to_stand.length))
	var to: Vector3 = hab.to_global(Vector3(c.hatch[0], 0.0, c.hatch[1])) - player.body.global_position
	player.place(player.body.global_position, -rad_to_deg(atan2(-to.x, -to.z)))
	player.cam.pitch = 0.0
	if kind == &"night":
		audio.wake()  # the next door opened plays the dawn cue
	_end()


## The drone shot at `k` (0 its start, 1 its end), on the cine camera: the captures pose it the same way.
func drone(k: float) -> void:
	var d: Dictionary = cfg.sleep.drone
	cam.look_at_from_position(_ground(d.from).lerp(_ground(d.to), k), _ground(d.at).lerp(_ground(d.at_to), k))


## The hero on the donning bench, sitting down: the hips onto the seat, facing into the room.
func _seat() -> void:
	var b: Array = cfg.sleep.bench
	var hab: Node3D = world.items.hab1
	var seat := hab.to_global(Vector3(b[0], b[1], b[2]))
	var face: Vector3 = hab.global_basis * Vector3(b[3], 0.0, b[4])
	var r := atan2(-face.x, -face.z)
	var hip: Vector3 = player.model.point(&"sit_idle", "seat_hip")
	var feet := seat - Basis(Vector3.UP, r) * Vector3(hip.x, 0.0, hip.z)
	feet.y = hab.to_global(Vector3(0.0, float(cfg.sleep.deck_y), 0.0)).y
	player.place(feet, -rad_to_deg(r))
	player.sit(true)


## HAB 1's own light at share `k`: the lamp pool fades it there (half a second), else it is set at once.
func _room_light(k: float) -> void:
	for l: OmniLight3D in world.items.hab1.find_children("RoomLight", "OmniLight3D", true, false):
		if not l.has_meta("full"):
			l.set_meta("full", l.get_meta("energy", l.light_energy))
		l.set_meta("energy", float(l.get_meta("full")) * k)
		if game.get_node_or_null("LampPool") == null:
			l.light_energy = float(l.get_meta("full")) * k


## From the rover: it drives away from a camera left standing, the screen goes black on a title card (an id; `args`
## fill its {sol} and {km}), and the rover stands at `landmark` (data/world.json landmarks) with the hero at the wheel.
func trip_to(landmark: String, args := {}) -> void:
	if shot != "" or not world.data.landmarks.has(landmark):
		push_warning("cine: no trip to '%s'" % landmark)
		return
	var rover: Node3D = player.vehicle if player.vehicle else world.items.get("rover")
	if rover == null:
		return
	if player.vehicle != rover:
		player.enter(rover)
	var c: Dictionary = cfg.trip
	_begin("trip_drive")
	var from: Vector3 = rover.global_transform * Vector3(c.cam[1], 0.0, c.cam[0])
	from.y = world.height_at(from.x, from.z) + float(c.cam[2])
	var watch := func(_k: float) -> void: cam.look_at_from_position(from, rover.global_position + Vector3.UP)
	watch.call(0.0)
	cam.make_current()
	Input.action_press(&"move_forward")  # the hero drives off: the real throttle, the real rover
	await _run(float(c.drive_s), watch)
	_fade(1.0, float(cfg.fade_out_s))
	await _run(float(cfg.fade_out_s), watch)
	Input.action_release(&"move_forward")
	shot = "trip_title"
	_title.text = tr(c.title_id).format(args)
	_title.show()
	await _wait(float(c.title_s))
	_title.hide()
	var l: Dictionary = world.landmark(landmark)
	rover.v = 0.0
	rover.yaw = -deg_to_rad(l.yaw)
	rover._plane = Vector3.INF  # ponytail: a jump, not a bump: the drawn body's spring must not feel it
	rover._apply(rover._pose(Vector3(l.pos.x, 0.0, l.pos.z), rover.yaw))
	await get_tree().physics_frame  # the hero rides to the new seat
	player.cam.snap(rover.yaw)
	_give_camera()
	await _fade(0.0, float(cfg.fade_in_s))
	_end()
	arrived.emit(landmark)


## The hero boards the ascent rocket (item `mav`; a stand-in on the lander's landmark when there is none), liftoff from
## outside with dust, then the window: the base and Gale fall away and the view turns to Earth. After it the sandbox
## carries on: the rocket back on its pad, the hero where they boarded.
func launch() -> void:
	if shot != "":
		return
	var c: Dictionary = cfg.launch
	var item: Node3D = world.items.get("mav")
	# what flies: the item's `ascent` part when the model has one (a world.json `moving` part, drawn where its node
	# is), else a copy of the whole model with the item's merged cell hidden meanwhile, else a stand-in tube
	var rocket: Node3D = item.find_child("ascent", true, false) as Node3D if item else null
	var made := rocket == null
	var hidden: Node3D = null
	if item and made:
		rocket = load(world.data.prefabs[item.get_meta("prefab")]).instantiate()
		HouseStyle.apply(rocket, game.design, false)
		world.add_child(rocket)
		rocket.global_transform = item.global_transform
		# ponytail: the still item is drawn by its 128 m cell's merged mesh; anything else in that cell blinks out
		# for the shot. Lane W's `ascent` part ends it
		hidden = world.get_node_or_null("cell_%d_%d" % [floori(item.position.x / world.CELL + 0.5), floori(item.position.z / world.CELL + 0.5)])
		if hidden:
			hidden.visible = false
	elif made:
		var m := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = float(c.stand_in[0]) * 0.4
		tube.bottom_radius = float(c.stand_in[0])
		tube.height = float(c.stand_in[1])
		m.mesh = tube
		world.add_child(m)
		m.global_position = world.landmark("lander").pos + Vector3.UP * tube.height / 2.0
		rocket = m
	rocket.name = "mav_flight" if made else rocket.name
	var start := rocket.global_position
	var pad := Vector3(start.x, world.height_at(start.x, start.z), start.z)
	_begin("launch_board")
	await _fade(1.0, float(cfg.fade_out_s))
	_freeze([player])
	player.visible = false  # aboard
	var b := deg_to_rad(float(c.out_bearing))
	var eye := pad + Vector3(sin(b), 0.0, -cos(b)) * float(c.out_m)
	eye.y = world.height_at(eye.x, eye.z) + 1.7
	shot = "launch_out"
	cam.look_at_from_position(eye, start + Vector3.UP * float(c.look_h))
	cam.make_current()
	_fade(0.0, float(cfg.fade_in_s))
	var up := Vector3.UP
	var climb := float(c.climb_s)
	var height := func(s: float) -> Vector3: return start + up * 0.5 * float(c.accel) * s * s
	await _run(float(c.ignite_s), func(k: float) -> void: _plume(pad, k))
	await _run(climb, func(k: float) -> void:
		rocket.global_position = height.call(k * climb)
		_plume(pad, 1.0 - k)
		cam.look_at(rocket.global_position + up * float(c.look_h), up))
	_plume(pad, 0.0)
	await _fade(1.0, float(cfg.fade_out_s))
	shot = "launch_window"
	_title.text = tr(c.caption_id)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)  # under Earth, not over it
	_title.offset_top = -140
	_title.show()
	var earth := earth_dir()
	# the window on the base's side of the cabin, looking back at the base as it shrinks
	var base: Vector3 = world.items.hab1.global_position
	var toward := Vector3(base.x - pad.x, 0.0, base.z - pad.z).normalized()
	var side := toward * float(c.window[0]) + Vector3.UP * float(c.window[1])
	var window := func(k: float) -> void:
		rocket.global_position = height.call(climb + k * float(c.window_s))
		var at := rocket.global_position + side
		var look := base
		if earth != Vector3.ZERO:
			look = base.lerp(at + earth * 1000.0, smoothstep(float(c.turn_at), 1.0, k))
		cam.look_at_from_position(at, look)
	window.call(0.0)
	_fade(0.0, float(cfg.fade_in_s))
	await _run(float(c.window_s), window)
	await _fade(1.0, float(cfg.fade_out_s))
	_title.hide()
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shot = "launch_back"
	launched.emit()
	if made:
		rocket.queue_free()
	else:
		rocket.global_position = start
	if hidden:
		hidden.visible = true
	player.visible = true
	_thaw()
	_give_camera()
	await _fade(0.0, float(cfg.fade_in_s))
	_end()


## Toward Earth in the scene's axes at the clock's hour, from the night sky's own planet (DESIGN.night.md celestial,
## the same sky sky.gdshader draws), by HouseStyle.sun_at()'s sky turn; zero while it is under the horizon.
func earth_dir() -> Vector3:
	var C: Dictionary = game.design.lighting.celestial
	var e: Array = C.get("planets", []).filter(func(p: Dictionary) -> bool: return p.name == "Earth")
	if e.is_empty():
		return Vector3.ZERO
	var f: Dictionary = HouseStyle._sky_frame(C)
	var lat: float = f.lat
	var th: float = atan2(f.sun_eq.y, f.sun_eq.x) + deg_to_rad((clock.hour() - 12.0) * 15.0)
	var zen := Vector3(cos(lat) * cos(th), cos(lat) * sin(th), sin(lat))
	var north := Vector3(-sin(lat) * cos(th), -sin(lat) * sin(th), cos(lat))
	var east := Vector3(-sin(th), cos(th), 0.0)
	var p: Vector3 = (f.frame as Basis).transposed() * f.dir.call([e[0].ra, e[0].dec])
	var d := Vector3(p.dot(east), p.dot(zen), -p.dot(north))
	return d if d.y > 0.05 else Vector3.ZERO


## The engine's dust: streams round the pad, thrown outward, `k` their strength (0 stops them).
func _plume(pad: Vector3, k: float) -> void:
	var c: Dictionary = cfg.launch
	for i in int(c.plume_n):
		var out := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / float(c.plume_n))
		world.stream("mav%d" % i, pad + out * float(c.plume_r), out * float(c.plume_v) * k, k)


func _begin(name: String) -> void:
	_prev = get_viewport().get_camera_3d()
	shot = name
	t = 0.0


func _give_camera() -> void:
	var to: Camera3D = _prev if is_instance_valid(_prev) and _prev != cam else player.cam.lens
	to.make_current()


func _end() -> void:
	_give_camera()
	shot = ""
	t = 0.0


## The cine takes the hour from whoever drives it (the clock itself, or the rules on 14 Nov) and gives it back.
func _take_clock() -> void:
	if not _holding:
		_was_driven = clock.driven
		_holding = true
	clock.driven = true


func _give_clock() -> void:
	if _holding:
		clock.driven = _was_driven
		_holding = false


func _freeze(nodes: Array) -> void:
	for n: Node in nodes:
		if n and not _frozen.has(n):
			_frozen[n] = n.process_mode
			n.process_mode = Node.PROCESS_MODE_DISABLED


func _thaw() -> void:
	for n: Node in _frozen:
		if is_instance_valid(n):
			n.process_mode = _frozen[n]
	_frozen.clear()


func _sun() -> DirectionalLight3D:
	for n: Node in game.get_children():
		if n is DirectionalLight3D and n.has_meta("house_rig"):
			return n
	return null


func _fade(a: float, s: float) -> void:
	_black.show()
	var tw := create_tween()
	tw.tween_property(_black, "color:a", a, s)
	await tw.finished
	_black.visible = a > 0.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## `step(k)` every frame for `s` seconds, k from 0 to 1; `t` counts the seconds.
func _run(s: float, step: Callable) -> void:
	t = 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
		step.call(minf(t / s, 1.0))


func _ground(p: Array) -> Vector3:
	return Vector3(p[0], float(p[1]) + world.height_at(p[0], p[2]), p[2])


func _v(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])
