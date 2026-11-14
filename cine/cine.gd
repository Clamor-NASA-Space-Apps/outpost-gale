extends Node
## The cinematics (design/plans/next-lanes.md section 3, design/plans/event-ready.md row C): the sleep time-lapse, the
## rover-trip skip and the launch, one method each. They move the look clock, the camera and what you see, and count
## nothing (hard rule 1): the rules listen to `slept` and `arrived` and do their own counting. Knobs: data/cine.json.
## Text is ids only (story words come on 14 Nov). Lane P owns `cine/beats*`; this file is lane C's. The tutorial's
## camera shots (shot()) are lane K's.

signal slept(kind: StringName, hours: float)  # the lapse is over: the sim counts the hours (lane S)
signal show_card(ledger: Dictionary)  # at the wake, for the ledger card (lane H)
signal arrived(landmark: String)
signal launched
signal shot_done(name: String)  # a tutorial shot (shot()) is over and the play camera is back: once per call

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
var beat := ""  # the beat on screen ("" when none): sleep_drone, wake, trip_drive, trip_title, launch_*, a shot's name
var t := 0.0  # seconds into the current beat
var _black := ColorRect.new()
var _title: Label
var _prev: Camera3D  # the camera in use before a shot, given back after it
var _holding := false
var _was_driven := false
var _frozen := {}  # node -> its process_mode before a shot froze it
var _rim_bins: Array = []  # _rim(): the crater rim's vertices by bearing
var _body_yaw := 0.0  # the hero's facing, eased, while a shot plays (the 'body' ref)
var _sun_yaw := 0.0  # rotation.y facing the sun, set when a shot starts (the 'sun' ref)


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
	return picker.visible or beat != ""


func state() -> Dictionary:
	return {"cine": {"shot": beat, "t": snappedf(t, 0.01), "picker": picker.visible}}


## A bed spot (data/world.json `uses`, kind `bed`, no clip: it reports at once) used: the picker, with the clock held
## while it is open; before the sol's tasks are done, PIP says why not (beats.may_sleep()).
func _used(what: String, _pos: Vector3) -> void:
	if what != "bed" or busy():
		return
	var beats: Node = game.get("beats")
	if beats and not beats.may_sleep():  # the sol's tasks first: a bed used early skipped whole sols (14 Nov playtest)
		beats.refuse_sleep()
		return
	_take_clock()
	picker.open()


## The sleep time-lapse: a night to the fixed wake hour, or a nap of `nap_h`. Lights out, a drone shot of the base
## while the look clock runs on, then the wake in HAB 1: the hero on the bench by the hatch, the lights up.
func sleep(kind: StringName) -> void:
	if beat != "":
		return
	var c: Dictionary = cfg.sleep
	_take_clock()
	var from: float = clock.hours
	var span: float = float(c.nap_h) if kind == &"nap" else fposmod(float(c.wake_h) - clock.hour(), 24.0)
	if kind == &"night" and game.get("sim"):  # never less than the rules' full night (sim.json sleep_h, in local hours)
		var r: Object = game.sim.sim
		span = maxf(span, r.n("clock", "sleep_h") * 24.0 / r.n("clock", "sol_h"))
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
	beat = "wake"
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
	if beat != "" or not world.data.landmarks.has(landmark):
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
	beat = "trip_title"
	_title.text = _words(c.title_id).format(args)
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
	if beat != "":
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
	beat = "launch_out"
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
	beat = "launch_window"
	_title.text = _words(c.caption_id)
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
	beat = "launch_back"
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


