extends RefCounted
## The rules of Outpost Gale: meters, the sol clock, choices, use spots, events and the cause log.
## Pure data in, numbers out: no nodes, no scene tree (tests/sim_test.gd runs it headless). Every number comes from
## data/sim.json, which names its source. The rules clock counts Earth hours in a 24 h 39 min sol; the look clock
## (world/sky_clock.gd) counts 24 local hours, so local = hour * 24 / sol_h.

const DATA := "res://data/sim.json"
const METERS := ["o2_kg", "water_kg", "food_kg"]

var d: Dictionary
var sol := 1
var hour := 0.0
var o2_kg := 0.0
var water_kg := 0.0
var food_kg := 0.0
var battery_kwh := 0.0
var power_in_kw := 0.0
var solar_in_kw := 0.0  # the panels' share of power_in_kw (the HUD shows a brushed wing's gain)
var power_out_kw := 0.0
var dose_msv := 0.0
var suit_air_min := 0.0
var outside := false
var panel_dust := 0.0
var tau := 1.0
var crop_age_days := 0.0
var knobs := {}
var active: Array[Dictionary] = []  # running events: the template plus t0 (absolute hours) and log index
var causes: Array[Dictionary] = []  # the cause log: {sol, hour, id, kind, label, effect: {meter: delta}}
var energy_in_kwh := 0.0  # running totals for the sleep ledger
var energy_out_kwh := 0.0
var _cause := {}  # knob -> log index of the choice that last set it
var _fired := {}  # schedule index -> true
var _rng := RandomNumberGenerator.new()


func _init(data: Dictionary = {}) -> void:
	d = data if data else JSON.parse_string(FileAccess.get_file_as_string(DATA))
	sol = int(n("clock", "start_sol"))
	hour = n("clock", "start_hour")
	for m: String in METERS:
		set(m, n("start", m))
	battery_kwh = n("power", "battery_kwh") * n("start", "battery_pct") / 100.0
	panel_dust = n("start", "panel_dust")
	crop_age_days = n("start", "crop_age_days")
	suit_air_min = n("suit", "full_min")
	tau = n("power", "tau_clear")
	for k: String in d.knobs:
		if k[0] != "_":
			knobs[k] = d.knobs[k].value
	_rng.seed = int(n("seed"))
	_power()


## A sourced number: n("clock", "sol_h") reads d.clock.sol_h.value.
func n(a: String, b := "") -> float:
	var e: Variant = d[a] if b == "" else d[a][b]
	return float(e.value if e is Dictionary else e)


func now() -> float:
	return (sol - 1) * n("clock", "sol_h") + hour


func state() -> Dictionary:
	var ev: Array[Dictionary] = []
	for e in active:
		ev.append({"id": e.id, "label": e.label, "source": e.source, "live": e.live})
	return {"sol": sol, "hour": hour, "o2_kg": o2_kg, "water_kg": water_kg, "food_kg": food_kg,
		"battery_pct": 100.0 * battery_kwh / n("power", "battery_kwh"), "power_in_kw": power_in_kw, "solar_in_kw": solar_in_kw,
		"power_out_kw": power_out_kw, "dose_msv": dose_msv, "suit_air_min": suit_air_min, "panel_dust": panel_dust,
		"tau": tau, "events": ev, "failing": failing()}


## Meters at zero. Winning and losing are the story's flow; this only says what ran out.
func failing() -> Array[String]:
	var out: Array[String] = []
	for m: String in METERS:
		if get(m) <= 0.0:
			out.append(m)
	if battery_kwh <= 0.0:
		out.append("battery_pct")
	if outside and suit_air_min <= 0.0:
		out.append("suit_air_min")
	return out


## A choice from data (`choices`): sets knobs. Its running cost is charged to its log entry as time passes.
func apply(choice_id: String) -> Dictionary:
	if not d.choices.has(choice_id):
		push_error("sim: no choice '%s' in data/sim.json" % choice_id)
		return {}
	var c: Dictionary = d.choices[choice_id]
	var before := state()
	var i := _log(choice_id, "choice", c.label)
	for k: String in c.get("set", {}):
		knobs[k] = c.set[k]
		_cause[k] = i
	_power()
	return _diff(before, state())


## A use spot's hook (`uses`): most have no effect, because the daily rates already count them.
func use(action_id: String) -> Dictionary:
	if not d.uses.has(action_id):
		push_error("sim: no use '%s' in data/sim.json" % action_id)
		return {}
	var u: Dictionary = d.uses[action_id]
	var before := state()
	if u.has("clean"):
		var was := panel_dust
		panel_dust *= 1.0 - float(u.clean)
		causes[_log(action_id, "use", u.label)].effect["panel_dust"] = panel_dust - was
	if u.has("plant"):
		crop_age_days = 0.0
	if u.has("harvest"):
		if crop_age_days < n("crop", "ready_days"):
			return {}
		crop_age_days = 0.0
		food_kg += n("crop", "harvest_food_kg")
	if u.has("to_hour"):
		var h := fposmod(n("clock", u.to_hour) - hour, n("clock", "sol_h"))
		return step(h if h > 1e-6 else n("clock", "sol_h"))
	if u.has("advance_h"):
		return step(n("clock", u.advance_h))
	_power()
	return _diff(before, state())


