extends CanvasLayer
## The settings screen, opened by the gear or Esc. The main page: five graphics presets named for the hardware they
## suit, a frame-rate switch and the sound levels. "Advanced" folds out six plain choices (ADVANCED), each a bundle
## of HouseStyle knobs; the preset decides every other knob (13 Nov playtest: a row per knob was "too much").
## A preset card applies at once. An Advanced choice waits for Apply (or Done), which puts it on behind the cover,
## where any new shaders compile. Every save shows "Saved". Kept per device in user://.
## It changes how the game looks and sounds, never anything the game counts (hard rule 1).
## The game it drives (the sandbox) has `design`, `quality`, `overrides`, `audio`, `fps_label` and
## `set_graphics(level, overrides, restyle := true, warm := true)`.

const Hud := preload("res://ui/hud.gd")
const HouseStyle := preload("res://addons/forge/house_style.gd")
# DESIGN.md quality id -> [name, icon, one line]. Ids missing here still get a card, by their own name.
const PRESETS := {
	"phone": ["Phone", "device_phone", "Smooth on budget phones"],
	"older": ["Older laptop", "device_older", "Laptops from 2015 to 2018"],
	"laptop": ["Laptop", "device_laptop", "Newer laptops, no graphics card"],
	"gaming": ["Gaming PC", "device_gaming", "Computers with a graphics card"],
	"max": ["Max", "device_max", "Everything on, for strong cards"],
}
const OLD := {"low": "phone", "medium": "laptop", "high": "gaming"}  # levels saved before 13 Nov
# Advanced: row -> [[shown, {knob: value}], ...]. An option that leaves a knob out keeps the preset's ("Auto"). The
# DESIGN.md presets are built from these same bundles, so each row names the preset's own choice
# (tests/settings_test.gd checks it); a mix that matches none reads "Custom".
const ADVANCED := {
	"Anti-aliasing": [["Off", {"msaa": 0}], ["2x", {"msaa": 2}], ["4x", {"msaa": 4}], ["8x", {"msaa": 8}]],
	"Resolution": [["Auto", {}], ["50%", {"pixels": 0.0, "scale": 0.5}], ["60%", {"pixels": 0.0, "scale": 0.6}],
		["75%", {"pixels": 0.0, "scale": 0.75}], ["85%", {"pixels": 0.0, "scale": 0.85}],
		["100%", {"pixels": 0.0, "scale": 1.0}]],
	"Shadows": [["Off", {"shadows": 0}],
		["Low", {"shadows": 1, "shadowMap": 1024, "shadowRange": 25, "shadowFilter": 2, "normalBias": 2.0}],
		["Medium", {"shadows": 2, "shadowMap": 2048, "shadowRange": 60, "shadowFilter": 3, "normalBias": 6.0}],
		["High", {"shadows": 4, "shadowMap": 4096, "shadowRange": 60, "shadowFilter": 4, "normalBias": 4.0}],
		["Ultra", {"shadows": 4, "shadowMap": 4096, "shadowRange": 60, "shadowFilter": 5, "normalBias": 4.0}]],
	"Effects": [["Low", {"glow": 0.0, "particles": 0.5, "lamps": 2}],
		["Medium", {"glow": 0.4, "particles": 0.75, "lamps": 4}],
		["High", {"glow": 0.5, "particles": 1.0, "lamps": -1}]],
	"V-Sync": [["On", {"vsync": true}], ["Off", {"vsync": false}]],
	"Frame cap": [["None", {"maxFps": 0}], ["30 fps", {"maxFps": 30}], ["45 fps", {"maxFps": 45}], ["60 fps", {"maxFps": 60}],
		["120 fps", {"maxFps": 120}]],
}
const VOLUMES := {"master": "All sound", "music": "Music", "effects": "Suit and world"}

# "" until first asked: user://settings.cfg in the game, "-" (none) in a test or tool run, so a player's saved
# choices never change what a check measures. A test that checks saving sets its own file first.
static var file := ""

var game: Node
var draft := {}  # the Advanced choices as knob overrides, put on by Apply
var rows := {}  # Advanced row name -> {value: Label, minus, plus, wait}
var cards := {}  # preset id -> Button
var sliders := {}  # volume name -> HSlider
var phone := DisplayServer.is_touchscreen_available()  # drawn larger, with margins clear of the back swipe
var root := Control.new()  # the screen, scaled for the device (_fit)
var gear := Button.new()
var shade := ColorRect.new()
var panel: PanelContainer
var apply_button: Button
var reset_button: Button
var fps_button: Button
var full_button: Button  # null where a page cannot go full screen (iPhone Safari)
var fold_button: Button
var advanced: Control  # the fold-out
var saved_tag: Control
var _flash: Tween


