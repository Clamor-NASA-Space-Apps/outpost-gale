extends "res://ui/hud_panel.gd"
## An alert: red fill, a warning icon and a short line. Its glow pulses once every PULSE_SECONDS, well under
## the 3 flashes a second Kid UX allows, and the text itself never fades, so it can always be read.

const Hud := preload("res://ui/hud.gd")
const PULSE_SECONDS := 1.2

@export var icon_name := "alert"
@export var title := "Power low!"
@export var line := "Clean the solar panels."


func _ready() -> void:
	theme_type_variation = "HudPanelAlert"
	add_child(Hud.row([Hud.icon(icon_name, 40, "on_primary"), Hud.col([Hud.label(title, "OnFill"), Hud.label(line, "OnFillBody")], 0)], 14))
	var glow: StyleBoxFlat = get_theme_stylebox("panel", "HudPanelAlert").duplicate()
	add_theme_stylebox_override("panel", glow)
	var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(glow, "shadow_size", 18, PULSE_SECONDS * 0.5)
	t.tween_property(glow, "shadow_size", 4, PULSE_SECONDS * 0.5)