## A tutorial camera shot (data/cine.json `shots`: dawn_reveal, focus_pip, look_around): from the camera in use
## through the shot's keys and back to exactly where it was, one spline in time eased at both ends, the hero frozen
## (and PIP, unless the shot films it rolling up), the look clock held. Refused (busy(), or no such shot):
## shot_done still fires, a frame later, so a caller waiting on it never hangs. `args` is not read yet.
func shot(name: String, _args := {}) -> void:
	# an outdoor shot never plays indoors (skills/guided-tutorial rows 3, 4): the beats lead the hero out first
	if busy() or not cfg.shots.has(name) or (cfg.shots[name].get("outdoors", false) and player.room != ""):
		push_warning("cine: no shot '%s' now" % name)
		shot_done.emit.call_deferred(name)
		return
	var c: Dictionary = cfg.shots[name]
	_begin(name)
	if c.get("mouse", false):
		await _mouse_look(c)
		_end()
		shot_done.emit(name)
		return
	var from: Camera3D = _prev if is_instance_valid(_prev) else player.cam.lens
	var home := {"eye": from.global_position, "rot": from.global_basis.get_rotation_quaternion(), "fov": from.fov,
		"shift": float(from.get("shift")) if "shift" in from else 0.0}
	# hero_moves: the hero walks on during the shot (the beats steer it), and the shot ends on the play camera's live
	# pose (to_play), so it hands over without a snap wherever the walk took the hero
	_freeze([null if c.get("hero_moves", false) else player, null if c.get("pip_moves", false) else game.pip])
	var showed: bool = player.cam.show_body
	player.cam.show_body = true  # this camera films the body, even while the play lens sits in the head
	_take_clock()
	if c.has("music"):
		audio.music(c.music, audio.cue != c.music)  # the dawn cue may already be on from the door (audio.wake())
	# takes: a key with `cut` starts a new one at once (a hard cut); the camera glides only within a take, each eased
	var ts: Array[float] = [0.0]
	var cuts: Array[int] = [0]
	for k: Dictionary in c.keys:
		if k.get("cut", false):
			cuts.append(ts.size())
		ts.append(ts[-1] + (0.0 if k.get("cut", false) else float(k.s)))
	ts.append(ts[-1] + float(c.back_s))
	cuts.append(ts.size())
	var total := ts[-1]
	var fired := {}  # the shot's timed events (pip_to, beep) that went off
	var near := cam.near
	cam.near = from.near
	# a sunrise shot runs the held clock on so the sun breaks over the rim `break_s` in, from whatever hour it finds
	# (only ever forward: a clock already past the rise keeps its hour)
	var rise: Dictionary = c.get("sunrise", {})
	var day: float = clock.hours - clock.hour()
	var h0: float = clock.hour()
	_sun_yaw = _yaw_of(HouseStyle.sun_at(clock._C, h0))  # the bearing barely moves over a sunrise: 'sun' keys
	var up := sunrise_hour(float(rise.get("peek_deg", 0.0))) if not rise.is_empty() else 0.0
	var lapse := not rise.is_empty() and h0 < up - 0.01
	_body_yaw = player.yaw
	var step := func(k: float) -> void:
		# the 'body' frame turns with the hero smoothed: a quick pivot swung the spot behind into a wall (14 Nov)
		_body_yaw = lerp_angle(_body_yaw, player.yaw, 1.0 - exp(-float(c.get("body_rate", 4.0)) * get_process_delta_time()))
		var poses := [home]
		for key: Dictionary in c.keys:
			poses.append(home if key.get("hold", false) else _key(key))  # every frame: PIP may be moving
		if c.get("to_play", false) and k < 1.0:
			# unseen while this camera films: the play camera eases round behind the hero for the hand-over, wherever
			# the kid had turned it (turned back at a wall, its arm cut in and the landing jumped, 14 Nov)
			var fc: Node3D = player.cam
			# behind the hero, then round to the landing bearing for the last glide (the end frame's own heading)
			var want: float = player.yaw if not c.has("land_bearing") or k * total < ts[-2] else -deg_to_rad(float(c.land_bearing))
			fc.yaw = lerp_angle(fc.yaw, want, 1.0 - exp(-float(c.get("behind_rate", 3.0)) * get_process_delta_time()))
		poses.append(_lens() if c.get("to_play", false) else home)
		var lin := k * total
		var j := 0
		while j < cuts.size() - 2 and lin >= ts[cuts[j + 1]]:
			j += 1
		var lo := cuts[j]
		var hi := cuts[j + 1] - 1
		var e := smoothstep(0.0, 1.0, (lin - ts[lo]) / maxf(ts[hi] - ts[lo], 0.001))
		_pose(poses, ts, ts[lo] + (ts[hi] - ts[lo]) * e, lo, hi)
		_events(c, lin, fired)
		if c.get("arm", false) and k < 1.0:  # like the play camera's spring arm: never behind a wall from the hero
			cam.global_position = _clear(cam.global_position)
		if c.get("hero_moves", false):
			# the body fades as one by this camera's gap to it, as the play lens fades it (follow_cam.gd): runs after
			# the physics step set the lens's fade and before player.gd applies it
			var fc: Node3D = player.cam
			var p: Vector3 = fc.target.global_transform.affine_inverse() * cam.global_position
			var gap := p.distance_to(p.clamp(fc.shell.position, fc.shell.end))
			fc.fade = smoothstep(float(fc.t.fade_near), float(fc.t.fade_far), gap) if k < 1.0 else fc.fade
		if lapse:
			var s := k * total
			var b := float(rise.break_s)
			clock.set_hour(day + (lerpf(h0, up, s / b) if s < b else up + (s - b) * float(rise.h_per_s)))
	step.call(0.0)
	cam.make_current()
	await _run(total, step)
	_thaw()
	_give_clock()
	player.cam.show_body = showed
	_title.hide()
	_title.modulate.a = 1.0
	cam.near = near
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE  # the other beats set only the fov
	cam.fov = float(cfg.fov)
	_end()
	shot_done.emit(name)


