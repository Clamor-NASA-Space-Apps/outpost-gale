extends "res://addons/forge/test.gd"
## The play camera on its worst spots (Ravindu, 14 Nov: "whenever the camera hits an object behind it, the camera
## glitches ... we don't need to show the skeleton of the model ... camera never hits any object or glitch"):
## godot --headless --path . --fixed-fps 60 -s tests/camera_test.gd
## At each spot, with real keys: the view turned once round each way with the look keys, level, looking up and looking
## down, then the hero walked back, forth and sideways while the view keeps turning. On every frame the near plane's
## own sphere at the lens is clear of every solid and every thin thing (nothing is cut open), and the lens never moves
## more than STEP; it never changes its distance by more than POP (a cut-in), and it rests REST clear of every solid.
## POP is not asked while a pitch key is held: looking up swings the arm down onto the ground, and the lens then
## slides in along it as fast as the key turns it (h / sin(pitch): 0.3 m a frame at 20 degrees), which is the
## player's own move, in one glide; STEP still holds there.
## Then the view swept through everything a player can reach, yaw all the way round in steps of 15 degrees at each
## pitch (Ravindu, 15 Nov: "I can move the camera under the rover itself ... every single object, to pass through and
## see their internals"): on foot, the hero stood close against each thing of AGAINST, the lens is never inside or
## behind a solid; boarded, once the camera has settled, the lens is outside the rover's drawn box grown by OUT, ABOVE
## over the ground under it, and every value of the rig is a real number.
## `-- foot` or `-- drive` after the command runs only that sweep (`-- foot PIP "a cargo bag"`: only those things).

const REST := 0.15  # m from the lens to every solid once it has settled: tuning.json camera.clear, less a cast's skin
const POP := 0.2  # m the lens may come in or go out along its arm in a frame: feel_rate's 0.125, and 7 cm of a cut
const STEP := 0.45  # m the lens may move in a frame: a key turn swings a 5 m arm 0.2 m, the feelers add 0.125, a hurry 0.03;
# a look up slides it along the ground at up to 0.42
# [name, item or "" for the ground, where the hero stands (the item's space, or world x, z), yaw from the item's front]
const SPOTS := [
	["HAB 1, inside by the hatch", "hab1", Vector3(0.0, 0.3, -1.3), 0.0],
	["HAB 1, mid-room", "hab1", Vector3(0.3, 0.3, 0.6), 90.0],
	["HAB 1, outside its hatch", "hab1", Vector3(0.4, 0.0, -3.4), 180.0],
	["the storm shelter, in its doorway", "shelter", Vector3(0.0, 0.1, -1.5), 180.0],
	["the storm shelter, inside", "shelter", Vector3(0.6, 0.1, 0.4), 90.0],
	["along the shelter's bag wall", "shelter", Vector3(2.9, 0.0, 0.3), 0.0],
	["between the rover and HAB 1", "", Vector3(7.7, 0.0, 7.2), 90.0],
	["by HAB 1's wall and the oxygen maker", "", Vector3(-2.6, 0.0, 4.3), 0.0],
	["by the lamp post east of HAB 1", "", Vector3(5.0, 0.0, 3.6), 45.0],
]

# [name, item, the way the hero stands off its middle (the item's space)]: pressed against what a ray from there meets
const AGAINST := [
	["the rover's side", "rover", Vector3(1, 0, 0)],
	["the rover's back", "rover", Vector3(0, 0, 1)],
	["the rover's corner", "rover", Vector3(1, 0, -1)],
	["HAB 1's wall", "hab1", Vector3(1, 0, 0.4)],
	["HAB 1's tanks", "hab1", Vector3(0, 0, 1)],
	["the greenhouse's glass", "greenhouse", Vector3(1, 0, 0.3)],
	["the storm shelter", "shelter", Vector3(-1, 0, 0)],
	["a solar row", "wing1", Vector3(0, 0, 1)],
	["the oxygen maker", "oxygen", Vector3(1, 0, 0)],
	["the battery bank", "battery", Vector3(0, 0, -1)],
	["PIP", "pip", Vector3(1, 0, 0)],
	["a cargo bag", "bag1", Vector3(0, 0, 1)],
	["a lamp post", "lamp1", Vector3(1, 0, 0)],
	["the rover's charger", "charger", Vector3(1, 0, 0)],
]
const OUT := 0.2  # m the lens keeps from the rover's drawn box while it is driven
const ABOVE := 0.3  # m the lens keeps over the ground then
const TURN := 15  # degrees between the sweep's poses

