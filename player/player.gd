extends Node3D
## The hero a player controls (CONTRACTS.md): a CharacterBody3D under Jolt, its drawn model, the follow camera
## and the touch controls. Physical numbers come from the reality sheet and feel numbers from tuning.json, so
## this file holds none. It keeps the hero out of things and says where it is; it decides no rules.

const HeroModel := preload("res://player/hero_model.gd")
const FollowCam := preload("res://player/follow_cam.gd")
const Touch := preload("res://player/touch.gd")
const Controls := preload("res://player/controls.gd")
const HERO_LAYER := 8
const MASK := 1 | 2 | 4 | 16 | 64  # ground, statics, thin, vehicles, carriables (CONTRACTS.md)
const OVERLAP := 2 | 4 | 16 | 64  # what the drawn body must never be inside; the step lift keeps the floor out
# The model and the names in its rig. Another hero swaps these and nothing else.
const MODEL := "res://models/character_astronaut.glb"
const RIG := {
	"idle": "Idle", "walk": "Walk", "run": "Run", "feet": ["Foot.L", "Foot.R"], "hips": "Hips",
	"legs": [["UpperLeg.L", "LowerLeg.L", "Foot.L"], ["UpperLeg.R", "LowerLeg.R", "Foot.R"]],
}

## A foot pressed onto the ground: each plant of a walk or run, and both feet on landing. `pos` is under the
## foot at the floor, `yaw_deg` the heading (CONTRACTS.md), `foot` is "foot_l" or "foot_r".
signal footstep(pos: Vector3, yaw_deg: float, foot: String)

const FEET := ["foot_l", "foot_r"]  # in the order of RIG.feet

var body: CharacterBody3D
var model: HeroModel
var cam: FollowCam
var touch: Touch
var tuning: Dictionary
var meshes: Array[MeshInstance3D] = []
var vehicle: Node3D = null
var gait := "idle"
# from the sheet, read once
var gravity: float
var walk: float
var hurry: float
var brake: float  # m/s2: the sheet's stop distance from a hurry
var hop_speed: float
var step: float
var pivot: float  # rad/s standing turn rate
var run_from: float  # walk to run and back, with hysteresis
var walk_from: float
var idle_below: float
# the body's own state
var yaw := 0.0  # rotation.y of the heading
var speed := 0.0  # along the heading
var coyote := 0.0
var buffer := 0.0
var launch := -1.0  # seconds of crouch left before take-off, negative when no hop is coming
var last_pos := Vector3.ZERO
var moved := 0.0  # horizontal speed from the change of position
var lower := -1  # which foot is drawn lower, the one bearing the body
var on_floor := false  # the body's floor contact, or a floor it was snapped down onto this frame


func _ready() -> void:
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json"))
	tuning = JSON.parse_string(FileAccess.get_file_as_string("res://data/tuning.json"))
	Controls.register(tuning.input.stick_deadzone)  # the joystick needs its actions now; the root's later call skips them
	var row := func(id: String) -> float:
		for r: Dictionary in sheet.rows:
			if r.id == id:
				return r.value
		push_error("reality.json has no row %s" % id)
		return NAN
	gravity = sheet.gravity
	walk = row.call("hero.speed.walk")
	hurry = row.call("hero.speed.hurry")
	brake = hurry * hurry / (2.0 * row.call("hero.stop"))  # v^2 / 2d
	hop_speed = sqrt(2.0 * gravity * row.call("hero.jump.hop"))  # rise v^2 / 2g
	step = row.call("hero.step")
	var leg: float = row.call("hero.leg")
	pivot = sqrt(gravity / leg)  # a leg swings as a pendulum: about one step's turn per swing
	# Froude number v^2 / (g leg): people leave the walk between 0.4 and 0.6 (Alexander and Jayes 1983)
	run_from = sqrt(0.6 * gravity * leg)
	walk_from = sqrt(0.4 * gravity * leg)
	idle_below = brake / Engine.physics_ticks_per_second  # less than one frame of speed change

	body = CharacterBody3D.new()
	body.name = "Hero"
	body.collision_layer = HERO_LAYER
	body.collision_mask = MASK
	# no engine snap: under Jolt it pulls the lifted cylinder a full snap length down past the separation ray
	# (measured: the feet sank exactly the snap length and stayed there). _settle() does it by hand.
	body.floor_snap_length = 0.0
	body.floor_max_angle = deg_to_rad(row.call("hero.slope.max"))
	add_child(body)
	var design := Forge.HouseStyle.load_design("res://design.json")
	model = HeroModel.new()
	body.add_child(model)
	model.setup(load(MODEL).instantiate(), design, RIG, tuning.hop)
	meshes.assign(model.find_children("*", "MeshInstance3D", true, false))
	_fading()
	_collider()
	cam = FollowCam.new()
	cam.name = "Camera"
	add_child(cam)
	cam.setup(tuning.camera)
	cam.follow_target(body, [body.get_rid()], meshes, tuning.camera.distance, tuning.camera.pivot_height)
	touch = Touch.new()
	add_child(touch)
	touch.setup(tuning, design.colors, cam.look)


