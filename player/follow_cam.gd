extends Node3D
## A third-person follow camera (skills/third-person-camera). This node is the pivot: it stores yaw, pitch and
## distance and rebuilds the shot from them every frame. Its SpringArm3D casts a sphere of `clear` m (well over the
## near plane's half-diagonal) against what the target collides with, feelers either side of it slide the Lens in
## before the arm is blocked, and the Lens beside the arm cuts in at once only for what they missed, holds, then
## eases out. A wall behind the target lifts the view over it before the target fades.
## In a room (the owner's `room`) the lens eases into the hero's own eye, first person, and back out at the door
## (Ravindu, 15 Nov: "first person inside the greenhouse, hab and the shelter like we did in older builds").
## Following a vehicle (`keep`, its drawn box) the pivot is inside its hull and the hull is left out of the casts, so
## the lens stands no nearer than where the arm's line leaves that box, the pitch has a chase camera's range, and the
## arm's sphere is wide enough to keep the lens off the ground.
## Every distance and time is a row of tuning.json `camera`.

const SOLIDS := 1 | 2 | 16 | 64  # CONTRACTS.md: ground, statics, vehicles, carriables; thin (4) only where the lens stands
const THIN := 4
const PROPS := 2 | 16 | 64 | THIN  # what the feelers look for: all but the ground, which has no edge to turn into

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
var may_capture := func() -> bool: return true  # the owner's answer: false while a menu or an overlay is up, so a click never hides the cursor
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
var room := false  # the owner says the target is in a room: the lens goes into its head
var first := 0.0  # 0 the follow camera, 1 the eye: eased over fp_ease_s, smoothstepped by the lens
var eye := Vector3.ZERO  # the eye in the target's space, y up, z forward along the view (negative is ahead)
var reveal := 1.0  # 0 while the lens could cut the drawn body, then up to 1 over fp_reveal_s: caps `fade`
var soft := INF  # m the feelers allow the arm (Lyra's predictive avoidance), INF with nothing near
var tail := INF  # m the arm's own line is free of the thin things the lens would stand in: a cut, as for a solid
var late := 0.0  # m of the arm's sphere the near plane does not need: a cut is eased over that last bit
var _reach := SphereShape3D.new()  # all the feelers can touch, asked once before they are cast
var show_body := false  # a cut is on: another camera films the body, so it is drawn even in first person
var keep := AABB()  # a vehicle's drawn box in its own space (the owner's), none on foot: the lens stays out of it
var out := 0.0  # m along the arm where its line leaves that box grown by vehicle_keep: the least the lens stands at


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
## vehicle's) brings the lens lower, closer and looking further ahead as the real speed nears it. `hull` is a
## vehicle's drawn box in its space: its bodies are left out of the casts, so the lens is kept out of it by this box.
func follow_target(node: Node3D, bodies: Array[RID], meshes: Array[MeshInstance3D], dist_wanted: float, pivot_height: float, drawn := AABB(), top_speed := 0.0, hull := AABB()) -> void:
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
	keep = hull
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
	soft = INF
	tail = INF
	if room:
		pitch = 0.0  # from the eye the view starts level: the default pitch frames a hero the eye does not see
	floor_y = target.global_position.y
	global_position = target.global_position + Vector3.UP * height
	dist = _wanted()
	rotation = Vector3(pitch, yaw, 0)
	# cut now by what stands behind, not at the first physics step: a frame drawn before it showed the lens where
	# the arm had not looked yet (inside HAB 1, snapped behind a rover parked against its wall)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = arm.shape
	q.collision_mask = arm.collision_mask
	q.exclude = excluded
	q.transform = Transform3D(Basis(), global_position)
	q.motion = global_basis.z * dist
	out = _leaves(global_basis.z) if keep.has_volume() else 0.0
	dist = maxf(dist * get_world_3d().direct_space_state.cast_motion(q)[0], out)
	lens.position = Vector3(0, 0, dist)
	lens.rotation = Vector3.ZERO
	if room:
		lens.into_eye(self)  # now, not at the next physics step: a frame drawn before it showed the follow view


## Turn the view by degrees: right and down are positive, as the mouse and the thumb move.
func look(right_deg: float, down_deg: float) -> void:
	yaw -= deg_to_rad(right_deg)
	var r := _pitches()
	pitch = clampf(pitch - deg_to_rad(down_deg), r.x, r.y)
	idle = 0.0
	glanced = 0.0