var game: Node3D
var player: Node3D
var cam: Node3D
var down := {}
var space: PhysicsDirectSpaceState3D
var ball := PhysicsShapeQueryParameters3D.new()
var m := {}  # this spot's tallies


func _init() -> void:
	watchdog = 1500.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	player = game.player
	cam = player.cam
	space = game.world.get_world_3d().direct_space_state
	ball.shape = SphereShape3D.new()
	ball.exclude = cam.excluded
	game.pip.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE  # stood still, and still a solid to stand against
	game.pip.process_mode = Node.PROCESS_MODE_DISABLED  # it wanders: a robot driving through the test is not the camera's doing
	for it: Node in get_nodes_in_group("interactable"):
		if it.kind == "door" and not it.open:
			game.interactions.use(it)  # the doorways open, as in play
	await frames(60)
	var only := OS.get_cmdline_user_args()
	if "foot" in only or "drive" in only:
		if "foot" in only:
			for a: Array in AGAINST:
				if only.size() == 1 or a[0] in only:
					await against(a)
		if "drive" in only:
			await boarded()
		return true
	for s: Array in SPOTS:
		await spot(s)
	for a: Array in AGAINST:
		await against(a)
	await boarded()
	# what the feelers cost a physics tick by the lamp post, to weigh against the frame budget (skills/frame-budget):
	# printed, not checked
	if cam.has_method("_feelers"):
		var t0 := Time.get_ticks_usec()
		for i in 200:
			cam._feelers(player.body.global_position + Vector3.UP * 1.55, 4.2)
		print("  the feelers take %.0f us a tick outdoors" % ((Time.get_ticks_usec() - t0) / 200.0))
	return true


func spot(s: Array) -> void:
	var at: Vector3 = s[2]
	var yaw: float = s[3]
	if s[1] != "":
		var item: Node3D = game.world.items[s[1]]
		at = item.to_global(at)
		yaw += -rad_to_deg(item.global_rotation.y)
	else:
		at.y = game.world.height_at(at.x, at.z) + 0.05
	player.place(at, yaw)
	await frames(60)
	if not check(player.inside().is_empty(), "%s: the hero stands clear there (%s)" % [s[0], player.inside()]):
		return
	m = {"frames": 0, "lens": Vector3.INF, "dist": cam.dist, "step": 0.0, "pop": 0.0, "pop_at": "", "near": 0, "near_in": "", "thin": 0, "thin_in": "",
		"cut": 0, "cut_in": "", "still": 0}
	var room: bool = player.room != ""
	# round each way, level, then looking up, then down
	for pitch: Array in [[KEY_I, 0], [KEY_I, 24], [KEY_K, 48]]:
		await hold([pitch[0]], pitch[1])
		await hold([KEY_L], 170)
		await hold([KEY_J], 170)
		await hold([], 40)
	await hold([KEY_I], 24)
	# the hero moves while the view turns: back, forth and sideways
	for keys: Array in [[KEY_S, KEY_L], [KEY_W, KEY_L], [KEY_A, KEY_J], [KEY_D, KEY_J], [KEY_S], [KEY_W]]:
		await hold(keys, 70)
		await hold([], 40)
	print("  %-38s %s: step %.3f, pop %.3f (%s), %d frames cut %s, %d resting near a solid %s, %d in a thin thing %s" % [s[0], "room" if room else "open", m.step, m.pop, m.pop_at,
		m.cut, m.cut_in, m.near, m.near_in, m.thin, m.thin_in])
	check(m.cut == 0, "%s: the near plane never reaches a solid (%d of %d frames: %s)" % [s[0], m.cut, m.frames, m.cut_in])
	check(m.near == 0, "%s: settled, the lens rests %.2f m clear of every solid (%d frames nearer: %s)" % [s[0], REST, m.near, m.near_in])
	check(m.thin == 0, "%s: the near plane never reaches a thin thing (%d frames: %s)" % [s[0], m.thin, m.thin_in])
	check(m.pop <= POP, "%s: the lens never pops along its arm (%.3f m in a frame, at most %.2f; %s)" % [s[0], m.pop, POP, m.pop_at])
	check(m.step <= STEP, "%s: the lens never jumps (%.3f m in a frame, at most %.2f)" % [s[0], m.step, STEP])


