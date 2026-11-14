extends "res://addons/forge/test.gd"
## The way into the game, as a person meets it (ui/boot.tscn, the main scene): the team's logo, then the start
## screen (ui/start.gd), then the sandbox once it is loaded and Start was pressed. Real keys throughout.


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

	# again from the top, in a hurry: a key skips the logo, and that key starts nothing
	boot = await _boot()
	start = boot.start
	await process_frame
	check(start.splash != null, "the logo is up first")
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
	_key(KEY_ENTER)
	check(boot._go, "Enter on Start mission asks for the game")
	if early:  # read at once: the loading may end in the very next frame, and boot goes with it
		check(rows[0].text == "Loading...", "pressed before the loading is done, the row says so")
	while current_scene == null or current_scene.get("beats") == null:
		await process_frame
	await process_frame
	check(not is_instance_valid(boot) and root.find_child("Start", true, false) == null, "nothing of the start screen is left in the tree")
	return true


## The main scene from the top; returns boot once its start screen is in the tree.
func _boot() -> Node:
	change_scene_to_file("res://ui/boot.tscn")
	await process_frame
	while current_scene == null or current_scene.get("start") == null or not current_scene.start.is_inside_tree():
		await process_frame
	return current_scene


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = down
		send(e)
