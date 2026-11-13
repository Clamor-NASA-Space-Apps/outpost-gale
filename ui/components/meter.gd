extends HBoxContainer
## One meter: icon, name, a segmented bar and the number. Below `low_below` it changes shape as well
## as colour (Kid UX: colour is never the only signal): the icon tile turns into a warning, a LOW tag
## appears, and each lit segment splits in two, so the bar reads "broken" in greyscale too.
## Set `value` (or call set_icon) at any time: the parts are built once and only shown, hidden or redrawn.

const Hud := preload("res://ui/hud.gd")
const SEGMENTS := 10
const SLANT := 6.0  # px each segment leans, the same lean as the theme's tags

@export var icon_name := "power"
@export var title := "Power"
@export_range(0, 100) var value := 72:
	set(v):
		value = clampi(v, 0, 100)
		if is_node_ready():
			_show()
@export var low_below := 30

var bar := Control.new()
var tile: PanelContainer
var tile_icon: TextureRect
var warn_tile: PanelContainer
var low_tag: PanelContainer
var num: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	tile = Hud.tag("Tag", icon_name, "", "OnFill", 30)
	tile_icon = tile.get_child(0).get_child(0)
	warn_tile = Hud.tag("TagDanger", "alert", "", "OnFill", 30)
	low_tag = Hud.tag("TagDanger", "", "LOW")
	var head := Hud.row([Hud.label(title), Hud.spacer(), low_tag], 8)
	bar.custom_minimum_size = Vector2(200, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar)
	var mid := Hud.col([head, bar], 6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num = Hud.label("", "Number")
	num.custom_minimum_size.x = 78
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for k: Control in [tile, warn_tile, mid, num]:
		add_child(k)
	_show()


## Which thing the meter stands for right now (Life support shows its lowest supply).
func set_icon(n: String) -> void:
	if n != icon_name:
		icon_name = n
		tile_icon.texture = load("res://ui/icons/%s.svg" % n)


func low() -> bool:
	return value < low_below


func _show() -> void:
	var l := low()
	tile.visible = not l
	warn_tile.visible = l
	low_tag.visible = l
	num.text = "%d%%" % value
	if l:
		num.add_theme_color_override("font_color", Hud.color("danger"))
	else:
		num.remove_theme_color_override("font_color")
	bar.queue_redraw()


func _draw_bar() -> void:
	var w := (bar.size.x - SLANT) / SEGMENTS
	var h := bar.size.y
	var lit := roundi(value / 100.0 * SEGMENTS)
	var l := low()
	var on := Hud.color("danger" if l else "primary")
	var off := Hud.color("segment_off")
	for i in SEGMENTS:
		var x := i * w
		if i >= lit:
			_slab(x, w - 4, h, off)
		elif l:
			_slab(x, w * 0.5 - 3, h, on)
			_slab(x + w * 0.5, w * 0.5 - 4, h, on)
		else:
			_slab(x, w - 4, h, on)


func _slab(x: float, w: float, h: float, col: Color) -> void:
	bar.draw_colored_polygon(PackedVector2Array([
		Vector2(x + SLANT, 0), Vector2(x + SLANT + w, 0), Vector2(x + w, h), Vector2(x, h)]), col)
