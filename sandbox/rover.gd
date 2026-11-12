extends AnimatableBody3D
## Drives the crewed rover over the real ground (CONTRACTS.md vehicle). Kinematic, not VehicleBody3D (unproven
## under Jolt in the web build): the sheet's top speed and acceleration, a pivot on the spot as the real SEV's
## swivelling wheels allow, height and tilt from the ground under its wheels, tracks pressed into the dust.

var world: Node3D
var top: float  # m/s
var accel: float  # m/s2
var turn: float  # rad/s
var track_every: float  # metres between wheel prints
var v := 0.0
var yaw := 0.0
var travelled := 0.0
var wheels: Array[Node3D] = []
var radius := 0.495  # the SEV's 39 in wheel
# local points the body rests on, the driver's seat and the rear hatch, from the model (forge/vehicle_rover.py)
const AXLE := 1.55
const TRACK := 1.0
const SEAT := Vector3(-0.5, 1.4, -1.3)
const HATCH := Vector3(0.0, 0.0, 3.2)


func setup(w: Node3D, sheet: Dictionary, tuning: Dictionary) -> void:
	world = w
	for r: Dictionary in sheet.rows:
		match r.id:
			"rover.speed.max": top = r.value
			"rover.accel": accel = r.value
			"rover.turn": turn = deg_to_rad(r.value)
	track_every = tuning.interact.track_every
	# the ground holds it up through _settle(), so the sweep must not stop on the ground it rests on
	collision_mask &= ~1
	yaw = rotation.y
	for n: Node in find_children("wheel_*", "Node3D", true, false):
		wheels.append(n)


## input.x steers (right positive), input.y is throttle (forward positive), CONTRACTS.md.
func drive(input: Vector2, _hurry: bool, delta: float) -> void:
	v = move_toward(v, input.y * top, accel * delta)
	# backing up turns the other way, as a car does
	yaw -= input.x * turn * delta * (1.0 if v >= -0.05 else -1.0)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var before := global_position
	var hit := move_and_collide(fwd * v * delta)
	if hit:
		v = 0.0  # a wall stops it dead; no bounce
	_settle()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() * signf(v)
	for wh in wheels:
		wh.rotate_object_local(Vector3.RIGHT, -moved / radius)
	travelled += absf(moved)
	if travelled >= track_every:
		travelled = 0.0
		for side: float in [-TRACK, TRACK]:
			var p := global_transform * Vector3(side, 0.0, AXLE)
			world.mark(p, -rad_to_deg(yaw), "wheel", 0.3)
		if absf(v) > top * 0.5:
			# a rolling tyre's tread leaves the ground backward at the rover's speed
			for side: float in [-TRACK, TRACK]:
				world.puff(global_transform * Vector3(side, 0.0, AXLE + 0.5), -Vector3(-sin(yaw), 0.0, -cos(yaw)) * v, 0.5, "wheel")


## Height and tilt from the ground under the four corner wheels.
func _settle() -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	var at := global_position
	var h := func(p: Vector3) -> float: return world.height_at(p.x, p.z)
	var front: float = (h.call(at + fwd * AXLE + side * TRACK) + h.call(at + fwd * AXLE - side * TRACK)) / 2.0
	var back: float = (h.call(at - fwd * AXLE + side * TRACK) + h.call(at - fwd * AXLE - side * TRACK)) / 2.0
	var right: float = (h.call(at + side * TRACK + fwd * AXLE) + h.call(at + side * TRACK - fwd * AXLE)) / 2.0
	var left: float = (h.call(at - side * TRACK + fwd * AXLE) + h.call(at - side * TRACK - fwd * AXLE)) / 2.0
	var pitch := atan2(front - back, 2.0 * AXLE)
	var roll := atan2(right - left, 2.0 * TRACK)
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), Vector3(at.x, (front + back) / 2.0, at.z))


func seat() -> Transform3D:
	return global_transform * Transform3D(Basis(), SEAT)


func exit_point() -> Vector3:
	var p := global_transform * HATCH
	return Vector3(p.x, world.height_at(p.x, p.z), p.z)


func speed() -> float:
	return v
