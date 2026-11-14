extends Node3D
## The hero a player controls (CONTRACTS.md): a CharacterBody3D under Jolt, its drawn model, the follow camera
## and the touch controls. Physical numbers come from the reality sheet and feel numbers from tuning.json, so
## this file holds none. It keeps the hero out of things and says where it is; it decides no rules.

const HeroModel := preload("res://player/hero_model.gd")
const HeroLife := preload("res://player/hero_life.gd")
const FollowCam := preload("res://player/follow_cam.gd")
const Touch := preload("res://player/touch.gd")
const Controls := preload("res://player/controls.gd")
const HeroShader := preload("res://player/hero.gdshader")
const SuitLamps := preload("res://player/suit_lamps.gd")
const HERO_LAYER := 8
const MASK := 1 | 2 | 4 | 16 | 64  # ground, statics, thin, vehicles, carriables (CONTRACTS.md)
const OVERLAP := 2 | 4 | 16 | 64  # what the drawn body must never be inside; the step lift keeps the floor out
const EDGE_SLIDE := 1.5  # m/s off a rim the body only rests on: a slip, quicker than a careful walk
# The model and its clips (names, loops, foot contacts). Another hero swaps these and nothing else.
const MODEL := "res://models/character_suited.glb"
const CLIPS := "res://data/clips.json"
const EYE_ROLE := "visor"  # the surface the eye sits behind in first person, and the head lamps aim from

## A foot pressed onto the ground: each plant of a walk or run, and both feet on landing. `pos` is under the
## foot at the floor, `yaw_deg` the heading (CONTRACTS.md), `foot` is "foot_l" or "foot_r".
signal footstep(pos: Vector3, yaw_deg: float, foot: String)
## The helmet lights went on or off: `auto` by the sun or a door, else by the `lamp` press (player/suit_lamps.gd).
signal lamps_changed(on: bool, auto: bool)

const FEET := ["foot_l", "foot_r"]  # in the order of clips.json feet: left, right

var body: CharacterBody3D
var model: HeroModel
var cam: FollowCam
var touch: Touch
var tuning: Dictionary
var meshes: Array[MeshInstance3D] = []
var vehicle: Node3D = null:
	set(v):
		vehicle = v
		hurrying = false  # boarding or leaving lets go of the hurry lock: a rover set off at a run would surprise
var pilot: RefCounted = null  # sandbox/rover_pilot.gd, set by the root: holds the stick of a boarded rover on its way to the map's mark
var design: Dictionary
var gait := "idle"
# from the sheet, read once
var gravity: float
var walk: float
var hurry: float
var brake: float  # m/s2: the sheet's stop distance from a hurry
var hop_speed: float
var step: float
var breadth: float  # m, the suited body side to side (hero.width)
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
## The hurry lock: a press of `hurry` locks it on, the next off. The walk, the rover and the tutorial read this, never
## the key. It lets go by itself when the hero stands still (tuning hero.hurry_still_s), when hurry is not allowed, on
## boarding or leaving a vehicle and on place(). The touch Hurry button wears it.
var hurrying := false:
	set(on):
		hurrying = on
		if touch:
			touch.show_hurry(on)
