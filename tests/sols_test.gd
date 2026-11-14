extends "res://addons/forge/test.gd"
## The sols past the first play end to end (data/sols.json, run by cine/beats.gd): godot --headless --path . --fixed-fps 60 -s tests/sols_test.gd
## A bot plays each sol as a kid would: out to PIP, after it, the use spot (a wing brushed, a tray planted), the sol's
## check answered, its choice made, then free play until a sleep. Every beat ends in order inside its time, every line
## is in data/lines.json, the brush raises the power coming in, PIP never gives up, and free play allows everything.
## Mission 1 (keys 2 to 10, design/plans/mission-1-contracts.md): a teaching line never waits for a dismiss, its page
## reaches the handbook, each sol asks one check. Sol 10 is its finale, the dust storm. Mission 2 (key 13 on) still
## has facts the bot dismisses.

# s a beat may take. A teaching line shows for 4 s (6 here); to_reactor and the day_done after it are 170 m walks
const BUDGET := {"wake": 45, "power_low": 6, "to_wings": 90, "see_dust": 6, "brush": 30, "your_call": 6, "explorers": 6,
	"to_reactor": 300, "reactor": 6, "check": 5, "sleep_hint": 6, "free": 3, "day_done": 400,
	"to_greenhouse": 90, "go_in": 40, "plant": 30, "water": 6, "vitamins": 6,
	"sent": 6, "light_time": 6, "valve": 60, "fixed": 6, "reply": 40, "reply_home": 6,
	"dustier": 6, "s9_plan": 2, "s9_far": 2, "s9_walk_back": 6, "s9_board": 60, "s9_drive": 40, "s9_lake": 6, "s9_sample": 120,
	"s9_curiosity": 6, "s9_home": 60, "s9_return": 40, "alert": 5, "to_shelter": 90, "half_dose": 6, "xrays": 6, "decide": 5,
	"m1_done": 6, "s12_dark": 10, "s12_storm": 6, "s12_wings": 6, "s12_reactor": 6, "s12_planet": 6, "s12_choose": 5,
	"s13_brush": 90, "s13_toxic": 2, "s13_why": 2, "s13_skip": 5, "s17_ripe": 120, "s17_go_in": 40, "s17_pick": 60,
	"s17_salad": 2, "s20_plan": 2, "s20_far": 2, "s20_ring": 2, "s20_board": 90, "s20_drive": 40, "s20_see": 90,
	"s20_touch": 2, "s20_archived": 2, "s20_lake": 2, "s20_life": 2, "s20_home": 90, "s20_return": 40, "s26_lift": 60,
	"s26_limit": 2, "s26_carry": 400, "s26_set": 30, "s26_suits": 2, "s26_skip": 5, "s31_liftoff": 120, "s31_year": 2,
	"s31_labs": 2}

var game: Node3D
var world: Node3D
var player: Node3D
var pip: Node3D
var beats: Node
var moving := false
var used_at := -1
var lines: Array[String] = []
var targets: Array[String] = []
var pages: Array[String] = []  # every handbook page the beats unlocked (beats.page)
var asked: Array[String] = []  # every check the beats offered, by id (beats.check_offered)
var offered: Array[String] = []  # every choice card the beats offered
var crumbs: Array[Vector3] = []  # PIP's tracks for _crumbs()
var _held := [Vector3.INF, 0, 0, Vector3.ZERO, 0]  # _crumbs(): where the hero last got somewhere, when, a sidestep's end, its target, sidesteps at this crumb


