extends "res://addons/forge/test.gd"
## The way into the game, as a person meets it (ui/boot.tscn, the main scene): the team's logo, then the start
## screen (ui/start.gd) with the hero and PIP alive on it (ui/start_stage.gd), then the sandbox once it is loaded and
## Start was pressed, with nothing of the start screen left beside it. Real keys throughout.


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
	# the still first; once all is in memory the same scene alive takes its place
	check(start.stage != null or start.live.modulate.a == 0.0, "the still shows until the live scene is there")
	while boot._done.size() < boot._paths.size():
		await process_frame
	await frames(90)
	var hero: Node3D = start.stage.hero if start.stage else null
	if check(hero != null and start.live.texture == start.stage.get_texture() and start.live.modulate.a == 1.0, "loaded, the live scene has faded in over the still"):
		check(hero.gait == "idle" and hero.on_floor, "the hero stands on the stage's ground (%s)" % hero.gait)
		var at: Vector3 = hero.body.global_position
		var pose: Transform3D = hero.model.skeleton.get_bone_global_pose(hero.model.skeleton.find_bone("spine_03"))
		_hold(KEY_W, true)
		await frames(45)
		_hold(KEY_W, false)
		check(hero.body.global_position.distance_to(at) < 0.01, "a move key on the menu moves nobody (%.2f m)" % hero.body.global_position.distance_to(at))
		check(not pose.is_equal_approx(hero.model.skeleton.get_bone_global_pose(hero.model.skeleton.find_bone("spine_03"))), "the hero is alive: its chest moved in 45 frames")
		check(root.get_camera_3d() == null and root.find_children("*", "WorldEnvironment", true, false).all(func(n: Node) -> bool: return start.stage.is_ancestor_of(n)), "its camera and sky are its own, not the window's")

	# again from the top, in a hurry: a key skips the logo, and that key starts nothing
	boot = await _boot()
	start = boot.start
	await process_frame
	check(start.splash != null, "the logo is up first")
	check(_theirs(boot).is_empty(), "the first start screen took its scene with it (%s)" % [_theirs(boot)])
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
	while not early and start.stage == null:
		await process_frame  # all loaded: the live scene is up before the press, so the start has one to clear away
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


## Every camera, light, sky and viewport in the tree that is not `mine`'s.
func _theirs(mine: Node) -> Array:
	var out := []
	for kind: String in ["Camera3D", "Light3D", "WorldEnvironment", "SubViewport"]:
		for n: Node in root.find_children("*", kind, true, false):
			if not mine.is_ancestor_of(n):
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
