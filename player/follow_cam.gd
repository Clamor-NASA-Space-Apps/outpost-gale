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
var faded: Array[MeshInstance3D] = []  # the hero's meshes, which fade when the lens is close
var shell := AABB()  # the drawn body in the target's space; none for a vehicle, which never fades
var fade := 1.0  # 1 solid, 0 hidden: by the lens's gap to `shell` (Lens); the owner applies it to its materials
var distance := 0.0  # the wanted distance at the default pitch
var height := 0.0  # pivot above the target's floor
var yaw := 0.0  # radians, as rotation.y: 0 puts the lens south of the target looking north
var pitch := 0.0  # radians, negative looks down
var lift := 0.0  # extra pitch over a wall behind the target
var dist := 0.0  # where the lens is now
var hold := 0.0
var idle := 0.0  # seconds since the player last looked
var floor_y := 0.0
var vel := Vector3.ZERO  # the pivot's own speed across the ground, for its spring
var ahead := Vector3.ZERO  # where the lens aims past the pivot, along the travel
var steady := Vector3.ZERO  # the travel, slowly averaged: what the spring may lead by
var slope := 0.0  # rad of extra pitch for the ground ahead
var fast := 0.0  # m/s at which the shot is all the way into its speed framing (rush_*); 0 for none (on foot)
var rush := 0.0  # 0 to 1: how far into it, eased by lead_rate so a start or a stop never jerks the lens
var glance: Array[Vector3] = []  # far things worth a slow look while the view is left alone (the owner fills it)
var glanced := 0.0  # rad the view has turned toward them since the player last looked
var room := false  # the owner says the target is in a room: the lens goes into its head (skills/third-person-camera,
# Into first person indoors)
var first := 0.0  # 0 the follow camera, 1 the eye: eased over fp_ease_s, smoothstepped by the lens
var eye := Vector3.ZERO  # the eye in the target's space, y up, z forward along the view (negative is ahead)
var reveal := 1.0  # 0 while the lens could cut the drawn body, then up to 1 over fp_reveal_s: caps `fade`
var show_body := false  # a cut is on (player.perform): another camera films the body, so it is drawn even in first person


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


## Follow `node`. `bodies` are left out of every cast (the hero, or the vehicle), `meshes` fade when the lens
## comes within the camera's fade range of `drawn`, the body's box in the node's space. `top_speed` (m/s, a
## vehicle's) brings the lens lower, closer and looking further ahead as the real speed nears it.
func follow_target(node: Node3D, bodies: Array[RID], meshes: Array[MeshInstance3D], dist_wanted: float, pivot_height: float, drawn := AABB(), top_speed := 0.0) -> void:
	for r in excluded:
		arm.remove_excluded_object(r)
	excluded = bodies
	for r in excluded:
		arm.add_excluded_object(r)
	target = node
	faded = meshes
	shell = drawn
	distance = dist_wanted
	height = pivot_height
	fast = top_speed
	snap(-node.global_rotation.y)


## Straight behind the target at the default pitch, no easing left over (a teleport, a probe row).
func snap(heading: float) -> void:
	yaw = heading
	pitch = deg_to_rad(t.pitch_default)
	lift = 0.0
	hold = 0.0
	idle = 0.0
	vel = Vector3.ZERO
	ahead = Vector3.ZERO
	steady = Vector3.ZERO
	slope = 0.0
	rush = 0.0
	glanced = 0.0
	first = 1.0 if room else 0.0  # a teleport into a room is already in first person
	reveal = 0.0 if room else 1.0
	floor_y = target.global_position.y
	global_position = target.global_position + Vector3.UP * height
	dist = _wanted()
	rotation = Vector3(pitch, yaw, 0)
	lens.position = Vector3(0, 0, dist)


