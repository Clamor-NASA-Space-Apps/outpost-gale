extends "res://addons/forge/test.gd"
## Sols 2 and 3 play end to end (data/sols.json, run by cine/beats.gd): godot --headless --path . --fixed-fps 60 -s tests/sols_test.gd
## A bot plays each sol as a kid would: out to PIP, after it, the use spot (a wing brushed, a tray planted), every
## fact dismissed, then free play until a sleep. Every beat ends in order inside its time, every line is in
## data/lines.json, the brush raises the power coming in, PIP never gives up, and free play allows everything.

const BUDGET := {"wake": 30, "power_low": 2, "to_wings": 90, "see_dust": 2, "brush": 30, "jumped": 2, "weak_sun": 2,
	"opportunity": 2, "see_reactor": 10, "reactor": 2, "nasa_chose": 2, "sleep_hint": 2, "free": 3,
	"to_greenhouse": 90, "go_in": 40, "robots_planted": 2, "lettuce_days": 2, "plant": 30, "microgreens": 2,
	"radish": 2, "vitamins": 2, "sent": 2, "light_time": 2, "valve": 60, "fixed": 2, "reply": 40, "reply_home": 2,
	"dustier": 2, "s9_plan": 2, "s9_far": 2, "s9_board": 60, "s9_drive": 40, "s9_outcrop": 2, "s9_sample": 120,
	"s9_water": 2, "s9_home": 60, "s9_return": 40, "alert": 5, "to_shelter": 90, "half_dose": 2, "xrays": 2, "stay": 2}

var game: Node3D
var world: Node3D
var player: Node3D
var pip: Node3D
var beats: Node
var moving := false
var used_at := -1
var lines: Array[String] = []
var targets: Array[String] = []