## A shot made the way a player's own mouse makes it (look_around, Ravindu's video of 14 Nov 10:09): the play camera
## itself turns through `turn_deg` (positive turns left, as a mouse dragged left) in `turn_s` at a steady speed eased
## in and out over `ease` of the turn, pitched up `pitch_deg` meanwhile, so its own collision, distance from the pitch
## and framing apply. It holds `hold_s` first (while the view tilts up) and ends where it started, input locked.
func _mouse_look(c: Dictionary) -> void:
	var fc: Node3D = player.cam
	var allowed: Array = player.allowed.duplicate()
	player.allow(["none"])
	_take_clock()
	var yaw0: float = fc.yaw
	var pitch0: float = fc.pitch
	var up := deg_to_rad(float(c.pitch_deg))
	var hold := float(c.hold_s)
	var turn := float(c.turn_s)
	var f := float(c.ease)
	var total := hold + turn
	await _run(total, func(k: float) -> void:
		var s := k * total
		var u := clampf((s - hold) / turn, 0.0, 1.0)
		# a steady speed with eased ends: the speed ramps up over the first `f` of the turn and down over the last
		var e := u * u / (2.0 * f * (1.0 - f)) if u < f else (1.0 - (1.0 - u) * (1.0 - u) / (2.0 * f * (1.0 - f)) if u > 1.0 - f else (u - f / 2.0) / (1.0 - f))
		var yaw: float = yaw0 + deg_to_rad(float(c.turn_deg)) * e
		var tilt := smoothstep(0.0, hold, s) * (1.0 - smoothstep(1.0 - f, 1.0, u))
		var pitch: float = lerpf(pitch0, up, tilt)
		fc.look(-rad_to_deg(yaw - fc.yaw), rad_to_deg(fc.pitch - pitch)))
	_give_clock()
	player.allow(allowed)


## The play camera's pose now, as a shot key.
func _lens() -> Dictionary:
	var l: Camera3D = player.cam.lens
	return {"eye": l.global_position, "rot": l.global_basis.get_rotation_quaternion(), "fov": l.fov, "shift": float(l.shift)}


## A shot's timed extras at `s` seconds in: `title` [in, out, fade] (cine_title from data/lines.json, faded in and out),
## `pip_to` [s, ref] (PIP rolls up to that spot, facing the hero), `beep` [s, sound] (at PIP).
func _events(c: Dictionary, s: float, fired: Dictionary) -> void:
	if c.has("title"):
		var tl: Array = c.title
		var a := clampf(minf((s - float(tl[0])) / float(tl[2]), (float(tl[1]) - s) / float(tl[2])), 0.0, 1.0)
		if a > 0.0 and not _title.visible:
			_title.text = _words("cine_title")
			_title.show()
		_title.modulate.a = a
		_title.visible = a > 0.0
	if c.has("pip_to") and game.pip and s >= float(c.pip_to[0]) and not fired.has("pip_to"):
		fired["pip_to"] = true
		game.pip.order(_at(c.pip_to[1]), player.body.global_position + Vector3.UP * 1.6)
	if c.has("beep") and game.pip and s >= float(c.beep[0]) and not fired.has("beep"):
		fired["beep"] = true
		audio.play(c.beep[1], game.pip.global_position)


