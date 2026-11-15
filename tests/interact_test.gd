extends "res://addons/forge/test.gd"
## Every sandbox interaction does its one physical thing: godot --headless --path . -s tests/interact_test.gd

var game: Node3D
var box: Node3D


func _init() -> void:
	watchdog = 180.0  # game seconds under --fixed-fps: the hatch trips (open, fade, shut) took the run past 120


## Stands the hero a metre off the first interactable of `kind`, facing the nearest point of its shape, and returns
## it: off a door's face (its thinnest level side), at the rover's hatch, beside a bag.
func face(kind: String) -> Node3D:
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if it.kind == kind:
			var s: AABB = it.shape
			var n := Vector3.AXIS_X if s.size.x < s.size.z else Vector3.AXIS_Z
			var off: Vector3 = (it.thing.global_basis[n] * Vector3(1, 0, 1)).normalized() * (s.size[n] / 2.0 + 1.0)
			var from: Vector3 = it.thing.exit_point() if kind == "rover" else it.middle() + (off if kind != "bag" else Vector3(0.7, 0, 0.7))
			var to: Vector3 = it.nearest(from + Vector3.UP * box.hand_y) - from
			game.place(Vector3(from.x, 0, from.z), rad_to_deg(atan2(to.x, -to.z)))
			return it
	check(false, "no %s interactable" % kind)
	return null


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	box = game.interactions
	var player: Node3D = game.player
	await galley()

	var door := face("door")
	await frames(3)
	check(box.target == door, "the door is the target in front of it (got %s)" % [box.target])
	var shut: float = door.thing.rotation.y
	var p0: Vector3 = player.body.global_position
	game.interactions.interact()
	await frames(2)
	check(player.cut.is_empty() and absf(door.thing.rotation.y - shut) > 0.0, "E: the door starts to swing at once, no reach clip (cut %s)" % [player.cut])
	await frames(60)
	# from 1 m off its face the hero is out of its swing (the swing never starts where the leaf would meet the hero)
	check(absf(door.thing.rotation.y - shut) > deg_to_rad(95) and player.state().player.inside.is_empty(), "and opens all the way (%.0f deg), never into the hero" % rad_to_deg(door.thing.rotation.y - shut))
	check(player.body.global_position.distance_to(p0) < 0.05, "the hero stays where it stood")

	# a solar panel is not tilted by hand: its row has a wiper, run from a button (uses_test's wiper)
	check(not game.get_tree().get_nodes_in_group("interactable").any(func(it: Node) -> bool: return it.kind == "panel"), "no panel is usable by itself")

	await steady()
	var bag := face("bag")
	await frames(3)
	# the bags lie side by side, and the one steady() left chosen keeps its stick: any bag will do
	check(box.target != null and box.target.kind == bag.kind, "a bag is the target beside them (got %s)" % [box.target])
	box.interact()
	await frames(2)
	check(player.cut.is_empty() and box.carried != null and box.carried.is_in_group("carriable"), "E: a bag is in the hands at once, no kneel")
	check(game.render_game_to_text().carry != "", "state says what is carried")
	var b: Node3D = box.carried
	check(b.get_parent() == player.body, "it rides with the hero")
	check(_clear_of_body(b), "held out in front, the bag is not inside the body")
	box.interact()
	await frames(2)
	check(box.carried == null and player.cut.is_empty(), "E: it is put down at once")
	check(absf(b.global_position.y - game.world.height_at(b.global_position.x, b.global_position.z)) < 0.05, "the bag rests on the ground")
	await set_down_beside()

	await hatch()
	var rover := face("rover")
	await frames(3)
	check(box.target == rover, "the rover is the target at its hatch (got %s)" % [box.target])
	var start: Vector3 = rover.thing.global_position
	box.interact()
	await frames(2)
	check(player.vehicle == rover.thing, "E: the hero is in the rover at once")
	check(seen() and solid(), "aboard, every mesh of the hero is drawn, solid (shown %.2f)" % player.shown)
	var seat: Vector3 = rover.thing.seat().origin
	var sk: Skeleton3D = player.model.skeleton
	var head: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"Head")).origin
	var hips: Vector3 = player.body.global_transform * player.model.hip_sit
	check(hips.distance_to(seat) < 0.05 and head.y > seat.y + 0.3 and head.y < game.world.drawn(rover.thing).end.y
			and Vector2(head.x - seat.x, head.z - seat.z).length() < 0.4,
			"it sits in the cab: hips on the driver's seat, helmet over them and under the roof (hips %.2f m off, head %s, seat %s)" % [hips.distance_to(seat), head, seat])
	action(&"move_forward")
	await frames(240)
	action(&"move_forward", false)
	await frames(60)
	var moved: float = (rover.thing.global_position - start).length()
	check(moved > 1.0, "the rover drives (moved %.2f m)" % moved)
	box.interact()
	await frames(2)
	check(player.vehicle == null and seen() and solid(), "E: the hero gets out at once, drawn as before")
	await frames(30)
	check(player.state().player.inside.is_empty(), "on free ground, in no solid")
	var out: Vector3 = player.body.global_position
	check(out.distance_to(rover.thing.exit_point()) < 1.0, "the hero is at the rover's hatch")
	await frames(3)
	var dust: Node3D = game.world.dust
	check(dust._streams.keys().any(func(k: String) -> bool: return k != "_warm"), "the wheels threw dust while driving")
	check(dust._streams.values().all(func(st: Dictionary) -> bool: return not st.grit.emitting and not st.haze.emitting), "no new dust once the driver is out")

	# rocks (reality.json rover.climb): a small one under a wheel is rolled over, a tall one stops it smoothly
	var r: Node3D = rover.thing
	var climb: float = r.climb
	var small := await over_rock(r, 0.6 * climb, 17.0)
	check(small.passed, "the rover rolls over a %.2f m rock (got to x %.1f)" % [0.6 * climb, small.x])
	check(small.rock > 0.5 * climb, "a wheel climbs onto it (highest %.2f m)" % small.rock)
	check(small.tilt > 1.0, "the body tilts as a wheel climbs (%.1f deg)" % small.tilt)
	var big := await over_rock(r, 1.8 * climb, 19.0)
	check(not big.passed, "a %.2f m rock stops the rover (got to x %.1f)" % [1.8 * climb, big.x])
	check(big.blocked == "rock", "it stopped for the rock (%s)" % big.blocked)
	check(big.top > 0.9 * r.top, "it was at full speed before (%.2f m/s)" % big.top)
	check(big.drop < r.brake / 60.0 * 1.01, "it braked, no dead stop (largest drop %.3f m/s in a frame)" % big.drop)
	check(absf(r.v) < 0.01, "and stands still against it (%.2f m/s)" % r.v)

	# low flat things (a build pad, a cable) are under the climb height: driven over at a walk and at full speed,
	# wheels on top, never braked for and never thrown up (13 Nov playtest: the rover stopped at a pad's edge)
	var walk: float = game.world.sheet_values["hero.speed.walk"]
	for id: String in ["pad1", "pad2"]:
		var pad: Node3D = game.world.items[id]
		for throttle: float in [walk / r.top, 1.0]:
			var run := await across(r, pad.global_position, [pad], throttle, 3.0)
			if not run.has("passed"):
				check(false, "%s: no clear lane across it for the test" % id)
				continue
			var top: float = pad.global_position.y + 0.15 - game.world.height_at(pad.global_position.x, pad.global_position.z)  # forge/pad_build.py T
			check(run.passed, "%s at %.1f m/s: the rover drives across (%s)" % [id, throttle * r.top, run])
			check(run.rock > 0.8 * top, "%s: its wheels ride on top, %.2f m up (highest %.2f m)" % [id, top, run.rock])
			check(run.blocked == "" and run.slow < 0.1 * throttle * r.top, "%s: never braked for (%s)" % [id, run])
			check(run.rise < 0.5 * top and run.heave < r.travel, "%s: rolled up, not thrown (%s)" % [id, run])
	var lines: Array = game.world.data.get("cables", {}).get("lines", [])
	var crossed := 0
	for line: Array in lines:
		for i in line.size() - 1:
			var mid := (Vector2(line[i][0], line[i][1]) + Vector2(line[i + 1][0], line[i + 1][1])) / 2.0
			if crossed < 2 and absf(mid.x) < 60.0 and absf(mid.y) < 60.0:
				var cables: Array = [game.world.get_node_or_null("Cables")].filter(func(c: Node) -> bool: return c != null)
				var run := await across(r, Vector3(mid.x, 0.0, mid.y), cables, 1.0 if crossed else walk / r.top, 0.5,
					Vector2(line[i + 1][0] - line[i][0], line[i + 1][1] - line[i][1]))
				if run.has("passed"):
					crossed += 1
					check(run.passed and run.blocked == "" and run.slow < 0.1 * r.top, "a cable at %s: driven over (%s)" % [mid, run])
	check(crossed == 2 or lines.is_empty(), "two cables crossed at a walk and at speed (%d had a clear lane)" % crossed)
	await lights(r)
	return true