var still := 0.0  # s with no move input
var carried: Node3D = null  # a bag the interactions hung on the body; it rides on the chest
var attention: Node3D = null  # what the helmet turns toward: the interactions set their target here
var life: HeroLife
var sink: float  # m the drawn boots sit in the dust (hero.sink)
var breath_clock: Object = null  # a sibling with `breath_phase` (the sound's clock), else our own
var breath := 0.0
var clock_seen := -1.0
var last_vel := Vector3.ZERO
var on_floor := false  # the body's floor contact, or a floor it was snapped down onto this frame
var fading: Shader  # hero.gdshader built with FADE: blended, swapped in only while the lens is close
var shown := 1.0  # the fade the materials carry now
var drawn_y := 0.0  # the drawn body's height: it follows a step at a capped speed (tuning.json hero.step_catch_s)
var glancing := false  # the camera faces the hero: the helmet looks at the lens, not along its aim
## Where the body may walk (x, z), set by the composition root; no area: anywhere. Near its edge the outward speed is
## held to what the hero's braking still stops in, so the hero slows and stops on the line, with no wall's jolt.
var bound := Rect2()
## The rooms that put the view in first person, set by the composition root: {id: {node: Node3D, areas: [{circle:
## [x, z, r]} or {rect: [x0, z0, x1, z1]}, ...]}}, each area in its node's space (data/world.json `rooms`).
var rooms := {}
var room := ""  # the one the body is in, "" outside
## Standing up from a seat (sit_to_stand), else empty: {left: s to its end}. Input moves nothing while it plays.
var cut := {}
var seated := false  # on a seat (sit): input moves nothing; a move key stands the hero up
## The tutorial's lock (allow()): only these may act; empty, everything may.
var allowed: Array = []
var _gate: Gate
var lamps: SuitLamps
var lamps_on: bool:
	get:
		return lamps.on


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
	breadth = row.call("hero.width")
	var leg: float = row.call("hero.leg")
	pivot = sqrt(gravity / leg)  # a leg swings as a pendulum: about one step's turn per swing
	# Froude number v^2 / (g leg): suited crews left the walk at the sheet's value; back to a walk a little lower,
	# so a speed on the edge does not flicker
	var froude: float = row.call("hero.froude.walk_run")
	run_from = sqrt(froude * gravity * leg)
	walk_from = sqrt((froude - tuning.hero.gait_hysteresis) * gravity * leg)
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
	design = Forge.HouseStyle.load_design("res://design.json")
	model = HeroModel.new()
	body.add_child(model)
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLIPS))
	sink = row.call("hero.sink")
	var drawn: Node3D = load(MODEL).instantiate()
	var bones: Skeleton3D = drawn.find_children("*", "Skeleton3D", true, false)[0]
	for mi: MeshInstance3D in drawn.find_children("*", "MeshInstance3D", true, false):
		var binds := PackedStringArray()
		for b in mi.skin.get_bind_count():
			var at := mi.skin.get_bind_bone(b)
			binds.append(bones.get_bone_name(at) if at >= 0 else String(mi.skin.get_bind_name(b)))
		mi.mesh = HeroModel.prepared(mi.mesh, binds, deg_to_rad(tuning.hero.smooth_deg), tuning.hero.coat)
	model.setup(drawn, design, clips, tuning.hop, sink, row.call("hero.contact.height"), tuning.life.carry_out, EYE_ROLE)
	life = HeroLife.new()
	life.setup(model.skeleton, tuning.life, row.call("hero.lean.max"), gravity)
	meshes.assign(model.find_children("*", "MeshInstance3D", true, false))
	fading = Shader.new()
	fading.code = HeroShader.code.replace("// VARIANT\n", "#define FADE\n")
	_fading()
	_collider()
	cam = FollowCam.new()
	cam.name = "Camera"
	add_child(cam)
	cam.setup(tuning.camera)
	cam.eye = Vector3(0.0, model.eye.y, model.eye.z)  # centred; the forward part turns with the view, not the body
	cam.follow_target(body, [body.get_rid()], meshes, tuning.camera.distance, tuning.camera.pivot_height, model.bounds)
	lamps = SuitLamps.new()
	lamps.setup(self, model.skeleton, model.eye, design)
	touch = Touch.new()
	add_child(touch)
	touch.setup(tuning, design.colors, func(right: float, down: float) -> void:
		if may(&"look_left"):
			cam.look(right, down))


