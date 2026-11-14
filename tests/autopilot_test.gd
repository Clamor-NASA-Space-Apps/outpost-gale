extends "res://addons/forge/test.gd"
## The rover's autopilot (sandbox/rover_pilot.gd), used as a kid uses it: aboard with E, a mark set as the map sets
## it, and the rover drives itself there round everything in the way.
## godot --headless --path . --fixed-fps 60 -s tests/autopilot_test.gd

var game: Node3D
var world: Node3D
var player: Node3D
var rover: Node3D
var hud: Control
var pilot: RefCounted
var hull: CollisionShape3D


func _init() -> void:
	watchdog = 900.0  # game seconds: two drives across the patch at 2.8 m/s


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	world = game.world
	player = game.player
	hud = game.hud
	pilot = player.pilot
	rover = world.items.rover
	hull = rover.find_children("*", "CollisionShape3D", false, false)[0]
	var park: Vector3 = rover.global_position
	var reactor: Vector3 = world.landmark("reactor").pos
	var cfg: Dictionary = game.tuning.rover.autopilot
	check(_touching().is_empty(), "parked, the rover touches nothing (%s)" % [_touching()])

	hud.set_mark(_xz(reactor))
	await frames(120)
	check(not pilot.driving() and rover.global_position.distance_to(park) < 0.01, "nobody aboard: a mark moves nothing")

	await _board()
	check(player.vehicle == rover, "E at the hatch: the kid is aboard")
	await frames(90)
	var said: String = hud.snapshot().subtitle
	check(pilot.hinted and said == hud.line("hint.autopilot") and hud.snapshot().bubble.keys == 1, "PIP teaches the pin, with the M key (said '%s')" % said)
	check(said.split(" ").size() <= 8, "in at most 8 words")
	check(not pilot.driving() and absf(rover.v) < 0.01, "the old mark, set on foot, starts nothing aboard")

	# a cinematic has the rover (as a trip sets cine.beat): a mark does nothing, then or after
	game.cine.beat = "trip"
	hud.set_mark(_xz(reactor))
	await frames(60)
	check(not pilot.driving() and rover.global_position.distance_to(park) < 0.01, "during a cinematic a mark moves nothing")
	game.cine.beat = ""
	await frames(60)
	check(not pilot.driving() and rover.global_position.distance_to(park) < 0.01, "nor once it is over")

	# the Sol 2 trip: from the parking spot to the reactor, round the solar rows
	hud.open_map()
	hud.set_mark(_xz(reactor))
	await frames(30)
	check(not pilot.driving() and absf(rover.v) < 0.01, "with the map open it waits")
	hud.close_map()
	await frames(2)
	check(pilot.driving() and hud.snapshot().alert == "Autopilot on", "the map shut: it takes the wheel and says so (alert '%s')" % hud.snapshot().alert)
	print("plan: %.0f ms, %s" % [pilot.plan_ms, pilot.path])
	check(pilot.path.size() > 1, "the straight line crosses the solar rows: the way has corners (%d points)" % pilot.path.size())
	var run := await _ride(150.0)
	print("reactor trip: %.1f s, top %.2f m/s, longest brake for something %.2f s" % [run.s, run.top, run.blocked_s])
	check(run.done and run.s < 110.0, "it arrives at the reactor in time (%.1f s)" % run.s)
	check(run.touched.is_empty(), "and touches nothing on the way (%s)" % [run.touched])
	check(run.blocked_s < 1.0, "never held up (%.2f s)" % run.blocked_s)
	check(run.past == 0.0, "never past the bound")
	check(run.top <= rover.top + 0.001, "never faster than a kid drives (%.2f m/s)" % run.top)
	check(_flat(rover.global_position, reactor) < 4.48, "within a rover length of the mark (%.1f m)" % _flat(rover.global_position, reactor))
	check(absf(rover.v) < 0.05 and hud.snapshot().alert == "We're here!", "standing, the wheel handed back with a word (alert '%s')" % hud.snapshot().alert)
	check(hud.mark == null, "the HUD's mark is reached and gone, as on foot")

	# off the patch: as far as the ground goes
	hud.set_mark(Vector2(-260.0, reactor.z))
	await frames(2)
	run = await _ride(60.0)
	check(run.done and run.past == 0.0 and rover.global_position.x < -175.0, "a mark off the patch ends at its edge (x %.1f)" % rover.global_position.x)
	check(hud.snapshot().alert == "Autopilot off" and hud.mark != null, "and says it got as near as it can; the mark stays")

	# a move key takes the wheel
	hud.set_mark(_xz(park))
	await frames(600)
	check(pilot.driving() and rover.v > 1.0, "under way again (%.1f m/s)" % rover.v)
	var yaw: float = rover.yaw
	action(&"move_left")
	await frames(2)
	check(not pilot.driving() and hud.snapshot().alert == "Autopilot off", "a move key hands the wheel back at once")
	await frames(60)
	check(angle_difference(yaw, rover.yaw) > deg_to_rad(15), "and the rover obeys it (turned %.0f deg left)" % rad_to_deg(angle_difference(yaw, rover.yaw)))
	action(&"move_left", false)
	await frames(240)
	check(not pilot.driving() and absf(rover.v) < 0.01 and hud.mark != null, "no key: it stands, the mark kept, the autopilot off")

	# the mark set again starts it; cleared, it lets go
	hud.set_mark(_xz(park))
	await frames(300)
	check(pilot.driving() and rover.v > 1.0, "the mark set again: it drives")
	hud.set_mark(null)
	await frames(2)
	check(not pilot.driving() and hud.snapshot().alert == "Autopilot off", "the mark cleared: the wheel is handed back")
	await frames(240)
	check(absf(rover.v) < 0.01, "and the rover stands")

	# a mark inside HAB 1: the nearest spot outside it
	var hab: Vector3 = world.items.hab1.global_position
	hud.set_mark(_xz(hab))
	await frames(2)
	run = await _ride(150.0)
	print("plan: %.1f ms" % pilot.plan_ms)
	print("to HAB 1: %.1f s, ends %.1f m from its middle" % [run.s, _flat(rover.global_position, hab)])
	check(run.done and run.touched.is_empty() and run.blocked_s < 1.0, "a mark inside HAB 1: it drives up and stops, touching nothing (%s, held %.2f s)" % [run.touched, run.blocked_s])
	check(_flat(rover.global_position, hab) < 14.0 and absf(rover.v) < 0.05, "beside the habitat, standing (%.1f m from its middle)" % _flat(rover.global_position, hab))
	check(hud.snapshot().alert in ["We're here!", "Autopilot off"], "and says so (alert '%s')" % hud.snapshot().alert)

	# getting out ends it
	hud.set_mark(_xz(world.landmark("lander").pos))
	await frames(300)
	check(pilot.driving(), "off to the lander")
	action(&"interact")
	action(&"interact", false)
	await frames(3)
	var left: Vector3 = rover.global_position
	check(player.vehicle == null and not pilot.driving(), "E: the kid is out and the autopilot off")
	await frames(120)
	check(rover.global_position.distance_to(left) < 0.01, "an empty rover never drives")
	await _board()
	await frames(120)
	check(player.vehicle == rover and not pilot.driving() and rover.global_position.distance_to(left) < 0.01, "back aboard: it waits for a new mark (aboard %s, moved %.2f m)" % [player.vehicle == rover, rover.global_position.distance_to(left)])
	check(cfg.arrive_m < 4.48, "it stops within a rover length (tuning arrive_m)")
	return true