func _init() -> void:
	watchdog = 1800.0


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
	beats.page.connect(func(id: String) -> void: pages.append(id))
	beats.check_offered.connect(func(c: Dictionary) -> void: asked.append(String(c.id)))
	beats.choice_offered.connect(func(id: String) -> void: offered.append(id))
	# the wiring sandbox.gd adds (the report's lines): the visor mail, the rules' events, the shelter's knob
	beats.send_mail.connect(game.hud.send_mail)
	var km := [8.8]  # the last field site's distance (world.json sites): the trip home shows the same
	beats.trip.connect(func(l: String) -> void:
		var site: Dictionary = world.data.sites.get(l.trim_prefix("site_").trim_suffix("_rover"), {})
		if site.has("km"):
			km[0] = float(site.km)
		game.cine.trip_to(l, {"sol": game.sim.sim.sol, "km": km[0]}))
	beats.liftoff.connect(game.cine.launch)
	game.cine.launched.connect(func() -> void: beats.notify("launched"))
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
	for n: String in ["2", "3", "4", "5", "6", "10", "13", "18", "21"]:
		for b: Dictionary in sols[n]:
			for k: String in ["line", "task"]:
				if b.has(k):
					check(words.has(b[k]) and (words[b[k]] as String).split(" ").size() <= 8, "%s is in lines.json, at most 8 words" % b[k])
					check((words.get(b[k], "") as String).count("*") in [0, 2, 4], "%s marks at most two key facts" % b[k])
			if b.has("fact_rows"):
				check(not (b.fact_rows as Array).is_empty(), "%s names its fact rows" % b.id)
	_mission1(sols, words)

	# Sol 2: the night of Sol 1 slept through (the rules' night gust dusts the wings), out to PIP, to the wings, a brush
	var sim: Object = game.sim.sim
	var clean_kw: float = sim.solar_kw(1.0) / (1.0 - sim.panel_dust)  # the field clean, at this hour
	while game.sim.sim.sol < 2:  # from the 06:30 start a night is 8.5 h (sim.json sleep_h): twice to reach Sol 2
		game.sim.use("sleep_night")  # through the node, as the sandbox's slept wiring does: the HUD hears the new state
	check(sim.sol == 2 and sim.panel_dust >= 0.33, "the night gust dusted the wings by Sol 2's morning (sol %d, dust %.3f)" % [sim.sol, sim.panel_dust])
	await _wake("sol2")
	await _beat("wake", _follow.bind(2.5))
	_stop()
	await _beat("power_low")
	await _beat("to_wings", _follow.bind(2.0))
	_stop()
	await _beat("see_dust")
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
		_use("clean_panel", Vector3(-8.116, 0.0, -26.723)))
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
	for id: String in ["your_call", "explorers"]:
		await _beat(id)
	# the reactor is visited (Ravindu, 14 Nov), about 170 m out. One more wing brushed first, the kid's own trade:
	# the step waits. Then round the wing rows' north ends and on to the reactor on foot, hurrying
	var route: Array[Vector3] = [Vector3(-9.5, 0.0, -23.0), Vector3(-17.0, 0.0, -23.0), Vector3(-15.616, 0.0, -26.723),
		Vector3(-17.0, 0.0, -23.0), Vector3(-50.0, 0.0, -23.0), world.landmark("reactor").pos]
	used_at = -1
	await _beat("to_reactor", func() -> void:
		if route.size() == 4:  # at wing 2's brush stand
			if sim.panel_dust < after[0] - 0.01:
				route.pop_front()
				action(&"hurry", true)
			else:
				_use("clean_panel", route[0])
			return
		if route.size() > 1 and _flat(player.body.global_position, route[0]) < 0.6:
			route.pop_front()
		_steer(route[0], 0.5))
	action(&"hurry", false)
	_stop()
	check(sim.panel_dust < after[0] - 0.01, "a second wing brushed on the way cleared more dust, and the step waited (%.3f to %.3f)" % [after[0], sim.panel_dust])
	check(player.vehicle == null and _flat(player.body.global_position, world.landmark("reactor").pos) < 14.5,
		"the kid stands at the reactor, on foot (%.0f m off)" % _flat(player.body.global_position, world.landmark("reactor").pos))
	await _beat("reactor")
	await _beat("check", _answer)
	check(asked == ["sol2"], "Sol 2 asked its one check (%s)" % [asked])
	await _sleep("sol2")

	# Sol 3: to the greenhouse, inside, a tray planted
	await _wake("sol3")
	await _beat("wake", _follow.bind(2.5))
	await _beat("to_greenhouse", _follow.bind(2.0))
	_stop()
	beats._do("open:greenhouse")  # the kid's E on the door (doors_test covers it)
	var lined_up := [false]  # square in front of the doorway first, as a kid lines up with a door
	await _beat("go_in", func() -> void:
		lined_up[0] = lined_up[0] or _flat(player.body.global_position, Vector3(5.869, 0.0, 10.208)) < 0.4
		_steer(Vector3(2.215, 0.0, 10.786) if lined_up[0] else Vector3(5.869, 0.0, 10.208)))
	_stop()
	await _beat("plant", _use.bind("plant", Vector3(-0.052, 0.0, 10.538)))
	for id: String in ["water", "vitamins"]:
		await _beat(id)
	await _beat("check", _answer)
	await _sleep("sol3")

	# Sol 4: a question to Earth on the radio, a valve fixed without Earth, the reply after its round trip
	await _wake("sol4")
	await _beat("wake", _use.bind("radio", Vector3(0.89, 0.0, 0.953)))
	await _beat("sent")
	check(game.hud.mail.visible, "the visor mail shows the question on its way")
	await _beat("light_time")
	check(targets[-1] == "", "the alarm shows no waypoint: the handbook says where the valve is (%s)" % targets[-1])
	used_at = -1
	await _beat("valve", func() -> void:
		var b: Vector3 = player.body.global_position
		if _hab_l(b).z > -4.0 and absf(_hab_l(b).x) < 2.5:
			_steer(Vector3(4.445, 0.0, -0.704), 0.5)  # out of HAB 1 first
		else:
			_use("o2_valve", Vector3(2.928, 0.0, 1.865)))
	check(pages.has("oxygen_valve"), "the alarm put the oxygen valve's page in the handbook (%s)" % [pages])
	await _beat("fixed")
	await _beat("reply")
	await _beat("reply_home")
	await _beat("check", _answer)
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
		var sh: Vector3 = world.items.shelter.global_position  # 4 m out of its door lines the kid up (the door turned with the base, 14 Nov)
		lined[0] = lined[0] or _flat(b, sh + Vector3(-3.951, 0.0, 0.626)) < 0.5
		if _hab_l(b).z > -4.0 and absf(_hab_l(b).x) < 2.5:
			_steer(Vector3(4.445, 0.0, -0.704), 0.5)
		else:
			_steer(sh if lined[0] else sh + Vector3(-3.951, 0.0, 0.626)))
	_stop()
	await frames(5)
	if game.player.room == "shelter" and not game.sim.sim.knobs.sheltered:
		game.sim.apply("shelter_in")
	check(game.sim.sim.knobs.sheltered, "inside the shelter the rules count half the dose (room '%s', hero at %s, shelter at %s)" % [game.player.room, player.body.global_position, world.items.shelter.global_position])
	for id: String in ["half_dose", "xrays"]:
		await _beat(id)
	await _beat("check", _answer)
	await _beat("decide", func() -> void:
		if offered.has("sol5_storm"):
			beats.notify("chose:sol5_storm"))  # the card's tap; it applies no rule (the hero's place does)
	check(offered == ["sol5_storm"] and game.sim.sim.knobs.sheltered, "the storm choice was offered, and the kid in the shelter keeps half the dose (%s)" % [offered])
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
	await _beat("dustier")

	# Sol 9: the trip planned on the map, the rover boarded, Mont Mercou, a sample, home again
	await _beat("s9_plan", _press.bind(&"map"))
	await _beat("s9_far", _press.bind(&"map"))
	await _beat("s9_walk_back")
	await _beat("s9_board", _board)
	await _beat("s9_drive")
	var site: Vector3 = world.landmark("site_mercou_rover").pos
	check(_flat(player.body.global_position, site) < 30.0, "the trip ends at the Mont Mercou site (%.0f m off)" % _flat(player.body.global_position, site))
	await _beat("s9_lake")
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
	await _beat("s9_curiosity")
	await _beat("s9_home", _board)
	await _beat("s9_return")
	check(_flat(player.body.global_position, world.landmark("rover").pos) < 30.0, "and the trip home ends at the base")
	await _beat("check", _answer)
	await _sleep("sol6")

	# Sol 10, Mission 1's finale: no skip, the kid wakes into the dust storm (the rules' began in Sol 9's night) under
	# a sky that is the storm's at the rules' own hour; out to PIP, the dark felt first, then named; the check; the
	# storm power choice; Mission 1's last line
	await _wake("sol10")
	await frames(2)
	check(sim.sol == 10 and not game.hud.is_open(), "Sol 10 starts with no skip and no card (sol %d)" % sim.sol)
	var storm: Array = sim.state().events.filter(func(e: Dictionary) -> bool: return e.id == "dust_storm")
	check(storm.size() == 1 and "ARCHIVED" in String(storm[0].source), "the storm is the real 2018 one, labelled ARCHIVED (%s)" % [storm])
	var tau0: float = sim.tau
	check(tau0 > 2.0, "the rules' sky is dusty by the wake (tau %.2f)" % tau0)
	check(game.clock.storm_on and not game.clock.pinned and absf(game.clock.hour() - sim.local_hour()) < 0.5,
		"the look is the storm's at the rules' hour, and runs (sky %.2f h, rules %.2f h)" % [game.clock.hour(), sim.local_hour()])
	await _beat("wake", _follow.bind(2.5))
	_stop()
	await _beat("s12_dark", func() -> void: player.cam.look(6.0, 0.0))
	for id: String in ["s12_storm", "s12_wings", "s12_reactor", "s12_planet"]:
		await _beat(id)
	await _beat("check", _answer)
	check(asked == ["sol2", "sol3", "sol4", "sol5", "sol9", "sol10"], "Mission 1 asked one check a played sol (%s)" % [asked])
	var pick: Dictionary = beats.data.offers.sol12_power.options[1]  # the oxygen maker, as a kid might tap
	await _beat("s12_choose", func() -> void:
		if offered.has("sol12_power") and not sim.knobs.o2_maker:
			for rule: String in pick.apply:
				game.sim.apply(rule)  # what the sandbox's chosen wiring does
			beats.notify("chose:sol12_power"))
	check(offered[-1] == "sol12_power" and sim.knobs.o2_maker and not sim.knobs.greenhouse and sim.knobs.heater_c < 21,
		"the storm choice was offered and the pick reached the rules (%s, %s)" % [offered, sim.knobs])
	await _beat("m1_done")  # Mission 1's last line, before the walk home
	print("  storm: tau %.2f at the wake, %.2f now, solar %.2f kW" % [tau0, sim.tau, sim.solar_in_kw])
	check(sim.tau > tau0, "the storm still climbs on Sol 10 (tau %.2f to %.2f)" % [tau0, sim.tau])
	await _sleep("sol10")

	# Sol 13: out to PIP, back in to brush the dust off, the stormy sols 13 to 16 skipped, Sol 17's first salad
	await _wake("sol13")
	await _beat("wake", _follow.bind(2.5))
	_stop()
	used_at = -1
	var hab_brush: Vector3 = world.items.hab1.to_global(Vector3(-0.605, 0.0, -1.426))
	var at_hatch := [false]
	await _beat("s13_brush", func() -> void:
		at_hatch[0] = at_hatch[0] or _flat(player.body.global_position, Vector3(5.432, 0.0, -0.86)) < 0.5
		if at_hatch[0]:
			_use("brush", hab_brush)
		else:
			_steer(Vector3(5.432, 0.0, -0.86), 0.3))  # square in front of the hatch first
	_stop()
	for id: String in ["s13_toxic", "s13_why"]:
		await _beat(id, _dismiss)
	await frames(2)
	check(sim.sol == 17 and game.hud.is_open(), "four stormy sols skip to Sol 17 with the ledger card open (sol %d)" % sim.sol)
	await _beat("s13_skip", func() -> void:
		if game.hud.is_open():
			game.hud.close_card()
			game.hud.ledger_closed.emit())
	await _beat("s17_ripe", _follow.bind(2.0))
	_stop()
	beats._do("open:greenhouse")
	# square in front of the door, then in; where PIP waits on that spot, round it by its left and in from just
	# outside the door (14 Nov: with no use clips the hero came later and PIP stood there first)
	var gh_way := [Vector3(5.869, 0.0, 10.208), Vector3(4.585, 0.0, 10.411), Vector3(2.215, 0.0, 10.786)]
	await _beat("s17_go_in", func() -> void:
		if gh_way.size() == 3 and _flat(pip.global_position, gh_way[0]) < 1.0:
			gh_way[0] = Vector3(6.041, 0.0, 11.294)
		while gh_way.size() > 1 and _flat(player.body.global_position, gh_way[0]) < 0.4:
			gh_way.pop_front()
		_steer(gh_way[0]))
	_stop()
	used_at = -1
	await _beat("s17_pick", _use.bind("harvest", Vector3(-0.398, 0.0, 10.593)))
	await _beat("s17_salad", _dismiss)
	await _sleep("sol13")

	# Sol 18: two dusty sols skipped, on into Sol 20: the long drive to Curiosity, look, never touch, home again
	await _wake("sol18")
	await frames(2)
	check(sim.sol == 20 and game.hud.is_open(), "two sols skip to Sol 20 with the ledger card open (sol %d)" % sim.sol)
	await _beat("wake", func() -> void:
		if game.hud.is_open():
			game.hud.close_card()
			game.hud.ledger_closed.emit())
	used_at = -1
	await _beat("s20_plan", _press.bind(&"map"))
	await _beat("s20_far", _press.bind(&"map"))
	await _beat("s20_ring", _dismiss)
	await _beat("s20_board", _board)
	await _beat("s20_drive")
	var cur_site: Vector3 = world.landmark("site_curiosity_rover").pos
	check(_flat(player.body.global_position, cur_site) < 30.0, "the trip ends at the Curiosity site (%.0f m off)" % _flat(player.body.global_position, cur_site))
	var rover_cur: Vector3 = world.landmark("curiosity").pos
	var rv: Node3D = world.items.rover
	var way: Array[Vector3] = []  # round the parked rover by the side Curiosity is on: past its flank, then on
	var leg := [0]
	await _beat("s20_see", func() -> void:
		if player.vehicle:
			game.interactions.interact()  # out of the rover (E)
			return
		if way.is_empty():
			var side := signf(rv.to_local(rover_cur).x)
			way = [rv.to_global(Vector3(4.5 * side, 0.0, 4.0)), rv.to_global(Vector3(4.5 * side, 0.0, -5.0)), rover_cur]
		if leg[0] < 2 and _flat(player.body.global_position, way[leg[0]]) < 0.8:
			leg[0] += 1
		_steer(way[leg[0]], 6.0 if leg[0] == 2 else 0.5))
	print("  s20_see: vehicle %s, hero %s" % [player.vehicle, player.body.global_position])
	_stop()
	for id: String in ["s20_touch", "s20_archived", "s20_lake", "s20_life"]:
		await _beat(id, _dismiss)
	await _beat("s20_home", _board)
	await _beat("s20_return")
	check(_flat(player.body.global_position, world.landmark("rover").pos) < 30.0, "and the long drive home ends at the base")
	await _sleep("sol18")

	# Sol 21: five calm sols skipped; Sol 26: the sample case carried to the rocket; Sol 31: liftoff
	await _wake("sol21")
	await frames(2)
	check(sim.sol == 26 and game.hud.is_open(), "five sols skip to Sol 26 with the ledger card open (sol %d)" % sim.sol)
	await _beat("wake", func() -> void:
		if game.hud.is_open():
			game.hud.close_card()
			game.hud.ledger_closed.emit())
	var case: Node3D = world.items.samples
	used_at = -1
	await _beat("s26_lift", func() -> void:
		var t: Node = game.interactions.target
		if _flat(player.body.global_position, case.global_position) > 1.6:
			_follow_out(case.global_position, 1.2)
		elif t and t.kind == "bag" and (t.thing == case or case.is_ancestor_of(t.thing)):
			_stop()
			_press(&"interact")
		else:
			_steer(case.global_position, 0.6))  # past a cargo bag offered on the way: a player goes for the case
	_stop()
	check(game.interactions.carried != null and (game.interactions.carried == case or case.is_ancestor_of(game.interactions.carried)
		or game.interactions.carried.is_ancestor_of(case)), "the hero carries the sample case (%s)" % [game.interactions.carried])
	await _beat("s26_limit", _dismiss)
	var mav: Vector3 = world.landmark("mav").pos
	await _beat("s26_carry", _steer.bind(mav, 0.5))
	_stop()
	used_at = -1
	await _beat("s26_set", func() -> void:
		if game.interactions.carried:
			_press(&"interact"))
	check(game.interactions.carried == null and _flat(case.global_position, mav) < 14.0, "the case rests by the rocket (%.1f m)" % _flat(case.global_position, mav))
	await _beat("s26_suits", _dismiss)
	await frames(2)
	check(sim.sol == 31 and game.hud.is_open(), "the last sols skip to Sol 31, launch day (sol %d)" % sim.sol)
	await _beat("s26_skip", func() -> void:
		if game.hud.is_open():
			game.hud.close_card()
			game.hud.ledger_closed.emit())
	var finished := [false]
	beats.finished.connect(func(s: String) -> void: finished[0] = finished[0] or s == "sol21", CONNECT_ONE_SHOT)
	await _beat("s31_liftoff")
	for id: String in ["s31_year", "s31_labs"]:
		await _beat(id, _dismiss)
	check(finished[0], "the game's story ends after the liftoff")
	var ids: Array = (beats.data.sol21 as Array).map(func(b: Dictionary) -> String: return b.id)
	check(beats.done == ids, "sol21: every beat ended, in order (%s)" % [beats.done])
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
	check(not beats.may_sleep(), "%s: no sleep at the start of the day (14 Nov playtest: sleep skipped sols)" % seq)
	check(_flat(pip.global_position, Vector3.ZERO) < 8.0, "%s: PIP starts the day at the base (was %.0f m out)" % [seq, far])