func _init() -> void:
	watchdog = 1200.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	player = game.get_node("Player")
	pip = world.items.get("pip")
	beats = load("res://cine/beats.gd").new()
	beats.name = "Beats"
	game.add_child(beats)
	beats.setup(world, player, game.interactions, game.clock)
	game.interactions.used.connect(beats.used)
	beats.line.connect(func(id: String, _opts: Dictionary) -> void: lines.append(id))
	beats.objective.connect(func(t: String) -> void: targets.append(t))
	# the wiring sandbox.gd adds (the report's lines): the visor mail, the rules' events, the shelter's knob
	beats.send_mail.connect(game.hud.send_mail)
	beats.trip.connect(func(l: String) -> void: game.cine.trip_to(l, {"sol": game.sim.sim.sol, "km": 8.8}))
	game.cine.arrived.connect(func(l: String) -> void: beats.notify("arrived:" + l))
	game.hud.map_toggled.connect(func(open: bool) -> void: beats.notify("map_open" if open else "map_closed"))
	beats.skip_sols.connect(func(n: int) -> void: game.hud.show_ledger(game.sim.skip_sols(n)))
	game.hud.ledger_closed.connect(func() -> void: beats.notify("ledger_closed"))
	game.hud.cue.connect(func(n: String) -> void:
		if n == "mail":
			beats.notify("mail_arrived"))
	game.sim.changed.connect(func(st: Dictionary) -> void:
		for e: Dictionary in st.events:
			beats.notify("event:" + String(e.id)))
	var sols: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sols.json"))
	var words: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))
	for n: String in ["2", "3", "4", "5", "6"]:
		for b: Dictionary in sols[n]:
			for k: String in ["line", "task"]:
				if b.has(k):
					check(words.has(b[k]) and (words[b[k]] as String).split(" ").size() <= 8, "%s is in lines.json, at most 8 words" % b[k])
			if b.get("fact", false) and b.has("fact_rows"):
				check(not (b.fact_rows as Array).is_empty(), "%s names its fact rows" % b.id)

	# Sol 2: the night of Sol 1 slept through (the rules' night gust dusts the wings), out to PIP, to the wings, a brush
	var sim: Object = game.sim.sim
	var clean_kw: float = sim.solar_kw(1.0) / (1.0 - sim.panel_dust)  # the field clean, at this hour
	game.sim.use("sleep_night")  # through the node, as the sandbox's slept wiring does: the HUD hears the new state
	check(sim.sol == 2 and sim.panel_dust >= 0.33, "the night gust dusted the wings by Sol 2's morning (sol %d, dust %.3f)" % [sim.sol, sim.panel_dust])
	await _wake("sol2")
	await _beat("wake", _follow.bind(2.5))
	await _beat("power_low", _dismiss)
	await _beat("to_wings", _follow.bind(2.0))
	_stop()
	await _beat("see_dust", _dismiss)
	var before: Array = [sim.panel_dust, sim.state().power_in_kw]
	var step := [0.0, 0.0]  # the power coming in just before and just after the use, as the HUD sees them
	game.sim.changed.connect(func(st: Dictionary) -> void:
		if step[1] == 0.0 and sim.panel_dust < before[0] - 0.01:
			step[1] = st.power_in_kw
		elif step[1] == 0.0:
			step[0] = st.power_in_kw)
	var gain: Label = game.hud.meters.power.get("gain") if game.get("hud") and game.hud.get("meters") else null
	var shown := [""]  # the HUD's "+x kW" beside the power meter, as it was seen while visible
	var watch := func() -> void:
		if gain and gain.modulate.a > 0.0 and gain.text.begins_with("+"):
			shown[0] = gain.text
	await _beat("brush", func() -> void:
		watch.call()
		_use("clean_panel", Vector3(27.95, 0.0, 9.5)))
	var after: Array = [sim.panel_dust, sim.state().power_in_kw]
	if gain == null:
		print("  SKIP the HUD's power gain: no real HUD meter here")
	else:
		await _until(func() -> bool: return shown[0] != "", 1.0, watch)
		check(shown[0] != "", "the power meter shows the gain beside its number after the brush ('%s'; the step it saw: %.2f -> %.2f kW, %+.1f%%)"
			% [shown[0], step[0], step[1], 100.0 * (step[1] / maxf(step[0], 0.01) - 1.0)])
		print("  HUD gain: %s" % shown[0])
	print("  brush: dust %.3f -> %.3f, power in %.2f -> %.2f kW (clean field %.2f kW at wake)" % [before[0], after[0], before[1], after[1], clean_kw])
	check(after[0] < before[0] - 0.01 and after[1] > before[1], "the brush cleared dust and the power coming in rose")
	for id: String in ["jumped", "weak_sun", "opportunity"]:
		await _beat(id, _dismiss)
	await _beat("see_reactor", func() -> void: player.cam.look(6.0, 0.0))  # the kid turns to see it
	for id: String in ["reactor", "nasa_chose"]:
		await _beat(id, _dismiss)
	await _sleep("sol2")

	# Sol 3: to the greenhouse, inside, a tray planted
	await _wake("sol3")
	await _beat("wake", _follow.bind(2.5))
	await _beat("to_greenhouse", _follow.bind(2.0))
	_stop()
	beats._do("open:greenhouse")  # the kid's E on the door (doors_test covers it)
	var lined_up := [false]  # square in front of the doorway first, as a kid lines up with a door
	await _beat("go_in", func() -> void:
		lined_up[0] = lined_up[0] or _flat(player.body.global_position, Vector3(-11.0, 0.0, 4.2)) < 0.4
		_steer(Vector3(-11.0, 0.0, 0.5) if lined_up[0] else Vector3(-11.0, 0.0, 4.2)))
	_stop()
	for id: String in ["robots_planted", "lettuce_days"]:
		await _beat(id, _dismiss)
	await _beat("plant", _use.bind("plant", Vector3(-10.4, 0.0, -1.7)))
	for id: String in ["microgreens", "radish", "vitamins"]:
		await _beat(id, _dismiss)
	await _sleep("sol3")

	# Sol 4: a question to Earth on the radio, a valve fixed without Earth, the reply after its round trip
	await _wake("sol4")
	await _beat("wake", _use.bind("radio", Vector3(-1.08, 0.0, 0.73)))
	await _beat("sent", _dismiss)
	check(game.hud.mail.visible, "the visor mail shows the question on its way")
	await _beat("light_time", _dismiss)
	used_at = -1
	await _beat("valve", func() -> void:
		var b: Vector3 = player.body.global_position
		if b.z < 4.0 and absf(b.x) < 2.5:
			_steer(Vector3(0.0, 0.0, 4.5), 0.5)  # out of HAB 1 first
		else:
			_use("o2_valve", Vector3(-2.3, 0.0, 2.6)))
	await _beat("fixed", _dismiss)
	await _beat("reply")
	await _beat("reply_home", _dismiss)
	await _sleep("sol4")

	# Sol 5: the ARCHIVED X12 flare at 07:00, to the shelter in time, half the dose inside
	await _wake("sol5")
	await _beat("wake")
	var flare: Array = game.sim.sim.state().events.filter(func(e: Dictionary) -> bool: return e.id == "flare_x12")
	check(flare.size() == 1 and not flare[0].live and "ARCHIVED" in String(flare[0].source), "the flare is the real one, labelled ARCHIVED (%s)" % [flare])
	await _beat("alert", _out)
	beats._do("open:shelter")  # the kid's E on the shelter's door, if it has one
	var lined := [false]
	await _beat("to_shelter", func() -> void:
		if game.player.room == "shelter" and not game.sim.sim.knobs.sheltered:
			game.sim.apply("shelter_in")  # what the wiring does when the hero is in the shelter's room
		var b: Vector3 = player.body.global_position
		lined[0] = lined[0] or _flat(b, Vector3(-6.0, 0.0, 6.5)) < 0.5
		if b.z < 4.0 and absf(b.x) < 2.5:
			_steer(Vector3(0.0, 0.0, 4.5), 0.5)
		else:
			_steer(Vector3(-6.0, 0.0, 10.0) if lined[0] else Vector3(-6.0, 0.0, 6.5)))
	_stop()
	await frames(5)
	if game.player.room == "shelter" and not game.sim.sim.knobs.sheltered:
		game.sim.apply("shelter_in")
	check(game.sim.sim.knobs.sheltered, "inside the shelter the rules count half the dose (room '%s', hero at %s, shelter at %s)" % [game.player.room, player.body.global_position, world.items.shelter.global_position])
	for id: String in ["half_dose", "xrays", "stay"]:
		await _beat(id, _dismiss)
	await _sleep("sol5")

	# Sol 6: the quiet sols 6 to 8 slept through at once, the ledger card read and closed, on into Sol 9
	var dust: float = game.sim.sim.panel_dust
	await _wake("sol6")
	await frames(2)
	check(game.sim.sim.sol == 9 and game.hud.is_open(), "three quiet sols skip to Sol 9 with the ledger card open (sol %d)" % game.sim.sim.sol)
	check(game.sim.sim.panel_dust > dust, "the wings got dustier meanwhile (%.3f to %.3f)" % [dust, game.sim.sim.panel_dust])
	await _beat("wake", func() -> void:
		if game.hud.is_open():
			game.hud.close_card()
			game.hud.ledger_closed.emit())  # the kid's tap on the card's close
	await _beat("dustier", _dismiss)

	# Sol 9: the trip planned on the map, the rover boarded, Mont Mercou, a sample, home again
	await _beat("s9_plan", _press.bind(&"map"))
	await _beat("s9_far", _press.bind(&"map"))
	await _beat("s9_board", _board)
	await _beat("s9_drive")
	var site: Vector3 = world.landmark("site_mercou_rover").pos
	check(_flat(player.body.global_position, site) < 30.0, "the trip ends at the Mont Mercou site (%.0f m off)" % _flat(player.body.global_position, site))
	await _beat("s9_outcrop", _dismiss)
	used_at = -1
	var cleared := [false]
	var pebble := [Vector3.INF]
	await _beat("s9_sample", func() -> void:
		if player.vehicle:
			game.interactions.interact()  # out of the rover (E)
			return
		# the nearest pebble still on the ground (a spot sits at its item's origin; its pebble is where the kid kneels)
		var best: Vector3 = pebble[0]  # one pebble, kept: switching to a nearer one mid-clip pressed a move key and cut it
		for it: Node in ([] if best != Vector3.INF else game.interactions.by_thing.values()):
			if it.kind == "spot" and it.row.kind == "sample" and (it.props[it.row.on] as Node3D).visible:
				var at: Vector3 = (it.props[it.row.on] as Node3D).global_position
				if best == Vector3.INF or _flat(at, player.body.global_position) < _flat(best, player.body.global_position):
					best = at
		var past: Vector3 = site + Vector3(5.0, 0.0, 3.0)  # round the parked rover first, as a kid walks round it
		cleared[0] = cleared[0] or _flat(player.body.global_position, past) < 0.8
		if not cleared[0]:
			_steer(past, 0.5)
		elif best != Vector3.INF:
			pebble[0] = best
			_use_near("sample", best))
	await _beat("s9_water", _dismiss)
	await _beat("s9_home", _board)
	await _beat("s9_return")
	check(_flat(player.body.global_position, world.landmark("rover").pos) < 30.0, "and the trip home ends at the base")
	await _sleep("sol6")
	check(pip.gave_up == 0, "PIP never gave up on an order (%d)" % pip.gave_up)
	return true


