extends "res://addons/forge/test.gd"
## The sleep time-lapse (design/plans/next-lanes.md section 3): godot --headless --path . --fixed-fps 60 -s tests/sleep_test.gd
## The bed spot opens the picker and the clock waits; Night drives only the look clock to the fixed 06:30 wake with the
## drone shot, PIP frozen, the shadows reaching further and the probes held; then the hero wakes on the bench in HAB 1,
## the clock given back. A nap from a pinned 13:00 ends 20 minutes on and stays pinned. Nothing counts (hard rule 1).

const Cine := preload("res://cine/cine.gd")

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
	check(await within(cine.slept, 15.0, 2), "the lapse ends within its 9 s cap")
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
	check(st.cam.indoor > 0.99 and not st.cam.inside, "the wake hands over to the room's third-person view, the lens in no solid (%.2f)" % st.cam.indoor)
	check(root.get_camera_3d() == player.cam.lens, "the play camera is back")
	check(not player.seated and player.process_mode != Node.PROCESS_MODE_DISABLED, "the hero stands and moves again")
	check(audio._dawn, "the next door opened plays the dawn cue")
	check(audio.cue != "sleep", "the sleep cue stopped on the cut")

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
	# Sol 10's wake sleeps through 10 and 11 itself (skip:2): it starts on Sol 10 and lands on 12
	check(beats.sequence == "sol10" and at_start[0] == 12, "after the key 6 day the next is Sol 10 (%s, sol %d at its start, %d now)" % [beats.sequence, at_start[0], sim.sol])
	game.queue_free()
	return true