## The Today list's last hint, free play with everything allowed, then the night's sleep ends the sol.
func _sleep(seq: String) -> void:
	var finished := [false]
	beats.finished.connect(func(s: String) -> void: finished[0] = finished[0] or s == seq, CONNECT_ONE_SHOT)
	check(beats.may_sleep(), "%s: the bed opens once the work is done" % seq)
	if beats.beat.get("id", "") == "day_done":  # PIP leads to HAB 1 (not on Sol 5: it stays in the shelter)
		check(beats.tasks().size() == 1 and lines[-1] == "sleep.day_done", "%s: only the rest is left, and PIP says so" % seq)
		player.exit()  # home from a trip: out of the rover first (E), as a kid does
		await frames(2)
		if beats.beat.get("id", "") == "day_done":  # already by the airlock, it has ended
			crumbs = [player.body.global_position, pip.global_position]
			await _beat("day_done", _crumbs)
			_stop()
		check(beats.done.has("day_done"), "%s: the walk to HAB 1 ended" % seq)
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
	var want: Array = []  # the pages this sol's beats name
	for b: Dictionary in beats.data[seq]:
		want += b.page if b.get("page") is Array else ([b.page] if b.has("page") else [])
	check(want.all(func(p: String) -> bool: return pages.has(p)), "%s: every page reached the handbook (%s)" % [seq, want])
	var said: Array[String] = []
	for id: String in lines:
		if not id.begins_with("nag.") and id != "pip.this_way" and (said.is_empty() or said[-1] != id):
			said.append(id)
	check(said == own, "%s: every line went to the HUD, in order (%s)" % [seq, said])


