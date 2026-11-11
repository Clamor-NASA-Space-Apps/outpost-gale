extends "res://addons/forge/test.gd"
## The sandbox's headless checks: godot --headless --path . -s tests/run.gd

# What render_game_to_text() may hold. A meter, a resource or a clock here breaks hard rule 1 before 14 Nov.
const ALLOWED := ["player", "cam", "heroScreen", "interaction", "carry", "vehicle", "sky", "quality", "fps", "view"]


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var world: Node3D = game.get_node("World")
	# one height source: what the hero stands on is what height_at() says
	var space := game.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := 0.0
	for i in 200:
		var x := rng.randf_range(-195, 195)
		var z := rng.randf_range(-195, 195)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 50, z), Vector3(x, -50, z), 1)
		var hit := space.intersect_ray(q)
		if not check(hit.size() > 0, "no ground under %.0f, %.0f" % [x, z]):
			continue
		worst = maxf(worst, absf(hit.position.y - world.height_at(x, z)))
	# HeightMapShape3D splits each 2 m cell into two triangles, height_at() blends four corners
	check(worst < 0.06, "ground collision and height_at() differ by %.3f m" % worst)
	var state: Dictionary = game.render_game_to_text()
	for k: String in state:
		check(k in ALLOWED, "render_game_to_text() has '%s': no game state before 14 Nov" % k)
	check(world.items.size() == world.data.items.size(), "every world.json item is placed")
	return true
