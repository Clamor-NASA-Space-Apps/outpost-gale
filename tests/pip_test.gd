extends "res://addons/forge/test.gd"
## PIP wanders on its own and keeps out of the way:
## godot --headless --path . --fixed-fps 60 -s tests/pip_test.gd
## A minute alone: it moves, reaches several stops, never overlaps a solid, a bag, the rover or the hero, never
## enters a building or parks in a doorway, and nothing but PIP moves (no game state). Then the hero: in its path
## (it waits), standing still nearby (it comes over and looks up), coming close (a beep).

const SOLID := 2 | 4 | 8 | 16 | 64  # statics, thin, hero, vehicles, carriables (CONTRACTS.md)


func _init() -> void:
	watchdog = 480.0


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var world: Node3D = game.get_node("World")
	var player: Node3D = game.get_node("Player")
	var pip: Node3D = world.items.get("pip")
	if not check(pip != null and pip.has_method("state_text"), "the sandbox drives PIP with sandbox/pip.gd"):
		return true
	_prints(world, float(pip.p.track_depth))
	var sounds: Array[String] = []
	pip.sound.connect(func(what: String, _at: Vector3) -> void: sounds.append(what))
	var keys: Array = game.render_game_to_text().keys()
	var others := {}  # every other mover's place: PIP must change nothing but itself
	for id: String in world.items:
		if id != "pip":
			others[id] = (world.items[id] as Node3D).global_transform
	# a minute alone: the hero far away at the patch edge
	var edge: Dictionary = world.landmark("edge")
	player.place(edge.pos, edge.yaw)
	var start: Vector3 = pip.global_position
	var far := 0.0
	var hits := 0
	var inside := 0
	var parked_in_door := 0
	var states := {}
	for i in 60 * 60:
		await frames(1)
		far = maxf(far, pip.global_position.distance_to(start))
		states[pip.state] = true
		hits += 1 if _overlaps(pip) else 0
		var at := Vector2(pip.global_position.x, pip.global_position.z)
		for r: Array in pip._rooms:
			var l: Vector3 = r[0] * Vector3(at.x, 0.0, at.y)
			var b: AABB = r[1].grow(-float(pip.p.room_margin))
			inside += 1 if l.x > b.position.x and l.x < b.end.x and l.z > b.position.z and l.z < b.end.z else 0
		if pip.state == "look":
			for d: Vector2 in pip._doors:
				parked_in_door += 1 if at.distance_to(d) < float(pip.p.door_clear_m) * 0.9 else 0
	var stops := {}
	for s: String in pip.reached:
		stops[s] = true
	check(far > 3.0, "PIP moves on its own (%.1f m from where it started)" % far)
	check(stops.size() >= 2 and pip.reached.size() + pip.passed >= 4, "it reaches several points in 60 s (stops %s, via points %d)" % [pip.reached, pip.passed])
	check(states.has("look") and states.has("drive"), "it drives and stops to look (%s)" % [states.keys()])
	check(hits == 0, "it never overlaps a solid, a bag, the rover or the hero (%d frames)" % hits)
	check(inside == 0, "it never enters a building (%d frames)" % inside)
	check(parked_in_door == 0, "it never parks in a doorway (%d frames)" % parked_in_door)
	check(sounds.has("pip_go"), "a beep when it sets out (%s)" % [sounds])
	var moved := []
	for id: String in others:
		if not (world.items[id] as Node3D).global_transform.is_equal_approx(others[id]):
			moved.append(id)
	check(moved.is_empty(), "nothing but PIP moved: no game state (%s)" % [moved])
	check(game.render_game_to_text().keys() == keys, "render_game_to_text keeps its keys")
	check(not _wheels_still(pip), "its wheels turn as it drives")

	# the hero steps into its path: it waits, never touching
	var waited := false
	for tries in 4:
		await _until(pip, func() -> bool: return pip.state == "drive" and pip.v > 0.3, 20.0)
		var ahead: Vector3 = pip.global_position - pip.global_basis.z * 1.2
		player.place(Vector3(ahead.x, world.height_at(ahead.x, ahead.z) + 0.05, ahead.z), 0.0)
		for i in 60:
			await frames(1)
			waited = waited or pip.state == "wait"
			hits += 1 if _overlaps(pip) else 0
		if waited:
			break
	check(waited, "a hero in its path makes it wait")
	check(hits == 0, "and it never touches the hero")
	# the hero stands still nearby: it comes over, looks up, beeps
	player.place(edge.pos, edge.yaw)
	await _until(pip, func() -> bool: return pip.state == "look", 30.0)
	var near: Vector3 = pip.global_position + Vector3(-0.626, 0.0, -3.951)
	if pip._no_go(Vector2(near.x, near.z)):
		near = pip.global_position - Vector3(-0.626, 0.0, -3.951)
	pip._greet_cool = 0.0
	pip._hello_cool = 0.0
	sounds.clear()
	player.place(Vector3(near.x, world.height_at(near.x, near.z) + 0.05, near.z), 0.0)
	var greeted := await _until(pip, func() -> bool: return pip.state == "greet", 25.0)
	var gap: float = Vector2(pip.global_position.x - near.x, pip.global_position.z - near.z).length()
	check(greeted, "a hero standing still nearby gets a visit")
	check(gap > 1.0 and gap < 2.5, "it parks beside the hero, not on it (%.2f m)" % gap)
	check(sounds.has("pip_hello"), "and beeps hello (%s)" % [sounds])
	check(pip._near, "its head is on the hero")
	await _lead(world, player, pip)
	await _sprint(world, player, pip)
	await _cluster(world, player, pip)
	await _wedged(world, player, pip)
	await _bags(world, player, pip, false)
	await _bags(world, player, pip, true)
	return true


