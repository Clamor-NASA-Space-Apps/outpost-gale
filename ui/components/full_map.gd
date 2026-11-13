extends Control
## The full map (M, or a tap on the minimap): a menu glass card over a scrim with Gale crater on the left and our base
## on the right. On the crater: the base and the field sites at their real distance and bearing from it (data/world.json
## `sites`: km and bearing from research/junior-astronaut/mission-collisions.md). On the base: its places
## (world.json `landmarks`), the hero, PIP and the objective, on the picture tools/bake_minimap.gd made.
## The crater picture is the LPG-3D model's colour (NASA/JPL-Caltech/MSSS, CC BY-NC 4.0, ASSETS.md); its north and
## scale are approximate, as on the table map in HAB 1 (forge/prop_gale_map.py), so the base pin is near, not exact.
## Set `hero`, `pip`, `objective` (world x, z as Vector2, or null) and `yaw` before showing it; refresh() redraws.

signal closed

const Hud := preload("res://ui/hud.gd")
const GALE := preload("res://models/prop_gale_map_gale_1024.jpg")
const BASE := preload("res://ui/map/base.png")
const PICTURE_M := 400.0  # the base picture's width (tools/bake_minimap.gd)
# The crater picture, as forge/prop_gale_map.py reads it: the rim fills about 0.8 of the width (by eye) and Gale is
# 154 km across, +y north; the base sits 29.0 km north and 24.2 km west of Mount Sharp's summit (that recipe's KM_N,
# KM_W), the summit taken as the dark pit near the middle of the picture (by eye).
const GALE_PX_PER_KM := 0.8 * 1024.0 / 154.0
const SUMMIT_PX := Vector2(535, 495)
const BASE_FROM_SUMMIT_KM := Vector2(-24.17, -28.99)  # x east, y south on the picture
const SIDE := 300.0  # each picture's side on the card
# every place an objective may name; the base picture labels only FAR ones, since the rest crowd round the habitat
# (the minimap shows those close up)
const PLACES := {"base": "Habitat", "greenhouse": "Greenhouse", "solar": "Solar farm", "rover": "Rover",
	"lander": "Lander", "reactor": "Reactor", "mav": "Ascent rocket", "airlock": "Airlock"}
const FAR := {"base": "Base", "lander": "Lander", "reactor": "Reactor", "mav": "Ascent rocket"}

var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
var width := 720.0
var height := 720.0  # the screen's: the pictures shrink so the card fits a phone's short side
var touch := false  # a touch screen gets a close chip big enough for a finger
var hero = Vector2.ZERO
var yaw := 0.0
var pip = null
var objective = null
var close_button := Button.new()
var crater := TextureRect.new()
var inset := TextureRect.new()
var card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("hud-scrim-menu")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	close_button.name = "Close"
	close_button.text = "Esc"
	close_button.icon = load("res://ui/icons/close.svg")
	close_button.theme_type_variation = "ChoiceButton"
	# 48 px on a laptop, 96 scene px under a phone's PHONE_SCALE (addons/forge/test.gd TARGET)
	var h := 96.0 / Hud.PHONE_SCALE if touch else 48.0
	close_button.custom_minimum_size = Vector2(h * 1.8, h)
	close_button.pressed.connect(func() -> void: closed.emit())
	var narrow := width < 600.0  # a narrow screen stacks the crater over the base
	var side := minf(minf(SIDE, (width - 80.0) * (1.0 if narrow else 0.5)), height - 290.0)
	for t: Array in [[crater, GALE, _draw_crater], [inset, BASE, _draw_base]]:
		var r: TextureRect = t[0]
		r.texture = t[1]
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.custom_minimum_size = Vector2(side, side)
		r.draw.connect(t[2])
	var legend := Hud.col([
		Hud.row([_swatch("base"), Hud.label("Our base", "MenuText")], 8),
		Hud.row([_swatch("mercou"), Hud.label(_site("mercou"), "MenuText")], 8),
		Hud.row([_swatch("curiosity"), Hud.label(_site("curiosity"), "MenuText")], 8),
		Hud.row([Hud.tag("TagArchive", "archive", "ARCHIVED", "CapInk", 12), Hud.label("Curiosity's place on 10 Nov 2026", "MenuSmall", true)], 8),
	], 6)
	var left := Hud.col([Hud.label("Gale crater", "Cap"), crater, legend], 8)
	var right := Hud.col([Hud.label("Our base", "Cap"), inset, Hud.label("400 m across", "MenuSmall")], 8)
	var body := Hud.col([
		Hud.row([Hud.icon("earth", 20, "on_surface"), Hud.label("Map", "MenuTitle"), Hud.spacer(), close_button], 10),
		_box([left, right], narrow),
		Hud.label("Crater: LPG-3D from NASA/JPL-Caltech/MSSS (CC BY-NC)", "MenuSmall", true),
	], 10)
	card = Hud.panel("HudMenu", body)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	add_child(center)


