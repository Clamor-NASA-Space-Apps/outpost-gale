extends CanvasLayer
## The settings screen, opened by the gear or Esc: a preset, then one row per graphics knob, built from
## HouseStyle.knobs() so a knob added there shows up here, and the sound levels. Kept per device in user://.
## A knob that compiles shaders waits for Apply (or Done), so the cover hides the compile once; the rest apply at
## once. It changes how the game looks and sounds, never anything the game counts (hard rule 1).
## The game it drives (the sandbox) has `design`, `quality`, `overrides`, `audio` and
## `set_graphics(level, overrides, restyle := true, warm := true)`.

const Hud := preload("res://ui/hud.gd")
const HouseStyle := preload("res://addons/forge/house_style.gd")
# knob -> [group, plain label]. A knob missing here still gets a row, under "Other", by its own name.
const ROWS := {
	"detail": ["Picture", "Surface detail"],
	"ground": ["Picture", "Ground look"],
	"msaa": ["Picture", "Smooth edges"],
	"aniso": ["Picture", "Far ground sharpness"],
	"pixels": ["Picture", "Pixel budget"],
	"scale": ["Picture", "Resolution"],
	"shadows": ["Shadows", "Shadows"],
	"shadowMap": ["Shadows", "Shadow sharpness"],
	"shadowFilter": ["Shadows", "Shadow softness"],
	"shadowRange": ["Shadows", "Shadow distance"],
	"normalBias": ["Shadows", "Shadow offset"],
	"glow": ["Effects", "Glow"],
	"fog": ["Effects", "Dust haze"],
	"ssao": ["Effects", "Corner shade"],
	"lamps": ["Effects", "Lamps lit"],
	"particles": ["Effects", "Dust puffs"],
	"trail": ["Effects", "Footprint detail"],
	"vsync": ["Performance", "V-Sync"],
	"maxFps": ["Performance", "Frame cap"],
}
const GROUPS := ["Picture", "Shadows", "Effects", "Performance", "Other"]
const LEVELS := ["low", "medium", "high"]
const VOLUMES := {"master": "All sound", "music": "Music", "effects": "Suit and world"}
const NAMES := {
	"detail": {"off": "Plain", "code": "Pattern", "texture": "Photo"},
	"ground": {"flat": "Flat", "cheap": "Simple", "full": "Full"},
	"shadows": {0: "Off", 1: "Simple", 2: "Good", 4: "Best"},
	"shadowFilter": {0: "Hard", 1: "Very low", 2: "Low", 3: "Medium", 4: "High", 5: "Ultra"},
	"aniso": {0: "Off", 1: "2x", 2: "4x", 3: "8x", 4: "16x"},
}

# "" until first asked: user://settings.cfg in the game, "-" (none) in a test or tool run, so a player's saved
# choices never change what a check measures. A test that checks saving sets its own file first.
static var file := ""

var game: Node
var pending := {}  # knobs that compile shaders, chosen but not applied yet
var rows := {}  # knob -> {mark, wait, value, minus, plus} or {mark, wait, toggle}
var presets := {}  # level -> Button
var sliders := {}  # volume name -> HSlider
var phone := DisplayServer.is_touchscreen_available()  # drawn larger, with margins clear of the back swipe
var root := Control.new()  # the screen, scaled for the device (_fit)
var gear := Button.new()
var shade := ColorRect.new()
var panel: PanelContainer
var apply_button: Button
var reset_button: Button


static func _path() -> String:
	if file == "":
		var tool := Engine.get_main_loop().get_script() != null or Array(OS.get_cmdline_user_args()).any(
			func(a: String) -> bool: return a.begins_with("--forge-job="))
		file = "-" if tool else "user://settings.cfg"
	return file


## What this device chose last time: {level, overrides, volume}, each checked; {} when nothing was saved.
static func saved() -> Dictionary:
	var c := ConfigFile.new()
	if _path() == "-" or c.load(_path()) != OK:
		return {}
	var out := {"level": str(c.get_value("graphics", "level", "")), "overrides": {}, "volume": {}}
	var o: Variant = c.get_value("graphics", "overrides", {})
	if o is Dictionary:
		for k: Variant in o:
			if HouseStyle.KNOBS.has(k) and _find(HouseStyle.KNOBS[k].values, o[k]) >= 0:
				out.overrides[k] = o[k]
	for k: String in VOLUMES:
		var v: Variant = c.get_value("sound", k, 1.0)
		if v is float or v is int:
			out.volume[k] = clampf(v, 0.0, 1.0)
	return out


func save() -> void:
	if _path() == "-":
		return
	var c := ConfigFile.new()
	c.set_value("graphics", "level", game.quality)
	c.set_value("graphics", "overrides", game.overrides)
	for k: String in VOLUMES:
		c.set_value("sound", k, game.audio.volume[k])
	c.save(_path())  # ponytail: a failure (a private window's storage) only forgets the choice for next time


func setup(g: Node) -> void:
	game = g
	layer = 100  # under the sandbox's cover (128), which hides the shader compile after Apply
	var s := saved()
	for k: String in s.get("volume", {}):
		game.audio.set_volume(k, s.volume[k])
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


