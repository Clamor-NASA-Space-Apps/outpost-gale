extends "res://addons/forge/test.gd"
## The sound bed listens to the game (skills/living-atmosphere, Checks): godot --headless --path . -s tests/audio_test.gd

const KEYS := ["started", "inside", "buses", "breath", "gust", "steps", "lastStep", "music", "bed", "radio"]

var game: Node3D
var audio: Node


func _init() -> void:
	watchdog = 120.0


func bus(b: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b))


func seconds(s: float) -> void:
	await create_timer(s).timeout


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	audio = game.audio
	audio._bed_next = 1e9  # no bed phrase until the bed checks below ask for one: they would count as music here
	var player: Node3D = game.player
	check(audio.started, "the bed starts at once outside a browser")

	# four buses, and no effect on any: a web build would skip it (Sample mode)
	for b: String in audio.BUSES:
		check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	for i in AudioServer.bus_count:
		check(AudioServer.get_bus_effect_count(i) == 0, "bus %s holds no effect" % AudioServer.get_bus_name(i))
	for q: AudioStreamPlayer3D in audio.find_children("*", "AudioStreamPlayer3D", true, false) + game.world.find_children("*", "AudioStreamPlayer3D", true, false):
		check(q.max_distance > 0.0 and q.max_distance <= audio.t.range, "%s carries no further than Mars allows" % q.name)

	# no game state in what the tools read (hard rule 1)
	var st: Dictionary = audio.state()
	check(st.keys() == ["audio"], "audio state is one key")
	for k: String in st.audio:
		check(k in KEYS, "audio state has '%s': sound only, no game state" % k)

	# a footstep signal plays a footstep, one per contact, the right foot's set
	var before: int = audio.steps
	player.footstep.emit(player.body.global_position, 0.0, "foot_r")
	check(audio.steps == before + 1, "one footstep signal, one footstep sound")
	var last: Node = audio.get_child(audio.get_child_count() - 1)
	check(last is AudioStreamPlayer and last.playing and last.stream.resource_path.get_file().begins_with("step_sand_r"), "the right foot plays a right step on sand")

	# walking: every contact event and nothing else makes a step; breathing quickens and settles
	var contacts := [0]
	player.footstep.connect(func(_p: Vector3, _y: float, _f: String) -> void: contacts[0] += 1)
	var rest: float = audio.breath_rate
	var l: Dictionary = game.world.landmark("spawn")
	player.place(l.pos, 90.0)
	before = audio.steps
	action(&"hurry")
	action(&"move_forward")
	await seconds(5.0)
	action(&"move_forward", false)
	action(&"hurry", false)
	check(contacts[0] > 3, "the walk had contacts (%d)" % contacts[0])
	check(audio.steps - before == contacts[0], "one step sound per contact (%d sounds, %d contacts)" % [audio.steps - before, contacts[0]])
	var peak: float = audio.breath_rate
	check(peak > rest + 5.0, "breathing quickens with speed (%.1f to %.1f a minute)" % [rest, peak])
	await seconds(5.0)
	check(audio.breath_rate < peak - 2.0, "and settles back when the hero stops (%.1f from %.1f)" % [audio.breath_rate, peak])
	check(audio.breath_rate >= audio.t.breath.rest, "never below rest")

	# one-shots go away when they have played
	var shots: Array[Node] = []
	for what: String in ["door_open", "door_close", "panel", "bag", "put_down"]:
		audio.used(what, player.body.global_position)
	await frames(1)
	shots = game.get_tree().get_nodes_in_group("one_shot")
	check(shots.size() >= 10, "the interactions played (%d one-shots)" % shots.size())
	for q: Node in shots:
		check(not q.stream.loop, "%s is not a loop" % q.stream.resource_path.get_file())
	await seconds(3.5)
	var left := shots.filter(func(q: Variant) -> bool: return is_instance_valid(q))
	check(left.is_empty(), "every one-shot is freed after it played (left: %s)" % [left.map(func(q: Node) -> String: return q.stream.resource_path.get_file())])
	var loops := audio.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.playing and not n.is_in_group("one_shot"))
	check(loops.size() <= 6, "only the bed's loops run (%d)" % loops.size())

	# through the airlock: outside falls and the habitat rises within the fade
	check(bus("Outside") > -1.0 and bus("Habitat") < -40.0, "outside: the Outside bus up, the Habitat bus down")
	var door: Node3D
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if it.kind == "door" and it.get_parent() == game.world.items[audio.t.habitat]:
			door = it
	game.interactions.use(door)
	l = game.world.landmark("airlock")
	player.place(l.pos, l.yaw)
	await seconds(0.5)
	action(&"move_forward")
	await seconds(4.0)
	action(&"move_forward", false)
	check(player.room == audio.t.habitat and audio._inside_now(), "the hero walked into the habitat, and sound and camera agree (room %s, at %s)" % [player.room, player.body.global_position])
	var indoors: Vector3 = player.body.global_position
	check(audio.cue == "", "no music on the way in")
	await seconds(audio.t.fade_s + 0.2)
	check(audio.inside == 1.0, "the crossfade finished inside")
	check(bus("Outside") < -40.0 and bus("Habitat") > -1.0, "inside: Outside down (%.0f dB), Habitat up (%.0f dB)" % [bus("Outside"), bus("Habitat")])
	check(audio.steps > 0 and audio.last_step.surface in ["in", "sand", "rock"], "steps know their surface")
	player.place(game.world.landmark("spawn").pos, 0.0)
	await seconds(audio.t.fade_s + 0.2)
	check(bus("Outside") > -1.0 and bus("Habitat") < -40.0, "back outside, the buses swap back")

	# music: rare cues on a clear bus of their own (skills/living-atmosphere)
	check(AudioServer.get_bus_index("Music") >= 0, "a Music bus exists")
	check(audio.cue == "first_step" and playing_music().size() == 1, "the first step outside plays first_step (%s)" % audio.cue)
	var first: Array = playing_music()
	audio._cue_end = -1e9  # as if the cue and the gap were long over
	player.place(indoors, 180.0)
	await seconds(0.5)
	player.place(game.world.landmark("spawn").pos, 0.0)
	await seconds(0.5)
	check(audio.cue == "" and playing_music() == first, "first_step plays once a session (%s)" % audio.cue)
	player.place(indoors, 180.0)
	await seconds(0.5)
	game.interactions.use(door)  # the hero closes the airlock behind them
	for i in 120:  # the hand reaches the handle first, then the door moves and its sound plays
		await frames(1)
		if audio.cue != "":
			break
	check(audio.cue == "airlock_sealed", "closing the airlock inside plays airlock_sealed (%s)" % audio.cue)
	var sealed: Array = playing_music().filter(func(q: Node) -> bool: return q not in first)
	check(not audio.music("discovery") and playing_music().size() == first.size() + 1, "a cue never starts over another")
	audio._cue_end = audio._time - 1.0
	check(not audio.music("discovery"), "nor within the gap after one ends")
	await seconds(audio._stream("music/airlock_sealed").get_length() / 0.8 + 0.5)
	check(sealed.size() == 1 and not is_instance_valid(sealed[0]), "a cue's player is freed when it has played")
	audio._cue_end = -1e9
	game._sky(game.SKIES.find("design.sunset"))
	await frames(1)
	check(audio.cue == "sunset", "the sky turning to sunset plays sunset (%s)" % audio.cue)
	audio._cue_end = -1e9
	game._sky(game.SKIES.find("design.sunset"))
	# a cue ends in audio._process(): after a heavy sky switch the next frame runs several physics steps first, and
	# frames(1) (one physics step) came back before any _process (flaky, 12 Nov)
	await process_frame
	await process_frame
	check(audio.cue == "", "once per change into sunset, not on every switch (%s)" % audio.cue)
	check(audio.music("discovery") and audio.cue == "discovery", "discovery plays when called")
	for q: AudioStreamPlayer in playing_music():
		check(q.bus == "Music", "music plays on the Music bus")
	# the greenhouse is a room too: inside it the sound is indoors, as the camera is (data/world.json rooms)
	var gh: Node3D = game.world.items["greenhouse"]
	player.place(gh.to_global(Vector3(0.0, 0.3, 0.0)), 0.0)
	await seconds(audio.t.fade_s + 0.2)
	check(player.room == "greenhouse" and audio.inside == 1.0, "in the greenhouse the sound is indoors (room %s, inside %.2f)" % [player.room, audio.inside])
	player.place(gh.to_global(Vector3(0.0, 0.3, -6.5)), 0.0)  # outside its door
	await frames(2)
	check(player.room == "" and not audio._inside_now(), "outside the greenhouse door the sound is outdoors")
	await names_and_files(player)
	await cues_and_beds(player, indoors)
	return true


