extends "res://addons/forge/test.gd"
## First person inside the rooms (player/follow_cam.gd; back on 15 Nov 2026):
## godot --headless --path . --fixed-fps 60 -s tests/indoor_test.gd
## For HAB 1, the greenhouse and the storm shelter, with real input: walking in through the door the view goes into
## the hero's eye within the ease time and no part of the hero is drawn; a look input turns the view there; walking
## out brings the follow camera back, the hero fading in, never popping. In and out, and in at an angle, no frame puts
## the lens in a solid, the lens never jumps (an eased step at most), the drawn feet never pop on the threshold and
## the walk never drops into the fall clip; a slow walk back and forth across the doorway never flips the room. Placed
## anywhere in a room, at every heading, looking level and as far down and up as the eye goes, the view is first
## person from the first frame, the lens in the room's plan and in no solid, the hero not drawn.

const ROOMS := ["hab1", "greenhouse", "shelter"]
const START := 7.0  # m in front of the building's centre, along its front (as tests/doors_test.gd)
const SLOW := 0.35  # stick share for the doorway rocking: a careful shuffle
const EYE_STEP := 0.1  # m the lens may move in one frame at the eye: a hurry (0.04 m) and a sill caught up (0.03 m)
const GRID := 0.7  # m between standing spots in the sweep

var game: Node3D
var player: Node3D
var world: Node3D
var cuts := 0  # frames the hero was drawn with the lens inside its box's near sphere
var step_max := 0.0  # the largest one-frame move of the lens
var eye_max := 0.0  # the same while the view stayed in the eye
var strays := 0  # frames the lens was in a solid
var feet_max := 0.0  # the largest one-frame rise or fall of a drawn foot
var falls := 0  # frames the model played its fall while walking on the ground
var jump := 0.0  # the largest one-frame rise of the hero's fade
var note := ""  # where the first stray frame or the largest lens move happened
var last_lens := Vector3.INF
var last_first := 0.0
var last_shown := 1.0
var last_feet: Array[Vector3] = []


func _init() -> void:
	watchdog = 1500.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():  # the warm-up draws the hero's parts one by one behind the cover
		await frames(1)
	world = game.get_node("World")
	player = game.get_node("Player")
	var box: Node = game.get_node("Interactions")
	for id: String in ROOMS:
		for it: Node in world.items[id].find_children("*", "", true, false):
			if it.is_in_group("interactable") and it.kind == "door" and not it.open:
				box.use(it)
	await frames(int(60 * (0.2 + float(game.tuning.interact.move_s))))
	for id: String in ROOMS:
		await room(id)
	for id: String in world.data.probe.rooms:
		probes(id)
	await curtain()
	return true


## HAB 1's toilet: a privacy curtain, closed at the start, that E gathers open at its jamb and draws closed again,
## aimed at from the room like a player would. Motion only: nothing else changes.
func curtain() -> void:
	var box: Node = game.get_node("Interactions")
	var it: Node3D = null
	for n: Node in get_nodes_in_group("interactable"):
		if n.kind == "curtain":
			it = n
	if not check(it != null, "HAB 1's toilet curtain is something to use"):
		return
	var c: Node3D = it.thing
	var axis: int = c.get_meta("rail")
	check(not it.open and is_equal_approx(c.scale[axis], 1.0), "the toilet curtain starts closed")
	# stand in the room 0.9 m in front of it, facing it, the view on it
	var hab: Node3D = world.items["hab1"]
	var into := (hab.global_position - it.global_position) * Vector3(1, 0, 1)
	var at := it.global_position + into.normalized() * 0.9
	at.y = hab.to_global(Vector3(0, 0.45, 0)).y
	var to := it.global_position - at
	player.place(at, rad_to_deg(atan2(to.x, -to.z)))
	await frames(40)
	var lens: Camera3D = player.cam.lens
	var down := (it.global_position - lens.global_position)
	player.cam.pitch = -atan2(-down.y, Vector2(down.x, down.z).length())
	await frames(5)
	check(box.target == it and it.prompt() == "Open curtain", "aimed at from the room, it offers Open curtain (%s)" % [box.target.prompt() if box.target else "nothing"])
	var wait := int(60 * (0.2 + float(game.tuning.interact.move_s)))
	box.interact()
	await frames(wait)
	check(it.open and c.scale[axis] < 0.5 and it.prompt() == "Close curtain", "E gathers it open at the jamb (scale %.2f)" % c.scale[axis])
	box.interact()
	await frames(wait)
	check(not it.open and is_equal_approx(c.scale[axis], 1.0), "E draws it closed again")


