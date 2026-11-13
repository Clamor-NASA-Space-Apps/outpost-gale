extends CanvasLayer
## Thumbs feed the same input actions as keys (skills/character-body): a VirtualJoystick to move, buttons to
## hurry, hop and use, and a look drag anywhere else. Shown on a touch screen, and from the first touch.
## Plain StyleBoxFlat from design.json colours until the HUD theme lands: setting `theme` on `root` swaps them.

const BUTTONS := [["hurry", "Hurry"], ["jump", "Hop"], ["interact", "Use"], ["lamp", "Lights"]]

var root: Control
var pad: Control  # the look area under everything else
var stick: VirtualJoystick
var look: Callable  # (right_deg, down_deg)
var deg_per_half := 0.0
var fingers := {}  # finger index -> its last position on the pad
var target := 0.0


func setup(tuning: Dictionary, colors: Dictionary, on_look: Callable) -> void:
	look = on_look
	deg_per_half = tuning.camera.touch_deg_per_half_window
	target = tuning.touch.target_px
	var size: float = tuning.touch.stick_px
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme(colors, target)
	add_child(root)
	pad = Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	# passes what it does not use on to the 3D view: with STOP it ate the mouse once a touch had shown it (or on any
	# touch-screen laptop), so a click never captured the cursor and a captured mouse never turned the view
	pad.mouse_filter = Control.MOUSE_FILTER_PASS
	pad.gui_input.connect(_on_pad)
	root.add_child(pad)
	stick = VirtualJoystick.new()
	stick.action_left = &"move_left"
	stick.action_right = &"move_right"
	stick.action_up = &"move_forward"
	stick.action_down = &"move_back"
	stick.joystick_size = size
	stick.tip_size = size / 2.0
	stick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC  # lands under the thumb, wherever it touches the area
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	# a target's width in from the edge clears Android's back swipe (30 dp, about 60 scene px)
	stick.offset_left = target
	stick.offset_right = target + size
	stick.offset_top = -target / 2.0 - size
	stick.offset_bottom = -target / 2.0
	root.add_child(stick)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_right = -target
	column.offset_bottom = -target / 2.0
	root.add_child(column)
	for b: Array in BUTTONS:
		var button := Button.new()
		button.name = b[0]
		button.text = b[1]
		button.custom_minimum_size = Vector2(target, target)
		button.focus_mode = Control.FOCUS_NONE  # a focused button would also take Space
		# action events, not Input.action_press(): that sets the state but skips every _input listener
		button.button_down.connect(_send.bind(StringName(b[0]), true))
		button.button_up.connect(_send.bind(StringName(b[0]), false))
		column.add_child(button)
	visible = DisplayServer.is_touchscreen_available()


func restyle(colors: Dictionary) -> void:
	root.theme = _theme(colors, target)


func _input(e: InputEvent) -> void:
	if not visible and e is InputEventScreenTouch:
		visible = true


func _send(action: StringName, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)


## Turns by each finger's own last position. Never `relative`: the web build measures it from whichever finger
## sat in the same place of the browser's list, so with a thumb on the stick a look swipe jumps half a screen.
func _on_pad(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			fingers[e.index] = e.position
		else:
			fingers.erase(e.index)
	elif e is InputEventScreenDrag and fingers.has(e.index):
		var d: Vector2 = e.position - fingers[e.index]
		fingers[e.index] = e.position
		var k := deg_per_half / (pad.size.x / 2.0)
		look.call(d.x * k, d.y * k)


func _theme(colors: Dictionary, corner: float) -> Theme:
	var th := Theme.new()
	var box := func(fill: String, alpha: float, edge: String) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(Color.html(colors[fill]), alpha)
		s.border_color = Color.html(colors[edge])
		s.set_border_width_all(2)
		s.set_corner_radius_all(int(corner))
		return s
	th.set_stylebox(&"normal", &"Button", box.call("surface", 0.55, "outline-variant"))
	th.set_stylebox(&"hover", &"Button", box.call("surface", 0.55, "outline-variant"))
	th.set_stylebox(&"pressed", &"Button", box.call("accent", 0.8, "accent"))
	th.set_color(&"font_color", &"Button", Color.html(colors["on-surface"]))
	th.set_color(&"font_pressed_color", &"Button", Color.html(colors["on-primary"]))
	th.set_stylebox(&"normal_joystick", &"VirtualJoystick", box.call("surface", 0.35, "outline-variant"))
	th.set_stylebox(&"pressed_joystick", &"VirtualJoystick", box.call("surface", 0.5, "accent"))
	th.set_stylebox(&"normal_tip", &"VirtualJoystick", box.call("on-surface", 0.6, "outline-variant"))
	th.set_stylebox(&"pressed_tip", &"VirtualJoystick", box.call("accent", 0.9, "accent"))
	return th
