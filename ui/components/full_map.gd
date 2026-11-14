extends Control
## The map (M, or a tap on the minimap): one zoomable view of Gale crater down to our base, as in Far Cry (Ravindu,
## 14 Nov). Wheel or pinch zooms toward the pointer, a drag pans, "Me" recentres on the hero. Places are labelled, and
## the labels thin out as the view zooms out so they never pile up. A tap on a place (or on open ground) marks it: the
## kid's own waypoint, one at a time; a tap on the mark clears it. `marked` tells the HUD, which shows the mark on the
## compass, at the screen's edge and as a beacon in the world.
## The map's space is world metres (x east, y south, the base at 0, 0: CONTRACTS.md). The crater picture is the LPG-3D
## model's colour (NASA/JPL-Caltech/MSSS, CC BY-NC 4.0, ASSETS.md); its north and scale are approximate, as on the
## table map in HAB 1 (forge/prop_gale_map.py), so the base sits near, not exactly on, its real spot. The field sites
## stand at their real km and bearing from the base (data/world.json `sites`), not at their world patches.
## Set `hero`, `pip`, `objective`, `mark` (world x, z as Vector2, or null) and `yaw` before showing it.

signal closed
signal marked(at: Variant, id: String, label: String)  # at null: the mark was cleared

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
const ZOOM_MAX := 8.0  # px a metre, closest in: a habitat about 80 px across
const ZOOM_STEP := 1.25  # one wheel notch
const PICK_PX := 24.0  # a tap this near a label or the mark takes it (a fingertip)
const DRAG_PX := 8.0  # a press that moves further is a drag, not a tap
# every place an objective may name (game_hud.gd), and the base's places on the map with the zoom (px a metre) their
# label shows from: the far ones first, the ones round the habitat only close in
const PLACES := {"base": "Habitat", "greenhouse": "Greenhouse", "solar": "Solar farm", "rover": "Rover",
	"lander": "Lander", "reactor": "Reactor", "mav": "Ascent rocket", "airlock": "Airlock"}
const SHOW_FROM := {"solar": 0.5, "greenhouse": 0.9, "rover": 1.2, "lander": 0.2, "reactor": 0.2, "mav": 0.2}

var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
var width := 720.0
var height := 720.0  # the screen's: the view shrinks so the card fits a phone
var touch := false  # a touch screen gets buttons big enough for a finger
var hero = Vector2.ZERO
var yaw := 0.0
var pip = null
var objective = null
var mark = null  # the kid's waypoint, or null
var mark_id := ""
var close_button := Button.new()
var me_button := Button.new()
var view := Control.new()
var card: PanelContainer
var center := Vector2.ZERO  # world metres at the view's middle
var zoom := 4.0  # px a metre
var labels: Array = []  # [id, name, screen rect] drawn this frame, for the tap test
var _press = null  # where a press began (screen), while it may still be a tap
var _moved := false
var _touches := {}  # finger index -> its screen position
var _pinch := 0.0  # the two fingers' distance at the last pinch step


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("hud-scrim-menu")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var h := 96.0 / Hud.PHONE_SCALE if touch else 48.0  # 48 dp (addons/forge/test.gd TARGET)
	for b: Array in [[close_button, "Esc", "close", func() -> void: closed.emit()], [me_button, "Me", "recenter", recenter]]:
		var button: Button = b[0]
		button.name = b[1]
		button.text = b[1]
		if ResourceLoader.exists("res://ui/icons/%s.svg" % b[2]):
			button.icon = load("res://ui/icons/%s.svg" % b[2])
		button.theme_type_variation = "ChoiceButton"
		button.custom_minimum_size = Vector2(h * 1.8, h)
		button.pressed.connect(b[3])
	var side := Vector2(maxf(width - 40.0, 200.0), maxf(height - 230.0, 200.0))
	view.custom_minimum_size = side
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.focus_mode = Control.FOCUS_NONE
	view.gui_input.connect(_view_input)
	view.draw.connect(_draw_view)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 14)
	legend.add_theme_constant_override("v_separation", 4)
	for kid: Control in [
		Hud.row([_swatch("mercou"), Hud.label(_site("mercou"), "MenuText")], 8),
		Hud.row([_swatch("curiosity"), Hud.label(_site("curiosity"), "MenuText")], 8),
		Hud.row([Hud.tag("TagArchive", "archive", "ARCHIVED", "CapInk", 12), Hud.label("Curiosity's place, 10 Nov 2026", "MenuSmall")], 8),
	]:
		legend.add_child(kid)
	var body := Hud.col([
		Hud.row([Hud.icon("earth", 20, "on_surface"), Hud.label("Map", "MenuTitle"), Hud.spacer(), me_button, close_button], 10),
		Hud.label("Tap to mark. Pinch or scroll to zoom.", "MenuSmall", true),
		view,
		legend,
		Hud.label("Crater: LPG-3D from NASA/JPL-Caltech/MSSS (CC BY-NC)", "MenuSmall", true),
	], 8)
	card = Hud.panel("HudMenu", body)
	card.custom_minimum_size.x = minf(width, side.x + 40.0)
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.add_child(card)
	add_child(middle)
	recenter()


