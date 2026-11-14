extends Node
## The rules in the scene: steps sim/sim.gd from real time (at the look clock's pace, else clock.real_s_per_sol in
## data/sim.json) and tells the HUD. The composition root adds it; everything else asks it (apply, use, skip_sols) so `changed` always follows.

signal changed(state: Dictionary)

const Sim := preload("res://sim/sim.gd")

var sim := Sim.new()
var paused := false
## The look clock's pace, local hours a real second (world/sky_clock.gd pace()): with it the rules keep the sky's
## time, the short night included (14 Nov playtest: the HUD said 06:30 under a 05:47 sky). Without it, real_s_per_sol.
var pace := Callable()
var _since := 0.0


func _process(delta: float) -> void:
	if paused:
		return
	var sol_h: float = sim.n("clock", "sol_h")
	sim.run(delta * (float(pace.call()) * sol_h / 24.0 if pace.is_valid() else sol_h / sim.n("clock", "real_s_per_sol")))
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
