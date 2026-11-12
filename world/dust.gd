extends Node3D
## Dust in the air, all GPU particles (the Compatibility renderer has no trails, no sub-emitters and no
## emit_particle()):
## - puff(): a boot or a wheel on the dust (skills/ground-contact-fx, design/research/dust.md). Grit: many
##   small grains in short ballistic arcs under Mars gravity, gone when they land. Haze: a few wide, faint
##   quads at ankle height that spread, slow, drift downwind and fade in 2 to 3 s. The print is terrain.mark().
## - streaks: faint lines low over the ground around the camera, at the wind's speed, more of them in a gust
##   (world.gust(): "dust blowing across the ground appears as pale horizontal streak", NASA, Gale sol 1597).
## - a dust devil wandering far off (seen crossing the crater floor on summer afternoons), day only.
## - the storm front: big slow clouds close around the camera, the storm state only.
## What shows in which sky is data/world.json `weather`; the wind's direction is `wind`.

const DUST := preload("res://world/dust.gdshader")
const GRIT := 6  # grit lives under half a second at a walk, so a few emitters cover any walk or drive
const HAZE := 8  # haze lives 2.5 s and a walk lands a foot every half second or so

var wind := Vector3.ZERO
var grit: Array[GPUParticles3D] = []
var haze: Array[GPUParticles3D] = []
var streaks: GPUParticles3D
var devil: GPUParticles3D
var front: GPUParticles3D
var _world: Node3D
var _soft: StandardMaterial3D  # one billboard material for every cloud, so one restyle reaches them all
var _column: StandardMaterial3D  # the dust devil's: ground-coloured, so it shows against the pale sky
var _line: StandardMaterial3D
var _dir: Vector3  # where the wind blows to, flat
var _devil_angle := 0.0
var _haze_mat: ShaderMaterial
var _wheel_haze_mat: ShaderMaterial  # a rover's trail: paler than a boot's puff, or it vanished against the ground
var _grit_mat: ShaderMaterial
var _c: Dictionary  # data/world.json `contact`
var _g: float  # gravity, from the reality sheet
var _live: Dictionary = {}  # emitter -> {kind, age, life, top}: what is in flight, for checks and for hiding
var _next_grit := 0  # the oldest of each pool, reused next
var _next_haze := 0
var _streams: Dictionary = {}  # id -> {grit, haze, off}: emitters that run while a wheel rolls (stream())
var _streak_share := 0.0  # the sky state's share of streaks; a gust shows all of it, a lull a quarter
## Render layers for emitters made after build(): world.gd puts the dust on the ground's layer, which the base's
## reflection probe does not shade. A stream made later on layer 1 took the probe's light and glowed at night.
var layers := 1
var _share := 1.0  # DESIGN.md quality `particles`: the share of every emitter's grains a preset draws
static var _shaders: Dictionary = {}  # dust.gdshader per variant: one compile serves every material made from it