## Every mesh of the hero is drawn. Hidden in the cab (14 Nov), its helmet lamps hung in the windscreen alone.
func seen() -> bool:
	return game.player.meshes.all(func(m: MeshInstance3D) -> bool: return m.is_visible_in_tree())


## None of it is faded: every material on the solid shader, the fade at 1.
func solid() -> bool:
	var player: Node3D = game.player
	return player.shown == 1.0 and player.meshes.all(func(m: MeshInstance3D) -> bool:
		return range(m.mesh.get_surface_count()).all(func(i: int) -> bool:
			return (m.get_surface_override_material(i) as ShaderMaterial).shader == player.HeroShader))


## The rover's lights: dark by day with the crew aboard, at night only with the crew aboard, fading in and out over
## about a second (tuning.json sky.lamps_fade_s), and off is the glimmer, never zero (no shader change in play).
func lights(r: Node3D) -> void:
	var player: Node3D = game.player
	var clock: Node = game.clock
	var floor_k: float = game.tuning.sky.light_floor
	var fade: float = game.tuning.sky.lamps_fade_s
	clock.pinned = true
	clock.set_hour(12.0)
	clock.refresh()
	player.enter(r)
	await frames(int(fade * 90.0))
	check(r.lamp_mat != null and r.lamp_level == 0.0, "by day the crew aboard leaves its lights off (%.2f)" % r.lamp_level)
	var mat_rid: RID = r.lamp_mat.get_rid()
	var full: float = r._lamp_full
	check(is_equal_approx(r.lamp_mat.emission_energy_multiplier, full * floor_k), "off is the glimmer (%.4f of %.2f)" % [r.lamp_mat.emission_energy_multiplier, full])
	player.exit()
	clock.set_hour(23.0)
	clock.refresh()
	await frames(int(fade * 90.0))
	check(r.lamp_level == 0.0 and is_equal_approx(r.lamp_mat.emission_energy_multiplier, full * floor_k), "at night an empty rover stays dark while the base's lamps burn (%.2f)" % r.lamp_level)
	player.enter(r)
	await frames(int(fade * 20.0))
	check(r.lamp_level > 0.05 and r.lamp_level < 0.6, "boarding at night fades its lights in, never pops them on (%.2f a third of a fade in)" % r.lamp_level)
	await frames(int(fade * 90.0))
	check(r.lamp_level == 1.0 and is_equal_approx(r.lamp_mat.emission_energy_multiplier, full), "then they burn full (%.2f)" % r.lamp_level)
	check(r.lamp_mat.get_rid() == mat_rid and r.lamp_mat.emission_enabled, "lighting up changed only a uniform: one material, emission on throughout")
	player.exit()
	await frames(int(fade * 20.0))
	check(r.lamp_level < 0.95 and r.lamp_level > 0.4, "leaving fades them out (%.2f a third of a fade on)" % r.lamp_level)
	await frames(int(fade * 90.0))
	check(r.lamp_level == 0.0, "and they go dark (%.2f)" % r.lamp_level)
	clock.pinned = false


