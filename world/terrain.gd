extends Node3D
## The ground. data/terrain.json is the one height source: the patch mesh, its collision and height_at()
## all read it. The far skyline is models/terrain_backdrop.glb. Both are drawn by terrain.gdshader.

const SHADER := preload("res://world/terrain.gdshader")
const CHUNK := 50  # cells per side of one patch mesh: 100 m pieces the camera can cull one by one
# The trail map: footprints and wheel tracks pressed into the dust, in a square that follows the camera.
# 2048 px over 64 m is 3 cm a pixel: a boot print (about 30 x 12 cm) is 10 x 4 px, enough for its tread.
const TRAIL_PX := 2048
const TRAIL_M := 64.0
const TRAIL_SHIFT := 16.0  # metres the camera may wander from the square's centre before it moves

var step: float
var cols: int
var rows: int
var origin: Vector2
var heights: PackedFloat32Array
var material: ShaderMaterial
var trail: Image
var trail_tex: ImageTexture
var trail_centre := Vector2.ZERO
var trail_dirty := false


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
	trail = Image.create_empty(TRAIL_PX, TRAIL_PX, false, Image.FORMAT_R8)
	trail_tex = ImageTexture.create_from_image(trail)
	material.set_shader_parameter("trail_map", trail_tex)
	_trail_rect()
	restyle(design)
	for i in range(0, rows - 1, CHUNK):
		for j in range(0, cols - 1, CHUNK):
			_chunk(i, j)
	_collision()
	var back: Node3D = load("res://models/terrain_backdrop.glb").instantiate()  # a web build has no file paths, only res://
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
	# the ground's extra layers ride on the dust role: gravel patches and wind ripples (DESIGN.md)
	var dd: Dictionary = design.materials.dust.get("detail", {})
	for layer: String in ["gravel", "ripple"]:
		var l: Dictionary = dd.get(layer, {})
		for map: String in ["texture", "normal"]:
			var file := "res://" + str(l.get(map, ""))
			var param: String = layer + {"texture": "_albedo", "normal": "_normal"}[map]
			material.set_shader_parameter(param, load(file) if l.has(map) and ResourceLoader.exists(file) else null)
		material.set_shader_parameter(layer + "_size", float(l.get("textureSize", 3.0)))
	material.set_shader_parameter("gravel_share", float(dd.get("gravel", {}).get("share", 0.3)))
	var level: String = design.get("_quality", {}).get("detail", "texture")
	material.set_shader_parameter("detail_strength", 0.0 if level == "off" else 1.0)


## Ground height at x, z (metres, world) on the same triangle the mesh draws and the collision uses (both split
## each cell from its (j+1, i) corner to its (j, i+1) corner; measured against the heightmap shape). A bilinear
## blend was up to 2 cm off them on 2 m cells, so things set on it hovered over the drawn ground or sank.
## Outside the patch: its edge.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / step, 0.0, cols - 1.001)
	var fz := clampf((z - origin.y) / step, 0.0, rows - 1.001)
	var j := int(fx)
	var i := int(fz)
	var u := fx - j
	var v := fz - i
	var a := heights[i * cols + j]
	var b := heights[i * cols + j + 1]
	var c := heights[(i + 1) * cols + j]
	var e := heights[(i + 1) * cols + j + 1]
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return e + (c - e) * (1.0 - u) + (b - e) * (1.0 - v)


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


## A print pressed into the dust: `foot_l` / `foot_r` (a boot with tread) or `wheel` (`width` wide, along `yaw`).
## Prints stay where they are made; they only fade when the square moves away from them.
func mark(pos: Vector3, yaw_deg: float, kind: String, width := 0.3) -> void:
	var px := TRAIL_M / TRAIL_PX
	var fwd := Vector2(sin(deg_to_rad(yaw_deg)), -cos(deg_to_rad(yaw_deg)))  # x, z of the heading
	var side := Vector2(-fwd.y, fwd.x)
	var long := 0.30 if kind != "wheel" else 0.12
	var wide := 0.12 if kind != "wheel" else width
	var c := (Vector2(pos.x, pos.z) - trail_centre) / px + Vector2.ONE * TRAIL_PX / 2.0
	var r := int(ceil(maxf(long, wide) / px)) + 1
	for y in range(int(c.y) - r, int(c.y) + r + 1):
		for x in range(int(c.x) - r, int(c.x) + r + 1):
			if x < 0 or y < 0 or x >= TRAIL_PX or y >= TRAIL_PX:
				continue
			var d := (Vector2(x, y) - c) * px
			var u := d.dot(fwd) / (long / 2.0)  # -1 heel to 1 toe
			var v := d.dot(side) / (wide / 2.0)
			var depth := 0.0
			if kind == "wheel":
				# a flat band with chevron lugs across it
				depth = clampf(1.0 - pow(absf(v), 6.0), 0.0, 1.0) * clampf(2.0 - 2.0 * absf(u), 0.0, 1.0)
				depth *= 0.7 + (0.3 if fposmod((d.dot(fwd) + absf(d.dot(side)) * 0.5) / 0.05, 1.0) >= 0.5 else 0.0)
			else:
				# a rounded boot outline, a little narrower at the arch, with tread bars every 3 cm
				var arch := 1.0 - 0.25 * exp(-u * u * 8.0)
				var e := u * u + pow(v / arch, 2.0)
				depth = clampf((1.0 - e) * 4.0, 0.0, 1.0) * (0.75 + (0.25 if fposmod(d.dot(fwd) / 0.03, 1.0) >= 0.5 else 0.0))
			if depth > 0.0:
				trail.set_pixel(x, y, Color(maxf(trail.get_pixel(x, y).r, depth), 0, 0))
	trail_dirty = true


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and trail:
		var at := Vector2(cam.global_position.x, cam.global_position.z)
		if at.distance_to(trail_centre) > TRAIL_SHIFT:
			_move_trail(at)
	if trail_dirty:
		trail_tex.update(trail)
		trail_dirty = false


## Moves the square to `at` in whole pixels, so the prints that stay inside keep their place exactly.
func _move_trail(at: Vector2) -> void:
	var px := TRAIL_M / TRAIL_PX
	var shift := Vector2i(roundi((at.x - trail_centre.x) / px), roundi((at.y - trail_centre.y) / px))
	var moved := Image.create_empty(TRAIL_PX, TRAIL_PX, false, Image.FORMAT_R8)
	moved.blit_rect(trail, Rect2i(shift, Vector2i(TRAIL_PX, TRAIL_PX)), Vector2i.ZERO)
	trail = moved
	trail_centre += Vector2(shift) * px
	_trail_rect()
	trail_dirty = true


func _trail_rect() -> void:
	material.set_shader_parameter("trail_rect", Vector4(trail_centre.x - TRAIL_M / 2.0, trail_centre.y - TRAIL_M / 2.0, TRAIL_M, TRAIL_M))
