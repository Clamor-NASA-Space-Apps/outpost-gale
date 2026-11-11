extends RefCounted
## The DESIGN.md look in Godot. Every project uses this instead of writing its own, so models from the
## forge, from kits and from official sources end up in one style under one light rig.
##
##   var design := Forge.HouseStyle.load_design("res://design.json")   # node tools/design-tokens.mjs DESIGN.md design.json
##   Forge.HouseStyle.apply_lighting(self, design)
##   add_child(Forge.HouseStyle.apply(model, design))
##
## Materials are shared per role: duplicate one before changing it on a single object (hover, fade),
## or every model with that role changes too.
##
## Quality: DESIGN.md `quality` holds named presets (low, medium, high), and set_quality() puts one on
## the running scene. A game offers them in its settings and starts from default_quality().

const SURFACE := preload("surface.gdshader")
const LampPool := preload("lamp_pool.gd")
# DESIGN.md light values were tuned where a light of strength pi on a white surface gives white.
# Godot gets there at energy 1, so every strength is divided by pi to keep one file meaning one look.
const UNIT := 1.0 / PI

static var _variants: Dictionary[String, Shader] = {}


static func load_design(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(d is Dictionary, "%s is not a design token file (node tools/design-tokens.mjs DESIGN.md design.json)" % path)
	return d


## One shared material per role, kept inside the design so a second design gets its own set.
## Its meta "shadow" is false for a role DESIGN.md marks `shadow: false`: whoever draws it may skip the shadow pass.
## `still` asks for the role's world-space extras (DESIGN.md `detail` and `lit`). They are laid on by world
## position and would slide over anything that moves, so only a mesh that never moves may have them.
static func role(design: Dictionary, name: String, still := false) -> Material:
	var cache: Dictionary = design.get_or_add("_roles", {})
	var t: Dictionary = design.materials[name]
	still = still and (t.has("detail") or t.has("lit"))
	var key := name + ("+still" if still else "")
	if cache.has(key):
		return cache[key]
	var color := Color.html(t.color)
	var glow := float(t.get("emissive", 0))
	var m: Material
	if still or _flat(design):
		# forge models bake their normals, but kit models and built-in meshes only facet here
		var s := ShaderMaterial.new()
		s.set_shader_parameter("albedo", color)
		s.set_shader_parameter("roughness", float(t.get("roughness", 0.6)))
		s.set_shader_parameter("metallic", float(t.get("metalness", 0)))
		s.set_shader_parameter("emission", color * glow)
		s.set_meta("still", still)
		_dress(design, t, s)
		m = s
	else:
		var s := StandardMaterial3D.new()
		s.albedo_color = color
		s.roughness = float(t.get("roughness", 0.6))
		s.metallic = float(t.get("metalness", 0))
		if glow > 0:
			s.emission_enabled = true
			s.emission = color
			s.emission_energy_multiplier = glow
		m = s
	m.resource_name = name
	m.set_meta("shadow", t.get("shadow", true))  # `shadow: false` is for roles that only ever lie flat on the ground
	cache[key] = m
	return m


static func _flat(design: Dictionary) -> bool:
	return design.get("geometry", {}).get("shading", "smooth") == "flat"


## Gives a role material the shader variant and the values its role has at the quality in force.
## A design nobody has set a quality on shows no detail.
static func _dress(design: Dictionary, t: Dictionary, s: ShaderMaterial) -> void:
	var defines := PackedStringArray(["FLAT"] if _flat(design) else [])
	var still: bool = s.get_meta("still")
	var d: Dictionary = t.get("detail", {}) if still else {}
	var level: String = design.get("_quality", {}).get("detail", "off")
	var photo: Texture2D = null
	if d.size() and level != "off":
		var file := "res://" + str(d.get("texture", ""))
		if level == "texture" and d.has("texture"):
			if ResourceLoader.exists(file):
				photo = load(file)
			else:
				push_warning("house-style: no texture at %s, the pattern is drawn instead" % file)
		defines.append_array(["DETAIL", "TEXTURE" if photo else "PATTERN_" + str(d.get("pattern", "grain")).to_upper()])
		var size: Variant = d.get("textureSize", 2.0) if photo else d.get("size", 1.0)
		s.set_shader_parameter("detail_size", Vector2(size[0], size[1]) if size is Array else Vector2.ONE * float(size))
		s.set_shader_parameter("detail_strength", float(d.get("strength", 0.4)))
	s.set_shader_parameter("detail_texture", photo)  # null lets go of the photo when a preset drops it
	s.set_meta("lit", still and t.has("lit"))
	if s.get_meta("lit"):
		defines.append("LIT")
		s.set_shader_parameter("lit_color", Color.html(t.lit.color) * float(t.lit.get("emissive", 1)))
		s.set_shader_parameter("lit_share", float(t.lit.get("share", 0.5)))
		s.set_shader_parameter("lit_period", float(t.lit.get("period", 60)))
	var key := " ".join(defines)
	if not _variants.has(key):
		var lines := ""
		for d_ in defines:
			lines += "#define %s\n" % d_
		var shader := Shader.new()
		shader.code = SURFACE.code.replace("// VARIANT\n", lines)
		_variants[key] = shader
	s.shader = _variants[key]


## Adds one surface of a still mesh to a merged one, placed by `at`. For a role with `lit` it first gives every
## island of joined triangles (a window pane) its own number in COLOR, which is what lets panes light up one by one.
static func merge(into: SurfaceTool, mesh: Mesh, surface: int, at: Transform3D, material: Material) -> void:
	if not material.get_meta("lit", false):
		into.append_from(mesh, surface, at)
		return
	var arrays := mesh.surface_get_arrays(surface)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array(range(verts.size()))
	# a flat-shaded pane repeats its corners once per triangle, so islands are joined by where a corner is
	var joined: Dictionary[Vector3, Vector3] = {}
	var root_of := func(p: Vector3) -> Vector3:
		while joined.get_or_add(p, p) != p:
			p = joined[p]
		return p
	for i in range(0, index.size(), 3):
		var a: Vector3 = root_of.call(verts[index[i]].snappedf(0.001))
		for k in [1, 2]:
			joined[root_of.call(verts[index[i + k]].snappedf(0.001))] = a
	var colors := PackedColorArray()
	for v in verts:
		# numbered by where the pane is in the world, so two copies of one house do not blink together
		var n := float(hash((at * root_of.call(v.snappedf(0.001))).snappedf(0.01)) % 251) / 251.0
		colors.append(Color(n, n, n))
	arrays[Mesh.ARRAY_COLOR] = colors
	var numbered := ArrayMesh.new()
	numbered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	into.append_from(numbered, 0, at)


static func _pick(design: Dictionary, m: Material, still := false) -> Material:
	var n := m.resource_name if m else ""
	if design.materials.has(n):
		return role(design, n, still)
	for pattern: String in design.get("kit", {}):
		if pattern.begins_with("#"):
			continue # colour anchors belong to tools/kit-roles.mjs, not name matching
		if RegEx.create_from_string("(?i)" + pattern).search(n):
			return role(design, design.kit[pattern], still)
	var std := m as BaseMaterial3D
	if std and std.albedo_texture:
		push_warning("house-style: textured material \"%s\" kept as is; map it in DESIGN.md kit or retexture it" % n)
		return m
	# nearest colour in RGB: good enough to flag, the fix is a kit entry and not a better metric
	var c := std.albedo_color if std else Color(0.53, 0.53, 0.53)
	var best := ""
	var dist := INF
	for r: String in design.materials:
		if design.materials[r].get("emissive", 0):
			continue # a guessed match must never make a crate glow
		var k := Color.html(design.materials[r].color)
		var d := (k.r - c.r) ** 2 + (k.g - c.g) ** 2 + (k.b - c.b) ** 2
		if d < dist:
			best = r
			dist = d
	push_warning("house-style: material \"%s\" is not in DESIGN.md kit; using nearest role \"%s\"" % [n, best])
	return role(design, best, still)


## Every mesh under `root` gets the role materials. Returns root.
## Pass `still` for a model that never moves: its roles then show their `detail` and `lit` (see role()).
static func apply(root: Node, design: Dictionary, still := false) -> Node:
	var todo: Array[Node] = [root]
	while todo.size():
		var n: Node = todo.pop_back()
		todo.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _pick(design, mi.get_active_material(i), still and mi.skin == null))
	return root


