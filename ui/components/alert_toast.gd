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
	# the pulse: a second glow from the atlas over the style's own, its strength rising and falling; a node of its own
	# (first, so under the icon and words), drawn with the other shapes in one call (Hud.layer)
	var pulse := Control.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.set_meta("shapes", true)
	pulse.draw.connect(func() -> void:
		var k := 0.5 - 0.5 * cos(TAU * fposmod(Time.get_ticks_msec() / 1000.0, PULSE_SECONDS) / PULSE_SECONDS)
		var g := 12.0
		var m := Color.WHITE  # no tint: the glow's colour is in the atlas; only its strength moves
		m.a = k
		var box := Rect2(-pulse.position, size)  # the whole toast, from the pulse node's own corner
		Hud.blit(pulse, "alert_glow", box.grow(g), m))
	add_child(pulse)
	move_child(pulse, 0)
	_pulse = pulse


var _pulse: Control


func _process(_delta: float) -> void:
	if visible:
		_pulse.queue_redraw()


func say(t: String, l: String) -> void:
	title = t
	line = l
	title_label.text = t
	line_label.text = l
	line_label.visible = l != ""