## A kid sprinting after a leading PIP: it hurries too, a little faster than the hero's hurry. ponytail: the closest
## gap is printed, not checked: a sprint from 3.5 m back still closes to about 0.8 m once while PIP gets going.
func _sprint(world: Node3D, player: Node3D, pip: Node3D) -> void:
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).pip
	pip.release()
	await frames(2)
	var from := Vector3(9.07, world.height_at(9.07, -3.462), -3.462)
	pip.yaw = deg_to_rad(9.0)  # facing east before the base turned -99 deg (tools/rotate_base.py)
	pip._place(from, pip.yaw)
	player.place(Vector3(9.618, world.height_at(9.618, -0.005) + 0.05, -0.005), 171.0)
	await frames(5)
	var arrived := [false]
	pip.arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	pip.order(Vector3(-0.166, 0.0, -20.223), Vector3.INF, false, Vector3(b.lead_wait_m, b.lead_resume_m, b.lead_near_m))
	action(&"move_forward", true)
	action(&"hurry", true)
	var gap := INF
	var top := 0.0
	for i in 60 * 40:
		await frames(1)
		if arrived[0]:
			break
		var d := Vector2(pip.global_position.x - player.body.global_position.x, pip.global_position.z - player.body.global_position.z)
		player.cam.yaw = atan2(-d.x, -d.y)
		if i > 60 and Vector2(pip.global_position.x - 20.0, pip.global_position.z - 3.0).length() > 4.0:  # not its parking stop
			gap = minf(gap, d.length())
		top = maxf(top, pip.v)
	action(&"move_forward", false)
	action(&"hurry", false)
	print("  sprint: closest %.2f m, PIP top %.2f m/s (hero hurry %.2f)" % [gap, top, player.hurry])
	check(top > player.hurry, "leading a sprinting kid, PIP goes faster than the hero's hurry (%.2f m/s)" % top)
	pip.release()


