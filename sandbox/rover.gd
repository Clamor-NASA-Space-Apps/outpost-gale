extends AnimatableBody3D
## Drives the crewed rover over the real ground (CONTRACTS.md vehicle). Kinematic, not VehicleBody3D (unproven
## under Jolt in the web build): the sheet's top speed, acceleration and braking, a pivot on the spot as the real
## SEV's swivelling wheels allow. Each wheel rests on the ground or on the rock under it (world.wheel_rest()): it
## rolls up rocks up to the sheet's climb height, the body takes its height and tilt from the six wheels, and each
## wheel takes up the rest on its suspension. A taller rock, or a wall, ahead within the braking distance brakes it
## to a stop at the contact. Tracks, a dust stream from the wheels, and a moving contact shadow on the ground.
## The drawn body rides on a damped spring over the wheels (`_spring()`): it leans out of a turn, squats when it sets
## off, dips when it brakes and bobs over a rock. Only the drawing moves: the physics body, which the camera follows,
## stays on the wheels' plane, so the camera never shakes with it.

const Rocks := preload("res://world/rocks.gd")
const AXLE := 1.55
const TRACK := 1.0
const HATCH := Vector3(0.0, 0.0, 3.2)  # the rear hatch, from the model (forge/vehicle_rover.py)
const BELLY := 0.62  # the chassis's underside over the ground, from the model

var world: Node3D
var top: float  # m/s
var accel: float  # m/s2
var brake: float  # m/s2
var turn: float  # rad/s
var climb: float  # m, the tallest rock a wheel rolls onto
var sink: float  # m, how far the wheels sit in the dust
var radius: float  # m, a wheel's
var travel: float  # m, each wheel's suspension travel either way
var track_every: float  # metres between wheel prints
var shade: Dictionary  # tuning.rover: contact shadow discs, dust and track depth by speed
var v := 0.0
var yaw := 0.0
var travelled := 0.0
var wheels: Array[Node3D] = []
var hubs: Array[Vector3] = []  # each wheel's hub at rest, in the body's space
var rest_at: Array[Vector3] = []  # each wheel node's rest position in its parent
var seat_at := Vector3(-0.5, 1.66, -0.85)  # replaced by the model's `seat` node
var blocked := ""  # what stopped it last: "", "rock", "wall", "edge" (for checks)
var on_rock := 0.0  # m, the highest rock a wheel stands on now (for checks)
var _belly := BoxShape3D.new()
var spring: Dictionary  # tuning.rover.spring
var g: float  # m/s2, the planet's (reality.json world.gravity)
var lean := Transform3D()  # the drawn body off the wheels' plane, in the body's space (for checks and the seat)
var _sprung: Node3D  # every drawn part but the wheels; `lean` is its transform
var _off := Vector3.ZERO  # (heave m, pitch rad, roll rad) of the drawn body off the wheels' plane
var _off_v := Vector3.ZERO
var _plane := Vector3.INF  # the wheels' plane last frame: (height, pitch, roll)
var _plane_v := Vector3.ZERO  # and how fast it moved
var _push := Vector3.ZERO  # (0, pitch, roll) the inertia of this frame's speed change and turn asks
var _driven := -2  # the physics frame drive() last ran


func setup(w: Node3D, sheet: Dictionary, tuning: Dictionary) -> void:
	world = w
	for r: Dictionary in sheet.rows:
		match r.id:
			"rover.speed.max": top = r.value
			"rover.accel": accel = r.value
			"rover.brake": brake = r.value
			"rover.turn": turn = deg_to_rad(r.value)
			"rover.climb": climb = r.value
			"rover.wheel": radius = r.value / 2.0
	sink = world.sheet_values[world.data.sink.get("rover", world.data.sink.default)]
	track_every = tuning.interact.track_every
	travel = tuning.rover.travel
	shade = tuning.rover
	spring = tuning.rover.spring
	g = world.sheet_values["world.gravity"]
	# the ground holds it up through _settle(), so the sweep must not stop on the ground it rests on; rocks are
	# the wheels' to climb, so the body's sweep passes them (a rock too tall is caught by _pose())
	collision_mask &= ~1
	collision_mask |= 16  # PIP (a vehicle too): the rover brakes for it as for a wall, and PIP gets out of the way
	for b: Node in world.rocks.solids:
		add_collision_exception_with(b)
	_belly.size = Vector3(1.3, 0.3, 4.1)
	yaw = rotation.y
	var seat_node := find_child("seat", true, false) as Node3D
	if seat_node:
		seat_at = to_local(seat_node.global_position)
	for n: Node in find_children("wheel_*", "Node3D", true, false):
		var wh := n as Node3D
		wheels.append(wh)
		rest_at.append(wh.position)
		var hub := to_local(wh.global_position)
		hub.y = radius  # the model stands its wheels on y = 0
		hubs.append(hub)
	# the wheels stay on the ground, everything else rides the springs. ponytail: the model sits at the body's
	# origin unturned (world._item), so its space is the body's
	var model := wheels[0].get_parent()
	_sprung = Node3D.new()
	_sprung.name = "sprung"
	model.add_child(_sprung)
	for c: Node in model.get_children():
		if c != _sprung and c is Node3D and c not in wheels:
			c.reparent(_sprung)
	var p := _pose(global_position, yaw)
	_apply(p)
	set_physics_process(true)


