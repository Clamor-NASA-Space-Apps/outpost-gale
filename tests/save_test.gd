extends "res://addons/forge/test.gd"
## The morning checkpoint and Continue (sandbox/save.gd): godot --headless --path . --fixed-fps 60 -s tests/save_test.gd
## A game jumped to Sol 3 as Settings, Demo does it, with a choice made, handbook pages found and learned and a
## decision logged, sleeps a night: the file is written as Sol 4's beats start, and only then. A fresh game through
## ui/boot.tscn and its Continue row then starts on that morning: Sol 4's beats (no opening), the rules, the handbook
## and the root's flags as saved, the hero in HAB 1 on the airlock start, the first beat waiting behind the cover and
## playing once it lifts. A lost mission writes nothing, and a file that cannot be used is ignored without an error.
## It writes user://save_test.json only, never a player's file.

const Save := preload("res://sandbox/save.gd")
const Sim := preload("res://sim/sim.gd")
const FILE := "user://save_test.json"


## Every error the engine reports, its own included (the base counts script and shader errors only).
class Any extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1


func _init() -> void:
	watchdog = 900.0


func play() -> bool:
	check(Save._path() == "-" and Save.read().is_empty(), "a test run has no save file of its own accord")
	Save.file = FILE
	DirAccess.remove_absolute(FILE)
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	# Sol 3 the way Settings, Demo starts it, then a day's doings
	game.beats.skip()
	game.sim.skip_sols(3 - int(game.sim.sim.sol))
	game.beats.start_sol(3)
	game.sim.apply("greenhouse_on")
	game.hud.unlock_page("thin_air")
	game.hud.unlock_page("solar_wings")
	game.hud.handbook.learned(["garden"])
	game.hud.open_handbook("thin_air")  # read: only solar_wings and garden are left unread
	game.hud.handbook.close()
	game.hud.log_decision("Power or plants?", "Greenhouse on")
	game.lamp_hinted = true
	game.warned["3:storm.dark"] = true
	game.trip_km = 4.2
	game.clock.storm_on = true
	# a mission lost keeps the last good morning: nothing is written
	game.lost = true
	game.checkpoint(4)
	check(not FileAccess.file_exists(FILE), "a lost mission writes no checkpoint")
	game.lost = false
	# 22:00, then a night's sleep: the checkpoint is written as the next sol's beats start
	game.clock.set_hour(22.0)
	game.clock.refresh()
	game._sync_rules()
	await frames(30)
	check(not FileAccess.file_exists(FILE), "nothing is written before a morning")
	game.cine.sleep(&"night")
	for i in 60 * 120:
		if game.beats.sequence == "sol4":
			break
		await physics_frame
	check(game.beats.sequence == "sol4" and FileAccess.file_exists(FILE), "a night's sleep starts Sol 4 and writes the checkpoint (%s)" % game.beats.sequence)
	var saved := Save.read()
	if not check(not saved.is_empty() and int(saved.sol) == 4 and int(saved.version) == Save.VERSION, "the file reads back: Sol 4, this version (%s)" % [saved.keys()]):
		return true
	var rules := Sim.new()
	rules.load(saved.sim)
	var state := rules.state()
	check(state.sol == 4 and absf(rules.local_hour() - 6.5) < 0.3 and rules.knobs.greenhouse == true, "it holds the rules on the morning of Sol 4, the greenhouse on (sol %d, %.2f h)" % [state.sol, rules.local_hour()])
	check(saved.handbook.decisions == [["Power or plants?", "Greenhouse on"]] and "garden" in saved.handbook.learned and saved.handbook.seen == ["thin_air"], "and the handbook (%s)" % [saved.handbook])
	var text := FileAccess.get_file_as_string(FILE)
	while game.cine.busy():
		await process_frame
	await frames(30)
	check(FileAccess.get_file_as_string(FILE) == text, "one write: the file does not change as the morning goes on")
	game.queue_free()
	await frames(3)

	# a new launch: the start screen offers the morning, and Enter takes it
	change_scene_to_file("res://ui/boot.tscn")
	while current_scene == null or current_scene.get("start") == null or not current_scene.start.is_inside_tree():
		await process_frame
	var start: Control = current_scene.start
	_key(KEY_SPACE)
	while start.splash:
		await process_frame
	check(start.rows[0].text == "Continue: Sol 4" and root.gui_get_focus_owner() == start.rows[0], "the start screen offers 'Continue: Sol 4' first, in focus (%s)" % start.rows[0].text)
	_key(KEY_ENTER)
	while current_scene == null or current_scene.get("beats") == null:
		await process_frame
	await process_frame
	game = current_scene
	var beats: Node = game.beats
	var player: Node3D = game.player
	check(game.cover.visible, "the loading cover is up")
	check(beats.sequence == "sol4" and beats.sol_key == 4 and beats.beat.get("id", "") == "wake", "Sol 4's beats run, not the opening (%s, %s)" % [beats.sequence, beats.beat.get("id", "")])
	check(game.sim.sim.state() == state, "the rules are the saved ones: %s, saved %s" % [game.sim.sim.state(), state])
	check(game.sim.sim.top_causes(3) == rules.top_causes(3) and not rules.top_causes(3).is_empty(), "with their cause log")
	check(JSON.stringify(game.hud.handbook.save()) == JSON.stringify(saved.handbook), "the handbook has the same pages and decisions (%s)" % [game.hud.handbook.save()])
	check(game.hud.handbook.unread() == 2 and game.hud.book_mark.visible, "and its '!' for the two pages not read yet (%d)" % game.hud.handbook.unread())
	check(game.lamp_hinted and game.warned.has("3:storm.dark") and is_equal_approx(game.trip_km, 4.2) and game.clock.storm_on, "the root's flags are back (%s, %.1f km)" % [game.warned, game.trip_km])
	check(absf(game.clock.hour() - rules.local_hour()) < 0.01 and not game.clock.pinned, "the sky is at the rules' hour (%.2f, %.2f)" % [game.clock.hour(), rules.local_hour()])
	check(game.hud.snapshot().sol == 4, "the HUD says Sol 4 (%s)" % game.hud.snapshot().sol)
	while game.cover.visible:
		await physics_frame
	# the first playable frame, as the opening's (tests/opening_live_test.gd)
	var hab: Node3D = game.world.items.hab1
	var s: Dictionary = beats.data.starts.airlock
	var spot: Vector3 = hab.to_global(Vector3(s.at[0], s.at[1], s.at[2]))
	var at: Vector3 = player.body.global_position
	check(beats.beat.get("id", "") == "wake" and beats._t < 0.1, "the beats waited behind the cover (%s, %.1f s in)" % [beats.beat.get("id", ""), beats._t])
	check(Vector2(at.x - spot.x, at.z - spot.z).length() < 0.1 and player.room == "hab1", "the hero stands in HAB 1 on the airlock start (%.2f m off, in '%s')" % [Vector2(at.x - spot.x, at.z - spot.z).length(), player.room])
	await frames(60)
	at = player.body.global_position
	check(Vector2(at.x - spot.x, at.z - spot.z).length() < 0.1 and absf(at.y - spot.y) < 0.4, "and stays there, on the deck (%s, the spot %s)" % [at, spot])
	check(beats.beat.get("id", "") == "wake" and beats._t > 0.5, "the cover gone, Sol 4's first beat plays (%s, %.1f s in)" % [beats.beat.get("id", ""), beats._t])
	var tasks: Array = game.hud.snapshot().tasks
	check(beats.tasks()[0] == {"label_id": "task.s4_call", "state": "now"} and tasks.size() == beats.tasks().size() and tasks[0][1] == "now", "with its tasks on Today's list (%s)" % [tasks])
	check(game.sim.sim.sol == 4 and game.sim.sim.hour > rules.hour and not game.lost, "and the rules run on from the saved hour (%.3f, saved %.3f)" % [game.sim.sim.hour, rules.hour])
	check(FileAccess.get_file_as_string(FILE) == text, "Continue itself writes nothing")

	# a file that cannot be used is no checkpoint, and no error either
	var any := Any.new()
	OS.add_logger(any)
	var file: Dictionary = JSON.parse_string(text)
	for bad: Array in [["broken JSON", text.left(text.length() / 2)], ["an empty file", ""], ["no dictionary", "[1, 2]"],
			["another version", JSON.stringify(file.merged({"version": Save.VERSION + 1}, true))],
			["a sol the story does not have", JSON.stringify(file.merged({"sol": 7}, true))],
			["no rules", JSON.stringify(file.merged({"sim": {}}, true))]]:
		FileAccess.open(FILE, FileAccess.WRITE).store_string(bad[1])
		check(Save.read().is_empty(), "%s is ignored" % bad[0])
	check(any.count == 0, "without an error (%d)" % any.count)
	OS.remove_logger(any)
	FileAccess.open(FILE, FileAccess.WRITE).store_string(text)
	check(not Save.read().is_empty(), "the good file still reads")
	DirAccess.remove_absolute(FILE)
	check(Save.read().is_empty(), "and no file is no checkpoint")
	return true


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		send(e)
