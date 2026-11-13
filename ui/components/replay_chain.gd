extends BoxContainer
## The replay chain: the choices that led to the end, in order, joined by arrows. Order is shown by position and
## arrows, never by colour. `stacked` lays it top to bottom for a narrow screen (the arrows then point down).
## steps: [[icon, label, caption], ...]; the caption ("Sol 9") may be left out.

const Hud := preload("res://ui/hud.gd")
const ARROW := 34.0

var steps: Array = [["storm", "Dust on the panels", "Sol 4"], ["battery", "Batteries ran low", "Sol 6"], ["heater", "Heaters turned off", "Sol 7"]]
var stacked := false


func _ready() -> void:
	vertical = stacked
	add_theme_constant_override("separation", 6)
	for i in steps.size():
		var s: Array = steps[i]
		if i > 0:
			var arrow := Hud.icon("next", ARROW, "danger")
			arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if stacked:
				arrow.pivot_offset = Vector2(ARROW, ARROW) * 0.5
				arrow.rotation = PI / 2.0
			add_child(arrow)
		var text := Hud.col([Hud.label(s[1], "", true)], 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if s.size() > 2 and s[2]:
			text.add_child(Hud.label(s[2], "Caption"))
		var chip := Hud.panel("HudPanelSoft", Hud.row([Hud.icon(s[0], 30), text], 8))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(chip)
