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
## Quality: DESIGN.md `quality` holds named presets (low, medium, high, or names of the game's own, weakest
## first), and set_quality() puts one on the running scene. A game offers them in its settings and starts from
## default_quality().

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
## `still` asks for the role's world-space extras (DESIGN.md `detail`, `lit` and the `weathering` coat). They are
## laid on by world position and would slide over anything that moves, so a moving mesh takes them in its own space.
## `clean` leaves the weathering coat off (DESIGN.md `weathering.clean`: a solar cell someone keeps swept).
static func role(design: Dictionary, name: String, still := false, clean := false) -> Material:
	var cache: Dictionary = design.get_or_add("_roles", {})
	var t: Dictionary = design.materials[name]
	var coated := not clean and _coat(design, t) > 0.0
	still = still and (t.has("detail") or t.has("lit") or coated)
	var key := name + ("+still" if still else "") + ("+clean" if clean else "")
	var moving_detail := not still and (t.has("detail") or coated)
	if cache.has(key):
		return cache[key]
	var color := Color.html(t.color)
	# `opacity` below 1 is glass you see through: alpha blended, so keep it to the few roles that need it
	color.a = float(t.get("opacity", 1.0))
	var glow := float(t.get("emissive", 0))
	var m: Material
	if still or moving_detail or _flat(design):
		# forge models bake their normals, but kit models and built-in meshes only facet here
		var s := ShaderMaterial.new()
		s.set_shader_parameter("albedo", color)
		s.set_shader_parameter("roughness", float(t.get("roughness", 0.6)))
		s.set_shader_parameter("metallic", float(t.get("metalness", 0)))
		s.set_shader_parameter("emission", color * glow)
		s.set_meta("still", still)
		s.set_meta("clean", clean)
		_dress(design, t, s)
		m = s
	else:
		var s := StandardMaterial3D.new()
		s.albedo_color = color
		if color.a < 1.0:
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.cull_mode = BaseMaterial3D.CULL_DISABLED  # a pane is one sheet: seen from both sides
		s.roughness = float(t.get("roughness", 0.6))
		s.metallic = float(t.get("metalness", 0))
		if glow > 0:
			s.emission_enabled = true
			s.emission = color
			s.emission_energy_multiplier = glow
		m = s
	m.resource_name = name
	m.set_meta("clean", clean)  # so a restyle of a merged mesh, which has no node names left, keeps it clean
	m.set_meta("shadow", t.get("shadow", true))  # `shadow: false` is for roles that only ever lie flat on the ground
	cache[key] = m
	return m


static func _flat(design: Dictionary) -> bool:
	return design.get("geometry", {}).get("shading", "smooth") == "flat"


## How much of the `weathering` coat a role takes on a level top: the design's amount times the role's own share.
static func _coat(design: Dictionary, t: Dictionary) -> float:
	return float(design.get("weathering", {}).get("amount", 0)) * float(t.get("weathering", 1))


## The coat's defines and values on `s`, at the quality in force: detail `off` is the plain coat,
## `code` breaks it into patches, `texture` adds the coat's photo (skills/surface-weathering).
static func _dress_coat(design: Dictionary, amount: float, s: ShaderMaterial, defines: PackedStringArray) -> void:
	var w: Dictionary = design.get("weathering", {})
	var level: String = design.get("_quality", {}).get("detail", "off")
	var grain: Texture2D = null
	if level == "texture" and w.has("texture") and ResourceLoader.exists("res://" + str(w.texture)):
		grain = load("res://" + str(w.texture))
	defines.append("COAT")
	if level != "off":
		defines.append("COAT_NOISE")
	if grain:
		defines.append("COAT_GRAIN")
	if not s.get_meta("still", false) and not defines.has("LOCAL"):
		defines.append("LOCAL")
	s.set_shader_parameter("coat_texture", grain)
	s.set_shader_parameter("coat_texture_size", float(w.get("textureSize", 3)))
	s.set_shader_parameter("coat_color", Color.html(w.color))  # style-check makes it required
	s.set_shader_parameter("coat_amount", amount)
	s.set_shader_parameter("coat_side", float(w.get("side", 0.15)))
	s.set_shader_parameter("coat_crevice", float(w.get("crevice", 0.5)))
	s.set_shader_parameter("coat_noise", float(w.get("noise", 1.5)))


