extends Control
## Every HUD component, laid out as the game would show it, at laptop and phone sizes. Mock values only.
## Keys: L switches laptop and phone, 1 to 9 (or Left and Right) switch the page. On the sleep page the arrows move
## the picker's focus instead, so use the number keys there.
## Pages: hud (ui/game_hud.tscn bound to ui/fake_state.gd: meters, clock, subtitle, mail, alert), comms (visor mail,
## data badges), event (the choice card, a fact card), ledger (the sleep ledger), sources (where this comes from),
## lost (mission lost and the three causes), log, credits, sleep (the sleep picker), speech (the play HUD with PIP
## behind the camera, so his bubble docks at the edge; on the hud page it rides above the PIP marker), map (the full
## map over the play HUD). The stand-in hero stands at the spawn and looks west-north-west, toward the greenhouse.
## capture-view views: "laptop" and "phone" show the hud page; "<layout>_<page>" any other, e.g. "phone_event".

const Hud := preload("res://ui/hud.gd")
const PAGES: Array[String] = ["hud", "comms", "event", "ledger", "sources", "lost", "log", "credits", "sleep", "speech", "map"]
# where the stand-in PIP stands for the camera at the origin: in view on the hud page, behind and left on speech
const PIP_AT := {"hud": Vector3(-1.6, -1.2, -6.0), "speech": Vector3(-4.0, -0.5, 3.0), "map": Vector3(-1.6, -1.2, -6.0)}
const HERO_AT := Vector3(0, 0, 9)  # data/world.json landmark `spawn`
const HEADING := 280.0
const Fake := preload("res://ui/fake_state.gd")
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
var game_hud: Control
var fake := Fake.new()
var cam := Camera3D.new()  # projects the stand-in PIP to the screen, as the play camera does in the game
var pip_spot := Node3D.new()
var hero := Node3D.new()
var pip_mark: TextureRect  # where PIP would be on screen
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
	game_hud = load("res://ui/game_hud.tscn").instantiate()
	pages.hud.add_child(game_hud)
	shown.hud.append(game_hud)
	game_hud.start_unix = 1794657600.0  # 14 Nov 2026, so the mail's delay in a capture does not move with the date
	add_child(fake)
	game_hud.bind(fake)
	add_child(cam)
	add_child(pip_spot)
	add_child(hero)
	hero.position = HERO_AT
	hero.rotation.y = -deg_to_rad(HEADING)  # CONTRACTS.md: rotation.y = -yaw
	cam.rotation.y = hero.rotation.y
	cam.position = HERO_AT + Vector3(0, 1.6, 0) + cam.basis.z * 4.0  # 4 m behind the hero's head
	game_hud.bind_speaker(pip_spot, cam)
	game_hud.bind_view(cam, hero)
	var gear := Button.new()  # a stand-in for the settings screen's gear, docked as the sandbox docks the real one
	gear.icon = load("res://ui/icons/settings.svg")
	gear.expand_icon = true
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(gear)
	game_hud.dock_gear(gear)
	pip_mark = Hud.icon("pip", 56, "accent")
	add_child(pip_mark)
	shown.speech.append(game_hud)
	shown.map.append(game_hud)
	var stick := _component("hud", "touch_stick")
	_pin(stick, Control.PRESET_BOTTOM_LEFT)
	var buttons := Hud.row([], 20)
	pages.hud.add_child(buttons)
	var use := _component("hud", "touch_button", {"name": "UseButton", "text": "Use", "icon": load("res://ui/icons/use.svg")}, buttons)
	var hop := _component("hud", "touch_button", {"name": "HopButton"}, buttons)
	_pin(buttons, Control.PRESET_BOTTOM_RIGHT)
	touch = [stick, use, hop]

	var comms := Hud.col([], 16)
	_center("comms").add_child(comms)
	_component("comms", "ask_earth", {}, comms)
	_component("comms", "data_badge", {"name": "LiveBadge"}, comms)
	_component("comms", "data_badge", {"name": "ArchivedBadge", "live": false, "date": "Weather, 20 May 2024"}, comms)

	_scrim("event")
	var cards := Hud.row([], 24)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.event.add_child(cards)
	# mock words and costs: the real ones are the story's, written at the event
	var options := [
		{"text": "Make oxygen", "costs": {"battery_pct": -20}},
		{"text": "Greenhouse lights", "costs": {"battery_pct": -10, "o2_kg": -0.8}},
		{"text": "Save the battery", "costs": {"food_kg": -1.2, "health": -1}},
	]
	_component("event", "event_card", {"size_flags_vertical": Control.SIZE_SHRINK_CENTER, "icon_name": "power", "title": "Not enough power!", "line": "Pick one to run this morning.", "options": options}, cards)
	_component("event", "fact_card", {"size_flags_vertical": Control.SIZE_SHRINK_CENTER}, cards)
	for p: String in ["ledger", "sources"]:
		_scrim(p)
		_component(p, p + "_card", {}, _center(p))

	_component("lost", "mission_lost")
	_scrim("log")
	_pin(_component("log", "mission_log"), Control.PRESET_CENTER)
	_component("credits", "credits")
	_component("sleep", "sleep_picker").open()
	# the other pages draw as the game would (Hud.layer: batched draw order and the text's dark edge)
	for p: String in PAGES:
		if p != "hud":
			Hud.layer(pages[p], 1)


