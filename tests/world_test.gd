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
	watchdog = 90.0  # the sweep casts a few thousand shapes and the sky loop rebuilds the rig four times


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
			# plus the rock bit on a low one, a wheel's to roll onto (world.gd _solidify())
			check(bodies.size() > 0 and bodies.all(func(b: CollisionObject3D) -> bool: return b.collision_layer & ~world.Rocks.ROCK in [world.STATICS, world.THIN]),
				"%s: every body on layer 2 or 3 (%d bodies)" % [it.id, bodies.size()])
			if it.prefab == "build_pad":
				check(bodies.all(func(b: CollisionObject3D) -> bool: return b.collision_layer & world.Rocks.ROCK), "%s: a rover wheel rolls onto it" % it.id)
		else:
			check(Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(it.pos[0], it.pos[1])) < 0.01,
				"%s stays where world.json puts it, not at %s" % [it.id, n.global_position])
			check(bodies.size() == 1, "%s: a mover holds no body but its own (the import's stay behind when it moves)" % it.id)
			check(n is AnimatableBody3D and n.collision_layer == (world.VEHICLES if kind == "vehicle" else world.CARRIABLES),
				"%s: a %s is one body on its own layer" % [it.id, kind])
		# resting (world.rest()): the drawn points near the underside, measured along the item's own up, are all in
		# the ground right under them, the shallowest by the prefab's sink row; a vehicle's just touch
		var up := n.global_basis.y.normalized()
		var pts: Array[Vector3] = []
		var base := INF
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh:
				for v in mi.mesh.get_faces():
					var p: Vector3 = mi.global_transform * v
					pts.append(p)
					base = minf(base, (p - n.global_position).dot(up))
		var mark := n.find_child("ground_level", true, false) as Node3D
		if mark:  # a bedded model rests on its ground line, its skirt in the dust (world.rest())
			base = (mark.global_position - n.global_position).dot(up)
		var sink: Dictionary = world.data.sink
		# a vehicle sits on its wheels only by its own sink row, set by its driver (sandbox/rover.gd)
		var want: float = 0.0 if kind == "vehicle" and not sink.has(it.prefab) else world.sheet_values[sink.get(it.prefab, sink.default)]
		var top := -INF  # the highest foot over the ground under it, each dropped onto the underside's plane
		var low := INF
		for p in pts:
			var h := (p - n.global_position).dot(up) - base
			if h < float(sink.support):
				var u := p - up * h
				top = maxf(top, u.y - world.height_at(u.x, u.z))
				low = minf(low, u.y - world.height_at(u.x, u.z))
		check(absf(top + want) < 0.02, "%s floats or sinks: its highest foot is %.3f m off the ground under it, not %.3f" % [it.id, top, -want])
		# a slab laid level needs level ground under all of it: a neighbour graded later can take back an edge of its
		# footprint (build pad 1's took the storm shelter's west wall, and the ground came up through its floor, 14 Nov)
		if it.prefab in world.data.graded.prefabs:
			check(top - low < 0.03, "%s: the ground under its footprint is not level (%.3f m between its feet)" % [it.id, top - low])

	# the base works on its own (world/machines.gd): panels turn, the dish nods, the telltale leans, lights flash
	# no faster than WCAG 2.3.1 allows, and every wind listener reads one gust between 0 and 1
	var m: Node = world.machines
	var was: Dictionary = m.state()
	game._sky(game.SKIES.find("design.night"))  # no sun: the trackers turn to lie flat
	for i in 400:
		m._process(0.05)
	var now: Dictionary = m.state()
	# rows that backtrack never shade the next row, at any sun: a chord's shadow across the row, L cos(sun - tilt),
	# fits in the pitch seen from the sun, P cos(sun) (gcr = L / P; machines.gd _track)
	for sky: String in ["design", "design.sunset"]:
		game._sky(game.SKIES.find(sky))
		for i in 800:
			m._process(0.05)
		var rows := 0
		for p: Dictionary in m.panels:
			if p.gcr > 0.0:
				var d: Vector3 = (p.node as Node3D).get_parent().global_basis.inverse() * m._sun
				var sun := atan2(d.z, d.y)
				var tilt: float = p.at
				rows += 1
				check(cos(sun - tilt) * p.gcr <= cos(sun) + 1e-3 or absf(tilt) >= p.lim - 1e-3,
					"%s: a %s row at %.1f deg shades the next (sun %.1f deg across it)" % [sky, (p.node as Node3D).get_parent().get_parent().name, rad_to_deg(tilt), rad_to_deg(sun)])
		check(rows >= 6, "the wing rows backtrack (%d rows with a ground coverage ratio)" % rows)
	game._sky(0)
	check(now.panels != was.panels and now.dish != was.dish, "the panels and the dish move on their own (%s, %s)" % [now.panels.slice(0, 2), now.dish])
	check(now.tell.size() == 1 and now.tell[0] >= 0.0, "the telltale leans downwind (%s deg)" % [now.tell])
	check(float(world.data.blink.hz) * maxf(float(world.data.blink.duty), 1.0) <= 3.0, "status lights flash at most 3 times a second")
	check(world.gust() >= 0.0 and world.gust() <= 1.0, "gust() is between 0 and 1 (%.2f)" % world.gust())

	for b: StaticBody3D in world.rocks.solids:
		# layer 2 or 3 for the hero and camera, plus the rock bit a wheel rolls onto (world/rocks.gd ROCK)
		check(b.collision_layer & ~world.Rocks.ROCK in [world.STATICS, world.THIN] and b.collision_layer & world.Rocks.ROCK, "a solid rock off layers 2 and 3, or not a rock to a wheel, at %s" % b.position)
	check(world.rocks.solids.size() > 0 and world.rocks.pebbles.size() > 0, "the scatter placed rocks and pebbles")

	# a build pad's top clears the ground everywhere under it (the ground came up through a corner of one laid on a
	# slope, 13 Nov playtest), and stands no higher than a step, so the hero walks on and a wheel rolls on
	for it: Dictionary in world.data.items:
		if it.prefab == "build_pad":
			var pad: Node3D = world.items[it.id]
			var top: float = pad.global_position.y + 0.15  # forge/pad_build.py T
			var lo := INF
			var hi := -INF
			for i in 25:
				for j in 25:
					var p: Vector3 = pad.global_transform * Vector3(-2.95 + i * 0.245, 0.0, -2.95 + j * 0.245)
					var over: float = top - world.height_at(p.x, p.z)
					lo = minf(lo, over)
					hi = maxf(hi, over)
			check(lo > 0.03 and hi <= world.hero_step, "%s: its top is 3 cm to a step over the ground under it (%.2f to %.2f m)" % [it.id, lo, hi])

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
	_cables_clear(world)
	await _charge_lead(world)
	await _contact(world)

	for i in game.SKIES.size():
		check(FileAccess.file_exists("res://%s.json" % game.SKIES[i]), "%s.json exists (node ../../tools/design-tokens.mjs)" % game.SKIES[i])
		errors.lines.clear()
		game._sky(i)
		await frames(2)
		check(errors.lines.is_empty(), "sky %s: errors %s" % [game.SKIES[i], errors.lines.slice(0, 3)])
		_no_leftovers(game, world, game.SKIES[i])
	game._sky(0)
	await _probe(game, world)
	OS.remove_logger(errors)
	return true