## A tutorial step allows only `actions` (cine/beats.gd): [] allows everything again, ["none"] nothing. A name is an
## input action or its family ("move" is move_forward and the other three, "look" the look keys, the mouse and a
## touch drag); jump, hurry, interact and map are the rest. A blocked action does nothing, from keys, a pad or a touch
## button (its button hides); Esc and the settings always work.
func allow(actions: Array) -> void:
	allowed = actions.duplicate()
	if _gate == null:
		_gate = Gate.new()
		_gate.player = self
		tree_exiting.connect(_gate.queue_free)
		# last child of the root: its _input runs before every other node's (the HUD takes M in its _input)
		get_tree().root.add_child.call_deferred(_gate)
	for b: Control in touch.root.find_children("*", "Button", true, false):
		b.visible = may(b.name)
	touch.stick.visible = [&"move_forward", &"move_back", &"move_left", &"move_right"].any(may)


func may(action: StringName) -> bool:
	if action == &"lamp":
		return allowed != ["none"]  # the helmet lights stay the player's in every lesson
	return allowed.is_empty() or action == &"settings" or allowed.any(func(a: String) -> bool:
		return action == StringName(a) or action.begins_with(a + "_"))


## Eats the events of blocked actions before anything else sees them (polled input is gated where it is read).
class Gate extends Node:
	const ACTIONS: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right", &"look_left",
		&"look_right", &"look_up", &"look_down", &"jump", &"hurry", &"interact", &"map"]
	var player: Node

	func _input(e: InputEvent) -> void:
		if player.allowed.is_empty():
			return
		var blocked: bool = e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player.may(&"look_left")
		for a in ACTIONS:
			blocked = blocked or InputMap.has_action(a) and e.is_action(a) and not player.may(a)
		if blocked:
			get_viewport().set_input_as_handled()


## One cylinder round the suited body, lifted by the step height, and a ray from it to the feet that walks the
## body up anything lower than the lift. A cylinder, not a capsule: a capsule's round bottom met a step a
## little over the lift at a floor-like slope and rode up it. The radius is half the sheet's suited breadth,
## not the drawn box: the box's corners (hands held out, the pack) made it 1.35 m round, wider than a real
## 1.2 m hatch, so the arms and the pack may graze a wall the torso cannot reach.
func _collider() -> void:
	var b := model.bounds
	var cyl := CylinderShape3D.new()
	# Jolt lets a body rest this far inside what it touches (its margin is a share of the shape's size): the
	# skin keeps the head out of a sloping underside. Not on the radius: the breadth is shoulder to elbow, the
	# torso is narrower, and a skin there shut the greenhouse's door (0.513 m blocked, 0.475 m walked in).
	var half := breadth / 2.0
	var skin: float = half * ProjectSettings.get_setting("physics/jolt_physics_3d/collisions/collision_margin_fraction")
	cyl.radius = half
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


## The hero's own copies of its role materials (house-style materials are shared by every model with that
## role, so changing them in place would change the whole base): they fade when the lens comes close, and they
## wear the design's dust coat (DESIGN.md `weathering`, each role's share) where a suit gathers it. A role with `detail` gives only its plain values: its detail is laid in world space.
func _fading() -> void:
	var t: Dictionary = tuning.hero
	for mi in meshes:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			var f := ShaderMaterial.new()
			f.shader = HeroShader
			if m is BaseMaterial3D:
				f.set_shader_parameter("albedo", m.albedo_color)
				f.set_shader_parameter("roughness", m.roughness)
				f.set_shader_parameter("metallic", m.metallic)
			else:
				for k: String in ["albedo", "roughness", "metallic"]:
					f.set_shader_parameter(k, m.get_shader_parameter(k))
			f.set_shader_parameter("coat_color", Color.html(design.get("weathering", {}).get("color", "#ffffff")))
			f.set_shader_parameter("coat_amount", Forge.HouseStyle._coat(design, design.materials.get(m.resource_name, {})))
			f.set_shader_parameter("coat_max", t.coat.max)
			f.set_shader_parameter("coat_chroma", t.coat.chroma)
			f.resource_name = m.resource_name  # the house style finds the role by this name on the next restyle
			mi.set_surface_override_material(i, f)


## A sky or quality switch: the hero takes the new role materials (and its own fading copies of them), and
## the touch controls the new colours.
func restyle(d: Dictionary) -> void:
	design = d
	Forge.HouseStyle.apply(model, design)
	_fading()
	shown = -1.0  # new solid copies: the next frame puts the fade back on them
	touch.restyle(design.colors)