## The one light rig: sky, ambient, sun, tone mapping and fog. Calling it again (a theme switch) replaces the old rig.
static func apply_lighting(parent: Node, design: Dictionary) -> Dictionary:
	var L: Dictionary = design.lighting
	for old in parent.get_children():
		if old.has_meta("house_rig"):
			parent.remove_child(old)
			old.queue_free()
	# a sky that is the sky colour above and the ground colour below gives metals something to reflect:
	# without it they render black
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color.html(L.sky)
	sky_mat.sky_horizon_color = Color.html(L.sky)
	sky_mat.ground_horizon_color = Color.html(L.get("ground", L.sky))
	sky_mat.ground_bottom_color = Color.html(L.get("ground", L.sky))
	sky_mat.sun_angle_max = 0.0
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	# ambient is a colour and not the sky: measured on 4.7.2, sky ambient in the Compatibility renderer
	# ignores ambient_light_energy and lights everything at full sky brightness
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html(L.sky)
	env.ambient_light_energy = float(L.get("ambient", 1)) * UNIT
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = {
		"aces": Environment.TONE_MAPPER_ACES, "agx": Environment.TONE_MAPPER_AGX,
		"filmic": Environment.TONE_MAPPER_FILMIC, "reinhard": Environment.TONE_MAPPER_REINHARDT,
	}.get(L.get("toneMapping", ""), Environment.TONE_MAPPER_LINEAR)
	env.tonemap_exposure = float(L.get("exposure", 1))
	# at the engine's white of 1 a sunlit `body` wall is already at the top of the range (252 of 255, measured);
	# 6 leaves it at 222, with room for a highlight
	env.tonemap_white = 6.0
	if L.has("fog"):
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color.html(L.fog.color)
		env.fog_depth_begin = float(L.fog.near)
		env.fog_depth_end = float(L.fog.far)
	var world := WorldEnvironment.new()
	world.environment = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color.html(L.get("sunColor", "#ffffff"))
	sun.light_energy = float(L.get("sun", 2.5)) * UNIT
	sun.shadow_enabled = true
	# every shadow split draws each caster again, and a phone pays for it: two splits, no farther than the fog shows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = minf(float(L.get("fog", {}).get("far", 60)), 60.0)
	sun.shadow_normal_bias = 4.0  # a split now covers more ground per texel; the default of 2 left ripples on flat tops
	sun.shadow_blur = 2.5  # and its edge showed the texels as a saw; a wider filter costs no more samples
	# same angles as the forge previews; Godot is Y-up, so azimuth turns around Y
	var phi := deg_to_rad(90.0 - float(L.get("elevation", 40)))
	var theta := deg_to_rad(float(L.get("azimuth", 35)))
	sun.position = Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta)) * 50.0
	var shadowed := sun.light_energy
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# The Compatibility renderer draws a shadowed light in a pass of its own and adds it to the picture after
		# tone mapping ("Note on Appearance Changes" in the Lights and shadows docs). Measured on 4.7.2: a day sun
		# plus ambient came out 2.2 times too bright on flat ground, and with that corrected by a plain gamma a
		# moon came out black, because the tone curve's dark end swallowed it. So find the energy at which the
		# two passes add up, on screen, to what one pass would show. No energy does that for every surface: it is
		# solved for the palette's brightest role, so nothing burns out and darker surfaces come out a little under.
		var k := 0.0
		for t: Dictionary in design.materials.values():
			if not t.get("emissive", 0):
				k = maxf(k, Color.html(t.color).srgb_to_linear().get_luminance())
		var a := env.ambient_light_energy * env.ambient_light_color.srgb_to_linear().get_luminance() * k
		var s := sun.light_energy * sun.light_color.srgb_to_linear().get_luminance() * cos(phi) * k
		var want := _on_screen(a + s, env) - _on_screen(a, env)
		var lo := 0.0
		var hi := 16.0
		for i in 40:
			var mid := (lo + hi) / 2.0
			if _on_screen(mid * s, env) < want:
				lo = mid
			else:
				hi = mid
		if s > 0.0 and want > 0.0:
			shadowed *= hi
	# a preset that turns the shadow off (set_quality) needs the plain energy back, or the scene goes dim
	sun.set_meta("energy", {false: sun.light_energy, true: shadowed})
	sun.light_energy = shadowed
	for n: Node in [world, sun]:
		n.set_meta("house_rig", true)
		parent.add_child(n)
	sun.look_at(Vector3.ZERO)
	return {"world": world, "sun": sun}


