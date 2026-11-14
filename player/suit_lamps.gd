extends BoneAttachment3D
## The helmet lights (data/tuning.json `lamps`): two glowing lamp faces either side of the visor and one unshadowed
## spot between them, riding the head bone so the beam goes where the helmet looks. Lit, each lamp also wears a cone
## of light in the air and a halo of glare (lamp_glow.gdshader): a spot shows only where it lands, which on foot is
## metres ahead, and glare needs no glow pass, which the phone preset has not. Outside they come on once the sun
## is below on_deg and go off above off_deg; in a room they are off. A press of `lamp` overrides that until what auto
## wants next changes (dusk, dawn, a door). Off is a glimmer, never hidden: a spot reaching a material is a shader
## variant of its own, and one appearing at dusk would compile every lit material in play (world/sky_clock.gd lamps).

const Glow := preload("res://player/lamp_glow.gdshader")
const R := 0.022  # m: a lamp face's radius

var on := false
var auto := true
var spot: SpotLight3D
var faces: Array[MeshInstance3D] = []
var beams: Array[MeshInstance3D] = []  # the cones, one a lamp, hidden while the lamps are off
var halos: Array[MeshInstance3D] = []
var _player: Node3D
var _t: Dictionary
var _floor: float  # tuning.sky.light_floor: an off lamp's energy and glow share
var _glow := StandardMaterial3D.new()  # the lamp faces
var _air: Array[ShaderMaterial] = []  # the cones' and the halos', with the tuning key of their share
var _sun: Object  # a sibling of the player with `sun` (world/sky_clock.gd), else it is day
var _dark := false
var _want := false
var _level := -1.0
var _eye: Vector3
var _mount := 3  # process frames until the lamps are placed: the clips pose the head first


func setup(player: Node3D, skeleton: Skeleton3D, eye: Vector3, design: Dictionary) -> void:
	_player = player
	_t = player.tuning.lamps
	_floor = float(player.tuning.sky.light_floor)
	name = "SuitLamps"
	# beside the model, not in it: the house style restyles the model's materials, and the fade lists its meshes
	player.body.add_child(self)
	use_external_skeleton = true
	external_skeleton = get_path_to(skeleton)
	bone_name = "Head"
	_eye = eye
	var lamp: Dictionary = design.lighting.get("lamp", Forge.HouseStyle.load_design("res://design.night.json").lighting.lamp)
	spot = SpotLight3D.new()
	spot.light_color = Color.html(lamp.color)
	spot.spot_range = float(_t.range_m)
	spot.spot_angle = float(_t.angle_deg)
	add_child(spot)
	# the faces burn in the lamp's own colour, not the `light` role's teal: they are what casts the beam
	_glow.albedo_color = spot.light_color
	_glow.emission_enabled = true
	_glow.emission = spot.light_color
	var disc := CylinderMesh.new()
	disc.top_radius = R
	disc.bottom_radius = R
	disc.height = 0.02
	# the cone opens from the lamp's rim along +Y, with no caps: seen from inside or end-on it is not a disc
	var cone := CylinderMesh.new()
	cone.height = float(_t.beam_m)
	cone.bottom_radius = R
	cone.top_radius = R + cone.height * tan(deg_to_rad(float(_t.beam_deg)))
	cone.radial_segments = 16
	cone.rings = 0
	cone.cap_top = false
	cone.cap_bottom = false
	var halo := Shader.new()
	halo.code = Glow.code.replace("// VARIANT\n", "#define HALO\n")
	for look: Array in [[Glow, cone.height, "beam_glow"], [halo, float(_t.halo_m), "halo_glow"]]:
		var m := ShaderMaterial.new()
		m.shader = look[0]
		m.set_shader_parameter("color", spot.light_color)
		m.set_shader_parameter("size", look[1])
		m.set_meta("share", look[2])
		_air.append(m)
	var parts := [[faces, disc, _glow], [beams, cone, _air[0]], [halos, QuadMesh.new(), _air[1]]]
	for side in 2:
		for part: Array in parts:
			var f := MeshInstance3D.new()
			f.mesh = part[1]
			f.material_override = part[2]
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(f)
			part[0].append(f)


## The faces and the beam in the head's frame, from where the visor is in the idle pose (hero_model `eye`) and which
## way the body faces now. Not at setup: the skeleton is still in its rest pose there, and the lamps floated over the
## helmet.
func _place() -> void:
	var to_head := global_transform.affine_inverse()
	var b: Basis = _player.body.global_basis
	var mid: Vector3 = _player.model.to_global(_eye) + b.y * float(_t.up_m) - b.z * float(_t.ahead_m)
	var aim := b.rotated(b.x, -deg_to_rad(float(_t.tilt_deg)))
	spot.transform = to_head * Transform3D(aim, mid - b.z * 0.03)
	for i in faces.size():
		# the disc's axis (Y) along the beam
		var at: Vector3 = mid + b.x * (i * 2 - 1) * float(_t.side_m)
		faces[i].transform = to_head * Transform3D(Basis(b.x, -PI / 2.0) * b, at)
		# the cone starts just clear of the face (no two surfaces in one plane) and runs down the spot's aim
		beams[i].transform = to_head * Transform3D(Basis(aim.x, -PI / 2.0) * aim, at - aim.z * (float(_t.beam_m) / 2.0 + 0.012))
		halos[i].transform = faces[i].transform  # the shader turns it to the lens; +Y says which way the lamp faces


## The `lamp` press: the other way round, held until auto wants something new.
func toggle() -> void:
	on = not on
	auto = false
	_player.lamps_changed.emit(on, auto)


func _process(delta: float) -> void:
	if _mount > 0:
		_mount -= 1
		if _mount == 0:
			_place()
	if _sun == null:  # the composition root adds its clock after the player
		for n in _player.get_parent().get_children():
			if n.get("sun") is Vector3:
				_sun = n
	var el := rad_to_deg(asin(clampf((_sun.sun as Vector3).y, -1.0, 1.0))) if _sun else 90.0
	_dark = el < float(_t.off_deg) if _dark else el < float(_t.on_deg)
	var want: bool = _dark and _player.room == ""
	if want != _want:
		_want = want
		auto = true
	if auto and on != _want:
		on = _want
		_player.lamps_changed.emit(on, auto)
	if Input.is_action_just_pressed(&"lamp") and _player.may(&"lamp"):
		toggle()
	var to := 1.0 if on else 0.0
	if _level != to:
		_level = to if _level < 0.0 else move_toward(_level, to, delta / float(_t.fade_s))
		spot.light_energy = maxf(float(_t.energy) * _level, _floor)
		_glow.emission_energy_multiplier = float(_t.bulb_glow) * maxf(_level, _floor)
		for m in _air:
			m.set_shader_parameter("strength", float(_t[m.get_meta("share")]) * _level)
	# the faces go with the body: hidden when the lens is close enough to hide it. Their light in the air too, and
	# it is not drawn at all while the lamps are off
	var body: bool = _player.shown > 0.5
	for i in faces.size():
		faces[i].visible = body
		beams[i].visible = body and _level > 0.0
		halos[i].visible = beams[i].visible