## After the physics steps, before the frame is drawn: the whole body fades as one by the lens's gap to it
## (follow_cam), never a pattern over part of it, and hides before the lens could be inside the helmet.
func _process(_delta: float) -> void:
	var f: float = cam.fade
	if f == shown:
		return
	shown = f
	for mi in meshes:
		mi.visible = f > 0.0
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			m.shader = HeroShader if f >= 1.0 else fading
			m.set_shader_parameter("opacity", f)


func _physics_process(delta: float) -> void:
	if vehicle:
		_drive(delta)
	else:
		_walk(delta)
	var p := body.global_position
	var vel := Vector3(p.x - last_pos.x, 0.0, p.z - last_pos.z) / delta
	moved = vel.length()
	last_pos = p
	_live(delta, (vel - last_vel) / delta)
	last_vel = vel


## The layers on top of the clips: breath on the sound's clock, lean from the push the body feels, and the
## helmet toward what the interactions offer, else toward where the camera looks.
func _live(delta: float, accel: Vector3) -> void:
	var b: Dictionary = tuning.audio.breath  # the sound's own breath numbers, so body and sound agree
	if breath_clock == null:
		for n in get_parent().get_children():
			if n.get("breath_phase") != null:
				breath_clock = n
	# the sound's clock while it runs; before the first tap starts the sound (a browser rule) it stands still,
	# and the chest keeps its own resting time
	var c: float = breath_clock.breath_phase if breath_clock else -1.0
	breath = c if c >= 0.0 and c != clock_seen else fmod(breath + delta * b.rest / 60.0, 1.0)
	clock_seen = c
	# where the camera looks, while that is ahead of the hero; once the camera comes round to face the hero,
	# its aim lies behind the hero and the helmet glances at the lens instead (with a little hysteresis, so a
	# camera parked at the side does not switch every frame)
	var view := -cam.lens.global_basis.z
	var ahead := Vector2(view.x, view.z).normalized().dot(Vector2(-sin(yaw), -cos(yaw)))
	# never from its own eye: the lens is in the helmet then, and a glance at it sent the lamps' beam anywhere
	glancing = cam.first < 1.0 and (ahead < cos(PI * 0.45) if not glancing else ahead < cos(PI * 0.35))
	var head := body.global_position + Vector3.UP * model.bounds.end.y * 0.9
	var look: Vector3 = cam.lens.global_position if glancing else head + view * tuning.life.look_far
	if is_instance_valid(attention) and attention.is_inside_tree():
		look = attention.global_position
	var pace := clampf(moved / walk, 0.0, 1.0)
	life.update(delta, accel if not vehicle else Vector3.ZERO, carried != null, breath, b.inhale_share, look, pace)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"hurry") and may(&"hurry"):
		hurrying = not hurrying
		still = 0.0  # a press standing still gives the kid the whole still time to set off


