extends "res://addons/forge/test.gd"
## The world's checks: godot --headless --path . -s tests/world_test.gd
## Collision on every solid, everything resting on the ground, a static sweep that finds a drawn face nothing
## stops (skills/world-collision), rocks off pads and paths, and every sky state switching with no errors and
## nothing of the state before left behind.


## Collects engine and script errors, so "restyles with no errors" is something a test can check.
class Errors extends Logger:
	var lines: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool,
			error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			lines.append("%s (%s:%d)" % [rationale if rationale else code, file, line])


func _init() -> void:
	watchdog = 60.0  # the sweep casts a few thousand shapes and the sky loop rebuilds the rig four times


func play() -> bool:
	var errors := Errors.new()
	OS.add_logger(errors)
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var world: Node3D = game.get_node("World")
	check(errors.lines.is_empty(), "the world built with errors: %s" % [errors.lines.slice(0, 3)])
	var solid: int = world.STATICS | world.THIN

	var statics: Array[Node3D] = []
	for it: Dictionary in world.data.items:
		var n: Node3D = world.items[it.id]
		var kind: String = world.data.kinds.get(it.prefab, "static")
		var bodies := n.find_children("*", "CollisionObject3D", true, false)
		if n is CollisionObject3D:
			bodies.append(n)
		if kind == "static":
			statics.append(n)
			check(bodies.size() > 0 and bodies.all(func(b: CollisionObject3D) -> bool: return b.collision_layer in [world.STATICS, world.THIN]),
				"%s: every body on layer 2 or 3 (%d bodies)" % [it.id, bodies.size()])
		else:
			check(Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(it.pos[0], it.pos[1])) < 0.01,
				"%s stays where world.json puts it, not at %s" % [it.id, n.global_position])
			check(n is AnimatableBody3D and n.collision_layer == (world.VEHICLES if kind == "vehicle" else world.CARRIABLES),
				"%s: a %s is one body on its own layer" % [it.id, kind])
		# resting: the lowest drawn point on the lowest ground under the footprint, sampled finer than the loader does
		var box: AABB = world.drawn(n)
		var low := INF
		for i in 11:
			for j in 11:
				low = minf(low, world.height_at(box.position.x + box.size.x * i / 10.0, box.position.z + box.size.z * j / 10.0))
		check(absf(box.position.y - low) < 0.05, "%s floats or sinks: lowest point %.2f m off the ground under it" % [it.id, box.position.y - low])

	for b: StaticBody3D in world.rocks.solids:
		check(b.collision_layer in [world.STATICS, world.THIN], "a solid rock off layers 2 and 3 at %s" % b.position)
	check(world.rocks.solids.size() > 0 and world.rocks.pebbles.size() > 0, "the scatter placed rocks and pebbles")

	var misses := _sweep(world, statics, solid)
	check(misses.is_empty(), "%d drawn faces nothing stops, first: %s" % [misses.size(), misses.slice(0, 5)])
	# the sweep proves itself: with one item's collision off it must find that item's faces
	var victim: Node3D = world.items[statics[0].name]
	var off := victim.find_children("*", "CollisionObject3D", true, false)
	var layers := off.map(func(b: CollisionObject3D) -> int: return b.collision_layer)
	for b: CollisionObject3D in off:
		b.collision_layer = 0
	await frames(1)
	check(_sweep(world, [victim], solid).size() > 0, "the sweep passed %s with its collision off: it tests nothing" % victim.name)
	for i in off.size():
		off[i].collision_layer = layers[i]

	_rocks_clear(world)
	world.puff(world.landmark("spawn").pos, 0.5)
	check(world.dust.puffs.any(func(e: GPUParticles3D) -> bool: return e.visible and e.emitting), "a puff shows after puff()")

	for i in game.SKIES.size():
		check(FileAccess.file_exists("res://%s.json" % game.SKIES[i]), "%s.json exists (node ../../tools/design-tokens.mjs)" % game.SKIES[i])
		errors.lines.clear()
		game._sky(i)
		await frames(2)
		check(errors.lines.is_empty(), "sky %s: errors %s" % [game.SKIES[i], errors.lines.slice(0, 3)])
		_no_leftovers(game, world, game.SKIES[i])
	game._sky(0)
	OS.remove_logger(errors)
	return true