func build(world: Node3D) -> void:
	_world = world
	var yaw := deg_to_rad(float(world.data.wind.toward_deg))
	_dir = Vector3(sin(yaw), 0, -cos(yaw))  # CONTRACTS.md: yaw clockwise from north, north is -Z
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 1, 1, 1))
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	_soft = _material(dot, BaseMaterial3D.BILLBOARD_PARTICLES)
	_line = _material(dot, BaseMaterial3D.BILLBOARD_DISABLED)

	_c = world.data.contact
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json")).rows:
		if r.id == "world.gravity":
			_g = float(r.value)
	# grains are cut out and opaque: no blending, no sorting, no overdraw; the dot's soft edge cut by the
	# scissor makes the last tenth's fade a shrink rather than a pop
	_grit_mat = _ground_lit(dot, true)
	_haze_mat = _ground_lit(_blot(), false)
	_wheel_haze_mat = _ground_lit(_blot(), false)
	var gs := float(_c.grit_size)
	for i in GRIT:
		var e := _emitter("Grit%d" % i, int(_c.grit), 0.5, Vector2(gs, gs), _grit_mat, [1.0, 1.0, 1.0], [1.0, 1.0])
		var pm: ParticleProcessMaterial = e.process_material
		var fade := Gradient.new()  # opaque, then the last tenth fades
		fade.offsets = PackedFloat32Array([0.0, 0.9, 1.0])
		fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
		pm.color_ramp.gradient = fade
		pm.gravity = Vector3(0, -_g, 0)  # ballistic, no damping: the sheet's g and nothing else
		pm.scale_min = 0.6
		pm.scale_max = 1.6
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.06  # a sole's width
		grit.append(_pooled(e))
	var hs: Array = _c.haze_size
	for i in HAZE:
		var e := _emitter("Haze%d" % i, int(_c.haze), float(_c.haze_life), Vector2(hs[0], hs[1]), _haze_mat,
			[0.0, float(_c.haze_alpha), 0.0], [0.6, 1.6])
		if i > 0:
			e.process_material = haze[0].process_material  # one material, so a wind change reaches all
		haze.append(_pooled(e))
	var hp: ParticleProcessMaterial = haze[0].process_material
	hp.direction = Vector3.RIGHT
	hp.spread = 180.0
	hp.flatness = 1.0  # out sideways along the ground, in every direction (Lemmon 2022)
	hp.initial_velocity_min = float(_c.haze_burst) * 0.5
	hp.initial_velocity_max = float(_c.haze_burst)
	# quadratic drag: the burst stops quickly and the wind's push settles at the wind's speed (restyle)
	hp.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_DAMPING_AS_FRICTION, true)

	streaks = _emitter("Streaks", 160, 1.6, Vector2(0.025, 1.1), _line, [0.0, 0.16, 0.0], [1.0, 1.0])
	streaks.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	var sp: ParticleProcessMaterial = streaks.process_material
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(22, 0.35, 22)
	sp.spread = 4.0

	front = _emitter("Front", 48, 9.0, Vector2(14, 14), _soft, [0.0, 0.28, 0.0], [0.7, 1.3])
	var fp: ParticleProcessMaterial = front.process_material
	fp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fp.emission_ring_axis = Vector3.UP
	fp.emission_ring_radius = 70.0
	fp.emission_ring_inner_radius = 14.0
	fp.emission_ring_height = 6.0
	fp.spread = 20.0
	front.preprocess = front.lifetime

	# a devil the colour of the haze vanished against the sky from the base (measured, 160 m off): the column is
	# the ground's own dust, denser
	_column = _material(dot, BaseMaterial3D.BILLBOARD_PARTICLES)
	# unshaded: lit as a solid, its billboards went black seen toward the sun, like smoke, where real dust
	# glows (it scatters light forward). It only shows in the day sky, so one flat colour holds
	_column.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	devil = _emitter("Devil", 200, 7.0, Vector2(4.0, 4.0), _column, [0.0, 0.75, 0.0], [0.6, 3.2])
	devil.local_coords = true  # the node spins, so the column swirls
	devil.preprocess = devil.lifetime  # a whole column at once, not a puff growing for 7 s after a sky switch
	devil.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 50, 40))
	var dp: ParticleProcessMaterial = devil.process_material
	dp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	dp.emission_ring_axis = Vector3.UP
	dp.emission_ring_radius = 1.4
	dp.emission_ring_inner_radius = 0.4
	dp.emission_ring_height = 0.4
	dp.direction = Vector3.UP
	dp.spread = 6.0
	dp.initial_velocity_min = 4.0
	dp.initial_velocity_max = 6.0
	dp.radial_velocity_min = 0.3  # the column widens as it climbs
	dp.radial_velocity_max = 0.9


