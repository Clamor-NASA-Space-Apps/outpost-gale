extends Node3D
## A third-person follow camera (skills/third-person-camera). This node is the pivot: it stores yaw, pitch and
## distance and rebuilds the shot from them every frame. Its SpringArm3D casts a sphere the size of the near
## plane against what the target collides with (thin things left out), and the Lens beside the arm cuts in at
## once, holds, then eases out. A wall behind the target lifts the view over it before the target fades.
## Every distance and time is a row of tuning.json `camera`.

const SOLIDS := 1 | 2 | 16 | 64  # CONTRACTS.md: ground, statics, vehicles, carriables; thin (4) never moves the lens
const THIN := 4

var t: Dictionary
var arm: SpringArm3D
var lens: Lens
var target: Node3D
var excluded: Array[RID] = []
var faded: Array[MeshInstance3D] = []  # the hero's meshes, which hide when the lens is inside them
var distance := 0.0  # the wanted distance at the default pitch
var height := 0.0  # pivot above the target's floor
var yaw := 0.0  # radians, as rotation.y: 0 puts the lens south of the target looking north
var pitch := 0.0  # radians, negative looks down
var lift := 0.0  # extra pitch over a wall behind the target
var dist := 0.0  # where the lens is now
var hold := 0.0
var idle := 0.0  # seconds since the player last looked
var floor_y := 0.0


func setup(tuning: Dictionary) -> void:
	t = tuning
	arm = SpringArm3D.new()
	arm.shape = SphereShape3D.new()
	arm.collision_mask = SOLIDS
	add_child(arm)
	lens = Lens.new()
	lens.far = 8000.0
	add_child(lens)  # after the arm, so it reads this frame's cast
	lens.make_current()


## Follow `node`. `bodies` are left out of every cast (the hero, or the vehicle), `meshes` hide when the lens is close.
func follow_target(node: Node3D, bodies: Array[RID], meshes: Array[MeshInstance3D], dist_wanted: float, pivot_height: float) -> void:
	for r in excluded:
		arm.remove_excluded_object(r)
	excluded = bodies
	for r in excluded:
		arm.add_excluded_object(r)
	target = node
	faded = meshes
	distance = dist_wanted
	height = pivot_height
	snap(-node.global_rotation.y)


## Straight behind the target at the default pitch, no easing left over (a teleport, a probe row).
func snap(heading: float) -> void:
	yaw = heading
	pitch = deg_to_rad(t.pitch_default)
	lift = 0.0
	hold = 0.0
	idle = 0.0
	floor_y = target.global_position.y
	global_position = target.global_position + Vector3.UP * height
	dist = _wanted()
	rotation = Vector3(pitch, yaw, 0)
	lens.position = Vector3(0, 0, dist)


## Turn the view by degrees: right and down are positive, as the mouse and the thumb move.
func look(right_deg: float, down_deg: float) -> void:
	yaw -= deg_to_rad(right_deg)
	pitch = clampf(pitch - deg_to_rad(down_deg), deg_to_rad(t.pitch_min), deg_to_rad(t.pitch_max))
	idle = 0.0


## The camera's flat heading: what "forward" means for the move keys.
func ground_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


