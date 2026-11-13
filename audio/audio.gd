extends Node
## The sound bed (skills/living-atmosphere, design/research/alive.md section 4): the suit you hear most, footsteps
## on the clips' contact frames, a faint muffled Mars outside, a clear humming habitat inside. Sound only: nothing
## here changes game state (hard rule 1).
## A web build plays audio in Sample mode, where bus effects do not run, so every muffle is baked into the files
## (audio/make.sh: `<name>.ogg` clear for the Habitat bus, `<name>_out.ogg` muffled for the Outside bus) and going
## in or out is a crossfade of bus volumes.
## Music is rare (skills/living-atmosphere): a cue at a few earned moments (music()), on its own clear bus, never two at
## once and never soon after the last one; nothing ducks for it, so the suit stays loudest.
## Beds (bed()): now and then one phrase of a calm piece, outside on foot after the first step or inside a room, then
## minutes of rest (Breath of the Wild's field music, design/plans/next-lanes.md 4.2). A bed waits for a cue to end,
## and ducks under one that starts, so it never blocks a cue.
## The radio and the quiet moments: now and then a wordless call from the base or a chirp from PIP on the suit radio,
## clear (a radio is not heard through the helmet), rare and never over another cue; a short motif when the hero
## stands still outside a while or first sees the dust devil; and, in the sunset sky, the far things worth a slow
## look for the camera (follow_cam `glance`).

const BUSES := ["Suit", "Outside", "Habitat", "UI", "Music"]
const SOLIDS := 2  # collision layer 2, statics: a boot on one is on rock or a pad, not in the dust

## Every sound name anything asks for (interactions.gd `used`, the world's and PIP's `sound`, a use spot's `sound` in
## data/world.json) and what it plays: files in audio/, each "file" or "file@seconds" after the start. A file plays
## its clear copy on the Habitat bus and its `_out` copy on Outside, whichever exist; `radio_*` goes to the suit radio.
## One table, so a missing name or file fails audio_test instead of staying silent (the curtain did, 13 Nov).
const SOUNDS := {
	# the sandbox's interactions
	"door_open": ["hiss", "door_open"],  # the lock equalises, then the door moves
	"door_close": ["door_close", "hiss@0.6"],  # shut, then the lock fills
	"curtain": ["curtain"],
	"panel": ["servo"],
	"bag": ["bag_lift"],
	"put_down": ["bag_drop"],
	"rover": ["hiss", "door_open", "door_close@1.2"],  # the cab hatch lets the hero in and shuts behind
	# the base and PIP on their own
	"servo": ["servo"],
	"pip_go": ["pip_go"],
	"pip_hello": ["pip_hello"],
	"radio_pip": ["radio_pip"],
	"radio_base": ["radio_base"],
	# the use spots (design/plans/next-lanes.md section 2): one name per world.json `uses` row
	"drink": ["pour", "sip@1.8"],
	"eat": ["latch", "pouch@0.4", "latch@1.4", "beep@1.8"],  # a real pouch rustle (the foil synth read as odd, 13 Nov)
	"grab": ["grab"],  # something picked up by hand
	"set_down": ["set_down"],  # and put down
	"toilet": ["curtain", "suction@0.8", "curtain@4.2"],
	"plant": ["rattle", "pat@0.7"],
	"harvest": ["leaf"],
	"sample": ["kneel", "rock@0.5", "zip@1.2"],  # the first of a session also plays the discovery cue
	"o2_valve": ["valve", "vent@0.35"],
	"suit_air": ["connect", "refill@0.3", "connect@3.5"],
	"call": ["screens", "radio_base@0.6"],
	"dish": ["servo"],
	"repair": ["latch", "ratchet@0.6", "latch@2.0"],
	"suit_check": ["ticks"],
	"brush": ["brush"],
	# each use-spot sound alone, for a row that wants one
	"pour": ["pour"], "sip": ["sip"], "crinkle": ["crinkle"], "latch": ["latch"], "beep": ["beep"],
	"suction": ["suction"], "rattle": ["rattle"], "pat": ["pat"], "leaf": ["leaf"], "kneel": ["kneel"],
	"rock": ["rock"], "zip": ["zip"], "valve": ["valve"], "vent": ["vent"], "connect": ["connect"],
	"refill": ["refill"], "screens": ["screens"], "ratchet": ["ratchet"], "ticks": ["ticks"],
}
## Every cue music() may play (audio/music/<name>.ogg), and the beds' phrases in the order they take turns.
const CUES := ["first_step", "airlock_sealed", "sunset", "discovery", "mission_lost", "quiet", "dawn", "sleep", "storm"]
const BEDS := {"eva": ["bed_eva_1", "bed_eva_2", "bed_eva_3"], "habitat": ["bed_hab_1", "bed_hab_2"]}
var _storm_heard := false  # the storm's cue played and the storm has not ended (a night in between keeps it)
const SKY_CUES := {"design.sunset": "sunset", "design.storm": "storm"}
# The HUD's own cues and their levels in dB on the UI bus: calm and quieter than the world. The sounds are made in
# code (ui/ui_sounds.gd); ui/game_hud.gd and ui/settings.gd emit `cue(name)`, which the sandbox connects to ui().
const UI_SOUNDS := {
	"objective_new": -14.0, "objective_done": -13.0, "task_tick": -18.0, "pip_open": -18.0, "mail": -16.0,
	"alert": -12.0, "danger": -11.0, "choice_open": -17.0, "choice_made": -16.0, "ledger_open": -16.0,
	"map_open": -17.0, "map_close": -18.0, "tick": -22.0, "select": -18.0,
}
const UiSounds := preload("res://ui/ui_sounds.gd")  # the sky turning plays its cue, once a change

