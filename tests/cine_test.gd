extends "res://addons/forge/test.gd"
## The rover-trip skip, the launch and the tutorial shots run to their end and give the cameras back:
## godot --headless --path . --fixed-fps 60 -s tests/cine_test.gd

const Cine := preload("res://cine/cine.gd")
const SITE := "lander"


func _init() -> void:
	watchdog = 420.0


func until(cine: Node, s: float) -> bool:
	var left := s
	while cine.busy() and left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()
	return not cine.busy()


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	var cine: Node = game.get("cine")
	if cine == null:  # until the root wires it (sandbox.gd)
		cine = Cine.new()
		game.add_child(cine)
		cine.setup(game)
	var world: Node3D = game.world
	var player: Node3D = game.player
	var rover: Node3D = world.items.rover

	# the trip: from the rover to a landmark, the title card on the way, the hero still at the wheel
	player.enter(rover)
	await frames(5)
	var lens: Camera3D = root.get_camera_3d()
	var shots := {}
	var arrived := []
	cine.arrived.connect(func(l: String) -> void: arrived.append(l))
	# ponytail: a landmark on the base's patch; a field site (site_*_rover) also needs the root's safety net to use
	# world.bound(p), or it pulls the rover home the next physics step
	cine.trip_to(SITE, {"sol": 12, "km": 14})
	await frames(2)
	check(root.get_camera_3d() == cine.cam, "the trip films from the cine camera")
	var from: Vector3 = rover.global_position
	var left := 20.0
	while cine.busy() and left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()
		shots[cine.beat] = true
		if cine.beat == "trip_drive":
			check(not cine._title.visible, "no title while driving")
	check(not cine.busy(), "the trip ends")
	check(shots.has("trip_drive") and shots.has("trip_title"), "the trip drives off, then shows its title (%s)" % [shots.keys()])
	check(arrived == [SITE], "arrived(%s) fires (%s)" % [SITE, arrived])
	var l: Dictionary = world.landmark(SITE)
	var at: Vector3 = rover.global_position
	check(Vector2(at.x - l.pos.x, at.z - l.pos.z).length() < 0.1, "the rover stands at the landmark (%.2f m off)" % Vector2(at.x - l.pos.x, at.z - l.pos.z).length())
	check(from.distance_to(l.pos) > 50.0, "it came from far away")
	check(player.vehicle == rover, "the hero is still at the wheel")
	check(root.get_camera_3d() == lens, "the play camera is back after the trip")
	check(not Input.is_action_pressed(&"move_forward"), "the throttle is let go")
	await frames(30)
	check(rover.speed() < 0.05, "the rover waits at the destination (%.2f m/s)" % rover.speed())
	cine.trip_to("nowhere")
	check(not cine.busy(), "an unknown landmark starts nothing")
	player.exit()
	await frames(5)

	# the launch: out, the liftoff, the window, then the sandbox as it was
	var hero_at: Vector3 = player.body.global_position
	lens = root.get_camera_3d()
	var item: Node3D = world.items.get("mav")
	var rocket: Node3D = item.find_child("ascent", true, false) as Node3D if item else null
	var pad: Vector3 = rocket.global_position if rocket else Vector3.ZERO
	var cells := world.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("cell_") and n.visible)
	var launched := [false]
	cine.launched.connect(func() -> void: launched[0] = true)
	shots.clear()
	var high := 0.0
	cine.launch()
	left = 40.0
	while cine.busy() and left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()
		shots[cine.beat] = true
		if cine.beat == "launch_window":
			high = maxf(high, cine.cam.global_position.y - world.height_at(cine.cam.global_position.x, cine.cam.global_position.z))
			check(not player.visible, "the hero is aboard, not on the ground")
	check(not cine.busy() and launched[0], "the launch runs to its end and fires launched")
	check(shots.has("launch_out") and shots.has("launch_window"), "an outside shot, then the window (%s)" % [shots.keys()])
	check(high > 100.0, "from the window the base falls away (%.0f m up)" % high)
	check(root.get_camera_3d() == lens, "the play camera is back after the launch")
	check(player.visible and player.process_mode != Node.PROCESS_MODE_DISABLED, "the hero is back")
	check(player.body.global_position.distance_to(hero_at) < 0.2, "where they boarded")
	if rocket:
		check(rocket.global_position.distance_to(pad) < 0.01, "the ascent stage is back on its pad")
	else:
		await frames(2)
		check(world.get_node_or_null("mav_flight") == null, "the flying copy is gone")
	check(cells.all(func(n: Node3D) -> bool: return n.visible), "every merged cell is drawn again")

	# the tutorial shots: the hero just out of HAB 1's door facing out, PIP called over for its own
	cine.stand_for_dawn()
	# the opening's pre-dawn wake (data/beats.json), as the beats leave it: pinned
	var clock: Node = game.clock
	# the shot machinery from the hour Sol 1 starts at (cine.dawn_hour()), pinned as a beat would pin it
	clock.pinned = true
	clock.set_hour(clock.hours - clock.hour() + cine.dawn_hour())
	clock.refresh()
	await shoot(game, cine, "dawn_reveal", 1.0)  # the play camera's own distance: a turn, not a pull-out
	check(clock.pinned and not clock.driven, "the clock is given back pinned, as the beats left it")
	var h_end: float = clock.hour()
	await shoot(game, cine, "dawn_reveal", 1.0)  # again, from a clock already past the rise
	check(is_equal_approx(clock.hour(), h_end), "a clock past the sunrise is never turned back (%.3f to %.3f)" % [h_end, clock.hour()])
	await mouse_shot(game, cine, "look_around")
	var pip: Node3D = game.pip
	if pip:
		var ahead: Vector3 = player.body.global_position + Vector3(1.0, 0.0, 6.0)
		pip.order(ahead, player.body.global_position)
		await shoot(game, cine, "focus_pip", 0.0)
		pip.release()
	var done := []
	cine.shot_done.connect(func(n: String) -> void: done.append(n))
	cine.shot("nothing")
	await frames(3)
	check(done == ["nothing"] and not cine.busy(), "an unknown shot starts nothing and still reports done (%s)" % [done])
	await drive_offs(game, cine)
	game.queue_free()
	return true


