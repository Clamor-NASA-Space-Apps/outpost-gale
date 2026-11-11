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
const CHAMFER := 14  # the cut corner every panel and button shares
const STROKE := 2

var tokens: Dictionary
var ts := TextServerManager.get_primary_interface()


func _initialize() -> void:
	tokens = JSON.parse_string(FileAccess.get_file_as_string("res://design.json"))
	var theme := build()
	var err := ResourceSaver.save(theme, OUT)
	print("theme: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func c(name: String, alpha := 1.0) -> Color:
	var col := Color.html(tokens.colors[name])
	col.a = alpha
	return col


func px(style: String) -> int:
	return roundi(float(String(tokens.typography[style].fontSize).trim_suffix("px")) * TYPE_SCALE)


func font(path: String, weight: int, tabular := false) -> FontVariation:
	var f := FontVariation.new()
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

	for n: String in ["primary", "on-primary", "accent", "light", "danger", "on-surface", "on-surface-variant",
			"surface", "surface-container", "outline-variant", "sky", "horizon", "ground"]:
		t.set_color(n.replace("-", "_"), "Hud", c(n))  # theme item names take no dashes

	t.set_color("font_color", "Label", c("on-surface"))
	t.set_constant("line_spacing", "Label", 2)
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
	}
	for v: String in labels:
		t.set_type_variation(v, "Label")
		t.set_font("font", v, labels[v][0])
		t.set_font_size("font_size", v, labels[v][1])
		t.set_color("font_color", v, labels[v][2])

	# Panels. "bracket" is the colour hud_panel.gd draws its corner brackets in.
	var panels := {
		"HudPanel": [box(c("surface", 0.92), c("primary", 0.45), c("primary", 0.14)), c("primary")],
		"HudPanelAlert": [box(c("danger"), c("on-primary", 0.35), c("danger", 0.55)), c("danger")],
		"HudPanelLost": [box(c("surface", 0.94), c("danger", 0.8), c("danger", 0.22)), c("danger")],
		"HudPanelSoft": [box(c("surface-container", 0.95), c("outline-variant")), c("outline-variant")],
		"Tag": [tag(c("primary")), c("primary")],
		"TagLive": [tag(c("accent")), c("accent")],
		"TagDanger": [tag(c("danger")), c("danger")],
		"TagArchive": [tag(c("outline-variant")), c("outline-variant")],
	}
	for v: String in panels:
		t.set_type_variation(v, "PanelContainer")
		t.set_stylebox("panel", v, panels[v][0])
		t.set_color("bracket", v, panels[v][1])
	var hud: StyleBoxFlat = t.get_stylebox("panel", "HudPanel")
	hud.content_margin_left = 20
	hud.content_margin_right = 20
	hud.content_margin_top = 14
	hud.content_margin_bottom = 16

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
	t.set_stylebox("normal", "Button", box(c("primary"), Color.TRANSPARENT, c("primary", 0.25)))
	t.set_stylebox("hover", "Button", box(c("primary").lightened(0.18), Color.TRANSPARENT, c("primary", 0.4)))
	t.set_stylebox("pressed", "Button", box(c("primary").darkened(0.15)))
	t.set_stylebox("disabled", "Button", box(c("outline-variant")))
	t.set_stylebox("focus", "Button", focus)
	t.set_constant("h_separation", "Button", 10)
	t.set_constant("icon_max_width", "Button", 30)

	# A choice: dark with a teal stroke, because teal means "you can use this".
	t.set_type_variation("ChoiceButton", "Button")
	t.set_font("font", "ChoiceButton", font(lex, 600))
	t.set_font_size("font_size", "ChoiceButton", label + 2)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "ChoiceButton", c("on-surface"))
	t.set_stylebox("normal", "ChoiceButton", box(c("surface-container", 0.96), c("accent"), c("accent", 0.12)))
	t.set_stylebox("hover", "ChoiceButton", box(c("surface-container").lerp(c("accent"), 0.12), c("light"), c("accent", 0.3)))
	t.set_stylebox("pressed", "ChoiceButton", box(c("surface-container").lerp(c("accent"), 0.22), c("light")))

	# Touch skins for the player lane: round, see-through so the world shows, teal because usable.
	t.set_type_variation("TouchButton", "Button")
	for st: String in ["normal", "hover", "focus"]:
		t.set_stylebox(st, "TouchButton", circle(c("surface", 0.62), c("accent", 0.9)))
	t.set_stylebox("pressed", "TouchButton", circle(c("accent", 0.45), c("light")))
	t.set_font("font", "TouchButton", font(exo, 700))
	t.set_constant("icon_max_width", "TouchButton", 44)
	t.set_font_size("font_size", "TouchButton", label)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "TouchButton", c("on-surface"))
	t.set_type_variation("StickBase", "Panel")
	t.set_stylebox("panel", "StickBase", circle(c("surface", 0.4), c("accent", 0.6), 2))
	t.set_type_variation("StickKnob", "Panel")
	t.set_stylebox("panel", "StickKnob", circle(c("accent", 0.85), c("light"), 3))
	return t