var world: Node3D
var player: Node3D
var t: Dictionary  # data/tuning.json `audio`
var started := false
var inside := 0.0  # where the crossfade is: 0 outside, 1 inside (the habitat or the rover's cab)
var breath_rate: float  # breaths a minute, easing toward what the hero's speed asks
var breath_phase := 0.0  # 0 to 1 through one breath; the clock a chest motion should share
var gust := 1.0  # the wind's swell on top of the sky state's speed: world.gust(), the one every wind listener reads
var steps := 0
var last_step := {}
var _time := 0.0
var _hurry: float  # m/s, the sheet's hurry: full effort and the loudest step
var _hab: Node3D
var _hab_mid: Vector3  # the habitat's middle at head height: where its hum sounds, and a far point the dusk view may turn to
var _rover: Node3D
var _driving := false
var _listener := AudioListener3D.new()
var _wind: AudioStreamPlayer
var _rover_loops: Dictionary = {}  # "motor" or "wheels" -> its players
var _streams: Dictionary = {}
var volume := {"master": 1.0, "music": 1.0, "effects": 1.0, "interface": 1.0}  # the player's own levels (ui/settings.gd), 0 to 1
var _ui := {}  # UI_SOUNDS name -> its sound, made on the first ui() call
var _lift := 0.0  # 0 while the splash and the first build are up (no wind over a loading bar), 1 once lift() has faded in
var cue := ""  # the music cue playing now, "" in silence
var _cue_end := -1e9  # _time the last cue ends; the next may start tuning `music.gap_s` after it
var _cue_player: AudioStreamPlayer
var _cue_tween: Tween
var bed_name := ""  # the bed phrase playing ("bed_eva_2"), "" in its rests
var _bed: AudioStreamPlayer
var _bed_of := ""  # which bed it is a phrase of
var _bed_end := -1e9
var _bed_next: float  # _time the next phrase may start
var _bed_turn := {}  # bed -> the index of its next phrase
var _duck := 0.0  # 0 to 1, how far the world is ducked under a cutscene (duck())
var _ducking := false
var _exert: AudioStreamPlayer  # the respirator under hard breathing
var _found := false  # discovery has played for a rock sample this session
var _dawn := false  # wake() armed the dawn cue for the next door that opens
var _was_inside := false
var _stepped_out := false  # first_step has played this session
var _sky := ""
var _busy_until := -1e9  # _time the last event sound (a door, a beep, a radio call) ends
var radio_last := -1e9  # _time the last radio sound started
var radio_who := ""  # and whose it was: "base" or "pip"
var _radio_want := ""  # a radio sound waiting for quiet
var _radio_by := 0.0  # until this _time, then it is dropped
var _radio_next: float  # _time the base calls next
var _motif_at := -1e9  # _time the quiet motif last started
var _still_s := 0.0  # seconds the hero has stood still outside
var _devil_seen := false
var _glance: Array[Vector3] = []  # the camera's own list (follow_cam `glance`), filled in the sunset sky


