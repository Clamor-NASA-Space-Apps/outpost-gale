extends Node3D
## The ground. data/terrain.json is the one height source: the patch mesh, its collision and height_at()
## all read it. The far skyline is models/terrain_backdrop.glb. Both are drawn by terrain.gdshader.

const SHADER := preload("res://world/terrain.gdshader")
const CHUNK := 50  # cells per side of one patch mesh: 100 m pieces the camera can cull one by one

var step: float
var cols: int
var rows: int
var origin: Vector2
var heights: PackedFloat32Array
var material: ShaderMaterial


func build(design: Dictionary) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	step = d.step
	cols = d.size[0]
	rows = d.size[1]
	origin = Vector2(d.origin[0], d.origin[1])
	heights = PackedFloat32Array(d.heights)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("macro_normal", load("res://data/terrain_normal.png"))
	material.set_shader_parameter("macro_rect", Vector4(origin.x, origin.y, (cols - 1) * step, (rows - 1) * step))
	restyle(design)
	for i in range(0, rows - 1, CHUNK):
		for j in range(0, cols - 1, CHUNK):
			_chunk(i, j)
	_collision()
	var back := Forge.load_glb(ProjectSettings.globalize_path("res://models/terrain_backdrop.glb"))
	for mi: MeshInstance3D in back.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # too far out to shade anything we see
	add_child(back)


## Colours and the detail strength from the design in force (a theme or quality switch calls it again).
func restyle(design: Dictionary) -> void:
	for r: String in ["dust", "rock"]:
		var t: Dictionary = design.materials[r]
		material.set_shader_parameter(r + "_color", Color.html(t.color))
		material.set_shader_parameter(r + "_roughness", float(t.get("roughness", 1)))
		# the role's photo set (DESIGN.md detail), so the ground and a rock model share one surface
		var d: Dictionary = t.get("detail", {})
		for map: String in ["texture", "normal", "roughness"]:
			var file := "res://" + str(d.get(map, ""))
			var param: String = r + {"texture": "_albedo", "normal": "_normal", "roughness": "_rough"}[map]
			material.set_shader_parameter(param, load(file) if d.has(map) and ResourceLoader.exists(file) else null)
		material.set_shader_parameter(r + "_size", float(d.get("textureSize", 3.0)))
	var level: String = design.get("_quality", {}).get("detail", "texture")
	material.set_shader_parameter("detail_strength", 0.0 if level == "off" else 1.0)


## Ground height at x, z (metres, world), between the four nearest samples. Outside the patch: its edge.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / step, 0.0, cols - 1.001)
	var fz := clampf((z - origin.y) / step, 0.0, rows - 1.001)
	var j := int(fx)
	var i := int(fz)
	var a := heights[i * cols + j]
	var b := heights[i * cols + j + 1]
	var c := heights[(i + 1) * cols + j]
	var e := heights[(i + 1) * cols + j + 1]
	return lerpf(lerpf(a, b, fx - j), lerpf(c, e, fx - j), fz - i)


func _h(i: int, j: int) -> float:
	return heights[clampi(i, 0, rows - 1) * cols + clampi(j, 0, cols - 1)]


func _chunk(i0: int, j0: int) -> void:
	var n := CHUNK + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in range(i0, i0 + n):
		for j in range(j0, j0 + n):
			verts.append(Vector3(origin.x + j * step, _h(i, j), origin.y + i * step))
			norms.append(Vector3(_h(i, j - 1) - _h(i, j + 1), 2.0 * step, _h(i - 1, j) - _h(i + 1, j)).normalized())
	var idx := PackedInt32Array()
	for i in CHUNK:
		for j in CHUNK:
			var a := i * n + j
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "patch_%d_%d" % [i0, j0]
	add_child(mi)


func _collision() -> void:
	# HeightMapShape3D puts its samples 1 unit apart, so the shape is scaled by the step and the heights are
	# divided by it: a uniform scale, which Jolt takes
	var shape := HeightMapShape3D.new()
	shape.map_width = cols
	shape.map_depth = rows
	var scaled := PackedFloat32Array(heights)
	for k in scaled.size():
		scaled[k] /= step
	shape.map_data = scaled
	var body := StaticBody3D.new()
	body.name = "ground"
	body.collision_layer = 1  # CONTRACTS.md: layer 1 is the ground
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * step
	col.position = Vector3(origin.x + (cols - 1) * step / 2.0, 0.0, origin.y + (rows - 1) * step / 2.0)
	body.add_child(col)
	add_child(body)