## Every name anything asks for is in SOUNDS, and every file a name plays loads: a missing one fails here instead of
## playing nothing (the curtain, 13 Nov).
func names_and_files(player: Node3D) -> void:
	for sound: String in audio.SOUNDS:
		for step: String in audio.SOUNDS[sound]:
			var f := step.get_slice("@", 0)
			check(audio._stream(f) != null or audio._stream(f + "_out") != null, "sound '%s' plays %s, and it loads" % [sound, f])
	var asked: Array[String] = ["door_open", "door_close", "grab", "set_down", "pip_go", "pip_hello", "radio_pip"]
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if not it.kind in ["door", "spot"]:  # a door says open or close; a use spot says its row's `sound`
			asked.append(it.kind)
	asked.append_array(sounds_in(game.world.data))
	for s: String in asked:
		check(audio.SOUNDS.has(s), "'%s' is asked for and named in SOUNDS" % s)
	for c: String in audio.CUES:
		var m: AudioStream = audio._stream("music/" + c)
		check(m != null and not m.loop and m.get_length() > 3.0, "cue %s loads" % c)
	for b: String in audio.BEDS:
		for ph: String in audio.BEDS[b]:
			var m: AudioStream = audio._stream("music/" + ph)
			check(m != null and not m.loop and m.get_length() > 20.0, "bed phrase %s loads" % ph)
	check(audio._exert.playing and audio._exert.stream.loop, "the respirator loops under the breaths")
	var at: Vector3 = player.body.global_position
	audio.used("curtain", at)
	audio.used("drink", at)
	await frames(1)
	check(heard("curtain.ogg") and heard("pour.ogg") and not heard("sip.ogg"), "the curtain swishes, the pour starts")
	await seconds(2.0)
	check(heard("sip.ogg"), "and the sip comes at its time")