## A trip's drive-off is driven, not a held throttle (sandbox/rover_pilot.gd film()): parked nose on to HAB 1, to a
## solar row or to PIP, the rover is seen to pull out and drive away the way the trip lies, touching nothing; the same
## on the way home from the site, where it arrives facing the outcrop. Nothing steers once the trip is over.
func drive_offs(game: Node3D, cine: Node) -> void:
	var world: Node3D = game.world
	var player: Node3D = game.player
	var rover: Node3D = world.items.rover
	var pip: Node3D = game.pip
	player.enter(rover)
	await frames(3)
	var bearing := float(world.data.sites.mercou.bearing)

	# nose on to HAB 1: up to its wall on the throttle, as a kid parks it
	var hab: Vector3 = world.items.hab1.global_position
	var parked := false
	for deg: float in [300.0, 240.0, 120.0, 60.0, 0.0, 180.0]:
		var dir := Vector3(sin(deg_to_rad(deg)), 0.0, -cos(deg_to_rad(deg)))
		_put(rover, hab + dir * 14.0, -dir)
		await frames(2)
		if not _touching(rover, 1.0).is_empty():
			continue
		parked = await _nose_on(rover) and _ahead(rover).begins_with("hab1")
		if parked:
			break
	if check(parked, "the rover is parked nose on to HAB 1's wall ('%s' ahead)" % _ahead(rover)):
		var run: Dictionary = await _trip(game, cine, "site_mercou_rover", hab)
		_judge(run, "from HAB 1's wall")
		check(absf(angle_difference(deg_to_rad(bearing), run.goal)) < deg_to_rad(30), "its way out lies toward the site (bearing %.0f of %.0f)" % [rad_to_deg(run.goal), bearing])

		# home from the site, where the trip set it down facing the outcrop
		var outcrop: Vector3 = world.items.mercou.global_position
		var home: Vector3 = world.landmark("rover").pos - rover.global_position
		var facing: Vector3 = -rover.global_basis.z
		check(facing.dot(outcrop - rover.global_position) > 0.0 and facing.dot(home) < 0.0, "at the site the rover faces the outcrop, its back to the way home")
		run = await _trip(game, cine, "rover", outcrop)
		_judge(run, "home from Mont Mercou")
		var off: float = rad_to_deg(absf(angle_difference(atan2(home.x, -home.z), run.heading)))
		check(off < 30.0, "it heads the way home lies as the picture fades (%.0f deg off)" % off)

	# nose on to a solar row
	var wing: Vector3 = world.items.wing1.global_position
	_put(rover, wing + Vector3(9.0, 0.0, 4.0), Vector3(-1.0, 0.0, 0.0))
	await frames(2)
	# its panels turn with the sun, so a ray from the nose may pass under them: stopped as by a wall, at the row
	if check(await _nose_on(rover) and absf(rover.global_position.x - wing.x) < 6.0, "the rover is parked nose on to a solar row (%.1f m from its middle)" % absf(rover.global_position.x - wing.x)):
		_judge(await _trip(game, cine, "site_mercou_rover", wing), "from a solar row")

	# PIP standing right ahead
	_put(rover, Vector3(45.0, 0.0, -45.0), Vector3(-1.0, 0.0, 0.0))
	if pip:
		pip.process_mode = Node.PROCESS_MODE_DISABLED  # it holds still, as when it waits for the hero
		var at: Vector3 = rover.global_position + Vector3(-3.4, 0.0, 0.0)
		pip.global_position = Vector3(at.x, world.height_at(at.x, at.z), at.z)
		await frames(2)
		_judge(await _trip(game, cine, "site_mercou_rover", pip.global_position), "from behind PIP")
		pip.process_mode = Node.PROCESS_MODE_INHERIT


