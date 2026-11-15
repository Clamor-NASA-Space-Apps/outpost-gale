extends "res://addons/forge/test.gd"
## The hero's input (15 Nov playtest): godot --headless --fixed-fps 60 --path . -s tests/hero_input_test.gd
## Worn out (player.weak, the rules' `weak`): from tuning.json hero.weak.no_hurry up the hurry lets go and cannot be
## set, and the walk slows to hero.weak.walk of the sheet's walk at 1. A move key held while another window takes the
## keyboard for a moment (the engine lets go of every key then, and a held key only repeats): the hero walks on at
## the key's first repeat, and stops when the key is let go. The cursor's part needs a display (mouse_mode never
## changes headless).

var player: Node3D


func _init() -> void:
	watchdog = 60.0


func _key(code: Key, on: bool, echo := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = on
	e.echo = echo
	send(e)


func play() -> bool:
	var world := Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	world.add_child(ground)
	player = load("res://player/player.gd").new()
	player.name = "Player"
	world.add_child(player)
	await frames(3)
	player.place(Vector3.ZERO, 0.0)
	await frames(30)
	var walk: float = player.walk
	var w: Dictionary = player.tuning.hero.weak

	_key(KEY_W, true)
	await frames(90)
	check(absf(player.moved - walk) < 0.05, "fresh, W walks at the sheet's walk (%.2f of %.2f m/s)" % [player.moved, walk])
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	await frames(120)
	check(player.hurrying and player.moved > walk * 1.2, "fresh, Shift hurries (%.2f m/s)" % player.moved)
	player.weak = float(w.no_hurry) + 0.1
	await frames(120)
	var slow: float = walk * lerpf(1.0, float(w.walk), player.weak)
	check(not player.hurrying and absf(player.moved - slow) < 0.05, "worn out: the hurry lets go and the walk slows (%.2f m/s, wants %.2f)" % [player.moved, slow])
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	await frames(30)
	check(not player.hurrying, "and Shift sets no hurry")
	player.weak = 1.0
	await frames(90)
	check(absf(player.moved - walk * float(w.walk)) < 0.05, "on the edge the walk is %.1f of itself (%.2f m/s)" % [float(w.walk), player.moved])
	player.weak = 0.0
	await frames(90)
	check(absf(player.moved - walk) < 0.05, "well again, the walk is back (%.2f m/s)" % player.moved)

	# another window takes the keyboard: the engine lets go of every action (Input.release_pressed_events(), which
	# does this for each pressed one) and tells the tree; W is still down under the finger
	Input.action_release(&"move_forward")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(180)  # the sheet's braking takes over a second from a walk
	check(player.moved < 0.05, "the keyboard gone, the hero stands (%.2f m/s)" % player.moved)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(KEY_W, true, true)  # the held key repeats
	await frames(90)
	check(absf(player.moved - walk) < 0.05, "back, the held key's first repeat walks the hero on (%.2f m/s)" % player.moved)
	_key(KEY_W, false)
	await frames(180)
	check(player.moved < 0.05 and not Input.is_action_pressed(&"move_forward"), "and letting go stops it: no stuck key (%.2f m/s)" % player.moved)
	# a repeat with nothing to mend presses nothing twice
	_key(KEY_W, true)
	_key(KEY_W, true, true)
	await frames(60)
	_key(KEY_W, false)
	await frames(180)
	check(player.moved < 0.05, "a held key's repeats while it already counts change nothing (%.2f m/s)" % player.moved)
	world.queue_free()
	return true