func _walk(delta: float) -> void:
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if not allowed.is_empty():
		stick.x *= float(may(&"move_left") if stick.x < 0.0 else may(&"move_right"))
		stick.y *= float(may(&"move_forward") if stick.y < 0.0 else may(&"move_back"))
	var busy := seated or not cut.is_empty()
	if busy:
		_busy(stick, delta)
		stick = Vector2.ZERO
	var want := cam.ground_basis() * Vector3(stick.x, 0.0, stick.y)
	still = still + delta if stick == Vector2.ZERO else 0.0
	hurrying = hurrying and may(&"hurry") and still < tuning.hero.hurry_still_s
	var top := (hurry if hurrying else walk) * stick.length()
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
	if bound.has_area():
		var p := body.global_position
		body.velocity.x = _held(body.velocity.x, p.x - bound.position.x, bound.end.x - p.x)
		body.velocity.z = _held(body.velocity.z, p.z - bound.position.y, bound.end.y - p.z)
		# the speed is what is left, or a turn back in would wait for the brakes to take off speed it never had
		speed = minf(speed, Vector2(body.velocity.x, body.velocity.z).length())

	coyote = tuning.input.coyote if on_floor else coyote - delta
	buffer = tuning.input.jump_buffer if Input.is_action_just_pressed(&"jump") and may(&"jump") else buffer - delta
	if buffer > 0.0 and coyote > 0.0 and launch < 0.0 and not busy:
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
	var was_on_floor := on_floor
	var before := body.global_position
	body.move_and_slide()
	on_floor = _settle(before, was_on_floor and not launching and body.velocity.y <= 0.0)
	# a step up or down moves the body at once; the drawn body follows at a step per step_catch_s and is never
	# more than a step behind (Source's SmoothViewOnStairs), so the feet do not pop up a sill. In the air: at once
	var y := body.global_position.y
	drawn_y = clampf(move_toward(drawn_y, y, step / tuning.hero.step_catch_s * delta), y - step, y + step) if on_floor and was_on_floor else y
	model.position.y = drawn_y - y
	cam.eye.y = model.eye.y + model.position.y  # the eye rides the drawn body over a sill, as Source smooths the view

	var real := body.get_real_velocity()
	var flat := Vector2(real.x, real.z).length()
	gait = _gait(flat)
	carried = null
	for c in body.get_children():
		if c.is_in_group("carriable"):
			carried = c
	var steps := model.update(0.0 if busy else flat, idle_below, on_floor, carried != null, delta)
	if carried:
		_carry()
	# a landing after real air time: a teleport's settle or a curb's single frame off the floor is not one
	_steps(steps, on_floor and not was_on_floor and coyote <= 0.0)
	_room()
	for a: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		if not may(a):
			Input.action_release(a)  # the camera polls them next
	cam.follow(delta, Vector3(real.x, 0.0, real.z), yaw, on_floor)


## Which room the body is in, with a doorway band as wide as the body: in once the whole body is past the door (the
## plan shrunk by its radius), out once it is wholly outside (grown by it), so rocking in the hatch never flips the
## view, the rules, the sound or the lights. ponytail: the plan is flat, a body on a roof would count as inside; add
## a height when one can get there.
func _room() -> void:
	var r := breadth / 2.0
	var p := body.global_position
	if room != "" and FollowCam.depth_in(rooms[room], p) <= -r:
		room = ""
	if room == "":
		for id: String in rooms:
			if FollowCam.depth_in(rooms[id], p) > r:
				room = id
	cam.room = room != ""


## A speed along one axis held to what the brakes stop in the room left: `back` metres behind, `ahead` in front,
## and never more than the room in one step (the last millimetre would otherwise step over the line).
func _held(v: float, back: float, ahead: float) -> float:
	var hz := float(Engine.physics_ticks_per_second)
	back = maxf(back, 0.0)
	ahead = maxf(ahead, 0.0)
	return clampf(v, -minf(sqrt(2.0 * brake * back), back * hz), minf(sqrt(2.0 * brake * ahead), ahead * hz))


## Puts the feet on the floor under them, if it is within a step: up at once, when the body fits there (the
## feet ray alone lagged a frame behind a curb edge), and down only when the body was on the floor and is not
## rising (the engine's floor snap sank the step-lifted body under Jolt). A step with no room above it, like
## a curb under a low overhang, is a wall: the body goes back to where it was. True when on a floor.
func _settle(before: Vector3, may_drop: bool) -> bool:
	var at := body.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * step, at + Vector3.DOWN * step, MASK & ~4, [body.get_rid()])
	var space := body.get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	# down off a step's edge the ray meets its bevel, steep: the floor is just past it, down its slope. Found within
	# a step, the body steps down onto it as a person does (and as an engine's floor snap does within its step
	# height); taken for a drop, a 1.5 cm sill bevel played the fall clip and reset the legs in HAB 1's hatch
	if may_drop and hit and hit.position.y <= at.y and hit.normal.angle_to(Vector3.UP) > body.floor_max_angle:
		var past := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized() * float(design.geometry.bevel) * 2.0
		q.from += past
		q.to += past
		var below := space.intersect_ray(q)
		if below and below.position.y <= at.y and below.normal.angle_to(Vector3.UP) <= body.floor_max_angle:
			hit = below
	# up onto any lip (a bevelled curb edge is steep where the ray meets it), down only onto a walkable slope
	if hit.is_empty() or hit.position.y <= at.y and hit.normal.angle_to(Vector3.UP) > body.floor_max_angle:
		return _off_edge()
	var y: float = hit.position.y
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