## Every row as one knob's value, with "Changed" where it differs from the preset and "On Apply" while it waits.
func _refresh() -> void:
	var kn := HouseStyle.knobs(game.design)
	for k: String in rows:
		var r: Dictionary = rows[k]
		var v: Variant = pending.get(k, kn[k].value)
		r.mark.visible = not _same(v, kn[k].preset)
		r.wait.visible = pending.has(k)
		if r.has("toggle"):
			r.toggle.text = "On" if v else "Off"
			continue
		var i := _find(kn[k].values, v)
		r.value.text = _text(k, v)
		r.minus.disabled = i == 0
		r.plus.disabled = i == kn[k].values.size() - 1
	for level: String in presets:
		var b: Button = presets[level]
		b.icon = load("res://ui/icons/check.svg") if level == game.quality else null  # a shape, not only a colour
	apply_button.disabled = pending.is_empty()
	reset_button.disabled = pending.is_empty() and game.overrides.is_empty()
	# only when there is something to apply or undo: a phone in landscape has room for two rows besides
	apply_button.get_parent().visible = not (apply_button.disabled and reset_button.disabled)
	for k: String in sliders:
		sliders[k].set_value_no_signal(game.audio.volume[k] * 100.0)
		sliders[k].get_meta("label").text = "%d%%" % roundi(game.audio.volume[k] * 100.0)


## One step along a knob's values (or the other value of an on/off knob).
func step(k: String, by: int) -> void:
	var row: Dictionary = HouseStyle.knobs(game.design)[k]
	var values: Array = row.values
	choose(k, values[clampi(_find(values, pending.get(k, row.value)) + by, 0, values.size() - 1)])


func choose(k: String, v: Variant) -> void:
	var row: Dictionary = HouseStyle.knobs(game.design)[k]
	if row.recompile:
		if _same(v, row.value):
			pending.erase(k)
		else:
			pending[k] = v
	else:
		_override(k, v, row.preset)
		game.set_graphics(game.quality, game.overrides, row.game, false)  # a game knob is read by the world's restyle
		save()
	_refresh()


func apply() -> void:
	if pending.is_empty():
		return
	var kn := HouseStyle.knobs(game.design)
	for k: String in pending:
		_override(k, pending[k], kn[k].preset)
	pending.clear()
	game.set_graphics(game.quality, game.overrides)
	save()
	_refresh()


## A preset, every knob back to it.
func preset(level: String) -> void:
	pending.clear()
	game.set_graphics(level, {})
	save()
	_refresh()


func volume(k: String, percent: float) -> void:
	game.audio.set_volume(k, percent / 100.0)
	save()
	_refresh()


func _override(k: String, v: Variant, preset_value: Variant) -> void:
	if _same(v, preset_value):
		game.overrides.erase(k)
	else:
		game.overrides[k] = v


func _build() -> Control:
	var list := Hud.col([], 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quick := HFlowContainer.new()
	quick.add_theme_constant_override("h_separation", 10)
	quick.add_theme_constant_override("v_separation", 10)
	for level: String in LEVELS:
		var b := _button(level.capitalize(), preset.bind(level), &"ChoiceButton")
		b.custom_minimum_size.x = 150
		presets[level] = b
		quick.add_child(b)
	list.add_child(Hud.label("Quick", "Heading"))
	list.add_child(quick)
	var kn := HouseStyle.knobs(game.design)
	for g: String in GROUPS:
		var mine := kn.keys().filter(func(k: String) -> bool: return ROWS.get(k, ["Other"])[0] == g)
		if mine.is_empty():
			continue
		list.add_child(Hud.label(g, "Heading"))
		for k: String in mine:
			list.add_child(_row(k, kn[k]))
	list.add_child(Hud.label("Sound", "Heading"))
	for k: String in VOLUMES:
		list.add_child(_slider(k))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var title := Hud.label("Settings", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Hud.row([Hud.icon("settings", 40), title, _button("Done", close)], 12)
	reset_button = _button("Reset to preset", func() -> void: preset(game.quality), &"ChoiceButton")
	apply_button = _button("Apply", apply)
	var foot := Hud.row([reset_button, Hud.spacer(), apply_button], 12)
	return Hud.col([head, scroll, foot], 14)


## A knob's row: its name (and marks) then its control; on a narrow screen the control wraps under the name.
func _row(k: String, knob: Dictionary) -> Control:
	var r := {"mark": Hud.tag("Tag", "", "Changed"), "wait": Hud.tag("TagLive", "", "On Apply")}
	var name := Hud.label(ROWS.get(k, ["", k])[1], "", true)
	var about := Hud.col([name, Hud.row([r.mark, r.wait], 6)], 4)
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.custom_minimum_size.x = 230
	var control: Control
	if knob.values.size() == 2 and knob.values[0] is bool:
		r.toggle = _button("", func() -> void: choose(k, r.toggle.text == "Off"), &"ChoiceButton")
		r.toggle.custom_minimum_size.x = 2 * Hud.BUTTON_H + 130
		control = r.toggle
	else:
		r.minus = _button("<", step.bind(k, -1), &"ChoiceButton")
		r.plus = _button(">", step.bind(k, 1), &"ChoiceButton")
		r.value = Hud.label("", "SmallNumber")
		r.value.custom_minimum_size.x = 130
		r.value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		control = Hud.row([r.minus, r.value, r.plus], 8)
	rows[k] = r
	return _flow([about, control])


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


func _text(k: String, v: Variant) -> String:
	if NAMES.has(k):
		for key: Variant in NAMES[k]:
			if _same(key, v):
				return NAMES[k][key]
	match k:
		"msaa":
			return "Off" if v == 0 else "%dx" % v
		"pixels":
			return "No limit" if v == 0 else "%s MP" % _num(v)
		"scale", "particles", "glow":
			return "Off" if v == 0 else "%d%%" % roundi(v * 100)
		"shadowMap", "trail":
			return "%d px" % v
		"shadowRange":
			return "%d m" % v
		"lamps":
			return "All" if v < 0 else ("None" if v == 0 else str(int(v)))
		"maxFps":
			return "No cap" if v == 0 else "%d fps" % v
	return _num(v) if v is float else str(v)


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(snappedf(v, 0.01))


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