func _put(rover: Node3D, at: Vector3, facing: Vector3) -> void:
	rover.yaw = atan2(-facing.x, -facing.z)
	rover.v = 0.0
	rover._apply(rover._pose(Vector3(at.x, 0.0, at.z), rover.yaw))


## Forward on the throttle until something stops the rover: true when it stands against a wall.
func _nose_on(rover: Node3D) -> bool:
	var by := ""
	action(&"move_forward")
	for i in 900:
		await physics_frame
		by = rover.blocked
		if by != "" and absf(rover.v) < 0.01:
			break
	action(&"move_forward", false)
	await frames(30)
	return by == "wall"


## What stands right before the rover's nose (its path under the world), "" when nothing within 2 m.
func _ahead(rover: Node3D) -> String:
	var from: Vector3 = rover.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, from - rover.global_basis.z * 4.3, 2 | 4 | 16 | 64)
	q.exclude = [rover.get_rid()]
	var hit := rover.get_world_3d().direct_space_state.intersect_ray(q)
	return str(rover.get_parent().get_path_to(hit.collider)) if not hit.is_empty() else ""


## The solids the rover's hull is in (buildings, rows, posts, PIP, bags; not what its wheels climb), the hull shrunk
## to `k` of its size so that standing against a wall is not being in it.
func _touching(rover: Node3D, k := 0.97) -> Array:
	var hull: CollisionShape3D = rover.find_children("*", "CollisionShape3D", false, false)[0]
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = hull.shape
	q.transform = hull.global_transform.scaled_local(Vector3.ONE * k)
	q.collision_mask = 2 | 4 | 16 | 64
	q.exclude = [rover.get_rid()]
	var out: Array = []
	for h: Dictionary in rover.get_world_3d().direct_space_state.intersect_shape(q):
		if not (h.collider as CollisionObject3D).collision_layer & 256:
			out.append(str(rover.get_parent().get_path_to(h.collider)))
	return out


## One trip from where the rover stands, watched every physics frame of its drive-off: what it touched, how long
## anything held it up, how far it got in the first three seconds and by the fade, from `thing` too.
func _trip(game: Node3D, cine: Node, landmark: String, thing: Vector3) -> Dictionary:
	var rover: Node3D = game.world.items.rover
	var pilot: RefCounted = game.player.pilot
	var from: Vector3 = rover.global_position
	var out := {"touched": {}, "held": 0.0, "early": 0.0, "moved": 0.0, "away": 0.0, "heading": 0.0, "goal": 0.0, "s": 0.0, "ended": false, "keys": [], "idle": false, "at": 0.0}
	var held := 0
	var far0 := Vector2(thing.x - from.x, thing.z - from.z).length()
	cine.trip_to(landmark, {"sol": 9, "km": 8.8})
	if not pilot.path.is_empty():
		var end: Vector2 = pilot.path[-1] - Vector2(from.x, from.z)
		out.goal = atan2(end.x, -end.y)
	for i in 60 * 40:
		await physics_frame
		if not cine.busy():
			out.ended = true
			break
		if cine.beat != "trip_drive":
			continue
		out.s += 1.0 / 60.0
		var p: Vector3 = rover.global_position
		for n: String in _touching(rover):
			out.touched[n] = true
		held = held + 1 if rover.blocked != "" else 0
		out.held = maxf(out.held, held / 60.0)
		out.moved = Vector2(p.x - from.x, p.z - from.z).length()
		if out.s <= 3.0:
			out.early = out.moved
		out.away = Vector2(thing.x - p.x, thing.z - p.z).length() - far0
		var nose: Vector3 = -rover.global_basis.z
		out.heading = atan2(nose.x, -nose.z)
	await frames(30)
	out.touched = out.touched.keys()
	out.keys = [&"move_forward", &"move_back", &"move_left", &"move_right"].filter(func(a: StringName) -> bool: return Input.is_action_pressed(a))
	out.idle = not pilot.on and not pilot.driving() and absf(rover.v) < 0.05
	var l: Vector3 = game.world.landmark(landmark).pos
	out.at = Vector2(rover.global_position.x - l.x, rover.global_position.z - l.z).length()
	return out