## The engine counts a capsule resting on a thin edge as a floor (a tilted solar panel's rim): with nothing to
## stand on under the middle of the body, the body slides off the edge it rests on and falls (friend's playtest,
## 14 Nov: the hero stood floating on a panel edge).
func _off_edge() -> bool:
	if not body.is_on_floor():
		return false
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		var away := body.global_position - c.get_position()
		away.y = 0.0
		if c.get_normal().angle_to(Vector3.UP) <= body.floor_max_angle and away.length() > 0.001:
			# off the first rim it rests on, never through a wall beside it
			body.move_and_collide(away.normalized() * EDGE_SLIDE * get_physics_process_delta_time())
			break
	return false


## A boot lands on its clip's measured touchdown (clips.json, low and still: skills/suited-locomotion section
## 4), and both land with the body on a hop. The mark goes under the drawn foot on that frame.
func _steps(feet_down: Array[int], landed: bool) -> void:
	var f := model.feet()
	var heading := -rad_to_deg(yaw)
	var floor_y := body.global_position.y
	if landed:
		feet_down.assign([0, 1])
	elif not on_floor:
		return
	for i in feet_down:
		footstep.emit(Vector3(f[i].x, floor_y, f[i].z), heading, FEET[i])


## The bag rides on the chest bone in the carry clip's hold, its centre where clips.json puts it.
func _carry() -> void:
	var centre := Vector3.ZERO
	for mi: MeshInstance3D in carried.find_children("*", "MeshInstance3D", true, false):
		centre = carried.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb().get_center()
		break
	var at := model.bag_transform()
	carried.global_transform = Transform3D(at.basis, at.origin - at.basis * centre)


func _gait(v: float) -> String:
	if not on_floor:
		return "hop"
	if v < idle_below:
		return "idle"
	if v > run_from:
		return "lope"  # the suited gait past the walk (Apollo's lope), as the clip is named
	if v < walk_from or gait != "lope":
		return "walk"
	return gait


func _drive(delta: float) -> void:
	var input := Vector2(Input.get_axis(&"move_left", &"move_right"), Input.get_axis(&"move_back", &"move_forward"))
	if pilot:
		input = pilot.steer(vehicle, input, delta)  # the autopilot's stick, or the keys back: any move key takes the wheel
	vehicle.drive(input, hurrying, delta)
	var seat: Transform3D = vehicle.seat()
	# the hero rides along with its drawn hips on the seat, so its position stays true
	body.global_transform = Transform3D(seat.basis, seat.origin - seat.basis * model.hip_sit)
	model.position.y = 0.0  # no step to catch up on a seat
	yaw = vehicle.global_rotation.y
	gait = "idle"
	model.update(0.0, idle_below, true, false, delta)
	cam.follow(delta, -vehicle.global_basis.z * vehicle.speed(), yaw, true)


func place(pos: Vector3, yaw_deg: float) -> void:
	if vehicle:
		_leave()
	body.global_position = pos
	yaw = -deg_to_rad(yaw_deg)
	body.rotation = Vector3(0, yaw, 0)  # a seat may have tilted it
	body.velocity = Vector3.ZERO
	on_floor = false  # put down, not snapped: it settles onto whatever is under it
	speed = 0.0
	hurrying = false
	launch = -1.0
	buffer = 0.0
	last_pos = pos
	last_vel = Vector3.ZERO
	gait = "idle"
	model.reset()
	_end_cut()
	seated = false
	room = ""
	_room()
	cam.snap(yaw)
	life.snap(pos + Vector3(-sin(yaw), 0.0, -cos(yaw)) * tuning.life.look_far + Vector3.UP * model.bounds.end.y * 0.9)