## A sky switch redraws the base's reflection probe behind the cover, from inside its box, for every step it takes:
## its ambient setters do not redraw it, and it kept the sunset at night (12 Nov playtest). And every dust emitter,
## also those made in play, is on the layer the probe does not shade (lit as the ground: it glowed at night).
func _probe(game: Node3D, world: Node3D) -> void:
	while game.busy():
		await frames(1)
	game._sky(game.SKIES.find("design.night"))
	var probe: ReflectionProbe = world.get_node("Probe")
	var box := AABB(probe.global_position - probe.size / 2.0, probe.size)
	var seen := 0
	for i in 3000:
		if not game.busy():
			break
		await frames(1)
		var cam := root.get_viewport().get_camera_3d()
		if cam and cam.get_parent().name != "WarmStage" and box.has_point(cam.global_position):
			seen += 1
	var need: int = load("res://addons/forge/house_style.gd").PROBE_FRAMES
	check(seen >= need, "the probe is redrawn behind the cover after a sky switch (%d frames from inside it, needs %d)" % [seen, need])
	for e: GPUParticles3D in world.dust.find_children("*", "GPUParticles3D", true, false):
		check(e.layers == 2, "dust %s on render layer 2, which the probe does not shade (%d)" % [e.name, e.layers])
	game._sky(0)
	while game.busy():
		await frames(1)


