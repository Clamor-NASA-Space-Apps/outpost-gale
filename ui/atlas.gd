extends RefCounted
## One texture for everything the play HUD draws that is not text: the glass panels as nine-patches (tint, stroke,
## glow and top highlight baked in), the icons, and the small shapes (diamond, dot, caret, arrows, rings, bars). The
## 2D renderer batches draws that share a texture, so the whole HUD's shapes cost one or two draw calls instead of one
## per panel, icon and polygon (the v2 HUD drew 181 times; skills/frame-budget). ui/theme_builder.gd calls build()
## and saves ui/atlas.png and ui/atlas.json; Hud reads them (Hud.region(), Hud.atlas()).
## Colours are the design.json tokens; sizes are canvas px (the 720 px tall HUD canvas).

const WIDTH := 1024
const PAD := 8  # px of edge copy round each region, so filtering and mipmaps never pull in a neighbour
const ICON := 72  # icons are drawn at 12 to 34 px; this is the size their SVGs imported at before (svg/scale 3)
const RADIUS := 7  # the glass's corner (10 mockup px)
const GLOW := 12  # the glass's outer glow (18 mockup px)

var tokens: Dictionary
var images := {}  # name -> Image
var margins := {}  # nine-patch name -> its margin (px) on every side
var expand := {}  # nine-patch name -> how far it draws past its box (the glow)


func _init(t: Dictionary) -> void:
	tokens = t


func c(name: String) -> Color:
	return Color.html(tokens.colors[name])


## Every region, then one packed image: {image: Image, regions: {name: [x, y, w, h]}, margins, expand}.
func build() -> Dictionary:
	var none := Color(0, 0, 0, 0)
	_panel("glass", c("hud-glass"), c("hud-stroke"), c("hud-glow"), RADIUS, GLOW, true)
	_panel("alert", c("danger"), none, c("hud-glow-danger"), RADIUS, GLOW, true)
	_panel("alert_glow", none, none, c("hud-glow-danger"), RADIUS, GLOW, false)
	_panel("key", c("hud-key"), c("on-surface-variant"), none, 3, 0, false)
	_panel("key_amber", c("hud-key"), c("primary"), none, 3, 0, false)
	_panel("choice", c("hud-glass-menu"), c("hud-stroke"), c("hud-glow"), RADIUS, GLOW, true)
	_panel("choice_hover", c("hud-glass-menu").lerp(c("accent"), 0.12), c("light"), c("hud-glow"), RADIUS, GLOW, true)
	_panel("choice_pressed", c("hud-glass-menu").lerp(c("accent"), 0.22), c("light"), none, RADIUS, 0, true)
	_panel("pill", Color.WHITE, none, none, 2, 0, false)
	_panel("pill_glow", none, none, Color.WHITE, 2, 5, false)
	_tag("tag_archive", c("outline-variant"), 16)
	# the touch controls: circles at the size they are drawn (a nine-patch whose corners meet stays a circle)
	_circle("touch", 96, c("hud-glass"), c("hud-stroke"), 2)
	_circle("touch_pressed", 96, c("hud-seg-on"), c("light"), 2)
	_circle("stick_base", 150, c("hud-glass"), c("hud-stroke"), 2)
	_circle("stick_knob", 68, c("accent"), c("light"), 3)
	images["white"] = _fill(8, 8, Color.WHITE)
	images["diamond"] = _shape(16, func(p: Vector2) -> float: return 7.5 - (absf(p.x) + absf(p.y)))
	images["dot"] = _shape(16, func(p: Vector2) -> float: return 7.5 - p.length())
	images["glow_dot"] = _soft(32)
	images["ring"] = _shape(16, func(p: Vector2) -> float: return 1.0 - absf(p.length() - 6.0))
	images["box_line"] = _shape(16, func(p: Vector2) -> float: return 0.75 - absf(_round_box(p, Vector2(6, 6), 3.0)))
	images["box_fill"] = _shape(16, func(p: Vector2) -> float: return 0.5 - _round_box(p, Vector2(6, 6), 3.0))
	images["caret"] = _shape(16, func(p: Vector2) -> float: return _triangle(p, Vector2(0, -5.5), Vector2(6, 4.5), Vector2(-6, 4.5)))
	images["arrow"] = _shape(16, func(p: Vector2) -> float: return _triangle(p, Vector2(7, 0), Vector2(-5, -6.5), Vector2(-5, 6.5)))
	images["hero"] = _shape(24, func(p: Vector2) -> float: return maxf(_triangle(p, Vector2(0, -9), Vector2(6.5, 7), Vector2(0, 2.5)), _triangle(p, Vector2(0, -9), Vector2(0, 2.5), Vector2(-6.5, 7))))
	images["disc_ring"] = _ring(172, 78.5, c("hud-stroke"), c("hud-glow"))
	for f: String in DirAccess.get_files_at("res://ui/icons"):
		if f.ends_with(".svg"):
			var img := Image.new()
			img.load_svg_from_string(FileAccess.get_file_as_string("res://ui/icons/" + f), ICON / 24.0)
			img.convert(Image.FORMAT_RGBA8)
			images["icon_" + f.get_basename()] = img
	return _pack()


