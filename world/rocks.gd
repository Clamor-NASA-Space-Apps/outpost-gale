extends Node3D
## Rocks over the patch, seeded from data/world.json `scatter`: pebbles in one MultiMesh per rock shape (a draw
## call each, no collision: the hero steps over them), and solid rocks of `big_size` in one more, each with a
## convex body of its own drawn shape. None on items, pads or paths; most just outside the base clearing.
## Solid rocks are models/rock_*.glb (lumps made here until they exist); pebbles are always the lumps.

const SHAPES := 3  # pebble shapes
const STANDIN := "standin"

var solids: Array[StaticBody3D] = []
var pebbles: Array[MultiMeshInstance3D] = []
var big: MeshInstance3D  # every solid rock in one mesh, a surface per role
var spots: Array[Transform3D] = []  # every rock placed, pebbles and solid ones
var _world: Node3D
var _keep_out: Array[AABB] = []  # item footprints, grown by the margin


func build(world: Node3D) -> void:
	_world = world
	var p: Dictionary = world.data.scatter
	for n: Node3D in world.items.values():
		_keep_out.append(world.drawn(n).grow(float(p.margin)))
	# the rock models are the solid rocks. Pebbles are lumpy spheres made here: a scanned pebble is 500
	# triangles, thousands were 1.7 million (measured), and simplifying one stopped at 231
	var big_shapes := _shapes()
	var small_shapes := _lumps()
	if big_shapes.is_empty():
		big_shapes = small_shapes
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.seed)
	var small: Array = [] # [mesh index, Transform3D]
	var large: Array = []
	for is_big: bool in [true, false]:
		var want := int(p.big if is_big else p.pebbles)
		var size: Array = p.big_size if is_big else p.pebble_size
		var placed: Array = large if is_big else small
		var meshes: Array[Mesh] = big_shapes if is_big else small_shapes
		# stand-in spheres need squashing to read as stones; a modelled rock already has its shape
		var squash: Array = [0.45, 0.8] if meshes[0].has_meta(STANDIN) else [0.8, 1.1]
		for attempt in want * 30:
			if placed.size() >= want:
				break
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * float(p.radius)
			var x := float(p.centre[0]) + cos(a) * d
			var z := float(p.centre[1]) + sin(a) * d
			var s := lerpf(size[0], size[1], pow(rng.randf(), 3.0))  # many small, few large, like a real field
			if rng.randf() > _density(d, p, is_big) or _blocked(x, z, s):
				continue
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
			basis = basis.scaled(Vector3(1.0, rng.randf_range(squash[0], squash[1]), rng.randf_range(0.7, 1.1)) * s)
			# a rock rests sunk into the dust a little, never balanced on a point
			var y: float = world.height_at(x, z) - 0.15 * s
			placed.append([rng.randi() % meshes.size(), Transform3D(basis, Vector3(x, y, z))])
	for r: Array in small + large:
		spots.append(r[1])
	pebbles = _multi(small_shapes, small)
	big = _baked(big_shapes, large)
	for r: Array in large:
		_solid(big_shapes[r[0]], r[1])


func restyle(design: Dictionary) -> void:
	var meshes: Array[Mesh] = [big.mesh]
	for mm: MultiMeshInstance3D in pebbles:
		meshes.append(mm.multimesh.mesh)
	for mesh in meshes:
		for i in mesh.get_surface_count():
			# a modelled rock names its roles (rock under a dust coat); anything else is rock
			var role: String = mesh.surface_get_name(i)
			mesh.surface_set_material(i, Forge.HouseStyle.role(design, role if design.materials.has(role) else "rock", true))


## How likely a rock is this far from the clearing's centre: few inside, most at its edge, thinning outward.
func _density(d: float, p: Dictionary, is_big: bool) -> float:
	var clear := float(p.clear)
	if d < clear:
		return 0.0 if is_big else float(p.inside)
	var out := float(p.outside)
	return out + (1.0 - out) * exp(-(d - clear) / float(p.edge))


