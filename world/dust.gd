extends Node3D
## Dust in the air, all GPU particles (the Compatibility renderer has no trails, no sub-emitters and no
## emit_particle()):
## - puff(): a boot or a wheel on the dust (skills/ground-contact-fx, design/research/dust.md). Grit: many
##   small grains in short ballistic arcs under Mars gravity, gone when they land. Haze: a few wide, faint
##   quads at ankle height that spread, slow, drift downwind and fade in 2 to 3 s. The print is terrain.mark().
## - streaks: faint lines low over the ground around the camera, at the wind's speed.
## - a dust devil wandering far off (seen crossing the crater floor on summer afternoons), day only.
## - the storm front: big slow clouds close around the camera, the storm state only.
## What shows in which sky is data/world.json `weather`; the wind's direction is `wind`.

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
var _line: StandardMaterial3D
var _dir: Vector3  # where the wind blows to, flat
var _devil_angle := 0.0
var _haze_mat: StandardMaterial3D
var _grit_mat: StandardMaterial3D
var _c: Dictionary  # data/world.json `contact`
var _g: float  # gravity, from the reality sheet
var _live: Dictionary = {}  # emitter -> {kind, age, life, top}: what is in flight, for checks and for hiding
var _next_grit := 0  # the oldest of each pool, reused next
var _next_haze := 0


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
	_grit_mat = _material(dot, BaseMaterial3D.BILLBOARD_PARTICLES)
	# grains are opaque: no blending, no sorting, no overdraw; the dot's soft edge cut by the scissor makes
	# the last tenth's fade a shrink rather than a pop
	_grit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_grit_mat.alpha_scissor_threshold = 0.5
	# a camera-facing grain turned from a low sun came out dark brown (measured); light passing through it
	# lights it about as the ground under it is lit, from either side
	_grit_mat.backlight = Color(0.9, 0.9, 0.9)
	_haze_mat = _material(_blot(), BaseMaterial3D.BILLBOARD_PARTICLES)
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

	devil = _emitter("Devil", 110, 7.0, Vector2(3.0, 3.0), _soft, [0.0, 0.5, 0.0], [0.6, 3.2])
	devil.local_coords = true  # the node spins, so the column swirls
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
	_grit_mat.albedo_color = Color.html(design.materials.dust.color)
	for m: StandardMaterial3D in [_soft, _line, _haze_mat]:
		# fine dust in the air is paler than the ground it rose from: it takes on the haze, and a cloud the
		# colour of the ground vanished against it (measured: the first puffs did not show)
		m.albedo_color = Color.html(design.materials.dust.color).lerp(Color.html(design.lighting.horizon), 0.5)
	wind = _dir * float(weather.wind)
	# low over the ground: streaks at the wind's speed and gusts a little over, the front slower
	for e: GPUParticles3D in [streaks, front]:
		var pm: ParticleProcessMaterial = e.process_material
		pm.direction = _dir
		pm.initial_velocity_min = wind.length() * (0.8 if e == streaks else 0.3)
		pm.initial_velocity_max = wind.length() * (1.4 if e == streaks else 0.6)
	# the haze is pushed by the wind against quadratic drag, which balances at the wind's speed:
	# damping = 20 a / v^2 (engine source, skills/ground-contact-fx); `a` sets how soon it gets there
	var hp: ParticleProcessMaterial = haze[0].process_material
	var push := maxf(wind.length(), 0.01)
	hp.gravity = _dir * push
	hp.damping_min = 20.0 * push / (push * push)
	hp.damping_max = hp.damping_min
	streaks.amount_ratio = float(weather.streaks)
	streaks.emitting = float(weather.streaks) > 0.0
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


## What is in flight: [{kind, age, life, top}], `top` the highest a grain can get (analytic H).
func contact_state() -> Array:
	return _live.values()


func _fire(e: GPUParticles3D, at: Vector3, strength: float, info: Dictionary) -> void:
	info.age = 0.0
	_live[e] = info
	e.global_position = at
	e.amount_ratio = clampf(strength, 0.1, 1.0)
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
	var cam := get_viewport().get_camera_3d()
	if cam:
		var at := cam.global_position
		at.y = _world.height_at(at.x, at.z)
		streaks.global_position = at + Vector3(0, 0.4, 0)
		front.global_position = at + Vector3(0, 3.0, 0)
	if devil.emitting:
		var d: Dictionary = _world.data.devil
		var c: Array = _world.data.scatter.centre
		_devil_angle += float(d.speed) / float(d.radius) * delta
		var x := float(c[0]) + cos(_devil_angle) * float(d.radius)
		var z := float(c[1]) + sin(_devil_angle) * float(d.radius)
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
	m.disable_receive_shadows = true
	# lit like the ground, so a night or a storm darkens the dust with no colour of its own; backlight lets a
	# cloud glow when the sun is behind it, the way fine dust does
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.backlight_enabled = true
	m.backlight = Color(0.6, 0.6, 0.6)
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
