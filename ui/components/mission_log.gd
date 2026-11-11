extends "res://ui/hud_panel.gd"
## The Mission Log card: one line per thing that happened, newest last. Mock entries only.

const Hud := preload("res://ui/hud.gd")

var entries: Array = [[1, "Landed in Gale crater"], [4, "Cleaned the solar panels"], [9, "Hid from a solar storm"], [12, "Planted lettuce in the greenhouse"]]


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 460
	var body := Hud.col([Hud.row([Hud.tag("Tag", "clock", "", "OnFill", 30), Hud.label("Mission log", "Heading")], 12)], 10)
	for e: Array in entries:
		var sol := Hud.label("Sol %d" % e[0], "SmallNumber")
		sol.custom_minimum_size.x = 76
		body.add_child(Hud.row([sol, Hud.label(e[1])], 12))
	add_child(body)
