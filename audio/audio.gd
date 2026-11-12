extends Node
## The sound bed (skills/living-atmosphere, design/research/alive.md section 4): the suit you hear most, footsteps
## on the clips' contact frames, a faint muffled Mars outside, a clear humming habitat inside. Sound only: nothing
## here changes game state (hard rule 1).
## A web build plays audio in Sample mode, where bus effects do not run, so every muffle is baked into the files
## (audio/make.sh: `<name>.ogg` clear for the Habitat bus, `<name>_out.ogg` muffled for the Outside bus) and going
## in or out is a crossfade of bus volumes.

const BUSES := ["Suit", "Outside", "Habitat", "UI"]
const SOLIDS := 2  # collision layer 2, statics: a boot on one is on rock or a pad, not in the dust

var world: Node3D
var player: Node3D
var t: Dictionary  # data/tuning.json `audio`
var started := false
var inside := 0.0  # where the crossfade is: 0 outside, 1 inside (the habitat or the rover's cab)
var breath_rate: float  # breaths a minute, easing toward what the hero's speed asks
var breath_phase := 0.0  # 0 to 1 through one breath; the clock a chest motion should share
var gust := 1.0  # the wind's slow swell on top of the sky state's speed
var steps := 0
var last_step := {}
var _time := 0.0
var _hurry: float  # m/s, the sheet's hurry: full effort and the loudest step
var _hab: Node3D
var _hab_box: AABB  # the habitat's inside, in its own space
var _rover: Node3D
var _driving := false
var _listener := AudioListener3D.new()
var _wind: AudioStreamPlayer
var _rover_loops: Dictionary = {}  # "motor" or "wheels" -> its players
var _noise := FastNoiseLite.new()
var _streams: Dictionary = {}


func setup(w: Node3D, p: Node3D, tuning: Dictionary) -> void:
	world = w
	player = p
	t = tuning
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	breath_rate = t.breath.rest
	_hurry = world.sheet_values["hero.speed.hurry"]
	_noise.frequency = t.wind.gust_hz
	add_child(_listener)
	_hab = world.items[t.habitat]
	_hab_box = _enclosure(_hab)
	_rover = world.items.get("rover")
	player.footstep.connect(_step)
	# a browser starts no sound before the player's first press (exporting_for_web.rst); elsewhere start now
	if not OS.has_feature("web"):
		start()


func _input(e: InputEvent) -> void:
	if not started and e.is_pressed():
		start()


## The loops that are always there. Called on the first press, once.
func start() -> void:
	if started:
		return
	started = true
	# loops loop by their import files (loop=true). A web build loops a sample by restarting it when it ends
	# (library_godot_audio.js, 4.7.2), so make.sh crossfades each loop's ends to hide the seam
	_flat("suit_fan", "Suit", t.fan_db).play()
	_wind = _flat("wind_out", "Outside", t.wind.db)
	_wind.play()
	_at("hum", "Habitat", _hab.global_transform * _hab_box.get_center(), t.hum_db, _hab).play()
	for id: String in t.machines:
		_at("hum_out", "Outside", world.items[id].global_position + Vector3.UP, t.hum_db, world.items[id]).play()
	if _rover:
		for n: String in ["motor", "wheels"]:
			_rover_loops[n] = [_at(n, "Habitat", Vector3.ZERO, 0.0, _rover), _at(n + "_out", "Outside", Vector3.ZERO, 0.0, _rover)]
			for q: AudioStreamPlayer3D in _rover_loops[n]:
				q.position = Vector3(0, 1, 0)


