extends "res://addons/forge/test.gd"
## Settings > Screen > Watch: skip the tutorial, a cinematic, a sol start (godot --headless --path . --fixed-fps 60 -s tests/demo_test.gd)

func _init() -> void:
	watchdog = 600.0


func _press(game: Node3D, text: String) -> void:
	for b: Button in game.settings.find_children("*", "Button", true, false):
		if b.text == text:
			b.pressed.emit()
			return
	check(false, "a %s button" % text)


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	game.beats.start_opening()
	await frames(30)
	check(game.beats.sequence == "opening", "the opening runs")
	_press(game, "Skip the tutorial")
	await frames(3)
	check(game.beats.sequence == "" and game.player.allowed.is_empty() and not game.clock.pinned, "Skip ends the opening: the hero is free, the clock runs")
	_press(game, "Look around")
	await frames(5)
	check(game.cine.busy(), "Look around plays a shot")
	for i in 60 * 40:
		if not game.cine.busy():
			break
		await frames(1)
	check(not game.cine.busy(), "the shot ends and gives the camera back")
	_press(game, "Sol 4")
	await frames(5)
	check(game.beats.sequence == "sol4" and int(game.sim.sim.sol) == 4, "Sol 4 starts its beats on sol 4 (%s, sol %d)" % [game.beats.sequence, game.sim.sim.sol])
	return true
