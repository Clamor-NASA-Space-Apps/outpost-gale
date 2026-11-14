extends "res://addons/forge/test.gd"
## The rules (sim/sim.gd) against their sources: godot --headless --path . -s tests/sim_test.gd
## Each rate over a simulated sol matches its data/sim.json row, the heater draws more at night, a flare doses half
## in the shelter, a storm dims the sun, the sleep ledger adds up over 5 sols, and top_causes() ranks what cost most.

const Sim := preload("res://sim/sim.gd")
const KEYS := ["sol", "hour", "o2_kg", "water_kg", "food_kg", "battery_pct", "power_in_kw", "solar_in_kw", "power_out_kw", "dose_msv",
	"suit_air_min", "panel_dust", "tau", "events", "failing"]

var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim.json"))
var SOL: float = base.clock.sol_h.value


## A sim with every machine off, no schedule and no dust: only the crew's own needs move the meters.
func quiet() -> Sim:
	var data := base.duplicate(true)
	for k: String in ["o2_maker", "moxie", "greenhouse", "recycler"]:
		data.knobs[k].value = false
	data.schedule.list = []
	data.power.dust_per_sol.value = 0.0
	return Sim.new(data)


func near(a: float, b: float, tol: float, what: String) -> bool:
	return check(absf(a - b) <= tol, "%s: %.5f, expected %.5f" % [what, a, b])


func play() -> bool:
	_rates()
	_power()
	_flare()
	_storm()
	_ledger()
	_causes()
	_uses()
	_awake()
	await _node()
	return true


func _rates() -> void:
	var s := quiet()
	check(s.state().keys() == KEYS, "state() has exactly the HUD's keys: %s" % [s.state().keys()])
	var r := s.step(SOL)
	var days := SOL / 24.0
	var p: Dictionary = base.per_person_day
	near(-r.o2_kg, 2 * p.o2_kg.value * days, 1e-6, "O2 over a sol, 2 crew x 0.84 kg/d (row 23)")
	near(-r.water_kg, 2 * p.water_kg.value * days, 1e-6, "water over a sol, 2 x 3.217 kg/d (row 25)")
	near(-r.food_kg, 2 * p.food_kg.value * days, 1e-6, "food over a sol, 2 x 2.39 kg/d (row 112)")
	near(r.dose_msv, p.dose_msv.value * days, 1e-6, "dose over a sol, 0.67 mSv/d (row 32)")
	check(s.sol == 2 and is_equal_approx(s.hour, base.clock.start_hour.value), "a sol of 24 h 39 min brings the same hour back")
	# the oxygen maker: 5.4 kg/d for 3.573 kW, 1.125 kg of water per kg (rows 74, 75, 106)
	var m := quiet()
	m.apply("o2_maker_on")
	r = m.step(SOL)
	near(r.o2_kg, (5.4 - 2 * 0.84) * days, 1e-6, "oxygen maker's net O2 over a sol")
	near(-r.water_kg, (2 * 3.217 + 5.4 * 1.125) * days, 1e-6, "oxygen maker's water over a sol")
	near(m.power_out_kw - quiet().power_out_kw, 3.573, 0.05, "oxygen maker draws 3.573 kW")
	# water recycling returns 98% of what the crew used (rows 26, 127)
	var w := quiet()
	w.apply("recycler_on")
	r = w.step(SOL)
	near(-r.water_kg, 2 * 3.217 * days * 0.02, 1e-6, "recycled water over a sol")


