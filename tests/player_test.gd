extends "res://addons/forge/test.gd"
## The player lane's checks: godot --headless --path . -s tests/player_test.gd
## The drawn body against a pillar from eight headings and turning beside it, the camera with the hero in a
## corner, the step, a vehicle, and two thumbs at once sent the way a browser sends them.
## Runs in real time (about a minute): physics ticks follow the clock without --fixed-fps.

const HouseStyle := preload("res://addons/forge/house_style.gd")  # the Forge autoload is unknown while a test compiles
const OPEN := Vector2(0, 30)  # open ground west of the beacon, clear of every world.json item
const CORNER := Vector2(-20, 30)
const STEPS := Vector2(20, 30)

var game: Node3D
var player: Node3D
var radius := 0.0


func _init() -> void:
	watchdog = 150.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	player = game.get_node("Player")
	radius = (player.body.find_children("*", "CollisionShape3D", false, false)[0].shape as CylinderShape3D).radius
	check(is_equal_approx(float(ProjectSettings.get_setting("physics/3d/default_gravity")), player.gravity),
		"project.godot gravity is the sheet's")
	await no_sinking()
	await footsteps()
	await life()
	await sweep()
	await turn_beside()
	await corner()
	await step_up()
	await drive()
	restyle()
	for s in SHAPES:
		await touch(await shape(s))
	return true


## A static box on the ground, its base sunk a little so no gap shows on a slope.
func box(at: Vector2, size: Vector3) -> StaticBody3D:
	var world: Node3D = game.get_node("World")
	var b := StaticBody3D.new()
	b.collision_layer = 2
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size + Vector3(0, 0.2, 0)
	c.shape = s
	b.add_child(c)
	b.position = Vector3(at.x, world.height_at(at.x, at.y) + size.y / 2.0 - 0.1, at.y)
	game.add_child(b)
	return b


## Holds `actions` for n frames, checking every frame that the drawn body is in nothing.
func hold(actions: Array, n: int, what: String) -> void:
	for a: StringName in actions:
		action(a, true)
	var bad := 0
	for i in n:
		await frames(1)
		var s: Dictionary = player.state()
		if not s.player.inside.is_empty():
			bad += 1
	for a: StringName in actions:
		action(a, false)
	check(bad == 0, "%s: the drawn body was inside a solid on %d frames" % [what, bad])


## The feet stay on the floor they walk on: the engine's floor snap once pulled the step-lifted body a whole
## snap length into the ground (0.30 m, for good). Both spots are the sweep test's repros.
func no_sinking() -> void:
	var space := game.get_world_3d().direct_space_state
	for spot: Array in [[Vector3(-1.42, 0, 4.0), 270.0, 0], [Vector3(0, 0, 30), 90.0, 30]]:
		game.place(spot[0], spot[1])
		await frames(spot[2])  # the second starts from standstill
		action(&"move_forward", true)
		var worst := 0.0
		for i in 120:
			await frames(1)
			var b: Vector3 = player.body.global_position
			var q := PhysicsRayQueryParameters3D.create(b + Vector3.UP * 2.0, b + Vector3.DOWN * 2.0, 1 | 2, [player.body.get_rid()])
			var hit := space.intersect_ray(q)
			if hit:
				worst = maxf(worst, hit.position.y - b.y)
		action(&"move_forward", false)
		check(worst < 0.02, "walking from %s: the feet sank %.3f m below the floor" % [spot[0], worst])