## HAB 1's galley (world.json `uses`): at its stand point, the view on the dispenser, E held for the row's `hold_s`
## drinks: the drink sound, no clip, no new state keys.
func galley() -> void:
	var spot: Node3D = null
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if it.kind == "spot" and it.row.kind == "drink":
			spot = it
	if not check(spot != null, "HAB 1's galley has a drink spot (world.json uses)"):
		return
	var player: Node3D = game.player
	var hab: Node3D = game.world.items["hab1"]
	var at: Vector3 = spot.stand().origin
	at.y = hab.to_global(Vector3(0, 0.45, 0)).y
	var to: Vector3 = spot.middle() - at
	player.place(at, rad_to_deg(atan2(to.x, -to.z)))
	await frames(40)
	var down: Vector3 = spot.middle() - player.cam.lens.global_position
	player.cam.pitch = -atan2(-down.y, Vector2(down.x, down.z).length())
	await frames(5)
	check(player.room != "", "the hero stands inside HAB 1 (room '%s')" % player.room)
	check(box.target == spot, "the galley dispenser is the target (got %s)" % [box.target])
	check(box.prompt_label.text.ends_with("Drink"), "the prompt says Drink ('%s')" % box.prompt_label.text)
	var keys: Array = game.render_game_to_text().keys()
	var heard: Array = []
	var hear := func(what: String, _pos: Vector3) -> void: heard.append(what)
	box.used.connect(hear)
	Input.action_press(&"interact")
	box.interact()
	await frames(2)
	check(heard.is_empty() and box.hold > 0.0, "E down: the drink waits for its hold (%s, hold %.2f)" % [heard, box.hold])
	await frames(int(float(spot.row.hold_s) * 60.0) + 2)
	Input.action_release(&"interact")
	box.used.disconnect(hear)
	# no use clips (14 Nov): the action is named for the rules once E was held long enough (15 Nov), the hero free
	check(player.cut.is_empty() and heard == ["drink"], "E held: the drink is had once, no clip (%s)" % [heard])
	var extra: Array = game.render_game_to_text().keys().filter(func(k: String) -> bool: return not k in keys)
	check(extra.is_empty(), "no new state keys (%s)" % [extra])
	check(not (spot.props.pouch as Node3D).visible, "its pouch stays put away")


