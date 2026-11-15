extends Node
## A stand-in for the rules node, for the gallery and the HUD tests: the sim's state shape and its `changed` signal,
## with mock values. Never game rules: set `values`, then emit_state(); state() hands them over like the sim does.

signal changed(state: Dictionary)

# mock: 2 crew on sol 12 at BVAD rates (factcheck rows 23, 25, 112); a low battery shows the LOW look
var values := {
	"sol": 12, "hour": 7.25, "o2_kg": 33.4, "water_kg": 127.3, "food_kg": 94.4,
	"battery_pct": 24.0, "power_in_kw": 1.2, "solar_in_kw": 1.2, "power_out_kw": 3.4, "dose_msv": 8.0, "suit_air_min": 395.0,
	"panel_dust": 0.024, "tau": 0.6,
	# the hero's body (design/plans/core-loop-contracts.md): thirsty, in a dusty suit, outside
	"health": 82.0, "hurt": "thirst", "body": true, "body_water": 0.0, "body_food": 0.7, "body_rest": 0.55,
	"suit_air": 0.82, "suit_dust": 0.6, "outside": true, "cold": false, "leak": false, "net_kw": -2.2,
	"events": [{"id": "flare_x12", "label": "Solar storm", "source": "JPL: Curiosity RAD, 20 May 2024", "live": false}],
	"failing": [],
}


func state() -> Dictionary:
	return values


## The rules' flows() (sim/sim.gd), mock: the base report's bars. Its net is the state's net_kw.
func flows() -> Dictionary:
	var made := float(values.power_in_kw)
	var net := float(values.net_kw)
	return {"power": {"makes": {"solar": made, "reactor": 0.0}, "uses": {"hab": made - net - 1.5, "heater": 1.2, "moxie": 0.3}, "net_kw": net},
		"supplies": {"o2_kg": {"left": 33.4, "uses": 1.7, "makes": 0.2}, "water_kg": {"left": 127.3, "uses": 6.6, "makes": 6.5},
			"food_kg": {"left": 94.4, "uses": 4.9, "makes": 0.0}}, "hurts": {"thirst": 8.0}}


func emit_state() -> void:
	changed.emit(values)


func set_values(d: Dictionary) -> void:
	values.merge(d, true)
	changed.emit(values)
