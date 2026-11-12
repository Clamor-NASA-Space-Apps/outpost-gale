extends "res://addons/forge/test.gd"
## The sound bed listens to the game (skills/living-atmosphere, Checks): godot --headless --path . -s tests/audio_test.gd

const KEYS := ["started", "inside", "buses", "breath", "gust", "steps", "lastStep", "music"]

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
	check(audio._in_habitat(), "the hero walked into the habitat (at %s)" % player.body.global_position)
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
	await frames(1)
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
	await frames(1)
	check(audio.cue == "", "once per change into sunset, not on every switch")
	check(audio.music("discovery") and audio.cue == "discovery", "discovery plays when called (no event calls it yet)")
	for q: AudioStreamPlayer in playing_music():
		check(q.bus == "Music", "music plays on the Music bus")
	return true


func playing_music() -> Array:
	return audio.get_children().filter(func(n: Node) -> bool:
		return n is AudioStreamPlayer and n.playing and n.stream.resource_path.contains("/music/"))
