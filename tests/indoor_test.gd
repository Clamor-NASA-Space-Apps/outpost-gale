extends "res://addons/forge/test.gd"
## First person inside the rooms (skills/third-person-camera, Into first person indoors):
## godot --headless --path . --fixed-fps 60 -s tests/indoor_test.gd
## For HAB 1, the greenhouse and the storm shelter, with real input: walk in through the door and the view goes into the eye within the
## ease time, the lens stays in the room's plan and in no solid, and no part of the hero is drawn; a slow walk back
## and forth across the doorway never flips the view; walking out brings the follow camera back, the hero fading in
## once the lens is clear of it. On no frame is the hero drawn with the lens close enough to cut it.

const ROOMS := ["hab1", "greenhouse", "shelter"]
const START := 7.0  # m in front of the building's centre, along its front (as tests/doors_test.gd)
const SLOW := 0.35  # stick share for the doorway rocking: a careful shuffle

var game: Node3D
var player: Node3D
var world: Node3D
var cuts := 0  # frames the hero was drawn with the lens inside its box's near sphere
var jump := 0.0  # the largest one-frame rise of the hero's fade
var last_shown := 1.0


func _init() -> void:
	watchdog = 240.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
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
	var start := c + front * START
	player.place(Vector3(start.x, world.height_at(start.x, start.z) + 0.05, start.z), rad_to_deg(atan2(-front.x, front.z)))
	await frames(5)
	check(player.room == "" and player.cam.first == 0.0, "%s: outside starts in the follow camera" % id)
	cuts = 0

	# walk in: the room is entered once, the eye reached within the ease time, the lens kept in the plan
	var ease: float = game.tuning.camera.fp_ease_s
	var entered := -1
	var reached := -1
	var flips := 0
	var was := ""
	var strays := 0
	action(&"move_forward", true)
	for i in 60 * 9:
		await tick()
		var s: Dictionary = player.state()
		if s.player.room != was:
			flips += 1
			was = s.player.room
			if was == id and entered < 0:
				entered = i
		if entered >= 0 and reached < 0 and player.cam.first >= 1.0:
			reached = i
		if reached >= 0 and (not lens_in(id) or s.cam.inside):
			strays += 1
		var p: Vector3 = player.body.global_position
		if Vector2(p.x - c.x, p.z - c.z).length() < 1.5 and reached >= 0:  # the shelter's room starts nearer than 1.5 m
			break
	action(&"move_forward", false)
	await frames(10)
	check(entered >= 0 and flips == 1, "%s: walking in enters the room once (%d changes)" % [id, flips])
	check(reached >= 0 and (reached - entered) / 60.0 <= ease + 1.0 / 60.0,
		"%s: in first person %.2f s after the door (ease %.2f s)" % [id, (reached - entered) / 60.0, ease])
	check(strays == 0, "%s: the lens left the room or went into a solid on %d frames" % [id, strays])

	# no part of the hero is drawn in first person, looking level or down at the feet
	var lens: Camera3D = player.cam.lens
	check(not drawn(), "%s: the hero is not drawn in first person (fade %.2f)" % [id, player.shown])
	check(casting(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "%s: in first person the hidden suit still casts its shadow (every mesh shadows only)" % id)
	player.cam.look(0.0, 200.0)  # as far down as the eye's range goes
	await frames(10)
	check(not drawn(), "%s: the hero is not drawn looking down" % id)
	check(absf(lens.global_basis.x.y) < 0.001, "%s: the view never rolls" % id)
	player.cam.look(0.0, -200.0)
	player.cam.look(0.0, 70.0)  # back to a little under level
	await frames(3)

	# rock across the doorway, slowly: from inside out onto the threshold and back, then from outside in and back,
	# each time staying within the band; the view never changes
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
	jump = 0.0
	last_shown = player.shown
	await walk_to(c + front * START, 10.0)
	for i in int(60 * (ease + float(game.tuning.camera.fp_reveal_s))) + 5:
		await tick()
	check(player.room == "" and player.cam.first == 0.0, "%s: walking out returns the follow camera (first %.2f)" % [id, player.cam.first])
	check(drawn() and player.shown == 1.0, "%s: the hero is drawn solid again outside (fade %.2f)" % [id, player.shown])
	check(casting(GeometryInstance3D.SHADOW_CASTING_SETTING_ON), "%s: outside, the suit is drawn and casts again" % id)
	check(jump <= 0.25, "%s: the hero fades in, it does not pop (largest step %.2f in a frame)" % [id, jump])
	check(cuts == 0, "%s: the hero was drawn with the lens close enough to cut it on %d frames" % [id, cuts])
	check(not player.state().cam.inside, "%s: outside, the lens is in no solid" % id)


func casting(how: int) -> bool:
	return player.meshes.all(func(m: MeshInstance3D) -> bool: return m.visible and m.cast_shadow == how)


## One physics frame, then the cut and pop tallies. The lens moved in that frame's physics and the hero's fade was
## applied in the _process after it, so the pair read here is what was drawn.
func tick() -> void:
	await frames(1)
	var cam: Node3D = player.cam
	var p: Vector3 = player.body.global_transform.affine_inverse() * cam.lens.global_position
	var box: AABB = player.model.bounds
	if drawn() and p.distance_to(p.clamp(box.position, box.end)) <= cam._near_radius():
		cuts += 1
	jump = maxf(jump, player.shown - last_shown)
	last_shown = player.shown


func drawn() -> bool:
	return player.meshes.any(func(m: MeshInstance3D) -> bool: return m.visible and m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)


## The door's distance from the item's centre along its front: where the plan's edge meets the front axis.
func door_depth(id: String) -> float:
	var best := 0.0
	for a: Dictionary in world.data.rooms[id]:
		if a.has("circle"):
			best = maxf(best, a.circle[2] - a.circle[1])
		else:
			best = maxf(best, -a.rect[1])
	return best


func lens_in(id: String) -> bool:
	var p: Vector3 = world.items[id].to_local(player.cam.lens.global_position)
	for a: Dictionary in world.data.rooms[id]:
		if a.has("circle") and Vector2(p.x - a.circle[0], p.z - a.circle[1]).length() < a.circle[2]:
			return true
		if a.has("rect") and Rect2(a.rect[0], a.rect[1], a.rect[2] - a.rect[0], a.rect[3] - a.rect[1]).has_point(Vector2(p.x, p.z)):
			return true
	return false


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