## Cues past the gap when forced, the dawn after a sleep, the first sample's discovery, the storm, and the beds.
func cues_and_beds(player: Node3D, indoors: Vector3) -> void:
	var at: Vector3 = player.body.global_position
	audio.stop_music()
	audio._cue_end = -1e9
	check(audio.music("quiet") and not audio.music("dawn"), "a cue waits for the one playing")
	var cut: AudioStreamPlayer = audio._cue_player
	check(audio.music("dawn", true) and audio.cue == "dawn", "force passes a playing cue and the gap")
	await seconds(audio.t.music.fade_s + 0.3)
	check(cut.volume_db < -50.0, "and the cue it cut fades out (%.0f dB)" % cut.volume_db)
	audio.stop_music()
	check(audio.cue == "" and not audio.music("quiet"), "stopped, the gap still counts")
	audio.wake()
	audio.used("door_open", at)
	check(audio.cue == "dawn", "after a sleep the next door opens on dawn, gap or not (%s)" % audio.cue)
	audio.stop_music()
	audio._cue_end = -1e9
	audio.used("door_open", at)
	check(audio.cue == "", "only that door (%s)" % audio.cue)
	audio.used("sample", at)
	check(audio.cue == "discovery", "the first rock sample of a session plays discovery (%s)" % audio.cue)
	audio.stop_music()
	audio._cue_end = -1e9
	audio.used("sample", at)
	check(audio.cue == "", "once a session (%s)" % audio.cue)
	audio.sky("design")
	audio.sky("design.storm")
	check(audio.cue == "storm", "the sky turning to storm plays storm (%s)" % audio.cue)
	audio.stop_music()
	audio._cue_end = -1e9

	# beds: outside on foot, a phrase when the rest is over; a cue starts over it and it ducks
	player.place(game.world.landmark("spawn").pos, 0.0)
	await seconds(audio.t.fade_s + 0.2)
	audio._bed_next = audio._time
	await process_frame
	await process_frame
	check(audio.bed_name.begins_with("bed_eva"), "outside, a bed phrase plays once its rest is over (%s)" % audio.bed_name)
	var bq: AudioStreamPlayer = audio._bed
	check(bq != null and bq.bus == "Music" and bq.playing, "on the Music bus")
	check(not audio.bed("eva"), "one phrase at a time")
	check(audio._bed_next > audio._time + float(audio.t.bed.rest_s[0]), "and a rest of minutes is booked after it")
	check(audio.music("discovery"), "a cue starts over a bed: a bed never blocks a cue")
	await seconds(audio.t.music.fade_s + 0.5)
	var ducked: float = float(audio.t.bed.db) - float(audio.t.bed.duck_db)
	check(absf(bq.volume_db - ducked) < 0.5, "the bed ducks under the cue (%.1f dB, want %.1f)" % [bq.volume_db, ducked])
	player.place(indoors, 180.0)
	await seconds(0.3)
	check(audio.bed_name == "", "going in lets the outside bed go")
	await seconds(float(audio.t.bed.fade_s) + 0.3)
	check(bq.volume_db < -50.0, "faded out (%.0f dB)" % bq.volume_db)
	audio._bed_next = audio._time
	audio.stop_music()
	audio._cue_end = -1e9
	await process_frame
	await process_frame
	check(audio.bed_name.begins_with("bed_hab"), "inside a room the habitat bed plays (%s)" % audio.bed_name)

	# a cutscene ducks the world, not the music
	audio.duck(true)
	await seconds(audio.t.fade_s + 0.2)
	check(absf(bus("Habitat") - float(audio.t.duck_db)) < 0.5 and bus("Music") > -1.0, "duck: the world down (%.1f dB), the music not" % bus("Habitat"))
	audio.duck(false)
	await seconds(audio.t.fade_s + 0.2)
	check(bus("Habitat") > -1.0, "and back up")


func heard(file: String) -> bool:
	return game.get_tree().get_nodes_in_group("one_shot").any(func(q: Node) -> bool:
		return is_instance_valid(q) and q.stream.resource_path.get_file() == file and q.playing)


## The sound names data/world.json asks for: every `sound` (a use spot's row) and the machines' `servo`.
func sounds_in(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if v is Dictionary:
		for k: Variant in v:
			if k in ["sound", "servo"] and v[k] is String:
				out.append(v[k])
			else:
				out.append_array(sounds_in(v[k]))
	elif v is Array:
		for e: Variant in v:
			out.append_array(sounds_in(e))
	return out


func playing_music() -> Array:
	return audio.get_children().filter(func(n: Node) -> bool:
		return n is AudioStreamPlayer and n.playing and n.stream.resource_path.contains("/music/"))