## A boot's dust (skills/ground-contact-fx checks): standing still throws nothing, a step's grit flies no higher
## than its arc allows and is gone by its flight time, its haze is gone by its life, a run throws higher than a walk.
func _contact(world: Node3D) -> void:
	var at: Vector3 = world.landmark("spawn").pos
	var dust: Node3D = world.dust
	world.puff(at, Vector3.ZERO, 1.0)
	check(dust.contact_state().is_empty(), "standing still throws dust")
	world.puff(at, Vector3(0, -0.3, -1.0), 0.5)  # a walking boot
	var live: Array = dust.contact_state()
	check(live.size() == 2, "a step throws grit and haze, got %s" % [live])
	var walk_top := 0.0
	for s: Dictionary in live:
		if s.kind == "foot":
			walk_top = s.top
			# the sheet's g, 1.3 x 1.04 m/s at 60 deg at most: about 17 cm, under a shin
			check(s.top < 0.25 and s.life < 0.8, "a walking step's grit rises %.2f m and flies %.2f s" % [s.top, s.life])
	world.puff(at, Vector3(0, -0.3, -1.6), 1.0)
	var run_top: float = dust.contact_state().filter(func(s: Dictionary) -> bool: return s.kind == "foot").map(func(s: Dictionary) -> float: return s.top).max()
	check(run_top > walk_top, "a hurried step throws higher than a walk")
	var grit_life: float = dust.contact_state().filter(func(s: Dictionary) -> bool: return s.kind == "foot").map(func(s: Dictionary) -> float: return s.life).max()
	await create_timer(grit_life + 0.1).timeout
	check(dust.contact_state().all(func(s: Dictionary) -> bool: return s.kind == "haze"), "grit outlived its flight time")
	check(dust.grit.all(func(e: GPUParticles3D) -> bool: return not e.visible), "a spent grit emitter still draws")
	await create_timer(float(world.data.contact.haze_life)).timeout
	check(dust.contact_state().is_empty() and dust.haze.all(func(e: GPUParticles3D) -> bool: return not e.visible), "haze outlived its life")


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