static func _variant(defines: PackedStringArray) -> Shader:
	var key := " ".join(defines)
	if not _variants.has(key):
		var lines := ""
		for d_ in defines:
			lines += "#define %s\n" % d_
		var shader := Shader.new()
		shader.code = SURFACE.code.replace("// VARIANT\n", lines)
		_variants[key] = shader
	return _variants[key]


## An official model's own textured material (a `keep` kit role) under the same coat as everything else, so a
## real rover parked at the base is as dusty as the base. Its original rides along as meta "kept", so a theme switch
## rebuilds the coat from it. Without a coat, or without a texture, the original is used as it is.
static func _kept(design: Dictionary, m: Material, still: bool) -> Material:
	var std := m as BaseMaterial3D
	var amount := float(design.get("weathering", {}).get("amount", 0))
	if std == null or std.albedo_texture == null or amount <= 0.0:
		return m
	var cache: Dictionary = design.get_or_add("_kept", {})
	var key := [m, still]
	if not cache.has(key):
		var s := ShaderMaterial.new()
		s.resource_name = m.resource_name
		s.set_meta("kept", m)
		s.set_meta("still", still)
		s.set_shader_parameter("albedo", std.albedo_color)
		s.set_shader_parameter("roughness", std.roughness)
		s.set_shader_parameter("metallic", std.metallic)
		s.set_shader_parameter("base_texture", std.albedo_texture)
		if std.normal_enabled and std.normal_texture:
			s.set_shader_parameter("base_normal", std.normal_texture)
			s.set_shader_parameter("base_normal_scale", std.normal_scale)
		s.set_meta("shadow", true)
		cache[key] = s
	var s: ShaderMaterial = cache[key]
	var defines := PackedStringArray(["KEEP"])
	if s.get_shader_parameter("base_normal"):
		defines.append("KEEP_NORMAL")
	_dress_coat(design, amount, s, defines)
	s.shader = _variant(defines)
	return s


## Gives a role material the shader variant and the values its role has at the quality in force.
## A design nobody has set a quality on shows no detail.
static func _dress(design: Dictionary, t: Dictionary, s: ShaderMaterial) -> void:
	var defines := PackedStringArray(["FLAT"] if _flat(design) else [])
	if float(t.get("opacity", 1.0)) < 1.0:
		defines.append("SEE")
	var still: bool = s.get_meta("still")
	# a moving mesh takes its detail in its own space, so the surface travels with it
	var d: Dictionary = t.get("detail", {})
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
		if not still:
			defines.append("LOCAL")
		for map: String in ["normal", "roughness"]:
			var tex: Texture2D = null
			if photo and d.has(map) and ResourceLoader.exists("res://" + str(d[map])):
				tex = load("res://" + str(d[map]))
				defines.append({"normal": "NORMALMAP", "roughness": "ROUGHMAP"}[map])
			s.set_shader_parameter("detail_" + map, tex)
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
	if not s.get_meta("clean", false) and _coat(design, t) > 0.0:
		_dress_coat(design, _coat(design, t), s, defines)
	s.shader = _variant(defines)


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


static func _pick(design: Dictionary, m: Material, still := false, clean := false) -> Material:
	if m and m.has_meta("kept"):
		m = m.get_meta("kept")  # a coated official material from an earlier design: start again from the original
	clean = clean or (m != null and m.get_meta("clean", false))
	var n := m.resource_name if m else ""
	if design.materials.has(n):
		return role(design, n, still, clean)
	for pattern: String in design.get("kit", {}):
		if pattern.begins_with("#"):
			continue # colour anchors belong to tools/kit-roles.mjs, not name matching
		if RegEx.create_from_string("(?i)" + pattern).search(n):
			if design.kit[pattern] == "keep":
				return _kept(design, m, still)  # an official model's own photo textures, kept on purpose (style-check allows only textured ones)
			return role(design, design.kit[pattern], still, clean)
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
	return role(design, best, still, clean)