## Drives the rover straight across `at` (x, z) from 8 m before it (room to reach top speed) to `beyond` + 4 m past
## it, at `throttle`, along the first way (east, north, west, south, each through the middle or 1.5 m to a side; or
## across `along`, a cable's run) whose lane holds nothing but `own` (no rock, wall, PIP or hero to brake for). Returns {} with no clear lane, else {passed, rock (highest a wheel stood on),
## blocked, slow (most speed lost below the throttle's once reached), rise (most a frame lifted the body, m),
## heave (most the drawn body rode off the wheels' plane over the thing, m)}.
func across(r: Node3D, at: Vector3, own: Array, throttle: float, beyond: float, along := Vector2.ZERO) -> Dictionary:
	var world: Node3D = game.world
	var ways: Array[Vector3] = [Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT, Vector3.BACK]
	if along != Vector2.ZERO:
		var n := Vector3(-along.y, 0.0, along.x).normalized()
		ways = [n, -n]
	var skip: Array[RID] = [r.get_rid()]
	for o: Node3D in own:
		for b: CollisionObject3D in o.find_children("*", "CollisionObject3D", true, false):
			skip.append(b.get_rid())
	var g: float = world.height_at(at.x, at.z)
	var lanes: Array[Array] = []
	for way in ways:
		for side: float in [0.0, 1.5, -1.5]:
			lanes.append([way, way.cross(Vector3.UP) * side])
	for l: Array in lanes:
		var way: Vector3 = l[0]
		var from: Vector3 = at + l[1] - way * 8.0
		var length := 8.0 + beyond + 4.0
		var q := PhysicsShapeQueryParameters3D.new()
		var lane := BoxShape3D.new()
		lane.size = Vector3(3.0, 5.0, length + 4.6)  # the rover's width and length, with a little room
		q.shape = lane
		q.collision_mask = world.STATICS | world.THIN | world.HERO | world.VEHICLES | world.CARRIABLES
		q.exclude = skip
		var mid := from + way * (length / 2.0)
		q.transform = Transform3D(Basis.looking_at(way), Vector3(mid.x, g + 1.5, mid.z))
		if not r.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			continue
		r.yaw = atan2(-way.x, -way.z)
		r.v = 0.0
		r._apply(r._pose(Vector3(from.x, 0.0, from.z), r.yaw))
		await frames(2)
		var out := {"rock": 0.0, "blocked": "", "slow": 0.0, "rise": 0.0, "heave": 0.0}
		var want: float = throttle * r.top
		var reached := false
		var y: float = r.global_position.y
		for i in int((length / want + r.top / r.accel + 2.0) * 60.0):
			r.drive(Vector2(0, throttle), false, 1.0 / 60.0)
			out.rock = maxf(out.rock, r.on_rock)
			if r.blocked != "":
				out.blocked = r.blocked
			reached = reached or r.v > 0.98 * want
			if reached:
				out.slow = maxf(out.slow, want - r.v)
			out.rise = maxf(out.rise, r.global_position.y - y)
			# over the thing only: the placing jump shakes the springs for the first second
			if absf((r.global_position - at - l[1]).dot(way)) < beyond + 2.5:
				out.heave = maxf(out.heave, absf(r.lean.origin.y))
			y = r.global_position.y
			await frames(1)
			if (r.global_position - from).dot(way) > length:
				break
		out.passed = (r.global_position - from).dot(way) > length - 0.5
		return out
	return {}