## Inside the cargo bag cluster by HAB 1 (14 Nov playtest: PIP wedged among the bags for good, "doesn't follow me"):
## from the free spot nearest the bags' middle, orders to [2, 12], to the hero's side and past the far side of the
## bags all arrive, never given up.
func _cluster(world: Node3D, player: Node3D, pip: Node3D) -> void:
	pip.release()
	await frames(2)
	var mid := Vector3.ZERO
	for id: String in ["bag1", "bag2", "bag3"]:
		mid += (world.items[id] as Node3D).global_position / 3.0
	var hero := Vector3(9.618, 0.0, -0.005)
	player.place(Vector3(hero.x, world.height_at(hero.x, hero.z) + 0.05, hero.z), -9.0)
	var far := mid + (mid - Vector3(0.0, mid.y, 0.0)).normalized() * 2.5  # beyond the bags, seen from HAB 1
	for to: Vector3 in [Vector3(11.539, 0.0, -3.853), hero + Vector3(-0.188, 0.0, -1.185), far]:
		var start := Vector3.INF
		for r in range(0, 12):  # the free spot nearest the middle of the bags, facing out between them
			for k in 8:
				var at := mid + Vector3(sin(TAU * k / 8.0), 0.0, cos(TAU * k / 8.0)) * r * 0.1
				pip.yaw = TAU * k / 8.0
				pip._place(Vector3(at.x, world.height_at(at.x, at.z), at.z), pip.yaw)
				if not _overlaps(pip):
					start = at
					break
			if start != Vector3.INF:
				break
		await frames(2)
		var arrived := [false]
		pip.arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
		var gave: int = pip.gave_up
		pip.order(to)
		var hits := 0
		var t := 0
		while t < 60 * 30 and not arrived[0]:
			await frames(1)
			t += 1
			hits += 1 if _overlaps(pip) else 0
		check(arrived[0], "from inside the bags (%.1f, %.1f) PIP gets to (%.1f, %.1f) in %.1f s (at %.1f, %.1f)" % [start.x, start.z, to.x, to.z, t / 60.0, pip.global_position.x, pip.global_position.z])
		check(pip.gave_up == gave, "and never gives up on it (%d)" % (pip.gave_up - gave))
		check(hits == 0, "and never sinks into a bag on the way out (%d frames)" % hits)
	pip.release()


## Boxed in on purpose: a bag snug on either side and one ahead, no room to turn. It backs out and gets round.
func _wedged(world: Node3D, player: Node3D, pip: Node3D) -> void:
	pip.release()
	await frames(2)
	var at := Vector3(8.0, 0.0, -7.5)  # open, level ground north-east of HAB 1 (since the base turned to the sunrise, 14 Nov: the turned spot sat on a slope PIP could not back up)
	at.y = world.height_at(at.x, at.z)
	pip.yaw = deg_to_rad(-171.0)  # facing -X before the base turned -99 deg
	pip._place(at, pip.yaw)
	player.place(Vector3(13.075, world.height_at(13.075, -0.552) + 0.05, -0.552), 0.0)
	var keep := {}
	var fwd := Vector3(0.156, 0.0, 0.988)
	var dirs := {"bag1": fwd, "bag2": Vector3(0.988, 0.0, -0.156), "bag3": Vector3(-0.988, 0.0, 0.156)}
	for id: String in dirs:
		var bag: Node3D = world.items[id]
		keep[id] = bag.global_transform
		var off := 1.5
		while off > 0.0:  # slide it in until it touches PIP, then 3 cm back
			var p: Vector3 = at + dirs[id] * off
			bag.global_position = Vector3(p.x, world.height_at(p.x, p.z), p.z)
			await frames(1)
			if _overlaps(pip):
				p = at + dirs[id] * (off + 0.03)
				bag.global_position = Vector3(p.x, world.height_at(p.x, p.z), p.z)
				break
			off -= 0.02
	await frames(2)
	var to := at + fwd * 5.0
	var arrived := [false]
	pip.arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	pip.order(to)
	var reversed := false
	var t := 0
	while t < 60 * 60 and not arrived[0]:
		await frames(1)
		t += 1
		reversed = reversed or pip.state == "reverse"
	check(reversed, "boxed in by bags, PIP backs out")
	check(arrived[0], "and gets round them to its spot in %.1f s (at %.1f, %.1f)" % [t / 60.0, pip.global_position.x, pip.global_position.z])
	pip.release()
	for id: String in keep:
		(world.items[id] as Node3D).global_transform = keep[id]
	await frames(2)


