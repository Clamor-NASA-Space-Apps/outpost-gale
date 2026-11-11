extends HBoxContainer
## The replay chain: the choices that led to the end, in order, joined by arrows.
## Order is shown by position and arrows, never by colour.

const Hud := preload("res://ui/hud.gd")

var steps: Array = [["storm", "Dust on the panels"], ["battery", "Batteries ran low"], ["heater", "Heaters turned off"]]


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for i in steps.size():
		if i > 0:
			add_child(Hud.icon("next", 34, "danger"))
		var chip := Hud.panel("HudPanelSoft", Hud.row([Hud.icon(steps[i][0], 30), Hud.label(steps[i][1], "", true)], 8))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(chip)