## A room's own reflection probe (data/world.json probe.rooms): glass and metal inside reflect the room. With only the
## base's probe they showed the rover and the sky (12 Nov playtest). A closed room's probe is an interior one, and
## its light lights only the rooms' layer.
func probes(id: String) -> void:
	if id.begins_with("_") or not world.items.has(id):
		return
	var r: Dictionary = world.data.probe.rooms[id]
	var hab: Node3D = world.items[id]
	var probe := hab.get_node_or_null("Probe_" + id) as ReflectionProbe
	if not check(probe != null and probe.interior == r.get("interior", true), "%s has its own reflection probe" % id):
		return
	var box := AABB(probe.global_position - probe.size / 2.0, probe.size)
	var eye := hab.to_global(Vector3(0, float(r.at[1]) + 0.4, 0))  # about eye height, mid-room
	check(box.has_point(eye), "%s: the room probe's box holds the room at eye height" % id)
	var light := hab.get_node_or_null("RoomLight") as OmniLight3D
	if r.has("light"):
		check(light != null and light.light_cull_mask == probe.reflection_mask and float(light.get_meta("energy", 0.0)) > 0.0,
			"%s: its room light is on and lights only the rooms' layer" % id)
	var base := world.get_node("Probe") as ReflectionProbe
	var swept := 0
	for mi: MeshInstance3D in world.find_children("merged_swept", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		if mi.is_visible_in_tree() and b.intersects(box):
			swept += 1
			check(mi.layers & probe.reflection_mask and not mi.layers & base.reflection_mask,
				"%s: the swept fit-out (%s) takes the room's reflections, not the base's (layers %d)" % [id, mi.get_parent().name, mi.layers])
	check(swept > 0, "%s: the fit-out is merged into a swept mesh the room probe reflects onto" % id)


func room(id: String) -> void:
	var item: Node3D = world.items[id]
	var front := -item.global_basis.z.normalized()
	var c := item.global_position
	var cam: Node3D = player.cam
	var lens: Camera3D = cam.lens
	var start := c + front * START
	player.place(Vector3(start.x, world.height_at(start.x, start.z) + 0.05, start.z), rad_to_deg(atan2(-front.x, front.z)))
	await frames(40)  # settled onto the ground: a placed body drops its last few centimetres
	check(player.room == "" and cam.first == 0.0, "%s: outside starts in the follow camera" % id)
	check(drawn() and player.shown == 1.0 and game.render_game_to_text().heroScreen > 0.1, "%s: outside the view is third person, the hero drawn solid in the frame (fade %.2f, %.2f of the frame)" % [id, player.shown, game.render_game_to_text().heroScreen])
	cuts = 0

	# walk in along the door's axis: the room is entered once, the eye reached within the ease time, nothing jumps
	var ease: float = game.tuning.camera.fp_ease_s
	var entered := -1
	var reached := -1
	var flips := 0
	var was := ""
	reset()
	action(&"move_forward", true)
	for i in 60 * 9:
		await tick()
		if player.room != was:
			flips += 1
			was = player.room
			if was == id and entered < 0:
				entered = i
		if entered >= 0 and reached < 0 and cam.first >= 1.0:
			reached = i
		var p: Vector3 = player.body.global_position
		if Vector2(p.x - c.x, p.z - c.z).length() < 0.6 and reached >= 0:
			break
	action(&"move_forward", false)
	await frames(30)
	check(flips == 1, "%s: walking in enters the room once (%d changes)" % [id, flips])
	check(reached >= 0 and (reached - entered) / 60.0 <= ease + 1.0 / 60.0,
		"%s: in first person %.2f s after the door (ease %.2f s)" % [id, (reached - entered) / 60.0, ease])
	check(cam.first == 1.0 and lens.global_position.distance_to(eye()) < 0.01, "%s: inside, the lens is in the hero's eye (first %.2f, %.3f m off)" % [id, cam.first, lens.global_position.distance_to(eye())])
	check(not drawn() and game.render_game_to_text().heroScreen == 0.0, "%s: the hero is not drawn in first person (fade %.2f)" % [id, player.shown])
	verdict(id, "walking in")

	# a look input turns the view, as far as the eye's range goes, and never rolls it
	var yaw0 := lens.global_rotation.y
	action(&"look_right", true)
	await frames(20)
	action(&"look_right", false)
	var turned := absf(wrapf(lens.global_rotation.y - yaw0, -PI, PI))
	check(turned > deg_to_rad(20.0), "%s: a look input turns the view in the room (%.0f deg in 20 frames)" % [id, rad_to_deg(turned)])
	action(&"look_down", true)
	await frames(60)
	action(&"look_down", false)
	check(absf(lens.global_rotation.x - deg_to_rad(float(game.tuning.camera.fp_pitch_min))) < 0.01, "%s: and down to the eye's lowest pitch (%.0f deg)" % [id, rad_to_deg(lens.global_rotation.x)])
	check(not drawn(), "%s: the hero is not drawn looking down" % id)
	check(absf(lens.global_basis.x.y) < 0.001, "%s: the view never rolls" % id)
	cam.yaw = yaw0
	cam.pitch = 0.0
	await frames(3)

	# rock across the doorway, slowly: from inside out onto the threshold and back, then from outside in and back,
	# each time staying within the band; the room, and the view with it, never changes
	var door := c + front * door_depth(id)
	for side: String in ["inside", "outside"]:
		if side == "outside":
			await walk_to(door + front * 1.2, 6.0)  # wholly out first
		await walk_to(door - front * 0.2 if side == "inside" else door + front * 0.2, 6.0)
		var at: String = player.room
		var changes := 0
		var span := Vector2(INF, -INF)
		for k in 3:
			for dir: Vector3 in [front, -front]:
				var goal := door + dir * 0.35
				await walk_to(goal, 5.0, SLOW)  # a turn on the spot takes about 1.5 s
				var along: float = (player.body.global_position - door).dot(front)
				span = Vector2(minf(span.x, along), maxf(span.y, along))
				if player.room != at:
					changes += 1
					at = player.room
		check(changes == 0, "%s: rocking in the doorway from %s (%.2f to %.2f m from the door) flips the view %d times" % [id, side, span.x, span.y, changes])

	# walk out: the follow camera comes back and the hero fades in, never popping
	await walk_to(c - front * 0.3, 8.0)
	reset()
	await walk_to(c + front * START, 12.0)
	for i in int(60 * (ease + float(game.tuning.camera.fp_reveal_s))) + 5:
		await tick()
	check(player.room == "" and cam.first == 0.0, "%s: walking out returns the follow camera (first %.2f)" % [id, cam.first])
	check(drawn() and player.shown == 1.0, "%s: the hero is drawn solid again outside (fade %.2f)" % [id, player.shown])
	check(jump <= 0.25, "%s: the hero fades in, it does not pop (largest step %.2f in a frame)" % [id, jump])
	verdict(id, "walking out")

	# in at an angle: from 4 m out, 35 degrees off the door's axis, to the door and on to the middle, the view left
	# where the walk puts it
	var off := front.rotated(Vector3.UP, deg_to_rad(35.0)) * 4.0
	var from := door + off
	player.place(Vector3(from.x, world.height_at(from.x, from.z) + 0.05, from.z), rad_to_deg(atan2(-off.x, off.z)))
	await frames(40)
	reset()
	await walk_to(door + front * 0.6, 8.0)
	await walk_to(c - front * 0.3, 8.0)
	check(player.room == id and cam.first == 1.0, "%s: the slanted walk ends inside, in first person (%s, first %.2f)" % [id, player.room, cam.first])
	verdict(id, "walking in at 35 degrees")
	check(cuts == 0, "%s: the hero was drawn with the lens close enough to cut it on %d frames" % [id, cuts])

	await sweep(id, player.rooms[id])


## Where first person looks from: the visor's middle over the hero, ahead along the view.
func eye() -> Vector3:
	var cam: Node3D = player.cam
	return player.body.global_position + Vector3.UP * cam.eye.y + Basis(Vector3.UP, cam.yaw) * Vector3(0.0, 0.0, cam.eye.z)


func reset() -> void:
	step_max = 0.0
	eye_max = 0.0
	strays = 0
	note = ""
	feet_max = 0.0
	falls = 0
	jump = 0.0
	last_shown = player.shown
	last_lens = Vector3.INF
	last_feet.clear()


func verdict(id: String, walk: String) -> void:
	check(strays == 0, "%s, %s: the lens was in a solid on %d frames (%s)" % [id, walk, strays, note])
	# the ease between the follow lens and the eye is a smoothstep: its steepest frame is 1.5 / (fp_ease_s * 60) of
	# the way, here over the play distance and a metre for the walk and the eye's height. A cut is the whole way at once
	var t: Dictionary = game.tuning.camera
	var most: float = 1.5 / (float(t.fp_ease_s) * 60.0) * (float(t.distance) + 1.0)
	check(step_max <= most, "%s, %s: the view is eased, the lens never jumps (largest move %.3f m in a frame, at most %.2f; %s)" % [id, walk, step_max, most, note])
	check(eye_max <= EYE_STEP, "%s, %s: in the eye the lens moves with the hero (largest move %.3f m in a frame, at most %.2f)" % [id, walk, eye_max, EYE_STEP])
	var hero: Dictionary = game.tuning.hero
	var pop: float = player.step / float(hero.step_catch_s) / 60.0 + 0.03  # a step caught up, plus the stride's own lift
	check(feet_max <= pop, "%s, %s: the drawn feet never pop (largest move %.3f m in a frame, at most %.3f)" % [id, walk, feet_max, pop])
	check(falls == 0, "%s, %s: the walk never drops into the fall clip on the ground (%d frames)" % [id, walk, falls])


## Placed anywhere in the room (the body wholly in the plan), at every heading: on the very next frame drawn the view
## is in the eye, level, along the heading, and the hero is not drawn; then looking as far down and up as the eye goes
## the lens stays in the plan and in no solid. Spots where the body would be in a solid are skipped.
func sweep(id: String, spec: Dictionary) -> void:
	var item: Node3D = world.items[id]
	var t: Dictionary = game.tuning.camera
	var cam: Node3D = player.cam
	var spots := 0
	var outside := 0
	var solid := 0
	var seen := 0
	var late := 0
	var first := ""  # the first pose that failed, to find it again
	for gx in range(-6, 7):
		for gz in range(-8, 7):
			var at := item.to_global(Vector3(gx * GRID, 0.0, gz * GRID))
			if cam.depth_in(spec, at) < player.breadth / 2.0 + 0.05:
				continue
			var over := item.to_global(Vector3(gx * GRID, 1.9, gz * GRID))  # under every room's ceiling
			var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(over, over + Vector3.DOWN * 4.0, 1 | 2, [player.body.get_rid()]))
			if hit.is_empty() or item.to_local(hit.position).y > 0.6:
				continue  # no floor, or the top of a rack
			for yaw in range(0, 360, 45):
				player.place(hit.position + Vector3.UP * 0.05, yaw)
				# before any physics step: what the next drawn frame shows (a wake, Continue)
				var fwd: Vector3 = -cam.lens.global_basis.z
				if cam.first < 1.0 or cam.lens.global_position.distance_to(eye()) > 0.01 or absf(fwd.y) > 0.001 or fwd.dot(-player.body.global_basis.z) < 0.999:
					late += 1
				for pitch: float in [0.0, t.fp_pitch_min, t.fp_pitch_max]:
					cam.pitch = deg_to_rad(pitch)
					await frames(3)
					if not player.inside().is_empty() or player.room != id:
						break  # a spot in the fit-out
					spots += 1
					for f in 4:
						await frames(1)
						var bad := ""
						if cam.depth_in(spec, cam.lens.global_position) <= 0.0:
							outside += 1
							bad = "out of the plan"
						if player.state().cam.inside:
							solid += 1
							bad = "in " + blocker()
						if drawn() or cam.first < 1.0:
							seen += 1
							bad = "the hero drawn"
						if bad != "" and first == "":
							first = "%s at %s yaw %d pitch %d, frame %d" % [bad, item.to_local(hit.position), yaw, pitch, f]
	check(spots > 0, "%s: the sweep stood somewhere (%d spot-poses)" % [id, spots])
	check(late == 0, "%s: placed in the room, the view is in the eye, level, along the heading before the next frame (%d placings were not)" % [id, late])
	check(seen == 0, "%s: standing in the room, the hero was drawn or the view left the eye on %d frames of %d (first: %s)" % [id, seen, spots * 4, first])
	check(outside == 0, "%s: standing in the room, the lens left the plan on %d frames of %d (first: %s)" % [id, outside, spots * 4, first])
	check(solid == 0, "%s: standing in the room, the lens was in a solid on %d frames of %d (first: %s)" % [id, solid, spots * 4, first])