## A rounded box's nine-patch: the glow's soft edge outside, the tint inside it, the stroke on the edge and a faint
## line just inside the top (the glass's highlight), as StyleBoxFlat drew them, one px per canvas px.
func _panel(n: String, tint: Color, stroke: Color, glow: Color, r: int, g: int, highlight: bool) -> void:
	var side := 2 * (g + r + 2) + 1
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var half := Vector2(side, side) * 0.5 - Vector2(g, g)
	for y in side:
		for x in side:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(side, side) * 0.5
			var d := _round_box(p, half, r)
			var col := Color(0, 0, 0, 0)
			if g > 0:
				col = _over(col, Color(glow, glow.a * (1.0 if d <= 0.0 else clampf(1.0 - d / g, 0.0, 1.0))))
			var inside := clampf(0.5 - d, 0.0, 1.0)
			col = _over(col, Color(tint, tint.a * inside))
			if stroke.a > 0.0:
				var band := clampf(0.5 - d, 0.0, 1.0) * clampf(d + 1.5, 0.0, 1.0)
				col = _over(col, Color(stroke, stroke.a * band))
			if highlight and y == g + 2 and absf(p.x) < half.x - r:
				col = _over(col, c("hud-highlight"))
			img.set_pixel(x, y, col)
	images[n] = img
	margins[n] = g + r + 2
	expand[n] = g


## The leaning tag (theme_builder.gd tag()): a parallelogram, `h` px tall, skewed a quarter of its height.
func _tag(n: String, col: Color, h: int) -> void:
	var slant := h * 0.25
	var w := int(2 * (slant + 4) + 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var off := slant * (1.0 - (y + 0.5) / h)  # the top leans right, as skew x 0.25 does
		for x in w:
			var left := clampf(x + 0.5 - off, 0.0, 1.0)
			var right := clampf((w - slant + off) - (x + 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(col, col.a * minf(left, right)))
	images[n] = img
	margins[n] = int(slant + 4)
	expand[n] = 0


func _circle(n: String, side: int, fill: Color, stroke: Color, width: float) -> void:
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var r := side * 0.5
	for y in side:
		for x in side:
			var d := (Vector2(x + 0.5, y + 0.5) - Vector2(r, r)).length() - r  # negative inside
			var col := Color(fill, fill.a * clampf(0.5 - d, 0.0, 1.0))
			col = _over(col, Color(stroke, stroke.a * clampf(0.5 - d, 0.0, 1.0) * clampf(d + width + 0.5, 0.0, 1.0)))
			img.set_pixel(x, y, col)
	images[n] = img
	margins[n] = side / 2
	expand[n] = 0


func _fill(w: int, h: int, col: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return img


## A white shape from a coverage function (px inside its edge, positive inside), antialiased by one px.
func _shape(side: int, inside: Callable) -> Image:
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(side, side) * 0.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(float(inside.call(p)) + 0.5, 0.0, 1.0)))
	return img


## A soft white glow, strongest in the middle.
func _soft(side: int) -> Image:
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var r := (Vector2(x + 0.5, y + 0.5) - Vector2(side, side) * 0.5).length() / (side * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - r, 0.0, 1.0)))
	return img


## The minimap's rim: a 1.5 px stroke on a 6 px glow.
func _ring(side: int, r: float, stroke: Color, glow: Color) -> Image:
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var d := absf((Vector2(x + 0.5, y + 0.5) - Vector2(side, side) * 0.5).length() - r)
			var col := Color(glow, glow.a * clampf(1.0 - (d - 0.75) / 3.0, 0.0, 1.0))
			col = _over(col, Color(stroke, stroke.a * clampf(1.25 - d, 0.0, 1.0)))
			img.set_pixel(x, y, col)
	return img


static func _round_box(p: Vector2, half: Vector2, r: float) -> float:
	var q := p.abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## Px inside a triangle (positive inside), by its nearest edge.
static func _triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var out := INF
	for e: Array in [[a, b, c], [b, c, a], [c, a, b]]:
		var n: Vector2 = (e[1] - e[0]).orthogonal().normalized()
		if n.dot(e[2] - e[0]) < 0.0:
			n = -n  # toward the third corner: inside
		out = minf(out, (p - e[0]).dot(n))
	return out


static func _over(under: Color, top: Color) -> Color:
	var a := top.a + under.a * (1.0 - top.a)
	if a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Color(top.r, top.g, top.b) * top.a + Color(under.r, under.g, under.b) * under.a * (1.0 - top.a)) / a
	return Color(rgb.r, rgb.g, rgb.b, a)


## Shelf packing, tallest first, each region with PAD px of its own edges copied round it.
func _pack() -> Dictionary:
	var names := images.keys()
	names.sort_custom(func(a: String, b: String) -> bool: return images[a].get_height() > images[b].get_height())
	var spots := {}
	var x := 0
	var y := 0
	var shelf := 0
	for n: String in names:
		var img: Image = images[n]
		var w := img.get_width() + 2 * PAD
		var h := img.get_height() + 2 * PAD
		if x + w > WIDTH:
			x = 0
			y += shelf
			shelf = 0
		spots[n] = Vector2i(x, y)
		x += w
		shelf = maxi(shelf, h)
	var out := Image.create(WIDTH, nearest_po2(y + shelf), false, Image.FORMAT_RGBA8)
	var regions := {}
	for n: String in names:
		var img: Image = images[n]
		var at: Vector2i = spots[n] + Vector2i(PAD, PAD)
		var w := img.get_width()
		var h := img.get_height()
		for py in range(-PAD, h + PAD):
			for px in range(-PAD, w + PAD):
				out.set_pixel(at.x + px, at.y + py, img.get_pixel(clampi(px, 0, w - 1), clampi(py, 0, h - 1)))
		regions[n] = [at.x, at.y, w, h]
	return {"image": out, "regions": regions, "margins": margins, "expand": expand}
