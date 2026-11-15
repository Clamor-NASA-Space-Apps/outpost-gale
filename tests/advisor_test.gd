extends "res://addons/forge/test.gd"
## The root's part of the core loop (design/plans/core-loop-contracts.md, R): PIP's advisor says a need once and
## puts the waypoint on its fix, and the step's own comes back; the power panel's card flips a switch in the rules;
## the story's rule() reaches the rules; a loss keeps its card; "Try this sol again" starts this morning, not Sol 1:
## godot --headless --path . -s tests/advisor_test.gd
## It writes user://advisor_test.json only, never a player's file.

const Save := preload("res://sandbox/save.gd")
const FILE := "user://advisor_test.json"

var game: Node3D
var said: Array[String] = []


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	Save.file = FILE
	DirAccess.remove_absolute(FILE)
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	current_scene = game  # once it is in: no opening starts, and the lost card's retry has a scene to start again
	await frames(3)
	while game.busy():
		await process_frame
	var sim: Object = game.sim.sim
	var hud: Control = game.hud
	var advisor: RefCounted = game.advisor
	game.beats.line.connect(func(id: String, _opts: Dictionary) -> void: said.append(id))

	# thirsty: one line, the waypoint on a drink spot, and the step's own back once the kid has drunk
	game.beats.objective.emit("use:radio")
	_state({})
	check(said.is_empty() and hud.objective == "use:radio", "nothing wrong: PIP is quiet and the step's waypoint stays (%s, %s)" % [said, hud.objective])
	_state({"body_water": 0.1})
	_state({"body_water": 0.1})
	check(said == ["need.thirst"], "thirsty: PIP says need.thirst, once (%s)" % [said])
	check(hud.objective == "use:drink" and hud.objective_node and hud.objective_node.row.kind == "drink", "and the waypoint is on a drink spot (%s)" % hud.objective)
	game.interactions.used.emit("drink", Vector3.ZERO)
	check(hud.objective == "use:radio" and advisor.goal == "", "the drink taken, the step's own waypoint is back (%s)" % hud.objective)

	# out of suit air outside: the most urgent line first, and at once, though PIP spoke a moment ago
	said.clear()
	_state({"outside": true, "suit_air": 0.0, "body_water": 0.1, "body_food": 0.1})
	check(said == ["need.air_out"] and hud.objective == "use:refill_air", "suit air 0 outside: need.air_out first, the waypoint on the air (%s, %s)" % [said, hud.objective])
	_state({"outside": true, "suit_air": 0.0, "body_water": 0.1, "body_food": 0.1})
	check(said == ["need.air_out"], "the next line waits its 20 s (%s)" % [said])
	advisor.last = -INF
	_state({"outside": true, "suit_air": 0.0, "body_water": 0.1, "body_food": 0.1})
	check(said == ["need.air_out", "need.thirst"], "then the next need in the table's order (%s)" % [said])
	_state({})
	check(hud.objective == "use:radio" and advisor.said.is_empty(), "every need gone: the step's waypoint again (%s, %s)" % [hud.objective, advisor.said])

	# the power panel: a row for each switch and "Leave it"; a pick flips the switch in the rules and says so
	said.clear()
	advisor.last = -INF
	var was: bool = sim.knobs.recycler
	var logged: int = hud.handbook.save().decisions.size()
	game.interactions.used.emit("panel", Vector3.ZERO)
	var options: Array = game.offers.get("panel", {}).get("options", [])
	var row := options.find_custom(func(o: Dictionary) -> bool: return String(o.text).begins_with("panel.recycler."))
	if check(hud.card != null and hud.side_card and options.size() == 5 and row >= 0 and options[-1].text == "panel.close",
			"the panel's card: four switches and Leave it (%s)" % [options.map(func(o: Dictionary) -> String: return o.text)]):
		check(options[row].text == "panel.recycler." + ("off" if was else "on"), "the recycler's row flips it from where it stands (%s)" % options[row].text)
		_state({"body_food": 0.1})
		check(said.is_empty(), "PIP says nothing over a card (%s)" % [said])
		hud.card.chosen.emit(row)
		check(sim.knobs.recycler != was, "picking it flips the recycler in the rules")
		check(hud.card == null and hud.snapshot().alert == hud.line(options[row].text), "the card goes and an alert names the switch ('%s')" % hud.snapshot().alert)
		check(hud.handbook.save().decisions.size() == logged, "a panel flip is no decision in the log")
		game.interactions.used.emit("panel", Vector3.ZERO)
		hud.card.chosen.emit(game.offers.panel.options.size() - 1)
		check(sim.knobs.recycler != was and hud.card == null, "Leave it leaves it")

	# the story's word to the rules: Sol 4's leak starts, PIP sends the kid to the valve, the valve ends it
	said.clear()
	game.beats.rule.emit("event:o2_leak")
	check(sim.state().leak, "rule(event:o2_leak) starts the leak")
	check("need.leak" not in said, "PIP leaves the leak to the kid and the handbook at first (%s)" % [said])
	sim.o2_kg = 0.7 * sim.n("start", "o2_kg")  # a quarter of the tank gone: now PIP helps
	game.sim.changed.emit(sim.state())
	check("need.leak" in said and hud.objective == "use:o2_valve", "PIP says need.leak and points at the valve (%s, %s)" % [said, hud.objective])
	game.interactions.used.emit("o2_valve", Vector3.ZERO)
	check(not sim.state().leak and hud.objective == "use:radio", "the valve shut: no leak, the step's waypoint back (%s)" % hud.objective)
	game.beats.rule.emit("apply:greenhouse_off")
	check(sim.knobs.greenhouse == false, "rule(apply:<choice>) reaches the rules")

	# a morning's checkpoint from before the body's rules, then a loss while quiet sols pass: the lost card stays
	game.beats.skip()
	game.sim.skip_sols(4 - int(sim.sol))
	check(not game.lost and int(sim.sol) == 4, "Sol 4, the mission still on (sol %d)" % sim.sol)
	game.checkpoint(4)
	var saved := Save.read()
	if not check(not saved.is_empty(), "the checkpoint is written"):
		return true
	for k: String in ["health", "body_water", "body_food", "body_rest", "suit_dust"]:
		saved.sim.erase(k)
	saved.sim.knobs.erase("body")
	Save.write(saved)
	sim.water_kg = 0.0
	game.beats.skip_sols.emit(1)
	check(game.lost and hud.card != null and hud.card.has_signal("retry"), "a loss while sols are skipped leaves the lost card up, not the ledger")

	# "Try this sol again": this morning, as Continue, with a save that lacks the body's values
	hud.retry.emit()
	while current_scene == null or current_scene.get("beats") == null:
		await process_frame
	var again: Node = current_scene
	await process_frame
	await process_frame
	check(again != game and again.beats.sequence == "sol4" and int(again.sim.sim.sol) == 4 and not again.lost,
		"retry starts Sol 4's morning, not Sol 1 (%s, sol %d)" % [again.beats.sequence, again.sim.sim.sol])
	check(again.sim.sim.water_kg > 0.0 and is_equal_approx(again.sim.sim.body_water, 1.0) and again.sim.sim.knobs.body == true,
		"on the saved rules, the body at its start values and its needs running (body %s)" % again.sim.sim.knobs.body)

	# no morning saved yet: the same button starts the mission again, with the opening
	DirAccess.remove_absolute(FILE)
	again.hud.retry.emit()
	while current_scene == null or current_scene.get("beats") == null:
		await process_frame
	var fresh: Node = current_scene
	await process_frame
	await process_frame
	check(fresh != again and fresh.beats.sequence == "opening" and int(fresh.sim.sim.sol) == 1, "with no checkpoint, retry starts Sol 1's opening (%s)" % fresh.beats.sequence)
	return true


## One state to everyone who listens to the rules: the rules' own, with `over` on top.
func _state(over: Dictionary) -> void:
	var st: Dictionary = game.sim.sim.state()
	st.merge(over, true)
	game.sim.changed.emit(st)
