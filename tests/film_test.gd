extends "res://addons/forge/test.gd"
## The film switch (P, or Settings, Demo): the whole HUD layer goes for a screen recording, and comes back.


func play() -> bool:
	var game: Node = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var layer: CanvasLayer = game.fps_label.get_parent()
	check(layer.visible, "the HUD shows at the start")
	action(&"film", true)
	action(&"film", false)
	await frames(2)
	await process_frame
	check(not layer.visible and game.film, "P hides the HUD layer")
	action(&"film", true)
	action(&"film", false)
	await frames(2)
	await process_frame
	check(layer.visible and not game.film, "P again brings it back")
	game.set_film(true)
	await frames(2)
	await process_frame
	check(not layer.visible, "the Demo button's call hides it")
	return true
