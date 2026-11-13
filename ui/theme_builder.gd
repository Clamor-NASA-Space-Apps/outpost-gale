extends SceneTree
## Builds ui/theme.tres from res://design.json, so every HUD colour has one source.
##   godot --headless --path . -s ui/theme_builder.gd
## Run it again after any DESIGN.md colour change (design-tokens.mjs writes design.json first).
## Components read colours with Hud.color(name), which looks them up under the "Hud" type here.

const OUT := "res://ui/theme.tres"
# Typography tokens are CSS px for a page. The HUD canvas is 720 px tall, and 28 px at 1080p
# (Game Accessibility Guidelines, design/research/sizes.md B) is 18.7 px here: x1.2 puts the
# smallest token (label, 16) on that floor and keeps the ratios DESIGN.md set.
const TYPE_SCALE := 1.2
const CHAMFER := 14  # the cut corner the tags and the old cards share
const STROKE := 2
# The glass look (design/mockups/hud.html, approved 13 Nov 2026) is drawn at 1080p; the HUD canvas is 720 px tall,
# so every mockup px is two thirds of a canvas px (g()).
const RADIUS := 10  # mockup px
const GLASS_STROKE := 1  # 1.5 mockup px
const GLOW := 18  # mockup px

var tokens: Dictionary
var ts := TextServerManager.get_primary_interface()