func _power() -> void:
	var s := quiet()
	s.knobs.reactor = false
	s.hour = 0.0
	s._power()
	check(s.power_in_kw == 0.0, "no solar at midnight")
	# a clean field in clear sky makes InSight's 0.658 kWh per m2 a sol (row 160)
	var r := s.step(SOL)
	near(r.energy_in_kwh, base.power.panel_m2.value * 0.658, 0.5, "solar energy over a clear sol")
	s = quiet()
	near(s.n("power", "reactor_kw"), 10.0, 0.0, "reactor 10 kWe (row 21)")
	# night heater: UA x (21 C - outside), outside -70 C before dawn and 0 C mid-afternoon (rows 173, 174)
	s.hour = 5.5 * SOL / 24.0
	var night := s.heater_kw()
	near(s.outside_c(), -70.0, 1e-6, "coldest at 05:30 local")
	s.hour = 14.5 * SOL / 24.0
	var day := s.heater_kw()
	near(s.outside_c(), 0.0, 1e-6, "warmest at 14:30 local")
	near(night, 0.022 * 91.0, 1e-6, "night heater draw")
	check(night > 4.0 * day, "the heater draws over 4x more at night (%.2f kW) than mid-afternoon (%.2f kW)" % [night, day])
	s.hour = 3.0 * SOL / 24.0
	s._power()
	var dark := s.power_out_kw
	s.hour = 13.0 * SOL / 24.0
	s._power()
	check(dark > s.power_out_kw, "the base draws more at night than at noon")
	# dust: 0.2% a sol (row 180), and cleaning a wing gives some of it back
	s = Sim.new()
	var d0 := s.panel_dust
	s.knobs.reactor = true
	s.d.schedule.list = []
	s.step(SOL * 10)
	near(s.panel_dust - d0, 0.02, 1e-6, "panels gather 0.2% of dust a sol")
	s.hour = 12.0 * SOL / 24.0
	s._power()
	var dusty := s.power_in_kw
	var r2 := s.use("clean_panel")
	check(r2.get("panel_dust", 0.0) < 0.0 and s.power_in_kw > dusty, "cleaning a panel lifts the power at once")
	# an empty battery: loads are cut to the power there is and the meter says so
	s = quiet()
	s.knobs.reactor = false
	s.battery_kwh = 1.0
	s.hour = 0.0
	s.step(2.0)
	check("battery_pct" in s.failing(), "a night with no reactor and an empty battery fails the battery")


func _flare() -> void:
	var out := quiet()
	var shel := quiet()
	shel.apply("shelter_in")
	for s: Sim in [out, shel]:
		s.start("flare_x12")
	var ev: Dictionary = out.state().events[0]
	check(ev.id == "flare_x12" and ev.live == false and "ARCHIVED" in ev.source, "a flare is labelled ARCHIVED with its source")
	var a := out.step(30.0)
	var b := shel.step(30.0)
	var bg: float = 0.67 * 30.0 / 24.0
	near(a.dose_msv - bg, 8.1, 1e-6, "an unsheltered flare gives Curiosity's 8.1 mSv (row 37)")
	near(b.dose_msv - bg, 8.1 * 0.5, 1e-6, "the water shelter halves it (row 90)")
	check(out.state().events.is_empty(), "the flare ends after its 24 h")
	var noaa := quiet()
	noaa.start("flare_noaa")
	check("2026-11-07" in noaa.state().events[0].source, "the NOAA flare carries its archive date")
	# the schedule fires on its own: data/sim.json's first event
	var s := Sim.new()
	var first: Dictionary = s.d.schedule.list[0]
	s.step((first.sol - 1) * SOL + first.hour - s.hour + 0.5)
	check(s.state().events.size() == 1 and s.state().events[0].id == first.event, "the schedule starts %s on sol %d" % [first.event, first.sol])


func _storm() -> void:
	var s := quiet()
	s.knobs.reactor = false
	s.start("dust_storm")
	var e: Dictionary = base.events.dust_storm
	s.step(e.rise_h)
	near(s.tau, 8.5, 0.05, "the storm peaks at tau 8.5 (row 182)")
	s.hour = 12.0 * SOL / 24.0
	s._power()
	var storm := s.power_in_kw
	var clear := s.solar_kw(1.0)
	near(storm / clear, s.sky_light(8.5), 1e-6, "power at noon falls with the sky's light")
	near(s.sky_light(5.0), 0.35, 1e-6, "tau 5 lets through 35% (NTRS 20160011275)")
	check(storm < 0.2 * clear, "a tau 8.5 storm leaves under a fifth of the sun")
	s.step(43.0 * SOL)
	near(s.tau - 1.0, 7.5 * exp(-1.0), 0.15, "the haze e-folds in 43 sols")


func _ledger() -> void:
	var s := quiet()
	var l := s.skip_sols(5)
	var days := 5.0 * SOL / 24.0
	check(l.sols == 5 and s.sol == 6, "skip_sols(5) moves five sols on")
	near(-l.o2_kg, 2 * 0.84 * days, 1e-5, "ledger O2 over 5 sols")
	near(-l.water_kg, 2 * 3.217 * days, 1e-5, "ledger water over 5 sols")
	near(-l.food_kg, 2 * 2.39 * days, 1e-5, "ledger food over 5 sols")
	check(l.energy_in_kwh > 0.0 and l.energy_out_kwh > 0.0, "ledger counts the energy made and used")