static func _path() -> String:
	if file == "":
		var tool := Engine.get_main_loop().get_script() != null or Array(OS.get_cmdline_user_args()).any(
			func(a: String) -> bool: return a.begins_with("--forge-job="))
		file = "-" if tool else "user://settings.cfg"
	return file


## What this device chose last time: {level, overrides, volume, fps}, each checked; {} when nothing was saved. Only the
## knobs Advanced can set come back, so a knob the screen no longer shows can never stay changed out of sight.
static func saved() -> Dictionary:
	var c := ConfigFile.new()
	if _path() == "-" or c.load(_path()) != OK:
		return {}
	var level := str(c.get_value("graphics", "level", ""))
	var out := {"level": OLD.get(level, level), "overrides": {}, "volume": {}, "fps": c.get_value("hud", "fps", true) == true}
	var o: Variant = c.get_value("graphics", "overrides", {})
	if o is Dictionary and not OLD.has(level):
		var shown := _knobs()
		for k: Variant in o:
			if k in shown and HouseStyle.KNOBS.has(k) and _find(HouseStyle.KNOBS[k].values, o[k]) >= 0:
				out.overrides[k] = o[k]
	for k: String in VOLUMES:
		var v: Variant = c.get_value("sound", k, 1.0)
		if v is float or v is int:
			out.volume[k] = clampf(v, 0.0, 1.0)
	return out


## Every knob an Advanced row sets.
static func _knobs() -> Array:
	var out := []
	for r: String in ADVANCED:
		for o: Array in ADVANCED[r]:
			for k: String in o[1]:
				if k not in out:
					out.append(k)
	return out


func save() -> void:
	if _path() != "-":
		var c := ConfigFile.new()
		c.set_value("graphics", "level", game.quality)
		c.set_value("graphics", "overrides", game.overrides)
		c.set_value("hud", "fps", game.fps_label.visible)
		for k: String in VOLUMES:
			c.set_value("sound", k, game.audio.volume[k])
		c.save(_path())  # ponytail: a failure (a private window's storage) only forgets the choice for next time
	saved_tag.visible = true
	if _flash:
		_flash.kill()
	_flash = create_tween()
	_flash.tween_interval(2.0)
	_flash.tween_callback(func() -> void: saved_tag.visible = false)


func setup(g: Node) -> void:
	game = g
	layer = 100  # under the sandbox's cover (128), which hides the shader compile after Apply
	var s := saved()
	for k: String in s.get("volume", {}):
		game.audio.set_volume(k, s.volume[k])
	game.fps_label.visible = s.get("fps", true)
	draft = game.overrides.duplicate()
	root.theme = Hud.THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	gear.theme_type_variation = &"TouchButton"
	gear.icon = load("res://ui/icons/settings.svg")
	gear.expand_icon = true
	gear.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear.tooltip_text = "Settings (Esc)"
	gear.focus_mode = Control.FOCUS_NONE  # a focused button would also take Space, the hop
	gear.custom_minimum_size = Vector2(Hud.BUTTON_H, Hud.BUTTON_H)
	gear.pressed.connect(toggle)
	root.add_child(gear)
	shade.color = Hud.color("surface", 0.5)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP  # the world under it takes no clicks or look drags
	root.add_child(shade)
	panel = Hud.panel("HudPanel", _build(), true)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	shade.visible = false
	panel.visible = false
	get_viewport().size_changed.connect(_fit)
	_fit()


func is_open() -> bool:
	return panel.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # a click on the world captures it again (follow_cam)
	shade.visible = true
	panel.visible = true
	gear.visible = false  # Done closes it; the gear sat under the panel's corner on a phone
	draft = game.overrides.duplicate()
	_refresh()


## Done: what still waits for Apply is applied, nothing chosen is lost.
func close() -> void:
	apply()
	shade.visible = false
	panel.visible = false
	gear.visible = true


func _input(e: InputEvent) -> void:
	if InputMap.has_action(&"settings") and e.is_action_pressed(&"settings"):
		toggle()
		get_viewport().set_input_as_handled()


func waiting() -> bool:
	return not _same_dict(draft, game.overrides)