## The lowest and highest pitch a look may reach now, rad: the eye's in a room, a chase camera's behind a vehicle
## (looking up swings the arm down, and at the walker's 60 degrees it met the ground a metre from the pivot, under
## the rover's belly: 15 Nov playtest, "I can move the camera under the rover itself"), else the follow camera's.
func _pitches() -> Vector2:
	if room:
		return Vector2(deg_to_rad(t.fp_pitch_min), deg_to_rad(t.fp_pitch_max))
	if keep.has_volume():
		return Vector2(deg_to_rad(t.vehicle_pitch_min), deg_to_rad(t.vehicle_pitch_max))
	return Vector2(deg_to_rad(t.pitch_min), deg_to_rad(t.pitch_max))


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
	# back from a wider pitch range (the eye's) into the one that holds now, eased, never a snap
	var reach := _pitches()
	pitch = lerpf(pitch, clampf(pitch, reach.x, reach.y), 1.0 - exp(-t.ease_rate * delta))
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
	# the pivot trails the hero on its spring, and trailed into a wall or a prop the hero had just left: the arm's
	# sphere, starting inside it, came back with no length and the lens jumped into the helmet. The sphere goes from
	# the hero's own axis, which its collider keeps clear, and the pivot stops where the sphere does
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = arm.shape
	q.collision_mask = arm.collision_mask
	q.exclude = excluded
	q.transform = Transform3D(Basis(), Vector3(at.x, y, at.z))
	q.motion = Vector3(want.x + off.x - at.x, 0.0, want.z + off.z - at.z)
	global_position = q.transform.origin + q.motion * _short(q)
	# once the travel is steady the lens looks a little ahead along it; the lead builds and goes slowly, so a
	# start or a stop shows only the spring
	ahead = ahead.lerp(travel * lerpf(t.lead_time, t.rush_lead, rush), 1.0 - exp(-t.lead_rate * delta))
	var wanted := _wanted()
	# lift over a wall behind the target: measured at the player's own pitch, so the lift cannot feed itself
	var back := Basis.from_euler(Vector3(pitch, yaw, 0)).z * wanted
	q.transform = Transform3D(Basis(), global_position)
	q.motion = back
	q.collision_mask = SOLIDS
	var free: float = space.cast_motion(q)[0] * wanted
	var squeeze := clampf(inverse_lerp(wanted, t.lift_full, free), 0.0, 1.0)
	# looking up, the arm swings down behind the hero and meets the ground, which is no wall: lifting then dragged
	# the view back to eye level and the night sky could not be watched (Ravindu, 14 Nov). The arm shortens instead
	# Behind a vehicle the lift stays: its arm cannot shorten into the hull, and its pitch stops short of the sky
	if pitch > deg_to_rad(t.pitch_default) and not keep.has_volume():
		squeeze = 0.0
	lift = lerpf(lift, (reach.x - pitch) * squeeze, 1.0 - exp(-t.ease_rate * delta))
	# the ground some way ahead pitches the view: up a dune shows the crest, down one the floor (Nesky #26)
	var fwd: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw)) * t.slope_ahead
	var ray := PhysicsRayQueryParameters3D.create(at + fwd + Vector3.UP * t.slope_ahead, at + fwd + Vector3.DOWN * t.slope_ahead, 1, excluded)
	var hit := space.intersect_ray(ray)
	var rise: float = atan2(hit.position.y - floor_y, t.slope_ahead) * t.slope_share if hit else 0.0
	slope = lerpf(slope, clampf(rise, -deg_to_rad(t.slope_max_deg), deg_to_rad(t.slope_max_deg)), 1.0 - exp(-t.rise_rate * delta))
	rotation = Vector3(pitch + lift + slope, yaw, 0)
	# the hero on the lower third looking level, centred looking straight down (Kaufmann): the lens shifts the
	# picture, it does not turn, so verticals stay upright
	lens.shift = t.frame_low * clampf(inverse_lerp(deg_to_rad(t.pitch_min), 0.0, rotation.x), 0.0, 1.0)
	# kept between the lens and every solid: with only the near plane's own sphere, anything drawn a centimetre proud
	# of its collider was cut open by the near plane and showed its hollow inside
	var radius := maxf(_near_radius(), t.vehicle_clear if keep.has_volume() else t.clear)
	late = radius - _near_radius()
	(arm.shape as SphereShape3D).radius = radius
	arm.spring_length = wanted
	out = _leaves(global_basis.z) if keep.has_volume() else 0.0
	_feelers(global_position, wanted)


## How far from the pivot along `dir` (unit) the arm's line leaves the vehicle's box grown by vehicle_keep, 0 when it
## never enters it (slabs, in the vehicle's space; the distance is still in world metres).
## ponytail: the lens is only kept past the far side. A pivot above a vehicle's box (none here: the rover's roof is
## over it) could rest the lens on the near side; keep both sides if such a vehicle comes.
func _leaves(dir: Vector3) -> float:
	var box := keep.grow(t.vehicle_keep)
	var inv := target.global_transform.affine_inverse()
	var p := inv * global_position
	var d := inv.basis * dir
	var enters := -INF
	var leaves := INF
	for i in 3:
		if absf(d[i]) < 1e-6:  # along this slab: in it all the way or never, and nothing to divide by
			if p[i] < box.position[i] or p[i] > box.end[i]:
				return 0.0
			continue
		var a := (box.position[i] - p[i]) / d[i]
		var b := (box.end[i] - p[i]) / d[i]
		enters = maxf(enters, minf(a, b))
		leaves = minf(leaves, maxf(a, b))
	return leaves if is_finite(leaves) and leaves > maxf(enters, 0.0) else 0.0


