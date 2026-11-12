extends "res://addons/forge/test.gd"
## The gate's walking sweeps (skills/world-collision, "Automated checks"), through the real controller and the
## real input actions:
##   godot --headless --path . --fixed-fps 60 -s tests/sweep_test.gd     (a few minutes; about 20 in real time without --fixed-fps)
## 1. Walk into every static item from 8 headings: the drawn body is never inside a solid, never inside the item's
##    drawn faces, and never ends inside a hollow building except through its door.
## 2. Never under the floor: not under the ground, not under a floor the hero stood on.
## 3. No snag on open ground: 30 m from spawn on 8 headings at 90% of the walk speed or more, unless a solid stopped it.
## 4. The sweep proves itself: one prop with its collision freed must fail it.

const GHOST := 1 << 19  # layer 20, which nothing in the game uses: every static item's drawn faces, touching nothing
const OVERLAP := 2 | 4 | 16 | 64  # what the hero must never stand in (player.gd OVERLAP)
const HOLLOW := ["habitat", "greenhouse", "storm_shelter"]
const HEADINGS := 8
const OPEN_WALK := 30.0
const GRAZE := 0.02  # metres a drawn face may sit proud of its collision before the drawn check calls it a gap
const SELF_CHECK := "battery"  # a plain box well clear of the others

var game: Node3D
var world: Node3D
var player: Node3D
var space: PhysicsDirectSpaceState3D
var walk: float  # the sheet's walk speed, m/s
var radius: float  # the hero's collision cylinder
var ghosts: Dictionary = {}  # item id -> StaticBody3D of its drawn faces
var bad: Dictionary = {}  # what went wrong in the current run: what -> [frames, first place]
var last_floor: Array = []  # [RID, y] of the last floor that was not the ground
var touched: Dictionary = {}  # owner name -> where, for everything but the ground the hero touched this run
var info: Array[String] = []  # what is worth reading but fails nothing


func _init() -> void:
	watchdog = 3000.0  # game seconds: about 75,000 frames of walking