## One cylinder round the drawn body, lifted by the step height, and a ray from it to the feet that walks the
## body up anything lower than the lift. A cylinder, not a capsule: a capsule's round bottom met a step a
## little over the lift at a floor-like slope and rode up it. The radius is the drawn box's half-diagonal, so
## no corner of the box leaves the cylinder at any heading.
func _collider() -> void:
	var b := model.bounds
	var cyl := CylinderShape3D.new()
	# Jolt lets a body rest this far inside what it touches (its margin is a share of the shape's size): the
	# skin keeps the drawn body out of a wall, and out of a sloping underside over the head
	var half := Vector2(b.size.x, b.size.z).length() / 2.0
	var skin: float = half * ProjectSettings.get_setting("physics/jolt_physics_3d/collisions/collision_margin_fraction")
	cyl.radius = half + skin
	cyl.height = b.end.y + skin - step
	var shape := CollisionShape3D.new()
	shape.shape = cyl
	shape.position.y = step + cyl.height / 2.0
	body.add_child(shape)
	var ray := SeparationRayShape3D.new()
	ray.length = step + cyl.radius
	var feet := CollisionShape3D.new()
	feet.shape = ray
	feet.position.y = step + cyl.radius
	feet.rotation.x = PI / 2.0  # the ray runs along the node's +Z: a quarter turn points it down
	body.add_child(feet)


## The hero's own copies of its materials, which dither away when the lens comes close. House-style materials
## are shared by every model with that role, so changing them in place would fade the whole base.
func _fading() -> void:
	for mi in meshes:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			var f: BaseMaterial3D
			if m is BaseMaterial3D:
				f = m.duplicate()
			else:
				# a role with `detail` is a ShaderMaterial with no distance fade: the hero takes its plain values
				f = StandardMaterial3D.new()
				f.albedo_color = m.get_shader_parameter("albedo")
				f.roughness = m.get_shader_parameter("roughness")
				f.metallic = m.get_shader_parameter("metallic")
			f.resource_name = m.resource_name  # the house style finds the role by this name on the next restyle
			f.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			f.distance_fade_min_distance = tuning.camera.fade_near
			f.distance_fade_max_distance = tuning.camera.fade_far
			mi.set_surface_override_material(i, f)


## A sky or quality switch: the hero takes the new role materials (and its own fading copies of them), and
## the touch controls the new colours.
func restyle(design: Dictionary) -> void:
	Forge.HouseStyle.apply(model, design)
	_fading()
	touch.restyle(design.colors)


func _physics_process(delta: float) -> void:
	if vehicle:
		_drive(delta)
	else:
		_walk(delta)
	var p := body.global_position
	moved = Vector2(p.x - last_pos.x, p.z - last_pos.z).length() / delta
	last_pos = p


func _walk(delta: float) -> void:
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var want := cam.ground_basis() * Vector3(stick.x, 0.0, stick.y)
	var top := (hurry if Input.is_action_pressed(&"hurry") else walk) * stick.length()
	if stick != Vector2.ZERO:
		var diff := wrapf(atan2(-want.x, -want.z) - yaw, -PI, PI)
		# grip limits a turn at speed (a / v), the legs limit it standing still
		var rate := minf(pivot, brake / speed) if speed > 0.0 else pivot
		yaw += clampf(diff, -rate * delta, rate * delta)
		if absf(diff) > PI / 2.0:
			top = 0.0  # a reversal at speed brakes first, then turns
	speed = move_toward(speed, top, brake * delta)
	body.rotation.y = yaw
	body.velocity.x = -sin(yaw) * speed
	body.velocity.z = -cos(yaw) * speed

	coyote = tuning.input.coyote if on_floor else coyote - delta
	buffer = tuning.input.jump_buffer if Input.is_action_just_pressed(&"jump") else buffer - delta
	if buffer > 0.0 and coyote > 0.0 and launch < 0.0:
		buffer = 0.0
		coyote = 0.0
		launch = tuning.hop.anticipation
		model.crouch()
	var launching := false
	if launch >= 0.0:
		launch -= delta
		if launch < 0.0:
			body.velocity.y = hop_speed
			launching = true
			model.take_off()
	# gravity on every frame, on the floor too: the body then presses its feet ray on the floor, which keeps the
	# floor contact real and lets move_and_slide() step it up with the cylinder checked. On the take-off frame
	# it puts the arc's peak just under the sheet's rise, never over it.
	body.velocity.y -= gravity * delta
	var falling := maxf(0.0, -body.velocity.y)
	var was_on_floor := on_floor
	var before := body.global_position
	body.move_and_slide()
	on_floor = _settle(before, was_on_floor and not launching and body.velocity.y <= 0.0)

	var real := body.get_real_velocity()
	var flat := Vector2(real.x, real.z).length()
	gait = _gait(flat)
	model.update(flat, idle_below, on_floor, body.velocity.y > 0.0, falling, delta)
	_steps(flat > idle_below, on_floor and not was_on_floor)
	cam.follow(delta, yaw, flat > idle_below, on_floor)


