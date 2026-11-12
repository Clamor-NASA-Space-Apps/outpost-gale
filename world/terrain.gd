extends Node3D
## The ground. data/terrain.json is the one height source: the patch mesh, its collision and height_at()
## all read it. The far skyline is models/terrain_backdrop.glb. Both are drawn by terrain.gdshader.

const SHADER := preload("res://world/terrain.gdshader")
const CHUNK := 100  # cells per side of one patch mesh: 200 m pieces, four in all (100 m ones drew 5 or 6 a view, each twice in sunlight)
# The trail map: footprints and wheel tracks pressed into the dust, in a square that follows the camera.
# 3 cm a pixel: a boot print (about 30 x 12 cm) is 10 x 4 px, enough for its tread. The square is DESIGN.md
# quality `trail` pixels wide (2048 is 64 m).
const TRAIL_MPX := 0.03125
const TILE := 64  # pixels: a print uploads the tiles it touched, never the whole map
const MOVERS := 12  # contact discs for things that move (terrain.gdshader `movers`)

var step: float
var cols: int
var rows: int
var origin: Vector2
var heights: PackedFloat32Array
var material: ShaderMaterial
var trail: Image  # the prints, on the CPU; the GPU's copy is trail_view's texture
var trail_view: SubViewport
var trail_px := 0
var trail_win := Vector2i.ZERO  # the square's corner, in pixels from the world origin
var trail_centre := Vector2.ZERO  # its middle, metres
var trail_dirty := false  # tiles or clears wait for the GPU
var _tiles: Dictionary[Vector2i, bool] = {}  # tiles of the map changed since the last upload
var _clears: Array[Rect2i] = []  # map rects zeroed since the last upload
var _patches: Array[Sprite2D] = []
var _wipes: Array[ColorRect] = []
static var _shaders: Dictionary = {}  # terrain.gdshader per `ground` variant
var _cmap := PackedByteArray()  # the contact map (contacts())
var _ctex: ImageTexture


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
	var back: Node3D = load("res://models/terrain_backdrop.glb").instantiate()  # a web build has no file paths, only res://
	for mi: MeshInstance3D in back.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = material
		mi.set_instance_shader_parameter("backdrop", 1.0)  # not drawn over the patch (terrain.gdshader)
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
	# DESIGN.md quality `ground`: full, cheap or flat (no photo fetched at all); without it, the role detail decides
	var kind: String = design.get("_quality", {}).get("ground", "flat" if level == "off" else "full")
	if not _shaders.has(kind):
		_shaders[kind] = Shader.new()
		_shaders[kind].code = SHADER.code.replace("// VARIANT\n", {"flat": "#define GROUND_FLAT\n", "cheap": "#define GROUND_CHEAP\n"}.get(kind, ""))
	material.shader = _shaders[kind]
	var px := int(design.get("_quality", {}).get("trail", 2048))
	if px != trail_px:
		_trail_setup(px)


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


## The ground's answer under everything resting on it: each foot (x, z) darkens a soft disc `radius` wide into a map
## over the play area, which the shader turns into ambient occlusion, a little darker dust and a faint rim of dust
## pushed up (data/world.json `grounding`). Feet within one pixel are drawn once. With `area` (world x, z) only that
## part is drawn again: a whole redraw in a script loop took 12 ms, a frame lost on every bag picked up.
func contacts(feet: PackedVector2Array, g: Dictionary, half: float, area := Rect2()) -> void:
	var px := int(g.px)
	var m := 2.0 * half / px
	var r := float(g.radius)
	var reach := int(ceil(r / m))
	var box := Rect2i(0, 0, px, px)
	if _cmap.size() != px * px or not area.has_area():
		_cmap.resize(px * px)
		_cmap.fill(0)
	else:
		var a := area.grow(r)
		box = Rect2i(Vector2i(floori((a.position.x + half) / m), floori((a.position.y + half) / m)), Vector2i(ceili(a.size.x / m) + 1, ceili(a.size.y / m) + 1)).intersection(box)
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				_cmap[y * px + x] = 0
	var seen: Dictionary = {}
	var near := box.grow(reach)
	for f in feet:
		var c := Vector2i(int((f.x + half) / m), int((f.y + half) / m))
		if seen.has(c) or not near.has_point(c):
			continue
		seen[c] = true
		for y in range(maxi(c.y - reach, box.position.y), mini(c.y + reach + 1, box.end.y)):
			for x in range(maxi(c.x - reach, box.position.x), mini(c.x + reach + 1, box.end.x)):
				var d := Vector2(x - c.x, y - c.y).length() * m / r
				if d < 1.0:
					_cmap[y * px + x] = maxi(_cmap[y * px + x], int(255.0 * (1.0 - d) * (1.0 - d)))
	var img := Image.create_from_data(px, px, false, Image.FORMAT_R8, _cmap)
	if _ctex and _ctex.get_size() == Vector2(px, px):
		_ctex.update(img)
	else:
		_ctex = ImageTexture.create_from_image(img)
	material.set_shader_parameter("contact_map", _ctex)
	material.set_shader_parameter("contact_rect", Vector4(-half, -half, 2.0 * half, 2.0 * half))
	material.set_shader_parameter("contact_ao", float(g.ao))
	material.set_shader_parameter("contact_albedo", float(g.albedo))
	material.set_shader_parameter("contact_pile", float(g.pile))