## The kid wakes in HAB 1 by the hatch (cine's wake), and the sol's beats start.
func _wake(seq: String) -> void:
	while game.sim.sim.sol < int(seq.trim_prefix("sol")):
		game.sim.use("sleep_night")  # the night, as cine.slept tells the rules
	var far: float = _flat(pip.global_position, Vector3.ZERO)
	var s: Dictionary = beats.data.starts.airlock
	var hab: Node3D = world.items[s.item]
	player.place(hab.to_global(Vector3(s.at[0], s.at[1], s.at[2])), -rad_to_deg(hab.global_rotation.y) + float(s.yaw))
	beats._do("open:hab1")  # the kid's E on the hatch
	await frames(30)
	lines.clear()
	check(beats.start_sol(int(seq.trim_prefix("sol"))), "data/sols.json has %s" % seq)
	check(_flat(pip.global_position, Vector3.ZERO) < 8.0, "%s: PIP starts the day at the base (was %.0f m out)" % [seq, far])


## The Today list's last hint, free play with everything allowed, then the night's sleep ends the sol.
func _sleep(seq: String) -> void:
	var finished := [false]
	beats.finished.connect(func(s: String) -> void: finished[0] = finished[0] or s == seq, CONNECT_ONE_SHOT)
	await _beat("sleep_hint", _dismiss)
	check(targets[-1] == "hab1", "%s ends pointing at HAB 1 to sleep (%s)" % [seq, targets[-1]])
	await frames(5)
	check(player.allowed.is_empty(), "free play allows everything")
	check(not pip.led, "PIP is let go to potter about in free play")
	beats.notify("slept")  # cine.slept, a night
	await _beat("free")
	check(finished[0], "%s finished on the sleep" % seq)
	var ids: Array = (beats.data[seq] as Array).map(func(b: Dictionary) -> String: return b.id)
	check(beats.done == ids, "%s: every beat ended, in order (%s)" % [seq, beats.done])
	var own: Array = (beats.data[seq] as Array).filter(func(b: Dictionary) -> bool: return b.has("line")).map(
		func(b: Dictionary) -> String: return b.line)
	var said: Array[String] = []
	for id: String in lines:
		if not id.begins_with("nag.") and id != "pip.this_way" and (said.is_empty() or said[-1] != id):
			said.append(id)
	check(said == own, "%s: every line went to the HUD, in order (%s)" % [seq, said])