## Mission 1's data rules (design/plans/mission-1-contracts.md), read from the files: no line stops the game, a line
## with a number names its factcheck rows, every page is one the handbook has, one check a played sol, and the two
## cards past Sol 1 show a gain and a loss.
func _mission1(sols: Dictionary, words: Dictionary) -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/handbook.json"))
	var ids: Array = (book.pages as Array).map(func(p: Dictionary) -> String: return p.id)
	var digit := RegEx.create_from_string("\\d")
	for n: String in ["2", "3", "4", "5", "6", "10"]:
		var checks: Array = []
		for b: Dictionary in sols[n]:
			check(not b.get("fact", false), "key %s %s: a Mission 1 line never waits for a dismiss" % [n, b.id])
			var said: String = (words.get(b.get("line", ""), "") as String).replace("HAB 1", "").replace("Mission 1", "")  # names, not facts
			check(digit.search(said) == null or b.has("fact_rows"), "key %s %s: a line with a number names its factcheck rows" % [n, b.id])
			var named: Array = b.get("check", {}).get("pages", []) + (b.page if b.get("page") is Array else ([b.page] if b.has("page") else []))
			check(named.all(func(p: String) -> bool: return p in ids), "key %s %s: its pages are in data/handbook.json (%s)" % [n, b.id, named])
			if b.has("check"):
				var c: Dictionary = b.check
				checks.append(c.id)
				check(c.options.size() == 3 and int(c.right) in [0, 1, 2] and not (c.pages as Array).is_empty()
					and ([c.q] + c.options).all(func(l: String) -> bool: return words.has(l)), "check %s: a question, three options, its pages" % c.id)
				check(not b.has("wait"), "check %s ends on its answer, never on a time" % c.id)
		check(checks.size() == 1, "key %s asks one check (%s)" % [n, checks])
	var offers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).offers
	for id: String in ["sol5_storm", "sol12_power"]:
		for o: Dictionary in offers[id].options:
			check(not o.has("costs") and [o.text, o.gain, o.lose].all(func(l: String) -> bool: return words.has(l)), "%s %s shows a gain and a loss" % [id, o.text])
	# the root sets the shelter knob from where the hero stands, every tick: a rule on the card would fight it
	check((offers.sol5_storm.options as Array).all(func(o: Dictionary) -> bool: return (o.apply as Array).is_empty()), "the Sol 5 card applies no rule")


