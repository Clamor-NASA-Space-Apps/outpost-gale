extends RefCounted
## What every HUD component builds from: theme colours, icons, labels, boxes.
## const Hud := preload("res://ui/hud.gd"), then Hud.label("Power"), Hud.icon("power"), Hud.color("danger").
## Colours come only from ui/theme.tres (built from design.json by ui/theme_builder.gd): no colour literals here.

const THEME: Theme = preload("res://ui/theme.tres")
const HudPanel := preload("res://ui/hud_panel.gd")
const Icon := preload("res://ui/icon.gd")
# The phone layout draws the HUD 1.4 times larger (PHONE_SCALE): body text then lands near iOS's 17 pt
# default on an iPhone 16, and a 72 px button is 101 scene px, above the 96 px a 48 dp touch target
# needs (addons/forge/test.gd TARGET).
const BUTTON_H := 72.0
const PHONE_SCALE := 1.4
const SOL_H := 24.6597  # Earth hours in a sol, the sim's clock (NSSDC, factcheck row 6)
# The sim's state keys a kid can see a cost, a ledger row or a source for: [icon, name, unit, scale shown].
# panel_dust is 0 to 1 in the state and shown in percent.
const KEYS := {
	"battery_pct": ["battery", "Battery", "%", 1.0],
	"o2_kg": ["oxygen", "Oxygen", "kg", 1.0],
	"water_kg": ["water", "Water", "kg", 1.0],
	"food_kg": ["food", "Food", "kg", 1.0],
	"dose_msv": ["radiation", "Radiation", "mSv", 1.0],
	"panel_dust": ["storm", "Panel dust", "%", 100.0],
	"suit_air_min": ["oxygen", "Suit air", "min", 1.0],
	"energy_in_kwh": ["sun", "Sun power made", "kWh", 1.0],
	"energy_out_kwh": ["power", "Power used", "kWh", 1.0],
	"health": ["health", "Crew health", "", 1.0],
	"science": ["science", "Science", "", 1.0],
}


## A signed amount with its unit, as a kid reads it: "-4.2 kg", "+10 %", "-1" ("55.4 kWh" for energy totals).
static func amount(key: String, v: float) -> String:
	var k: Array = KEYS.get(key, ["", "", "", 1.0])
	v *= k[3]
	# energy made and used are totals, not changes: a "+" on "Power used" would read as a gain
	var plus := "+" if v > 0.0 and not key.begins_with("energy_") else ""
	return plus + num(v) + (" " + k[2] if k[2] else "")


## One decimal below 100 ("16.7", "2.4"), whole numbers above, and no ".0".
static func num(v: float) -> String:
	return String.num(v, 0 if absf(v) >= 100.0 else 1).trim_suffix(".0")


## Theme colour by its design.json name ("on-surface" and "on_surface" both work).
static func color(name: String, alpha := 1.0) -> Color:
	var c := THEME.get_color(name.replace("-", "_"), "Hud")
	c.a *= alpha
	return c


## A white-stroke icon from the atlas, tinted by its own draw colour (ui/icon.gd) so one region serves every colour.
static func icon(name: String, size := 32.0, tint := "primary") -> TextureRect:
	var r: TextureRect = Icon.new()
	r.art = icon_texture(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.custom_minimum_size = Vector2(size, size)
	r.tint = color(tint)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## An icon as a region of the HUD's one texture (ui/atlas.gd), so icons batch with the panels; the SVG if the atlas
## has none (a new icon before ui/theme_builder.gd ran again).
static func icon_texture(name: String) -> Texture2D:
	if THEME.has_icon("icon_" + name, "HudAtlas"):
		return THEME.get_icon("icon_" + name, "HudAtlas")
	return load("res://ui/icons/%s.svg" % name)


## A shape from the atlas (white, tinted by `col`) drawn into `rect` on `ci`: "white", "diamond", "dot", "glow_dot",
## "ring", "box_line", "box_fill", "caret", "arrow", "hero", "disc_ring". One texture for all of them: one batch.
static func blit(ci: CanvasItem, name: String, rect: Rect2, col := Color.WHITE) -> void:
	var t := THEME.get_icon(name, "HudAtlas") as AtlasTexture
	ci.draw_texture_rect_region(t.atlas, rect, t.region, col)


## A shape from the atlas centred on `at`, `size` px across, turned by `angle` (radians).
static func blit_at(ci: CanvasItem, name: String, at: Vector2, size: float, col := Color.WHITE, angle := 0.0) -> void:
	if angle == 0.0:
		blit(ci, name, Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), col)
		return
	ci.draw_set_transform(at, angle)
	blit(ci, name, Rect2(-Vector2(size, size) * 0.5, Vector2(size, size)), col)
	ci.draw_set_transform(Vector2.ZERO)