func setup(w: Node3D, p: Node3D, tuning: Dictionary) -> void:
	world = w
	player = p
	t = tuning
	_master(0.0)  # nothing is heard until lift()
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	breath_rate = t.breath.rest
	_hurry = world.sheet_values["hero.speed.hurry"]
	add_child(_listener)
	_hab = world.items[t.habitat]
	_hab_mid = _hab.to_global(Vector3.UP * world.hero_height * 0.9)
	_rover = world.items.get("rover")
	player.footstep.connect(_step)
	_radio_next = randf_range(t.radio.base_s[0], t.radio.base_s[1])
	_bed_next = float(t.bed.first_s)
	player.cam.glance = _glance
	# a browser starts no sound before the player's first press (exporting_for_web.rst); elsewhere start now
	if not OS.has_feature("web"):
		start()


## Every player stops on a close request (a window closing, or the tools before they quit): a stream still playing
## when the engine quits stays "in use at exit", and the audio server only lets go of a stopped one a frame later.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_inside_tree():
		started = false  # nothing starts again: _process returns early
		for q: Node in get_tree().get_nodes_in_group("sound"):
			q.stop()


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
	_was_inside = _inside_now()
	_flat("suit_fan", "Suit", t.fan_db).play()
	_exert = _flat("exert", "Suit", -80.0)
	_exert.play()
	_wind = _flat("wind_out", "Outside", t.wind.db)
	_wind.play()
	_at("hum", "Habitat", _hab_mid, t.hum_db, _hab).play()
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
	if _was_inside and into == 0.0 and not _stepped_out:
		_stepped_out = music("first_step")  # out of the airlock or the cab, the first time
	_was_inside = into == 1.0
	if _time >= _cue_end:
		cue = ""
	inside = move_toward(inside, into, delta / t.fade_s)
	_duck = move_toward(_duck, 1.0 if _ducking else 0.0, delta / t.fade_s)
	# equal power, so the doorway does not dip
	_bus("Outside", cos(inside * PI / 2.0))
	_bus("Habitat", sin(inside * PI / 2.0))
	_bus("Suit", lerpf(1.0, db_to_linear(t.suit_inside_db), inside))
	_bus("UI", 1.0)
	_bus("Music", 1.0)
	# hear from the hero's helmet, facing where the camera looks (the camera may be 9 m back from the rover)
	var cam := get_viewport().get_camera_3d()
	_listener.global_transform = Transform3D(cam.global_basis if cam else Basis(), player.body.global_position + Vector3.UP * t.ear_height)
	if not _listener.is_current():
		_listener.make_current()
	_breathe(delta)
	gust = 1.0 + t.wind.gust * (2.0 * world.gust() - 1.0)
	var wind: float = world.dust.wind.length() / t.wind.ref_speed * gust
	_wind.volume_db = t.wind.db + linear_to_db(clampf(wind, 0.05, 2.0))
	if _rover:
		_drive()
	_radio()
	_quiet_moments(delta)
	_beds(delta)


## The sounds an interaction makes (sandbox/interactions.gd `used`): one SOUNDS name, where it happened.
func used(what: String, pos: Vector3) -> void:
	_one_shot("chirp", "UI", t.chirp_db)  # the suit acknowledges, no words
	_hold(_stream("chirp"))
	if SOUNDS.has(what):
		play(what, pos)  # a use spot's own sound already played at its start (world.sound); its id ends here
	if what == "door_close" and _in_room():
		music("airlock_sealed")  # shut in, safe
	elif what == "door_open" and _dawn:
		_dawn = false
		music("dawn", true)  # the first door after a night's sleep opens on the morning
	elif what == "sample" and not _found:
		_found = music("discovery")  # a find; tried again on the next sample if a cue was in the way


## A music cue from audio/music/<name>.ogg, faded in. False when it does not play: before the first press, while
## another cue plays, or within `music.gap_s` of the last one's end (rare by design). `force` (the cine's sleep and
## wake) fades out whatever cue plays and skips the gap.
func music(name: String, force := false) -> bool:
	var m: Dictionary = t.music
	var s := _stream("music/" + name)
	if s == null:
		push_error("audio: no cue audio/music/%s.ogg" % name)
		return false
	if not started or (not force and _time < _cue_end + float(m.gap_s)):
		return false
	if force:
		stop_music()
	if name == t.motif.name:
		_motif_at = _time
	_cue_player = _flat("music/" + name, "Music", -60.0)
	_cue_player.play()
	_cue_tween = create_tween()
	_cue_tween.tween_property(_cue_player, "volume_db", float(m.db), float(m.fade_s))
	_free_after(_cue_player)
	cue = name
	_cue_end = _time + s.get_length()
	return true


