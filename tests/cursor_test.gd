extends "res://addons/forge/test.gd"
## When the mouse cursor is captured: xvfb-run -a godot --path . -s tests/cursor_test.gd --fixed-fps 60
## (not --headless: there Input.mouse_mode never changes). Only a left click that reaches the 3D view captures it;
## the wheel, another button, a touch, the gear, the settings screen and the cover never do; Esc, the settings
## screen, the cover and a lost window focus give it back (13 Nov playtest: "mouse cursor disappears randomly").

const VISIBLE := Input.MOUSE_MODE_VISIBLE
const CAPTURED := Input.MOUSE_MODE_CAPTURED

var game: Node3D


func _init() -> void:
	watchdog = 120.0


func settle() -> void:
	# by the clock, not by frames: the cover fades over 0.25 s, and with the render loop off a frame takes 0.3 ms here
	# (two room probes made the warm-up 800 frames, past a 600-frame budget, in 0.27 s)
	var end := Time.get_ticks_msec() + 10000
	while game.busy():
		if Time.get_ticks_msec() > end:
			check(false, "the cover came down")
			return
		await process_frame


func press(button: MouseButton, pos: Vector2) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.position = root.get_final_transform() * pos
		e.pressed = down
		send(e)


func mode(want: Input.MouseMode, what: String) -> void:
	var names := {VISIBLE: "shown", CAPTURED: "captured"}
	check(Input.mouse_mode == want, "%s: the cursor should be %s, it is %s" % [what, names[want], names.get(Input.mouse_mode, Input.mouse_mode)])


func play() -> bool:
	if DisplayServer.get_name() == "headless":
		check(false, "run under xvfb-run, not --headless: the mouse mode never changes headless")
		return true
	RenderingServer.render_loop_enabled = false  # nothing here needs a picture, and llvmpipe drew a frame a second
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	await settle()
	var s: CanvasLayer = game.settings
	var world := root.get_visible_rect().get_center()
	mode(VISIBLE, "at start")
	for b: MouseButton in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		press(b, world)
		await frames(1)
		mode(VISIBLE, "mouse button %d over the world (a touchpad scroll is wheel presses)" % b)
	tap(world)
	await frames(1)
	mode(VISIBLE, "a touch on the world")
	press(MOUSE_BUTTON_LEFT, s.gear.get_global_rect().get_center())
	await frames(1)
	check(s.is_open(), "the gear opens the settings")
	mode(VISIBLE, "a click on the gear")
	press(MOUSE_BUTTON_LEFT, s.panel.get_global_rect().get_center())
	press(MOUSE_BUTTON_LEFT, s.panel.get_global_rect().position + Vector2(4, 4))
	press(MOUSE_BUTTON_LEFT, Vector2(4, root.get_visible_rect().size.y - 4))  # the shade beside the panel
	await frames(1)
	mode(VISIBLE, "clicks on the settings screen")
	s.close()
	await settle()
	press(MOUSE_BUTTON_LEFT, world)
	await frames(1)
	mode(CAPTURED, "a left click on the world")
	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(s.is_open(), "Esc opens the settings")
	mode(VISIBLE, "Esc")
	action(&"settings")
	await frames(1)
	action(&"settings", false)
	await settle()
	mode(VISIBLE, "the settings closed again, before a click")
	press(MOUSE_BUTTON_LEFT, world)
	await frames(1)
	mode(CAPTURED, "a left click on the world again")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(1)
	mode(VISIBLE, "the window lost focus")
	press(MOUSE_BUTTON_LEFT, world)
	await frames(1)
	mode(CAPTURED, "a click back in the window")
	game.set_graphics(game.quality, {})
	check(game.busy(), "a graphics change puts the cover up")
	mode(VISIBLE, "the cover went up")
	press(MOUSE_BUTTON_LEFT, world)
	await frames(1)
	mode(VISIBLE, "a click on the cover")
	await settle()
	press(MOUSE_BUTTON_LEFT, world)
	await frames(1)
	mode(CAPTURED, "a click once the cover is down")
	# the map over the play view: the cursor shows, a click on the world beside it never hides it, and M gives the
	# look back (14 Nov playtest: the cursor hidden over the map and Settings)
	action(&"map")
	await frames(1)
	action(&"map", false)
	await frames(2)
	check(game.hud.map_open(), "M opens the map")
	mode(VISIBLE, "the map open")
	press(MOUSE_BUTTON_LEFT, Vector2(4, 4))
	await frames(2)
	mode(VISIBLE, "a click while the map is open")
	action(&"map")
	await frames(1)
	action(&"map", false)
	await frames(2)
	check(not game.hud.map_open(), "M closes it")
	Input.mouse_mode = VISIBLE
	game.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames(2)
	return true