## Contacts that move (world.touch()): at most MOVERS discs Vector4(x, z, radius, strength), darkened like the map's.
func movers(discs: PackedVector4Array) -> void:
	discs.resize(MOVERS)  # unused slots are zero: no radius, no strength
	material.set_shader_parameter("movers", discs)


## A print pressed into the dust: `foot_l` / `foot_r` (a boot with tread) or `wheel` (`width` wide, along `yaw`),
## `strength` (0 to 1) as deep as a full print; a fainter one never lightens a deeper one already there.
## Prints stay where they are made; they only fade when the square moves away from them.
## The map wraps (toroidal addressing, GPU Gems 2 ch. 2): world pixel g lives at g mod trail_px, so the square
## follows the camera without moving a byte, and only the strip that wraps in is cleared.
func mark(pos: Vector3, yaw_deg: float, kind: String, width := 0.3, strength := 1.0) -> void:
	var px := TRAIL_MPX
	var fwd := Vector2(sin(deg_to_rad(yaw_deg)), -cos(deg_to_rad(yaw_deg)))  # x, z of the heading
	var side := Vector2(-fwd.y, fwd.x)
	var long := 0.30 if kind != "wheel" else 0.12
	var wide := 0.12 if kind != "wheel" else width
	var c := Vector2(pos.x, pos.z) / px
	var r := int(ceil(maxf(long, wide) / px)) + 1
	var win := Rect2i(trail_win, Vector2i(trail_px, trail_px))
	for y in range(floori(c.y) - r, floori(c.y) + r + 1):
		for x in range(floori(c.x) - r, floori(c.x) + r + 1):
			if not win.has_point(Vector2i(x, y)):
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
			depth *= strength
			if depth > 0.0:
				var tx := posmod(x, trail_px)
				var ty := posmod(y, trail_px)
				trail.set_pixel(tx, ty, Color(maxf(trail.get_pixel(tx, ty).r, depth), 0, 0))
				_tiles[Vector2i(tx / TILE, ty / TILE)] = true
	trail_dirty = true


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and trail:
		var at := Vector2(cam.global_position.x, cam.global_position.z)
		if at.distance_to(trail_centre) > trail_px * TRAIL_MPX / 4.0:
			_move_trail(at)
	if trail_dirty:
		_upload()


## The prints changed since the last frame, to the GPU: each changed tile drawn over its place in trail_view, wrapped-in
## strips wiped first. A whole-map ImageTexture.update() sent 4 MB per print and missed vsync (profile of 12 Nov).
func _upload() -> void:
	for i in _wipes.size():
		_wipes[i].visible = i < _clears.size()
		if i < _clears.size():
			_wipes[i].position = _clears[i].position
			_wipes[i].size = _clears[i].size
	_clears = _clears.slice(_wipes.size())
	var n := 0
	for t: Vector2i in _tiles.keys():
		if n == _patches.size():
			break  # the rest go next frame
		var patch := _patches[n]
		(patch.texture as ImageTexture).update(trail.get_region(Rect2i(t * TILE, Vector2i(TILE, TILE))))
		patch.position = Vector2(t * TILE)
		patch.visible = true
		_tiles.erase(t)
		n += 1
	for i in range(n, _patches.size()):
		_patches[i].visible = false
	trail_dirty = not (_tiles.is_empty() and _clears.is_empty())
	trail_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## A new, empty map `px` wide (a quality switch to another size drops the prints).
