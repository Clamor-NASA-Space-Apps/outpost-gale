extends "res://addons/forge/test.gd"
## The commander's body and the tight power budget (sim/sim.gd): godot --headless --path . -s tests/body_test.gd
## A kid who meets every need loses nothing in Sols 1 to 10. Each need left alone costs health, and top_causes()
## names it. A leak empties the tank until the valve is closed. Every machine on in a dust storm ends in a cold base.

const Sim := preload("res://sim/sim.gd")

var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim.json"))
var B: Dictionary = base.body
var SOL: float = base.clock.sol_h.value
var TICK: float = base.clock.step_h.value  # a need that empties inside a solver step is charged for that whole step


## The shipped rules after Sol 1's lesson: the body switched on.
func body() -> Sim:
	var s := Sim.new()
	s.apply("body_on")
	return s


## Awake hours for a kid who looks after themselves: a drink and a meal whenever one is half gone.
func live(s: Sim, hours: float) -> void:
	for i in int(hours * 2.0):
		if s.body_water < 0.5:
			s.use("drink")
		if s.body_food < 0.5:
			s.use("eat")
		s.run(0.5)


func near(a: float, b: float, tol: float, what: String) -> bool:
	return check(absf(a - b) <= tol, "%s: %.5f, expected %.5f" % [what, a, b])


func play() -> bool:
	_off()
	_cared_for()
	_air()
	_thirst()
	_needs()
	_dust()
	_flare()
	_leak()
	_power()
	return true


## Before the story's lesson (knob `body`), and asleep, the body waits.
func _off() -> void:
	var s := Sim.new()
	check(not s.state().body and not s.knobs.greenhouse, "the body and the garden's lamps start off")
	s.eva(true)
	s.dust_hit()
	s.run(12.0)
	var st := s.state()
	check(st.health == 100.0 and st.body_water == 1.0 and st.suit_air == 1.0 and st.suit_dust == 0.0 and st.hurt == "",
		"nothing of the body moves before body_on: %s" % [st])
	s.apply("body_on")
	s.use("sleep_night")
	s.skip_sols(2)
	s.use("nap")
	check(s.body_food == 1.0 - B.sleep_food.value and s.suit_air_min == 480.0 and s.health == 100.0,
		"nor asleep: a night costs its breakfast and no more (food %.2f, suit %.0f)" % [s.body_food, s.suit_air_min])


## (a) Ten sols of a kid who eats, drinks, sleeps, fills the suit, brushes it and shelters from the flare.
func _cared_for() -> void:
	var s := body()
	var low := 100.0
	var battery := 100.0
	for sol in range(1, 11):
		# breakfast, a morning outside, lunch, an afternoon outside, an evening in, bed at 22:00
		for part: Array in [[0.5, false], [4.0, true], [3.0, false], [4.0, true], [4.0, false]]:
			var flare: bool = s.active.any(func(e: Dictionary) -> bool: return e.kind == "flare")
			if flare != s.knobs.sheltered:
				s.apply("shelter_in" if flare else "shelter_out")
			s.eva(part[1] and not flare)
			if s.outside:
				s.use("refill_air")
			live(s, part[0])
			if s.outside:
				s.use("brush")
			low = minf(low, s.health)
			battery = minf(battery, s.state().battery_pct)
		s.eva(false)
		s.use("sleep_night")
		check(s.sol == sol + 1 and s.health == 100.0 and s.failing().is_empty(),
			"Sol %d's morning: whole and nothing failing (health %.1f, %s)" % [s.sol, s.health, s.failing()])
	var harms := s.causes.filter(func(e: Dictionary) -> bool: return e.kind == "harm").map(func(e: Dictionary) -> String: return e.id)
	check(harms.all(func(id: String) -> bool: return id == "flare"), "only the flare cost anything, and the shelter halved it: %s" % [harms])
	check(low >= 85.0 and battery >= 99.0, "health never under 85 (%.1f), the battery full with no machine on (%.1f%%)" % [low, battery])
	check(s.tau > 8.0, "and Sol 10 was the dust storm (tau %.2f)" % s.tau)


## (b) Outside with the suit's air gone: health is lost in under a game hour.
func _air() -> void:
	var s := body()
	s.suit_air_min = 0.0
	s.run(1.0)
	check(s.health == 100.0 and s.state().hurt == "", "an empty suit inside the base hurts nobody")
	s.eva(true)
	check(s.state().hurt == "air", "outside it is the worst thing happening: %s" % s.state().hurt)
	var h := 0.0
	while s.health > 0.0 and h < 3.0:
		s.run(0.05)
		h += 0.05
	check(h < 1.0 and s.failing() == ["health"], "health 0 after %.2f game hours: %s" % [h, s.failing()])
	var top := s.top_causes()
	check(top[0].id == "air" and top[0].label == B.labels.air and is_equal_approx(top[0].effect.health, -100.0),
		"and the causes name it: %s" % [top])
	s = body()
	s.eva(true)
	s.suit_air_min = 15.0
	s.run(0.75)
	s.use("refill_air")
	var was := s.health
	s.run(1.0)
	check(was < 100.0 and s.health == was and s.state().suit_air > 0.8, "a fill stops the fall (%.1f, then %.1f)" % [was, s.health])