## The sol's check answered right, as the HUD's card does (hud.checked, wired to this by the root).
func _answer() -> void:
	if not asked.is_empty():
		beats.notify("checked:" + asked[-1])


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
	if _hab_l(b).z > -4.0 and absf(_hab_l(b).x) < 2.5:
		_steer(Vector3(4.445, 0.0, -0.704), 0.5)  # out of HAB 1 first
		return
	for it: Node in game.interactions.by_thing.values():
		if it.kind == "rover":
			if _flat(it.thing.global_position, b) > 4.0:
				_steer(it.thing.global_position, 3.5)
			else:
				_stop()
				game.interactions.use(it)
			return


## Toward `at`, out of HAB 1 first.
func _follow_out(at: Vector3, near: float) -> void:
	var b: Vector3 = player.body.global_position
	if _hab_l(b).z > -5.8 and absf(_hab_l(b).x) < 2.5:
		_steer(Vector3(6.124, 0.0, -0.97), 0.4)  # straight out through the hatch first: a turn in it rubs the frame
	else:
		_steer(at, near)


## Out of HAB 1 and stand by.
func _out() -> void:
	var b: Vector3 = player.body.global_position
	if _hab_l(b).z > -4.0 and absf(_hab_l(b).x) < 2.5:
		_steer(Vector3(4.445, 0.0, -0.704), 0.5)
	else:
		_stop()


