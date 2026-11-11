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
	body.floor_snap_length = step
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
	cyl.radius = Vector2(b.size.x, b.size.z).length() / 2.0
	cyl.height = b.end.y - step
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

	coyote = tuning.input.coyote if body.is_on_floor() else coyote - delta
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
	# gravity on the take-off frame too: the arc then peaks just under the sheet's rise, never over it
	if launching or not body.is_on_floor():
		body.velocity.y -= gravity * delta
	var falling := maxf(0.0, -body.velocity.y)
	var was_on_floor := body.is_on_floor()
	body.move_and_slide()

	var real := body.get_real_velocity()
	var flat := Vector2(real.x, real.z).length()
	gait = _gait(flat)
	model.update(flat, idle_below, body.is_on_floor(), body.velocity.y > 0.0, falling, delta)
	_steps(flat > idle_below, body.is_on_floor() and not was_on_floor)
	cam.follow(delta, yaw, flat > idle_below, body.is_on_floor())


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
	elif low != lower and moving and body.is_on_floor():
		footstep.emit(Vector3(f[low].x, floor_y, f[low].z), heading, FEET[low])
	lower = low


func _gait(v: float) -> String:
	if not body.is_on_floor():
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
		"player": {"pos": feet, "speed": moved, "onFloor": body.is_on_floor(), "gait": gait, "inside": [] if vehicle else inside()},
		"cam": {"inside": cam.inside(), "dist": cam.dist},
		"heroScreen": 0.0 if vehicle else cam.on_screen(feet, model.bounds.end.y),
		"interaction": {"target": "", "prompt": ""},
		"carry": "",
		"vehicle": {"driving": vehicle != null, "speed": vehicle.speed() if vehicle else 0.0},
	}