func _refresh() -> void:
	for id: String in cards:
		var b: Button = cards[id]
		b.set_pressed_no_signal(id == game.quality)
		b.get_meta("check").visible = id == game.quality  # a shape, not only a colour
	for r: String in rows:
		var i := current(r)
		var n: int = ADVANCED[r].size()
		rows[r].value.text = "Custom" if i < 0 else ADVANCED[r][i][0]
		rows[r].minus.disabled = i == 0
		rows[r].plus.disabled = i == n - 1
		rows[r].wait.visible = not _same_dict(_values(r, draft), _values(r, game.overrides))
	apply_button.disabled = not waiting()
	reset_button.disabled = draft.is_empty() and game.overrides.is_empty()
	fps_button.text = "On" if game.fps_label.visible else "Off"
	_full_text()
	fold_button.text = "Hide advanced" if advanced.visible else "Advanced"
	for k: String in sliders:
		sliders[k].set_value_no_signal(game.audio.volume[k] * 100.0)
		sliders[k].get_meta("label").text = "%d%%" % roundi(game.audio.volume[k] * 100.0)


## Which option of row `r` the draft is on, -1 for none.
func current(r: String) -> int:
	var now := _values(r, draft)
	for i: int in ADVANCED[r].size():
		if _same_dict(now, _values(r, _option(r, i))):
			return i
	return -1


## Row `r`'s knobs as they would be with `over` on the preset.
func _values(r: String, over: Dictionary) -> Dictionary:
	var kn := HouseStyle.knobs(game.design)
	var out := {}
	for o: Array in ADVANCED[r]:
		for k: String in o[1]:
			out[k] = over.get(k, kn[k].preset)
	return out


## Option `i` of row `r` as overrides: a knob it leaves out is the preset's.
func _option(r: String, i: int) -> Dictionary:
	return ADVANCED[r][i][1]


## One step along row `r`'s options; from "Custom" the first step lands on the first option.
func step(r: String, by: int) -> void:
	choose(r, clampi(current(r) + by, 0, ADVANCED[r].size() - 1) if current(r) >= 0 else 0)


func choose(r: String, i: int) -> void:
	var kn := HouseStyle.knobs(game.design)
	var o := _option(r, i)
	for k: String in _values(r, {}):
		var v: Variant = o.get(k, kn[k].preset)
		if _same(v, kn[k].preset):
			draft.erase(k)
		else:
			draft[k] = v
	_refresh()


## The Advanced choices on, behind the cover (a shader knob compiles there), and saved.
func apply() -> void:
	if not waiting():
		return
	game.set_graphics(game.quality, draft.duplicate())
	save()
	_refresh()


## A preset card: every knob back to it, at once.
func preset(level: String) -> void:
	draft.clear()
	game.set_graphics(level, {})
	save()
	_refresh()


func volume(k: String, percent: float) -> void:
	game.audio.set_volume(k, percent / 100.0)
	save()
	_refresh()