## From the cargo bags by HAB 1 to the solar farm, the bags where world.json puts them (or one dropped right on the
## straight way, `dropped`): PIP plans round them and gets there, never giving up (14 Nov playtest: stuck at the bags,
## "follow me" for ever).
func _bags(world: Node3D, player: Node3D, pip: Node3D, dropped: bool) -> void:
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).pip
	var from := Vector3(5.707, world.height_at(5.707, -2.321), -2.321)  # the bags stop, where the Sol 1 lift leaves PIP
	var to := Vector3(-0.166, 0.0, -20.223)  # the solar stop
	if dropped:
		var bag: Node3D = world.items.bag1
		var mid := from.lerp(to, 0.3)
		bag.global_position = Vector3(mid.x, world.height_at(mid.x, mid.z), mid.z)
		await frames(2)
	pip.release()
	await frames(2)
	pip.yaw = atan2(-(to.x - from.x), -(to.z - from.z))
	pip._place(from, pip.yaw)
	player.place(Vector3(7.07, world.height_at(7.07, -0.107) + 0.05, -0.107), 171.0)
	await frames(5)
	var arrived := [false]
	pip.arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	var gave: int = pip.gave_up
	pip.order(to, Vector3.INF, false, Vector3(b.lead_wait_m, b.lead_resume_m, b.lead_near_m))
	var hits := 0
	var held := false
	for i in 60 * 70:
		await frames(1)
		if arrived[0]:
			break
		hits += 1 if _overlaps(pip) else 0
		var d := Vector2(pip.global_position.x - player.body.global_position.x, pip.global_position.z - player.body.global_position.z)
		player.cam.yaw = atan2(-d.x, -d.y)
		if d.length() > 2.5 and not held:
			held = true
			action(&"move_forward", true)
		elif d.length() < 2.0 and held:
			held = false
			action(&"move_forward", false)
	if held:
		action(&"move_forward", false)
	var how := "one dropped on the way" if dropped else "in their spots"
	check(arrived[0], "PIP leads from the bags to the solar farm, bags %s (at %.1f, %.1f)" % [how, pip.global_position.x, pip.global_position.z])
	check(pip.gave_up == gave, "and never gives up on it (%d)" % (pip.gave_up - gave))
	check(hits == 0, "and never drives into a bag (%d frames)" % hits)
	pip.release()


## Held by the beats (data/beats.json pip numbers): PIP leads at the hero's pace, a kid walking right after it never
## comes within 1.5 m, it never gives up, and a kid walking into it parked makes it back off, never stepped on.
func _lead(world: Node3D, player: Node3D, pip: Node3D) -> void:
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).pip
	pip.back_m = float(b.back_m)
	pip.back_s = float(b.back_s)
	pip.back_lead = float(b.back_lead_s)
	var from := Vector3(9.07, world.height_at(9.07, -3.462), -3.462)  # a via point beside HAB 1, the solar stop 20 m on (turned with the base, 14 Nov)
	pip.yaw = deg_to_rad(9.0)  # facing east before the base turned -99 deg (tools/rotate_base.py)
	pip._place(from, pip.yaw)
	player.place(Vector3(9.539, world.height_at(9.539, -0.498) + 0.05, -0.498), 171.0)
	var arrived := [false]
	pip.arrived.connect(func() -> void: arrived[0] = true, CONNECT_ONE_SHOT)
	var gave: int = pip.gave_up
	pip.order(Vector3(-0.166, 0.0, -20.223), Vector3.INF, false, Vector3(b.lead_wait_m, b.lead_resume_m, b.lead_near_m))
	var gap := INF
	var hits := 0
	var speeds: Array[float] = []
	var held := false
	for i in 60 * 60:
		await frames(1)
		if arrived[0]:
			break
		var d := Vector2(pip.global_position.x - player.body.global_position.x, pip.global_position.z - player.body.global_position.z)
		gap = minf(gap, d.length())
		hits += 1 if _overlaps(pip) else 0
		if pip.state == "drive" and d.length() < 3.0 and i > 120:
			speeds.append(pip.v)
		# a kid walking straight after PIP, never stopping short of it
		player.cam.yaw = atan2(-d.x, -d.y)
		if not held:
			held = true
			action(&"move_forward", true)
	action(&"move_forward", false)
	var mean := 0.0
	for v in speeds:
		mean += v / speeds.size()
	print("  lead: closest %.2f m, pace %.2f m/s over %d frames" % [gap, mean, speeds.size()])
	check(arrived[0], "PIP leads all the way to its spot (at %.1f, %.1f)" % [pip.global_position.x, pip.global_position.z])
	check(pip.gave_up == gave, "it never gives up on the lead (%d)" % (pip.gave_up - gave))
	check(gap > 1.5, "a kid walking right after it never comes within 1.5 m (%.2f m)" % gap)
	check(mean > 0.9 and mean < 1.2, "it leads at the hero's walking pace (%.2f m/s)" % mean)
	check(hits == 0, "and never overlaps anything on the way (%d frames)" % hits)
	# parked: a kid walking straight into it from the open side
	await frames(60)
	var at: Vector3 = pip.global_position
	var start := Vector3.INF
	for k in 8:
		var dir := Vector3(sin(TAU * k / 8.0), 0.0, cos(TAU * k / 8.0))
		var p := at + dir * 6.0
		if pip._clear(at, p):
			start = Vector3(p.x, world.height_at(p.x, p.z) + 0.05, p.z)
			break
	if not check(start != Vector3.INF, "open ground round PIP's spot"):
		return
	player.place(start, 0.0)
	await frames(10)
	gap = INF
	var backed := false
	action(&"move_forward", true)
	for i in 60 * 8:
		await frames(1)
		var d := Vector2(pip.global_position.x - player.body.global_position.x, pip.global_position.z - player.body.global_position.z)
		gap = minf(gap, d.length())
		backed = backed or pip.state == "back"
		player.cam.yaw = atan2(-d.x, -d.y)
	action(&"move_forward", false)
	print("  parked: closest %.2f m" % gap)
	check(backed, "a kid walking into a parked PIP makes it back off")
	check(gap > 0.8, "and the kid never steps on it (%.2f m)" % gap)
	pip.release()


