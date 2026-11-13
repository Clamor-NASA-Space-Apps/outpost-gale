extends Node
## A stand-in for the rules node, for the gallery and the HUD tests: the sim's state shape and its `changed` signal,
## with mock values. Never game rules: set `values`, then emit_state(); state() hands them over like the sim does.

signal changed(state: Dictionary)

# mock: 2 crew on sol 12 at BVAD rates (factcheck rows 23, 25, 112); a low battery shows the LOW look
var values := {
	"sol": 12, "hour": 7.25, "o2_kg": 33.4, "water_kg": 127.3, "food_kg": 94.4,
	"battery_pct": 24.0, "power_in_kw": 1.2, "power_out_kw": 3.4, "dose_msv": 8.0, "suit_air_min": 395.0,
	"panel_dust": 0.024, "tau": 0.6,
	"events": [{"id": "flare_x12", "label": "Solar storm", "source": "JPL: Curiosity RAD, 20 May 2024", "live": false}],
	"failing": [],
}


func state() -> Dictionary:
	return values


func emit_state() -> void:
	changed.emit(values)


func set_values(d: Dictionary) -> void:
	values.merge(d, true)
	changed.emit(values)
