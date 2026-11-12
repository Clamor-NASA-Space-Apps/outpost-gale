extends RefCounted
## The hero's own motion on top of its clips (skills/living-atmosphere section 3, skills/character-life section 4):
## the chest and shoulders rise on the breath you hear, the upper body leans into acceleration and turns and
## overshoots a little at a stop (one damped spring), and the helmet turns toward what is worth noticing, the
## torso taking most of the turn as a suit makes it. All of it runs after the AnimationTree, as modifiers.

var body: Body
var looks: Array[LookAtModifier3D] = []
var target: Node3D  # where the look modifiers aim, rebuilt every frame from the eased angles below
var yaw := 0.0  # rad, the gaze's turn from the body's front (left positive), eased, within the limits
var pitch := 0.0  # rad, up positive
var t: Dictionary  # tuning.json `life`
var lean_max: float  # rad, hero.lean.max
var gravity: float


func setup(skeleton: Skeleton3D, tuning: Dictionary, lean_max_deg: float, g: float) -> void:
	t = tuning
	lean_max = deg_to_rad(lean_max_deg)
	gravity = g
	body = Body.new()
	body.setup(skeleton, t)
	skeleton.add_child(body)
	target = Node3D.new()
	skeleton.add_child(target)
	# parent bone first, as the class reference requires; the waist turns more than the neck inside a helmet
	for spec: Array in [[&"spine_03", t.look_waist_deg], [&"Head", t.look_head_deg]]:
		var m := LookAtModifier3D.new()
		skeleton.add_child(m)
		var b := skeleton.find_bone(spec[0])
		m.bone = b
		var rest := skeleton.get_bone_global_rest(b).basis
		m.forward_axis = _axis_along(rest, Vector3.BACK)  # the model faces +Z in skeleton space
		m.primary_rotation_axis = _axis_index(_axis_along(rest, Vector3.UP))
		m.use_secondary_rotation = true
		m.relative = true  # on top of the clip's pose
		m.use_angle_limitation = true
		m.symmetry_limitation = true
		m.primary_limit_angle = deg_to_rad(spec[1]) * 2.0  # the whole arc, half each side
		m.secondary_limit_angle = deg_to_rad(t.look_pitch_deg) * 2.0
		m.target_node = m.get_path_to(target)
		looks.append(m)


## Every physics frame. `accel` is the body's horizontal acceleration (world, m/s2), `breath` 0..1 through one
## breath, `look` the world point worth looking at, `pace` 0 standing to 1 at a walk.
func update(delta: float, accel: Vector3, carrying: bool, breath: float, inhale: float, look: Vector3, pace: float) -> void:
	var s := body.get_skeleton()
	var a := s.global_basis.inverse() * Vector3(accel.x, 0.0, accel.z)
	# lean the way the body is pushed, at a share of the angle a free body would need (atan a / g)
	var tilt := Vector2(a.x, a.z)
	var angle := minf(atan(tilt.length() / gravity) * t.lean_share, lean_max)
	body.target = tilt.normalized() * angle if tilt.length() > 0.001 else Vector2.ZERO
	if carrying:
		body.target.y = minf(body.target.y + deg_to_rad(t.carry_lean_deg), lean_max)  # forward, over the load
	body.breath = smoothstep(0.0, inhale, breath) if breath < inhale else 1.0 - smoothstep(inhale, 1.0, breath)
	body.hold = move_toward(body.hold, 1.0 if carrying else 0.0, delta / t.carry_swing_s)
	# a walker looks with the head, not the torso: the waist's share of a turn goes as the pace comes
	looks[0].influence = 1.0 - pace
	var want := _angles(look, deg_to_rad(t.look_head_deg) + deg_to_rad(t.look_waist_deg) * (1.0 - pace))
	# ease the angles, never the point: a point eased across the body passes through the head and the
	# modifiers' limits throw the turn from one side to the other
	var k := 1.0 - exp(-t.look_rate * delta)
	yaw += (want.x - yaw) * k
	pitch += (want.y - pitch) * k
	_aim()


func snap(look: Vector3) -> void:
	var want := _angles(look, deg_to_rad(t.look_head_deg + t.look_waist_deg))
	yaw = want.x
	pitch = want.y
	_aim()
	body.lean = Vector2.ZERO
	body.lean_vel = Vector2.ZERO


