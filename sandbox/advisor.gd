extends RefCounted
## PIP reacting to the rules, outside the script (design/plans/core-loop-contracts.md, R). The root feeds it each
## state of the rules. For the most urgent need that holds and has not been said since it last cleared, PIP says one
## line and the waypoint goes on the fix. The fix used, or the need gone, and the step's own waypoint comes back.

const GAP_S := 20.0  # s between two lines, so PIP never nags (the contract's table); URGENT ones do not wait
# the dust waits for nobody either: brought inside it costs health after a few seconds (the rules' body.dust_grace_h)
# nor does an empty gauge: it costs Crew health from the moment it is empty (the rules' body.hurt_per_h)
const URGENT: Array[String] = ["need.air_out", "need.leak", "need.dusty", "need.dry", "need.starve"]
# line id -> its fix ("use:<kind>", "" for none), the most urgent first. The limits in feed() are the same table's
const NEEDS := {
	"need.air_out": "use:refill_air", "need.air_low": "use:refill_air", "need.leak": "use:o2_valve",
	"need.dusty": "use:brush", "need.devil": "", "need.dry": "use:drink", "need.starve": "use:eat",
	"need.thirst": "use:drink", "need.hunger": "use:eat",
	"need.tired": "use:bed", "need.blackout": "use:panel", "need.power_low": "use:panel",
	"need.supply_low": "use:panel", "need.health_low": "",
}

var say: Callable  # PIP says a line id
var point: Callable  # the waypoint on a fix, or with "" the step's own back
var listed: Callable  # the needs that hold, or the one with the waypoint, changed: the root redraws the Today list
var dusty := 0.5  # suit_dust from which dust comes inside with the suit (the rules' body.dusty)
var stock := {}  # o2_kg, water_kg, food_kg -> what the base landed with (the rules' start): a supply under a quarter of it is low
var devil := false  # the root sets it: a dust devil touched the hero since the last state
var said := {}  # line id -> true, until its need has cleared
var goal := ""  # the need whose fix has the waypoint, "" while the waypoint is the step's own
var tasks: Array[String] = []  # the fixes ("use:drink") of every need that holds, the most urgent first, each once
var done := {}  # need id -> true: its fix was used though it still holds (the panel left as it was); no waypoint again
var last := -INF  # s, when PIP last spoke here


## One state of the rules (sim.state()). `quiet`: a card, the handbook or a cinematic is up, or the mission is lost;
## PIP then says nothing new, and a need that cleared meanwhile still lets go. True when a line was said.
func feed(st: Dictionary, quiet: bool) -> bool:
	var out: bool = st.outside
	var air := float(st.suit_air)
	var battery := float(st.battery_pct)
	var holds := {
		"need.air_out": out and air <= 0.0, "need.air_low": out and air > 0.0 and air < 0.3,
		# the leak: the handbook first (Sol 4), and PIP helps once a quarter of the tank is gone
		"need.leak": st.leak and float(st.o2_kg) < 0.75 * float(stock.get("o2_kg", 0.0)),
		"need.dusty": float(st.suit_dust) >= dusty,  # outside too: the kid hears it before the door
		"need.devil": devil, "need.dry": float(st.body_water) <= 0.0, "need.starve": float(st.body_food) <= 0.0,
		"need.thirst": float(st.body_water) < 0.25,
		"need.hunger": float(st.body_food) < 0.25, "need.tired": float(st.body_rest) < 0.2,
		"need.blackout": battery <= 0.0, "need.power_low": battery > 0.0 and battery < 25.0,
		"need.supply_low": stock.keys().any(func(k: String) -> bool: return float(st[k]) < 0.25 * float(stock[k])),
		"need.health_low": float(st.health) < 40.0,
	}
	devil = false  # a touch is a moment: said now or not at all
	var now := Time.get_ticks_msec() / 1000.0
	var spoke := false
	var was := [tasks, goal]
	tasks = []
	for id: String in NEEDS:
		if not holds[id]:
			said.erase(id)
			done.erase(id)
			continue
		# the panel's needs are no task: a low battery at night or a thin stock late on can hold for sols
		if NEEDS[id] not in ["", "use:panel"] and NEEDS[id] not in tasks:
			tasks.append(NEEDS[id])
		if not (quiet or spoke or said.has(id)) and (id in URGENT or now - last >= GAP_S):
			said[id] = true
			last = now
			spoke = true
			say.call(id)
			# the waypoint stays on the most urgent need: a later, lesser one waits its turn (thirst, then hunger)
			if NEEDS[id] != "" and (goal == "" or NEEDS.keys().find(id) < NEEDS.keys().find(goal)):
				goal = id
				point.call(NEEDS[id])
	if goal != "" and not holds[goal]:
		_release()  # after the loop: every need that cleared in this state is out of `said` by now
	if was != [tasks, goal] and listed.is_valid():
		listed.call()
	return spoke


## A use spot was used: when it is the fix PIP pointed at, the step's own waypoint comes back, whether or not the
## need is gone yet (the power panel left as it was).
func used(kind: String) -> void:
	if goal != "" and NEEDS[goal] == "use:" + kind:
		for id: String in NEEDS:
			if NEEDS[id] == NEEDS[goal]:
				done[id] = true  # every need this one fix answers (thirsty and empty: one drink), until it clears
		_release()
		if listed.is_valid():
			listed.call()


## The waypoint leaves this need: on to the next one PIP has said that still waits for its fix, or back to the step.
func _release() -> void:
	goal = ""
	for id: String in NEEDS:
		if said.has(id) and not done.has(id) and NEEDS[id] != "":
			goal = id
			break
	point.call(NEEDS[goal] if goal != "" else "")
