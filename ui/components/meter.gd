extends HBoxContainer
## One slim meter (design/mockups/hud.png): icon, a 6 px rounded bar with a glow, the number. Below `warn_below` the
## bar turns amber; below `low_below` it turns red, the icon becomes a warning sign and a "!" joins the number, so the
## state reads without colour (Kid UX). Set `value` (or call set_icon) at any time: nothing is rebuilt.
## `compact` is the small gauge of the body row and the hurry bar: no number; when low it keeps its own icon (the
## only thing that names it), and a "!" and a slow pulse say so. The "!" keeps its room when it is not shown and the
## gain is drawn over the bar's end, so a meter is one width whatever it says (15 Nov playtest: the card grew and
## shrank as the numbers changed). A compact gauge with a `word` (the body's four) stacks the word over its bar,
## and the word names it, so when low its icon becomes the warning sign like a big meter's.

const Hud := preload("res://ui/hud.gd")
const BAR_H := 4.0  # 6 mockup px
const PULSE_SECONDS := 0.8  # a low compact gauge fades and returns 1.25 times a second (Kid UX: under 3)

@export var icon_name := "power"
@export var title := "Power"  # the tooltip
@export var word := ""  # a short name beside the icon (14 Nov playtest: kids could not tell Life support from Crew health)
@export_range(0, 100) var value := 72:
	set(v):
		var was := value
		value = clampi(v, 0, 100)
		if is_node_ready() and value != was:  # the hurry bar is set every frame
			_show()
@export var warn_below := 50
@export var low_below := 30
@export var compact := false
@export var text_px := 0  # the word's and the number's font size (the status card's four bars); 0 keeps the theme's

var bar := Control.new()
var tile_icon: Hud.Icon
var name_label: Label
var num: Label
var gain: Label  # a sudden rise in what feeds the meter ("+0.7 kW"), fading beside the number
var _bump: Tween
var _pulse: Tween


func _ready() -> void:
	add_theme_constant_override("separation", 7)
	tooltip_text = title
	var stacked := compact and word != ""
	tile_icon = Hud.icon(icon_name, 13 if stacked else 15, "on_surface") as Hud.Icon
	bar.custom_minimum_size = Vector2(12 if compact else 60, BAR_H if stacked else 10.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar)
	num = Hud.label("", "HudNum")
	num.custom_minimum_size.x = 6 if compact else 38
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gain = Hud.label("", "HudNum")
	gain.add_theme_color_override("font_color", Hud.color("light"))
	gain.modulate.a = 0.0
	gain.visible = false
	# over the bar's right end, outside the row's layout: in the row it took its width from the bar (14 Nov: "the
	# power bar gets shorter"), and then from the card
	gain.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	gain.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gain.grow_vertical = Control.GROW_DIRECTION_BOTH
	bar.add_child(gain)
	# big, the word is plain text: the caps style's wide spacing would take the card's width before its size
	name_label = Hud.label(word, "HudText" if text_px else "Cap")
	name_label.visible = word != ""
	if stacked:
		add_theme_constant_override("separation", 3)
		add_child(tile_icon)
		var over := Hud.col([name_label, bar], 0)
		over.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(over)
	else:
		for k: Control in [tile_icon, name_label, bar, num]:
			add_child(k)
	if text_px:
		for l: Label in [name_label, num, gain]:
			l.add_theme_font_size_override("font_size", text_px)
		# the widest it ever says, so the bar beside it keeps one length
		num.custom_minimum_size.x = ceilf(num.get_theme_font("font").get_string_size("100%!", HORIZONTAL_ALIGNMENT_LEFT, -1, num.get_theme_font_size("font_size")).x)
	Hud.nudge(self)  # the icon on the number's capitals
	_show()


## Which thing the meter stands for right now (Life support shows its lowest supply).
func set_icon(n: String) -> void:
	if n != icon_name:
		icon_name = n
		if not low():
			tile_icon.art = Hud.icon_texture(n)


## A gain the battery percent is too slow to show (a cleaned wing feeds a 140 kWh battery): the kid sees it now.
func bump(text: String) -> void:
	gain.text = text
	gain.visible = true
	if _bump:
		_bump.kill()  # its hide at the end would cut this one short
	_bump = create_tween()
	_bump.tween_property(gain, "modulate:a", 1.0, 0.2)
	_bump.tween_interval(2.5)
	_bump.tween_property(gain, "modulate:a", 0.0, 0.6)
	_bump.tween_callback(gain.hide)


func low() -> bool:
	return value < low_below


func _show() -> void:
	var l := low()
	tile_icon.art = Hud.icon_texture("alert" if l and (not compact or word != "") else icon_name)
	tile_icon.tint = Hud.color("danger" if l else "on_surface")
	num.text = ("!" if l else "") if compact else "%d%%%s" % [value, "!" if l else ""]
	if l:
		num.add_theme_color_override("font_color", Hud.color("danger"))
	else:
		num.remove_theme_color_override("font_color")
	bar.queue_redraw()
	if compact and l != (_pulse != null):
		if _pulse:
			_pulse.kill()
			_pulse = null
			bar.modulate.a = 1.0
		else:
			_pulse = create_tween().set_loops()
			_pulse.tween_property(bar, "modulate:a", 0.35, PULSE_SECONDS * 0.5)
			_pulse.tween_property(bar, "modulate:a", 1.0, PULSE_SECONDS * 0.5)


func _fill() -> Color:
	return Hud.color("danger" if low() else ("primary" if value < warn_below else "light"))


func _draw_bar() -> void:
	var r := Rect2(0, (bar.size.y - BAR_H) * 0.5, bar.size.x, BAR_H)
	Hud.pill(bar, r, Hud.color("hud-track"))
	if value <= 0:
		return
	var fill := Rect2(r.position, Vector2(r.size.x * value / 100.0, BAR_H))
	Hud.pill(bar, fill, Hud.color("hud-glow-danger" if low() else ("hud-glow-amber" if value < warn_below else "hud-glow")), true)
	Hud.pill(bar, fill, _fill())