## The atlas's rounded bar, nine-sliced so its ends stay round at any length (meter fills and tracks); `glow` draws
## the soft halo under a fill instead. A nine-patch from the one texture: it batches with every other shape.
static func pill(ci: CanvasItem, rect: Rect2, col: Color, glow := false) -> void:
	var key := "pill_glow" if glow else "pill"
	if not _boxes.has(key):
		var t := THEME.get_icon(key, "HudAtlas") as AtlasTexture
		var s := StyleBoxTexture.new()
		s.texture = t.atlas
		s.region_rect = t.region
		s.set_texture_margin_all(7.0 if glow else 2.0)  # ui/atlas.gd: radius 2, and a 5 px glow round the glowing one
		s.set_expand_margin_all(5.0 if glow else 0.0)
		_boxes[key] = s
	(_boxes[key] as StyleBoxTexture).modulate_color = col
	ci.draw_style_box(_boxes[key], rect)


static var _boxes := {}


## Draw order for batching. The 2D renderer draws by z_index, then tree order, and starts a new draw call whenever the
## texture or the kind of draw changes (a nine-patch, a rect, a line). Every shape in the HUD comes from the one atlas,
## and each font weight is its own texture. So within a layer (`base`; -1 takes the nearest ancestor's "hud_layer"):
## panels and bars (nine-patches) at base, icons and drawn shapes (rects; a node with meta "shapes") at base + 1, then
## each font at base + 2 + its rank. Absolute z, so the same font in every component draws in one call.
## A node that draws its own words names its theme variation in meta "text_font".
static func layer(root: Node, base := -1) -> void:
	if base < 0:
		var at := root
		while at and not at.has_meta("hud_layer"):
			at = at.get_parent()
		base = at.get_meta("hud_layer") if at else 0
	root.set_meta("hud_layer", base)
	for n: Node in root.find_children("*", "", true, false):
		if (n is Label or n is RichTextLabel) and not String((n as Control).theme_type_variation).begins_with("OnFill"):
			edge(n as Control)  # dark text on a solid fill needs none
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "CanvasItem", true, false))
	for n: Node in nodes:
		var ci := n as CanvasItem
		if ci == null:
			continue
		var font: Font = null
		var size := 0
		var outline := 0
		if n is Label:
			font = (n as Label).get_theme_font("font")
			size = (n as Label).get_theme_font_size("font_size")
			outline = (n as Label).get_theme_constant("outline_size")
		elif n is RichTextLabel:
			font = (n as RichTextLabel).get_theme_font("normal_font")
			size = (n as RichTextLabel).get_theme_font_size("normal_font_size")
			outline = (n as RichTextLabel).get_theme_constant("outline_size")
		elif n.has_meta("text_font"):
			var v: String = n.get_meta("text_font")
			font = (n as Control).get_theme_font("font", v)
			size = (n as Control).get_theme_font_size("font_size", v)
			outline = 0  # draws its edges from the fill glyphs too (Hud.edge)
		ci.z_as_relative = false
		if n.has_meta("edge_of"):
			ci.z_index = (n.get_parent() as CanvasItem).z_index  # with its label: same texture, same batch
			continue
		if font:
			ci.z_index = base + 2 + _rank(font, size, outline)
		elif n is TextureRect or n.has_meta("shapes"):
			ci.z_index = base + 1
		else:
			ci.z_index = base
		if n.has_meta("under"):
			ci.z_index = base - 1  # drawn under the panels: the visor arcs, the minimap's picture
		elif n.has_meta("over"):
			ci.z_index = base + 90  # drawn over the words: a strike through them


static var _ranks := {}


## One rank per texture a text draws from: its font file and weight, its size and its outline (a dynamic font keeps
## one glyph texture per size and per outline width).
static func _rank(f: Font, size: int, outline: int) -> int:
	var key := "%d/%d" % [size, outline]
	var base: Font = f
	while base is FontVariation:
		key += str((base as FontVariation).variation_opentype)
		base = (base as FontVariation).base_font
	key = (base.resource_path if base else "") + key
	if not _ranks.has(key):
		_ranks[key] = _ranks.size() + 1
	return _ranks[key]