## (c) Never drinking costs health within the sol; a drink stops it and a night's sleep mends some.
func _thirst() -> void:
	var s := body()
	check(s.state().weak == 0.0, "fed and watered, the commander is not weak")
	for i in 22:
		s.use("eat")
		s.run(0.5)
	check(s.health < 100.0 and s.state().hurt == "thirst" and s.state().body_water == 0.0, "eleven hours without a drink cost health (%.1f)" % s.health)
	near(100.0 - s.health, (11.0 - B.water_h.value) * B.hurt_per_h.thirst, TICK * B.hurt_per_h.thirst, "%d points for each hour past empty" % B.hurt_per_h.thirst)
	check(s.state().weak == 1.0, "an empty gauge: weak is 1, for the hero's walk (%.2f)" % s.state().weak)
	# the whole fall: from an empty water gauge the mission is lost within 6.25 game hours (100 / hurt_per_h.thirst)
	var dry := body()
	dry.body_water = 0.0
	dry.run(6.0)
	check(dry.health > 0.0 and dry.failing().is_empty(), "six hours dry: still alive (%.1f)" % dry.health)
	dry.run(0.25 + TICK)
	check(dry.health == 0.0 and dry.failing() == ["health"], "an empty water gauge loses the mission within 6.25 game hours (%.1f, %s)" % [dry.health, dry.failing()])
	# up all night: the clock waits at dawn for a sleep, the body does not
	var late := body()
	live(late, 24.0)
	late.run(1.0)
	check(late.awake_left() == 0.0, "past the night the clock waits for a sleep")
	late.body_water = 0.0
	late.body_food = 0.0
	var at := late.health
	late.run(1.0)
	near(at - late.health, B.hurt_per_h.thirst + B.hurt_per_h.hunger + B.hurt_per_h.tired, 1e-6, "and thirst, hunger and tiredness still cost health while it waits")
	# weak follows Crew health under body.weak_health
	var hurt := body()
	hurt.health = B.weak_health.value
	check(hurt.state().weak == 0.0, "health at %d: not weak yet" % B.weak_health.value)
	hurt.health = B.weak_health.value * 0.5
	near(hurt.state().weak, 0.5, 1e-6, "half of it: weak 0.5")
	hurt.knobs.body = false
	check(hurt.state().weak == 0.0, "the body's needs off (Sol 1): never weak")
	var top := s.top_causes()
	check(top.size() == 1 and top[0].id == "thirst" and top[0].label == B.labels.thirst, "the causes name it, in one line for the sol: %s" % [top])
	s.use("drink")
	var was := s.health
	s.run(1.0)
	check(s.health == was and s.state().hurt == "", "a drink stops the fall")
	s.use("sleep_night")
	near(s.health, was + B.heal_sleep.value, 1e-6, "a night's sleep mends")
	near(s.body_water, 1.0 - 1.0 / B.water_h.value - B.sleep_water.value, 1e-6, "and the morning wants a drink")
	check(s.body_rest == 1.0, "rested")
	s.run(8.0)
	check(s.causes.filter(func(e: Dictionary) -> bool: return e.id == "thirst").size() == 2, "a new sol's thirst gets its own line")


## Hunger and tiredness the same way, hurrying drinks more, and the HUD is told the worst of them.
func _needs() -> void:
	var s := body()
	s.run(B.food_h.value + 1.0)
	s.use("drink")
	near(100.0 - s.health, (B.food_h.value + 1.0 - B.water_h.value) * B.hurt_per_h.thirst + B.hurt_per_h.hunger,
		TICK * (B.hurt_per_h.thirst + B.hurt_per_h.hunger), "an hour hungry, on top of the thirst")
	check(s.state().hurt == "hunger" and is_equal_approx(s.use("eat").body_food, 1.0), "a meal fills it")
	s = body()
	live(s, B.rest_h.value + 1.0)
	near(100.0 - s.health, B.hurt_per_h.tired, TICK * B.hurt_per_h.tired, "an hour past %d awake costs" % B.rest_h.value)
	s.body_water = 0.0
	check(s.state().hurt == "thirst", "the HUD hears the need that costs most: %s" % s.state().hurt)
	s = body()
	s.effort = B.effort_hurry.value
	s.run(1.0)
	near(1.0 - s.body_water, B.effort_hurry.value / B.water_h.value, 1e-6, "hurrying sweats the water out faster (row 123)")


