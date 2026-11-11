extends Control
## Every HUD component, laid out as the game would show it, at laptop and phone sizes. Mock values only.
## Keys: L switches laptop and phone, 1 to 6 (or Left and Right) switch the page.
## Pages: hud (the play HUD), comms (Ask Earth, data badges), event (event and fact cards), lost (mission lost and replay chain), log, credits.
## capture-view views: "laptop" and "phone" show the hud page; "<layout>_<page>" any other, e.g. "phone_event".

const Hud := preload("res://ui/hud.gd")
const PAGES: Array[String] = ["hud", "comms", "event", "lost", "log", "credits"]
# iPhone 16 in landscape is 852 x 393 pt; on the 720 px tall canvas that is 1561 x 720.
const PHONE := Vector2(1561, 720)
const LAPTOP := Vector2(1280, 720)
# The phone's margins clear the Dynamic Island side and Android's 30 dp back-swipe strip (test.gd EDGE).
const MARGIN := {"laptop": Vector2(24, 20), "phone": Vector2(48, 20)}

var layout := "laptop"
var page := "hud"
var screen := Control.new()  # the device's canvas, shrunk to fit the window when it is bigger than it
var bezel := Panel.new()
var hud := Control.new()  # drawn PHONE_SCALE times larger on the phone
var pages := {}
var shown := {}  # page -> the component nodes on it, for render_game_to_text()
var toast: Control
var touch: Array[Control] = []


func _ready() -> void:
	theme = Hud.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Hud.color("surface")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Hud.color("surface-container")
	frame.border_color = Hud.color("outline-variant")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(56)
	bezel.add_theme_stylebox_override("panel", frame)
	add_child(bezel)
	screen.clip_contents = true
	add_child(screen)
	var world := _backdrop()
	screen.add_child(world)
	screen.add_child(load("res://ui/components/visor.tscn").instantiate())
	screen.add_child(hud)
	for p in PAGES:
		var c := Control.new()
		c.name = p
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(c)
		pages[p] = c
		shown[p] = []
	_build()
	get_viewport().size_changed.connect(_apply)
	_apply()
	Forge.register(self)


## Instance a component with its mock values set before _ready builds it, under `parent` (the page by default).
func _component(p: String, path: String, props := {}, parent: Control = null) -> Control:
	var n: Control = load("res://ui/components/%s.tscn" % path).instantiate()
	for k: String in props:
		n.set(k, props[k])
	(parent if parent else pages[p]).add_child(n)
	shown[p].append(n)
	return n


func _pin(n: Control, preset: Control.LayoutPreset) -> void:
	n.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	# grow away from the edge it is pinned to, so content that grows later stays on screen
	n.grow_horizontal = _grow(n.anchor_left)
	n.grow_vertical = _grow(n.anchor_top)


func _grow(anchor: float) -> Control.GrowDirection:
	if anchor == 0.5:
		return Control.GROW_DIRECTION_BOTH
	return Control.GROW_DIRECTION_BEGIN if anchor == 1.0 else Control.GROW_DIRECTION_END


func _build() -> void:
	_pin(_component("hud", "status_panel"), Control.PRESET_TOP_LEFT)
	_pin(_component("hud", "sol_clock"), Control.PRESET_TOP_RIGHT)
	toast = _component("hud", "alert_toast")
	var stick := _component("hud", "touch_stick")
	_pin(stick, Control.PRESET_BOTTOM_LEFT)
	var buttons := Hud.row([], 20)
	pages.hud.add_child(buttons)
	var use := _component("hud", "touch_button", {"name": "UseButton", "text": "Use", "icon": load("res://ui/icons/use.svg")}, buttons)
	var hop := _component("hud", "touch_button", {"name": "HopButton"}, buttons)
	_pin(buttons, Control.PRESET_BOTTOM_RIGHT)
	touch = [stick, use, hop]

	var comms := Hud.col([], 16)
	pages.comms.add_child(comms)
	_component("comms", "ask_earth", {}, comms)
	_component("comms", "data_badge", {"name": "LiveBadge"}, comms)
	_component("comms", "data_badge", {"name": "ArchivedBadge", "live": false, "date": "Weather, 20 May 2024"}, comms)
	_pin(comms, Control.PRESET_CENTER)

	_scrim("event")
	var cards := Hud.row([], 24)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.event.add_child(cards)
	for c: String in ["event_card", "fact_card"]:
		_component("event", c, {"size_flags_vertical": Control.SIZE_SHRINK_CENTER}, cards)

	_component("lost", "mission_lost")
	_scrim("log")
	_pin(_component("log", "mission_log"), Control.PRESET_CENTER)
	_component("credits", "credits")


