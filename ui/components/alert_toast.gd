extends "res://ui/hud_panel.gd"
## An alert: red fill, a warning icon and a short line. Its glow pulses once every PULSE_SECONDS, well under
## the 3 flashes a second Kid UX allows, and the text itself never fades, so it can always be read.

const Hud := preload("res://ui/hud.gd")
const PULSE_SECONDS := 1.2

@export var icon_name := "alert"
@export var title := "Power low!"
@export var line := "Clean the solar panels."

var title_label: Label
var line_label: Label


func _ready() -> void:
	theme_type_variation = "HudPanelAlert"
	custom_minimum_size.x = 200  # the line wraps, so it asks for no width of its own (300 mockup px)
	title_label = Hud.label(title, "OnFillTitle")
	line_label = Hud.label(line, "OnFillText", true)
	var text := Hud.col([title_label, line_label], 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(Hud.row([Hud.icon(icon_name, 22, "on_primary"), text], 9))
	var glow: StyleBoxFlat = get_theme_stylebox("panel", "HudPanelAlert").duplicate()
	add_theme_stylebox_override("panel", glow)
	var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	t.tween_property(glow, "shadow_size", 14, PULSE_SECONDS * 0.5)
	t.tween_property(glow, "shadow_size", 3, PULSE_SECONDS * 0.5)


func say(t: String, l: String) -> void:
	title = t
	line = l
	title_label.text = t
	line_label.text = l
	line_label.visible = l != ""