## The hero stood close against a thing, the view swept through its whole range: the lens is never inside or behind
## a solid, never in a thin thing, and the rig stays real numbers.
func against(a: Array) -> void:
	var item: Node3D = game.world.items[a[1]]
	var dir: Vector3 = (item.global_basis * (a[2] as Vector3) * Vector3(1, 0, 1)).normalized()
	# walked up to it: a body as wide and tall as the hero comes in from 12 m out until it meets the thing
	var body := CylinderShape3D.new()
	body.radius = player.breadth / 2.0
	body.height = player.model.bounds.end.y - player.step
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = body
	q.collision_mask = cam.PROPS
	q.exclude = [player.body.get_rid()]
	var c := item.global_position
	var up: float = game.world.height_at(c.x, c.z) + player.step + body.height / 2.0
	var at := Vector3.INF
	for i in 6:  # past what stands between
		q.transform = Transform3D(Basis(), Vector3(c.x, up, c.z) + dir * 12.0)
		q.motion = -dir * 12.0
		var stop := q.transform.origin + q.motion * space.cast_motion(q)[0]
		q.transform = Transform3D(Basis(), stop - dir * 0.1)
		q.motion = Vector3.ZERO
		var met := space.intersect_shape(q, 8)
		if met.any(func(h: Dictionary) -> bool: return h.collider == item or item.is_ancestor_of(h.collider)):
			at = stop + dir * 0.03
			break
		if met.is_empty():
			break
		q.exclude += met.map(func(h: Dictionary) -> RID: return h.rid)
	# a thing lower than a step (a bag, PIP) or thinner than the body's skin (a post): where a ray at the shin meets it
	for h: float in ([0.4, 0.15, 0.9] if at == Vector3.INF else []):
		var to := Vector3(c.x, game.world.height_at(c.x, c.z) + h, c.z)
		var skip: Array[RID] = [player.body.get_rid()]
		for i in 6:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + dir * 12.0, to, cam.PROPS, skip))
			if hit.is_empty():
				break
			if hit.collider == item or item.is_ancestor_of(hit.collider):
				at = hit.position + dir * (body.radius + 0.03)
				break
			skip.append(hit.rid)
		if at != Vector3.INF:
			break
	if not check(at != Vector3.INF, "%s: something to stand against" % a[0]):
		return
	player.place(Vector3(at.x, game.world.height_at(at.x, at.z) + 0.05, at.z), rad_to_deg(atan2(-dir.x, dir.z)))
	await frames(40)
	if not check(player.inside().is_empty(), "%s: the hero stands beside it, in nothing (%s)" % [a[0], player.inside()]):
		return
	var r := await sweep(func() -> String:
		if cam.inside():
			return "in or behind a solid"
		ball.transform = Transform3D(Basis(), cam.lens.global_position)
		ball.shape.radius = cam._near_radius() - cam.arm.margin
		ball.collision_mask = cam.THIN
		var hit := space.intersect_shape(ball, 1)
		return "in the thin " + _name(hit[0].collider) if hit and hit[0].collider.name != &"feet" else "", 12, false)
	var p: Vector3 = player.body.global_position
	print("  against %-26s hero %.1f, %.1f: %d poses, %d frames wrong (%s)" % [a[0], p.x, p.z, r.poses, r.bad, r.first])
	check(r.bad == 0, "%s: with the view swept all round, the lens is never inside or behind a solid (%d frames: %s)" % [a[0], r.bad, r.first])
	check(r.nan == 0, "%s: every value of the rig is a real number (%d frames were not)" % [a[0], r.nan])