## For every drawn face of every solid: cast a hero-sized capsule at it from outside, on the solid layers.
## A face nothing stops is a place the hero walks through what it sees.
func _sweep(world: Node3D, nodes: Array, mask: int) -> Array[String]:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = world.hero_width / 2.0
	cap.height = world.hero_height
	# nothing that moves reaches higher than the hero at the top of a hop, or the rover's roof (the reality
	# sheet), plus the tallest step it may stand on: a roof mast above that is drawn, never touched
	var rows := {}
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json")).rows:
		rows[r.id] = float(r.value)
	var top: float = maxf(rows["hero.height"] + rows["hero.jump.hop"], rows["rover.height"]) + rows["hero.step"]
	var out: Array[String] = []
	for n: Node3D in nodes:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var faces := mi.mesh.get_faces()
			var tris := faces.size() / 3
			for t in range(0, tris, maxi(1, tris / 80)):
				var a := mi.global_transform * faces[t * 3]
				var b := mi.global_transform * faces[t * 3 + 1]
				var c := mi.global_transform * faces[t * 3 + 2]
				var nrm := (c - a).cross(b - a)  # Godot's front faces wind clockwise
				if nrm.length() < 1e-6:
					continue
				nrm = nrm.normalized()
				var mid := (a + b + c) / 3.0
				# undersides face the ground, and buried faces and faces above `top` cannot be reached
				var ground: float = world.height_at(mid.x, mid.z)
				if nrm.y < -0.5 or mid.y < ground + 0.1 or mid.y > ground + top:
					continue
				var reach := cap.radius + absf(nrm.y) * (cap.height / 2.0 - cap.radius) + 0.3
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.collision_mask = mask
				q.transform = Transform3D(Basis(), mid + nrm * reach)
				# Jolt answers [1, 1] for a cast that starts inside a solid: such a start says nothing
				if space.intersect_shape(q, 1).size():
					continue
				q.motion = -nrm * (reach + 0.3)
				if space.cast_motion(q)[0] >= 1.0:
					out.append("%s/%s at %s" % [n.name, mi.name, mid.snappedf(0.1)])
	return out


## No rock on an item, a pad or a path.
func _rocks_clear(world: Node3D) -> void:
	var boxes: Array[AABB] = []
	for n: Node3D in world.items.values():
		boxes.append(world.drawn(n))
	var half: float = world.data.paths.width / 2.0
	var bad := 0
	# the rocks' own list: a headless MultiMesh reads back every transform as identity
	for spot: Transform3D in world.rocks.spots:
		var p := spot.origin
		var flat := Vector3(p.x, 0, p.z)
		if boxes.any(func(box: AABB) -> bool: return p.x > box.position.x and p.x < box.end.x and p.z > box.position.z and p.z < box.end.z):
			bad += 1
			continue
		for line: Array in world.data.paths.lines:
			for k in line.size() - 1:
				var on := Geometry3D.get_closest_point_to_segment(flat, Vector3(line[k][0], 0, line[k][1]), Vector3(line[k + 1][0], 0, line[k + 1][1]))
				if flat.distance_to(on) < half:
					bad += 1
	check(bad == 0, "%d rocks on an item, a pad or a path" % bad)


## After a sky switch: one light rig, one probe, lamps only where the design has them, every role material
## from the new design, and the dust that state asks for.
func _no_leftovers(game: Node3D, world: Node3D, sky: String) -> void:
	var design: Dictionary = game.design
	var rigs := game.get_children().filter(func(c: Node) -> bool: return c.has_meta("house_rig"))
	check(rigs.size() == 2, "%s: one environment and one sun, found %d rig nodes" % [sky, rigs.size()])
	check(world.find_children("*", "ReflectionProbe", true, false).size() == 1, "%s: one reflection probe" % sky)
	var lamps := world.get_tree().get_nodes_in_group("world_lamp").size()
	var want: int = world.data.items.filter(func(it: Dictionary) -> bool: return it.prefab in world.data.lamps).size() if design.lighting.has("lamp") else 0
	check(lamps == want, "%s: %d lamps lit, want %d" % [sky, lamps, want])
	var roles: Array = design.get("_roles", {}).values()
	var stale := 0
	for n: Node3D in world.items.values():
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m and design.materials.has(m.resource_name) and not m in roles:
					stale += 1
	check(stale == 0, "%s: %d surfaces still wear the last sky's materials" % [sky, stale])
	check(world.data.weather.has(design.name), "%s: data/world.json weather has a row named \"%s\"" % [sky, design.name])
	check(world.dust.front.emitting == bool(world.weather.front) and world.dust.devil.emitting == bool(world.weather.devil),
		"%s: the dust follows the weather row" % sky)
