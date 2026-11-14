extends Node
## The rules in the scene: steps sim/sim.gd from real time (clock.real_s_per_sol in data/sim.json) and tells the
## HUD. The composition root adds it; everything else asks it (apply, use, skip_sols) so `changed` always follows.

signal changed(state: Dictionary)

const Sim := preload("res://sim/sim.gd")

var sim := Sim.new()
var paused := false
var _since := 0.0


func _process(delta: float) -> void:
	if paused:
		return
	sim.run(delta * sim.n("clock", "sol_h") / sim.n("clock", "real_s_per_sol"))
	_since += delta
	if _since >= 1.0 / sim.n("clock", "emit_hz"):
		_since = 0.0
		changed.emit(sim.state())


## The HUD's bind() reads it at once: before the first `changed` it showed its gallery sample (Sol 3, 72%).
func state() -> Dictionary:
	return sim.state()


func apply(choice_id: String) -> Dictionary:
	return _told(sim.apply(choice_id))


func use(action_id: String) -> Dictionary:
	return _told(sim.use(action_id))


func skip_sols(count: int) -> Dictionary:
	return _told(sim.skip_sols(count))


func _told(result: Dictionary) -> Dictionary:
	changed.emit(sim.state())
	return result