## The turn toward `look` from the body's front, as (yaw, pitch), within `reach` each side. Toward a point
## behind the body the turn fades to straight ahead: there is no side to turn to, and clamping it picks one
## at random each frame (the helmet thrown from hard left to hard right as a walk sways).
func _angles(look: Vector3, reach: float) -> Vector2:
	var s := body.get_skeleton()
	var to := s.global_basis.inverse() * (look - _eyes())
	var side := atan2(to.x, to.z)  # the model faces +Z in skeleton space
	var front := 1.0 - smoothstep(PI * 0.4, PI * 0.6, absf(side))  # whole to 72 deg, none past 108
	var up := atan2(to.y, Vector2(to.x, to.z).length())
	var tilt := deg_to_rad(t.look_pitch_deg) * 2.0
	return Vector2(clampf(side, -reach, reach), clampf(up, -tilt, tilt)) * front


func _aim() -> void:
	var s := body.get_skeleton()
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	target.global_position = _eyes() + s.global_basis * dir * t.look_far


func _eyes() -> Vector3:
	var s := body.get_skeleton()
	return s.global_transform * s.get_bone_global_rest(s.find_bone(&"Head")).origin


## The bone axis that points most along `dir` (skeleton space) at rest, as a SkeletonModifier3D.BoneAxis.
static func _axis_along(rest: Basis, dir: Vector3) -> int:
	var best := 0
	var most := -INF
	for i in 6:
		var v := rest[i / 2] * (1.0 if i % 2 == 0 else -1.0)
		if v.normalized().dot(dir) > most:
			most = v.normalized().dot(dir)
			best = i
	return best  # BONE_AXIS_PLUS_X, MINUS_X, PLUS_Y, MINUS_Y, PLUS_Z, MINUS_Z in that order


static func _axis_index(bone_axis: int) -> int:
	return bone_axis / 2  # Vector3.AXIS_X, Y, Z


## Breath and lean on the spine, by rotations about skeleton-space axes through each bone.
class Body extends SkeletonModifier3D:
	var t: Dictionary
	var lean := Vector2.ZERO  # rad: x tips the top toward skeleton +X, y toward +Z (forward)
	var lean_vel := Vector2.ZERO
	var target := Vector2.ZERO
	var breath := 0.0  # 0 empty, 1 full
	var hold := 0.0  # 0 free, 1 holding a bag: the arms swing out round it
	var waist := -1
	var chest := -1
	var shoulders: Array[int] = []
	var arms: Array[int] = []

	func setup(s: Skeleton3D, tuning: Dictionary) -> void:
		t = tuning
		waist = s.find_bone(&"spine_01")
		chest = s.find_bone(&"spine_03")
		shoulders.assign([s.find_bone(&"clavicle_l"), s.find_bone(&"clavicle_r")])
		arms.assign([s.find_bone(&"upperarm_l"), s.find_bone(&"upperarm_r")])

	func _process_modification_with_delta(delta: float) -> void:
		# an underdamped spring: it lags into a lean and swings a little past upright when the push stops
		var w: float = TAU * t.lean_hz
		lean_vel += ((target - lean) * w * w - 2.0 * t.lean_damping * w * lean_vel) * delta
		lean += lean_vel * delta
		var s := get_skeleton()
		if lean.length() > 0.0001:
			_turn(s, waist, Vector3.UP.cross(Vector3(lean.x, 0.0, lean.y)).normalized(), lean.length())
		# the chest lifts and opens, the shoulders rise: a top toward -Z is the chest tipping back
		_turn(s, chest, Vector3.RIGHT, -deg_to_rad(t.breath_chest_deg) * breath)
		var side := 1.0
		for b in shoulders:
			_turn(s, b, Vector3.BACK, deg_to_rad(t.breath_shoulder_deg) * breath * side)
			side = -side
		# the carry clip's hands meet in the bag: each arm swings out round the vertical at the shoulder until
		# the gloves are at its sides (left is +X, the hands ahead on +Z)
		if hold > 0.0:
			_turn(s, arms[0], Vector3.UP, deg_to_rad(t.carry_swing_deg) * hold)
			_turn(s, arms[1], Vector3.UP, -deg_to_rad(t.carry_swing_deg) * hold)

	## Rotates bone `b` about `axis` (skeleton space, through the bone) by `angle`, on top of its pose.
	func _turn(s: Skeleton3D, b: int, axis: Vector3, angle: float) -> void:
		var local := (s.get_bone_global_pose(b).basis.inverse() * axis).normalized()
		s.set_bone_pose_rotation(b, s.get_bone_pose_rotation(b) * Quaternion(local, angle))