func _initialize() -> void:
	tokens = JSON.parse_string(FileAccess.get_file_as_string("res://design.json"))
	var theme := build()
	var err := ResourceSaver.save(theme, OUT)
	print("theme: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


## A token's colour with its own alpha (an 8-digit hex keeps it).
func c(name: String) -> Color:
	return Color.html(tokens.colors[name])


## A 1080p mockup size on the 720 px canvas.
static func g(mockup_px: float) -> int:
	return maxi(1, roundi(mockup_px * 720.0 / 1080.0))


## A glass panel: the tint, a thin bright stroke and a soft outer glow, no blur (phones). The top highlight is drawn
## by ui/hud_panel.gd, since a flat style has one border colour.
func glass(bg: Color, border: Color, glow: Color, pad := Vector2(18, 14)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(GLASS_STROKE if border.a > 0.0 else 0)
	s.set_corner_radius_all(g(RADIUS))
	s.shadow_color = glow
	s.shadow_size = g(GLOW) if glow.a > 0.0 else 0
	s.anti_aliasing = true
	s.content_margin_left = g(pad.x)
	s.content_margin_right = g(pad.x)
	s.content_margin_top = g(pad.y)
	s.content_margin_bottom = g(pad.y)
	return s


func px(style: String) -> int:
	return roundi(float(String(tokens.typography[style].fontSize).trim_suffix("px")) * TYPE_SCALE)


func font(path: String, weight: int, tabular := false, spacing := 0) -> FontVariation:
	var f := FontVariation.new()
	f.spacing_glyph = spacing  # the mockup's letter-spaced capitals
	f.base_font = load(path)
	f.variation_opentype = {ts.name_to_tag("wght"): weight}
	if tabular:
		# digits of equal width, so a countdown or a meter number never jitters sideways
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
	return f


## A panel with two cut corners (corner_detail 1 turns a radius into a straight 45 degree cut).
func box(bg: Color, border := Color.TRANSPARENT, glow := Color.TRANSPARENT, cut := CHAMFER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(STROKE if border.a > 0.0 else 0)
	s.corner_radius_top_right = cut
	s.corner_radius_bottom_left = cut
	s.corner_detail = 1
	s.shadow_color = glow
	s.shadow_size = 10 if glow.a > 0.0 else 0
	s.anti_aliasing = true
	s.set_content_margin_all(12)
	return s


func circle(bg: Color, border: Color, width := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(9999)
	s.corner_detail = 24
	return s


func tag(bg: Color) -> StyleBoxFlat:
	var s := box(bg, Color.TRANSPARENT, Color.TRANSPARENT, 0)
	s.skew = Vector2(0.25, 0)  # the leaning tag is the "visor display" signature, text stays upright
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func build() -> Theme:
	var t := Theme.new()
	var lex := "res://ui/fonts/Lexend-latin-wght.woff2"
	var exo := "res://ui/fonts/Exo2-wght.ttf"
	var body := px("body")
	var label := px("label")
	var heading := px("headline")

	t.default_font = font(lex, 400)
	t.default_font_size = body

	# every hud-* token (the glass, its strokes and glows, the scrims: each with its alpha, in DESIGN.md) and the base
	# colours the HUD uses. A component asks for Hud.color("hud-scrim"), never for a colour with an alpha of its own.
	var names: Array = ["primary", "on-primary", "accent", "light", "danger", "on-surface", "on-surface-variant",
			"surface", "surface-container", "outline-variant", "sky", "horizon", "ground"]
	names.append_array(tokens.colors.keys().filter(func(k: String) -> bool: return k.begins_with("hud-")))
	for n: String in names:
		t.set_color(n.replace("-", "_"), "Hud", c(n))  # theme item names take no dashes

	t.set_color("font_color", "Label", c("on-surface"))
	t.set_constant("line_spacing", "Label", 2)
	# text over in-game glass sees the world through it: a soft dark edge keeps it readable on a bright sky
	t.set_color("font_outline_color", "Label", c("hud-text-edge"))
	t.set_constant("outline_size", "Label", 3)
	var labels := {
		"Caption": [font(lex, 500), label, c("on-surface-variant")],
		"Heading": [font(exo, 700), roundi(heading * 0.85), c("on-surface")],
		"Title": [font(exo, 800), heading + 10, c("on-surface")],
		"Number": [font(exo, 700, true), heading, c("primary")],
		"BigNumber": [font(exo, 800, true), heading + 20, c("primary")],
		"OnFill": [font(exo, 700), label, c("on-primary")],
		"AccentText": [font(exo, 700, true), label, c("accent")],
		"SmallNumber": [font(exo, 700, true), label + 3, c("primary")],
		"TagText": [font(exo, 700), label, c("on-surface")],
		"OnFillBody": [font(lex, 500), label + 1, c("on-primary")],
		# the glass HUD, sizes from design/mockups/hud.html and settings.html (1080p px)
		"Cap": [font(lex, 600, false, 2), g(13), c("on-surface-variant")],
		"CapInk": [font(lex, 600, false, 2), g(13), c("on-surface")],
		"CapLight": [font(lex, 600, false, 2), g(13), c("light")],
		"HudText": [font(lex, 400), g(17), c("on-surface")],
		"HudTextDim": [font(lex, 400), g(17), c("on-surface-variant")],
		"HudNum": [font(exo, 700, true), g(17), c("on-surface")],
		"HudNumDim": [font(exo, 700, true), g(18), c("on-surface-variant")],
		"HudNumAmber": [font(exo, 700, true), g(16), c("primary")],
		"SolNum": [font(exo, 700, true), g(30), c("on-surface")],
		"Compass": [font(exo, 700), g(17), c("on-surface")],
		"CompassNorth": [font(exo, 700), g(17), c("primary")],
		"CompassSmall": [font(lex, 500), g(12), c("hud-ink-dim")],
		"CompassHeading": [font(exo, 700, true), g(16), c("light")],
		"BubbleText": [font(lex, 500), g(22), c("on-surface")],
		"PromptText": [font(lex, 400), g(19), c("on-surface")],
		"KeyText": [font(exo, 700), g(14), c("on-surface")],
		"KeyAmber": [font(exo, 700), g(17), c("primary")],
		"MenuTitle": [font(lex, 700), g(26), c("on-surface")],
		"MenuText": [font(lex, 400), g(16), c("on-surface")],
		"MenuSmall": [font(lex, 400), g(13), c("on-surface-variant")],
		"MenuFoot": [font(lex, 400), g(15), c("on-surface-variant")],
		"MenuStrong": [font(lex, 600), g(16), c("on-surface")],
		"HudSmall": [font(lex, 400), g(14), c("on-surface-variant")],
		"OnFillTitle": [font(exo, 700), g(18), c("on-primary")],
		"OnFillText": [font(lex, 500), g(15), c("on-primary")],
	}
	for v: String in labels:
		t.set_type_variation(v, "Label")
		t.set_font("font", v, labels[v][0])
		t.set_font_size("font_size", v, labels[v][1])
		t.set_color("font_color", v, labels[v][2])
		if v.begins_with("OnFill"):
			t.set_constant("outline_size", v, 0)  # dark text on a solid fill needs no dark edge

	# Panels: in-game glass (HudPanel) lets the world through; menu glass (HudMenu: cards, settings, the map) holds
	# more back. "highlight" is the line ui/hud_panel.gd draws along the top inside edge.
	var none := Color.TRANSPARENT
	var panels := {
		"HudPanel": glass(c("hud-glass"), c("hud-stroke"), c("hud-glow")),
		"HudMenu": glass(c("hud-glass-menu"), c("hud-stroke"), c("hud-glow"), Vector2(30, 26)),
		"HudPanelAlert": glass(c("danger"), none, c("hud-glow-danger")),
		"HudPanelLost": glass(c("hud-glass-menu"), c("danger"), c("hud-glow-danger"), Vector2(30, 26)),
		"HudPanelSoft": glass(c("hud-glass-menu"), c("hud-stroke-faint"), none, Vector2(12, 10)),
		"HudKey": glass(c("hud-key"), c("on-surface-variant"), none, Vector2(8, 3)),
		"HudKeyAmber": glass(c("hud-key"), c("primary"), none, Vector2(8, 3)),
		"SegGroup": glass(none, c("hud-stroke"), none, Vector2(0, 0)),
		"Tag": tag(c("primary")),
		"TagLive": tag(c("accent")),
		"TagDanger": tag(c("danger")),
		"TagArchive": tag(c("outline-variant")),
	}
	for v: String in panels:
		t.set_type_variation(v, "PanelContainer")
		t.set_stylebox("panel", v, panels[v])
		t.set_color("highlight", v, c("hud-highlight") if v.begins_with("Hud") else none)
	(panels.HudKey as StyleBoxFlat).set_corner_radius_all(g(5))
	(panels.HudKeyAmber as StyleBoxFlat).set_corner_radius_all(g(5))
	(panels.SegGroup as StyleBoxFlat).set_corner_radius_all(g(7))

	var focus := box(Color.TRANSPARENT, c("accent"))
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.set_expand_margin_all(4)

	# The main action: amber fill, one per card (DESIGN.md components.button).
	t.set_font("font", "Button", font(exo, 700))
	t.set_font_size("font_size", "Button", label + 3)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", c("on-primary"))
	t.set_color("font_disabled_color", "Button", c("on-surface-variant"))
	t.set_color("icon_normal_color", "Button", c("on-primary"))
	t.set_stylebox("normal", "Button", glass(c("primary"), none, c("hud-glow-amber"), Vector2(22, 10)))
	t.set_stylebox("hover", "Button", glass(c("primary").lightened(0.18), none, c("hud-glow-amber"), Vector2(22, 10)))
	t.set_stylebox("pressed", "Button", glass(c("primary").darkened(0.15), none, none, Vector2(22, 10)))
	t.set_stylebox("disabled", "Button", glass(c("outline-variant"), none, none, Vector2(22, 10)))
	t.set_stylebox("focus", "Button", focus)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 30)

	# A choice: dark with a teal stroke, because teal means "you can use this".
	t.set_type_variation("ChoiceButton", "Button")
	t.set_font("font", "ChoiceButton", font(lex, 600))
	t.set_font_size("font_size", "ChoiceButton", label + 2)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "ChoiceButton", c("on-surface"))
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		t.set_color(state, "ChoiceButton", c("accent"))  # a mark on a choice (the preset in use) is teal, "on"
	t.set_stylebox("normal", "ChoiceButton", glass(c("hud-glass-menu"), c("hud-stroke"), c("hud-glow"), Vector2(14, 8)))
	t.set_stylebox("hover", "ChoiceButton", glass(c("hud-glass-menu").lerp(c("accent"), 0.12), c("light"), c("hud-glow"), Vector2(14, 8)))
	t.set_stylebox("pressed", "ChoiceButton", glass(c("hud-glass-menu").lerp(c("accent"), 0.22), c("light"), none, Vector2(14, 8)))
	# a stepper's arrow at the end of its range: a faint outline and faint text, no fill (the shape changes, too)
	t.set_stylebox("disabled", "ChoiceButton", glass(none, c("hud-stroke-faint"), none, Vector2(14, 8)))
	t.set_color("font_disabled_color", "ChoiceButton", c("hud-ink-ghost"))

	# Settings: a tab (teal edge and tint when open), a segment of a switch, a device card (amber when picked).
	var flat := glass(none, none, none, Vector2(14, 11))
	var tab_on := glass(c("hud-tab-on"), none, none, Vector2(14, 11))
	tab_on.border_color = c("accent")
	tab_on.border_width_left = g(3)
	t.set_type_variation("TabButton", "Button")
	t.set_font("font", "TabButton", font(lex, 400))
	t.set_font_size("font_size", "TabButton", g(18))
	for st: String in ["normal", "hover", "focus"]:
		t.set_stylebox(st, "TabButton", flat)
	t.set_stylebox("pressed", "TabButton", tab_on)
	t.set_stylebox("hover_pressed", "TabButton", tab_on)
	t.set_stylebox("focus", "TabButton", focus)
	for st: String in ["font_color", "font_hover_color", "icon_normal_color", "icon_hover_color"]:
		t.set_color(st, "TabButton", c("on-surface-variant"))
	for st: String in ["font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		t.set_color(st, "TabButton", c("on-surface"))
	t.set_constant("icon_max_width", "TabButton", g(20))
	t.set_constant("h_separation", "TabButton", g(12))
	var seg_on := glass(c("hud-seg-on"), none, none, Vector2(11, 7))
	seg_on.set_corner_radius_all(0)
	seg_on.border_color = c("accent")
	seg_on.border_width_bottom = g(2)
	var seg := glass(none, none, none, Vector2(11, 7))
	seg.set_corner_radius_all(0)
	t.set_type_variation("SegButton", "Button")
	t.set_font("font", "SegButton", font(exo, 600))
	t.set_font_size("font_size", "SegButton", g(14))
	for st: String in ["normal", "hover"]:
		t.set_stylebox(st, "SegButton", seg)
	t.set_stylebox("pressed", "SegButton", seg_on)
	t.set_stylebox("hover_pressed", "SegButton", seg_on)
	t.set_stylebox("focus", "SegButton", focus)
	for st: String in ["font_color", "font_hover_color"]:
		t.set_color(st, "SegButton", c("on-surface-variant"))
	for st: String in ["font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(st, "SegButton", c("on-surface"))
	var card := glass(c("hud-glass"), c("hud-stroke"), c("hud-glow"), Vector2(10, 14))
	var card_on := glass(c("hud-glass"), c("primary"), c("hud-glow-amber"), Vector2(10, 14))
	t.set_type_variation("DeviceCard", "Button")
	for st: String in ["normal", "hover"]:
		t.set_stylebox(st, "DeviceCard", card)
	t.set_stylebox("pressed", "DeviceCard", card_on)
	t.set_stylebox("hover_pressed", "DeviceCard", card_on)
	t.set_stylebox("focus", "DeviceCard", focus)

	# Touch skins for the player lane: round, see-through so the world shows, teal because usable.
	t.set_type_variation("TouchButton", "Button")
	for st: String in ["normal", "hover", "focus"]:
		t.set_stylebox(st, "TouchButton", circle(c("hud-glass"), c("hud-stroke"), 2))
	t.set_stylebox("pressed", "TouchButton", circle(c("hud-seg-on"), c("light")))
	t.set_font("font", "TouchButton", font(exo, 700))
	t.set_constant("icon_max_width", "TouchButton", 44)
	t.set_color("font_outline_color", "TouchButton", c("hud-text-edge"))  # its word sits on see-through glass
	t.set_constant("outline_size", "TouchButton", 3)
	t.set_font_size("font_size", "TouchButton", label)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		t.set_color(state, "TouchButton", c("on-surface"))  # the icon too: Button's on-primary was dark on dark
	t.set_type_variation("StickBase", "Panel")
	t.set_stylebox("panel", "StickBase", circle(c("hud-glass"), c("hud-stroke"), 2))
	t.set_type_variation("StickKnob", "Panel")
	t.set_stylebox("panel", "StickKnob", circle(c("accent"), c("light"), 3))
	return t
