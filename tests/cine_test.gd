extends "res://addons/forge/test.gd"
## The rover-trip skip and the launch run to their end and give the cameras back:
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
		shots[cine.shot] = true
		if cine.shot == "trip_drive":
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
		shots[cine.shot] = true
		if cine.shot == "launch_window":
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
	game.queue_free()
	return true