func _process(delta: float) -> void:
	if not started:
		return
	_time += delta
	var into := 1.0 if _inside_now() else 0.0
	inside = move_toward(inside, into, delta / t.fade_s)
	# equal power, so the doorway does not dip
	_bus("Outside", cos(inside * PI / 2.0))
	_bus("Habitat", sin(inside * PI / 2.0))
	_bus("Suit", lerpf(1.0, db_to_linear(t.suit_inside_db), inside))
	_bus("UI", 1.0)
	# hear from the hero's helmet, facing where the camera looks (the camera may be 9 m back from the rover)
	var cam := get_viewport().get_camera_3d()
	_listener.global_transform = Transform3D(cam.global_basis if cam else Basis(), player.body.global_position + Vector3.UP * t.ear_height)
	if not _listener.is_current():
		_listener.make_current()
	_breathe(delta)
	gust = 1.0 + t.wind.gust * _noise.get_noise_1d(_time)
	var wind: float = world.dust.wind.length() / t.wind.ref_speed * gust
	_wind.volume_db = t.wind.db + linear_to_db(clampf(wind, 0.05, 2.0))
	if _rover:
		_drive()


## The sounds an interaction makes (sandbox/interactions.gd `used`): one name, where it happened.
func used(what: String, pos: Vector3) -> void:
	_one_shot("chirp", "UI", t.chirp_db)  # the suit acknowledges, no words
	match what:
		"door_open":
			play("hiss", pos)  # the lock equalises, then the door moves
			play("door_open", pos)
		"door_close":
			play("door_close", pos)
			get_tree().create_timer(t.hiss_after).timeout.connect(play.bind("hiss", pos))
		"panel":
			play("servo", pos)
		"bag":
			play("bag_lift", pos)
		"put_down":
			play("bag_drop", pos)


## A world sound at `pos`: the clear copy on Habitat and the muffled one on Outside, so the crossfade picks.
func play(sound: String, pos: Vector3) -> void:
	if not started:
		return
	for v: Array in [["", "Habitat"], ["_out", "Outside"]]:
		var s := _stream(sound + v[0])
		if s:
			var q := _at(sound + v[0], v[1], pos, t.sounds.get(sound, 0.0), self)
			q.pitch_scale = 1.0 + randf_range(-t.pitch, t.pitch)
			q.play()
			_free_after(q)


func state() -> Dictionary:
	var buses := {}
	for b: String in BUSES:
		buses[b] = snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b)), 0.1)
	return {"audio": {"started": started, "inside": snappedf(inside, 0.01), "buses": buses, "breath": snappedf(breath_rate, 0.1),
		"gust": snappedf(gust, 0.01), "steps": steps, "lastStep": last_step}}


func _step(pos: Vector3, _yaw: float, foot: String) -> void:
	if not started or player.vehicle:
		return
	var surface := "in" if _in_habitat() else "sand"
	if surface == "sand":
		var ray := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 0.2, SOLIDS)
		if world.get_world_3d().direct_space_state.intersect_ray(ray):
			surface = "rock"
	var v: Vector3 = player.body.velocity
	var k := clampf(Vector2(v.x, v.z).length() / _hurry, 0.0, 1.0)
	_one_shot("step_%s_%s%d" % [surface, foot.right(1), randi_range(1, 3)], "Habitat" if surface == "in" else "Suit",
		lerpf(t.step.db_soft, t.step.db_loud, k), 1.0 + randf_range(-t.step.pitch, t.step.pitch))
	steps += 1
	last_step = {"foot": foot, "surface": surface, "time": snappedf(_time, 0.01)}


## One clock: the rate eases toward the effort (fast up, slow down), the phase runs at the rate, and an inhale
## and an exhale play at fixed points of it, louder when hard.
func _breathe(delta: float) -> void:
	var v: Vector3 = player.body.velocity
	var effort := 0.0 if player.vehicle else clampf(Vector2(v.x, v.z).length() / _hurry, 0.0, 1.0)
	var want: float = lerpf(t.breath.rest, t.breath.hard, effort)
	var tau: float = t.breath.rise_s if want > breath_rate else t.breath.fall_s
	breath_rate += (want - breath_rate) * (1.0 - exp(-delta / tau))
	var before := breath_phase
	breath_phase = fmod(breath_phase + delta * breath_rate / 60.0, 1.0)
	var hard := inverse_lerp(t.breath.rest, t.breath.hard, breath_rate)
	var db: float = lerpf(t.breath.db_rest, t.breath.db_hard, clampf(hard, 0.0, 1.0))
	if breath_phase < before:
		_one_shot("breath_in", "Suit", db, 1.0 + randf_range(-t.pitch, t.pitch))
	elif before < t.breath.inhale_share and breath_phase >= t.breath.inhale_share:
		_one_shot("breath_out", "Suit", db, 1.0 + randf_range(-t.pitch, t.pitch))


