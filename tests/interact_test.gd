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
	await frames(3)
	var dust: Node3D = game.world.dust
	check(dust._streams.size() > 0, "the wheels threw dust while driving")
	check(dust._streams.values().all(func(st: Dictionary) -> bool: return not st.grit.emitting and not st.haze.emitting), "no new dust once the driver is out")

	# rocks (reality.json rover.climb): a small one under a wheel is rolled over, a tall one stops it smoothly
	var r: Node3D = rover.thing
	var climb: float = r.climb
	var small := await over_rock(r, 0.6 * climb, 17.0)
	check(small.passed, "the rover rolls over a %.2f m rock (got to x %.1f)" % [0.6 * climb, small.x])
	check(small.rock > 0.5 * climb, "a wheel climbs onto it (highest %.2f m)" % small.rock)
	check(small.tilt > 1.0, "the body tilts as a wheel climbs (%.1f deg)" % small.tilt)
	var big := await over_rock(r, 1.8 * climb, 19.0)
	check(not big.passed, "a %.2f m rock stops the rover (got to x %.1f)" % [1.8 * climb, big.x])
	check(big.blocked == "rock", "it stopped for the rock (%s)" % big.blocked)
	check(big.top > 0.9 * r.top, "it was at full speed before (%.2f m/s)" % big.top)
	check(big.drop < r.brake / 60.0 * 1.01, "it braked, no dead stop (largest drop %.3f m/s in a frame)" % big.drop)
	check(absf(r.v) < 0.01, "and stands still against it (%.2f m/s)" % r.v)
	return true


## Puts the rover on open ground heading east along z = 18 and a test rock `tall` metres over the ground 12 m
## ahead (room to reach top speed) at z `lane` (the left wheels' line is 17, the right's 19), then drives it forward for 10 s.
## Returns {passed: bool, x, rock: highest rock a wheel stood on, tilt: most pitch or roll, deg, top: fastest,
## drop: largest speed lost in one frame, blocked}.
func over_rock(r: Node3D, tall: float, lane: float) -> Dictionary:
	var world: Node3D = game.world
	var x0 := -22.0
	var at := Vector3(x0 + 12.0, 0.0, lane)
	var g: float = world.height_at(at.x, at.z)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = Vector3(0.6, 1.0, 0.6)
	body.add_child(col)
	body.collision_layer = 2 | 256  # a solid rock (world/rocks.gd ROCK)
	body.collision_mask = 0
	world.add_child(body)
	body.global_position = Vector3(at.x, g + tall - 0.5, at.z)
	r.add_collision_exception_with(body)
	r.yaw = -PI / 2.0
	r.v = 0.0
	r._apply(r._pose(Vector3(x0, 0.0, 18.0), r.yaw))
	await frames(2)
	var out := {"rock": 0.0, "tilt": 0.0, "top": 0.0, "drop": 0.0, "blocked": ""}
	var last := 0.0
	for i in 600:
		r.drive(Vector2(0, 1), false, 1.0 / 60.0)
		out.rock = maxf(out.rock, r.on_rock)
		var e: Vector3 = r.global_basis.get_euler()
		out.tilt = maxf(out.tilt, rad_to_deg(maxf(absf(e.x), absf(e.z))))
		out.top = maxf(out.top, r.v)
		out.drop = maxf(out.drop, last - r.v)
		if OS.has_environment("ROVER_DEBUG") and r.v < last - 0.03:
			print("frame %d v %.3f -> %.3f blocked %s x %.3f" % [i, last, r.v, r.blocked, r.global_position.x])
		if r.blocked != "":
			out.blocked = r.blocked
		last = r.v
		await frames(1)
	out.x = r.global_position.x
	out.passed = r.global_position.x > at.x + 3.0
	body.free()
	return out