## On a seat behind the hero (true: sit_down, then sit_idle; the hips go to model.point(&"sit_idle", "seat_hip")),
## or back up (false: sit_to_stand, which no key cuts short). A move key while seated stands the hero up.
func sit(on: bool) -> void:
	if vehicle or on == seated:
		return
	seated = on
	speed = 0.0
	model.seat(on)
	cam.show_body = true
	cut = {} if on else {"left": float(model.clips.sit_to_stand.length)}


## Seated, a move key stands the hero up; standing up, the clip runs out.
func _busy(stick: Vector2, delta: float) -> void:
	if seated:
		if stick != Vector2.ZERO:
			sit(false)
		return
	cut.left -= delta
	if cut.left <= 0.0:
		_end_cut()


func _end_cut() -> void:
	cut = {}
	cam.show_body = false


## Drive `v` (group `vehicle`): the hero sits on its seat and stops colliding, the camera follows the vehicle.
func enter(v: Node3D) -> void:
	_end_cut()
	seated = false
	vehicle = v
	room = ""
	cam.room = false
	model.sit(true)
	body.collision_layer = 0
	body.collision_mask = 0
	var rids: Array[RID] = []
	for c: Node in [v] + v.find_children("*", "CollisionObject3D", true, false):
		if c is CollisionObject3D:
			rids.append((c as CollisionObject3D).get_rid())
	# the vehicle's drawn box in its own space: its bodies are left out of the camera's casts, so this keeps the lens out
	var hull := AABB()
	for mi: MeshInstance3D in v.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = v.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		hull = hull.merge(b) if hull.has_volume() else b
	cam.follow_target(v, rids, [], tuning.camera.vehicle_distance, tuning.camera.vehicle_pivot_height, AABB(), float(v.top) if "top" in v else 0.0, hull)  # a vehicle's top speed, m/s: the speed framing


func exit() -> void:
	if vehicle == null:
		return
	var v := vehicle
	_leave()
	place(v.exit_point(), -rad_to_deg(v.global_rotation.y))


func _leave() -> void:
	vehicle = null
	model.sit(false)
	body.collision_layer = HERO_LAYER
	body.collision_mask = MASK
	cam.follow_target(body, [body.get_rid()], meshes, tuning.camera.distance, tuning.camera.pivot_height, model.bounds)


## The solids the suited torso is inside (skills/world-collision). Empty means the body never went into a wall.
func inside() -> Array:
	var cyl := CylinderShape3D.new()
	# the torso the collider guards (arms and pack may graze, see _collider), less the depth Jolt lets a resting
	# contact sink, which is no one walking into a wall
	cyl.radius = breadth / 2.0 * (1.0 - ProjectSettings.get_setting("physics/jolt_physics_3d/collisions/collision_margin_fraction"))
	cyl.height = model.bounds.end.y - step
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cyl
	q.transform = body.global_transform * Transform3D(Basis(), Vector3(0, step + cyl.height / 2.0, 0))
	q.collision_mask = OVERLAP
	q.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(q).map(
		func(h: Dictionary) -> String: return str(h.collider.get_path()))


func state() -> Dictionary:
	var feet := body.global_position
	return {
		"player": {"pos": feet, "speed": moved, "onFloor": on_floor, "gait": gait, "inside": [] if vehicle else inside(), "room": room,
			"lamps": {"on": lamps.on, "auto": lamps.auto}},
		"cam": {"inside": cam.inside(), "dist": cam.dist, "first": cam.first},
		"heroScreen": 0.0 if vehicle else cam.on_screen(feet, model.bounds.end.y),
		"interaction": {"target": "", "prompt": ""},
		"carry": "",
		"vehicle": {"driving": vehicle != null, "speed": vehicle.speed() if vehicle else 0.0},
	}

