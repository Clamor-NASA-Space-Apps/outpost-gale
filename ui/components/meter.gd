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
var tile_icon: TextureRect
var num: Label


func _ready() -> void:
	add_theme_constant_override("separation", 7)
	tooltip_text = title
	tile_icon = Hud.icon(icon_name, 15, "on_surface")
	bar.custom_minimum_size = Vector2(60, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar)
	num = Hud.label("", "HudNum")
	num.custom_minimum_size.x = 38
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for k: Control in [tile_icon, bar, num]:
		add_child(k)
	_show()


## Which thing the meter stands for right now (Life support shows its lowest supply).
func set_icon(n: String) -> void:
	if n != icon_name:
		icon_name = n
		if not low():
			tile_icon.texture = load("res://ui/icons/%s.svg" % n)


func low() -> bool:
	return value < low_below


func _show() -> void:
	var l := low()
	tile_icon.texture = load("res://ui/icons/%s.svg" % ("alert" if l else icon_name))
	tile_icon.self_modulate = Hud.color("danger" if l else "on_surface")
	num.text = "%d%%%s" % [value, "!" if l else ""]
	if l:
		num.add_theme_color_override("font_color", Hud.color("danger"))
	else:
		num.remove_theme_color_override("font_color")
	bar.queue_redraw()


func _fill() -> Color:
	return Hud.color("danger" if low() else ("primary" if value < warn_below else "light"))


func _draw_bar() -> void:
	var y := (bar.size.y - BAR_H) * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Hud.color("hud-track")
	track.set_corner_radius_all(int(BAR_H * 0.5))
	bar.draw_style_box(track, Rect2(0, y, bar.size.x, BAR_H))
	if value <= 0:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = _fill()
	fill.set_corner_radius_all(int(BAR_H * 0.5))
	fill.shadow_color = Hud.color("hud-glow-danger" if low() else ("hud-glow-amber" if value < warn_below else "hud-glow"))
	fill.shadow_size = 5
	bar.draw_style_box(fill, Rect2(0, y, bar.size.x * value / 100.0, BAR_H))