func _build() -> Control:
	var list := Hud.col([], 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var deck := HFlowContainer.new()
	deck.add_theme_constant_override("h_separation", 8)
	deck.add_theme_constant_override("v_separation", 8)
	for id: String in game.design.quality:
		deck.add_child(_card(id))
	list.add_child(Hud.label("Graphics", "Heading"))
	list.add_child(deck)
	fps_button = _button("", func() -> void:
		game.fps_label.visible = not game.fps_label.visible
		save()
		_refresh(), &"ChoiceButton")
	fps_button.custom_minimum_size.x = 2 * Hud.BUTTON_H + 130
	list.add_child(_flow([Hud.label("Show FPS", "", true), fps_button]))
	if not OS.has_feature("web_ios"):  # iPhone Safari has no full screen for a page; Add to Home Screen is the way
		full_button = _button("", full_screen, &"ChoiceButton")
		full_button.custom_minimum_size.x = fps_button.custom_minimum_size.x
		list.add_child(_flow([Hud.label("Full screen", "", true), full_button]))
	list.add_child(Hud.label("Sound", "Heading"))
	for k: String in VOLUMES:
		list.add_child(_slider(k))
	advanced = Hud.col([], 14)
	advanced.visible = false
	for r: String in ADVANCED:
		advanced.add_child(_row(r))
	fold_button = _button("", func() -> void:
		advanced.visible = not advanced.visible
		_refresh(), &"ChoiceButton")
	fold_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fold_button.custom_minimum_size.x = 260
	list.add_child(fold_button)
	list.add_child(advanced)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var title := Hud.label("Settings", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Hud.row([Hud.icon("settings", 40), title, _button("Done", close)], 12)
	reset_button = _button("Reset to preset", func() -> void: preset(game.quality), &"ChoiceButton")
	apply_button = _button("Apply", apply)
	saved_tag = Hud.tag("TagLive", "check", "Saved")
	saved_tag.visible = false
	var foot := Hud.row([reset_button, Hud.spacer(), saved_tag, apply_button], 12)
	return Hud.col([head, scroll, foot], 14)


## A preset as a big card: its icon, its name, one line, and a check when it is in force.
func _card(id: String) -> Button:
	var about: Array = PRESETS.get(id, [id.capitalize(), "settings", ""])
	var b := _button("", preset.bind(id), &"ChoiceButton")
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(168, 176)
	var check := Hud.icon("check", 28, "accent")
	b.set_meta("check", check)
	var name := Hud.label(about[0], "TagText", true)
	var line := Hud.label(about[2], "Caption", true)
	line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var inside := Hud.col([Hud.row([Hud.icon(about[1], 44, "accent"), Hud.spacer(), check]), name, line], 6)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_child(inside)
	for c: Control in [pad, inside] + inside.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the card takes the click
	b.add_child(pad)
	cards[id] = b
	return b


## An Advanced row: its name (and "On Apply" while it waits) then < value >; on a narrow screen the control wraps.
func _row(r: String) -> Control:
	var row := {"wait": Hud.tag("TagLive", "", "On Apply")}
	var about := Hud.col([Hud.label(r, "", true), row.wait], 4)
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.custom_minimum_size.x = 230
	row.minus = _button("<", step.bind(r, -1), &"ChoiceButton")
	row.plus = _button(">", step.bind(r, 1), &"ChoiceButton")
	row.value = Hud.label("", "SmallNumber")
	row.value.custom_minimum_size.x = 130
	row.value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows[r] = row
	return _flow([about, Hud.row([row.minus, row.value, row.plus], 8)])


func _slider(k: String) -> Control:
	var s := HSlider.new()
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(2 * Hud.BUTTON_H + 130, Hud.BUTTON_H)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Hud.color("outline-variant")
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Hud.color("primary")
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var shown := Hud.label("", "SmallNumber")
	s.set_meta("label", shown)
	s.value_changed.connect(func(v: float) -> void: volume(k, v))
	sliders[k] = s
	var name := Hud.label(VOLUMES[k], "", true)
	name.custom_minimum_size.x = 230
	return _flow([Hud.row([name, shown], 10), s])


func _flow(kids: Array) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_END
	f.add_theme_constant_override("h_separation", 12)
	f.add_theme_constant_override("v_separation", 8)
	for c: Control in kids:
		f.add_child(c)
	kids[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


## The F key and the settings button. On the web it asks the browser, which allows it only right after a press.
func full_screen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if _full() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_full_text()  # a desktop window switches at once; the web's switch lands later, through _fit()


func _full() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _full_text() -> void:
	if full_button:
		full_button.text = "On" if _full() else "Off"


func _button(text: String, on: Callable, variation := &"") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(Hud.BUTTON_H, Hud.BUTTON_H)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on)
	return b


## Sized for the device: a phone draws it PHONE_SCALE larger, and in portrait (where the canvas is wider than 720 px
## of the 1280 x 720 base) larger still, so a button stays a 48 dp target.
func _fit() -> void:
	_full_text()  # the window changes size when it enters or leaves full screen, also by the browser's own Esc
	var s := get_viewport().get_visible_rect().size
	var k := maxf(1.0, minf(s.x, s.y) / 720.0) * (Hud.PHONE_SCALE if phone else 1.0)
	root.scale = Vector2(k, k)
	root.position = Vector2.ZERO
	root.size = s / k
	shade.size = root.size
	# Android's back swipe starts 30 dp in from a side: 60 px of a phone's 720 (addons/forge/test.gd EDGE), either way up
	var m := Vector2(60.0 / Hud.PHONE_SCALE if phone else 24.0, 20.0)
	gear.position = Vector2(root.size.x - m.x - Hud.BUTTON_H, m.y)
	gear.size = Vector2(Hud.BUTTON_H, Hud.BUTTON_H)
	panel.size = Vector2(minf(root.size.x - 2.0 * m.x, 960.0), root.size.y - 2.0 * m.y)
	panel.position = Vector2((root.size.x - panel.size.x) / 2.0, m.y)


static func _same_dict(a: Dictionary, b: Dictionary) -> bool:
	return a.size() == b.size() and a.keys().all(func(k: Variant) -> bool: return b.has(k) and _same(a[k], b[k]))


## Equal, with JSON's floats and the knob table's ints counted the same.
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


static func _find(values: Array, v: Variant) -> int:
	for i in values.size():
		if _same(values[i], v):
			return i
	return -1