## Cards whose text wraps go in a CenterContainer: it sizes them again on every sort, where an anchored card keeps
## the tall size its wrapping labels asked for before they had a width.
func _center(p: String) -> CenterContainer:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages[p].add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _scrim(p: String) -> void:
	var s := ColorRect.new()
	s.color = Hud.color("hud-scrim")
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
		c.visible = p == page or p == "hud" and page in ["speech", "map"]
		if p != "hud":
			continue  # the other pages are centred and their scrims cover the whole screen
		c.offset_left = m.x
		c.offset_top = m.y
		c.offset_right = -m.x
		c.offset_bottom = -m.y
	for t in touch:
		t.visible = phone
	pip_spot.position = cam.transform * PIP_AT.get(page, PIP_AT.hud)
	pip_mark.visible = page == "hud"
	pip_mark.position = cam.unproject_position(pip_spot.position) - pip_mark.custom_minimum_size * 0.5
	game_hud.touch = phone
	if page in PIP_AT:
		_mock()
	if page == "map":
		game_hud.open_map()
	else:
		game_hud.close_map()


## The play HUD's moving parts, put up again whenever its page shows (they time out by themselves in play).
func _mock() -> void:
	# the mockup's own placeholder words, so the look is judged on real-length lines (the game's come from lines.json)
	game_hud.say("sol1_try_jump")
	game_hud.bubble.speak("Good morning, Commander! Try a jump. Watch how high")
	game_hud.bubble.typed = game_hud.bubble.text.length() * 2 / 3  # mostly typed, as the mockup, for a still picture
	game_hud.bubble._typed = game_hud.bubble.typed
	game_hud.bubble._show_text()
	game_hud.set_tasks([{"label_id": "morning_check", "state": "done"}, {"label_id": "sol1_first_choice", "state": "now"}, {"label_id": "brush_dust", "state": "next"}])
	game_hud.tasks.set_tasks([["Morning check", "done"], ["Pick lettuce", "now"], ["Clean solar panels", "next"]])
	game_hud.set_objective("greenhouse")
	game_hud.show_prompt("Open the greenhouse")
	game_hud.alert("Solar storm", "ARCHIVED data. Tap ? for its source.")
	game_hud.send_mail()
	game_hud.mail.set_now(fake.values.hour + 0.1)


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
	return {"view": layout if page == "hud" else "%s_%s" % [layout, page], "layout": layout, "page": page, "components": names, "hud": game_hud.snapshot()}