## Every mesh under `root` gets the role materials. Returns root.
## Pass `still` for a model that never moves: its roles then show their `detail` and `lit` (see role()).
## A node whose name, or an ancestor's, matches DESIGN.md `weathering.clean` keeps its surfaces free of the coat.
static func apply(root: Node, design: Dictionary, still := false) -> Node:
	var pattern := str(design.get("weathering", {}).get("clean", ""))
	var clean_re := RegEx.create_from_string(pattern) if pattern else null
	var todo: Array = [[root, false]]
	while todo.size():
		var item: Array = todo.pop_back()
		var n: Node = item[0]
		var clean: bool = item[1] or (clean_re != null and clean_re.search(n.name) != null)
		for c in n.get_children():
			todo.append([c, clean])
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _pick(design, mi.get_active_material(i), still and mi.skin == null, clean))
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
	# `sunDisc` is the sun's size in degrees, drawn with a haze around it (`halo`: colour, size in degrees, strength;
	# by default the sun's colour, ten discs wide); 0 draws no sun. `twilight` (colour, azimuth, height in degrees,
	# strength) is a glow along the horizon toward an azimuth, the sun's by default, and needs no disc. `celestial`
	# is a planet's real night sky (_celestial())
	var disc := float(L.get("sunDisc", 0))
	var sky_mat: Material
	var clock: SkyClock = null
	if disc > 0.0 or L.has("twilight") or L.has("celestial"):
		var sm := ShaderMaterial.new()
		# the shader names the global clock, and compiles when it loads: the global must exist first
		# (the list of globals leaves out ones added at run time, so a flag remembers it)
		if not Engine.has_meta(&"forge_sky_clock"):
			RenderingServer.global_shader_parameter_add(&"forge_sky_clock", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
			Engine.set_meta(&"forge_sky_clock", true)
		sm.shader = load("res://addons/forge/sky.gdshader")
		var sun_color := Color.html(L.get("sunColor", "#ffffff"))
		var halo: Dictionary = L.get("halo", {})
		var dusk: Dictionary = L.get("twilight", {})
		var az := deg_to_rad(float(dusk.get("azimuth", L.get("azimuth", 0))))
		sm.set_shader_parameter("top", Color.html(L.sky))
		sm.set_shader_parameter("horizon", Color.html(L.get("horizon", L.sky)))
		sm.set_shader_parameter("ground", Color.html(L.get("ground", L.sky)))
		sm.set_shader_parameter("sun", sun_color)
		sm.set_shader_parameter("disc", deg_to_rad(disc) / 2.0)
		sm.set_shader_parameter("halo_color", Color.html(halo.color) if halo.has("color") else sun_color)
		sm.set_shader_parameter("halo", deg_to_rad(float(halo.get("size", disc * 10.0))))
		sm.set_shader_parameter("halo_strength", float(halo.get("strength", 0.7)))
		sm.set_shader_parameter("twilight_color", Color.html(dusk.get("color", "#ffffff")))
		sm.set_shader_parameter("twilight_dir", Vector3(sin(az), 0.0, cos(az)))  # azimuth as the sun's, below
		sm.set_shader_parameter("twilight_height", deg_to_rad(float(dusk.get("height", 10))))
		sm.set_shader_parameter("twilight_strength", float(dusk.get("strength", 0.0)))
		if L.has("celestial"):
			_celestial(sm, L.celestial)
			clock = SkyClock.new()
		sky_mat = sm
	else:
		var ps := ProceduralSkyMaterial.new()
		ps.sky_top_color = Color.html(L.sky)
		ps.sky_horizon_color = Color.html(L.get("horizon", L.sky))
		ps.ground_horizon_color = Color.html(L.get("ground", L.sky))
		ps.ground_bottom_color = Color.html(L.get("ground", L.sky))
		ps.sun_angle_max = 0.0
		sky_mat = ps
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	# ambient is a colour and not the sky: measured on 4.7.2, sky ambient in the Compatibility renderer
	# ignores ambient_light_energy and lights everything at full sky brightness
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# a cool shade under a warm sun is what keeps shadows from going muddy: `ambientColor`, else the sky
	env.ambient_light_color = Color.html(L.get("ambientColor", L.sky))
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
		# 1 paints the whole sky in the fog colour, which flattens a sky gradient; haze wants it low
		env.fog_sky_affect = float(L.fog.get("sky", 1))
		env.fog_depth_curve = float(L.fog.get("curve", 1))
		# in depth mode density is the most fog anything gets: the engine's 0.01 left the far end 1% fogged
		# (measured on 4.7.2), so `far` meant nothing until this was set. `density` 0.4 to 0.7 keeps a far hill
		env.fog_density = float(L.fog.get("density", 1))
		# `sun`: fog lit by the sun when you look toward it, the haze bleaching around a low sun
		env.fog_sun_scatter = float(L.fog.get("sun", 0))
	var world := WorldEnvironment.new()
	world.environment = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color.html(L.get("sunColor", "#ffffff"))
	sun.light_energy = float(L.get("sun", 2.5)) * UNIT
	sun.shadow_enabled = true
	sun.light_angular_distance = disc  # the sky draws the disc at the light's own angular size
	# every shadow split draws each caster again, and a phone pays for it: two splits, no farther than the fog shows
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = minf(float(L.get("fog", {}).get("far", 60)), 60.0)
	sun.shadow_normal_bias = 4.0  # a split now covers more ground per texel; the default of 2 left ripples on flat tops
	# shadow_blur is not read by the Compatibility renderer (4.7.2 source): the filter is set_quality's `shadowFilter`
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
	for n: Node in [world, sun, clock]:
		if n:
			n.set_meta("house_rig", true)
			parent.add_child(n)
	sun.look_at(Vector3.ZERO)
	return {"world": world, "sun": sun}


## Counts the seconds sky.gdshader turns its night sky by, from when the rig was built: a global shader uniform, as a
## material parameter set every frame would re-render the sky's reflection cubemap over and over.
class SkyClock extends Node:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		RenderingServer.global_shader_parameter_set(&"forge_sky_clock", t)


## A planet's real night sky from DESIGN.md `lighting.celestial` (sky.gdshader, tools/sky-stars.mjs):
##   pole: [RA, Dec] of the planet's north pole (deg, J2000)   latitude: the place (deg, north +)   day: sidereal day (s)
##   radius: the planet's (km)   sun: [RA, Dec] of the sun on the chosen date   hour: local solar hour of the scene
##   timeScale: how many times faster the sky turns than the real one   tau: dust optical depth (horizon dimming)
##   stars: {map, list (from tools/sky-stars.mjs, paths from the project), brightness, milkyWay, milkyColor}
##   planets: [{ra, dec, mag, color}]   moons: [{radius, orbit (km), period (s), start (deg east of the meridian
##   along its orbit at the start; negative rises in the west for a moon faster than the sky), color, brightness}]
## Stars come out with the sun's real elevation at that hour: planets and moons from sunset to civil dusk (-6 deg),
## stars to nautical (-12), the Milky Way to astronomical (-18) (US Naval Observatory twilight definitions).
static func _celestial(sm: ShaderMaterial, C: Dictionary) -> void:
	var dir := func(ra_dec: Array) -> Vector3:
		var ra := deg_to_rad(float(ra_dec[0]))
		var de := deg_to_rad(float(ra_dec[1]))
		return Vector3(cos(de) * cos(ra), cos(de) * sin(ra), sin(de))
	var pole: Vector3 = dir.call(C.pole)
	var node := Vector3(0, 0, 1).cross(pole).normalized()  # where the planet's equator crosses Earth's
	var frame := Basis(node, pole.cross(node), pole)
	var to_eq := frame.transposed()
	var lat := deg_to_rad(float(C.latitude))
	var sun_eq: Vector3 = to_eq * dir.call(C.sun)
	# the sun is on the meridian at noon, and the sky turns 15 degrees a planet hour
	var lst0 := atan2(sun_eq.y, sun_eq.x) + deg_to_rad((float(C.hour) - 12.0) * 15.0)
	var zen := Vector3(cos(lat) * cos(lst0), cos(lat) * sin(lst0), sin(lat))
	var sun_el := rad_to_deg(asin(sun_eq.dot(zen)))
	var scale := float(C.get("timeScale", 1))
	var R := float(C.radius)
	var stars: Dictionary = C.get("stars", {})
	sm.set_shader_parameter("celestial", true)
	sm.set_shader_parameter("frame", frame)
	sm.set_shader_parameter("latitude", lat)
	sm.set_shader_parameter("lst0", lst0)
	sm.set_shader_parameter("spin", TAU / float(C.day) * scale)
	sm.set_shader_parameter("planet_radius", 1.0)
	sm.set_shader_parameter("tau", float(C.get("tau", 0.5)))
	sm.set_shader_parameter("sun_eq", sun_eq)
	sm.set_shader_parameter("moon_fade", clampf(-sun_el / 6.0, 0.0, 1.0))
	sm.set_shader_parameter("star_fade", clampf((-sun_el - 6.0) / 6.0, 0.0, 1.0))
	sm.set_shader_parameter("star_gain", float(stars.get("brightness", 1)))
	sm.set_shader_parameter("milky_gain", float(stars.get("milkyWay", 0.5)) * clampf((-sun_el - 12.0) / 6.0, 0.0, 1.0))
	sm.set_shader_parameter("milky_color", Color.html(stars.get("milkyColor", "#ffffff")))
	for k: String in ["map", "list"]:
		if stars.has(k) and ResourceLoader.exists("res://" + str(stars[k])):
			sm.set_shader_parameter({"map": "star_map", "list": "star_list"}[k], load("res://" + str(stars[k])))
	var dirs := PackedVector4Array()
	var colors := PackedColorArray()
	for p: Dictionary in C.get("planets", []).slice(0, 4):
		var d: Vector3 = to_eq * dir.call([p.ra, p.dec])
		dirs.append(Vector4(d.x, d.y, d.z, float(p.mag)))
		colors.append(Color.html(p.get("color", "#ffffff")))
	dirs.resize(4)  # unused slots are zero: the shader skips them
	colors.resize(4)
	sm.set_shader_parameter("planet_dir", dirs)
	sm.set_shader_parameter("planet_color", colors)
	var orbits := PackedVector4Array()
	var looks := PackedVector4Array()
	for m: Dictionary in C.get("moons", []).slice(0, 2):
		orbits.append(Vector4(float(m.radius) / R, float(m.orbit) / R, lst0 + deg_to_rad(float(m.start)), TAU / float(m.period) * scale))
		var c := Color.html(m.get("color", "#808080")).srgb_to_linear()
		looks.append(Vector4(c.r, c.g, c.b, float(m.get("brightness", 1))))
	orbits.resize(2)
	looks.resize(2)
	sm.set_shader_parameter("moon_orbit", orbits)
	sm.set_shader_parameter("moon_look", looks)


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


## The preset a game starts on before the player has chosen: the one DESIGN.md marks `start: phone` on a phone,
## `start: desktop` elsewhere. A design without marks names its presets low, medium and high.
static func default_quality(design := {}) -> String:
	var phone := ["mobile", "web_android", "web_ios"].any(OS.has_feature)
	var q: Dictionary = design.get("quality", {})
	for level: String in q:
		if q[level].get("start", "") == ("phone" if phone else "desktop"):
			return level
	return "low" if phone else "high"


## Every knob a settings screen may set on its own (set_quality() `overrides`), so the screen is built from data:
## `values` it offers (a number knob takes anything in [first, last]), `default` when a preset leaves it out, and
## `recompile`: a change compiles new shader variants, so warm() behind a cover before showing it (no shader cache
## on the web). `game` knobs are read by the game's own restyle from design["_quality"], not here.
const KNOBS := {
	"msaa": {"values": [0, 2, 4, 8], "default": 0, "recompile": false},
	"pixels": {"values": [0.0, 0.4, 0.6, 1.0, 1.5, 2.1, 4.0], "default": 0.0, "recompile": false},  # 3D Mpx budget, 0 = no cap
	"scale": {"values": [0.5, 0.6, 0.75, 0.85, 1.0], "default": 1.0, "recompile": false},  # under the budget
	"shadows": {"values": [0, 1, 2, 4], "default": 2, "recompile": true},
	"shadowMap": {"values": [512, 1024, 2048, 4096], "default": 2048, "recompile": false},
	"shadowRange": {"values": [15, 25, 40, 60], "default": 60, "recompile": false},
	"shadowFilter": {"values": [0, 1, 2, 3, 4, 5], "default": 2, "recompile": true},
	"normalBias": {"values": [0.0, 2.0, 4.0, 6.0], "default": 4.0, "recompile": false},
	"glow": {"values": [0.0, 0.2, 0.4, 0.5, 0.8], "default": 0.0, "recompile": true},
	"fog": {"values": [true, false], "default": true, "recompile": true},
	"ssao": {"values": [false, true], "default": false, "recompile": true},
	"aniso": {"values": [0, 1, 2, 3, 4], "default": 2, "recompile": false},  # off, 2x, 4x, 8x, 16x
	"detail": {"values": ["off", "code", "texture"], "default": "off", "recompile": true},
	"lamps": {"values": [0, 1, 2, 4, 8, -1], "default": -1, "recompile": true},  # nearest lamps lit, -1 all
	"vsync": {"values": [true, false], "default": true, "recompile": false},
	"maxFps": {"values": [0, 30, 60, 120], "default": 0, "recompile": false},  # 0 = no cap
	"trail": {"values": [512, 1024, 2048], "default": 2048, "recompile": false, "game": true},  # print map pixels
	"particles": {"values": [0.25, 0.5, 0.75, 1.0], "default": 1.0, "recompile": false, "game": true},  # share of dust
	"ground": {"values": ["flat", "cheap", "full"], "default": "full", "recompile": true, "game": true},  # ground shader
}


## The knobs as a settings screen shows them: name -> {values, recompile, game, value (in force), preset (the
## preset's own)}. Knobs the design never mentions report their default.
static func knobs(design: Dictionary) -> Dictionary:
	var q: Dictionary = design.get("_quality", {})
	var preset: Dictionary = design.get("quality", {}).get(design.get("_quality_level", ""), {})
	var out := {}
	for k: String in KNOBS:
		var row: Dictionary = KNOBS[k].duplicate()
		row.value = q.get(k, row.default)
		row.preset = preset.get(k, row.default)
		row.game = row.get("game", false)
		out[k] = row
	return out


## Puts one DESIGN.md `quality` preset on the running scene under `root`, the node apply_lighting() was given, with
## `overrides` (knob -> value, KNOBS) on top: a settings screen passes the player's own choices.
##   msaa: 0, 2, 4 or 8        pixels: the 3D picture's budget in millions of pixels, so a 3x phone and a laptop shade
##   a similar count (scale = min(scale, sqrt(budget / window pixels)), A3 in frame-budget)        scale: a cap under it
##   shadows: 0 for none, else the sun's splits (1, 2 or 4)        shadowMap: its map, in pixels
##   glow: 0 for none, else its strength        lamps: how many lamps shine at once, the nearest ones (absent: all)
##   detail: off, code (each role's `detail` pattern) or texture (its photo, where it names one)
##   aniso: anisotropic filtering level        fog, ssao: on or off        vsync, maxFps: the frame pacing
## Every key is set on every call, so nothing of the preset before is left behind.
static func set_quality(root: Node, design: Dictionary, level: String, overrides := {}) -> void:
	var q: Dictionary = design.get("quality", {}).get(level, {}).duplicate()
	if q.is_empty():
		push_error("house-style: DESIGN.md quality has no preset \"%s\"" % level)
		return
	q.merge(overrides, true)
	design["_quality"] = q  # a role first used after this call takes the same detail
	design["_quality_level"] = level
	var view := root.get_viewport()
	view.msaa_3d = {2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}.get(int(q.get("msaa", 0)), Viewport.MSAA_DISABLED)
	view.anisotropic_filtering_level = int(q.get("aniso", KNOBS.aniso.default)) as Viewport.AnisotropicFiltering
	if not view.has_meta("forge_quality"):
		view.size_changed.connect(func() -> void: _fit_pixels(view, view.get_meta("forge_quality")))
	view.set_meta("forge_quality", q)
	_fit_pixels(view, q)
	# frame pacing only when asked for, or to undo an earlier call's: a preset without it leaves the window as the
	# tools set it, but a player's "V-Sync off" must not outlive the next preset
	if q.has("vsync") or view.has_meta("forge_vsync"):
		view.set_meta("forge_vsync", true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if q.get("vsync", KNOBS.vsync.default) else DisplayServer.VSYNC_DISABLED)
	if q.has("maxFps") or view.has_meta("forge_max_fps"):
		view.set_meta("forge_max_fps", true)
		Engine.max_fps = int(q.get("maxFps", KNOBS.maxFps.default))
	var splits := int(q.get("shadows", 2))
	var map := int(q.get("shadowMap", 2048))
	RenderingServer.directional_shadow_atlas_set_size(map, true)
	for rig in root.get_children():
		if rig is WorldEnvironment and rig.has_meta("house_rig"):
			rig.environment.glow_enabled = float(q.get("glow", 0)) > 0.0
			rig.environment.glow_intensity = float(q.get("glow", 0))
			rig.environment.ssao_enabled = bool(q.get("ssao", false))
			# the design's fog, unless the player turned it off (apply_lighting() makes a new environment each time)
			if not rig.environment.has_meta("fog"):
				rig.environment.set_meta("fog", rig.environment.fog_enabled)
			rig.environment.fog_enabled = rig.environment.get_meta("fog") and q.get("fog", true)
		elif rig is DirectionalLight3D and rig.has_meta("house_rig"):
			rig.shadow_enabled = splits > 0
			rig.directional_shadow_mode = {1: DirectionalLight3D.SHADOW_ORTHOGONAL, 4: DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}.get(
				splits, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
			rig.light_energy = rig.get_meta("energy")[rig.shadow_enabled]
			rig.set_meta("shadow_map", map)  # the engine keeps no getter for it; this is for checks
			# skills/shadows-and-grounding: a low sun throws a hero's shadow far past the near split's default
			# 10%, and the seam cuts it like scissors; size the near split to hold the whole shadow, sun angle
			# by sun angle. `shadowPad` is about the follow camera's distance plus a metre
			var L: Dictionary = design.lighting
			var reach := minf(float(q.get("shadowRange", 60)), float(L.get("fog", {}).get("far", 60)))
			rig.directional_shadow_max_distance = reach
			rig.shadow_normal_bias = float(q.get("normalBias", 4.0))
			var human: float = design.get("geometry", {}).get("human", 1.8)
			var near := human / tan(deg_to_rad(maxf(float(L.get("elevation", 40)), 2.0))) + float(L.get("shadowPad", 6.0))
			rig.directional_shadow_split_1 = clampf(near / reach, 0.1, 0.6)
			RenderingServer.directional_soft_shadow_filter_set_quality(int(q.get("shadowFilter", 2)) as RenderingServer.ShadowQuality)
	for m: Material in design.get("_roles", {}).values():
		if m is ShaderMaterial:
			_dress(design, design.materials[m.resource_name], m)
	for m: Material in design.get("_kept", {}).values():
		_kept(design, m.get_meta("kept"), m.get_meta("still"))
	var pool: Node = root.get_node_or_null("LampPool")
	if int(q.get("lamps", -1)) < 0:
		if pool:
			pool.free()  # on its way out it turns every lamp back on
		return
	if pool == null:
		pool = LampPool.new()
		pool.name = "LampPool"
		root.add_child(pool)
	pool.count = int(q.lamps)


## The 3D picture's scale from the `pixels` budget and the window's real pixels (a phone's canvas has its full
## density on the web), capped by `scale`.
static func _fit_pixels(view: Viewport, q: Dictionary) -> void:
	var scale := float(q.get("scale", 1))
	var budget := float(q.get("pixels", 0)) * 1e6
	var size := Vector2(view.get_window().size) if view.get_window() else view.get_visible_rect().size
	if budget > 0.0 and size.x * size.y > 0.0:
		scale = minf(scale, sqrt(budget / (size.x * size.y)))
	view.scaling_3d_scale = clampf(scale, 0.25, 1.0)


## Draws one of every material under `root` (plus `extra`, materials that are swapped in later, like a fade) in front
## of a camera at `at` for a few frames, under the lights and quality in force, and every particle emitter once:
## Compatibility compiles a shader variant on first sight, and the web build keeps no cache between visits (skills/
## frame-budget section 1). Call it behind a cover at load and after a quality or sky switch, and await it. Each
## distinct render `layers` value seen gets its own copy (a reflection probe's mask makes another variant), and a
## design with lamps gets a lamp over half the stage (a lamp in reach is another variant). Put `at` inside any
## reflection probe the game has.
static func warm(root: Node, design: Dictionary, at: Transform3D, extra: Array = [], frames := 3) -> void:
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--forge-job=")):
		return  # a tool run wants pictures and state, not hitches; every variant on the tools' software GL took minutes
	# each material with what its instances use: the render layers (a probe's reflection mask picks a variant), whether
	# it is drawn instanced (MultiMesh, particles) and whether it casts (a depth variant). Copies of the same variant
	# cost a draw, not a compile; an unused variant costs a compile (seconds on the web), so only these are drawn.
	var mats: Dictionary = {}  # Material -> {layers: {int: true}, inst: {bool: true}, cast: bool}
	var masks := 0
	for p: ReflectionProbe in root.find_children("*", "ReflectionProbe", true, false):
		masks |= p.reflection_mask
	var emitters: Array[GPUParticles3D] = []
	var use := func(m: Material, g: GeometryInstance3D, inst: bool) -> void:
		if m == null:
			return
		var u: Dictionary = mats.get_or_add(m, {"layers": {}, "inst": {}, "cast": false})
		u.layers[g.layers] = true
		if g.layers & masks:
			u.layers[1 << 19] = true  # the same thing outside every probe's box: drawn on a layer no probe reflects
		u.inst[inst] = true
		u.cast = u.cast or g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		use.call(g.material_override, g, false)
		use.call(g.material_overlay, g, false)
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mi := g as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				use.call(mi.get_surface_override_material(i) if mi.get_surface_override_material(i) else mi.mesh.surface_get_material(i), g, false)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
			var mesh := (g as MultiMeshInstance3D).multimesh.mesh
			for i in mesh.get_surface_count():
				use.call(mesh.surface_get_material(i), g, true)
		elif g is GPUParticles3D:
			emitters.append(g)
	for m: Material in extra:
		mats[m] = {"layers": {1: true}, "inst": {false: true}, "cast": false}
	var cam := Camera3D.new()
	var was := root.get_viewport().get_camera_3d()
	if was:
		cam.fov = was.fov
		cam.near = was.near
		cam.far = was.far
	var stage := Node3D.new()
	stage.name = "WarmStage"
	root.add_child(stage)
	stage.global_transform = at
	stage.add_child(cam)
	cam.make_current()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.05
	var lamp := make_lamp(design)
	# with lamps, a second group in a lamp's reach (a lamp in reach is another variant), and one out of it
	for side: float in ([-3.0, 3.0] if lamp else [0.0]):
		var spot := Vector3(side, 0.0, -8.0)
		if lamp and side < 0.0:
			lamp.omni_range = 1.5  # the variant does not depend on the reach; keep the other group out of it
			lamp.position = spot + Vector3(0, 0.5, 0)
			stage.add_child(lamp)
		var k := 0
		for m: Material in mats:
			var u: Dictionary = mats[m]
			for layers: int in u.layers:
				for inst: bool in u.inst:
					var g: GeometryInstance3D
					if inst:
						var mm := MultiMesh.new()
						mm.transform_format = MultiMesh.TRANSFORM_3D
						mm.mesh = box
						mm.instance_count = 1
						g = MultiMeshInstance3D.new()
						(g as MultiMeshInstance3D).multimesh = mm
					else:
						g = MeshInstance3D.new()
						(g as MeshInstance3D).mesh = box
					g.material_override = m
					g.layers = layers
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if u.cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					g.position = spot + Vector3(float(k % 12) * 0.06 - 0.33, float(floori(k / 12.0) % 12) * 0.06 - 0.33, -0.01 * floorf(k / 144.0))
					stage.add_child(g)
					k += 1
		for e in emitters:
			var c := e.duplicate() as GPUParticles3D
			c.visible = true
			c.local_coords = false
			c.preprocess = 0.0
			c.one_shot = false
			c.amount_ratio = 1.0
			c.position = spot
			stage.add_child(c)
			c.emitting = true
			c.restart()
	var tree := root.get_tree()
	for i in frames:
		await tree.process_frame
	if not is_instance_valid(stage):
		return  # the scene went away while it warmed
	if was and is_instance_valid(was):
		was.make_current()
	stage.free()