## The dark edge round a label's letters (the theme's hud-text-edge), so words read over a bright sky. Not Godot's
## outline: an outlined line draws from a second glyph texture, so every label breaks the text's batch twice (the v2
## HUD's 181 draw calls). Here a child drawn behind the label lays the same words 8 times, 1.5 px out all round, from
## the label's own glyph texture: the edge and the words batch into one draw call per font.
static func edge(l: Control) -> void:
	if l.has_node("Edge"):
		return
	var e := Control.new()
	e.name = "Edge"
	e.show_behind_parent = true
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	e.set_meta("edge_of", true)
	e.draw.connect(_draw_edge.bind(e, l))
	l.add_child(e)
	l.draw.connect(e.queue_redraw)  # new words or a new size: the edge follows on the next frame


const EDGE_R := 1.5  # px: the old outline_size 3 drew 1.5 px each side


static func _draw_edge(e: Control, l: Control) -> void:
	var rich := l is RichTextLabel
	var text: String = (l as RichTextLabel).get_parsed_text() if rich else (l as Label).text
	if text == "" or not l.is_visible_in_tree():
		return
	var f := l.get_theme_font("normal_font" if rich else "font")
	var s := l.get_theme_font_size("normal_font_size" if rich else "font_size")
	var p := TextParagraph.new()
	p.add_string(text, f, s)
	p.width = l.size.x
	if rich or (l as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
		p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	else:
		p.break_flags = TextServer.BREAK_MANDATORY
	var align := HORIZONTAL_ALIGNMENT_LEFT if rich else (l as Label).horizontal_alignment
	var gap := 0.0 if rich else float(l.get_theme_constant("line_spacing"))
	var lines := p.get_line_count()
	var tall := 0.0
	for i in lines:
		tall += p.get_line_size(i).y + (gap if i > 0 else 0.0)
	var y := 0.0
	if not rich and (l as Label).vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = floorf((l.size.y - tall) * 0.5)
	elif not rich and (l as Label).vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = l.size.y - tall
	var col := l.get_theme_color("font_outline_color")
	col.a = 1.0 - pow(1.0 - col.a, 1.0 / 3.0)  # about three copies overlap at a letter's edge: together they make its alpha
	# words not typed yet (PIP's bubble, meta "typed" and "ghost") get an edge as faint as they are
	var typed: int = l.get_meta("typed", text.length())
	var faint := col
	faint.a *= float(l.get_meta("ghost", 1.0))
	var ts := TextServerManager.get_primary_interface()
	var ci := e.get_canvas_item()
	for i in lines:
		var w := p.get_line_width(i)
		var x := 0.0 if align == HORIZONTAL_ALIGNMENT_LEFT else ((l.size.x - w) * (1.0 if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.5))
		var rid := p.get_line_rid(i)
		var range_i := p.get_line_range(i)
		# where the typed words end on this line, in px from its start
		var cut := w
		if typed < range_i.y:
			cut = 0.0 if typed <= range_i.x else ts.shaped_text_get_grapheme_bounds(rid, typed).x
		var base := Vector2(x, y + p.get_line_ascent(i))
		for k in 8:
			var o := base + Vector2.from_angle(k * TAU / 8.0) * EDGE_R
			# the clips are px from the line's start and cut whole glyphs: typed up to the cut, faint from it
			if cut >= w:
				ts.shaped_text_draw(rid, ci, o, -1.0, -1.0, col)  # all typed: no clip (a clip cuts the last glyph)
			elif cut > 0.0:
				ts.shaped_text_draw(rid, ci, o, -1.0, cut - 0.5, col)
			if cut < w:
				ts.shaped_text_draw(rid, ci, o, maxf(cut, 0.01), -1.0, faint)
		y += p.get_line_size(i).y + gap


static func label(text: String, variation := "", wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		# a wrapping label asks for no width of its own; without EXPAND it gets none in a row
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func row(kids: Array, sep := 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	for k: Control in kids:
		b.add_child(k)
	b.ready.connect(nudge.bind(b), CONNECT_ONE_SHOT)
	return b


# Cap height over the em, from each font's OS/2 table (sCapHeight / unitsPerEm): Lexend 700/1000, Exo 2 690/1000.
const CAP := {"Lexend": 0.70, "Exo2": 0.69}


## How far below the middle of a label's box its capitals' middle sits (the label centres its line in its box, and the
## line holds descenders and accents, so its middle is not the letters' middle).
static func cap_drop(l: Label) -> float:
	var f := l.get_theme_font("font")
	var s := l.get_theme_font_size("font_size")
	var base: Font = f
	while base is FontVariation:
		base = (base as FontVariation).base_font
	var cap: float = CAP.Exo2 if base and "Exo2" in base.resource_path else CAP.Lexend
	return (f.get_ascent(s) - f.get_descent(s) - cap * s) * 0.5


## In a row, every icon (a TextureRect, or a control with meta "icon") sits centred on the capitals of the row's first
## label, not on its box. Hud.row calls it once the row is in the tree; a row made another way calls it itself.
static func nudge(b: Container) -> void:
	var label: Label = null
	for k: Node in b.get_children():
		if k is Label:
			label = k
			break
	if label == null:
		return
	var dy := cap_drop(label)
	for k: Node in b.get_children():
		if k is TextureRect or k.has_meta("icon"):
			var c := k as Control
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			c.offset_transform_enabled = true
			c.offset_transform_visual_only = false
			c.offset_transform_position = Vector2(0, dy)


static func col(kids: Array, sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	for k: Control in kids:
		b.add_child(k)
	return b


## A themed panel around one child. Variations live in theme_builder.gd: HudPanel, HudPanelAlert,
## HudPanelLost, HudPanelSoft, Tag, TagLive, TagDanger, TagArchive.
static func panel(variation: String, child: Control) -> PanelContainer:
	var p: PanelContainer = HudPanel.new()
	p.theme_type_variation = variation
	p.add_child(child)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A leaning tag: icon and a short word on a solid fill (LIVE, LOW, a cost).
static func tag(variation: String, icon_name: String, text: String, text_variation := "OnFill", icon_size := 22.0) -> PanelContainer:
	var kids: Array = []
	if icon_name:
		kids.append(icon(icon_name, icon_size, "on_primary" if text_variation == "OnFill" else "on_surface"))
	if text:
		kids.append(label(text, text_variation))
	var t := panel(variation, row(kids, 6))
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## "14 Nov 2026": the workspace writes absolute dates this way.
static func date(unix: float) -> String:
	var d := Time.get_date_dict_from_unix_time(int(unix))
	return "%d %s %d" % [d.day, ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.month - 1], d.year]


## Where a world point lands on `c` (a full-screen HUD control), seen through `cam`: {at: Vector2 in c's space,
## on: in view and inside c shrunk by `inset`, dir: the screen direction toward it}. Behind the camera only its side
## counts (dir is down and to its side, else straight down), so a marker docks on the bottom edge toward the side it
## lies, as far out as it is up from the middle: clear of the hero and of a phone's stick and buttons in the corners. The speech bubble and the waypoint both use it.
static func project(c: Control, cam: Camera3D, world: Vector3, inset := 0.0) -> Dictionary:
	var local := cam.global_transform.affine_inverse() * world
	var at := Vector2(c.size.x * 0.5, c.size.y)
	var dir := Vector2.DOWN
	var front := local.z < 0.0
	if front:
		at = c.get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(world)
		dir = Vector2(local.x, -local.y).normalized()
	elif absf(local.x) > 0.05:
		dir = Vector2(signf(local.x), 1.0).normalized()  # behind the camera: the bottom edge, on the side it lies
	var on := front and Rect2(Vector2.ZERO, c.size).grow(-inset).has_point(at)
	return {"at": at, "on": on, "dir": dir if dir != Vector2.ZERO else Vector2.DOWN}


## The spot on c's edge, `inset` in, where a box of `box` size sits when it docks toward `dir`.
static func dock(c: Control, dir: Vector2, box: Vector2, inset: float) -> Vector2:
	var half := (c.size - box) * 0.5 - Vector2(inset, inset)
	var t := minf(half.x / maxf(absf(dir.x), 1e-4), half.y / maxf(absf(dir.y), 1e-4))
	return c.size * 0.5 + dir * t - box * 0.5


## Compass bearing in degrees (0 north, clockwise) of a flat world direction (+X east, -Z north, CONTRACTS.md).
static func bearing(v: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)