func _beat(id: String, each := Callable()) -> void:
	if not check(beats.beat.get("id", "") == id, "beat %s is playing (now '%s')" % [id, beats.beat.get("id", "")]):
		return
	var f0 := Engine.get_physics_frames()
	var ok := await _until(func() -> bool: return beats.done.has(id) and beats.beat.get("id", "") != id, float(BUDGET[id]), each)
	var h: Vector3 = player.body.global_position
	print("  %-14s %5.1f s game" % [id, (Engine.get_physics_frames() - f0) / 60.0])
	check(ok, "beat %s ends within %d s (hero at %.1f, %.1f; PIP %s at %.1f, %.1f)" % [id, BUDGET[id], h.x, h.z, pip.state,
		pip.global_position.x, pip.global_position.z])


func _until(ok: Callable, seconds: float, each := Callable()) -> bool:
	for i in int(60 * seconds):
		if ok.call():
			return true
		if each.is_valid():
			each.call()
		await frames(1)
	return ok.call()


## To `at`, then the use spot of `kind` whose pebble (row `on`) lies there.
func _use_near(kind: String, at: Vector3) -> void:
	if _flat(at, player.body.global_position) > 1.2:
		_steer(at, 0.9)
		return
	_stop()
	if used_at >= 0 and Engine.get_physics_frames() - used_at < 60 * 8:
		return
	for it: Node in game.interactions.by_thing.values():
		if it.kind == "spot" and it.row.kind == kind and _flat((it.props[it.row.on] as Node3D).global_position, at) < 0.1:
			used_at = Engine.get_physics_frames()
			game.interactions.use(it)
			return