## What the lens is in, as follow_cam.inside() finds it: the solid between the pivot and the lens, else the one the
## lens's sphere overlaps.
func blocker() -> String:
	var cam: Node3D = player.cam
	var space := root.world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, cam.lens.global_position, cam.SOLIDS, cam.excluded))
	if hit:
		return "the line to it: " + str((hit.collider as Node).get_path()).get_slice("/World/", 1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cam.arm.shape
	q.transform = Transform3D(Basis(), cam.lens.global_position)
	q.collision_mask = cam.SOLIDS | cam.THIN
	q.exclude = cam.excluded
	var o := space.intersect_shape(q, 1)
	return "its sphere: " + str((o[0].collider as Node).get_path()).get_slice("/World/", 1) if o else "nothing now"


## One physics frame, then the cut and pop tallies. The lens moved in that frame's physics and the hero's fade was
## applied in the _process after it, so the pair read here is what was drawn.
func tick() -> void:
	await frames(1)
	var cam: Node3D = player.cam
	var lens: Vector3 = cam.lens.global_position
	var p: Vector3 = player.body.global_transform.affine_inverse() * lens
	var box: AABB = player.model.bounds
	if drawn() and p.distance_to(p.clamp(box.position, box.end)) <= cam._near_radius():
		cuts += 1
	if last_lens != Vector3.INF and cam.first == 1.0 and last_first == 1.0:
		eye_max = maxf(eye_max, lens.distance_to(last_lens))
	if last_lens != Vector3.INF and lens.distance_to(last_lens) > step_max:
		step_max = lens.distance_to(last_lens)
		if strays == 0:
			note = "move %.3f at hero %s, dist %.2f, soft %.2f, first %.2f" % [step_max, player.body.global_position, cam.dist, cam.soft, cam.first]
	last_lens = lens
	last_first = cam.first
	jump = maxf(jump, player.shown - last_shown)
	last_shown = player.shown
	if player.state().cam.inside:
		if strays == 0:
			note = "in %s at hero %s" % [blocker(), player.body.global_position]
		strays += 1
	var feet: Array[Vector3] = player.model.feet()
	for i in mini(feet.size(), last_feet.size()):
		feet_max = maxf(feet_max, absf(feet[i].y - last_feet[i].y))
	last_feet = feet
	if player.model.phase == "air" and player.launch < 0.0:
		falls += 1


func drawn() -> bool:
	return player.meshes.any(func(m: MeshInstance3D) -> bool: return m.visible)


## The door's distance from the item's centre along its front: where the plan's edge meets the front axis.
func door_depth(id: String) -> float:
	var best := 0.0
	for a: Dictionary in world.data.rooms[id]:
		if a.has("circle"):
			best = maxf(best, a.circle[2] - a.circle[1])
		else:
			best = maxf(best, -a.rect[1])
	return best


## Steers with the move stick toward `goal` (a stick share `strength`), the way a player walks there, until within a
## few centimetres or `seconds` pass; the stick is read relative to the view, so it is aimed through the camera's yaw.
func walk_to(goal: Vector3, seconds: float, strength := 1.0) -> void:
	for i in int(60 * seconds):
		var to: Vector3 = goal - player.body.global_position
		to.y = 0.0
		if to.length() < 0.05:
			break
		var local: Vector3 = player.cam.ground_basis().inverse() * to.normalized() * strength
		stick(Vector2(local.x, local.z))
		await tick()
	stick(Vector2.ZERO)
	for i in 20:
		await tick()


func stick(v: Vector2) -> void:
	for a: Array in [[&"move_right", v.x], [&"move_left", -v.x], [&"move_back", v.y], [&"move_forward", -v.y]]:
		var e := InputEventAction.new()
		e.action = a[0]
		e.strength = maxf(a[1], 0.0)
		e.pressed = a[1] > 0.0
		send(e)