## Out on an EVA, the suit's air runs down; back in, it is refilled.
func eva(on: bool) -> void:
	outside = on
	if not on:
		suit_air_min = n("suit", "full_min")


## Sleep through `count` sols; the ledger says what the base used meanwhile (the sleep card).
func skip_sols(count: int) -> Dictionary:
	var ledger := step(count * n("clock", "sol_h"))
	ledger["sols"] = count
	return ledger


## Advance the rules by `hours` of game time. Returns what changed: each meter's delta, and the energy made and used.
func step(hours: float) -> Dictionary:
	var before := state()
	var e_in := energy_in_kwh
	var e_out := energy_out_kwh
	var left := hours
	var dt_max := n("clock", "step_h")
	var sol_h := n("clock", "sol_h")
	while left > 1e-9:
		var dt := minf(left, dt_max)
		_tick(dt)
		left -= dt
		hour += dt
		if hour >= sol_h - 1e-9:
			hour = maxf(hour - sol_h, 0.0)
			sol += 1
			_new_sol()
		_events()
	var out := _diff(before, state())
	out["energy_in_kwh"] = energy_in_kwh - e_in
	out["energy_out_kwh"] = energy_out_kwh - e_out
	return out


## The `count` log entries that cost the base most, each weighed as a share of its meter's starting stock.
func top_causes(count := 3) -> Array[Dictionary]:
	var scale: Dictionary = d.harm_scale
	var ranked: Array[Dictionary] = []
	for e in causes:
		var harm := 0.0
		for m: String in e.effect:
			if scale.has(m):
				var v: float = e.effect[m]
				harm += (maxf(v, 0.0) if m == "dose_msv" else maxf(-v, 0.0)) / float(scale[m])
		if harm > 0.0:
			var r := e.duplicate(true)
			r["harm"] = harm
			ranked.append(r)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.harm > b.harm)
	return ranked.slice(0, count)


## Local solar hour (0 to 24) for the sun and the weather curves.
func local_hour() -> float:
	return hour * 24.0 / n("clock", "sol_h")


## Solar power now, in kW, at sky opacity `t`. Calibrated so a clean field in clear sky makes InSight's yield per m2.
func solar_kw(t: float) -> float:
	var sol_h := n("clock", "sol_h")
	# a half-sine sun from 06:00 to 18:00 local: its integral over a sol is sol_h / PI hours of peak
	var shape := maxf(sin(PI * (local_hour() - 6.0) / 12.0), 0.0)
	var peak := n("power", "panel_m2") * n("power", "yield_kwh_m2_sol") * PI / sol_h
	return peak * shape * (1.0 - panel_dust) * sky_light(t)


## Share of clear-sky light at opacity `t`: 1 at tau_clear, storm_light at tau_storm, the same exponential beyond.
func sky_light(t: float) -> float:
	var c := n("power", "tau_clear")
	var k := log(1.0 / n("power", "storm_light")) / (n("power", "tau_storm") - c)
	return exp(-k * maxf(t - c, 0.0))


## Air outside, deg C: a cosine from the pre-dawn low to the afternoon high and back.
func outside_c() -> float:
	var lo := n("power", "outside_low_c")
	var hi := n("power", "outside_high_c")
	var lo_h := n("power", "low_hour")
	var rise := n("power", "high_hour") - lo_h
	var x := fposmod(local_hour() - lo_h, 24.0)
	var f := x / rise if x < rise else 1.0 - (x - rise) / (24.0 - rise)
	return lo + (hi - lo) * (1.0 - cos(PI * f)) / 2.0


func heater_kw() -> float:
	return n("power", "heater_ua_kw_per_k") * maxf(float(knobs.heater_c) - outside_c(), 0.0)


## Sets power_in_kw and power_out_kw for now and returns the device loads.
func _power() -> Dictionary:
	var loads := {"hab": n("power", "hab_kw"), "heater": heater_kw()}
	for dev: String in d.devices:
		if knobs.get(dev, false):
			loads[dev] = float(d.devices[dev].kw)
	power_out_kw = 0.0
	for k: String in loads:
		power_out_kw += loads[k]
	solar_in_kw = solar_kw(tau)
	power_in_kw = solar_in_kw + (n("power", "reactor_kw") if knobs.reactor else 0.0)
	return loads