## The layers on top of the clips (skills/living-atmosphere check 4): the chest breathes on the sound's own
## clock, the helmet turns toward a thing worth noticing, and a stop leans back then swings once past upright.
func life() -> void:
	game.place(Vector3(OPEN.x, 0, OPEN.y + 6.0), 180)
	await frames(30)
	var audio: Object = player.breath_clock
	if audio and not audio.started:
		audio.start()  # a browser starts sound on the first tap; headless there is none
	await frames(10)  # the chest moves from its own resting time onto the sound's
	var worst := 0.0
	var lo := 1.0
	var hi := 0.0
	for i in 300:
		await frames(1)
		# read in the physics step, advanced in the sound's process step: at most a frame apart
		var gap := absf(angle_difference(player.breath * TAU, audio.breath_phase * TAU)) / TAU if audio else 1.0
		worst = maxf(worst, gap)
		lo = minf(lo, player.life.body.breath)
		hi = maxf(hi, player.life.body.breath)
	check(worst < 0.02, "the chest breathes on the breath sound's clock (at most %.3f of a breath apart)" % worst)
	check(lo < 0.1 and hi > 0.9, "a full breath in 5 s standing (chest %.2f to %.2f)" % [lo, hi])
	# a thing to the hero's right, a little ahead: the drawn head turns toward it
	var sk: Skeleton3D = player.model.skeleton
	var head := sk.find_bone(&"Head")
	var drawn := [Vector3.ZERO]
	var grab := func() -> void: drawn[0] = (sk.global_basis * sk.get_bone_global_pose(head).basis * Vector3.BACK).normalized()
	sk.skeleton_updated.connect(grab)  # the pose after the modifiers is readable only here
	await frames(5)
	var b: Node3D = player.body
	var mark := Node3D.new()
	game.add_child(mark)
	mark.global_position = b.global_position + b.global_basis.x * 1.2 - b.global_basis.z * 0.8 + Vector3.UP * 1.2
	var to: Vector3 = (mark.global_position - (b.global_position + Vector3.UP * 1.7)).normalized()
	var before: float = drawn[0].dot(to)
	var box: Node = game.get_node("Interactions")
	box.set_physics_process(false)  # it sets the attention every frame; here the test does
	player.attention = mark
	await frames(90)
	check(drawn[0].dot(to) > before + 0.1, "the helmet turns toward a thing in reach (%.2f to %.2f)" % [before, drawn[0].dot(to)])
	player.attention = null
	box.set_physics_process(true)
	sk.skeleton_updated.disconnect(grab)
	mark.free()
	action(&"move_forward", true)
	action(&"hurry", true)
	await frames(180)
	action(&"move_forward", false)
	action(&"hurry", false)
	var back := 0.0
	var past := 0.0
	for i in 240:
		await frames(1)
		var l: float = player.life.body.lean.y
		back = minf(back, l)
		if back < 0.0 and player.moved < 0.01:
			past = maxf(past, l)
	check(back < -0.02 and past > 0.002, "a stop leans back then swings past upright once (%.3f, %.3f rad)" % [back, past])


## Feet plant in turn while walking and hurrying, each on the frame its boot is down (skills/suited-locomotion
## section 4: the drawn ankle at its planted height, within the sheet's contact height), both come down on a
## landing, and each mark is under the body.
func footsteps() -> void:
	var clips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/clips.json"))
	var planted: float = clips.feet.ankle_height_planted - player.sink
	var marks: Array = []
	var worst := [0.0]
	var log_step := func(pos: Vector3, _yaw: float, foot: String) -> void:
		marks.append([foot, pos])
		var f: Vector3 = player.model.feet()[player.FEET.find(foot)]
		worst[0] = maxf(worst[0], absf(f.y - pos.y - planted))
	player.footstep.connect(log_step)
	for keys: Array in [[&"move_forward"], [&"move_forward", &"hurry"]]:
		game.place(Vector3(OPEN.x, 0, OPEN.y + 6.0), 180)
		await frames(30)
		marks.clear()
		await hold(keys, 180, "walk in the open")
		var alternate := true
		for i in range(1, marks.size()):
			alternate = alternate and marks[i][0] != marks[i - 1][0]
		check(marks.size() >= 3 and alternate, "%s: 3 s plant feet in turn (%s)" % [keys, marks.map(func(m: Array) -> String: return m[0])])
	var contact: float = 0.02
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json")).rows:
		if r.id == "hero.contact.height":
			contact = r.value
	check(worst[0] <= contact, "every footstep fires with its boot down (worst %.3f m off the planted height)" % worst[0])
	var far := 0.0
	for m: Array in marks:
		var b: Vector3 = player.body.global_position
		far = maxf(far, Vector2(m[1].x, m[1].z).distance_to(Vector2(b.x, b.z)))
	check(far < 3.0, "every footprint lies near the walker (farthest %.2f m)" % far)
	await frames(120)
	marks.clear()
	action(&"jump", true)
	await frames(1)
	action(&"jump", false)
	await frames(70)
	check(marks.size() == 2 and marks[0][0] != marks[1][0], "a hop lands on both feet (%d marks)" % marks.size())
	player.footstep.disconnect(log_step)