## The rover is boarded at its rear hatch only: offered from spots behind it (across the hatch, two distances, three
## headings off facing it), never from beside its front or mid-hull. Spots are in the rover's own space, off its hull.
func hatch() -> void:
	var it: Node3D = null
	for n: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if n.kind == "rover":
			it = n
	var r: Node3D = it.thing
	var hull: AABB = it.thing.find_children("*", "CollisionShape3D", true, false)[0].shape.get_debug_mesh().get_aabb()
	var back: Vector3 = (r.global_transform.affine_inverse() * r.exit_point())  # behind the hatch, as the model says
	var missed: Array[String] = []
	for dz: float in [0.0, -0.3]:
		for x: float in [-0.4, 0.0, 0.4]:
			for turn: float in [-20.0, 0.0, 20.0]:
				var at: Vector3 = r.global_transform * Vector3(x, 0, back.z + dz)
				var to: Vector3 = it.nearest(at + Vector3.UP * box.hand_y) - at
				game.place(Vector3(at.x, 0, at.z), rad_to_deg(atan2(to.x, -to.z)) + turn)
				await frames(3)
				if box.target != it:
					missed.append("x %.1f z %.1f turn %d (%s)" % [x, back.z + dz, turn, box.target])
	check(missed.is_empty(), "the rover is offered at its rear hatch from every spot and heading %s" % [missed])
	var mid := hull.get_center()
	var front := Vector3(mid.x, 0, hull.position.z - 0.8) if back.z > mid.z else Vector3(mid.x, 0, hull.end.z + 0.8)
	for spot: Vector3 in [front, Vector3(hull.position.x - 0.8, 0, mid.z), Vector3(hull.end.x + 0.8, 0, mid.z)]:
		var at: Vector3 = r.global_transform * spot
		var to: Vector3 = r.global_transform * Vector3(mid.x, 0, mid.z) - at
		game.place(Vector3(at.x, 0, at.z), rad_to_deg(atan2(to.x, -to.z)))
		await frames(3)
		check(box.target != it, "facing the rover's hull from %s (its space), no Drive rover (got %s)" % [spot, box.target])


## Two bags side by side in reach, the heading rocking a few degrees either side of the line between them: the target
## stays the one first picked (interact.stick_deg), never flickering between them.
func steady() -> void:
	var bags: Array = game.get_tree().get_nodes_in_group("interactable").filter(func(it: Node3D) -> bool: return it.kind == "bag")
	var a: Vector3 = bags[0].middle()
	var b: Vector3 = bags[1].middle()
	var mid := (a + b) / 2.0
	var side := Vector3.UP.cross(b - a).normalized() * 1.0
	if bags.size() > 2 and side.dot(bags[2].middle() - mid) > 0.0:
		side = -side  # stand on the side away from any third bag, so the two are the only rivals
	var at := mid + side
	var to := mid - at
	game.place(Vector3(at.x, 0, at.z), rad_to_deg(atan2(to.x, -to.z)))
	await frames(3)
	var player: Node3D = game.player
	var centre: float = player.yaw
	var first: Node3D = box.target
	var changes := 0
	for i in 120:
		player.yaw = centre + deg_to_rad(3.0 * sin(i * 0.4))
		await frames(1)
		changes += 1 if box.target != first else 0
	check(first in bags.slice(0, 2), "standing between two bags, one is the target (%s)" % [first])
	check(changes == 0, "rocking the heading 3 degrees each way, the target never flips (%d frames on the other)" % changes)