func _judge(run: Dictionary, what: String) -> void:
	check(run.early > 0.5, "%s: the rover moves in the shot's first seconds (%.1f m in 3 s)" % [what, run.early])
	check(run.moved > 6.0 and run.away > 3.0, "%s: it drives off, away from what it stood at (%.1f m, %.1f m further from it, in %.1f s)" % [what, run.moved, run.away, run.s])
	check(run.touched.is_empty(), "%s: touching nothing (%s)" % [what, run.touched])
	check(run.held < 1.0, "%s: never held up (%.2f s)" % [what, run.held])
	check(run.ended and run.at < 0.1, "%s: the trip ends at its landmark (%.2f m off)" % [what, run.at])
	check(run.keys.is_empty() and run.idle, "%s: nothing steers after it (keys %s, idle %s)" % [what, run.keys, run.idle])


## One shot from the settled play camera: it ends, says so once, never puts the camera in or through a solid or
## under the ground, freezes the hero (and PIP unless it films it moving), and hands back the play camera's own pose.
## A mouse shot: the play camera itself goes round once, low and pitched up, with the hero standing and input locked,
## and ends where it started.
func mouse_shot(game: Node3D, cine: Node, name: String) -> void:
	var player: Node3D = game.player
	var fc: Node3D = player.cam
	await frames(120)
	var lens: Camera3D = root.get_camera_3d()
	var yaw0: float = fc.yaw
	var pitch0: float = fc.pitch
	var feet: Vector3 = player.body.global_position
	var allowed: Array = player.allowed.duplicate()
	var done := []
	cine.shot_done.connect(func(n: String) -> void: done.append(n))
	var c: Dictionary = cine.cfg.shots[name]
	cine.shot(name)
	var turned := 0.0
	var last: float = fc.yaw
	var top := -INF
	var step := 0.0
	var left: float = float(c.hold_s) + float(c.turn_s) + 3.0
	while cine.busy() and left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()
		if not cine.busy():
			break  # it ended this frame: the input is the player's again
		check(root.get_camera_3d() == lens, "%s turns the play camera itself" % name)
		check(player.allowed == ["none"], "%s locks the player's input" % name)
		step = maxf(step, absf(fc.yaw - last))
		turned += fc.yaw - last
		last = fc.yaw
		top = maxf(top, fc.pitch)
	check(not cine.busy() and done == [name], "%s ends and says so once (%s)" % [name, done])
	check(absf(rad_to_deg(turned) - float(c.turn_deg)) < 1.0, "%s goes once round (%.1f deg)" % [name, rad_to_deg(turned)])
	check(rad_to_deg(step) < float(c.turn_deg) / float(c.turn_s) / 60.0 * 2.0, "%s turns smoothly (at most %.2f deg a frame)" % [name, rad_to_deg(step)])
	check(absf(rad_to_deg(top) - float(c.pitch_deg)) < 1.0, "%s looks up %.0f deg on the way (%.1f)" % [name, float(c.pitch_deg), rad_to_deg(top)])
	check(absf(wrapf(fc.yaw - yaw0, -PI, PI)) < 0.01 and absf(fc.pitch - pitch0) < 0.01, "%s ends facing where it started" % name)
	check(player.body.global_position.distance_to(feet) < 0.05, "%s: the hero stands still" % name)
	check(player.allowed == allowed, "%s gives the input back" % name)