func _drive() -> void:
	var driving: bool = player.vehicle == _rover
	if driving != _driving:
		_driving = driving
		used("door_close" if driving else "door_open", _rover.global_position + Vector3.UP)  # the cab hatch
	var k := clampf(absf(_rover.speed()) / maxf(_rover.top, 0.1), 0.0, 1.0)
	var r: Dictionary = t.rover
	for q: AudioStreamPlayer3D in _rover_loops.motor:
		_run(q, driving, r.motor_db + linear_to_db(0.3 + 0.7 * k), lerpf(r.pitch_min, r.pitch_max, k))
	for q: AudioStreamPlayer3D in _rover_loops.wheels:
		_run(q, k > 0.02, r.wheels_db + linear_to_db(maxf(k, 0.01)), lerpf(0.85, 1.1, k))


func _run(q: AudioStreamPlayer3D, on: bool, db: float, pitch: float) -> void:
	if on != q.playing:
		if on:
			q.play()
		else:
			q.stop()
	q.volume_db = db
	q.pitch_scale = pitch


func _inside_now() -> bool:
	return (_rover != null and player.vehicle == _rover) or _in_habitat()


func _in_habitat() -> bool:
	return _hab_box.has_point(_hab.to_local(player.body.global_position + Vector3.UP * 0.5))


## The habitat's inside in its own space: its drawn box, from the airlock door's inner face to the far wall.
func _enclosure(item: Node3D) -> AABB:
	var inv := item.global_transform.affine_inverse()
	var box := AABB()
	var door := AABB()
	for m: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = inv * (m.global_transform * m.get_aabb())
		if m.name == "door":
			door = a
		box = a if box.size == Vector3.ZERO else box.merge(a)
	# ponytail: the door sits in an end wall across the model's z, as building_habitat.glb is built
	if door.get_center().z < box.get_center().z:
		box.size.z = box.end.z - door.end.z
		box.position.z = door.end.z
	else:
		box.size.z = door.position.z - box.position.z
	return box


func _bus(b: String, gain: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), t.bus_db[b] + linear_to_db(maxf(gain, 0.0001)))


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := "res://audio/%s.ogg" % sound
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func _flat(sound: String, bus: String, db: float) -> AudioStreamPlayer:
	var q := AudioStreamPlayer.new()
	q.stream = _stream(sound)
	q.bus = bus
	q.volume_db = db
	add_child(q)
	return q


func _at(sound: String, bus: String, pos: Vector3, db: float, parent: Node) -> AudioStreamPlayer3D:
	var q := AudioStreamPlayer3D.new()
	q.stream = _stream(sound)
	q.bus = bus
	q.volume_db = db
	# Mars: "falters at just 26 feet (8 meters)" (NASA/JPL 2022); the distance high-cut is an effect, and the
	# web build skips effects, so it is off here too and both builds sound the same
	q.max_distance = t.range
	q.unit_size = t.unit_size
	q.attenuation_filter_db = 0.0
	parent.add_child(q)
	q.global_position = pos
	return q


func _one_shot(sound: String, bus: String, db: float, pitch := 1.0) -> void:
	var q := _flat(sound, bus, db)
	q.pitch_scale = pitch
	q.play()
	_free_after(q)


## Gone when it has played: a timer, not `finished`, so it holds on any audio driver (the headless one too).
## The length is stretched for the lowest pitch any one-shot gets (1 - step.pitch, about 0.92) with room to spare.
func _free_after(q: Node) -> void:
	q.add_to_group("one_shot")
	get_tree().create_timer(q.stream.get_length() / 0.8 + 0.1).timeout.connect(q.queue_free)