## "Mont Mercou  8.8 km": a site's name and its real distance from the base.
func _site(id: String) -> String:
	var s: Dictionary = world.sites[id]
	var name: String = String(s.label).get_slice(",", 0)
	return "%s  %s km" % [name, String.num(s.km, 1)]


func refresh() -> void:
	view.queue_redraw()


## Back to the hero, close enough to see the base's places.
func recenter() -> void:
	center = hero if hero != null else Vector2.ZERO
	zoom = maxf(zoom, 4.0)  # the habitat about 40 px across: the base's places and their labels apart
	refresh()


## The whole crater fits the view at this zoom; closer than ZOOM_MAX is not offered.
func zoom_min() -> float:
	var s: Vector2 = view.size if view.size.x > 0.0 else view.custom_minimum_size
	return minf(s.x, s.y) / (1024.0 * 1000.0 / GALE_PX_PER_KM)


## World metres (x, z) to the view's pixels, and back.
func to_view(m: Vector2) -> Vector2:
	return (m - center) * zoom + view.size * 0.5


func to_world(p: Vector2) -> Vector2:
	return (p - view.size * 0.5) / zoom + center


## A spot on the crater picture (its pixels) in world metres.
func _crater_m(px: Vector2) -> Vector2:
	var base := SUMMIT_PX + BASE_FROM_SUMMIT_KM * GALE_PX_PER_KM
	return (px - base) / GALE_PX_PER_KM * 1000.0


## A field site's real place: km and bearing (0 north, clockwise) from the base, in world metres.
func site_m(id: String) -> Vector2:
	var s: Dictionary = world.sites[id]
	var b := deg_to_rad(float(s.bearing))
	return Vector2(sin(b), -cos(b)) * float(s.km) * 1000.0


## Every labelled place: [id, name, world metres, the zoom its label shows from], the far ones first.
func places() -> Array:
	var out: Array = [["sharp", "Mount Sharp", _crater_m(SUMMIT_PX), 0.0],
		["mercou", _site("mercou"), site_m("mercou"), 0.0], ["curiosity", _site("curiosity"), site_m("curiosity"), 0.0],
		["base", "Our base", Vector2.ZERO, 0.0]]
	for id: String in SHOW_FROM:
		var l: Array = world.landmarks.get(id, [])
		if not l.is_empty():
			out.append([id, PLACES[id], Vector2(l[0], l[1]), SHOW_FROM[id]])
	return out


## Zoom by `k` keeping the world point under `at` (view px) where it is.
func zoom_at(k: float, at: Vector2) -> void:
	var m := to_world(at)
	zoom = clampf(zoom * k, zoom_min(), ZOOM_MAX)
	center = m - (at - view.size * 0.5) / zoom
	refresh()


func pan(by: Vector2) -> void:
	center -= by / zoom
	refresh()


## A tap on the view: on the mark clears it, on a label marks that place, anywhere else marks the ground there.
func tap(at: Vector2) -> void:
	if mark != null and to_view(mark).distance_to(at) < PICK_PX:
		mark = null
		mark_id = ""
		marked.emit(null, "", "")
		refresh()
		return
	var best = null
	for l: Array in labels:
		var r: Rect2 = l[2]
		var d := r.grow(PICK_PX * 0.5).get_center().distance_to(at) if r.grow(PICK_PX * 0.5).has_point(at) else INF
		if d < INF and (best == null or d < best[1]):
			best = [l, d]
	if best != null:
		var p: Array = best[0]
		mark = _place_at(p[0])
		mark_id = p[0]
		marked.emit(mark, mark_id, p[1])
	else:
		mark = to_world(at)
		mark_id = ""
		marked.emit(mark, "", "Marker")
	refresh()


func _place_at(id: String) -> Vector2:
	for p: Array in places():
		if p[0] == id:
			return p[2]
	return Vector2.ZERO


## Where a place's label sits on screen now (for a test's tap: the same input path a finger takes), or null.
func screen_of(id: String):
	for l: Array in labels:
		if l[0] == id:
			return view.get_global_transform_with_canvas() * (l[2] as Rect2).get_center()
	return null


