extends Node3D
## Dust in the air, all GPU particles (the Compatibility renderer has no trails and no sub-emitters):
## - puff(): a footstep or a wheel. Fine dust does not fall back in arcs: it "became diffuse within seconds"
##   and drifted downwind (movement-and-look §4), so a puff is a small cloud that drifts and thins.
## - streaks: faint lines low over the ground around the camera, at the wind's speed.
## - a dust devil wandering far off (seen crossing the crater floor on summer afternoons), day only.
## - the storm front: big slow clouds close around the camera, the storm state only.
## What shows in which sky is data/world.json `weather`; the wind's direction is `wind`.

const PUFFS := 8  # clouds in flight at once: a walk lays one every half second, each lasts three

var wind := Vector3.ZERO
var puffs: Array[GPUParticles3D] = []
var streaks: GPUParticles3D
var devil: GPUParticles3D
var front: GPUParticles3D
var _world: Node3D
var _soft: StandardMaterial3D  # one billboard material for every cloud, so one restyle reaches them all
var _line: StandardMaterial3D
var _dir: Vector3  # where the wind blows to, flat
var _devil_angle := 0.0
var _puff_left: PackedFloat32Array  # seconds until each puff has faded and can be hidden
var _next := 0  # the puff reused next: the oldest


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

	# the Compatibility renderer cannot emit particles by hand ("does not support manually emitting
	# particles"), so a puff is a one-shot emitter moved to the foot and restarted, the oldest reused
	for i in PUFFS:
		var e := _emitter("Puff%d" % i, 8, 3.0, Vector2(0.7, 0.7), _soft, [0.0, 0.7, 0.0], [0.5, 2.0])
		if i > 0:
			e.process_material = puffs[0].process_material  # one material, so a wind change reaches all
		e.one_shot = true
		e.explosiveness = 1.0
		e.emitting = false
		e.visible = false  # a spent emitter still costs a draw call
		puffs.append(e)
	var pp: ParticleProcessMaterial = puffs[0].process_material
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_sphere_radius = 0.15
	pp.spread = 35.0
	_puff_left.resize(PUFFS)

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
	for m: StandardMaterial3D in [_soft, _line]:
		# fine dust in the air is paler than the ground it rose from: it takes on the haze, and a cloud the
		# colour of the ground vanished against it (measured: a walk's puffs did not show)
		m.albedo_color = Color.html(design.materials.dust.color).lerp(Color.html(design.lighting.horizon), 0.5)
	wind = _dir * float(weather.wind)
	# low over the ground: streaks at the wind's speed and gusts a little over, clouds and puffs slower
	for e: GPUParticles3D in [streaks, front, puffs[0]]:
		var pm: ParticleProcessMaterial = e.process_material
		pm.direction = _dir if e != puffs[0] else (_dir + Vector3(0, 0.35, 0)).normalized()
		pm.initial_velocity_min = wind.length() * {streaks: 0.8, front: 0.3}.get(e, 0.35)
		pm.initial_velocity_max = wind.length() * {streaks: 1.4, front: 0.6}.get(e, 0.6)
	streaks.amount_ratio = float(weather.streaks)
	streaks.emitting = float(weather.streaks) > 0.0
	devil.emitting = bool(weather.devil)
	devil.visible = devil.emitting
	front.emitting = bool(weather.front)
	front.visible = front.emitting


## A small cloud at a foot or a wheel. `strength` 0 to 1: a step is about 0.3, a wheel at speed 1.
func puff(pos: Vector3, strength: float) -> void:
	var e := puffs[_next]
	_puff_left[_next] = e.lifetime
	_next = (_next + 1) % PUFFS
	e.global_position = pos
	e.amount_ratio = lerpf(0.35, 1.0, clampf(strength, 0.0, 1.0))
	e.visible = true
	e.restart()


func _process(delta: float) -> void:
	for i in PUFFS:
		if _puff_left[i] > 0.0:
			_puff_left[i] -= delta
			puffs[i].visible = _puff_left[i] > 0.0
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