func play() -> bool:
	var t0 := Time.get_ticks_msec()
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	player = game.get_node("Player")
	space = game.get_world_3d().direct_space_state
	walk = player.walk
	radius = (player.body.find_children("*", "CollisionShape3D", false, false)[0].shape as CylinderShape3D).radius
	var statics: Array[String] = []
	for it: Dictionary in world.data.items:
		if world.data.kinds.get(it.prefab, "static") == "static":
			statics.append(it.id)
			_ghost(it.id)
	await frames(2)

	for id in statics:
		var problems: Array[String] = await walk_into(id, range(HEADINGS))
		for p in problems:
			check(false, p)
		print("%s  %s: walked into from %d headings" % ["ok  " if problems.is_empty() else "FAIL", id, HEADINGS])
	var snags: Array[String] = await open_ground()
	for p in snags:
		check(false, p)
	print("%s  open ground: %d headings from spawn" % ["ok  " if snags.is_empty() else "FAIL", HEADINGS])
	await self_check()
	for line in info:
		print("info  ", line)
	print("sweep took %.0f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	return true


## A body on the GHOST layer with a triangle shape per drawn mesh of the item: what the player sees, with no say in
## what blocks. Hidden meshes count, since the item's own still meshes are drawn merged into the ground cells.
func _ghost(id: String) -> void:
	var g := StaticBody3D.new()
	g.collision_layer = GHOST
	g.collision_mask = 0
	g.set_meta("item", id)
	for mi: MeshInstance3D in world.items[id].find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var faces := mi.mesh.get_faces()
		for i in faces.size():
			faces[i] = mi.global_transform * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var col := CollisionShape3D.new()
		col.name = mi.name  # the report names the drawn part
		col.shape = shape
		g.add_child(col)
	game.add_child(g)
	ghosts[id] = g


## Walks at the item's middle from each heading in `headings` (index of 8) and returns what went wrong.
func walk_into(id: String, headings: Array) -> Array[String]:
	var n: Node3D = world.items[id]
	var box: AABB = world.drawn(n)
	var c := box.get_center()
	var reach := Vector2(box.size.x, box.size.z).length() / 2.0 + radius + 1.5
	var hollow: bool = _prefab(id) in HOLLOW
	var door: Node3D = null
	for part: Node3D in n.get_meta("parts"):
		if part.name == &"door":
			door = part
	var problems: Array[String] = []
	var skipped: Array[String] = []
	for h: int in headings:
		var yaw := h * 360.0 / HEADINGS
		var dir := Vector3(sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
		var start := Vector3(c.x, 0, c.z) - dir * reach
		var tag := "%s, walking at %d deg from %s" % [id, yaw, Vector2(start.x, start.z).snappedf(0.1)]
		if not _clear(start):
			skipped.append("%d" % yaw)
			continue
		await _begin(start, yaw)
		action(&"move_forward", true)
		var entered := Vector3.INF
		for i in int((reach + 1.0) / walk * 60.0) + 90:
			await frames(1)
			var p: Vector3 = await watch()
			if hollow and i % 10 == 0 and entered == Vector3.INF and _enclosed(id, p):
				entered = p
		action(&"move_forward", false)
		await frames(1)
		var end: Vector3 = await watch()
		if hollow and entered == Vector3.INF and _enclosed(id, end):
			entered = end
		if entered != Vector3.INF:
			var by_door := door != null and Vector2(entered.x, entered.z).distance_to(Vector2(door.global_position.x, door.global_position.z)) < 2.0
			if not by_door:
				_note("got inside the hollow %s away from its door" % id, entered)
			else:
				info.append("%s: went in through the door at %s" % [tag, entered.snappedf(0.1)])
		if not touched.has(id) and not n.find_children("*", "CollisionObject3D", true, false).any(
				func(b: CollisionObject3D) -> bool: return b.is_in_group("floor")):
			info.append("%s: never touched it%s" % [tag, (", stopped by %s" % [touched]) if touched.size() else ""])
		problems.append_array(_report(tag))
	if skipped.size():
		info.append("%s: headings %s skipped, the start was in a solid or off the patch" % [id, ", ".join(skipped)])
	return problems


## 30 m straight out from spawn on each heading at the walk speed. Slower than 90% of it with nothing but the
## ground touched is a snag; an item or a rock in the way ends or explains the slowdown.
func open_ground() -> Array[String]:
	var spawn: Dictionary = world.landmark("spawn")
	var problems: Array[String] = []
	for h in HEADINGS:
		var yaw := h * 360.0 / HEADINGS
		var from: Vector3 = spawn.pos
		var tag := "open ground, %d deg from spawn" % yaw
		await _begin(from, yaw)
		action(&"move_forward", true)
		var stuck := 0
		var accel := int(walk / player.brake * 60.0) + 10  # frames to reach the walk speed
		for i in int(OPEN_WALK / walk * 60.0 * 1.3) + accel:
			await frames(1)
			var p: Vector3 = await watch()
			if Vector2(p.x - from.x, p.z - from.z).length() >= OPEN_WALK:
				break
			var s: Dictionary = game.render_game_to_text().player
			if i < accel or s.speed >= 0.9 * walk:
				stuck = 0
				continue
			var now := _contacts()
			var items: Array = now.keys().filter(func(k: String) -> bool: return world.items.has(k))
			if items.size():
				var item: String = items[0]
				info.append("%s: stopped by %s at %s after %.1f m" % [tag, item, p.snappedf(0.1), Vector2(p.x - from.x, p.z - from.z).length()])
				break
			if now.has("rock"):
				var at: String = now.rock
				if not info.has("%s: snags on the rock at %s" % [tag, at]):
					info.append("%s: snags on the rock at %s" % [tag, at])
				stuck += 1
				if stuck > 60:
					break  # held behind it: a solid in the way, like any item
				continue
			_note("slowed to %.2f m/s (under 90%% of %.1f) touching only the ground" % [s.speed, walk], p)
		action(&"move_forward", false)
		await frames(1)
		problems.append_array(_report(tag))
	return problems


## With its bodies freed, the self-check prop must fail the walk-into sweep, or the sweep tests nothing.
func self_check() -> void:
	var n: Node3D = world.items[SELF_CHECK]
	for b: Node in n.find_children("*", "CollisionObject3D", true, false):
		b.free()
	await frames(2)
	var heading := -1
	for h in HEADINGS:
		var yaw := h * 360.0 / HEADINGS
		var box: AABB = world.drawn(n)
		var reach := Vector2(box.size.x, box.size.z).length() / 2.0 + radius + 1.5
		if _clear(Vector3(box.get_center().x, 0, box.get_center().z) - Vector3(sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw))) * reach):
			heading = h
			break
	var caught: Array[String] = []
	if heading >= 0:
		caught = await walk_into(SELF_CHECK, [heading])
	if check(caught.size() > 0, "self-check: the sweep passed %s with its collision freed, so it tests nothing" % SELF_CHECK):
		print("ok    self-check: with %s's collision freed the sweep fails it (%d findings, first: %s)" % [SELF_CHECK, caught.size(), caught[0]])


## Puts the hero down standing still and forgets the last run.
func _begin(at: Vector3, yaw: float) -> void:
	game.place(Vector3(at.x, 0, at.z), yaw)
	await frames(2)
	last_floor = []
	touched.clear()
	bad.clear()


