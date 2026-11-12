extends "res://addons/forge/test.gd"
## The real hero walks into every building a person enters, through its door, and back out:
## godot --headless --path . --fixed-fps 60 -s tests/doors_test.gd
## Doors are opened through the interactions, as a player opens them. The walk is real input: forward from
## 7 m in front of the door until the hero is inside on the floor, then back toward the camera until it is out.

const ENTERABLE := ["hab1", "greenhouse", "shelter"]  # world.json items a person walks into
const START := 7.0  # m in front of the building's centre, along its front
const INSIDE := 1.5  # m from the centre that counts as inside


func _init() -> void:
	watchdog = 240.0


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var world: Node3D = game.get_node("World")
	var player: Node3D = game.get_node("Player")
	var box: Node = game.get_node("Interactions")
	for id: String in ENTERABLE:
		var item: Node3D = world.items[id]
		for it: Node in item.find_children("*", "", true, false):
			if it.is_in_group("interactable") and it.kind == "door" and not it.open:
				box.use(it)  # as the player opens it: one press
	await frames(int(60 * 0.2) + int(60 * float(game.tuning.interact.move_s)))
	for id: String in ENTERABLE:
		var item: Node3D = world.items[id]
		var front := -item.global_basis.z.normalized()  # a model's front faces -Z
		var c := item.global_position
		var start := c + front * START
		player.place(Vector3(start.x, world.height_at(start.x, start.z) + 0.05, start.z), rad_to_deg(atan2(-front.x, front.z)))
		await frames(5)
		var closest := await _walk(player, [&"move_forward"], c, 9.0, true)
		var s: Dictionary = player.state().player
		check(closest < INSIDE, "%s: the hero walks in through its door (closest %.2f m from the centre)" % [id, closest])
		check(s.onFloor and s.inside.is_empty(), "%s: inside, on the floor and in no wall (%s)" % [id, s.inside])
		var far := await _walk(player, [&"move_back"], c, 12.0, false)
		check(far > START - 1.0, "%s: and walks back out (%.2f m from the centre)" % [id, far])
	return true


## Holds `keys` for `seconds`; the closest (or farthest) the hero came to `c` across the ground.
func _walk(player: Node3D, keys: Array, c: Vector3, seconds: float, closest: bool) -> float:
	for k: StringName in keys:
		action(k, true)
	var best := INF if closest else 0.0
	for i in int(60 * seconds):
		await frames(1)
		var p: Vector3 = player.body.global_position
		var d := Vector2(p.x - c.x, p.z - c.z).length()
		best = minf(best, d) if closest else maxf(best, d)
	for k: StringName in keys:
		action(k, false)
	await frames(2)
	return best