## Turn the view by degrees: right and down are positive, as the mouse and the thumb move.
func look(right_deg: float, down_deg: float) -> void:
	yaw -= deg_to_rad(right_deg)
	var lo: float = t.fp_pitch_min if room else t.pitch_min
	var hi: float = t.fp_pitch_max if room else t.pitch_max
	pitch = clampf(pitch - deg_to_rad(down_deg), deg_to_rad(lo), deg_to_rad(hi))
	idle = 0.0
	glanced = 0.0


## The camera's flat heading: what "forward" means for the move keys.
func ground_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


## Called by the player after the target moved this physics frame (skills/third-person-camera rule 14: a calm
## frame, a lively hero). `travel` is the target's real ground velocity, `facing` its heading as rotation.y
## (the way a vehicle points, which may be backing up), `on_floor` keeps hops out of the pivot's height.
func follow(delta: float, travel: Vector3, facing: float, on_floor: bool) -> void:
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick != Vector2.ZERO:
		look(stick.x * t.stick_deg_per_s * delta, stick.y * t.stick_deg_per_s * delta)
	idle += delta
	first = move_toward(first, 1.0 if room else 0.0, delta / t.fp_ease_s)
	if not room:
		# back from the eye's wider pitch range into the follow camera's, eased, never a snap
		pitch = lerpf(pitch, clampf(pitch, deg_to_rad(t.pitch_min), deg_to_rad(t.pitch_max)), 1.0 - exp(-t.ease_rate * delta))
	var speed := travel.length()
	# a phone player has no thumb free to look: left alone, the view drifts behind the real travel like a towed
	# leash, by distance covered, so it never turns while the target stands or pushes into a wall (Nesky #23)
	# Never while the travel comes toward the lens: swinging round behind a hero walking at the camera turns
	# "back" with it, and the hero walks in circles (found by the doors test, walking out of a building)
	var away := travel.dot(Vector3(-sin(yaw), 0, -cos(yaw))) > 0.0
	# In first person every turn is the player's (Xbox AG 117: no camera motion the player did not start)
	var mine := first > 0.0
	if idle > t.recentre_after and speed > 0.0 and away and not mine:
		var heading := facing if travel.dot(Vector3(-sin(facing), 0, -cos(facing))) < 0.0 else atan2(-travel.x, -travel.z)
		yaw = lerp_angle(yaw, heading, 1.0 - exp(-t.recentre_per_m * speed * delta))
	# a far thing worth seeing (Nesky #32: for a far target, rotate): with the view left alone and the hero standing
	# on foot (`fast` is a vehicle's), the yaw turns slowly toward the one most in front, a few degrees at most, and
	# the next look takes over at once (#34, #35: never take control, never while the player looks). Yaw only
	elif glance.size() and not mine and idle > t.glance_after and speed < 0.05 and fast == 0.0 and glanced < deg_to_rad(t.glance_max_deg):
		var best := INF
		for p in glance:
			var err := wrapf(atan2(global_position.x - p.x, global_position.z - p.z) - yaw, -PI, PI)
			best = err if absf(err) < absf(best) else best
		if absf(best) < deg_to_rad(t.glance_front_deg):
			var step := signf(best) * minf(absf(best), deg_to_rad(t.glance_deg_s) * delta)
			yaw += step
			glanced += absf(step)
	var at := target.global_position
	if on_floor:
		floor_y = at.y
	# across: a critically damped spring with a limit, so the hero pulls ahead at a start and the camera
	# arrives late at a stop, never overshooting. It trails a steady pace by 2 v / w; leading by that much once
	# the pace has held (`steady` builds slowly) puts a steady walk back on the frame (Solar Ash: no horizontal
	# lag at speed). Up: slower, toward the floor under the hero, not the hop.
	var w: float = t.follow_rate
	steady = steady.lerp(travel, 1.0 - exp(-t.lead_rate * delta))
	var want := Vector3(at.x, global_position.y, at.z) + steady * (2.0 / w)
	var off := global_position - want
	var push := (vel + w * off) * delta
	var decay := exp(-w * delta)
	vel = (vel - w * push) * decay
	off = ((off + push) * decay).limit_length(t.follow_limit)
	# speed you can feel without faking it: the ground nearer the lens streams past faster (Need for Speed and Forza
	# chase cams sit lower and closer as speed builds); the field of view stays fixed (rule 14)
	rush = lerpf(rush, clampf(speed / fast, 0.0, 1.0) if fast > 0.0 else 0.0, 1.0 - exp(-t.lead_rate * delta))
	var y := lerpf(global_position.y, floor_y + height * lerpf(1.0, t.rush_height, rush), 1.0 - exp(-t.rise_rate * delta))
	global_position = Vector3(want.x + off.x, y, want.z + off.z)
	# once the travel is steady the lens looks a little ahead along it; the lead builds and goes slowly, so a
	# start or a stop shows only the spring
	ahead = ahead.lerp(travel * lerpf(t.lead_time, t.rush_lead, rush), 1.0 - exp(-t.lead_rate * delta))
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
	var squeeze := clampf(inverse_lerp(wanted, t.lift_full, free), 0.0, 1.0)
	# looking up, the arm swings down behind the hero and meets the ground, which is no wall: lifting then dragged
	# the view back to eye level and the night sky could not be watched (Ravindu, 14 Nov). The arm shortens instead
	if pitch > deg_to_rad(t.pitch_default):
		squeeze = 0.0
	lift = lerpf(lift, (deg_to_rad(t.pitch_min) - pitch) * squeeze, 1.0 - exp(-t.ease_rate * delta))
	# the ground some way ahead pitches the view: up a dune shows the crest, down one the floor (Nesky #26)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw)) * t.slope_ahead
	var ray := PhysicsRayQueryParameters3D.create(at + fwd + Vector3.UP * t.slope_ahead, at + fwd + Vector3.DOWN * t.slope_ahead, 1, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var rise: float = atan2(hit.position.y - floor_y, t.slope_ahead) * t.slope_share if hit else 0.0
	slope = lerpf(slope, clampf(rise, -deg_to_rad(t.slope_max_deg), deg_to_rad(t.slope_max_deg)), 1.0 - exp(-t.rise_rate * delta))
	rotation = Vector3(pitch + lift + slope, yaw, 0)
	# the hero on the lower third looking level, centred looking straight down (Kaufmann): the lens shifts the
	# picture, it does not turn, so verticals stay upright
	lens.shift = t.frame_low * clampf(inverse_lerp(deg_to_rad(t.pitch_min), 0.0, rotation.x), 0.0, 1.0)
	(arm.shape as SphereShape3D).radius = _near_radius()
	arm.spring_length = wanted


## Closer when looking up, a little farther when looking down, so the target keeps its size on screen.
func _wanted() -> float:
	var pd := deg_to_rad(t.pitch_default)
	var k: float = distance * lerpf(1.0, t.rush_distance, rush) / t.distance
	if pitch >= pd:
		return k * lerpf(t.distance, t.distance_up, inverse_lerp(pd, deg_to_rad(t.pitch_max), pitch))
	return k * lerpf(t.distance, t.distance_down, inverse_lerp(pd, deg_to_rad(t.pitch_min), pitch))


## A sphere a bit larger than the near plane's half-diagonal, so the near plane never cuts into a surface.
func _near_radius() -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var half := lens.near * tan(deg_to_rad(lens.fov) / 2.0)
	return Vector2(half * aspect, half * (1.0 + 2.0 * lens.shift)).length() + arm.margin  # the shifted top corner


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


## The target's height as a share of the frame, 0 when it is hidden or behind the lens, or seen from its own eye.
func on_screen(feet: Vector3, tall: float) -> float:
	if faded.is_empty() or not faded[0].visible or first > 0.0 or lens.is_position_behind(feet):
		return 0.0
	var a := lens.unproject_position(feet)
	var b := lens.unproject_position(feet + Vector3.UP * tall)
	return absf(a.y - b.y) / get_viewport().get_visible_rect().size.y


## The cursor is captured only by a left click that reached the 3D view: a HUD control, the settings screen and the
## cover take their own clicks first (MOUSE_FILTER_STOP). Any button used to capture, and a touchpad's two-finger
## scroll is a stream of wheel "presses", so the cursor vanished while the player only scrolled (13 Nov playtest).
func _unhandled_input(e: InputEvent) -> void:
	# the browser allows a capture only from inside an input event; a touch's made-up click never captures
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(e.screen_relative.x * t.mouse_deg_per_px, e.screen_relative.y * t.mouse_deg_per_px)


## Another window took the keyboard: give the cursor back, or it stays hidden over the desktop.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Sits beside the arm, not under it: the arm would snap a child both ways, and the lens must ease out.
class Lens extends Camera3D:
	var shift := 0.0  # share of the frame height the picture moves up, so the pivot sits that far below centre

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
		rotation = Vector3.ZERO
		if rig.ahead.length() > 0.01:
			look_at(rig.global_position + rig.ahead)  # aim only: the lens stays where the arm put it
		# an off-axis frustum the size the fov would give: the same lens, its picture moved up
		var h := 2.0 * near * tan(deg_to_rad(fov) / 2.0)
		set_frustum(h, Vector2(0.0, shift * h), near, far)
		# the gap from the lens to the drawn body, not to the pivot: over a backpack or a helmet the lens is
		# much nearer the suit than the arm's length says. The whole body fades as one (Opsive's Object
		# Fader): solid as long as possible, then gone before the near plane could cut into it.
		rig.fade = 1.0
		if rig.shell.has_volume():
			var p: Vector3 = rig.target.global_transform.affine_inverse() * global_position
			var gap := p.distance_to(p.clamp(rig.shell.position, rig.shell.end))
			rig.fade = smoothstep(rig.t.fade_near, rig.t.fade_far, gap)
		if rig.first > 0.0:
			_into_eye(rig, h)
		# a body seen from its own head shows its shoulders as triangles at the lens, and one met by the near plane
		# shows half drawn: hidden while the lens is within the near sphere of the drawn box (in first person, and
		# through the ease), then faded back in over fp_reveal_s once clear, never popped (skills/third-person-camera)
		if rig.shell.has_volume():
			var p: Vector3 = rig.target.global_transform.affine_inverse() * global_position
			var clear: bool = p.distance_to(p.clamp(rig.shell.position, rig.shell.end)) > rig._near_radius()
			rig.reveal = move_toward(rig.reveal, 1.0, delta / rig.t.fp_reveal_s) if clear and rig.first < 1.0 else 0.0
			rig.fade = minf(rig.fade, rig.reveal)
		if rig.show_body:
			rig.reveal = 1.0
			rig.fade = 1.0

	## Toward the eye: position lerped, rotation slerped, one smoothstep for both. The lens above sits on the arm's
	## free line from the pivot, so the straight path from it to the eye stays in what the arm already cleared (the
	## doorway). Pitch and yaw are the player's own in both views, never a roll.
	func _into_eye(rig: Node3D, h: float) -> void:
		var s := smoothstep(0.0, 1.0, rig.first)
		var at: Vector3 = rig.target.global_position + Vector3.UP * rig.eye.y + Basis(Vector3.UP, rig.yaw) * Vector3(0.0, 0.0, rig.eye.z)
		var aim := Basis.from_euler(Vector3(rig.pitch, rig.yaw, 0.0)).get_rotation_quaternion()
		global_transform = Transform3D(Basis(global_basis.get_rotation_quaternion().slerp(aim, s)), global_position.lerp(at, s))
		set_frustum(h, Vector2(0.0, shift * h * (1.0 - s)), near, far)