## input.x steers (right positive), input.y is throttle (forward positive), CONTRACTS.md.
func drive(input: Vector2, _hurry: bool, delta: float) -> void:
	var was_v := v
	var want := input.y * top
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	# anything ahead within the braking distance brakes it now, so it stops at the contact, not inside it
	blocked = ""
	# standing still, the way the throttle asks: a stop checked nothing, so a held throttle crept on a few
	# millimetres a step (4 cm past the map's edge in 9 s, tests/edge_test.gd)
	var dir := signf(v) if absf(v) > 0.01 else signf(want)
	if dir != 0.0:
		# reach measured at the speed this frame's motors would add: from the current speed, every frame the look
		# came up short sped it up once more than the brakes could take back, and at accel 1.0 against brake 1.2
		# it met the rock at 0.2 m/s
		var n := absf(v) + accel * delta
		var look := n * n / (2.0 * brake) + n * delta
		blocked = _blocked(fwd * dir * look)
	if blocked != "" and signf(want) != -dir:
		want = 0.0  # the driver's throttle waits; backing away is allowed
	# speeding up takes the motors' acceleration, slowing down the brakes'
	var speeding := absf(want) > absf(v) and (signf(want) == signf(v) or is_zero_approx(v))
	v = move_toward(v, want, (accel if speeding else brake) * delta)
	# backing up turns the other way, as a car does
	var new_yaw := yaw - input.x * turn * delta * (1.0 if v >= -0.05 else -1.0)
	var step := fwd * v * delta
	var before := global_position
	var at := global_position + step
	var was_yaw := yaw
	var p := _pose(Vector3(at.x, 0.0, at.z), new_yaw)
	if not p.ok or (step.length() > 0.0 and test_move(global_transform, step)):
		# the last few millimetres: the brake ran out of road (a rock that came into reach by a turn)
		v = 0.0
		p = _pose(Vector3(before.x, 0.0, before.z), new_yaw)
		if not p.ok:
			p = _pose(Vector3(before.x, 0.0, before.z), yaw)  # nor may it turn a wheel into a rock
		else:
			yaw = new_yaw
	else:
		yaw = new_yaw
	_apply(p)
	# the push the body feels: speeding up tips the nose up, braking dips it; a turn's sideways acceleration
	# (velocity x turn rate) leans it to the outside. In the planet's g: a spring sized for the same sag under
	# Mars weight is that much softer (design/research/pages/alive/rover-spring-and-radio.md)
	var along := (v - was_v) / delta
	var side := -v * wrapf(yaw - was_yaw, -PI, PI) / delta
	_push = Vector3(0.0, deg_to_rad(spring.pitch_deg_g) * along / g, deg_to_rad(spring.roll_deg_g) * side / g)
	_spring(delta)
	_driven = Engine.get_physics_frames()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() * signf(v)
	for wh in wheels:
		wh.rotate_object_local(Vector3.RIGHT, -moved / radius)
	_ground_fx(moved)


## What stops a move of `step` (world): "rock" (a wheel would meet a rock over the climb height, or the belly one),
## "wall" (the body's sweep meets a solid), "edge" (it would take the rover further past the end of the real ground,
## world.bound(), kept `reach` in for its hatch) or "".
func _blocked(step: Vector3) -> String:
	var at := global_position + step
	var reach := float(world.data.bound.reach)
	if world.past(at, reach) > world.past(global_position, reach):
		return "edge"
	if not _pose(Vector3(at.x, 0.0, at.z), yaw).ok:
		return "rock"
	if test_move(global_transform, step):
		return "wall"
	return ""


