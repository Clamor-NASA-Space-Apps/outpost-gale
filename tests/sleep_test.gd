extends "res://addons/forge/test.gd"
## The sleep time-lapse (design/plans/next-lanes.md section 3): godot --headless --path . --fixed-fps 60 -s tests/sleep_test.gd
## The bed spot opens the picker and the clock waits; Night drives only the look clock to the fixed 06:30 wake with the
## drone shot, PIP frozen, the shadows reaching further and the probes held; then the hero wakes standing in the middle of HAB 1,
## the clock given back. A nap from a pinned 13:00 ends 20 minutes on and stays pinned. Nothing counts (hard rule 1).
## The lapse itself (15 Nov): the sun moves on every frame with no step much larger than the rest, and the night ends
## with the sun in the drone's frame, over the skyline it sees, wherever the base is turned; the drone is in no solid.

const Cine := preload("res://cine/cine.gd")
const HouseStyle := preload("res://addons/forge/house_style.gd")

var game: Node3D
var cine: Node


func _init() -> void:
	watchdog = 240.0


## Waits for `sig` at most `s` seconds of game time; true when it came.
func within(sig: Signal, s: float, args: int) -> bool:
	var got := [false]
	var on := (func() -> void: got[0] = true).unbind(args)
	sig.connect(on, CONNECT_ONE_SHOT)
	var left := s
	while not got[0] and left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()
	if sig.is_connected(on):
		sig.disconnect(on)
	return got[0]