## Called by the player after the target moved this physics frame. `heading` is where the target travels,
## `on_floor` keeps hops out of the pivot's height.
func follow(delta: float, heading: float, moving: bool, on_floor: bool) -> void:
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick != Vector2.ZERO:
		look(stick.x * t.stick_deg_per_s * delta, stick.y * t.stick_deg_per_s * delta)
	idle += delta
	# a phone player has no thumb free to look: left alone, the view swings back behind the travel
	if idle > t.recentre_after and moving:
		yaw = lerp_angle(yaw, heading, 1.0 - exp(-t.recentre_rate * delta))
	var at := target.global_position
	if on_floor:
		floor_y = at.y
	var want := Vector3(at.x, floor_y + height, at.z)
	var p := global_position.lerp(want, 1.0 - exp(-t.follow_rate * delta))
	global_position = want + (p - want).limit_length(t.follow_limit)  # an elastic band with a limit
	var wanted := _wanted()
	# lift over a wall behind the target: measured at the player's own pitch, so the lift cannot feed itself
	var back := Basis.from_euler(Vector3(pitch, yaw, 0)).z * wanted
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = arm.shape
	q.transform = Transform3D(Basis(), global_position)
	q.motion = back
	q.collision_mask = SOLIDS
	q.exclude = excluded
	var free: float = get_world_3d().direct_space_state.cast_motion(q)[0] * wanted
	var squeeze := clampf(inverse_lerp(wanted, t.fade_far, free), 0.0, 1.0)
	lift = lerpf(lift, (deg_to_rad(t.pitch_min) - pitch) * squeeze, 1.0 - exp(-t.ease_rate * delta))
	rotation = Vector3(pitch + lift, yaw, 0)
	(arm.shape as SphereShape3D).radius = _near_radius()
	arm.spring_length = wanted


## Closer when looking up, a little farther when looking down, so the target keeps its size on screen.
func _wanted() -> float:
	var pd := deg_to_rad(t.pitch_default)
	var k: float = distance / t.distance
	if pitch >= pd:
		return k * lerpf(t.distance, t.distance_up, inverse_lerp(pd, deg_to_rad(t.pitch_max), pitch))
	return k * lerpf(t.distance, t.distance_down, inverse_lerp(pd, deg_to_rad(t.pitch_min), pitch))


## A sphere a bit larger than the near plane's half-diagonal, so the near plane never cuts into a surface.
func _near_radius() -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	return lens.near * tan(deg_to_rad(lens.fov) / 2.0) * sqrt(1.0 + aspect * aspect) + arm.margin


## Is the lens inside or behind a solid? Not the arm's own cast: a ray from the pivot to the lens, and a
## sphere overlap at the lens that counts thin things too.
func inside() -> bool:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(global_position, lens.global_position, SOLIDS, excluded)
	if space.intersect_ray(ray):
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = arm.shape
	q.transform = Transform3D(Basis(), lens.global_position)
	q.collision_mask = SOLIDS | THIN
	q.exclude = excluded
	return not space.intersect_shape(q, 1).is_empty()


## The target's height as a share of the frame, 0 when it is hidden or behind the lens.
func on_screen(feet: Vector3, tall: float) -> float:
	if faded.is_empty() or not faded[0].visible or lens.is_position_behind(feet):
		return 0.0
	var a := lens.unproject_position(feet)
	var b := lens.unproject_position(feet + Vector3.UP * tall)
	return absf(a.y - b.y) / get_viewport().get_visible_rect().size.y


func _unhandled_input(e: InputEvent) -> void:
	# the browser allows a capture only from inside an input event; a touch's made-up click never captures
	if e is InputEventMouseButton and e.pressed and e.device != InputEvent.DEVICE_ID_EMULATION:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(e.screen_relative.x * t.mouse_deg_per_px, e.screen_relative.y * t.mouse_deg_per_px)


## Sits beside the arm, not under it: the arm would snap a child both ways, and the lens must ease out.
class Lens extends Camera3D:
	func _physics_process(delta: float) -> void:
		var rig: Node3D = get_parent()
		var safe: float = rig.arm.get_hit_length()
		if safe < rig.dist:
			rig.dist = safe  # blocked: cut in at once
			rig.hold = rig.t.hold_time
		elif rig.hold > 0.0:
			rig.hold -= delta
		else:
			rig.dist = lerpf(rig.dist, safe, 1.0 - exp(-rig.t.ease_rate * delta))
		position = Vector3(0, 0, rig.dist)  # the arm casts along its +Z, the lens looks back down -Z
		for m: MeshInstance3D in rig.faded:
			m.visible = rig.dist > rig.t.fade_near  # never show the inside of the hero's head
