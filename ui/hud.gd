extends RefCounted
## What every HUD component builds from: theme colours, icons, labels, boxes.
## const Hud := preload("res://ui/hud.gd"), then Hud.label("Power"), Hud.icon("power"), Hud.color("danger").
## Colours come only from ui/theme.tres (built from design.json by ui/theme_builder.gd): no colour literals here.

const THEME: Theme = preload("res://ui/theme.tres")
const HudPanel := preload("res://ui/hud_panel.gd")
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


## A white-stroke icon from ui/icons, tinted by modulate so one file serves every colour.
static func icon(name: String, size := 32.0, tint := "primary") -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://ui/icons/%s.svg" % name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.self_modulate = color(tint)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


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
	return b


static func col(kids: Array, sep := 8) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	for k: Control in kids:
		b.add_child(k)
	return b


## A themed panel around one child. Variations live in theme_builder.gd: HudPanel, HudPanelAlert,
## HudPanelLost, HudPanelSoft, Tag, TagLive, TagDanger, TagArchive.
static func panel(variation: String, child: Control, brackets := false) -> PanelContainer:
	var p: PanelContainer = HudPanel.new()
	p.theme_type_variation = variation
	p.brackets = brackets
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