func sweep() -> void:
	var pillar := box(OPEN, Vector3(2, 3, 2))
	for i in 8:
		var yaw := i * 45.0
		var dir := Vector3(sin(deg_to_rad(yaw)), 0, -cos(deg_to_rad(yaw)))
		game.place(Vector3(OPEN.x, 0, OPEN.y) - dir * 3.0, yaw)
		await hold([&"move_forward"], 180, "walk into a pillar at %d deg" % yaw)
		# it got there: the body's axis ends within a capsule radius of the pillar's side
		var p: Vector3 = player.body.global_position
		var gap := Vector2(maxf(absf(p.x - OPEN.x) - 1.0, 0.0), maxf(absf(p.z - OPEN.y) - 1.0, 0.0)).length()
		check(gap < radius + 0.05, "walk into a pillar at %d deg: stopped %.2f m from it, a radius is %.2f" % [yaw, gap, radius])
	pillar.free()


func turn_beside() -> void:
	var pillar := box(OPEN, Vector3(2, 3, 2))
	game.place(Vector3(OPEN.x + 1.0 + radius + 0.02, 0, OPEN.y), 0)
	for a: StringName in [&"move_left", &"move_back", &"move_right", &"move_forward", &"move_left"]:
		await hold([a], 50, "turn beside a pillar (%s)" % a)
	pillar.free()


func corner() -> void:
	var north := box(CORNER + Vector2(1.5, -2.0), Vector3(4, 3, 0.3))
	var west := box(CORNER + Vector2(-0.5, 0), Vector3(0.3, 3, 4))
	var c := CORNER + Vector2(-0.35 + radius + 0.05, -1.85 + radius + 0.05)
	# facing away from the corner: the camera behind the hero is behind both walls
	game.place(Vector3(c.x, 0, c.y), 135)
	for turn: float in [0.0, 40.0, -80.0]:
		player.cam.look(turn, 0.0)
		var inside := 0
		for i in 40:
			await frames(1)
			inside += int(player.state().cam.inside)
		check(inside == 0, "corner, camera turned %d deg: the lens was inside a wall on %d frames" % [turn, inside])
	check(player.cam.dist < player.tuning.camera.distance, "corner: the lens came in (%.2f m)" % player.cam.dist)
	# pressed into the corner by walking back toward the camera
	var inside := 0
	action(&"move_back", true)
	for i in 150:
		await frames(1)
		var s: Dictionary = player.state()
		inside += int(s.cam.inside)
		check(s.player.inside.is_empty(), "corner: the drawn body is inside a wall")
	action(&"move_back", false)
	check(inside == 0, "corner, pressed in: the lens was inside a wall on %d frames" % inside)
	var meshes: Array = player.meshes
	check(player.cam.dist > player.tuning.camera.fade_near or not meshes[0].visible, "a lens inside the fade range hides the hero")
	north.free()
	west.free()


func step_up() -> void:
	var world: Node3D = game.get_node("World")
	var step: float = player.step
	for k: float in [0.9, 1.3]:
		# measured from the ground under the body when its cylinder meets the near face: the patch is not flat
		var top: float = world.height_at(STEPS.x, STEPS.y + 1.0 + radius) + step * k
		var b := box(STEPS, Vector3(2, step * k, 2))
		b.position.y = top - (step * k + 0.2) / 2.0
		game.place(Vector3(STEPS.x, 0, STEPS.y + 3.0), 0)
		await hold([&"move_forward"], 200, "step %.2f m" % (step * k))
		var y: float = player.body.global_position.y
		if k < 1.0:
			check(absf(y - top) < 0.05, "walks up a %.2f m step (feet at %.2f, top at %.2f)" % [step * k, y, top])
		else:
			check(y < top - 0.1, "a %.2f m step stops the hero (feet at %.2f, top at %.2f)" % [step * k, y, top])
		b.free()


## A sky switch reaches the hero: its own fading copies now carry the new design's colours.
func restyle() -> void:
	var night := HouseStyle.load_design("res://design.night.json")
	player.restyle(night)
	var faded := 0
	var matched := 0
	for mi: MeshInstance3D in player.meshes:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			faded += int(m != null and m.shader == player.HeroShader)
			var role: Dictionary = night.materials.get(m.resource_name, {}) if m else {}
			matched += int(role.has("color") and (m.get_shader_parameter("albedo") as Color).is_equal_approx(Color.html(role.color)))
	var total: int = player.meshes.reduce(func(n: int, mi: MeshInstance3D) -> int: return n + mi.mesh.get_surface_count(), 0)
	check(faded == total and matched == total, "restyle: %d of %d hero surfaces fade, %d carry the night colours" % [faded, total, matched])
	player.restyle(HouseStyle.load_design("res://design.json"))