## Fades out the cue playing (the cine's cut at the end of a time-lapse); the gap to the next counts from now.
func stop_music() -> void:
	if cue != "" and is_instance_valid(_cue_player):
		if _cue_tween:
			_cue_tween.kill()  # its fade-in would fight the fade-out
		create_tween().tween_property(_cue_player, "volume_db", -60.0, float(t.music.fade_s))
	cue = ""
	_cue_end = minf(_cue_end, _time)


## One phrase of a bed ("eva" or "habitat", BEDS), its phrases taking turns, on the Music bus under any cue. False
## before the first press or while a phrase plays. The next may start a `bed.rest_s` rest after this one ends.
func bed(name: String) -> bool:
	if not started or is_instance_valid(_bed):
		return false
	var phrases: Array = BEDS[name]
	var i: int = _bed_turn.get(name, 0)
	_bed_turn[name] = (i + 1) % phrases.size()
	_bed = _flat("music/" + phrases[i], "Music", _bed_db())
	_bed.play()
	_free_after(_bed)
	_bed_of = name
	bed_name = phrases[i]
	_bed_end = _time + _bed.stream.get_length()
	_bed_next = _bed_end + randf_range(t.bed.rest_s[0], t.bed.rest_s[1])
	return true


## The world's sound (suit, outside, inside) down by `duck_db` while a cutscene wants the music heard, eased.
func duck(on: bool) -> void:
	_ducking = on


## After a sleep (the cine): the next door that opens plays the dawn cue, whatever the gap.
func wake() -> void:
	_dawn = true


## The sky state's name (sandbox SKIES): turning to sunset or storm plays its cue, once per change into it. The sunset
## key also leads between night and day at dawn, so `setting` (the afternoon) holds its cue to the evening; a storm that
## outlasts a night does not play again in the morning.
func sky(name: String, setting := true) -> void:
	var again := name == "design.storm" and _storm_heard
	if name != _sky and SKY_CUES.has(name) and (setting or name != "design.sunset") and not again:
		music(SKY_CUES[name])
	_storm_heard = name == "design.storm" or (_storm_heard and name == "design.night")
	_sky = name


## A level from the settings screen, 0 to 1: `master`, `music` or `effects` (the suit and the world).
func set_volume(which: String, v: float) -> void:
	volume[which] = clampf(v, 0.0, 1.0)
	_master(_lift)


## The cover is down for the first time: the sound fades in over a second. Later covers keep it on.
func lift() -> void:
	if _lift == 0.0:
		_lift = 0.0001  # a second call before the first step starts no second fade
		create_tween().tween_method(_master, 0.0001, 1.0, 1.0)


func _master(k: float) -> void:
	_lift = k
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume.master * k, 0.0001)))


## A world sound at `pos`, by its SOUNDS name: each of its files at its time.
func play(sound: String, pos: Vector3) -> void:
	if not started:
		return
	if not SOUNDS.has(sound):
		push_error("audio: no sound named '%s' (audio.gd SOUNDS)" % sound)
		return
	for step: String in SOUNDS[sound]:
		var after := step.get_slice("@", 1).to_float()  # "" when it has no time: 0
		if after > 0.0:
			get_tree().create_timer(after).timeout.connect(_file.bind(step.get_slice("@", 0), pos))
		else:
			_file(step, pos)


## One file of a sound: the clear copy on Habitat and the muffled one on Outside, so the crossfade picks.
func _file(sound: String, pos: Vector3) -> void:
	if not started:
		return
	if sound.begins_with("radio_"):
		radio(sound.trim_prefix("radio_"))  # PIP on the radio, not in the air
		return
	if not _stream(sound) and not _stream(sound + "_out"):
		push_error("audio: no file audio/%s.ogg nor its _out copy" % sound)
	for v: Array in [["", "Habitat"], ["_out", "Outside"]]:
		var s := _stream(sound + v[0])
		if s:
			var q := _at(sound + v[0], v[1], pos, t.sounds.get(sound, 0.0), self)
			q.pitch_scale = 1.0 + randf_range(-t.pitch, t.pitch)
			q.play()
			_free_after(q)
			_hold(s)