## The share of q.motion the sphere may go, stopped `skin` short of what it meets. A sphere left touching a wall cannot
## move toward it at all: with the pivot or the arm's root in contact, a turn of a few degrees took the arm from its
## full length to nothing, and the lens jumped into the helmet.
func _short(q: PhysicsShapeQueryParameters3D) -> float:
	var f: float = get_world_3d().direct_space_state.cast_motion(q)[0]
	return f if f >= 1.0 else maxf(f - t.skin / maxf(q.motion.length(), 0.001), 0.0)


## Predictive avoidance (Lyra's feelers, design/research/interior-camera.md) as a cone: a sphere cast at each angle of
## `feelers` either side of the arm (and of `feel_pitch` above and below it), and a hit there allows the arm that
## hit's length plus feel_slack m for every degree the feeler inside it is off the arm. What the feelers allow then
## never changes faster than feel_slack against the view's turn, so turning toward a wall, a door frame or a prop
## slides the lens in ahead of the arm's own cut: no pop (14 Nov playtest: "whenever the camera hits an object behind
## it, the camera glitches").
## Thin things (layer 3: posts, but also machines narrower than the hero) count only over the last thin_tail m before
## where the lens would stand, on the arm's own line too (`tail`): the lens stops before one it would stand in, where
## it used to pass through and show its hollow inside. Nearer the hero they are passed and draw in front of it:
## pulling in for a post shoves the lens into the hero's back (rule 4).
## The ground is left to the arm: it has no edge the view could turn into. With nothing else in reach, nothing is cast.
func _feelers(root: Vector3, length: float) -> void:
	soft = INF
	tail = INF
	# an arm of no length has nothing to feel with, and 0 times a cast's INF is not a number: in the eye at HAB 1's
	# hatch (a thin thing in reach) `tail` and then the lens's place went NaN, and the view was sky from nowhere
	# (15 Nov playtest: "where am I even on right now? sky?")
	if length <= 0.001:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.exclude = excluded
	q.transform = Transform3D(Basis(), root)
	_reach.radius = length + (arm.shape as SphereShape3D).radius
	q.shape = _reach
	q.collision_mask = PROPS
	if space.intersect_shape(q, 1).is_empty():
		return
	q.collision_mask = THIN
	var thin := not space.intersect_shape(q, 1).is_empty()
	q.shape = arm.shape
	# where the lens would stand: the arm's length, or less where a solid stopped it last tick
	var reach := minf(length, arm.get_hit_length())
	if thin:  # the arm's own line
		tail = _thin(space, q, root, global_basis.z, reach)
	var solids := PROPS & ~THIN
	# what a feeler meets is still somewhere between it and the feeler inside it, so it allows that inner feeler's
	# slack: the lens is then in before the arm gets there, not one feeler late
	var slack := 0.0
	for deg: float in t.feelers:
		for side: float in [1.0, -1.0]:
			var dir := global_basis.rotated(Vector3.UP, deg_to_rad(deg * side)).z
			soft = minf(soft, length * _cast(space, q, root, dir * length, solids) + slack)
			if thin and deg <= float(t.feel_thin):
				soft = minf(soft, _thin(space, q, root, dir, reach) + slack)
		slack = deg * t.feel_slack
	# up and down too: without them a look up threaded the arm under the rover, and a look down over a wall's top
	slack = 0.0
	for deg: float in t.feel_pitch:
		for side: float in [1.0, -1.0]:
			var dir := Basis.from_euler(Vector3(rotation.x + deg_to_rad(deg * side), rotation.y, 0.0)).z
			soft = minf(soft, length * _cast(space, q, root, dir * length, solids) + slack)
		slack = deg * t.feel_slack


## How far the arm's sphere may go from `root` along `dir` before a thin thing the lens would stand in: one met in
## the last thin_tail m of `reach`, or one that reaches across the start of that stretch (the lens then stops before
## it: a cast that starts inside a thing comes back with nonsense, and the lens sat in a lamp's mast). One wholly
## nearer the hero is passed. INF for none.
func _thin(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, root: Vector3, dir: Vector3, reach: float) -> float:
	if reach <= 0.001:
		return INF  # the arm is cut to nothing already: no stretch left to stop in (and 0 times INF is not a number)
	var from := maxf(reach - float(t.thin_tail), 0.0)
	var first := reach * _cast(space, q, root, dir * reach, THIN)
	if first >= from:
		return first
	q.transform = Transform3D(Basis(), root + dir * from)
	q.motion = Vector3.ZERO
	if not space.intersect_shape(q, 1).is_empty():
		return first
	return from + (reach - from) * _cast(space, q, root + dir * from, dir * (reach - from), THIN)