class Rover extends AnimatableBody3D:
	var last := Vector2.ZERO

	func drive(input: Vector2, _hurry: bool, _delta: float) -> void:
		last = input

	func seat() -> Transform3D:
		return global_transform

	func exit_point() -> Vector3:
		return global_position + global_basis.x * 2.0

	func speed() -> float:
		return 0.0


func drive() -> void:
	var v := Rover.new()
	v.collision_layer = 16
	v.add_to_group("vehicle")
	game.add_child(v)
	v.global_position = Vector3(STEPS.x, game.get_node("World").height_at(STEPS.x, STEPS.y + 10), STEPS.y + 10)
	player.enter(v)
	action(&"move_forward", true)
	await frames(10)
	action(&"move_forward", false)
	var s: Dictionary = player.state()
	check(s.vehicle.driving and player.model.visible and player.model.state == &"drive_sit", "driving seats the hero (%s)" % player.model.state)
	var hips: Vector3 = player.body.global_transform * player.model.hip_sit
	check(hips.distance_to(v.seat().origin) < 0.01, "the drawn hips sit on the seat (%.3f m off)" % hips.distance_to(v.seat().origin))
	check(v.last.y > 0.5, "the forward key reaches drive() as input.y")
	check(is_equal_approx(player.cam.distance, player.tuning.camera.vehicle_distance), "the camera keeps the vehicle distance")
	player.exit()
	await frames(5)
	s = player.state()
	check(not s.vehicle.driving and player.model.state != &"drive_sit", "leaving stands the hero up")
	var out: Vector3 = s.player.pos
	check(Vector2(out.x, out.z).distance_to(Vector2(v.exit_point().x, v.exit_point().z)) < 0.1, "the hero steps out at exit_point()")
	v.free()


## A thumb on the stick and another dragging the view, moving in turn as two fingers do, sent the way the
## web build sends them. Half a window of drag turns the tuning angle at every window shape.
func touch(view: Rect2) -> void:
	game.place(Vector3(OPEN.x, 0, OPEN.y), 0)
	var t: CanvasLayer = player.touch
	if not t.visible:
		tap(view.size * Vector2(0.5, 0.2))  # the first touch shows the controls
	await frames(2)
	check(t.visible, "the first touch shows the touch controls")
	var stick: Control = t.stick
	var c := stick.get_global_rect().get_center()
	finger(0, c, true)
	var look_from := view.size * Vector2(0.25, 0.3)
	finger(1, look_from, true)
	var yaw0: float = player.cam.yaw
	var pitch0: float = player.cam.pitch
	var n := 20
	for i in range(1, n + 1):
		move(1, look_from + Vector2(view.size.x / 2.0 * i / n, 0))
		move(0, c + Vector2(stick.size.x / 2.0, 0) + Vector2(0, i % 2))  # the stick thumb trembles too
		await frames(1)
	var turned := rad_to_deg(angle_difference(yaw0, player.cam.yaw))
	var want: float = player.tuning.camera.touch_deg_per_half_window
	check(absf(-turned - want) < 1.0, "%s: half a window of drag turned %.1f deg, wants %.1f" % [view.size, -turned, want])
	check(absf(player.cam.pitch - pitch0) < 0.01, "%s: a flat drag left the pitch alone" % view.size)
	check(Input.get_action_strength(&"move_right") > 0.5, "%s: the stick held right while the view turned" % view.size)
	finger(1, look_from + Vector2(view.size.x / 2.0, 0), false)
	finger(0, c, false)
	await frames(2)
	check(not Input.is_action_pressed(&"move_right"), "%s: lifting the thumb lets go of the stick" % view.size)
	# each button is a full target and holds its action while the finger stays down
	for b: Button in t.root.find_children("*", "Button", true, false):
		check(b.size.x >= TARGET and b.size.y >= TARGET, "%s button is at least %d px" % [b.name, TARGET])
		finger(2, b.get_global_rect().get_center(), true)
		await frames(1)
		check(Input.is_action_pressed(StringName(b.name)), "%s: a finger on the button holds its action" % view.size)
		finger(2, b.get_global_rect().get_center(), false)
		await frames(1)
		check(not Input.is_action_pressed(StringName(b.name)), "%s: lifting the finger lets go" % view.size)
