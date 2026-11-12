extends AnimatableBody3D
## Drives the crewed rover over the real ground (CONTRACTS.md vehicle). Kinematic, not VehicleBody3D (unproven
## under Jolt in the web build): the sheet's top speed, acceleration and braking, a pivot on the spot as the real
## SEV's swivelling wheels allow. Each wheel rests on the ground or on the rock under it (world.wheel_rest()): it
## rolls up rocks up to the sheet's climb height, the body takes its height and tilt from the six wheels, and each
## wheel takes up the rest on its suspension. A taller rock, or a wall, ahead within the braking distance brakes it
## to a stop at the contact. Tracks, a dust stream from the wheels, and a moving contact shadow on the ground.

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
var shade: Dictionary  # tuning.rover: contact shadow discs
var v := 0.0
var yaw := 0.0
var travelled := 0.0
var wheels: Array[Node3D] = []
var hubs: Array[Vector3] = []  # each wheel's hub at rest, in the body's space
var rest_at: Array[Vector3] = []  # each wheel node's rest position in its parent
var seat_at := Vector3(-0.5, 1.66, -0.85)  # replaced by the model's `seat` node
var blocked := ""  # what stopped it last: "", "rock", "wall" (for checks)
var on_rock := 0.0  # m, the highest rock a wheel stands on now (for checks)
var _belly := BoxShape3D.new()


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
	var p := _pose(global_position, yaw)
	_apply(p)


## input.x steers (right positive), input.y is throttle (forward positive), CONTRACTS.md.
func drive(input: Vector2, _hurry: bool, delta: float) -> void:
	var want := input.y * top
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	# anything ahead within the braking distance brakes it now, so it stops at the contact, not inside it
	blocked = ""
	if absf(v) > 0.01:
		var look := v * v / (2.0 * brake) + absf(v) * delta
		blocked = _blocked(fwd * signf(v) * look)
	if blocked != "" and signf(want) != -signf(v):
		want = 0.0  # the driver's throttle waits; backing away is allowed
	# speeding up takes the motors' acceleration, slowing down the brakes'
	var speeding := absf(want) > absf(v) and (signf(want) == signf(v) or is_zero_approx(v))
	v = move_toward(v, want, (accel if speeding else brake) * delta)
	# backing up turns the other way, as a car does
	var new_yaw := yaw - input.x * turn * delta * (1.0 if v >= -0.05 else -1.0)
	var step := fwd * v * delta
	var before := global_position
	var at := global_position + step
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
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() * signf(v)
	for wh in wheels:
		wh.rotate_object_local(Vector3.RIGHT, -moved / radius)
	_ground_fx(moved)


## What stops a move of `step` (world): "rock" (a wheel would meet a rock over the climb height, or the belly one),
## "wall" (the body's sweep meets a solid) or "".
func _blocked(step: Vector3) -> String:
	var at := global_position + step
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
	return {"ok": ok, "basis": basis, "origin": origin, "lift": lift, "rock": rock}


func _apply(p: Dictionary) -> void:
	global_transform = Transform3D(p.basis, p.origin)
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
		world.stream("rover%d" % int(side), p, back * absf(v), absf(v) / top)
	if travelled >= track_every:
		travelled = 0.0
		for side: float in [-TRACK, TRACK]:
			var p := global_transform * Vector3(side, 0.0, AXLE)
			world.mark(p, -rad_to_deg(yaw), "wheel", 0.3)


func seat() -> Transform3D:
	return global_transform * Transform3D(Basis(), seat_at)


func exit_point() -> Vector3:
	var p := global_transform * HATCH
	return Vector3(p.x, world.height_at(p.x, p.z), p.z)


func speed() -> float:
	return v