func _blocked(x: float, z: float, r: float) -> bool:
	var at := Vector3(x, 0, z)
	for box in _keep_out:
		if x > box.position.x - r and x < box.end.x + r and z > box.position.z - r and z < box.end.z + r:
			return true
	var half: float = _world.data.paths.width / 2.0 + r
	for line: Array in _world.data.paths.lines:
		for i in line.size() - 1:
			var a := Vector3(line[i][0], 0, line[i][1])
			var b := Vector3(line[i + 1][0], 0, line[i + 1][1])
			if at.distance_to(Geometry3D.get_closest_point_to_segment(at, a, b)) < half:
				return true
	return false


## Unit-sized rock meshes from models/rock_*.glb.
func _shapes() -> Array[Mesh]:
	var out: Array[Mesh] = []
	for f in DirAccess.get_files_at("res://models"):
		if f.begins_with("rock_") and f.ends_with(".glb"):
			var m: Node3D = load("res://models/" + f).instantiate()
			for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
				out.append(_unit(mi, mi.transform))
				break
			m.free()
	return out


## Unit-sized lumpy spheres of a few dozen triangles, one surface named rock.
func _lumps() -> Array[Mesh]:
	var out: Array[Mesh] = []
	for k in SHAPES:
		var sphere := SphereMesh.new()
		sphere.radial_segments = 7
		sphere.rings = 4
		var arrays := sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var noise := FastNoiseLite.new()
		noise.seed = k + 1
		noise.frequency = 1.4
		for i in verts.size():
			verts[i] *= 1.0 + 0.35 * noise.get_noise_3dv(verts[i])
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		var st := SurfaceTool.new()
		st.create_from_arrays(arrays)
		st.generate_normals()
		var lumpy := MeshInstance3D.new()
		lumpy.mesh = st.commit()
		var unit := _unit(lumpy, Transform3D())
		lumpy.free()
		unit.set_meta(STANDIN, true)
		out.append(unit)
	return out


## Scaled so its widest side is 1 m and its base sits at 0, the way the scatter sizes it. Every surface is kept,
## named by its role so restyle() can find it again.
func _unit(mi: MeshInstance3D, at: Transform3D) -> ArrayMesh:
	var box := at * mi.mesh.get_aabb()
	var k := 1.0 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	var to := Transform3D(Basis().scaled(Vector3.ONE * k), -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k) * at
	var out := ArrayMesh.new()
	for i in mi.mesh.get_surface_count():
		var st := SurfaceTool.new()
		st.append_from(mi.mesh, i, to)
		st.commit(out)
		var m := mi.get_active_material(i)
		out.surface_set_name(i, m.resource_name if m else "rock")
	return out


## The solid rocks baked into one mesh: a MultiMesh per rock model cost two draw calls per model plus two per
## shadow split for a few dozen rocks; one mesh costs one per role.
func _baked(meshes: Array[Mesh], placed: Array) -> MeshInstance3D:
	var tools: Dictionary = {}  # role -> SurfaceTool
	for r: Array in placed:
		var mesh: Mesh = meshes[r[0]]
		for i in mesh.get_surface_count():
			var role: String = mesh.surface_get_name(i)
			if not tools.has(role):
				tools[role] = SurfaceTool.new()
			tools[role].append_from(mesh, i, r[1])
	var out := ArrayMesh.new()
	for role: String in tools:
		tools[role].commit(out)
		out.surface_set_name(out.get_surface_count() - 1, role)
	var mi := MeshInstance3D.new()
	mi.name = "solid_rocks"
	mi.mesh = out
	add_child(mi)
	return mi


func _multi(meshes: Array[Mesh], placed: Array) -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for k in meshes.size():
		var mine := placed.filter(func(r: Array) -> bool: return r[0] == k)
		if mine.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = mine.size()
		for i in mine.size():
			mm.set_instance_transform(i, mine[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# pebbles are too small for a shadow to read, and each shadow split would draw them all again
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		out.append(mmi)
	return out


## A solid rock: its own drawn points as a convex body, so what you see is what you hit.
func _solid(mesh: Mesh, at: Transform3D) -> void:
	var points := PackedVector3Array()
	for v in mesh.get_faces():
		points.append(at.basis * v)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var body := StaticBody3D.new()
	body.position = at.origin
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)
	_world._layer(body)
	solids.append(body)