## Puts the feet on the floor under them, if it is within a step: up at once, when the body fits there (the
## feet ray alone lagged a frame behind a curb edge), and down only when the body was on the floor and is not
## rising (the engine's floor snap sank the step-lifted body under Jolt). A step with no room above it, like
## a curb under a low overhang, is a wall: the body goes back to where it was. True when on a floor.
func _settle(before: Vector3, may_drop: bool) -> bool:
	var at := body.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * step, at + Vector3.DOWN * step, MASK & ~4, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return body.is_on_floor()
	var y: float = hit.position.y
	# up onto any lip (a bevelled curb edge is steep where the ray meets it), down only onto a walkable slope
	if y <= at.y and hit.normal.angle_to(Vector3.UP) > body.floor_max_angle:
		return body.is_on_floor()
	if y > at.y:
		var standing := Transform3D(body.global_basis, Vector3(at.x, y + body.safe_margin, at.z))
		if body.test_move(standing, Vector3.ZERO):
			body.global_position = Vector3(before.x, at.y, before.z)
			return body.is_on_floor() or may_drop
	elif not (body.is_on_floor() or may_drop):
		return false
	body.global_position.y = y
	body.velocity.y = 0.0
	return true


## A foot plants when it becomes the lower of the two: heel strike in a walk, touchdown after the flight in a
## run. Read from the drawn clip, so the marks fall where the feet do at any blend and cadence.
func _steps(moving: bool, landed: bool) -> void:
	var f := model.feet()
	var low := 0 if f[0].y <= f[1].y else 1
	var heading := -rad_to_deg(yaw)
	var floor_y := body.global_position.y
	if landed:
		for i in f.size():
			footstep.emit(Vector3(f[i].x, floor_y, f[i].z), heading, FEET[i])
	elif low != lower and moving and on_floor:
		footstep.emit(Vector3(f[low].x, floor_y, f[low].z), heading, FEET[low])
	lower = low


func _gait(v: float) -> String:
	if not on_floor:
		return "hop"
	if v < idle_below:
		return "idle"
	if v > run_from:
		return "run"
	if v < walk_from or gait != "run":
		return "walk"
	return gait


func _drive(delta: float) -> void:
	var input := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_back", &"move_forward"))
	vehicle.drive(input, Input.is_action_pressed(&"hurry"), delta)
	var seat: Transform3D = vehicle.seat()
	body.global_position = seat.origin  # the hero rides along, so its position stays true
	yaw = vehicle.global_rotation.y
	body.rotation.y = yaw
	gait = "idle"
	cam.follow(delta, yaw, absf(vehicle.speed()) > idle_below, true)


func place(pos: Vector3, yaw_deg: float) -> void:
	if vehicle:
		_leave()
	body.global_position = pos
	yaw = -deg_to_rad(yaw_deg)
	body.rotation.y = yaw
	body.velocity = Vector3.ZERO
	on_floor = false  # put down, not snapped: it settles onto whatever is under it
	speed = 0.0
	launch = -1.0
	buffer = 0.0
	last_pos = pos
	gait = "idle"
	model.reset()
	cam.snap(yaw)


## Drive `v` (group `vehicle`): the hero hides and stops colliding, the camera follows the vehicle.
func enter(v: Node3D) -> void:
	vehicle = v
	model.visible = false
	body.collision_layer = 0
	body.collision_mask = 0
	var rids: Array[RID] = []
	for c: Node in [v] + v.find_children("*", "CollisionObject3D", true, false):
		if c is CollisionObject3D:
			rids.append((c as CollisionObject3D).get_rid())
	cam.follow_target(v, rids, [], tuning.camera.vehicle_distance, tuning.camera.vehicle_pivot_height)


func exit() -> void:
	if vehicle == null:
		return
	var v := vehicle
	_leave()
	place(v.exit_point(), -rad_to_deg(v.global_rotation.y))


func _leave() -> void:
	vehicle = null
	model.visible = true
	body.collision_layer = HERO_LAYER
	body.collision_mask = MASK
	cam.follow_target(body, [body.get_rid()], meshes, tuning.camera.distance, tuning.camera.pivot_height)


## The solids the drawn body is inside (skills/world-collision). Empty means what you see is what you hit.
func inside() -> Array:
	var b := model.bounds
	var box := BoxShape3D.new()
	box.size = b.size - Vector3(0, step, 0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = body.global_transform * Transform3D(Basis(), b.get_center() + Vector3(0, step / 2.0, 0))
	q.collision_mask = OVERLAP
	q.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(q).map(
		func(h: Dictionary) -> String: return str(h.collider.get_path()))


func state() -> Dictionary:
	var feet := body.global_position
	return {
		"player": {"pos": feet, "speed": moved, "onFloor": on_floor, "gait": gait, "inside": [] if vehicle else inside()},
		"cam": {"inside": cam.inside(), "dist": cam.dist},
		"heroScreen": 0.0 if vehicle else cam.on_screen(feet, model.bounds.end.y),
		"interaction": {"target": "", "prompt": ""},
		"carry": "",
		"vehicle": {"driving": vehicle != null, "speed": vehicle.speed() if vehicle else 0.0},
	}