func shoot(game: Node3D, cine: Node, name: String, far: float) -> void:
	var player: Node3D = game.player
	var world: Node3D = game.world
	await frames(120)  # the lens settles behind the hero
	var lens: Camera3D = root.get_camera_3d()
	check(lens == player.cam.lens, "%s starts from the play camera" % name)
	var before := lens.global_transform
	var done := []
	cine.shot_done.connect(func(n: String) -> void: done.append(n))
	var space := world.get_world_3d().direct_space_state
	var ball := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	ball.shape = sphere
	ball.exclude = [player.body.get_rid()]
	var c: Dictionary = cine.cfg.shots[name]
	var total: float = c.back_s
	for k: Dictionary in c.keys:
		total += 0.0 if k.get("cut", false) else float(k.s)
	cine.shot(name)
	var last: Vector3 = lens.global_position
	var worst := ""
	var away := 0.0
	var left := total + 3.0
	# a sunrise shot: the sun's centre under the rim at the start, over it by the middle (from its sunrise key)
	var rise: Dictionary = c.get("sunrise", {})
	var eye: Vector3 = player.body.global_position + Vector3.UP * 1.9  # near the shot's eye
	var h0: float = game.clock.hour()
	var rising: bool = not rise.is_empty() and cine.sun_clear(h0, eye) < float(rise.get("peek_deg", 0.0)) - 0.5
	var clear := [INF, -INF]
	var cue := {}  # the music cues heard during the shot  # the sun over the rim: at the first frame, at the middle
	while cine.busy() and left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()
		if not cine.busy():
			break  # it ended this frame: the play camera is back
		var at: Vector3 = cine.cam.global_position
		check(root.get_camera_3d() == cine.cam, "%s films from the cine camera" % name)
		ball.transform = Transform3D(Basis(), at)
		var ray := PhysicsRayQueryParameters3D.create(last, at)
		ray.exclude = ball.exclude
		if worst == "" and not space.intersect_shape(ball, 1).is_empty():
			worst = "inside a solid at %s (t %.2f)" % [at, cine.t]
		elif worst == "" and last.distance_to(at) > 0.001 and not space.intersect_ray(ray).is_empty():
			worst = "through a solid from %s to %s (t %.2f)" % [last, at, cine.t]
		elif worst == "" and at.y < world.height_at(at.x, at.z) + 0.3:
			worst = "under the ground at %s" % at
		last = at
		cue[game.audio.cue] = true
		away = maxf(away, at.distance_to(before.origin))
		if rising and clear[0] == INF:
			clear[0] = cine.sun_clear(game.clock.hour(), eye)
		if rising and clear[1] == -INF and cine.t >= float(rise.break_s) + 0.1:
			clear[1] = cine.sun_clear(game.clock.hour(), eye)
		check(player.process_mode == Node.PROCESS_MODE_DISABLED, "%s freezes the hero" % name)
		if game.pip and not c.get("pip_moves", false):
			check(game.pip.process_mode == Node.PROCESS_MODE_DISABLED, "%s freezes PIP" % name)
	check(not cine.busy(), "%s ends within %.1f s" % [name, total + 3.0])
	if rising:
		var peek := float(rise.get("peek_deg", 0.0))
		check(clear[0] < peek - 1.0 and absf(clear[1] - peek) < 0.35, "%s: the sun is under the rim at the start and peeks over it at break_s (%.2f, %.2f deg)" % [name, clear[0], clear[1]])
		check(game.clock.hour() > h0, "%s runs the clock forward (%.3f to %.3f h)" % [name, h0, game.clock.hour()])
	check(worst == "", "%s keeps the camera clear: %s" % [name, worst])
	check(away > far, "%s goes out (%.1f m, wants over %.0f)" % [name, away, far])
	await frames(3)
	check(done == [name], "%s fires shot_done once (%s)" % [name, done])
	check(root.get_camera_3d() == lens, "%s gives the play camera back" % name)
	var off := lens.global_transform.origin.distance_to(before.origin)
	var turn := lens.global_basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion())
	check(off < 0.01 and turn < 0.01, "%s leaves the play camera where it was (%.3f m, %.3f rad)" % [name, off, turn])
	check(player.process_mode != Node.PROCESS_MODE_DISABLED, "%s lets the hero go" % name)
	if name == "dawn_reveal":
		check(not game.audio.started or cue.has("dawn"), "the dawn cue plays (%s)" % [cue.keys()])