## A radio sound from `who` ("base" or "pip"): it waits for quiet (no cue, no event sound) up to `radio.wait_s`,
## then is dropped; and none comes within `radio.gap_s` of the last, so the radio stays rare.
func radio(who: String) -> void:
	_radio_want = who
	_radio_by = _time + float(t.radio.wait_s)


func state() -> Dictionary:
	var buses := {}
	for b: String in BUSES:
		buses[b] = snappedf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b)), 0.1)
	return {"audio": {"started": started, "inside": snappedf(inside, 0.01), "buses": buses, "breath": snappedf(breath_rate, 0.1),
		"gust": snappedf(gust, 0.01), "steps": steps, "lastStep": last_step, "music": cue, "bed": bed_name,
		"radio": {"who": radio_who, "at": snappedf(radio_last, 0.01)}}}


func _step(pos: Vector3, _yaw: float, foot: String) -> void:
	if not started or player.vehicle:
		return
	var surface := "in" if _in_room() else "sand"
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
	# a recorded breath is one resting breath long: a faster one plays it quicker, or the inhale ran into the exhale
	# hard work: the respirator rises under the breaths, silent at rest
	_exert.volume_db = float(t.breath.exert_db) + linear_to_db(maxf(clampf(hard, 0.0, 1.0), 0.0001))
	var quick := sqrt(maxf(breath_rate / float(t.breath.rest), 1.0))
	if breath_phase < before:
		_one_shot("breath_in", "Suit", db, quick + randf_range(-t.pitch, t.pitch))
	elif before < t.breath.inhale_share and breath_phase >= t.breath.inhale_share:
		_one_shot("breath_out", "Suit", db, quick + randf_range(-t.pitch, t.pitch))


func _drive() -> void:
	var driving: bool = player.vehicle == _rover
	if driving != _driving:
		_driving = driving
		if not driving:  # out through the cab hatch; boarding is the interaction's "rover" sound
			play("door_open", _rover.global_position + Vector3.UP)
	var k := clampf(absf(_rover.speed()) / maxf(_rover.top, 0.1), 0.0, 1.0)
	var r: Dictionary = t.rover
	for q: AudioStreamPlayer3D in _rover_loops.motor:
		_run(q, driving, r.motor_db + linear_to_db(lerpf(r.motor_idle, 1.0, k)), lerpf(r.pitch_min, r.pitch_max, k))
	for q: AudioStreamPlayer3D in _rover_loops.wheels:
		_run(q, k > 0.02, r.wheels_db + linear_to_db(maxf(k, 0.01)), lerpf(r.wheels_pitch[0], r.wheels_pitch[1], k))


func _run(q: AudioStreamPlayer3D, on: bool, db: float, pitch: float) -> void:
	if on != q.playing:
		if on:
			q.play()
		else:
			q.stop()
	q.volume_db = db
	q.pitch_scale = pitch


## The base calls now and then; a waiting radio sound plays once the air is clear.
func _radio() -> void:
	var r: Dictionary = t.radio
	if _time >= _radio_next:
		_radio_next = _time + randf_range(r.base_s[0], r.base_s[1])
		radio("base")
	if _radio_want == "":
		return
	if _time > _radio_by:
		_radio_want = ""
	elif _clear() and _time >= radio_last + float(r.gap_s):
		var sound := "radio_" + _radio_want
		_one_shot(sound, "Suit", float(r.db))
		_hold(_stream(sound))
		radio_last = _time
		radio_who = _radio_want
		_radio_want = ""