func _trail_setup(px: int) -> void:
	trail_px = px
	trail = Image.create_empty(px, px, false, Image.FORMAT_R8)
	if trail_view:
		trail_view.free()
	_patches.clear()
	_wipes.clear()
	_tiles.clear()
	_clears.clear()
	trail_view = SubViewport.new()
	trail_view.name = "Trail"
	trail_view.size = Vector2i(px, px)
	trail_view.disable_3d = true
	trail_view.transparent_bg = true  # cleared to 0: no print
	trail_view.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	trail_view.render_target_update_mode = SubViewport.UPDATE_ONCE  # the first draw clears it
	add_child(trail_view)
	# made now, not while playing: nothing is allocated per print
	for i in 8:
		var w := ColorRect.new()
		w.color = Color(0, 0, 0, 1)
		w.visible = false
		trail_view.add_child(w)
		_wipes.append(w)
	for i in 48:  # a rover's frame touches a few tiles; a burst over this waits a frame
		var p := Sprite2D.new()
		p.centered = false
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.z_index = 1  # over the wipes
		p.texture = ImageTexture.create_from_image(Image.create_empty(TILE, TILE, false, Image.FORMAT_R8))
		p.visible = false
		trail_view.add_child(p)
		_patches.append(p)
	material.set_shader_parameter("trail_map", trail_view.get_texture())
	var at := trail_centre
	trail_win = Vector2i(roundi(at.x / TRAIL_MPX), roundi(at.y / TRAIL_MPX)) - Vector2i(px, px) / 2
	_trail_rect()


## Moves the square to `at` in whole pixels. Prints inside both squares stay put; the strip that wraps in is zeroed.
func _move_trail(at: Vector2) -> void:
	var old := Rect2i(trail_win, Vector2i(trail_px, trail_px))
	trail_win = Vector2i(roundi(at.x / TRAIL_MPX), roundi(at.y / TRAIL_MPX)) - Vector2i(trail_px, trail_px) / 2
	var now := Rect2i(trail_win, Vector2i(trail_px, trail_px))
	var keep := now.intersection(old)
	var fresh: Array[Rect2i] = [now]
	if keep.has_area():
		fresh = [Rect2i(now.position.x, now.position.y, keep.position.x - now.position.x, trail_px),
			Rect2i(keep.end.x, now.position.y, now.end.x - keep.end.x, trail_px),
			Rect2i(keep.position.x, now.position.y, keep.size.x, keep.position.y - now.position.y),
			Rect2i(keep.position.x, keep.end.y, keep.size.x, now.end.y - keep.end.y)]
	for r in fresh:
		if not r.has_area():
			continue
		# a rect no wider than the map falls in at most two pieces along each axis once wrapped
		var x0 := posmod(r.position.x, trail_px)
		var y0 := posmod(r.position.y, trail_px)
		for xs: Vector2i in [Vector2i(x0, mini(r.size.x, trail_px - x0)), Vector2i(0, r.size.x - (trail_px - x0))]:
			for ys: Vector2i in [Vector2i(y0, mini(r.size.y, trail_px - y0)), Vector2i(0, r.size.y - (trail_px - y0))]:
				if xs.y > 0 and ys.y > 0:
					var piece := Rect2i(xs.x, ys.x, xs.y, ys.y)
					trail.fill_rect(piece, Color(0, 0, 0))
					_clears.append(piece)
	_trail_rect()
	trail_dirty = true


func _trail_rect() -> void:
	trail_centre = (Vector2(trail_win) + Vector2.ONE * trail_px / 2.0) * TRAIL_MPX
	material.set_shader_parameter("trail_rect", Vector4(trail_win.x * TRAIL_MPX, trail_win.y * TRAIL_MPX, trail_px * TRAIL_MPX, trail_px * TRAIL_MPX))