func _dismiss() -> void:
	beats.notify("dismissed")  # the HUD's Enter or tap


## After PIP along its own tracks, as a kid behind it does (heading straight at PIP from its far side stood in its way
## out of the greenhouse, and PIP waited for good), stopping 2 m short of it.
func _crumbs() -> void:
	if pip.global_position.distance_to(crumbs[-1]) > 0.5:
		crumbs.append(pip.global_position)
	var b: Vector3 = player.body.global_position
	while crumbs.size() > 1 and _flat(crumbs[0], b) < 0.8:
		crumbs.pop_front()
		_held[4] = 0
	if _flat(pip.global_position, b) < 2.0:
		_stop()
		return
	# PIP in plain sight with room for the suit on the way: straight at it, as a kid does; its tracks only round
	# things (they squeezed past the dish's mount, where the suit does not fit, 14 Nov)
	var body: CollisionShape3D = player.body.find_children("*", "CollisionShape3D", false, false)[0]
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = body.shape
	q.collision_mask = 2 | 4 | 64
	q.exclude = [player.body.get_rid()]
	q.transform = Transform3D(Basis(), b + body.position + Vector3.UP * 0.1)
	q.motion = (pip.global_position - b) * Vector3(1, 0, 1)
	q.motion -= q.motion.normalized() * 1.0
	if player.get_world_3d().direct_space_state.cast_motion(q)[0] >= 1.0:
		crumbs = [b, pip.global_position]
		_steer(pip.global_position, 2.0)
		return
	# a second without getting anywhere (a lamp post on the straight line to PIP's tracks): a kid steps round it
	var f := Engine.get_physics_frames()
	if f < int(_held[2]):
		_steer(_held[3])
		return
	if _flat(b, _held[0]) > 0.2:
		_held[0] = b
		_held[1] = f
	elif f - int(_held[1]) > 60:
		_held[4] = int(_held[4]) + 1
		if int(_held[4]) > 1 and crumbs.size() > 1:
			# PIP's track squeezed past something the suit does not fit by (the dish's mount, 14 Nov): a kid cuts on
			# to the next of its tracks
			crumbs.pop_front()
			_held[4] = 0
		var way: Vector3 = crumbs[0] - b
		_held[3] = b + Vector3(-way.z, 0.0, way.x).normalized() * 1.2
		_held[2] = f + 60
		_held[1] = f
	_steer(crumbs[0])


## After PIP like a kid: toward it, stopping `near` short.
func _follow(near: float) -> void:
	var b: Vector3 = player.body.global_position
	if Vector2(b.x, b.z).length() < 4.0:  # in or by HAB 1: out through the hatch first
		_steer(Vector3(4.445, 0.0, -0.704), 0.5)
	else:
		_steer(pip.global_position, near)


## To the use spot `kind` near `at`, then the use itself (aim is interact_test's job).
func _use(kind: String, at: Vector3) -> void:
	if _flat(at, player.body.global_position) > 2.0:
		_steer(at, 1.5)
		return
	_stop()
	if used_at >= 0 and Engine.get_physics_frames() - used_at < 60 * 8:
		return  # one use, and again only if it has long gone without the beat seeing it
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


## A point in HAB 1's own frame (its door on -Z): the bot's "still in HAB 1" tests, written for the base before it
## turned to face the sunrise (tools/rotate_base.py), in the frame that turned with it.
func _hab_l(b: Vector3) -> Vector3:
	return world.items.hab1.to_local(b)