## Colours from the design's `dust` role (the sky's light does the rest: the clouds are lit), and the weather row.
func restyle(design: Dictionary, weather: Dictionary) -> void:
	# grit is the ground itself, lit like it; the colour is the dust role's, a fixed preset per surface
	_grit_mat.set_shader_parameter("albedo", Color.html(design.materials.dust.color))
	# a fifth of the way to the horizon's colour: half way, a puff at a boot was a bright orange patch against the
	# shaded ground under a sunset (13 Nov playtest)
	_haze_mat.set_shader_parameter("albedo", Color.html(design.materials.dust.color).lerp(Color.html(design.lighting.horizon), 0.2))
	_wheel_haze_mat.set_shader_parameter("albedo", Color.html(design.materials.dust.color).lerp(Color.html(design.lighting.horizon), 0.65))
	_column.albedo_color = Color.html(design.materials.dust.color).lerp(Color.html(design.lighting.horizon), 0.15)
	for m: StandardMaterial3D in [_soft, _line]:
		# fine dust in the air is paler than the ground it rose from: it takes on the haze, and a cloud the
		# colour of the ground vanished against it (measured: the first puffs did not show)
		m.albedo_color = Color.html(design.materials.dust.color).lerp(Color.html(design.lighting.horizon), 0.5)
	_share = float(design.get("_quality", {}).get("particles", 1.0))
	wind = _dir * float(weather.wind)
	# low over the ground: streaks at the wind's speed and gusts a little over, the front slower
	for e: GPUParticles3D in [streaks, front]:
		var pm: ParticleProcessMaterial = e.process_material
		pm.direction = _dir
		pm.initial_velocity_min = wind.length() * (0.8 if e == streaks else 0.3)
		pm.initial_velocity_max = wind.length() * (1.4 if e == streaks else 0.6)
	# the haze is pushed by the wind against quadratic drag, which balances at the wind's speed:
	# damping = 20 a / v^2 (engine source, skills/ground-contact-fx); `a` sets how soon it gets there
	var push := maxf(wind.length(), 0.01)
	for e: GPUParticles3D in [haze[0]] + _streams.values().map(func(st: Dictionary) -> GPUParticles3D: return st.haze):
		var hp: ParticleProcessMaterial = e.process_material
		hp.gravity = _dir * push
		hp.damping_min = 20.0 * push / (push * push)
		hp.damping_max = hp.damping_min
	_streak_share = float(weather.streaks)
	streaks.amount_ratio = _streak_share * _share
	streaks.emitting = _streak_share > 0.0
	devil.emitting = bool(weather.devil)
	devil.visible = devil.emitting
	front.emitting = bool(weather.front)
	front.visible = front.emitting


## A boot or a wheel touching the dust at `pos`. `vel` is the foot's (or the wheel rim's) world velocity at
## contact, and the grit goes that way: ahead of a boot, behind a wheel (its rim moves backward at the
## ground). `strength` 0 to 1 scales how much is thrown, `kind` is "foot" or "wheel". Standing still throws nothing.
func puff(pos: Vector3, vel: Vector3, strength: float, kind := "foot") -> void:
	var v := vel.length()
	if v < float(_c.min_speed) or strength <= 0.0:
		return
	var flat := Vector3(vel.x, 0, vel.z)
	var ahead := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var angles: Array = _c.launch_deg
	if kind == "wheel":
		angles = _c.wheel_launch_deg  # the fenders keep a wheel's throw low
	var e := grit[_next_grit]
	_next_grit = (_next_grit + 1) % GRIT
	var pm: ParticleProcessMaterial = e.process_material
	var mid := deg_to_rad((float(angles[0]) + float(angles[1])) / 2.0)
	pm.direction = ahead * cos(mid) + Vector3.UP * sin(mid)
	pm.spread = (float(angles[1]) - float(angles[0])) / 2.0
	var fast := v * (1.0 + float(_c.speed_spread))
	pm.initial_velocity_min = v * (1.0 - float(_c.speed_spread))
	pm.initial_velocity_max = fast
	var steep := sin(deg_to_rad(float(angles[1])))
	# every grain has landed by the flight time of the fastest, steepest one
	e.lifetime = 2.0 * fast * steep / _g
	_fire(e, pos, strength, {"kind": kind, "life": e.lifetime, "top": pow(fast * steep, 2.0) / (2.0 * _g)})
	_fire(haze[_next_haze], pos + Vector3(0, 0.03, 0), strength, {"kind": "haze", "life": float(_c.haze_life), "top": 0.05})
	_next_haze = (_next_haze + 1) % HAZE