## How bright a linear value ends up on screen, 0 to 1, by the engine's own tone curves
## (drivers/gles3/shaders/tonemap_inc.glsl, grey only) and the sRGB step after them.
static func _on_screen(x: float, env: Environment) -> float:
	var aces := func(v: float) -> float:
		v *= 1.8
		return (v * (v + 0.0245786) - 0.000090537) / (v * (0.983729 * v + 0.432951) + 0.238081)
	var filmic := func(v: float) -> float:
		v *= 2.0
		return (v * (0.22 * v + 0.03) + 0.002) / (v * (0.22 * v + 0.3) + 0.06) - 0.01 / 0.3
	x *= env.tonemap_exposure
	var w := env.tonemap_white
	match env.tonemap_mode:
		Environment.TONE_MAPPER_REINHARDT:
			x = x * (1.0 + x / (w * w)) / (1.0 + x)
		Environment.TONE_MAPPER_FILMIC:
			x = filmic.call(x) / filmic.call(w)
		Environment.TONE_MAPPER_ACES:
			x = aces.call(x) / aces.call(w)
	# ponytail: AgX is treated as linear here; give it its curve when a design uses it with a shadowed sun
	x = clampf(x, 0.0, 1.0)
	return x * 12.92 if x < 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055


## A game light (streetlamp, window, fire) from DESIGN.md `lighting.lamp`, so a night scene's lamp
## pools stay in the design language too. The world data places it; null if the design has none.
static func make_lamp(design: Dictionary) -> OmniLight3D:
	var l: Variant = design.lighting.get("lamp")
	if l == null:
		return null
	var lamp := OmniLight3D.new()
	lamp.name = "lamp"
	lamp.light_color = Color.html(l.color)
	lamp.light_energy = float(l.get("intensity", 10)) * UNIT
	lamp.omni_range = float(l.get("distance", 10))
	lamp.set_meta("energy", lamp.light_energy)
	lamp.add_to_group(LampPool.GROUP)  # so a quality preset can light only the nearest few
	return lamp


