extends "res://addons/forge/test.gd"
## The way into the game, as a person meets it (ui/boot.tscn, the main scene): the team's logo, then the start
## screen (ui/start.gd) with the hero and PIP alive on it as a loop of video over a still (no 3D of its own), then the
## sandbox once it is loaded and Start was pressed, with nothing of the start screen left beside it. Real keys throughout.
## With a morning saved (sandbox/save.gd) the menu leads with "Continue: Sol N", in focus; without one, or with a file
## of another version, it is the three rows it always was. tests/save_test.gd continues a game through it.

const Save := preload("res://sandbox/save.gd")


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	# left alone, the logo goes by itself in about 3 s and the menu is ready for a key
	var boot := await _boot()
	var start: Control = boot.start
	await frames(60)
	check(start.splash != null and start.splash.is_visible_in_tree(), "the team's logo is up first, and still up a second in")
	check(root.gui_get_focus_owner() == null, "no menu row is in focus under the logo")
	await frames(60 * 3)
	check(start.splash == null and root.gui_get_focus_owner() == start.rows[0], "the logo goes by itself within 4 s and Start mission is in focus")
	# the hero and PIP alive: a loop of video over the still, and no 3D scene of the start screen's own, ever
	var video: VideoStreamPlayer = start.video
	if check(video != null and video.is_playing() and video.loop and video.stream is VideoStreamTheora, "the loop plays over the still on a computer"):
		var frame := video.get_parent() as Control
		check(frame.get_index() == 1 and start.get_child(0) is TextureRect, "it lies on the still, under the menu")
		await frames(90)
		check(video.is_playing() and video.stream_position > 0.5 and frame.modulate.a == 1.0, "a second and a half on it has faded in and runs (%.1f s in)" % video.stream_position)
		check(frame.size.is_equal_approx(root.get_visible_rect().size), "and fills the screen (%s)" % frame.size)
		var s := await shape(SHAPES[1])
		check(video.size.x >= s.size.x - 1.0 and video.size.y >= s.size.y - 1.0 and is_equal_approx(video.size.aspect(), 16.0 / 9.0), "on a wide screen it covers it at 16:9 (%s in %s)" % [video.size, s.size])
		await shape(SHAPES[0])
	while boot._done.size() < boot._paths.size():
		await process_frame
	await frames(5)
	check(_theirs(null).is_empty(), "loaded, the start screen still has no camera, light, sky or viewport (%s)" % [_theirs(null)])

	# a morning saved: Continue leads the menu, names its sol and has the focus. The test's own file, never a player's
	Save.file = "user://save_test.json"
	Save.write({"version": Save.VERSION, "sol": 13, "sim": {}, "handbook": {}})
	boot = await _boot()
	start = boot.start
	_key(KEY_ENTER)
	while start.splash:
		await process_frame
	var saved: Array[Button] = start.rows
	check(saved.map(func(b: Button) -> String: return b.text) == ["Continue: Sol 13", "Start mission", "Credits", "Exit"], "with a checkpoint: Continue: Sol 13, Start mission, Credits, Exit")
	check(root.gui_get_focus_owner() == saved[0], "Continue is in focus first")
	for b in saved:
		check(b.size.y >= TARGET and root.get_visible_rect().encloses(b.get_global_rect()) and b.get_global_rect().position.x >= EDGE, "'%s' is a touch target on the screen (%s)" % [b.text, b.get_global_rect()])
	_key(KEY_DOWN)
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	_key(KEY_ESCAPE)
	check(not start.credits.visible and root.gui_get_focus_owner() == saved[2], "the credits close back on Credits, now the third row")
	# which game each row asks for; boot is not told, so none loads here
	for c: Dictionary in start.started.get_connections():
		start.started.disconnect(c.callable)
	saved[0].pressed.emit()
	check(start.resume == start.checkpoint and int(start.resume.sol) == 13 and saved[0].text == "Loading...", "Continue asks for the checkpoint's morning")
	saved[1].pressed.emit()
	check(start.resume.is_empty() and saved[1].text == "Loading...", "Start mission asks for Sol 1, whatever is saved")
	# a checkpoint this build cannot use is none: the menu is as it always was
	Save.write({"version": Save.VERSION + 1, "sol": 13, "sim": {}, "handbook": {}})
	boot = await _boot()
	check(boot.start.rows.size() == 3 and boot.start.rows[0].text == "Start mission" and boot.start.checkpoint.is_empty(), "a checkpoint of another version: no Continue row")
	DirAccess.remove_absolute(Save.file)
	Save.file = "-"

	# again from the top, in a hurry: a key skips the logo, and that key starts nothing
	boot = await _boot()
	start = boot.start
	await process_frame
	check(start.splash != null, "the logo is up first")
	check(_theirs(null).is_empty(), "the logo makes no camera, light, sky or viewport (%s)" % [_theirs(null)])
	start.loop = "res://ui/no_such_loop.ogv"  # a build without the video: the still alone, and the menu as ever
	_key(KEY_ENTER)
	for i in 30:
		if start.splash == null:
			break
		await process_frame
	check(start.splash == null, "a key skips the logo")
	check(not boot._go, "the key that skipped the logo did not start the game")
	var rows: Array[Button] = start.rows
	check(rows.size() == 3 and rows.all(func(b: Button) -> bool: return b.is_visible_in_tree()), "three rows on a native run")
	check(rows.map(func(b: Button) -> String: return b.text) == ["Start mission", "Credits", "Exit"], "Start mission, Credits, Exit")
	for b in rows:
		check(b.size.y >= TARGET, "'%s' is a touch target (%d px tall, wanted %d)" % [b.text, b.size.y, TARGET])
		check(root.get_visible_rect().encloses(b.get_global_rect()) and b.get_global_rect().position.x >= EDGE, "'%s' is on the screen, clear of the back swipe" % b.text)
	check(root.gui_get_focus_owner() == rows[0], "Start mission is in focus")
	check(start.video == null, "with no video file the still stays, alone")
	_key(KEY_DOWN)
	check(root.gui_get_focus_owner() == rows[1], "the down key moves the focus to Credits")
	_key(KEY_ENTER)
	check(start.credits.is_visible_in_tree() and root.gui_get_focus_owner() == start.back, "Enter opens the credits, Back in focus")
	check(start.back.size.y >= TARGET, "Back is a touch target")
	_key(KEY_ESCAPE)
	check(not start.credits.visible and root.gui_get_focus_owner() == rows[1], "Esc closes them, back on Credits")
	_key(KEY_UP)
	check(root.gui_get_focus_owner() == rows[0], "the up key moves the focus back to Start mission")
	# the game starts on Enter, at once or as soon as its loading is done
	var early: bool = boot._done.size() < boot._paths.size()
	_key(KEY_ENTER)
	check(boot._go, "Enter on Start mission asks for the game")
	if early:  # read at once: the loading may end in the very next frame, and boot goes with it
		check(rows[0].text == "Loading...", "pressed before the loading is done, the row says so")
	while current_scene == null or current_scene.get("beats") == null:
		await process_frame
	await process_frame
	var game: Node = current_scene
	check(not is_instance_valid(boot) and root.find_child("Start", true, false) == null, "nothing of the start screen is left in the tree")
	check(_theirs(game).is_empty(), "every camera, light, sky and viewport is the game's own (%s)" % [_theirs(game)])
	var lens := root.get_camera_3d()
	check(lens != null and game.is_ancestor_of(lens), "the window's camera is the game's")
	var skies := root.find_children("*", "WorldEnvironment", true, false)
	check(skies.size() == 1 and root.get_world_3d().environment == (skies[0] as WorldEnvironment).environment, "the window's one environment is the game's")
	return true


## Every camera, light, sky and viewport in the tree that is not `mine`'s (null: every one there is).
func _theirs(mine: Node) -> Array:
	var out := []
	for kind: String in ["Camera3D", "Light3D", "WorldEnvironment", "SubViewport"]:
		for n: Node in root.find_children("*", kind, true, false):
			if mine == null or not mine.is_ancestor_of(n):
				out.append(n.get_path())
	return out


## The main scene from the top; returns boot once its start screen is in the tree.
func _boot() -> Node:
	change_scene_to_file("res://ui/boot.tscn")
	await process_frame
	while current_scene == null or current_scene.get("start") == null or not current_scene.start.is_inside_tree():
		await process_frame
	return current_scene


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		_hold(code, down)


func _hold(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	send(e)
