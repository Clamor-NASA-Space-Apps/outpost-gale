extends HBoxContainer
## One meter: icon, name, a segmented bar and the number. Below `low_below` it changes shape as well
## as colour (Kid UX: colour is never the only signal): the icon tile turns into a warning, a LOW tag
## appears, and each lit segment splits in two, so the bar reads "broken" in greyscale too.
## Mock values only: the game sets `value` on 14 Nov.

const Hud := preload("res://ui/hud.gd")
const SEGMENTS := 10
const SLANT := 6.0  # px each segment leans, the same lean as the theme's tags

@export var icon_name := "power"
@export var title := "Power"
@export_range(0, 100) var value := 72
@export var low_below := 30

var bar := Control.new()


func _ready() -> void:
	var low := value < low_below
	add_theme_constant_override("separation", 14)
	var tile := Hud.tag("TagDanger" if low else "Tag", "alert" if low else icon_name, "", "OnFill", 30)
	var head: Array = [Hud.label(title)]
	if low:
		head.append(Hud.spacer())
		head.append(Hud.tag("TagDanger", "", "LOW"))
	bar.custom_minimum_size = Vector2(200, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(_draw_bar.bind(low))
	var mid := Hud.col([Hud.row(head, 8), bar], 6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var num := Hud.label("%d%%" % value, "Number")
	num.custom_minimum_size.x = 78
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if low:
		num.add_theme_color_override("font_color", Hud.color("danger"))
	for k: Control in [tile, mid, num]:
		add_child(k)


func _draw_bar(low: bool) -> void:
	var w := (bar.size.x - SLANT) / SEGMENTS
	var h := bar.size.y
	var lit := roundi(value / 100.0 * SEGMENTS)
	var on := Hud.color("danger" if low else "primary")
	var off := Hud.color("outline-variant", 0.7)
	for i in SEGMENTS:
		var x := i * w
		if i >= lit:
			_slab(x, w - 4, h, off)
		elif low:
			_slab(x, w * 0.5 - 3, h, on)
			_slab(x + w * 0.5, w * 0.5 - 4, h, on)
		else:
			_slab(x, w - 4, h, on)


func _slab(x: float, w: float, h: float, col: Color) -> void:
	bar.draw_colored_polygon(PackedVector2Array([
		Vector2(x + SLANT, 0), Vector2(x + SLANT + w, 0), Vector2(x + w, h), Vector2(x, h)]), col)