## The hour of the sol the sun's centre clears the skyline, seen from dawn_reveal's sunrise key (`sunrise.key`, a fixed
## eye: a ground or world ref).
func sunrise_hour(peek := 0.0) -> float:
	var c: Dictionary = cfg.shots.dawn_reveal
	var eye: Vector3 = _key(c.keys[int(c.sunrise.key)]).eye
	var lo := 0.0
	var hi := 12.0
	for i in 24:
		var mid := (lo + hi) / 2.0
		if sun_clear(mid, eye) > peek:
			hi = mid
		else:
			lo = mid
	return (hi + lo) / 2.0


## Degrees the sun's centre stands over the skyline at its own azimuth, seen from `eye`, at local hour `h`: the patch
## marched out along that way, then the backdrop's crater rim (models/terrain_backdrop.glb).
func sun_clear(h: float, eye: Vector3) -> float:
	var sun: Vector3 = HouseStyle.sun_at(clock._C, h).normalized()  # the sky the clock places the sun in
	var way := Vector2(sun.x, sun.z).normalized()
	var top := -90.0
	for d in range(2, 300, 2):
		var p := Vector2(eye.x, eye.z) + way * d
		top = maxf(top, rad_to_deg(atan2(world.height_at(p.x, p.y) - eye.y, d)))
	var bin := int(fposmod(rad_to_deg(atan2(way.x, -way.y)), 360.0))
	for i in range(bin - 1, bin + 2):  # the rim's vertices lie about 2 deg apart
		for v: Vector3 in _rim()[posmod(i, 360)]:
			var flat := Vector2(v.x - eye.x, v.z - eye.z)
			top = maxf(top, rad_to_deg(atan2(v.y - eye.y, flat.length())))
	return rad_to_deg(asin(sun.y)) - top


## Where the opening leaves the hero for dawn_reveal (data/beats.json face_dawn): east of HAB 1's door, facing the
## sunrise; for tests and captures.
func stand_for_dawn() -> void:
	var at := Vector3(3.5, 0.0, 5.5)
	player.place(Vector3(at.x, world.height_at(at.x, at.z) + 0.1, at.z), -rad_to_deg(_yaw_of(HouseStyle.sun_at(clock._C, clock.hour()))))
	player.cam.snap(player.yaw)


func _yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


## The backdrop's vertices in world metres, by whole degrees of bearing from the patch centre (read once).
func _rim() -> Array:
	if _rim_bins.is_empty():
		_rim_bins.resize(360)
		for i in 360:
			_rim_bins[i] = []
		var back: Node3D = load("res://models/terrain_backdrop.glb").instantiate()
		for mi: MeshInstance3D in back.find_children("*", "MeshInstance3D", true, false):
			var x := Transform3D()
			var n: Node = mi
			while n is Node3D:  # out of the tree, so no global_transform
				x = (n as Node3D).transform * x
				n = n.get_parent()
			for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var g := x * v
				_rim_bins[int(fposmod(rad_to_deg(atan2(g.x, -g.z)), 360.0))].append(g)
		back.free()
	return _rim_bins


## One key of a shot: where the eye is and what it looks at, each [ref, [x, y, z]] (data/cine.json shots._note).
func _key(key: Dictionary) -> Dictionary:
	var eye := _at(key.eye) if key.has("eye") else Vector3.ZERO
	if key.has("orbit"):  # the play camera's own place: behind the hero, away from what it looks at
		var to: Vector3 = _at(key.look) - player.body.global_position
		eye = player.body.global_position + Vector3.UP * float(key.orbit[1]) - Vector3(to.x, 0.0, to.z).normalized() * float(key.orbit[0])
	if key.has("orbit") or key.eye[0] in ["hero", "sun", "body"]:
		eye = _clear(eye)
	return {"eye": eye, "rot": Basis.looking_at(_at(key.look) - eye).get_rotation_quaternion(),
		"fov": float(key.get("fov", cfg.fov)), "shift": 0.0}


