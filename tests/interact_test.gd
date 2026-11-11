extends "res://addons/forge/test.gd"
## Every sandbox interaction does its one physical thing: godot --headless --path . -s tests/interact_test.gd

var game: Node3D
var box: Node3D


func _init() -> void:
	watchdog = 120.0


## Stands the hero a little in front of the first interactable of `kind`, facing it, and returns it.
func face(kind: String) -> Node3D:
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if it.kind == kind:
			var at: Vector3 = it.global_position
			var from := at + (Vector3(1, 0, 1).normalized() if kind != "rover" else Vector3(0, 0, 0))
			if kind == "rover":
				from = at + (at - it.thing.global_position) * Vector3(1, 0, 1) * 0.6
			var yaw := rad_to_deg(atan2(at.x - from.x, -(at.z - from.z)))
			game.place(Vector3(from.x, 0, from.z), yaw)
			return it
	check(false, "no %s interactable" % kind)
	return null


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	box = game.interactions
	var player: Node3D = game.player

	var door := face("door")
	await frames(3)
	check(box.target == door, "the door is the target in front of it (got %s)" % [box.target])
	var shut: float = door.thing.rotation.y
	game.interactions.interact()
	await frames(60)
	check(absf(door.thing.rotation.y - shut) > deg_to_rad(60), "the door swings open")

	var panel := face("panel")
	await frames(3)
	var flat: float = panel.thing.rotation.x
	box.interact()
	await frames(60)
	check(absf(panel.thing.rotation.x - flat) > deg_to_rad(5), "the panel tilts")

	var bag := face("bag")
	await frames(3)
	box.interact()
	await frames(2)
	check(box.carried != null and box.carried.is_in_group("carriable"), "a bag is carried")
	check(game.render_game_to_text().carry != "", "state says what is carried")
	var b: Node3D = box.carried
	box.interact()
	await frames(2)
	check(box.carried == null, "the bag is put down")
	check(absf(b.global_position.y - game.world.height_at(b.global_position.x, b.global_position.z)) < 0.05, "the bag rests on the ground")

	var rover := face("rover")
	await frames(3)
	check(box.target == rover, "the rover is the target at its hatch (got %s)" % [box.target])
	var start: Vector3 = rover.thing.global_position
	box.interact()
	await frames(2)
	check(player.vehicle == rover.thing, "the hero is in the rover")
	action(&"move_forward")
	await frames(240)
	action(&"move_forward", false)
	await frames(60)
	var moved: float = (rover.thing.global_position - start).length()
	check(moved > 1.0, "the rover drives (moved %.2f m)" % moved)
	box.interact()
	await frames(2)
	check(player.vehicle == null, "the hero gets out")
	var out: Vector3 = player.body.global_position
	check(out.distance_to(rover.thing.exit_point()) < 1.0, "the hero is at the rover's hatch")
	return true
