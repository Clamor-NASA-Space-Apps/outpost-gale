extends "res://ui/hud_panel.gd"
## The sleep ledger: what the base used while the crew slept through `sols` sols. Set `ledger` before it enters
## the tree: the sim's skip_sols() result, {sols, <state key>: change, energy_in_kwh, energy_out_kwh}. Only keys
## in Hud.KEYS get a row, each with its icon, name and signed amount, so a rise and a fall read without colour.

signal closed

const Hud := preload("res://ui/hud.gd")

@export var width := 460.0
# mock: 2 crew for 3 sols at BVAD's daily rates (factcheck rows 23, 25, 112)
var ledger := {"sols": 3, "o2_kg": -5.0, "water_kg": -19.3, "food_kg": -14.3, "energy_in_kwh": 41.0, "energy_out_kwh": 55.4, "panel_dust": 0.006}
var button := Button.new()


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = width
	var n := int(ledger.get("sols", 1))
	var body := Hud.col([
		Hud.row([Hud.tag("Tag", "clock", "", "OnFill", 30), Hud.label("%d sols went by" % n if n != 1 else "One sol went by", "Heading", true)], 12),
		Hud.label("While you slept, the base used:", "Caption", true),
	], 10)
	for k: String in Hud.KEYS:
		if not ledger.has(k) or is_zero_approx(float(ledger[k])):
			continue
		var amt := Hud.label(Hud.amount(k, ledger[k]), "SmallNumber")
		body.add_child(Hud.row([Hud.icon(Hud.KEYS[k][0], 28), Hud.label(Hud.KEYS[k][1], "", true), amt], 10))
	button.text = "Good morning"
	button.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
	button.pressed.connect(func() -> void: closed.emit())
	body.add_child(button)
	add_child(body)