## A wheel rolling on the dust: grit and haze stream from `pos` (behind the contact) for as long as it rolls, so
## a drive leaves a steady low trail. A puff per wheel print restarted one of six shared emitters 20 times a second,
## and every grain died a few frames old: nothing showed (13 Nov playtest). `vel` is the tread's world velocity,
## `strength` 0 to 1 (0 stops it; grains in flight land first). Call it every physics frame while the wheel
## rolls: a stream not called for a frame stops (13 Nov playtest: dust kept coming from a parked rover after its
## driver got out). data/world.json `contact` wheel_*.
func stream(id: String, pos: Vector3, vel: Vector3, strength: float) -> void:
	var on := strength > 0.0 and vel.length() >= float(_c.min_speed)
	if not _streams.has(id):
		if not on:
			return
		_stream(id)
	var st: Dictionary = _streams[id]
	st.frame = Engine.get_physics_frames()
	var g: GPUParticles3D = st.grit
	var h: GPUParticles3D = st.haze
	g.emitting = on
	h.emitting = on
	if on:
		st.off = 0.0
		g.visible = true
		h.visible = true
		var flat := Vector3(vel.x, 0, vel.z).normalized()
		var angles: Array = _c.wheel_launch_deg
		var mid := deg_to_rad((float(angles[0]) + float(angles[1])) / 2.0)
		var gp: ParticleProcessMaterial = g.process_material
		gp.direction = flat * cos(mid) + Vector3.UP * sin(mid)
		gp.initial_velocity_min = vel.length() * (1.0 - float(_c.speed_spread))
		gp.initial_velocity_max = vel.length() * (1.0 + float(_c.speed_spread))
		g.amount_ratio = clampf(strength, 0.05, 1.0) * _share
		h.amount_ratio = clampf(strength, 0.05, 1.0) * _share
		g.global_position = pos
		h.global_position = pos + Vector3(0, 0.03, 0)


## A stream rolled for a moment at `at`, behind the shader warm-up's cover (sandbox): the first stream made in play
## cost 190 ms on a cold cache, and only a stream made and run after load took that cost away (one made in build()
## and run did not; measured 12 Nov). Hidden again a fifth of a second later.
func warm(at: Vector3) -> void:
	stream("_warm", at, _dir * 2.0, 1.0)
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		_streams["_warm"].grit.visible = false
		_streams["_warm"].haze.visible = false)