## The checks that hold on every frame of every run. Returns where the hero's feet are.
func watch() -> Vector3:
	var s: Dictionary = game.render_game_to_text().player
	var p: Vector3 = s.pos
	var solids := {}
	for path: String in s.inside:
		solids[_owner(root.get_node_or_null(path))] = true
	for o: String in solids:
		_note("drawn body inside the solid %s" % o, p)
	for part: String in _drawn_overlaps():
		_note("drawn body inside the drawn faces of %s" % part, p)
	var ground: float = world.height_at(p.x, p.z)
	if p.y < ground - 0.1:
		_note("feet under the ground", p)
		bad["feet under the ground"].append(ground - p.y)
	var b: CharacterBody3D = player.body
	for i in b.get_slide_collision_count():
		var c := b.get_slide_collision(i)
		var o := c.get_collider() as CollisionObject3D
		if o == null or o.collision_layer & world.GROUND:
			continue
		touched[_owner(o)] = str(o.global_position.snappedf(0.1))
		if c.get_normal().y > cos(b.floor_max_angle):
			last_floor = [c.get_collider_rid(), c.get_position().y]
	# under a floor it stood on: that floor's surface is between the feet and where the feet were
	if last_floor.size() and p.y < last_floor[1] - 0.1:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, last_floor[1] + 0.3, p.z), p, OVERLAP)
		var hit := space.intersect_ray(q)
		if hit.size() and hit.rid == last_floor[0]:
			_note("feet under a floor it stood on (top %.2f)" % hit.position.y, p)
	return p


## The drawn parts ("item/mesh") the hero's torso overlaps: the cylinder player.inside() asks physics about
## (less Jolt's resting sink), GRAZE narrower, since a drawn face may sit that far proud of its collision. The suited arms and pack are
## left out on purpose: the collider is the sheet's breadth, so they may graze a wall (a 1.2 m hatch needs it).
func _drawn_overlaps() -> Array:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * (1.0 - ProjectSettings.get_setting("physics/jolt_physics_3d/collisions/collision_margin_fraction")) - GRAZE
	cyl.height = player.model.bounds.end.y - player.step
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.transform = player.body.global_transform * Transform3D(Basis(), Vector3(0, player.step + cyl.height / 2.0, 0))
	q.collision_mask = GHOST
	var out := {}
	for h: Dictionary in space.intersect_shape(q, 64):
		var g: StaticBody3D = h.collider
		out["%s/%s" % [g.get_meta("item"), g.shape_owner_get_owner(g.shape_find_owner(h.shape)).name]] = true
	return out.keys()


## Walls of the item on four sides at chest height and a roof over the head: inside a hollow building.
func _enclosed(id: String, p: Vector3) -> bool:
	var others: Array[RID] = []
	for k: String in ghosts:
		if k != id:
			others.append((ghosts[k] as StaticBody3D).get_rid())
	var chest := p + Vector3(0, 1.2, 0)
	for d: Vector3 in [Vector3(0, 30, 0), Vector3(30, 0, 0), Vector3(-30, 0, 0), Vector3(0, 0, 30), Vector3(0, 0, -30)]:
		var q := PhysicsRayQueryParameters3D.create(chest, chest + d, GHOST, others)
		if space.intersect_ray(q).is_empty():
			return false
	return true


## The start of a run: on the patch, and the hero's whole body there touches no solid and no drawn face.
func _clear(at: Vector3) -> bool:
	var half: float = world.data.play_half - 2.0
	if absf(at.x) > half or absf(at.z) > half:
		return false
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = player.model.bounds.end.y - player.step
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.collision_mask = OVERLAP | GHOST
	q.transform = Transform3D(Basis(), Vector3(at.x, world.height_at(at.x, at.z) + player.step + cyl.height / 2.0, at.z))
	return space.intersect_shape(q, 1).is_empty()


## What the hero touches now besides the ground: owner name -> where.
func _contacts() -> Dictionary:
	var out := {}
	var b: CharacterBody3D = player.body
	for i in b.get_slide_collision_count():
		var o := b.get_slide_collision(i).get_collider() as CollisionObject3D
		if o and not o.collision_layer & world.GROUND:
			out[_owner(o)] = str(o.global_position.snappedf(0.1))
	return out


## The world.json item a node belongs to, or "rock".
func _owner(n: Node) -> String:
	while n != null and n.get_parent() != world:
		n = n.get_parent()
	if n == null:
		return "something outside the world"
	return "rock" if n == world.rocks else str(n.name)


func _prefab(id: String) -> String:
	for it: Dictionary in world.data.items:
		if it.id == id:
			return it.prefab
	return ""


func _note(what: String, at: Vector3) -> void:
	var b: Array = bad.get_or_add(what, [0, at.snappedf(0.01)])
	b[0] += 1


func _report(tag: String) -> Array[String]:
	var out: Array[String] = []
	for what: String in bad:
		var deepest: float = bad[what].slice(2).max() if bad[what].size() > 2 else 0.0
		out.append("%s: %s on %d frames, first at %s%s" % [tag, what, bad[what][0], bad[what][1], ", %.2f m deep at most" % deepest if deepest > 0.0 else ""])
	bad.clear()
	return out
