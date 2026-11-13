extends "res://addons/forge/test.gd"
## The rover-trip skip, the launch and the tutorial shots run to their end and give the cameras back:
## godot --headless --path . --fixed-fps 60 -s tests/cine_test.gd

const Cine := preload("res://cine/cine.gd")
const SITE := "lander"


func _init() -> void:
	watchdog = 240.0


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
	var wake: String = Array(JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).opening[0].do).filter(
		func(c: String) -> bool: return c.begins_with("clock:"))[0]
	clock.pinned = true
	clock.set_hour(clock.hours - clock.hour() + float(wake.get_slice(":", 1)))
	clock.refresh()
	await shoot(game, cine, "dawn_reveal", 1.0)  # the play camera's own distance: a turn, not a pull-out
	check(clock.pinned and not clock.driven, "the clock is given back pinned, as the beats left it")
	var h_end: float = clock.hour()
	await shoot(game, cine, "dawn_reveal", 1.0)  # again, from a clock already past the rise
	check(is_equal_approx(clock.hour(), h_end), "a clock past the sunrise is never turned back (%.3f to %.3f)" % [h_end, clock.hour()])
	await shoot(game, cine, "look_around", 1.0)  # a pan from beside the hero
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
	game.queue_free()
	return true


## One shot from the settled play camera: it ends, says so once, never puts the camera in or through a solid or
## under the ground, freezes the hero (and PIP unless it films it moving), and hands back the play camera's own pose.
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