## A key tapped once a beat (the map), as the kid does.
func _press(a: StringName) -> void:
	if used_at < 0 or Engine.get_physics_frames() - used_at > 60:
		used_at = Engine.get_physics_frames()
		action(a, true)
		action(a, false)


## To the rover and in (E at its door; aim is interact_test's job).
func _board() -> void:
	if player.vehicle:
		return
	var b: Vector3 = player.body.global_position
	if b.z < 4.0 and absf(b.x) < 2.5:
		_steer(Vector3(0.0, 0.0, 4.5), 0.5)  # out of HAB 1 first
		return
	for it: Node in game.interactions.by_thing.values():
		if it.kind == "rover":
			if _flat(it.thing.global_position, b) > 4.0:
				_steer(it.thing.global_position, 3.5)
			else:
				_stop()
				game.interactions.use(it)
			return


## Out of HAB 1 and stand by.
func _out() -> void:
	var b: Vector3 = player.body.global_position
	if b.z < 4.0 and absf(b.x) < 2.5:
		_steer(Vector3(0.0, 0.0, 4.5), 0.5)
	else:
		_stop()


func _dismiss() -> void:
	beats.notify("dismissed")  # the HUD's Enter or tap


## After PIP like a kid: toward it, stopping `near` short.
func _follow(near: float) -> void:
	var b: Vector3 = player.body.global_position
	if Vector2(b.x, b.z).length() < 4.0:  # in or by HAB 1: out through the hatch first
		_steer(Vector3(0.0, 0.0, 4.5), 0.5)
	else:
		_steer(pip.global_position, near)


## To the use spot `kind` near `at`, then the use itself (aim is interact_test's job).
func _use(kind: String, at: Vector3) -> void:
	if _flat(at, player.body.global_position) > 2.0:
		_steer(at, 1.5)
		return
	_stop()
	if used_at >= 0 and Engine.get_physics_frames() - used_at < 60 * 8:
		return  # one use, and again only if its clip has long ended without the beat seeing it
	for it: Node in game.interactions.by_thing.values():
		if it.kind == "spot" and it.row.kind == kind and _flat(it.global_position, at) < 3.0:
			used_at = Engine.get_physics_frames()
			game.interactions.use(it)
			return


func _steer(at: Vector3, near := 0.3) -> void:
	if _flat(at, player.body.global_position) < near:
		_stop()
		return
	var d: Vector3 = at - player.body.global_position
	player.cam.yaw = atan2(-d.x, -d.z)
	if not moving:
		moving = true
		action(&"move_forward", true)


func _stop() -> void:
	if moving:
		moving = false
		action(&"move_forward", false)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
