extends Node3D
## The gravity lesson (design/typical-day.md, Sol 1 at 1:30): a faint copy of the hero beside them does the same hop
## on Earth. Same take-off speed (the same legs push the same suited body), so it rises g_mars / g_earth as high, 0.38
## of the hero's rise, and is back down 0.38 as soon. Drawn from the crouch to a moment after it lands; no shadow, no
## collision. Numbers: reality.json hero.jump.hop, world.gravity, world.gravity.earth; the look: data/beats.json ghost.

var on := false
var material: StandardMaterial3D
var rise := 0.0  # m above the ground now
var peak := 0.0  # the highest it rose on the last hop (checks)
var air := 0.0  # s in the air on the last hop (checks)
var _player: Node3D
var _world: Node3D
var _anim: AnimationPlayer
var _g: float  # m/s2, Earth's
var _v0: float  # m/s, the hop's take-off speed on Mars: sqrt(2 g h)
var _side: float
var _linger: float
var _crouch_at: float  # s into hop_start where the body's short crouch begins (as hero_model.gd plays it)
var _flying := false
var _left := 0.0  # s until it hides


func setup(world: Node3D, player: Node3D, sheet: Dictionary, cfg: Dictionary, design: Dictionary) -> void:
	_world = world
	_player = player
	var row := func(id: String) -> float:
		for r: Dictionary in sheet.rows:
			if r.id == id:
				return r.value
		push_error("reality.json has no row %s" % id)
		return NAN
	_g = row.call("world.gravity.earth")
	_v0 = sqrt(2.0 * float(sheet.gravity) * row.call("hero.jump.hop"))
	_side = float(cfg.side_m)
	_linger = float(cfg.linger_s)
	_crouch_at = maxf(float(player.model.clips.hop_start.takeoff_at) - float(player.tuning.hop.anticipation), 0.0)
	var model: Node3D = load(player.MODEL).instantiate()
	model.rotation.y = PI  # glTF faces +Z, the game's front is -Z
	model.position.y = -player.sink
	add_child(model)
	material = StandardMaterial3D.new()
	material.resource_name = "ghost"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # one shell: no far limb seen through a near one
	material.albedo_color = Color(Color.html(design.colors[cfg.color]), float(cfg.alpha))
	# per surface, not material_override: the warm-up would otherwise compile the file's own materials too
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, material)
	_anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	visible = false


## The hero started the crouch before a hop.
func crouch() -> void:
	if not on:
		return
	visible = true
	_flying = false
	rise = 0.0
	_left = INF
	_anim.speed_scale = 1.0
	_anim.play(&"hop_start")
	_anim.seek(_crouch_at, true)


## The hero left the ground: the ghost too, at the same speed, under Earth's pull. hop_air is timed to the Mars arc
## (reality.json hero.jump.time), so it plays faster by the ratio of the two flights.
func take_off() -> void:
	if not visible:
		return
	_flying = true
	air = 0.0
	peak = 0.0
	_anim.play(&"hop_air")
	_anim.speed_scale = _anim.current_animation_length / (2.0 * _v0 / _g)


func step(delta: float) -> void:
	if not visible:
		return
	if _flying:
		air += delta
		rise = _v0 * air - 0.5 * _g * air * air  # the arc itself: a stepped one fell 14% short at 60 Hz
		peak = maxf(peak, rise)
		if rise <= 0.0:
			rise = 0.0
			_flying = false
			_anim.speed_scale = 1.0
			_anim.play(&"hop_land")
			_anim.queue(&"idle")
			_left = _linger
	else:
		_left -= delta
		if _left <= 0.0:
			visible = false
	var b: Node3D = _player.body
	var at: Vector3 = b.global_transform * Vector3(_side, 0.0, 0.0)
	global_transform = Transform3D(Basis(Vector3.UP, _player.yaw), Vector3(at.x, _world.height_at(at.x, at.z) + rise, at.z))