## PIP's hull sunk more than a touch (pip.TOUCH, 5 mm, and 1 mm of slack) into anything it must keep out of. A hull
## 3% smaller measured this before: it shrinks about the hull's origin on its belly, so a pebble touching the belly
## counted as an overlap while a corner could sink a centimetre (14 Nov).
## Wheel prints in the ground's trail map (world/terrain.gd mark()): PIP's as faint as its data says, every print's
## sides faded over more than a pixel, and two tracks crossing no deeper than one (13 Nov playtest: PIP's tracks deep
## and thick, hard dark bands where they crossed).
func _prints(world: Node3D, depth: float) -> void:
	var t: Node3D = world.terrain
	var at: Vector2 = t.trail_centre + Vector2(5.0, 5.0)
	var px: float = t.TRAIL_MPX
	var read := func(x: float, z: float) -> float:
		return t.trail.get_pixel(posmod(floori(x / px), t.trail_px), posmod(floori(z / px), t.trail_px)).r
	world.mark(Vector3(at.x, 0.0, at.y), 0.0, "wheel", 0.08, depth)
	var deepest := 0.0
	for i in range(-6, 7):
		for k in range(-6, 7):
			deepest = maxf(deepest, read.call(at.x + i * px, at.y + k * px))
	check(deepest > 0.0 and deepest <= depth + 1.0 / 255.0, "a PIP print is %.2f deep at most (%.3f)" % [depth, deepest])
	var b: Vector2 = at + Vector2(1.0, 0.0)
	world.mark(Vector3(b.x, 0.0, b.y), 0.0, "wheel", 0.3, 1.0)
	var step := 0.0
	for i in range(-8, 8):
		step = maxf(step, absf(read.call(b.x + (i + 1) * px, b.y) - read.call(b.x + i * px, b.y)))
	check(step < 0.75, "a wheel print's sides fade over more than a pixel (largest step %.2f)" % step)
	var c: Vector2 = at + Vector2(-1.0, 0.0)
	world.mark(Vector3(c.x, 0.0, c.y), 0.0, "wheel", 0.3, 0.5)
	world.mark(Vector3(c.x, 0.0, c.y), 90.0, "wheel", 0.3, 0.5)
	check(absf(read.call(c.x, c.y) - 0.5) < 0.01, "two tracks crossing are as deep as one, not deeper (%.2f of 0.5)" % read.call(c.x, c.y))


func _overlaps(pip: Node3D) -> bool:
	var cs: CollisionShape3D = pip._shape
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.collision_mask = SOLID
	q.exclude = [pip.get_rid()]
	q.transform = pip._at(pip.global_position, pip.yaw) * cs.transform
	var pts := pip.get_world_3d().direct_space_state.collide_shape(q, 8)
	for i in range(0, pts.size(), 2):
		if pts[i].distance_to(pts[i + 1]) > pip.TOUCH + 0.001:
			return true
	return false


func _wheels_still(pip: Node3D) -> bool:
	for w: Node3D in pip._wheels:
		if not w.basis.is_equal_approx(Basis()):
			return false
	return true


func _until(_pip: Node3D, ok: Callable, seconds: float) -> bool:
	for i in int(60 * seconds):
		if ok.call():
			return true
		await frames(1)
	return ok.call()