## A stream's two emitters, made once per id.
func _stream(id: String) -> void:
	# grains fly at the tread's speed: the lifetime is the flight of the fastest, at the rover's top speed
	var angles: Array = _c.wheel_launch_deg
	var fast := float(_world.sheet_values["rover.speed.max"]) * (1.0 + float(_c.speed_spread))
	var gs := float(_c.wheel_grit_size)
	var g := _emitter("Stream_" + id, int(_c.wheel_grit), 2.0 * fast * sin(deg_to_rad(float(angles[1]))) / _g, Vector2(gs, gs), _grit_mat, [1.0, 1.0, 1.0], [1.0, 1.0])
	var gp: ParticleProcessMaterial = g.process_material
	gp.color_ramp = (grit[0].process_material as ParticleProcessMaterial).color_ramp
	gp.gravity = Vector3(0, -_g, 0)
	gp.scale_min = 0.6
	gp.scale_max = 1.6
	gp.spread = (float(angles[1]) - float(angles[0])) / 2.0
	gp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	gp.emission_sphere_radius = 0.12  # about a tread's half width
	var hs: Array = _c.wheel_haze_size
	var h := _emitter("StreamHaze_" + id, int(_c.wheel_haze), float(_c.haze_life), Vector2(hs[0], hs[1]), _wheel_haze_mat, [0.0, float(_c.wheel_haze_alpha), 0.0], [0.6, 1.6])
	# the haze's motion (restyle() keeps the wind on both), with its own fade: the alpha lives in the process
	# material's colour ramp, and sharing the puffs' left the trail at their 0.07, invisible
	var hp := (haze[0].process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	hp.color_ramp = (h.process_material as ParticleProcessMaterial).color_ramp
	h.process_material = hp
	g.layers = layers
	h.layers = layers
	_streams[id] = {"grit": g, "haze": h, "off": 0.0, "frame": 0}


## What is in flight: [{kind, age, life, top}], `top` the highest a grain can get (analytic H).
func contact_state() -> Array:
	return _live.values()


func _fire(e: GPUParticles3D, at: Vector3, strength: float, info: Dictionary) -> void:
	info.age = 0.0
	_live[e] = info
	e.global_position = at
	e.amount_ratio = clampf(strength, 0.1, 1.0) * _share
	e.visible = true
	e.restart()


## A spent emitter still costs a draw call, so it hides until it is reused.
func _pooled(e: GPUParticles3D) -> GPUParticles3D:
	e.one_shot = true
	e.explosiveness = 1.0
	e.emitting = false
	e.visible = false
	return e


## An irregular soft blot for the haze: a round falloff broken up by noise, so no ball and no hard quad edge.
func _blot() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var r := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a := clampf(1.0 - r, 0.0, 1.0) * clampf(0.6 + noise.get_noise_2d(x, y), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	for e: GPUParticles3D in _live.keys():
		_live[e].age += delta
		if _live[e].age >= _live[e].life:
			e.visible = false
			_live.erase(e)
	for st: Dictionary in _streams.values():
		var h: GPUParticles3D = st.haze
		if h.emitting and Engine.get_physics_frames() - int(st.frame) > 1:
			# nobody rolls it any more (the driver got out): a wheel that is not driven throws nothing
			h.emitting = false
			st.grit.emitting = false
		if not h.emitting and h.visible:
			st.off += delta
			if st.off > h.lifetime:  # the last haze has faded: hide them, a spent emitter still costs a draw call
				h.visible = false
				st.grit.visible = false
	var cam := get_viewport().get_camera_3d()
	if cam:
		var at := cam.global_position
		at.y = _world.height_at(at.x, at.z)
		streaks.global_position = at + Vector3(0, 0.4, 0)
		front.global_position = at + Vector3(0, 3.0, 0)
	if streaks.emitting:
		streaks.amount_ratio = _streak_share * _share * (0.25 + 0.75 * _world.gust())
	if devil.emitting:
		var d: Dictionary = _world.data.devil
		var c: Array = _world.data.scatter.centre
		_devil_angle += float(d.speed) / float(d.radius) * delta
		# it wanders in and out a little as it goes round, never inside `radius` less its wander
		var r := float(d.radius) * (1.0 + float(d.wander) * sin(_devil_angle * 3.0))
		var x := float(c[0]) + cos(_devil_angle) * r
		var z := float(c[1]) + sin(_devil_angle) * r
		devil.position = Vector3(x, _world.height_at(x, z), z)
		devil.rotate_y(2.5 * delta)


func _material(tex: Texture2D, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# lit and shadowed like everything else: a night, a storm or a building's shadow darkens the dust too.
	# A backlit, unshadowed cloud stayed bright in the shade (Ravindu's playtest, 12 Nov 2026)
	m.roughness = 1.0
	return m


## Grit and haze: the dust role's colour, matte, lit as the ground they rose from (world/dust.gdshader).
func _ground_lit(tex: Texture2D, cut: bool) -> ShaderMaterial:
	if not _shaders.has(cut):
		_shaders[cut] = Shader.new()
		_shaders[cut].code = DUST.code.replace("// VARIANT\n", "#define GRIT\n" if cut else "")
	var m := ShaderMaterial.new()
	m.shader = _shaders[cut]
	m.set_shader_parameter("shape", tex)
	return m


## A particle node: `fade` is the alpha at birth, peak and death; `grow` the size at birth and death.
func _emitter(id: String, amount: int, life: float, size: Vector2, mat: Material, fade: Array, grow: Array) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = id
	e.amount = amount
	e.lifetime = life
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-250, -30, -250), Vector3(500, 80, 500))
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	e.draw_pass_1 = quad
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO  # fine dust hangs in thin air: the wind carries it, nothing pulls it down in seconds
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, fade[0]))
	ramp.set_color(1, Color(1, 1, 1, fade[2]))
	ramp.add_point(0.15, Color(1, 1, 1, fade[1]))
	pm.color_ramp = GradientTexture1D.new()
	pm.color_ramp.gradient = ramp
	var curve := Curve.new()
	curve.max_value = 4.0
	curve.add_point(Vector2(0, grow[0]))
	curve.add_point(Vector2(1, grow[1]))
	pm.scale_curve = CurveTexture.new()
	pm.scale_curve.curve = curve
	e.process_material = pm
	add_child(e)
	return e