## Boarded, where the rover is parked and then backed up to HAB 1's wall (a solid a step behind it): through the whole
## pitch range the driving camera allows and all the way round, the settled lens is outside the rover's drawn box grown
## by OUT and ABOVE over the ground under it. And with the arm cut to nothing, as the worst obstacle would cut it, the
## lens is still outside that box on the next frame. A snap (a teleport) cuts its own arm before a frame is drawn.
func boarded() -> void:
	var rover: Node3D = game.world.items["rover"]
	var box := AABB()
	for mi: MeshInstance3D in rover.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = rover.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = box.merge(b) if box.has_volume() else b
	var gap := func() -> float:
		var l: Vector3 = rover.global_transform.affine_inverse() * cam.lens.global_position
		return l.distance_to(l.clamp(box.position, box.end))
	player.enter(rover)
	for where: String in ["in its bay", "backed up to HAB 1"]:
		if where != "in its bay":
			# its back (+Z) half a metre from the west wall, as cine.gd moves it on a trip
			var away: Vector3 = (game.world.items["hab1"] as Node3D).global_position + Vector3(-2.75 - box.end.z - 0.5, 0.0, 0.0)
			rover.v = 0.0
			rover.yaw = PI / 2.0
			rover._plane = Vector3.INF
			rover._apply(rover._pose(Vector3(away.x, 0.0, away.z), rover.yaw))
			await frames(1)
			cam.snap(rover.yaw)
			# straight behind it stands HAB 1: the snap itself cuts the arm, before any frame is drawn
			check(not cam.inside() and gap.call() >= OUT, "boarded %s: snapped behind it, the lens is in no solid at once (dist %.2f)" % [where, cam.dist])
		await frames(60)
		var r := await sweep(func() -> String:
			var lens: Vector3 = cam.lens.global_position
			var over: float = lens.y - game.world.height_at(lens.x, lens.z)
			if gap.call() < OUT:
				return "%.2f m from the rover's box, at %s in its space" % [gap.call(), (rover.global_transform.affine_inverse() * lens).snappedf(0.01)]
			return "%.2f m over the ground" % over if over < ABOVE else "", 45, true)
		print("  boarded %s: %d poses, pitch %.0f to %.0f, %d wrong (%s)" % [where, r.poses, r.lo, r.hi, r.bad, r.first])
		check(r.bad == 0, "boarded %s: settled, the lens is %.1f m outside the rover's box and %.1f m over the ground (%d of %d poses were not: %s)" % [where, OUT, ABOVE, r.bad, r.poses, r.first])
		check(r.nan == 0, "boarded %s: every value of the rig is a real number (%d frames were not)" % [where, r.nan])
		var cut := 0
		for turn in range(0, 360, 45):
			cam.yaw = rover.yaw + deg_to_rad(turn)
			await frames(30)
			cam.dist = 0.0
			await frames(1)
			cut += int(gap.call() < OUT)
		check(cut == 0, "boarded %s: with the arm cut to nothing the lens is still outside the rover's box (%d of 8 headings were not)" % [where, cut])
	player.exit()
	await frames(10)