## Dust on the suit: a devil coats it, a storm's sky does slowly, and it must be brushed off before a moment inside.
func _dust() -> void:
	var s := body()
	s.eva(true)
	s.run(2.0)
	check(s.suit_dust == 0.0, "a clear sky leaves the suit clean")
	s.dust_hit()
	s.run(1.0)
	check(s.suit_dust == 1.0 and s.health == 100.0, "a dust devil coats it; outside that costs nothing")
	s.use("brush")
	s.eva(false)
	s.run(1.0)
	check(s.suit_dust == 0.0 and s.health == 100.0, "brushed off, it comes inside clean")
	s.dust_hit()
	s.run(B.dust_grace_h.value * 0.5)
	check(s.health == 100.0, "inside and dusty: a moment's grace")
	s.run(1.0)
	near(100.0 - s.health, B.hurt_dust.value, 1e-6, "then the dust is in the cabin, once")
	check(s.suit_dust == 0.0 and s.top_causes()[0].label == B.labels.dust, "and the causes name it")
	s.start("dust_storm")
	s.step(base.events.dust_storm.rise_h)
	s.eva(true)
	s.use("refill_air")
	s.run(1.0)
	check(s.suit_dust >= B.dusty.value, "an hour out in the storm leaves the suit dusty (%.2f)" % s.suit_dust)


## An unsheltered flare day costs health; the shelter halves it (row 90).
func _flare() -> void:
	var cost := {}
	for shelter: bool in [false, true]:
		var s := body()
		if shelter:
			s.apply("shelter_in")
		s.start("flare_x12")
		live(s, 10.0)
		cost[shelter] = 100.0 - s.health
		check(s.state().hurt == "flare", "the HUD is told it is the solar storm")
	near(cost[false], B.hurt_per_msv.value * 8.1 * 10.0 / 24.0, 1e-6, "ten hours of the X12 flare in the open")
	near(cost[true], cost[false] * 0.5, 1e-6, "half of it in the water shelter")


## (d) A leak drains the tank until the valve is closed; left alone it ends the mission.
func _leak() -> void:
	var s := Sim.new()
	s.start("o2_leak")
	var rate: float = base.events.o2_leak.o2_kg_h
	check(s.state().leak and s.state().events.is_empty() and s.causes[-1].label == "Oxygen leak",
		"the state says `leak`; it is no data event, so the HUD's ARCHIVED list leaves it out")
	near(-s.step(1.0).o2_kg, rate + 2 * 0.84 / 24.0, 1e-6, "an hour of it, on top of what the crew breathes")
	var shut := Sim.new()
	shut.load(s.save())
	s.step(12.0)
	check(s.o2_kg == 0.0 and s.failing() == ["o2_kg"], "left alone the tank is empty within half a sol: %s" % [s.failing()])
	check(s.top_causes()[0].id == "o2_leak", "and the leak leads the causes")
	shut.use("o2_valve")
	check(not shut.state().leak and shut.active.is_empty(), "the valve closes it")
	near(-shut.step(1.0).o2_kg, 2 * 0.84 / 24.0, 1e-6, "and the tank falls only by the crew's breathing again")
	check(shut.o2_kg < base.start.o2_kg.value - rate, "what leaked is gone")


## (e) Power is tight: a clear night with every machine on shows on the meter, the same in a dust storm drains the
## battery within about two sols and the cold then costs health, and the garden's lamps off holds it.
func _power() -> void:
	var on := ["o2_maker_on", "recycler_on", "greenhouse_on"]
	var s := body()
	for c: String in on:
		s.apply(c)
	live(s, 15.5)
	s.use("sleep_night")
	var dawn: float = s.state().battery_pct
	live(s, 7.0)
	check(dawn < 60.0 and dawn > 0.0 and s.state().battery_pct == 100.0,
		"a clear night with everything on drains the battery to %.0f%%, and the sun fills it by early afternoon (%.0f%%)" % [dawn, s.state().battery_pct])
	var cold_h := {}
	for garden: bool in [true, false]:
		s = body()
		for c: String in on.slice(0, 3 if garden else 2):
			s.apply(c)
		s.hour = 21.0  # the story's storm starts on a night (data/sim.json schedule)
		s.start("dust_storm")
		var t0 := s.now()
		var mornings := 100.0
		for i in 3:
			for awake: bool in [true, false]:  # an hour to bed that first night, then whole days
				if awake:
					live(s, 1.0 if i == 0 else 15.5)
				else:
					s.use("sleep_night")
				if s.state().cold and not cold_h.has(garden):
					cold_h[garden] = s.now() - t0
			mornings = minf(mornings, s.health)
		if garden:
			check(cold_h.get(true, 99.0) <= 2.0 * SOL, "garden lit in the storm: the battery is empty within two sols (the kid meets it %.1f h in)" % cold_h.get(true, -1.0))
			var top := s.top_causes().map(func(e: Dictionary) -> String: return e.id)
			check(mornings < 100.0 and "cold" in top, "and the cold costs health (a morning at %.1f); causes: %s" % [mornings, top])
			var was := s.health
			s.apply("greenhouse_off")
			live(s, 6.0)
			check(not s.state().cold and s.state().net_kw > 0.0, "lamps off, the base warms again by noon (net %.1f kW)" % s.state().net_kw)
			check(was > 0.0 and s.health == was, "and the fall stops (%.1f from %.1f)" % [s.health, was])
		else:
			check(not cold_h.has(false) and mornings == 100.0 and s.state().battery_pct > 90.0,
				"garden dark in the storm: the battery holds (%.0f%%) and nobody is cold" % s.state().battery_pct)