func _causes() -> void:
	var s := quiet()
	s.apply("moxie_on")  # 0.3 kW
	s.apply("o2_maker_on")  # 3.6 kW and 6 kg of water a day
	s.apply("heater_low")  # saves power: never a cause
	s.apply("greenhouse_on")  # 5.67 kW
	s.start("flare_x12")
	s.skip_sols(3)
	var top := s.top_causes(3)
	var ids := top.map(func(e: Dictionary) -> String: return e.id)
	check(top.size() == 3, "three causes")
	check(ids[0] == "greenhouse_on" and ids[1] == "o2_maker_on", "the hungriest choices lead: %s" % [ids])
	check(not ("heater_low" in ids) and not ("moxie_on" in ids), "a saving and a small cost stay out: %s" % [ids])
	check(top[0].harm >= top[1].harm and top[1].harm >= top[2].harm, "ranked by harm")
	check(top[0].effect.energy_kwh < 0.0, "each cause carries its effect")


func _uses() -> void:
	var s := quiet()
	for id: String in base.uses:
		if id[0] != "_" and id not in ["sleep_night", "nap", "clean_panel", "harvest", "plant"]:
			check(s.use(id).is_empty(), "use('%s') changes nothing the daily rates already count" % id)
	s.hour = 22.0
	var sol := s.sol
	s.use("sleep_night")
	check(s.sol == sol + 1 and is_equal_approx(s.hour, 6.5), "a night's sleep wakes at 06:30 the next sol")
	var h := s.hour
	s.use("nap")
	near(s.hour - h, 20.0 / 60.0, 1e-3, "a nap takes 20 minutes")
	s.eva(true)
	s.step(1.0)
	near(s.suit_air_min, 420.0, 1e-6, "an hour out uses 60 of the suit's 480 minutes (row 135)")
	s.suit_air_min = 0.0
	check("suit_air_min" in s.failing(), "an empty suit outside fails")
	s.eva(false)
	check(s.suit_air_min == 480.0 and s.failing().is_empty(), "back inside the suit is refilled")
	# the greenhouse's lettuce: 33 days (row 29), a 15 g salad each (row 121)
	s.crop_age_days = 30.0
	check(s.use("harvest").is_empty(), "lettuce is not ready before 33 days")
	s.skip_sols(3)
	near(s.use("harvest").get("food_kg", 0.0), 0.03, 1e-6, "a harvest is two small salads")
	s.o2_kg = 0.01
	s.step(1.0)
	check("o2_kg" in s.failing(), "failing() lists an empty meter")


## Up all night: the rules run on only to just short of the next sol's 06:30 wake and wait there, a nap cannot pass it,
## and the night's sleep then lands on that next sol, not the one after (14 Nov playtest: sleep skipped sols).
func _awake() -> void:
	var s := quiet()
	var wake: float = base.clock.wake_hour.value
	var wait: float = base.clock.wait_before_wake_h.value
	s.run(40.0)
	check(s.sol == 2 and near(s.hour, wake - wait, 1e-6, "awake through the night, the rules wait before the 06:30 wake"), "and on the next sol (%d)" % s.sol)
	s.run(5.0)
	s.use("nap")
	check(s.sol == 2 and s.hour < wake, "nor do more hours or a nap pass the wake (%.3f)" % s.hour)
	s.use("sleep_night")
	check(s.sol == 2 and near(s.hour, wake, 1e-6, "the sleep wakes at 06:30"), "on the next sol, none skipped (%d)" % s.sol)
	s.run(10.0)
	check(s.sol == 2 and s.hour > wake + 9.0, "a new day runs on as usual")
	s.skip_sols(3)
	s.run(40.0)
	check(s.sol == 6 and s.hour < wake, "after a skip the wait is the morning after the skip (sol %d)" % s.sol)


func _node() -> void:
	var node: Node = load("res://sim/sim_node.gd").new()
	var got: Array[Dictionary] = []
	node.changed.connect(func(st: Dictionary) -> void: got.append(st))
	root.add_child(node)
	var h0: float = node.sim.hour
	await frames(30)
	check(got.size() > 0 and node.sim.hour > h0, "sim_node steps the rules from real time and tells the HUD")
	node.apply("shelter_in")
	check(got[-1].keys() == KEYS, "a choice through the node is told at once")
	node.queue_free()