## Rides until the autopilot lets go (or `limit` seconds): what the rover touched, how long anything held it up, how
## far it got past the bound, its top speed.
func _ride(limit: float) -> Dictionary:
	var out := {"done": false, "s": 0.0, "touched": {}, "blocked_s": 0.0, "past": 0.0, "top": 0.0}
	var held := 0
	for i in int(limit * 60.0):
		await physics_frame
		if not pilot.driving():
			out.done = true
			break
		out.s = (i + 1) / 60.0
		for n: String in _touching():
			out.touched[n] = true
		held = held + 1 if rover.blocked != "" else 0
		out.blocked_s = maxf(out.blocked_s, held / 60.0)
		out.past = maxf(out.past, world.past(rover.global_position, float(world.data.bound.reach)))
		out.top = maxf(out.top, absf(rover.v))
	out.touched = out.touched.keys()
	return out


## Everything solid the rover's hull is in now: buildings, solar rows, posts, PIP, bags. Rocks and low pads are its
## wheels' to climb (rover.gd), so they are left out.
func _touching() -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = hull.shape
	q.transform = hull.global_transform
	q.collision_mask = 2 | 4 | 16 | 64
	q.exclude = [rover.get_rid()]
	var out: Array = []
	for h: Dictionary in rover.get_world_3d().direct_space_state.intersect_shape(q):
		if not (h.collider as CollisionObject3D).collision_layer & 256:
			out.append(str(world.get_path_to(h.collider)))
	return out


## To the rover's hatch and in with E (interact_test's stance). Where the rover stopped on a slope the aim can miss
## its hatch, and aim is interact_test's job: then in as sols_test's bot goes.
func _board() -> void:
	var door: Node3D = null
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if it.kind == "rover":
			door = it
	var from: Vector3 = rover.exit_point()
	var to: Vector3 = door.nearest(from + Vector3.UP * game.interactions.hold) - from
	game.place(Vector3(from.x, 0, from.z), rad_to_deg(atan2(to.x, -to.z)))
	await frames(3)
	action(&"interact")
	action(&"interact", false)
	await frames(3)
	if player.vehicle == null:
		game.interactions.use(door)
		await frames(3)


func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _flat(a: Vector3, b: Vector3) -> float:
	return _xz(a).distance_to(_xz(b))