func _tick(dt: float) -> void:
	var day := dt / 24.0
	var crew := n("crew")
	var loads := _power()
	# the battery takes the difference; when it runs dry, every load gets the share of power there is
	var cap := n("power", "battery_kwh")
	var net := (power_in_kw - power_out_kw) * dt
	var served := 1.0
	if battery_kwh + net < 0.0:
		served = clampf((battery_kwh / dt + power_in_kw) / power_out_kw, 0.0, 1.0)
	battery_kwh = clampf(battery_kwh + net, 0.0, cap)
	energy_in_kwh += power_in_kw * dt
	energy_out_kwh += power_out_kw * served * dt

	o2_kg -= n("per_person_day", "o2_kg") * crew * day
	food_kg -= n("per_person_day", "food_kg") * crew * day
	var drunk := n("per_person_day", "water_kg") * crew * day
	water_kg -= drunk
	for dev: String in loads:
		if not d.devices.has(dev):
			continue
		var spec: Dictionary = d.devices[dev]
		var fx := {"energy_kwh": -float(spec.kw) * served * dt}
		if spec.has("o2_kg_day"):
			var made: float = float(spec.o2_kg_day) * served * day
			fx["o2_kg"] = made
			fx["water_kg"] = -made * float(spec.water_per_o2)
		if spec.has("recover"):
			fx["water_kg"] = drunk * float(spec.recover) * served
		o2_kg += fx.get("o2_kg", 0.0)
		water_kg += fx.get("water_kg", 0.0)
		_charge(_cause.get(dev, -1), fx)
	# a heat choice costs only what it adds over the starting set point (or saves under it)
	var base_heat := n("power", "heater_ua_kw_per_k") * maxf(n("knobs", "heater_c") - outside_c(), 0.0)
	_charge(_cause.get("heater_c", -1), {"energy_kwh": -(loads.heater - base_heat) * served * dt})

	dose_msv += n("per_person_day", "dose_msv") * day
	for e in active:
		if e.kind == "flare":
			var dose: float = float(e.dose_msv) * dt / float(e.duration_h)
			if knobs.sheltered:
				dose *= float(e.shelter_factor)
			dose_msv += dose
			_charge(e.log, {"dose_msv": dose})
		elif e.kind == "storm":
			_charge(e.log, {"energy_kwh": -(solar_kw(n("power", "tau_clear")) - solar_kw(tau)) * dt})
	panel_dust = minf(panel_dust + n("power", "dust_per_sol") * dt / n("clock", "sol_h"), 1.0)
	crop_age_days += day
	if outside:
		suit_air_min = maxf(suit_air_min - dt * 60.0, 0.0)
	for m: String in METERS:
		set(m, maxf(get(m), 0.0))


## Starts scheduled events that are due, ends finished ones, and sets the sky's opacity.
func _events() -> void:
	var t := now()
	var sol_h := n("clock", "sol_h")
	var list: Array = d.schedule.list
	for i in list.size():
		var s: Dictionary = list[i]
		if not _fired.has(i) and t >= (float(s.sol) - 1.0) * sol_h + float(s.hour):
			_fired[i] = true
			start(s.event)
	var clear := n("power", "tau_clear")
	tau = clear
	for e in active.duplicate():
		var age: float = t - e.t0
		if e.kind == "flare" and age >= float(e.duration_h):
			active.erase(e)
		elif e.kind == "storm":
			var rise := float(e.rise_h)
			var extra := float(e.tau_peak) - clear
			extra *= age / rise if age < rise else exp(-(age - rise) / (float(e.e_fold_sols) * sol_h))
			if age >= rise and extra < 0.05:
				active.erase(e)
			else:
				tau = maxf(tau, clear + extra)


## Start an event now, by template id (`events`). The story or a test may call it directly.
func start(event_id: String) -> void:
	var e: Dictionary = d.events[event_id].duplicate()
	e["id"] = event_id
	e["t0"] = now()
	e["log"] = _log(event_id, "event", e.label)
	if e.has("dust_to"):  # a moment, not a lasting event: wind left dust on the panels
		var was := panel_dust
		panel_dust = maxf(panel_dust, float(e.dust_to))
		causes[e.log].effect["panel_dust"] = panel_dust - was
		return
	active.append(e)


## Once a sol, each event with a real base rate may start (a global storm every 3 Mars years, row 40).
func _new_sol() -> void:
	for id: String in d.events:
		var p := float(d.events[id].chance_per_sol)
		if p > 0.0 and _rng.randf() < p:
			start(id)


func _log(id: String, kind: String, label: String) -> int:
	causes.append({"sol": sol, "hour": hour, "id": id, "kind": kind, "label": label, "effect": {}})
	return causes.size() - 1


func _charge(i: int, fx: Dictionary) -> void:
	if i < 0:
		return
	var eff: Dictionary = causes[i].effect
	for m: String in fx:
		eff[m] = eff.get(m, 0.0) + fx[m]


func _diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for k: String in b:
		if (b[k] is float or b[k] is int) and k != "sol" and k != "hour" and not is_equal_approx(float(a[k]), float(b[k])):
			out[k] = float(b[k]) - float(a[k])
	return out