func idle(s: float) -> void:
	var left := s
	while left > 0.0:
		await process_frame
		left -= root.get_process_delta_time()


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	cine = game.get("cine")
	if cine == null:  # until the root wires it (sandbox.gd)
		cine = Cine.new()
		game.add_child(cine)
		cine.setup(game)
	var clock: Node = game.clock
	var player: Node3D = game.player
	var pip: Node = game.pip
	var audio: Node = game.audio
	var keys: Array = cine.state().keys()
	check(keys == ["cine"] and cine.state().cine.keys() == ["shot", "t", "picker"], "cine state is the shot only, no game state (%s)" % [cine.state()])

	# 22:00, unpinned, the hero at the berth: the prompt says Sleep
	clock.pinned = false
	clock.set_hour(22.0)
	clock.refresh()
	var hab: Node3D = game.world.items.hab1
	var bed: Dictionary = game.world.data.uses.hab1.filter(func(r: Dictionary) -> bool: return r.kind == "bed")[0]
	var stand: Transform3D = hab.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(bed.stand[2])), Vector3(bed.stand[0], 0.42, bed.stand[1]))
	var face := -stand.basis.z
	player.place(stand.origin, -rad_to_deg(atan2(-face.x, -face.z)))
	player.cam.pitch = deg_to_rad(-30.0)
	await frames(30)
	var st: Dictionary = game.render_game_to_text()
	check(st.player.room == "hab1", "the berth's stand point is inside HAB 1 (%s)" % st.player.room)
	check(String(st.interaction.prompt).ends_with("Sleep"), "at the berth the prompt says Sleep (%s)" % st.interaction.prompt)

	# a sol's tasks first (14 Nov playtest: the bed skipped whole sols): at the start of Sol 2 the bed says why not and
	# opens nothing; once only the rest is left, it opens
	var beats: Node = game.beats
	var said: Array[String] = []
	beats.line.connect(func(id: String, _o: Dictionary) -> void: said.append(id))
	beats.start_sol(2)
	await frames(2)
	game.interactions.interact()
	await frames(2)
	check(not cine.picker.visible and not cine.busy(), "the bed opens no picker before the sol's tasks are done")
	check(said.has(beats.NOT_YET) and beats.beat.get("id", "") == "wake", "PIP says why, and the day stays on its step (%s)" % [said])
	beats._start(beats.beats.find_custom(func(b: Dictionary) -> bool: return b.id == "day_done"))
	await frames(2)
	game.interactions.interact()
	await frames(2)
	check(cine.picker.visible, "the bed opens once only the rest is left")
	beats.skip()  # the rest of this test is the time-lapse alone
	cine.picker._cancel()  # "Not now"
	player.place(stand.origin, -rad_to_deg(atan2(-face.x, -face.z)))  # Sol 2's wake moved nothing, but PIP may block
	await frames(10)

	# a door left open: the bed is refused, PIP says to close it and the waypoint is on the door; shut, the bed works
	said.clear()
	game.interactions.set_door("hab1", true)
	await frames(2)
	game.interactions.interact()
	await frames(2)
	check(not cine.picker.visible and not cine.busy(), "HAB 1's door open: the bed opens no picker")
	check(said == ["need.door"] and game.hud.objective == "door", "PIP says to close it, the waypoint on the door (%s, %s)" % [said, game.hud.objective])
	game.interactions.set_door("hab1", false)
	await idle(3.0)
	check(game.hud.objective != "door", "the door shut: its waypoint goes (%s)" % game.hud.objective)

	# E: the picker opens and the clock waits
	game.interactions.interact()
	await frames(2)
	check(cine.picker.visible and cine.busy(), "E on the berth opens the sleep picker")
	var h0: float = clock.hour()
	await idle(1.0)
	check(absf(clock.hour() - h0) < 0.001, "the clock waits while the picker is open (%.3f -> %.3f)" % [h0, clock.hour()])

	# Night, by a tap on its card
	var redraws: int = clock.probe_redraws
	var sun: DirectionalLight3D = cine._sun()
	var reach := sun.directional_shadow_max_distance
	var got := []
	cine.slept.connect(func(k: StringName, h: float) -> void: got.append([k, h]))
	cine.show_card.connect(func(l: Dictionary) -> void: got.append(l))
	var card: Button = cine.picker.cards[0]
	tap(card.get_global_rect().get_center())
	await idle(1.0)
	check(cine.beat == "sleep_drone", "Night starts the drone shot (%s)" % cine.beat)
	check(audio.cue == "sleep", "the sleep cue plays (%s)" % audio.cue)
	check(pip == null or pip.process_mode == Node.PROCESS_MODE_DISABLED, "PIP is frozen for the lapse")
	check(clock.driven, "the cine drives the look clock")
	check(sun.directional_shadow_max_distance >= 60.0, "the shadows reach the drone shot (%.0f m)" % sun.directional_shadow_max_distance)
	check(root.get_camera_3d() == cine.cam, "the drone camera is the one in use")
	# the end of the night as the drone sees it, read as `slept` fires (the wake moves the camera a moment later)
	var end := {}  # filled in place: a lambda holds its own copy of a local, but the same dictionary
	cine.slept.connect(func(_k: StringName, _h: float) -> void:
		var cam: Camera3D = cine.cam
		var to_sun: Vector3 = HouseStyle.sun_at(clock._C, clock.hour())
		var at := cam.global_position + to_sun * 1000.0
		var ray := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + to_sun * 300.0)
		end.merge({"behind": cam.is_position_behind(at), "at": cam.unproject_position(at) / root.get_visible_rect().size,
			"clear": cine.sun_clear(clock.hour(), cam.global_position),
			"hidden": not game.world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),
			"hab": cam.unproject_position(hab.global_position) / root.get_visible_rect().size}), CONNECT_ONE_SHOT)
	# the lapse frame by frame, as the clock handed the sun to the sky: the frames on which it saw the hour move
	var steps: Array[float] = []
	var was_sun: Vector3 = clock.sun
	var was_h: float = clock._seen
	var looks: int = clock.looks
	for i in 900:
		if got.size() > 0:
			break
		await process_frame
		if clock._seen != was_h:
			steps.append(rad_to_deg(was_sun.angle_to(clock.sun)) if clock.sun != was_sun else 0.0)
		was_sun = clock.sun
		was_h = clock._seen
	check(got.size() > 0, "the lapse ends within its 9 s cap")
	var by_size := steps.duplicate()
	by_size.sort()
	if check(steps.size() > 200, "the lapse ran the clock on %d frames" % steps.size()):
		check(by_size[0] > 0.0, "the sun moved on every frame of the lapse (it stood still on %d of %d)" % [steps.count(0.0), steps.size()])
		check(by_size[-1] < by_size[by_size.size() / 2] * 2.0, "no frame moves the sun more than twice the median (%.3f, median %.3f deg)" % [by_size[-1], by_size[by_size.size() / 2]])
		check(clock.looks - looks > steps.size() * 0.8, "the sky's colour follows on most frames, not at look_hz (%d looks in %d frames)" % [clock.looks - looks, steps.size()])
	if check(not end.is_empty(), "the night's end was seen"):
		check(not end.behind and Rect2(0.05, 0.05, 0.9, 0.9).has_point(end.at), "the night ends with the sun in the drone's frame (at %.2f, %.2f of it)" % [end.at.x, end.at.y])
		check(end.clear > 0.5 and not end.hidden, "over the skyline the drone sees, behind nothing (%.1f deg over it)" % end.clear)
		check(Rect2(0.0, 0.0, 1.0, 1.0).has_point(end.hab), "with HAB 1 in the frame (at %.2f, %.2f)" % [end.hab.x, end.hab.y])
	check(absf(clock.hour() - 6.5) < 0.05, "a night ends at the fixed 06:30 wake (%.2f)" % clock.hour())
	check(got.size() > 0 and got[0][0] == &"night" and absf(got[0][1] - (30.5 - h0)) < 0.01, "slept(night, hours to 06:30) fires (%s from %.2f)" % [got, h0])
	check(not clock.driven and not clock.pinned, "the clock is given back as it was: running, not pinned")
	check(pip == null or pip.process_mode != Node.PROCESS_MODE_DISABLED, "PIP moves again")
	check(is_equal_approx(sun.directional_shadow_max_distance, reach), "the shadow range is back (%.0f m)" % sun.directional_shadow_max_distance)
	check(await within(cine.show_card, 5.0, 1) or got.size() > 1, "show_card fires at the wake")
	while cine.busy():
		await process_frame
	await idle(1.0)
	st = game.render_game_to_text()
	check(clock.probe_redraws - redraws <= 2, "the probes redraw at most twice for the whole night (%d)" % (clock.probe_redraws - redraws))
	check(st.player.room == "hab1", "the hero wakes in HAB 1 (%s)" % st.player.room)
	check(st.cam.first > 0.99 and not st.cam.inside, "the wake hands over to first person, the lens in no solid (%.2f)" % st.cam.first)
	check(root.get_camera_3d() == player.cam.lens, "the play camera is back")
	check(player.process_mode != Node.PROCESS_MODE_DISABLED, "the hero moves again")
	# the wake (15 Nov playtest: woken in a corner, inside the donning bench, and the first step threw the hero across
	# the room): standing in the middle of HAB 1 facing the hatch, in nothing, and a second of W walks it there smoothly
	var woke: Vector3 = hab.to_local(player.body.global_position)
	var hatch: Vector3 = hab.to_global(Vector3(cine.cfg.sleep.hatch[0], 0.0, cine.cfg.sleep.hatch[1])) - player.body.global_position
	check(Vector2(woke.x, woke.z).length() < 1.0 and player.on_floor and player.inside().is_empty(),
			"the hero wakes standing in the middle of HAB 1, in nothing (%s in its space, in %s)" % [woke, player.inside()])
	check(absf(wrapf(atan2(-hatch.x, -hatch.z) - player.yaw, -PI, PI)) < deg_to_rad(5.0) and absf(wrapf(player.cam.yaw - player.yaw, -PI, PI)) < deg_to_rad(5.0) and absf(player.cam.pitch) < deg_to_rad(2.0),
			"facing the hatch, the view level behind its eyes (yaw %.0f, view %.0f, pitch %.1f deg)" % [rad_to_deg(player.yaw), rad_to_deg(player.cam.yaw), rad_to_deg(player.cam.pitch)])
	action(&"move_forward", true)
	var last: Vector3 = player.body.global_position
	var worst := 0.0
	for i in 60:
		await physics_frame
		worst = maxf(worst, player.body.global_position.distance_to(last))
		last = player.body.global_position
	action(&"move_forward", false)
	var went: Vector3 = hab.to_local(last) - woke
	# at the worn-out pace too (player.weak: a night can end thirsty and hungry, and the walk is then 0.6 of itself)
	check(worst < 0.1 and went.z < -0.3 and absf(went.x) < 0.3, "a second of W walks it toward the hatch, no jump (%.3f m the largest step in a frame, gone %s, weak %.2f)" % [worst, went, player.weak])
	check(audio._dawn, "the next door opened plays the dawn cue")
	check(audio.cue != "sleep", "the sleep cue stopped on the cut")
	# the drone's whole path is in the open: no solid at the camera, and well over the ground
	var ball := PhysicsShapeQueryParameters3D.new()
	ball.shape = SphereShape3D.new()
	ball.shape.radius = 0.5
	var in_solid := 0
	var lowest := INF
	for i in 21:
		cine.drone(i / 20.0)
		var eye: Vector3 = cine.cam.global_position
		ball.transform = Transform3D(Basis(), eye)
		in_solid += int(not game.world.get_world_3d().direct_space_state.intersect_shape(ball, 1).is_empty())
		lowest = minf(lowest, eye.y - game.world.height_at(eye.x, eye.z))
	check(in_solid == 0 and lowest > 3.0, "the drone is in no solid on its way (%d of 21 points), %.1f m over the ground at its lowest" % [in_solid, lowest])

	# a nap from a pinned 13:00: 20 minutes on, and it stays pinned there
	clock.pinned = true
	clock.set_hour(13.0)
	clock.refresh()
	cine.sleep(&"nap")
	check(await within(cine.slept, 8.0, 2), "a nap's lapse ends at its 4 s floor")
	check(absf(clock.hour() - 13.333) < 0.02, "a nap from 13:00 ends at 13:20 (%.3f)" % clock.hour())
	while cine.busy():
		await process_frame
	await idle(1.0)
	check(clock.pinned and not clock.driven and absf(clock.hour() - 13.333) < 0.02, "the pinned clock stays on its pin after the nap (%.3f)" % clock.hour())

	# up all night past the next 06:30, then to bed: the next sol with beats still plays and none is skipped. Before,
	# the rules ran on into the next morning and the sleep jumped over a whole sol's tasks
	var sim: Object = game.sim.sim
	while sim.sol < 3:
		game.sim.use("sleep_night")
	beats.start_sol(3)
	beats._start(beats.beats.find_custom(func(b: Dictionary) -> bool: return b.id == "day_done"))
	game.sim.sim.run(40.0)  # real time through the night and past the wake
	check(sim.sol == 4 and sim.hour < 6.5, "awake all night, the rules wait before Sol 4's wake (sol %d, %.2f h)" % [sim.sol, sim.hour])
	await frames(2)
	check(clock.paused, "and the sky waits with them")
	cine.slept.emit(&"night", 8.0)  # the night's sleep, as cine's time-lapse ends it
	for i in 30:
		await process_frame
	check(beats.sequence == "sol4" and sim.sol == 4, "the sleep starts Sol 4, not Sol 5 (%s, sol %d)" % [beats.sequence, sim.sol])
	# a sol with no beats is never landed on: Sol 6's beats run through 9, so the next night is Sol 10's
	while sim.sol < 6:
		game.sim.use("sleep_night")
	beats.start_sol(6)  # its wake sleeps through Sols 6 to 8 (skip:3), and its day is Sol 9
	var at_start := [-1]
	beats.task.connect(func(_id: String) -> void:
		if at_start[0] < 0 and beats.sequence == "sol10":
			at_start[0] = sim.sol, CONNECT_DEFERRED)
	cine.slept.emit(&"night", 8.0)
	for i in 30:
		await process_frame
	# Sol 10 is played as it comes (the dust storm, Mission 1's finale): no skip at its start
	check(beats.sequence == "sol10" and at_start[0] == 10, "after the key 6 day the next is Sol 10 (%s, sol %d at its start, %d now)" % [beats.sequence, at_start[0], sim.sol])
	# the day's tasks run late (skills/guided-tutorial row 6): an idle day hears PIP at each deadline hour, then at the
	# dawn hold, once each; to bed at dawn, the kid sleeps a full night and wakes late
	check(not beats.may_sleep(), "Sol 10's tasks are not done")
	said.clear()
	for i in 200:
		sim.run(0.5)
		game.sim.changed.emit(sim.state())
		if sim.awake_left() <= 0.0:
			break
	game.sim.changed.emit(sim.state())
	var warns := said.filter(func(id: String) -> bool: return id.begins_with("deadline."))
	check(warns == ["deadline.sunset", "deadline.night", "deadline.late", "deadline.dawn"], "PIP warns at each hour, then at the hold (%s)" % [warns])
	# out in the storm: PIP says it is dark and the panels barely work (rows 16, 183, 210)
	said.clear()
	var out: Vector3 = Vector3(3.0, game.world.height_at(3.0, 9.0), 9.0)
	player.place(out, 0.0)
	await frames(10)
	for i in 3:
		game.sim.changed.emit(sim.state())
	check(sim.tau > 3.0 and said.has("storm.dark") and said.has("storm.panels"), "outside in the storm PIP warns (tau %.1f, %s)" % [sim.tau, said])
	cine.slept.emit(&"night", 8.0)
	for i in 30:
		await process_frame
	check(sim.hour > float(sim.n("clock", "wake_hour")) + 6.0, "to bed at dawn, up in the afternoon (%.1f h)" % sim.hour)

	# a meter at 0 leads somewhere, PG: the mission-lost card with what led there, the day's beats stop, the rules wait
	# (14 Nov playtest: life support at 0% and nothing happened)
	check(not game.lost, "no mission lost while the meters hold")
	sim.water_kg = 0.0
	game.sim.use("drink")  # any change: the node tells the HUD and the root
	await frames(2)
	check(game.lost and game.hud.card != null and game.hud.card.has_signal("retry"), "water at 0 puts the mission-lost card up")
	check(beats.sequence == "" and game.sim.paused, "the beats stop and the rules wait")
	game.queue_free()
	return true