## Power cables (data/world.json `cables`) cross no path (a drive or walk across one would need a cover ramp) and run
## through no solid: a ray 0.2 m over the ground along each, its ends left out where it plugs into a machine. Each
## ends in a device (13 Nov playtest: "those wires aren't connected"): both drawn ends within a few cm of a port
## empty (`port*`) in the named item's model, and the data's ends near it too (rocks keep off the data's line).
func _cables_clear(world: Node3D) -> void:
	var space := world.get_world_3d().direct_space_state
	var crossings := 0
	var through: Array[String] = []
	var loose: Array[String] = []
	var c: Dictionary = world.data.cables
	check(c.ends.size() == c.lines.size() and world.cable_paths.size() == c.lines.size(),
		"every cable names its two devices (%d lines, %d ends, %d drawn)" % [c.lines.size(), c.ends.size(), world.cable_paths.size()])
	for li in c.lines.size():
		var line: Array = c.lines[li]
		var drawn: PackedVector3Array = world.cable_paths[li] if li < world.cable_paths.size() else PackedVector3Array()
		for k in 2:
			var ref: String = c.ends[li][k] if li < c.ends.size() else "?"
			var port: Node3D = world._port(ref)
			if port == null or not str(port.name).begins_with("port") or port is MeshInstance3D or drawn.is_empty():
				loose.append("%s (no port)" % ref)
				continue
			var end := drawn[0] if k == 0 else drawn[-1]
			var at: Array = line[0] if k == 0 else line[-1]
			var flat := Vector2(port.global_position.x, port.global_position.z)
			if Vector2(end.x, end.z).distance_to(flat) > 0.03 or absf(end.y - port.global_position.y) > 0.06 \
					or Vector2(at[0], at[1]).distance_to(flat) > 0.3:
				loose.append("%s at %s, its cable at %s (data %s)" % [ref, port.global_position.snappedf(0.01), end.snappedf(0.01), at])
		var pts: Array[Vector2] = []
		for k in line.size() - 1:
			var a := Vector2(line[k][0], line[k][1])
			var b := Vector2(line[k + 1][0], line[k + 1][1])
			for path: Array in world.data.paths.lines:
				for j in path.size() - 1:
					if Geometry2D.segment_intersects_segment(a, b, Vector2(path[j][0], path[j][1]), Vector2(path[j + 1][0], path[j + 1][1])) != null:
						crossings += 1
			for i in ceili(a.distance_to(b)):
				pts.append(a.move_toward(b, i))
		pts.append(Vector2(line[-1][0], line[-1][1]))
		for i in range(1, pts.size() - 2):  # the first and last metre plug in
			var from := Vector3(pts[i].x, world.height_at(pts[i].x, pts[i].y) + 0.2, pts[i].y)
			var to := Vector3(pts[i + 1].x, world.height_at(pts[i + 1].x, pts[i + 1].y) + 0.2, pts[i + 1].y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, world.STATICS | world.THIN))
			if hit:
				through.append("%s at %s" % [hit.collider.get_parent().owner.name if hit.collider.get_parent().owner else hit.collider.name, Vector2(from.x, from.z).snappedf(0.1)])
	check(crossings == 0, "%d cable crossings over a path" % crossings)
	check(through.is_empty(), "cables run through solids: %s" % [through])
	check(loose.is_empty(), "cables that end beside their device, not in its port: %s" % [loose])


## The rover's charge lead (world.gd _charger): plugged in while the rover stands in its bay, the plug in the
## rover's socket and the post's light lit; driven off, the plug goes back to the post and the lead stays short;
## parked back, it plugs in again once the rover stands still.
func _charge_lead(world: Node3D) -> void:
	var k: Dictionary = world._charge
	check(not k.is_empty(), "the charging post and the rover's charge port are found")
	if k.is_empty():
		return
	var rover: Node3D = k.rover
	var plug: Node3D = k.plug
	var lead: MeshInstance3D = k.lead
	var c: Dictionary = world.data.charger
	await frames(ceili(float(c.still_s) * Engine.physics_ticks_per_second) + 5)
	await root.get_tree().process_frame
	check(world.charging() and plug.global_position.distance_to((k.port as Node3D).global_position) < 0.02 and (k.light as Node3D).visible,
		"parked in its bay, the rover is plugged in (plug %.2f m from its port)" % plug.global_position.distance_to((k.port as Node3D).global_position))
	var home := rover.global_transform
	rover.global_position -= rover.global_basis.z * 12.0  # driven off, nose first down its track
	await frames(2)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	var out: Vector3 = (k.out as Node3D).global_position
	var far := 0.0
	for v in lead.mesh.get_faces():
		far = maxf(far, v.distance_to(out))
	check(not world.charging() and plug.global_position.distance_to((k.holster as Node3D).global_position) < 0.02 and not (k.light as Node3D).visible,
		"driven off, the plug is back in the post's holster and the light is off")
	check(far <= float(c.lead_m) + 0.1, "the lead stays at the post when the rover is away (%.2f m from it)" % far)
	rover.global_transform = home
	await frames(ceili(float(c.still_s) * Engine.physics_ticks_per_second) + 5)
	await root.get_tree().process_frame
	check(world.charging() and plug.global_position.distance_to((k.port as Node3D).global_position) < 0.02,
		"parked back in its bay, the rover is plugged in again")


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
	var rig_n := 3 if design.lighting.has("celestial") else 2  # a night sky adds its clock (house_style SkyClock)
	check(rigs.size() == rig_n, "%s: one environment, one sun (and a sky clock), found %d rig nodes" % [sky, rigs.size()])
	check(world.find_children("*", "ReflectionProbe", true, false).size() == 1 + world.data.probe.get("rooms", {}).size(), "%s: one reflection probe, and one per room" % sky)
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