## The preset a game starts on before the player has chosen: a phone gets the light one.
static func default_quality() -> String:
	return "low" if ["mobile", "web_android", "web_ios"].any(OS.has_feature) else "high"


## Puts one DESIGN.md `quality` preset on the running scene under `root`, the node apply_lighting() was given.
##   msaa: 0, 2, 4 or 8        scale: the 3D picture's size as a share of the window
##   shadows: 0 for none, else the sun's splits (1, 2 or 4)        shadowMap: its map, in pixels
##   glow: 0 for none, else its strength        lamps: how many lamps shine at once, the nearest ones (absent: all)
##   detail: off, code (each role's `detail` pattern) or texture (its photo, where it names one)
## Every key is set on every call, so nothing of the preset before is left behind.
static func set_quality(root: Node, design: Dictionary, level: String) -> void:
	var q: Dictionary = design.get("quality", {}).get(level, {})
	if q.is_empty():
		push_error("house-style: DESIGN.md quality has no preset \"%s\"" % level)
		return
	design["_quality"] = q  # a role first used after this call takes the same detail
	var view := root.get_viewport()
	view.msaa_3d = {2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}.get(int(q.get("msaa", 0)), Viewport.MSAA_DISABLED)
	view.scaling_3d_scale = float(q.get("scale", 1))
	var splits := int(q.get("shadows", 2))
	var map := int(q.get("shadowMap", 2048))
	RenderingServer.directional_shadow_atlas_set_size(map, true)
	for rig in root.get_children():
		if rig is WorldEnvironment and rig.has_meta("house_rig"):
			rig.environment.glow_enabled = float(q.get("glow", 0)) > 0.0
			rig.environment.glow_intensity = float(q.get("glow", 0))
		elif rig is DirectionalLight3D and rig.has_meta("house_rig"):
			rig.shadow_enabled = splits > 0
			rig.directional_shadow_mode = {1: DirectionalLight3D.SHADOW_ORTHOGONAL, 4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}.get(
				splits, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
			rig.light_energy = rig.get_meta("energy")[rig.shadow_enabled]
			rig.set_meta("shadow_map", map)  # the engine keeps no getter for it; this is for checks
	for m: Material in design.get("_roles", {}).values():
		if m is ShaderMaterial:
			_dress(design, design.materials[m.resource_name], m)
	var pool: Node = root.get_node_or_null("LampPool")
	if not q.has("lamps"):
		if pool:
			pool.free()  # on its way out it turns every lamp back on
		return
	if pool == null:
		pool = LampPool.new()
		pool.name = "LampPool"
		root.add_child(pool)
	pool.count = int(q.lamps)
