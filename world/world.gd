extends Node3D
## The world: terrain, every item in data/world.json on the ground, the rock scatter, the dust and one
## reflection probe. A prefab whose model is not in models/ yet stands in as a labelled box of its real size,
## so the sandbox runs before the models land. Collision always comes from what is drawn (skills/world-collision).

const Terrain := preload("res://world/terrain.gd")
const Rocks := preload("res://world/rocks.gd")
const Dust := preload("res://world/dust.gd")
# CONTRACTS.md collision layers, as bits
const GROUND := 1
const STATICS := 2
const THIN := 4
const HERO := 8
const VEHICLES := 16
const CARRIABLES := 64
const CELL := 64.0  # metres: still items in one cell share their meshes; the patch centre is a cell's middle

var data: Dictionary
var terrain: Node3D
var rocks: Node3D
var dust: Node3D
var items: Dictionary = {}  # id -> Node3D
var hero_width: float  # from the reality sheet: a solid narrower than this is `thin`
var hero_step: float  # and one no higher than this is a `floor` the hero steps onto
var hero_height: float  # for the sweeps in tests/world_test.gd
var weather: Dictionary
var _moving: RegEx
var _probe: ReflectionProbe
var _cells: Array[Node3D] = []


func build(design: Dictionary) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json"))
	for r: Dictionary in sheet.rows:
		if r.id == "hero.width":
			hero_width = r.value
		elif r.id == "hero.step":
			hero_step = r.value
		elif r.id == "hero.height":
			hero_height = r.value
	_moving = RegEx.create_from_string(data.moving)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(design)
	for it: Dictionary in data.items:
		items[it.id] = _item(it, design)
	_merge_cells()
	rocks = Rocks.new()
	rocks.name = "Rocks"
	add_child(rocks)
	rocks.build(self)
	dust = Dust.new()
	dust.name = "Dust"
	add_child(dust)
	dust.build(self)
	# the probe's light on rough ground came out as a bright square around the base (measured): the ground
	# and the rocks sit on render layer 2, which the probe draws but does not shade
	for g: GeometryInstance3D in terrain.find_children("*", "GeometryInstance3D", true, false) + rocks.find_children("*", "GeometryInstance3D", true, false):
		g.layers = 2
	# the patch is within 2 m of flat over 400 m, so its shadow on itself is a few pixels at most, and each
	# chunk in the shadow range was drawn again per split (the base view was over its 150 draw calls)
	for g: GeometryInstance3D in terrain.find_children("patch_*", "GeometryInstance3D", false, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	restyle(design)


## A sky state or a quality switch: every material, lamp, the probe and the dust follow the design in force.
func restyle(design: Dictionary) -> void:
	terrain.restyle(design)
	for n: Node3D in items.values():
		Forge.HouseStyle.apply(n, design, n.get_meta("still"))
		for part: Node3D in n.get_meta("parts"):
			Forge.HouseStyle.apply(part, design, false)  # it moves, so its detail must travel with it
	for cell: Node3D in _cells:
		Forge.HouseStyle.apply(cell, design, true)
	rocks.restyle(design)
	weather = data.weather.get(design.get("name", ""), data.weather["Outpost Gale"])
	dust.restyle(design, weather)
	_lamps(design)
	# One probe for the life of the world: freeing one leaked its two atlas textures in Compatibility (measured,
	# "Texture ... leaked" at exit). It draws its six faces once, and again whenever a property changes, so the
	# ambient set below on every sky switch also makes metal reflect the new sky.
	if _probe == null:
		_probe = ReflectionProbe.new()
		_probe.name = "Probe"
		var p: Array = data.probe.pos
		var s: Array = data.probe.size
		_probe.size = Vector3(s[0], s[1], s[2])
		_probe.position = Vector3(p[0], height_at(p[0], p[1]) + 2.0, p[1])
		_probe.reflection_mask = 1  # machines only: ground and rocks on layer 2 keep the sky's light
		# a probe also replaces the ambient light inside its box with what it captured, and faces turned from
		# the sun went pure black there; the rig's own shade colour keeps them as DESIGN.md says
		_probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		add_child(_probe)
	_probe.ambient_color = Color.html(design.lighting.get("ambientColor", design.lighting.sky))
	_probe.ambient_color_energy = float(design.lighting.get("ambient", 1)) / PI  # the rig's units (house_style UNIT)


func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


## {pos: Vector3 on the ground, yaw: degrees}
func landmark(name: String) -> Dictionary:
	var l: Array = data.landmarks.get(name, data.landmarks.spawn)
	return {"pos": Vector3(l[0], height_at(l[0], l[1]), l[1]), "yaw": float(l[2])}


## A footprint ("foot_l", "foot_r") or a wheel print ("wheel", `width` in metres) pressed into the dust: terrain.gd draws it.
func mark(pos: Vector3, yaw_deg: float, kind: String, width := 0.3) -> void:
	terrain.mark(pos, yaw_deg, kind, width)


## A dust puff at a footstep or a wheel (strength 0 to 1).
func puff(pos: Vector3, strength: float) -> void:
	dust.puff(pos, strength)


## Lowest ground under a world-space box, sampled on a grid: what a footprint rests on.
func ground_under(box: AABB) -> float:
	var low := INF
	for i in 6:
		for j in 6:
			low = minf(low, height_at(box.position.x + box.size.x * i / 5.0, box.position.z + box.size.z * j / 5.0))
	return low


## The box everything drawn under `root` fills, in world space.
static func drawn(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _item(it: Dictionary, design: Dictionary) -> Node3D:
	var kind: String = data.kinds.get(it.prefab, "static")
	var model := _model(it.prefab, design)
	var root: Node3D = model
	if kind != "static":
		# a mover is one body around its model: the lane that moves it finds the body at the item's node
		var body := AnimatableBody3D.new()
		# with sync_to_physics the body is pulled back to where physics first saw it, the origin: every mover
		# sat at (0, 0, 0). The rover and the bags are moved by setting their transform.
		body.sync_to_physics = false
		body.collision_layer = VEHICLES if kind == "vehicle" else CARRIABLES
		body.collision_mask = GROUND | STATICS | THIN | HERO if kind == "vehicle" else 0
		body.add_to_group(kind)
		body.add_child(model)
		root = body
	root.name = it.id
	add_child(root)
	root.position = Vector3(it.pos[0], 0, it.pos[1])
	root.rotation.y = -deg_to_rad(float(it.get("yaw", 0)))
	var parts := _parts(model)
	if kind == "static":
		_solidify(model, parts)
	else:
		_hull(root, model)
	root.set_meta("parts", parts)
	var still := _still(root)
	if still.size() > 1:
		_merge(still, model)
		for mi: MeshInstance3D in still:
			mi.mesh = null
	# on a slope the footprint's lowest corner touches the ground and the rest sits a little into it
	var box := drawn(root)
	root.position.y = ground_under(box) - box.position.y
	if kind != "static":
		# a vehicle's wheels sit in the shadow of its own body
		for part in parts:
			for g: Node in part.find_children("*", "GeometryInstance3D", true, false) + [part]:
				if g is GeometryInstance3D:
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if box.size.y < float(data.shadow_min):
		# each shadow split draws a caster again, and a knee-high bag's shadow is a few pixels
		for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("still", kind == "static")
	root.set_meta("lamp", _lamp_at(root) if it.prefab in data.lamps else null)
	return root


func _model(id: String, design: Dictionary) -> Node3D:
	var file: String = data.prefabs.get(id, "")
	if ResourceLoader.exists(file):
		var m: Node3D = load(file).instantiate()
		Forge.HouseStyle.apply(m, design, true)
		return m
	var size: Array = data.standin.get(id, [1, 1, 1])
	var s := Vector3(size[0], size[1], size[2])
	var root := Node3D.new()
	var box := BoxMesh.new()
	box.size = s
	box.material = Forge.HouseStyle.role(design, "trim")  # a named role, so restyle() finds it again
	var mi := MeshInstance3D.new()
	mi.name = "standin"
	mi.mesh = box
	mi.position.y = s.y / 2.0
	root.add_child(mi)
	var label := Label3D.new()
	label.text = id + " (stand-in)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = s.y + 0.4
	label.font_size = 48
	root.add_child(label)
	return root


## The parts that move (data/world.json `moving`: door, dish, panel_N, wheel_N): the topmost node so named, below the model.
func _parts(model: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var todo: Array[Node] = model.get_children()
	while todo.size():
		var n: Node = todo.pop_back()
		if n is Node3D and _moving.search(n.name):
			out.append(n)
		else:
			todo.append_array(n.get_children())
	return out


func _in_part(n: Node, parts: Array[Node3D]) -> bool:
	return parts.any(func(p: Node3D) -> bool: return p == n or p.is_ancestor_of(n))


## Collision for a static item, from its own triangles. A model that arrives with bodies (-col names) chose
## which parts block, so its other still parts (handles, labels) stay walk-past detail; a model with none gets
## a triangle body on every still mesh. A moving part with no body gets a convex hull on an AnimatableBody3D,
## so it can open, tilt or turn and still block.
func _solidify(model: Node3D, parts: Array[Node3D]) -> void:
	var authored := model.find_children("*", "CollisionObject3D", true, false).size() > 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin or mi.get_children().any(func(c: Node) -> bool: return c is CollisionObject3D):
			continue
		var moving := _in_part(mi, parts)
		if authored and not moving:
			continue
		if moving:
			var body := AnimatableBody3D.new()
			body.sync_to_physics = false  # it rides a moving parent (world-collision rule: or its shape stays behind)
			var col := CollisionShape3D.new()
			col.shape = mi.mesh.create_convex_shape(true, false)
			body.add_child(col)
			mi.add_child(body)
		else:
			mi.create_trimesh_collision()
	for body: CollisionObject3D in model.find_children("*", "CollisionObject3D", true, false):
		_layer(body)


## Statics on layer 2, anything narrower than the hero on layer 3 (the camera ignores it), groups for the rules.
func _layer(body: CollisionObject3D) -> void:
	var box := AABB()
	var first := true
	for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
		var b := cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		box = b if first else box.merge(b)
		first = false
	var thin := maxf(box.size.x, box.size.z) < hero_width
	body.collision_layer = THIN if thin else STATICS
	body.collision_mask = 0
	body.add_to_group("thin" if thin else "wall")
	if box.size.y <= hero_step:
		body.add_to_group("floor")


## One convex hull around a mover's drawn points. The rover is entered by a door script, not walked into.
func _hull(body: Node3D, model: Node3D) -> void:
	var points := PackedVector3Array()
	var to_body := body.global_transform.affine_inverse()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var at := to_body * mi.global_transform
			for v in mi.mesh.get_faces():
				points.append(at * v)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points  # the engine reduces it to the hull
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)


## Meshes into one mesh with one surface per material, placed in `parent`: a draw call per material, not per part.
func _merge(meshes: Array, parent: Node3D) -> MeshInstance3D:
	var tools: Dictionary = {}  # Material -> SurfaceTool
	var to_parent := parent.global_transform.affine_inverse()
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if not tools.has(m):
				tools[m] = SurfaceTool.new()
			Forge.HouseStyle.merge(tools[m], mi.mesh, s, to_parent * mi.global_transform, m)
	var mesh := ArrayMesh.new()
	for m: Material in tools:
		tools[m].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var out := MeshInstance3D.new()
	out.name = "merged"
	out.mesh = mesh
	parent.add_child(out)
	return out


## An item's meshes that never move: not a moving part, not skinned.
func _still(n: Node3D) -> Array:
	var parts: Array[Node3D] = n.get_meta("parts")
	return n.find_children("*", "MeshInstance3D", true, false).filter(func(mi: MeshInstance3D) -> bool:
		return mi.mesh != null and mi.skin == null and not _in_part(mi, parts))


## The still meshes of every static item in one ground cell, merged per material (world-collision rule 9):
## the base went from 400 draw calls to a handful per material. Each item keeps its own meshes hidden,
## for its collision, its tags, its lamp and the checks.
func _merge_cells() -> void:
	var cells: Dictionary = {}  # Vector2i -> meshes
	for n: Node3D in items.values():
		if n.get_meta("still"):
			cells.get_or_add(Vector2i(floori(n.position.x / CELL + 0.5), floori(n.position.z / CELL + 0.5)), []).append_array(_still(n))
	for key: Vector2i in cells:
		var holder := Node3D.new()
		holder.name = "cell_%d_%d" % [key.x, key.y]
		add_child(holder)
		_merge(cells[key], holder)
		for mi: MeshInstance3D in cells[key]:
			mi.visible = false
		_cells.append(holder)


## Where a lamp's light sits: the middle of its `light` role parts, else the top of the model.
func _lamp_at(root: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m and m.resource_name == "light":
				var b := mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
	if first:
		var all := drawn(root)
		return root.to_local(Vector3(all.get_center().x, all.end.y - 0.15, all.get_center().z))
	return root.to_local(box.get_center())


## Lamps light only when the design has `lighting.lamp` (the night). The old ones go first, every time.
func _lamps(design: Dictionary) -> void:
	for old: Node in get_tree().get_nodes_in_group("world_lamp"):
		old.free()
	for n: Node3D in items.values():
		var at: Variant = n.get_meta("lamp") if n.has_meta("lamp") else null  # set_meta(null) stores nothing
		var lamp := Forge.HouseStyle.make_lamp(design) if at != null else null
		if lamp:
			lamp.position = at
			lamp.add_to_group("world_lamp")
			n.add_child(lamp)