## The view through every pose a player can reach: each pitch from the lowest to the highest the camera allows now,
## and at each the yaw all the way round, `hold` frames a pose. `wrong` says what is wrong with the lens ("" for
## nothing), asked on every frame, or with `settled` only on a pose's last one.
func sweep(wrong: Callable, hold: int, settled: bool) -> Dictionary:
	var r := {"poses": 0, "bad": 0, "first": "", "nan": 0}
	cam.look(0.0, 1000.0)
	r.lo = roundf(rad_to_deg(cam.pitch))
	cam.look(0.0, -1000.0)
	r.hi = roundf(rad_to_deg(cam.pitch))
	var yaw0: float = cam.yaw
	var pitches: Array = range(int(r.lo), int(r.hi), TURN) + [int(r.hi)]
	for pitch: int in pitches:
		for turn in range(0, 360, TURN):
			cam.yaw = yaw0 + deg_to_rad(turn)
			cam.pitch = deg_to_rad(pitch)
			r.poses += 1
			for f in hold:
				await frames(1)
				var real: bool = [cam.dist, cam.yaw, cam.pitch, cam.lift, cam.slope, cam.late].all(is_finite) and not is_nan(cam.soft) and not is_nan(cam.tail) \
					and cam.global_position.is_finite() and cam.lens.global_position.is_finite() and cam.lens.global_basis.is_finite()
				r.nan += int(not real)
				if settled and f < hold - 1:
					continue
				var what: String = wrong.call() if real else "not a number"
				if what != "":
					r.bad += 1
					if r.first == "":
						r.first = "%s, yaw %d, pitch %d, dist %.2f" % [what, turn, pitch, cam.dist]
	return r


## `keys` held for `n` frames, the camera read on each.
func hold(keys: Array, n: int) -> void:
	for k: Key in keys:
		_key(k, true)
	for i in n:
		await frames(1)
		_read()
	for k: Key in keys:
		_key(k, false)


func _read() -> void:
	var lens: Vector3 = cam.lens.global_position
	m.frames += 1
	if m.lens != Vector3.INF:
		m.step = maxf(m.step, lens.distance_to(m.lens))
	m.lens = lens
	if absf(cam.dist - m.dist) > m.pop and not down.get(KEY_I, false) and not down.get(KEY_K, false):
		m.pop = absf(cam.dist - m.dist)
		m.pop_at = "%.2f to %.2f m, yaw %.0f, pitch %.0f, hero %.1f, %.1f, keys %s" % [m.dist, cam.dist, rad_to_deg(cam.yaw), rad_to_deg(cam.pitch),
			player.body.global_position.x, player.body.global_position.z, down.keys().filter(func(k: Key) -> bool: return down[k]).map(func(k: Key) -> String: return OS.get_keycode_string(k))]
	m.dist = cam.dist
	ball.transform = Transform3D(Basis(), lens)
	ball.shape.radius = cam._near_radius() - cam.arm.margin  # the near plane's own sphere: inside it, a thing is cut open
	ball.collision_mask = cam.SOLIDS
	var hit := space.intersect_shape(ball, 1)
	if hit:
		m.cut += 1
		if m.cut_in == "":
			m.cut_in = "%s, yaw %.0f, pitch %.0f, dist %.2f" % [_name(hit[0].collider), rad_to_deg(cam.yaw), rad_to_deg(cam.pitch), cam.dist]
	# at rest: no key held for a third of a second (a cut is eased over the last of the arm's sphere, note_clear)
	m.still = m.still + 1 if down.values().all(func(on: bool) -> bool: return not on) else 0
	ball.shape.radius = REST
	hit = space.intersect_shape(ball, 1)
	if hit and m.still > 20:
		m.near += 1
		if m.near_in == "":
			m.near_in = "%s, yaw %.0f, pitch %.0f, dist %.2f" % [_name(hit[0].collider), rad_to_deg(cam.yaw), rad_to_deg(cam.pitch), cam.dist]
	ball.shape.radius = cam._near_radius() - cam.arm.margin
	ball.collision_mask = cam.THIN
	hit = space.intersect_shape(ball, 1)
	if hit and hit[0].collider.name != &"feet":  # a lamp's `feet` is the hull round its tripod (world.gd), mostly air
		m.thin += 1
		if m.thin_in == "":
			m.thin_in = "%s, yaw %.0f, dist %.2f" % [_name(hit[0].collider), rad_to_deg(cam.yaw), cam.dist]


func _name(n: Node) -> String:
	return str(n.get_path()).get_slice("/World/", 1)


## A real key, sent only when it changes.
func _key(code: Key, on: bool) -> void:
	if down.get(code, false) == on:
		return
	down[code] = on
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = on
	send(e)