func _box(kids: Array, vertical: bool) -> BoxContainer:
	var b := BoxContainer.new()
	b.vertical = vertical
	b.add_theme_constant_override("separation", 20)
	for k: Control in kids:
		b.add_child(k)
	return b


## "Mont Mercou  8.8 km": a site's name and its real distance from the base.
func _site(id: String) -> String:
	var s: Dictionary = world.sites[id]
	var name: String = String(s.label).get_slice(",", 0)
	return "%s  %s km" % [name, String.num(s.km, 1)]


func refresh() -> void:
	crater.queue_redraw()
	inset.queue_redraw()


## Where a site is on the crater picture: the base, then its km and bearing (0 north, clockwise).
func crater_px(km: float, bearing: float) -> Vector2:
	var base := SUMMIT_PX + BASE_FROM_SUMMIT_KM * GALE_PX_PER_KM
	return base + Vector2(sin(deg_to_rad(bearing)), -cos(deg_to_rad(bearing))) * km * GALE_PX_PER_KM


func _draw_crater() -> void:
	var k := crater.size.x / 1024.0
	var base := crater_px(0.0, 0.0) * k
	_mark(crater, "base", base)
	for id: String in ["mercou", "curiosity"]:
		var s: Dictionary = world.sites[id]
		_mark(crater, id, crater_px(s.km, s.bearing) * k)
	_north(crater)


## A place on the base picture: world x, z (CONTRACTS.md) to the inset's pixels.
func base_px(p: Vector2) -> Vector2:
	return (p / PICTURE_M + Vector2(0.5, 0.5)) * inset.size


func _draw_base() -> void:
	var f := get_theme_font("font", "MenuSmall")
	var fs := get_theme_font_size("font_size", "MenuSmall")
	for id: String in FAR:
		var l: Array = world.landmarks.get(id, [])
		if l.is_empty():
			continue
		var at := base_px(Vector2(l[0], l[1]))
		inset.draw_circle(at, 2.5, Hud.color("on-surface"))
		var off := Vector2(-f.get_string_size(FAR[id], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x - 6, 4) if id == "base" else Vector2(5, 4)
		inset.draw_string_outline(f, at + off, FAR[id], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Hud.color("hud-text-edge"))
		inset.draw_string(f, at + off, FAR[id], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Hud.color("on-surface"))
	if objective != null:
		_mark(inset, "objective", base_px(objective))
	if pip != null:
		inset.draw_circle(base_px(pip), 4.0, Hud.color("accent"))
	var o := base_px(hero)
	var a := deg_to_rad(yaw)
	inset.draw_colored_polygon(PackedVector2Array([o + Vector2(0, -9).rotated(a), o + Vector2(6, 6).rotated(a), o + Vector2(0, 2).rotated(a), o + Vector2(-6, 6).rotated(a)]), Hud.color("light"))
	_north(inset)


func _north(c: Control) -> void:
	var f := get_theme_font("font", "CompassNorth")
	var fs := get_theme_font_size("font_size", "CompassNorth")
	c.draw_string_outline(f, Vector2(c.size.x * 0.5 - 5, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Hud.color("hud-text-edge"))
	c.draw_string(f, Vector2(c.size.x * 0.5 - 5, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Hud.color("primary"))


## Each kind of place has its own shape as well as colour: the base a teal ring, Mont Mercou an amber triangle (a
## rock), Curiosity a light square (a rover), the objective an amber diamond.
func _mark(c: Control, kind: String, p: Vector2) -> void:
	match kind:
		"base":
			c.draw_arc(p, 5.0, 0.0, TAU, 20, Hud.color("accent"), 2.5, true)
		"mercou":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 5), p + Vector2(-6, 5)]), Hud.color("primary"))
		"curiosity":
			c.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), Hud.color("light"))
		_:
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), Hud.color("primary"))


## The legend's copy of a mark.
func _swatch(kind: String) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(16, 16)
	s.set_meta("icon", true)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.draw.connect(func() -> void: _mark(s, kind, s.size * 0.5))
	return s