## The share of `motion` the arm's sphere may go from `at`, INF when it meets nothing (so it limits nothing).
func _cast(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, at: Vector3, motion: Vector3, mask: int) -> float:
	q.transform = Transform3D(Basis(), at)
	q.motion = motion
	q.collision_mask = mask
	var hit: float = space.cast_motion(q)[0]
	return hit if hit < 1.0 else INF


## How far `p` is inside a room's plan (data/world.json rooms: circles and rects in the room node's space),
## negative outside: the largest of each area's own depth, so "inside grown by g" is depth > -g.
static func depth_in(spec: Dictionary, p: Vector3) -> float:
	var l: Vector3 = (spec.node as Node3D).to_local(p)
	var best := -INF
	for a: Dictionary in spec.areas:
		if a.has("circle"):
			best = maxf(best, a.circle[2] - Vector2(l.x - a.circle[0], l.z - a.circle[1]).length())
		elif a.has("rect"):
			best = maxf(best, minf(minf(l.x - a.rect[0], a.rect[2] - l.x), minf(l.z - a.rect[1], a.rect[3] - l.z)))
	return best


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
## sphere overlap at the lens that counts thin things too. The sphere is the near plane's, without the arm's margin:
## a lens kept that margin off a wall touches it with the arm's sphere, and touching is not inside.
func inside() -> bool:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(global_position, lens.global_position, SOLIDS, excluded)
	if space.intersect_ray(ray):
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	var near := SphereShape3D.new()
	near.radius = _near_radius() - arm.margin
	q.shape = near
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
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION and may_capture.call():
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
		var safe: float = minf(rig.arm.get_hit_length(), rig.tail)
		var step: float = rig.t.feel_rate * delta
		var want := minf(safe, rig.soft)
		if want < rig.dist:
			# a feeler sees a wall coming, or the arm is blocked: in at a held speed, never a jump, but at once to
			# where the near plane is clear of what blocks (the arm's sphere is `late` wider than the near plane
			# needs, so only that last bit of a cut is eased); then hold
			rig.dist = minf(maxf(want, rig.dist - step), safe + rig.late)
			rig.hold = rig.t.hold_time
		elif rig.hold > 0.0:
			rig.hold -= delta
		else:
			rig.dist = minf(lerpf(rig.dist, minf(safe, rig.soft), 1.0 - exp(-rig.t.ease_rate * delta)), rig.dist + step)
		# never in a vehicle's own box, whatever cut the arm: its line leaves the box at `out`, which moves smoothly
		# with the view, so the lens slides along the box and does not pop
		rig.dist = maxf(rig.dist, rig.out)
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
			into_eye(rig)
		# a body seen from its own head shows its shoulders as triangles at the lens, and one met by the near plane
		# shows half drawn: hidden while the lens is within the near sphere of the drawn box (in first person, and
		# through the ease), then faded back in over fp_reveal_s once clear, never popped
		if rig.shell.has_volume():
			var p: Vector3 = rig.target.global_transform.affine_inverse() * global_position
			var clear: bool = p.distance_to(p.clamp(rig.shell.position, rig.shell.end)) > rig._near_radius()
			rig.reveal = move_toward(rig.reveal, 1.0, delta / rig.t.fp_reveal_s) if clear and rig.first < 1.0 else 0.0
			rig.fade = minf(rig.fade, rig.reveal)
		if rig.show_body:
			rig.reveal = 1.0
			rig.fade = 1.0

	## Toward the eye: position lerped, rotation slerped, one smoothstep for both. The lens sits on the arm's free line
	## from the pivot, so the straight path from it to the eye stays in what the arm already cleared (the doorway).
	## Pitch and yaw are the player's own in both views, never a roll.
	func into_eye(rig: Node3D) -> void:
		var s := smoothstep(0.0, 1.0, rig.first)
		var at: Vector3 = rig.target.global_position + Vector3.UP * rig.eye.y + Basis(Vector3.UP, rig.yaw) * Vector3(0.0, 0.0, rig.eye.z)
		var aim := Basis.from_euler(Vector3(rig.pitch, rig.yaw, 0.0)).get_rotation_quaternion()
		global_transform = Transform3D(Basis(global_basis.get_rotation_quaternion().slerp(aim, s)), global_position.lerp(at, s))
		var h := 2.0 * near * tan(deg_to_rad(fov) / 2.0)
		set_frustum(h, Vector2(0.0, shift * h * (1.0 - s)), near, far)