## The motif on a quiet moment: the hero standing still outside for a while, or the first time the dust devil is
## near the middle of the view; and the far things the camera may glance at in the sunset sky.
func _quiet_moments(delta: float) -> void:
	var m: Dictionary = t.motif
	var outside := inside == 0.0 and player.vehicle == null
	_still_s = _still_s + delta if outside and player.moved < float(m.still_speed) else 0.0
	var devil: Node3D = world.dust.devil
	var cam := get_viewport().get_camera_3d()
	var sighted := false
	if not _devil_seen and devil.emitting and cam and not cam.is_position_behind(devil.global_position):
		var at := cam.unproject_position(devil.global_position) / get_viewport().get_visible_rect().size
		sighted = absf(at.x - 0.5) < float(m.devil_centre) and at.y > 0.0 and at.y < 1.0
	if (sighted or _still_s > float(m.still_s)) and _time > float(m.after_s) and _time >= _motif_at + float(m.gap_s) and _clear():
		if music(m.name):
			_devil_seen = _devil_seen or sighted
			_still_s = 0.0
	_glance.clear()
	if _sky == "design.sunset" and outside:
		_glance.append(_hab_mid)
		if devil.emitting:
			_glance.append(devil.global_position)


## Which bed fits where the hero is (outside on foot after the first step, or in a room), and its phrases: one at a
## time, after the rest and once any cue is over; ducked while a cue plays; let go if the hero goes in or out.
func _beds(delta: float) -> void:
	var b: Dictionary = t.bed
	if not is_instance_valid(_bed) or _time >= _bed_end:  # over (its player frees itself a little later)
		_bed = null
		bed_name = ""
	var want := ""
	if player.vehicle == null:
		if _in_room():
			want = "habitat"
		elif inside == 0.0 and _stepped_out:
			want = "eva"
	if _bed and _bed_of != want:
		create_tween().tween_property(_bed, "volume_db", -60.0, float(b.fade_s))
		_bed = null
		bed_name = ""
	elif _bed:
		_bed.volume_db = move_toward(_bed.volume_db, _bed_db(), float(b.duck_db) * delta / float(t.music.fade_s))
	elif want != "" and _time >= _bed_next and _time >= _cue_end + float(b.after_cue_s):
		bed(want)


func _bed_db() -> float:
	return float(t.bed.db) - (float(t.bed.duck_db) if cue != "" else 0.0)


## No music cue playing and no event sound sounding.
func _clear() -> bool:
	return _time >= _busy_until and _time >= _cue_end


func _hold(s: AudioStream) -> void:
	if s:
		_busy_until = maxf(_busy_until, _time + s.get_length())


func _inside_now() -> bool:
	return (_rover != null and player.vehicle == _rover) or _in_room()


## In a room (data/world.json `rooms`: HAB 1, the greenhouse): the player's own answer, the one that puts the view in
## first person, so what you hear and what you see change at the same step.
func _in_room() -> bool:
	return player.room != ""


func _bus(b: String, gain: float) -> void:
	var world_bus := b in ["Suit", "Outside", "Habitat"]
	var down := float(t.duck_db) * _duck if world_bus else 0.0
	var level: float = volume.music if b == "Music" else (volume.interface if b == "UI" else volume.effects)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(b), t.bus_db[b] + down + linear_to_db(maxf(gain * level, 0.0001)))


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := "res://audio/%s.ogg" % sound
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]


func _flat(sound: String, bus: String, db: float) -> AudioStreamPlayer:
	var q := AudioStreamPlayer.new()
	q.add_to_group("sound")
	q.stream = _stream(sound)
	q.bus = bus
	q.volume_db = db
	add_child(q)
	return q


func _at(sound: String, bus: String, pos: Vector3, db: float, parent: Node) -> AudioStreamPlayer3D:
	var q := AudioStreamPlayer3D.new()
	q.add_to_group("sound")
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


## A HUD cue by its UI_SOUNDS name, on the UI bus (the settings' Interface level).
func ui(name: String) -> void:
	if not UI_SOUNDS.has(name):
		push_error("audio: no HUD cue '%s' in UI_SOUNDS" % name)
		return
	if _ui.is_empty():
		_ui = UiSounds.build()
	var q := AudioStreamPlayer.new()
	q.add_to_group("sound")
	q.stream = _ui[name]
	q.bus = "UI"
	q.volume_db = UI_SOUNDS[name]
	add_child(q)
	q.play()
	_free_after(q)


## Gone when it has played: a timer, not `finished`, so it holds on any audio driver (the headless one too).
## The length is stretched for the lowest pitch any one-shot gets (1 - step.pitch, about 0.92) with room to spare.
func _free_after(q: Node) -> void:
	q.add_to_group("one_shot")
	get_tree().create_timer(q.stream.get_length() / 0.8 + 0.1).timeout.connect(q.queue_free)