## Puts the rover on open ground heading east along z = 18 and a test rock `tall` metres over the ground 12 m
## ahead (room to reach top speed) at z `lane` (the left wheels' line is 17, the right's 19), then drives it forward for 10 s.
## Returns {passed: bool, x, rock: highest rock a wheel stood on, tilt: most pitch or roll, deg, top: fastest,
## drop: largest speed lost in one frame, blocked}.
func over_rock(r: Node3D, tall: float, lane: float) -> Dictionary:
	var world: Node3D = game.world
	var x0 := -22.0
	var at := Vector3(x0 + 12.0, 0.0, lane)
	var g: float = world.height_at(at.x, at.z)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	(col.shape as BoxShape3D).size = Vector3(0.6, 1.0, 0.6)
	body.add_child(col)
	body.collision_layer = 2 | 256  # a solid rock (world/rocks.gd ROCK)
	body.collision_mask = 0
	world.add_child(body)
	body.global_position = Vector3(at.x, g + tall - 0.5, at.z)
	r.add_collision_exception_with(body)
	r.yaw = -PI / 2.0
	r.v = 0.0
	r._apply(r._pose(Vector3(x0, 0.0, 18.0), r.yaw))
	await frames(2)
	var out := {"rock": 0.0, "tilt": 0.0, "top": 0.0, "drop": 0.0, "blocked": ""}
	var last := 0.0
	for i in 600:
		r.drive(Vector2(0, 1), false, 1.0 / 60.0)
		out.rock = maxf(out.rock, r.on_rock)
		var e: Vector3 = r.global_basis.get_euler()
		out.tilt = maxf(out.tilt, rad_to_deg(maxf(absf(e.x), absf(e.z))))
		out.top = maxf(out.top, r.v)
		out.drop = maxf(out.drop, last - r.v)
		if OS.has_environment("ROVER_DEBUG") and r.v < last - 0.03:
			print("frame %d v %.3f -> %.3f blocked %s x %.3f" % [i, last, r.v, r.blocked, r.global_position.x])
		if r.blocked != "":
			out.blocked = r.blocked
		last = r.v
		await frames(1)
	out.x = r.global_position.x
	out.passed = r.global_position.x > at.x + 3.0
	body.free()
	return out


## The carried bag's box against the drawn body (the idle pose's box, a little in, as hands and arms reach round it).
func _clear_of_body(b: Node3D) -> bool:
	var player: Node3D = game.player
	var cs: CollisionShape3D = b.find_children("*", "CollisionShape3D", true, false)[0]
	var bag: AABB = player.body.global_transform.affine_inverse() * cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
	var torso: AABB = player.model.bounds.grow(-0.08)  # the torso and pack, not the arms held out
	return not bag.intersects(torso)


## 14 Nov playtest: a bag set down where another bag lay sank into it. Standing with another bag where E would put
## it, from four sides: it is set down beside it, never in it (or kept in the hands where there is no room).
func set_down_beside() -> void:
	var bags: Array = game.get_tree().get_nodes_in_group("interactable").filter(func(it: Node3D) -> bool: return it.kind == "bag")
	var player: Node3D = game.player
	var mine: Node3D = bags[0]
	var under: Node3D = bags[1]
	for k in 4:
		var face := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 4.0)
		var at: Vector3 = mine.middle() - face * 1.2
		game.place(Vector3(at.x, game.world.height_at(at.x, at.z) + 0.02, at.z), rad_to_deg(atan2(face.x, -face.z)))
		await frames(40)
		box.target = mine
		box.interact()
		await frames(2)
		if not check(box.carried == mine.thing, "side %d: picked up" % k):
			continue
		var spot: Vector3 = under.middle() + face * (float(game.tuning.interact.carry_ahead) + 0.4)
		game.place(Vector3(spot.x, game.world.height_at(spot.x, spot.z) + 0.02, spot.z) - face * 2.0 * (float(game.tuning.interact.carry_ahead) + 0.4), rad_to_deg(atan2(face.x, -face.z)))
		await frames(40)
		box.interact()
		await frames(2)
		var cs: CollisionShape3D = mine.thing.find_children("*", "CollisionShape3D", true, false)[0]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cs.shape
		q.transform = cs.global_transform
		q.collision_mask = box.CARRIABLES
		q.exclude = [(mine.thing as CollisionObject3D).get_rid()]
		var deepest := 0.0
		var pairs := game.get_world_3d().direct_space_state.collide_shape(q, 32)
		for i in range(0, pairs.size(), 2):
			deepest = maxf(deepest, pairs[i].distance_to(pairs[i + 1]))
		check(box.carried != null or deepest < 0.01, "side %d: set down by another bag, it is inside none (in by %.3f m)" % [k, deepest])
		if box.carried:
			box.carried.reparent(game.world)  # no room here: back on its own spot for the next side
			(box.carried as CollisionObject3D).collision_layer = box.CARRIABLES
			box.carried = null