func _view_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.device != InputEvent.DEVICE_ID_EMULATION:
		var b := e as InputEventMouseButton
		if b.pressed and b.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var k := pow(ZOOM_STEP, b.factor if b.factor > 0.0 else 1.0)  # a touchpad scrolls in fractions of a notch
			zoom_at(k if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / k, b.position)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			_press_or_tap(b.pressed, b.position)
		view.accept_event()
	elif e is InputEventMouseMotion and e.device != InputEvent.DEVICE_ID_EMULATION and _press != null:
		_drag(e.position, e.relative)
	elif e is InputEventMagnifyGesture:
		zoom_at(e.factor, e.position)
	elif e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		_pinch = 0.0
		if _touches.size() <= 1:
			_press_or_tap(t.pressed and _touches.size() == 1, t.position)
		else:
			_press = null  # two fingers: a pinch, never a tap
		view.accept_event()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() == 2:
			var p: Array = _touches.values()
			var gap: float = (p[0] as Vector2).distance_to(p[1])
			if _pinch > 0.0:
				zoom_at(gap / _pinch, ((p[0] as Vector2) + p[1]) * 0.5)
			_pinch = gap
		elif _press != null:
			_drag(d.position, d.relative)
		view.accept_event()


func _press_or_tap(down: bool, at: Vector2) -> void:
	if down:
		_press = at
		_moved = false
	elif _press != null:
		if not _moved:
			tap(at)
		_press = null


func _drag(at: Vector2, rel: Vector2) -> void:
	_moved = _moved or at.distance_to(_press) > DRAG_PX
	if _moved:
		pan(rel)


func _draw_view() -> void:
	labels.clear()
	var v := view
	# the crater, then the base's own picture over it once it is more than a smudge
	var c0 := _crater_m(Vector2.ZERO)
	var c1 := _crater_m(Vector2(1024, 1024))
	v.draw_texture_rect(GALE, Rect2(to_view(c0), (c1 - c0) * zoom), false)
	if PICTURE_M * zoom > 24.0:
		var half := Vector2(PICTURE_M, PICTURE_M) * 0.5
		v.draw_texture_rect(BASE, Rect2(to_view(-half), half * 2.0 * zoom), false)
	# marks first, labels over them, the far places' labels before the near ones; a label that would overlap one
	# already drawn waits for a closer zoom
	var f := get_theme_font("font", "MenuSmall")
	var fs := get_theme_font_size("font_size", "MenuSmall")
	var taken: Array[Rect2] = []
	for p: Array in places():
		if zoom < float(p[3]) or (p[0] == "base" and zoom > 0.5):
			continue
		var at := to_view(p[2])
		if not Rect2(Vector2.ZERO, v.size).grow(40.0).has_point(at):
			continue
		_mark(v, p[0], at)
		var w := f.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var r := Rect2(at + Vector2(8, -w.y * 0.5), w)
		if taken.any(func(t: Rect2) -> bool: return t.intersects(r.grow(2.0))):
			continue
		taken.append(r)
		labels.append([p[0], p[1], r.merge(Rect2(at - Vector2(6, 6), Vector2(12, 12)))])
		v.draw_string_outline(f, r.position + Vector2(0, w.y * 0.8), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Hud.color("hud-text-edge"))
		v.draw_string(f, r.position + Vector2(0, w.y * 0.8), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Hud.color("on-surface"))
	if objective != null:
		_mark(v, "objective", to_view(objective))
	if mark != null:
		_mark(v, "mark", to_view(mark))
	if pip != null:
		Hud.blit_at(v, "dot", to_view(pip), 9.0, Hud.color("accent"))
	Hud.blit_at(v, "hero", to_view(hero), 19.0, Hud.color("light"), deg_to_rad(yaw))
	var nf := get_theme_font("font", "CompassNorth")
	var nfs := get_theme_font_size("font_size", "CompassNorth")
	v.draw_string_outline(nf, Vector2(v.size.x * 0.5 - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, 3, Hud.color("hud-text-edge"))
	v.draw_string(nf, Vector2(v.size.x * 0.5 - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Hud.color("primary"))


## Each kind of place has its own shape as well as colour: the base a teal ring, Mont Mercou an amber triangle (a
## rock), Curiosity a light square (a rover), the objective an amber diamond, the kid's mark a light ring with a glow,
## anything else a small dot.
func _mark(c: Control, kind: String, p: Vector2) -> void:
	match kind:
		"base":
			c.draw_arc(p, 5.0, 0.0, TAU, 20, Hud.color("accent"), 2.5, true)
		"mercou":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 5), p + Vector2(-6, 5)]), Hud.color("primary"))
		"curiosity":
			c.draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), Hud.color("light"))
		"objective":
			Hud.blit_at(c, "diamond", p, 13.0, Hud.color("primary"))
		"mark":
			Hud.blit_at(c, "glow_dot", p, 30.0, Hud.color("hud-glow"))
			Hud.blit_at(c, "ring", p, 18.0, Hud.color("light"))
		_:
			c.draw_circle(p, 3.0, Hud.color("on-surface"))


## The legend's copy of a mark.
func _swatch(kind: String) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(16, 16)
	s.set_meta("icon", true)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.draw.connect(func() -> void: _mark(s, kind, s.size * 0.5))
	return s