func _at(r: Array) -> Vector3:
	var o := Vector3(r[1][0], r[1][1], r[1][2])
	match r[0]:
		"hero":  # the hero's feet, turned the way the play camera faces (-Z ahead, +Z back toward the lens)
			return player.body.global_position + Basis(Vector3.UP, player.cam.yaw) * o
		"body":  # the hero's feet, turned the way the hero faces (-Z ahead, +Z behind)
			return player.body.global_position + Basis(Vector3.UP, _body_yaw) * o
		"sun":  # the hero's feet, turned to the rising sun's bearing (-Z toward the sun)
			return player.body.global_position + Basis(Vector3.UP, _sun_yaw) * o
		"ground":
			return _ground(r[1])
		"world":
			return o
	return world.items[r[0]].to_global(o)


## A point near the hero pulled in front of whatever stands between it and the hero's head, as the spring arm does.
func _clear(eye: Vector3) -> Vector3:
	var head: Vector3 = player.body.global_position + Vector3.UP * float(cfg.shot_margin[1])
	var q := PhysicsRayQueryParameters3D.create(head, eye)
	q.exclude = [player.body.get_rid()]
	var space := world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		eye = hit.position + (head - eye).normalized() * float(cfg.shot_margin[0])
	# a ray through a doorway can end inside the wall beside it: step in while a ball there still touches a solid
	var ball := PhysicsShapeQueryParameters3D.new()
	ball.shape = SphereShape3D.new()
	ball.shape.radius = 0.25
	ball.exclude = q.exclude
	for i in 16:
		ball.transform = Transform3D(Basis(), eye)
		if space.intersect_shape(ball, 1).is_empty() or eye.distance_to(head) < 0.5:
			break
		eye = eye.move_toward(head, 0.25)
	return eye


## The cine camera at `tau` seconds along the keys at times `ts`: position, turn, fov and the lens's frame shift each
## on a cubic through time (Barry-Goldman, the engine's own), so the camera never stops at a key.
func _pose(p: Array, ts: Array[float], tau: float, lo := 0, hi := -1) -> void:
	hi = p.size() - 1 if hi < 0 else hi
	var i := lo
	while i < hi - 1 and tau > ts[i + 1]:
		i += 1
	var a := maxi(i - 1, lo)
	var b := mini(i + 2, hi)
	var span := ts[i + 1] - ts[i]
	var w := clampf((tau - ts[i]) / span, 0.0, 1.0)
	var pre := ts[a] - ts[i]
	var post := ts[b] - ts[i]
	var eye: Vector3 = p[i].eye.cubic_interpolate_in_time(p[i + 1].eye, p[a].eye, p[b].eye, w, span, pre, post)
	var rot: Quaternion = p[i].rot.spherical_cubic_interpolate_in_time(p[i + 1].rot, p[a].rot, p[b].rot, w, span, pre, post)
	var f := {}
	for k: String in ["fov", "shift"]:
		f[k] = cubic_interpolate_in_time(p[i][k], p[i + 1][k], p[a][k], p[b][k], w, span, pre, post)
	cam.global_transform = Transform3D(Basis(rot.normalized()), eye)
	var h := 2.0 * cam.near * tan(deg_to_rad(f.fov) / 2.0)  # the lens's own off-axis frustum (follow_cam.gd Lens)
	cam.set_frustum(h, Vector2(0.0, f.shift * h), cam.near, cam.far)


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
	beat = name
	t = 0.0


func _give_camera() -> void:
	var to: Camera3D = _prev if is_instance_valid(_prev) and _prev != cam else player.cam.lens
	to.make_current()


func _end() -> void:
	_give_camera()
	beat = ""
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


## A card's words from data/lines.json through the HUD, like PIP's (tr() had no table and showed the raw id).
func _words(id: String) -> String:
	var hud: Variant = game.get("hud") if game else null
	return hud.line(id) if hud else tr(id)