## The body on its wheels at `at` (x, z) facing `heading`: {ok, basis, origin, lift (per wheel, m), rock (m)}.
## Each wheel's height comes from what is under it; the body takes the plane through its six hubs, and each wheel's
## suspension takes up its distance from that plane, up to `travel`.
func _pose(at: Vector3, heading: float) -> Dictionary:
	var flat := Basis(Vector3.UP, heading)
	var hy: Array[float] = []
	var ok := true
	var rock := 0.0
	for h in hubs:
		var p := at + flat * Vector3(h.x, 0.0, h.z)
		var ground: float = world.height_at(p.x, p.z)
		var rests: float = world.wheel_rest(p.x, p.z, radius, climb + 0.05)
		var up := rests - ground
		if up > climb:
			ok = false
		rock = maxf(rock, up)
		# on dust a wheel sinks; on a rock it stands on the rock
		hy.append((rests if up > sink else ground - sink) + radius)
	# the plane through the hubs: height at the middle, then the slope front to back and side to side
	var mid := 0.0
	var front := 0.0
	var back := 0.0
	var right := 0.0
	var left := 0.0
	var nf := 0
	var nb := 0
	for i in hubs.size():
		mid += hy[i] / hubs.size()
		if hubs[i].z < -0.5:
			front += hy[i]
			nf += 1
		elif hubs[i].z > 0.5:
			back += hy[i]
			nb += 1
		if hubs[i].x > 0.0:
			right += hy[i]
		else:
			left += hy[i]
	var half := hubs.size() / 2.0
	var pitch := atan2(front / maxi(nf, 1) - back / maxi(nb, 1), 2.0 * AXLE)
	var roll := atan2(right / half - left / half, 2.0 * TRACK)
	var basis := Basis.from_euler(Vector3(pitch, heading, roll))
	var origin := Vector3(at.x, mid - radius, at.z)
	var plane := Vector3(origin.y, pitch, roll)
	var lift: Array[float] = []
	for i in hubs.size():
		var on_plane := (origin + basis * hubs[i]).y
		lift.append(clampf(hy[i] - on_plane, -travel, travel))
	if ok:
		# a rock between the wheels that the belly would meet
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _belly
		q.collision_mask = Rocks.ROCK
		q.transform = Transform3D(basis, origin + basis * Vector3(0.0, BELLY + 0.15, -0.1))
		ok = get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
	return {"ok": ok, "basis": basis, "origin": origin, "lift": lift, "rock": rock, "plane": plane}


func _apply(p: Dictionary) -> void:
	global_transform = Transform3D(p.basis, p.origin)
	# the drawn body keeps its own motion when the wheels' plane jumps (a wheel onto a rock): only the plane's
	# change of speed reaches it, through the spring, so a steady slope does not leave it behind
	var plane: Vector3 = p.plane
	var pv := Vector3.ZERO if _plane == Vector3.INF else (plane - _plane) * Engine.physics_ticks_per_second
	_off_v -= pv - _plane_v
	_plane = plane
	_plane_v = pv
	on_rock = p.rock
	for i in wheels.size():
		wheels[i].position = rest_at[i] + Vector3(0.0, p.lift[i], 0.0)


## Prints, dust and the contact shadow where the wheels meet the ground.
func _ground_fx(moved: float) -> void:
	var discs := PackedVector4Array()
	var wr: float = shade.wheel_shade[0]
	for wh in wheels:
		var c := wh.global_position
		discs.append(Vector4(c.x, c.z, wr, shade.wheel_shade[1]))
	for z: float in [-1.0, 1.0]:
		var c := global_transform * Vector3(0.0, 0.0, z)
		discs.append(Vector4(c.x, c.z, shade.body_shade[0], shade.body_shade[1]))
	world.touch(self, discs)
	travelled += absf(moved)
	var back := global_basis.z * signf(v)  # the way the tread leaves the ground: backward as it rolls forward
	for side: float in [-TRACK, TRACK]:
		# the trailing pair on each side throws the dust, from behind its contact patch
		var p := global_transform * Vector3(side, 0.0, AXLE * signf(v) + 0.5 * signf(v))
		p.y = world.height_at(p.x, p.z)
		world.stream("rover%d" % int(side), p, back * absf(v), pow(absf(v) / top, shade.dust_power))
	if travelled >= track_every:
		travelled = 0.0
		for side: float in [-TRACK, TRACK]:
			var p := global_transform * Vector3(side, 0.0, AXLE)
			world.mark(p, -rad_to_deg(yaw), "wheel", 0.3, lerpf(shade.track_depth[0], shade.track_depth[1], absf(v) / top))


## Parked (nobody drives): the body settles on its own.
func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() - _driven > 1:
		_push = Vector3.ZERO
		_plane_v = Vector3.ZERO
		_spring(delta)


## One step of the drawn body's damped spring (a little under critical: one small overshoot, then still), toward
## what the push asks, held inside the suspension's travel; then the drawing is moved, about the hubs' height.
func _spring(delta: float) -> void:
	var w := TAU * float(spring.hz)
	_off_v += (w * w * (_push - _off) - 2.0 * float(spring.damping) * w * _off_v) * delta
	_off += _off_v * delta
	var lim := Vector3(travel, atan2(travel, AXLE), atan2(travel, TRACK))
	for i in 3:
		if absf(_off[i]) > lim[i]:
			_off[i] = clampf(_off[i], -lim[i], lim[i])
			_off_v[i] = 0.0  # the bump stop
	var b := Basis.from_euler(Vector3(_off.y, 0.0, _off.z))
	var pivot := Vector3(0.0, radius, 0.0)
	lean = Transform3D(b, pivot - b * pivot + Vector3.UP * _off.x)
	_sprung.transform = lean


## The driver's seat, riding the springs with the cab.
func seat() -> Transform3D:
	return global_transform * lean * Transform3D(Basis(), seat_at)


func exit_point() -> Vector3:
	var p := global_transform * HATCH
	return Vector3(p.x, world.height_at(p.x, p.z), p.z)


func speed() -> float:
	return v