func _scrim(p: String) -> void:
	var s := ColorRect.new()
	s.color = Hud.color("surface", 0.45)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages[p].add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A stand-in for the 3D view: the dusk sky, the haze and the ground in DESIGN.md colours, and Mount Sharp.
func _backdrop() -> Control:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.6, 1.0])
	g.colors = PackedColorArray([Hud.color("sky"), Hud.color("horizon"), Hud.color("ground"), Hud.color("ground").darkened(0.45)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.draw.connect(func() -> void:
		var w := r.size.x
		var h := r.size.y
		# Mount Sharp: a broad, low mound on the horizon, not a peak
		var ridge := PackedVector2Array([Vector2(w * 0.18, h * 0.6)])
		for x: float in [0.3, 0.4, 0.47, 0.53, 0.58, 0.66, 0.78, 0.92]:
			var t := (x - 0.18) / 0.74
			ridge.append(Vector2(w * x, h * (0.6 - 0.11 * pow(sin(PI * t), 1.6) * (1.0 - 0.25 * t))))
		ridge.append(Vector2(w * 0.92, h * 0.6))
		r.draw_colored_polygon(ridge, Hud.color("sky").lerp(Hud.color("horizon"), 0.5)))
	return r


func _apply() -> void:
	var phone := layout == "phone"
	var device := PHONE if phone else LAPTOP
	var view := get_viewport_rect().size
	var fit := minf(1.0, minf(view.x / device.x, view.y / device.y))
	if phone:
		fit = minf(fit, 0.94)  # leave room for the bezel in the preview
	screen.size = device
	screen.scale = Vector2(fit, fit)
	screen.position = ((view - device * fit) * 0.5).floor()
	bezel.visible = phone
	bezel.position = screen.position - Vector2(18, 18)
	bezel.size = device * fit + Vector2(36, 36)
	var k := Hud.PHONE_SCALE if phone else 1.0
	hud.scale = Vector2(k, k)
	hud.size = device / k
	var m: Vector2 = MARGIN[layout]
	for p: String in PAGES:
		var c: Control = pages[p]
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.visible = p == page
		if p != "hud":
			continue  # the other pages are centred and their scrims cover the whole screen
		c.offset_left = m.x
		c.offset_top = m.y
		c.offset_right = -m.x
		c.offset_bottom = -m.y
	for t in touch:
		t.visible = phone
	# on a phone the top row is full, so the alert sits low, between the stick and the buttons
	_pin(toast, Control.PRESET_CENTER_BOTTOM if phone else Control.PRESET_CENTER_TOP)


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var i := PAGES.find(page)
	match k.keycode:
		KEY_L:
			layout = "laptop" if layout == "phone" else "phone"
		KEY_LEFT:
			page = PAGES[posmod(i - 1, PAGES.size())]
		KEY_RIGHT:
			page = PAGES[posmod(i + 1, PAGES.size())]
		_:
			var n := k.keycode - KEY_1
			if n < 0 or n >= PAGES.size():
				return
			page = PAGES[n]
	_apply()


func set_view(view: String) -> void:
	var parts := view.split("_")
	layout = parts[0] if parts[0] in MARGIN else "laptop"
	page = parts[1] if parts.size() > 1 and parts[1] in PAGES else "hud"
	_apply()


func render_game_to_text() -> Dictionary:
	var names: Array[String] = []
	for n: Control in shown[page]:
		if n.is_visible_in_tree():
			names.append(String(n.name))
	return {"view": layout if page == "hud" else "%s_%s" % [layout, page], "layout": layout, "page": page, "components": names}
