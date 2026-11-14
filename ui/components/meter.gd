extends HBoxContainer
## One slim meter (design/mockups/hud.png): icon, a 6 px rounded bar with a glow, the number. Below `warn_below` the
## bar turns amber; below `low_below` it turns red, the icon becomes a warning sign and a "!" joins the number, so the
## state reads without colour (Kid UX). Set `value` (or call set_icon) at any time: nothing is rebuilt.

const Hud := preload("res://ui/hud.gd")
const BAR_H := 4.0  # 6 mockup px

@export var icon_name := "power"
@export var title := "Power"  # the tooltip; the icon says it on screen
@export_range(0, 100) var value := 72:
	set(v):
		value = clampi(v, 0, 100)
		if is_node_ready():
			_show()
@export var warn_below := 50
@export var low_below := 30

var bar := Control.new()
var tile_icon: Hud.Icon
var num: Label
var gain: Label  # a sudden rise in what feeds the meter ("+0.7 kW"), fading beside the number
var _bump: Tween


func _ready() -> void:
	add_theme_constant_override("separation", 7)
	tooltip_text = title
	tile_icon = Hud.icon(icon_name, 15, "on_surface") as Hud.Icon
	bar.custom_minimum_size = Vector2(60, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar)
	num = Hud.label("", "HudNum")
	num.custom_minimum_size.x = 38
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gain = Hud.label("", "HudNum")
	gain.add_theme_color_override("font_color", Hud.color("light"))
	gain.modulate.a = 0.0
	gain.visible = false  # a faded gain still took its width from the bar (14 Nov playtest: "the power bar gets shorter")
	for k: Control in [tile_icon, bar, num, gain]:
		add_child(k)
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
	tile_icon.art = Hud.icon_texture("alert" if l else icon_name)
	tile_icon.tint = Hud.color("danger" if l else "on_surface")
	num.text = "%d%%%s" % [value, "!" if l else ""]
	if l:
		num.add_theme_color_override("font_color", Hud.color("danger"))
	else:
		num.remove_theme_color_override("font_color")
	bar.queue_redraw()


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
