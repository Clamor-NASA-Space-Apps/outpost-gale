extends CanvasLayer
## The settings screen, opened by the gear or Esc, in menu glass (design/mockups/settings.html, approved 13 Nov 2026).
## Tabs on the left: Graphics (five presets named for the hardware they suit, then "Fine tune": six plain choices,
## ADVANCED, each a bundle of HouseStyle knobs), Sound (three levels), Controls (the keys), Screen (full screen, the
## frame counter). A preset card applies at once. A fine-tune pick goes on a moment later (APPLY_S, so a few picks
## share one cover), or when the screen closes; the cover hides any shader compile. Every save shows "Saved". The
## Esc chip at the top right closes it (a touch player has no Esc). Kept per device in user://.
## It changes how the game looks and sounds, never anything the game counts (hard rule 1).
## The game it drives (the sandbox) has `design`, `quality`, `overrides`, `audio`, `fps_label` and
## `set_graphics(level, overrides, restyle := true, warm := true)`.

## A sound the screen asks for: "tick" when the pointer or focus reaches a control, "select" when a choice is picked.
## The game plays it (audio.ui); the screen plays nothing itself.
signal cue(name: String)

const Hud := preload("res://ui/hud.gd")
const HouseStyle := preload("res://addons/forge/house_style.gd")
# DESIGN.md quality id -> [name, icon, one line]. Ids missing here still get a card, by their own name.
const PRESETS := {
	"phone": ["Phone", "device_phone", "Budget phones"],
	"older": ["Older laptop", "device_older", "2015 to 2018"],
	"laptop": ["Laptop", "device_laptop", "No graphics card"],
	"gaming": ["Gaming PC", "device_gaming", "With a graphics card"],
	"max": ["Max", "device_max", "Everything on"],
}
const TABS := [["Graphics", "sun"], ["Sound", "live"], ["Controls", "hop"], ["Screen", "device_laptop"]]
# the Controls tab: what each key does, read from the input map (player/controls.gd registers it)
const KEYS := [["Walk", ["move_forward", "move_left", "move_back", "move_right"]], ["Hurry", ["hurry"]],
	["Hop", ["jump"]], ["Use", ["interact"]], ["Look", ["look_left", "look_up", "look_down", "look_right"]],
	["Map", ["map"]], ["Full screen", ["fullscreen"]], ["Settings", ["settings"]]]
const APPLY_S := 1.0  # a fine-tune pick goes on this long after the last one
const WIDTH := 747.0  # the mockup's 1120 px at 1080p, on the 720 px canvas
const SMALL_H := 32.0  # a segment or card row on a laptop (a mouse); a phone gets Hud.BUTTON_H
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
		["Medium", {"shadows": 2, "shadowMap": 2048, "shadowRange": 40, "shadowFilter": 3, "normalBias": 6.0}],
		["High", {"shadows": 4, "shadowMap": 4096, "shadowRange": 40, "shadowFilter": 4, "normalBias": 3.0}],
		["Ultra", {"shadows": 4, "shadowMap": 4096, "shadowRange": 40, "shadowFilter": 5, "normalBias": 3.0}]],
	"Effects": [["Low", {"glow": 0.0, "particles": 0.5, "lamps": 2}],
		["Medium", {"glow": 0.4, "particles": 0.75, "lamps": 4}],
		["High", {"glow": 0.5, "particles": 1.0, "lamps": -1}]],
	"V-Sync": [["On", {"vsync": true}], ["Off", {"vsync": false}]],
	"Frame cap": [["None", {"maxFps": 0}], ["30 fps", {"maxFps": 30}], ["45 fps", {"maxFps": 45}], ["60 fps", {"maxFps": 60}],
		["120 fps", {"maxFps": 120}]],
}
const VOLUMES := {"master": "All sound", "music": "Music", "effects": "Suit and world", "interface": "Interface"}

# "" until first asked: user://settings.cfg in the game, "-" (none) in a test or tool run, so a player's saved
# choices never change what a check measures. A test that checks saving sets its own file first.
static var file := ""

var game: Node
var draft := {}  # the fine-tune choices as knob overrides, put on by apply()
var rows := {}  # fine-tune row name -> its SegButtons, one per option (the laptop's switches)
var steppers := {}  # fine-tune row name -> [<, value, >, the row]: a phone's or a narrow screen's "<  High  >"
var compact := false  # touch or narrow: steppers in place of switches (_fit)
var cards := {}  # preset id -> Button
var sliders := {}  # volume name -> HSlider
var tabs: Array[Button] = []
var pages: Array[Control] = []  # one per tab
var page := 0
var phone := DisplayServer.is_touchscreen_available()  # drawn larger, with margins clear of the back swipe
var root := Control.new()  # the screen, scaled for the device (_fit)
var gear := Button.new()
var shade := ColorRect.new()
var panel: PanelContainer
var close_button: Button  # the Esc chip
var fps_buttons: Array[Button] = []  # On, Off
var full_buttons: Array[Button] = []  # On, Off; empty where a page cannot go full screen (iPhone Safari)
var saved_tag: Control
var scroll := ScrollContainer.new()
var body: Control  # the tab column and the page beside it
var timer := Timer.new()  # waits APPLY_S after a fine-tune pick
var _flash: Tween


static func _path() -> String:
	if file == "":
		var tool := Engine.get_main_loop().get_script() != null or Array(OS.get_cmdline_user_args()).any(
			func(a: String) -> bool: return a.begins_with("--forge-job="))
		file = "-" if tool else "user://settings.cfg"
	return file


## What this device chose last time: {level, overrides, volume, fps, full}, each checked; {} when nothing was saved. Only the
## knobs Advanced can set come back, so a knob the screen no longer shows can never stay changed out of sight.
static func saved() -> Dictionary:
	var c := ConfigFile.new()
	if _path() == "-" or c.load(_path()) != OK:
		return {}
	var level := str(c.get_value("graphics", "level", ""))
	var out := {"level": OLD.get(level, level), "overrides": {}, "volume": {}, "fps": c.get_value("hud", "fps", true) == true}
	if c.has_section_key("display", "full"):
		out.full = c.get_value("display", "full") == true  # read by ui/boot.gd; a game never asked starts full screen
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
		if not OS.has_feature("web"):  # a browser leaves full screen on its own, and enters it only on a press
			c.set_value("display", "full", _full())
		for k: String in VOLUMES:
			c.set_value("sound", k, game.audio.volume.get(k, 1.0))
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
	shade.color = Hud.color("hud-scrim-menu")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP  # the world under it takes no clicks or look drags
	root.add_child(shade)
	panel = Hud.panel("HudMenu", _build())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	for c: Node in panel.find_children("*", "Control", true, false):
		if c is BaseButton or c is Range:  # a tick as the pointer or the keys reach it, once per arrival
			(c as Control).mouse_entered.connect(cue.emit.bind("tick"))
			(c as Control).focus_entered.connect(cue.emit.bind("tick"))
		if c is BaseButton and c != close_button:
			(c as BaseButton).pressed.connect(cue.emit.bind("select"))
	timer.one_shot = true
	timer.wait_time = APPLY_S
	timer.timeout.connect(apply)
	add_child(timer)
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
	gear.visible = false  # the Esc chip closes it; the gear sat under the panel's corner on a phone
	draft = game.overrides.duplicate()
	_refresh()
	_fit.call_deferred()  # the page's size settles on the next frame


## The Esc chip, the Esc key or the gear: what still waits is applied, nothing chosen is lost.
func close() -> void:
	timer.stop()
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
		var i := current(r)  # -1 (a mix no option names) lights none
		for j: int in rows[r].size():
			(rows[r][j] as Button).set_pressed_no_signal(j == i)
		var st: Array = steppers[r]
		(st[1] as Label).text = String(ADVANCED[r][i][0]) if i >= 0 else "Mixed"
		(st[0] as Button).disabled = i == 0  # at an end the arrow greys and stops: a shape change too, not colour alone
		(st[2] as Button).disabled = i == ADVANCED[r].size() - 1
	_onoff(fps_buttons, game.fps_label.visible)
	_full_text()
	for i: int in tabs.size():
		tabs[i].set_pressed_no_signal(i == page)
		pages[i].visible = i == page
	for k: String in sliders:
		var v: float = game.audio.volume.get(k, 1.0)
		sliders[k].set_value_no_signal(v * 100.0)
		sliders[k].get_meta("label").text = "%d%%" % roundi(v * 100.0)


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


## A stepper's arrow: the option before (-1) or after (+1) the one in force; from a mix, the first or last.
func step(r: String, d: int) -> void:
	var i := current(r)
	var n: int = ADVANCED[r].size()
	choose(r, (0 if d > 0 else n - 1) if i < 0 else clampi(i + d, 0, n - 1))


## A fine-tune pick: it goes on APPLY_S later (or when the screen closes), behind the cover.
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
	if waiting():
		timer.start()


func show_tab(i: int) -> void:
	page = i
	scroll.scroll_vertical = 0
	_refresh()
	_fit.call_deferred()


## The fine-tune choices on, behind the cover (a shader knob compiles there), and saved.
func apply() -> void:
	if not waiting():
		return
	game.set_graphics(game.quality, draft.duplicate())
	save()
	_refresh()


## A preset card: every knob back to it, at once (so the card in force is also "reset to preset").
func preset(level: String) -> void:
	timer.stop()
	draft.clear()
	game.set_graphics(level, {})
	save()
	_refresh()


func volume(k: String, percent: float) -> void:
	game.audio.set_volume(k, percent / 100.0)
	save()
	_refresh()


func _build() -> Control:
	var head := Hud.row([Hud.icon("settings", 22, "on_surface"), Hud.label("Settings", "MenuTitle"), Hud.spacer()], 10)
	close_button = _button("Esc", close, &"ChoiceButton")
	close_button.icon = load("res://ui/icons/close.svg")
	close_button.tooltip_text = "Close"
	close_button.add_theme_constant_override("icon_max_width", 16)
	close_button.add_theme_font_size_override("font_size", 10)  # the mockup's 15 px key chip
	close_button.set_meta("seg", true)  # a finger's width on a phone
	head.add_child(close_button)
	var column := Hud.col([], 4)
	for i: int in TABS.size():
		var t := _button(TABS[i][0], show_tab.bind(i), &"TabButton")
		t.toggle_mode = true
		t.icon = load("res://ui/icons/%s.svg" % TABS[i][1])
		t.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tabs.append(t)
		column.add_child(t)
	var stack := Control.new()  # ponytail: the pages share one scroll; only the open one is visible
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var each := Hud.col([], 0)
	each.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p: Control in [_graphics(), _sound(), _controls(), _screen()]:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.append(p)
		each.add_child(p)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(each)
	column.custom_minimum_size.x = 127  # the mockup's 190 px tab column
	body = BoxContainer.new()  # side by side; stacked on a narrow (portrait) screen (_fit)
	body.add_theme_constant_override("separation", 19)
	body.add_child(column)
	body.add_child(scroll)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	saved_tag = Hud.tag("TagLive", "check", "Saved")
	saved_tag.visible = false
	var line := ColorRect.new()
	line.color = Hud.color("hud-stroke-faint")
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var foot := Hud.row([Hud.label("Changes apply behind the cover, in a moment.", "MenuFoot", true), saved_tag], 12)
	return Hud.col([head, body, line, foot], 12)


func _graphics() -> Control:
	var deck := GridContainer.new()  # five equal cards in a row, as in the mockup; 3 + 2 on a narrow screen (_sizes)
	deck.columns = 5
	deck.set_meta("deck", true)
	deck.add_theme_constant_override("h_separation", 7)
	deck.add_theme_constant_override("v_separation", 7)
	for id: String in game.design.quality:
		deck.add_child(_card(id))
	var grid := GridContainer.new()  # two columns on a laptop, one on a phone (_sizes)
	grid.columns = 2
	grid.set_meta("fine", true)
	grid.add_theme_constant_override("h_separation", 19)
	grid.add_theme_constant_override("v_separation", 8)
	for r: String in ADVANCED:
		grid.add_child(_row(r))
	return Hud.col([Hud.label("Your device", "Cap"), deck, Hud.label("Fine tune", "Cap"), grid], 8)


func _sound() -> Control:
	var c := Hud.col([Hud.label("Sound", "Cap")], 8)
	for k: String in VOLUMES:
		c.add_child(_slider(k))
	return c


func _controls() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 19)
	grid.add_theme_constant_override("v_separation", 8)
	for k: Array in KEYS:
		var keys: Array[String] = []
		for a: String in k[1]:
			if InputMap.has_action(a):
				for e: InputEvent in InputMap.action_get_events(a):
					var key := e as InputEventKey
					if key:
						keys.append(OS.get_keycode_string(key.physical_keycode if key.physical_keycode else key.keycode))
						break  # the first key of each action: W A S D, not the arrows too
		if keys.is_empty():
			continue
		grid.add_child(Hud.label(k[0], "MenuText"))
		var chips := Hud.row([], 6)
		for name: String in keys:
			chips.add_child(Hud.panel("HudKey", Hud.label(name, "KeyText")))
		grid.add_child(chips)
	return Hud.col([Hud.label("Keys", "Cap"), grid], 8)


func _screen() -> Control:
	var c := Hud.col([Hud.label("Screen", "Cap")], 8)
	fps_buttons = _switch(func(on: bool) -> void:
		game.fps_label.visible = on
		save()
		_refresh())
	c.add_child(_line("Show FPS", _group(fps_buttons)))
	if not OS.has_feature("web_ios"):  # iPhone Safari has no full screen for a page; Add to Home Screen is the way
		full_buttons = _switch(func(on: bool) -> void:
			if on != _full():
				full_screen())
		c.add_child(_line("Full screen", _group(full_buttons)))
	return c


## A preset as a card: its icon, its name, one line, and a check in the corner when it is in force.
func _card(id: String) -> Button:
	var about: Array = PRESETS.get(id, [id.capitalize(), "settings", ""])
	var b := _button("", preset.bind(id), &"DeviceCard")
	b.toggle_mode = true
	b.set_meta("h", 76.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var check := Hud.icon("check", 16, "primary")
	check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -22
	check.offset_right = -6
	check.offset_top = 6
	check.offset_bottom = 22
	b.set_meta("check", check)
	var name := Hud.label(about[0], "MenuStrong")
	var line := Hud.label(about[2], "MenuSmall", true)
	for l: Label in [name, line]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a narrow card takes its line in two
	var icon := Hud.icon(about[1], 20, "on_surface")
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var inside := Hud.col([icon, name, line], 3)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 6)
	for c: Control in [inside, name, line]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the card takes the click
	b.add_child(inside)
	b.add_child(check)
	b.set_meta("seg", true)  # a finger's width on a phone
	cards[id] = b
	return b


## A fine-tune row: its name, then a segmented switch, one button per option.
func _row(r: String) -> Control:
	var segs: Array[Button] = []
	var group := _group([])
	for i: int in ADVANCED[r].size():
		var b := _seg(String(ADVANCED[r][i][0]).trim_suffix(" fps"), choose.bind(r, i))
		segs.append(b)
		group.add_child(b)
	rows[r] = segs
	var line := _line(r, group)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the compact form: the name, then "<  High  >", one touch target high (_sizes shows one form or the other)
	var minus := _button("<", step.bind(r, -1), &"ChoiceButton")
	var plus := _button(">", step.bind(r, 1), &"ChoiceButton")
	var value := Hud.label("", "MenuStrong")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.custom_minimum_size.x = 80.0
	var name := Hud.label(r, "MenuText")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stepper := Hud.row([name, minus, value, plus], 8)
	steppers[r] = [minus, value, plus, stepper]
	var both := Hud.col([line, stepper], 0)
	both.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return both


## An On / Off switch as two segments; `on` gets true or false.
func _switch(on: Callable) -> Array[Button]:
	var out: Array[Button] = []
	for v: bool in [true, false]:
		out.append(_seg("On" if v else "Off", on.bind(v)))
	return out


## A name, then its switch at the right.
func _line(text: String, group: Control) -> Control:
	var box := Hud.panel("SegGroup", group)
	var name := Hud.label(text, "MenuText")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Hud.row([name, box], 12)


## A switch's segments in one line on a laptop; on a narrow phone they may wrap to a second line (_sizes).
func _group(segs: Array) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_END
	f.add_theme_constant_override("h_separation", 0)
	f.add_theme_constant_override("v_separation", 0)
	f.set_meta("flow", true)
	for b: Button in segs:
		f.add_child(b)
	return f


func _seg(text: String, on: Callable) -> Button:
	var b := _button(text, on, &"SegButton")
	b.toggle_mode = true
	b.set_meta("h", SMALL_H)
	b.set_meta("seg", true)
	return b


func _onoff(segs: Array[Button], on: bool) -> void:
	if segs.size() == 2:
		segs[0].set_pressed_no_signal(on)
		segs[1].set_pressed_no_signal(not on)


## A laptop row's height, or a touch target on a phone.
func _h(laptop: float) -> float:
	return maxf(laptop, Hud.BUTTON_H) if phone else laptop


## Every control's height (meta "h", its laptop size) for this device; a segment gets a finger's width on a phone.
func _sizes() -> void:
	for c: Node in root.find_children("*", "Control", true, false):
		if c.has_meta("h"):
			(c as Control).custom_minimum_size.y = _h(c.get_meta("h"))
		if c.has_meta("seg"):
			(c as Control).custom_minimum_size.x = Hud.BUTTON_H if phone else 0.0
	for c: Node in root.find_children("*", "GridContainer", true, false):
		if c.has_meta("fine"):
			(c as GridContainer).columns = 1 if compact else 2
		elif c.has_meta("deck"):
			(c as GridContainer).columns = 3 if body and (body as BoxContainer).vertical else 5  # 3 + 2 when narrow
	for r: String in steppers:
		var st: Array = steppers[r]
		(st[3] as Control).visible = compact
		(st[3] as Control).get_parent().get_child(0).visible = not compact
		for b: Button in [st[0], st[2]]:
			# exactly a 48 dp target on a phone (96 scene px under PHONE_SCALE, addons/forge/test.gd TARGET), 48 px under a mouse
			var t := 96.0 / Hud.PHONE_SCALE if phone else 48.0
			b.custom_minimum_size = Vector2(t, t)
	# a flow asks only for its widest child: on a laptop ask for the whole line, so a switch never wraps there
	for c: Node in root.find_children("*", "HFlowContainer", true, false):
		if c.has_meta("flow"):
			var w := 0.0
			for b: Control in c.get_children():
				w += b.get_combined_minimum_size().x
			(c as Control).custom_minimum_size.x = 0.0 if phone else w
			# the box hugs its segments on a laptop; on a phone it takes the line, so they can wrap in it
			(c.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL if phone else Control.SIZE_SHRINK_END


func _slider(k: String) -> Control:
	var s := HSlider.new()
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size.x = 240
	s.set_meta("h", SMALL_H)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Hud.color("hud-track")
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Hud.color("accent")
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var shown := Hud.label("", "HudNum")
	shown.custom_minimum_size.x = 44
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.set_meta("label", shown)
	s.value_changed.connect(func(v: float) -> void: volume(k, v))
	sliders[k] = s
	var name := Hud.label(VOLUMES[k], "MenuText")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Hud.row([name, s, shown], 12)


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
	if not OS.has_feature("web"):
		save()  # the next start opens the same way (ui/boot.gd)


func _full() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _full_text() -> void:
	_onoff(full_buttons, _full())


func _button(text: String, on: Callable, variation := &"") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.set_meta("h", 48.0)  # the close chip and the tabs on a laptop; _sizes() makes it a touch target on a phone
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
	var room := root.size - 2.0 * m
	(body as BoxContainer).vertical = room.x < 620.0  # portrait: the tabs go above the page
	compact = phone or room.x < 620.0  # a finger or a narrow screen gets steppers, a laptop the approved switches
	_sizes()
	# as tall as the open page needs, up to the screen; past that the page scrolls
	scroll.custom_minimum_size.y = 0.0
	var need: float = pages[page].get_combined_minimum_size().y
	scroll.custom_minimum_size.y = need
	var over := panel.get_combined_minimum_size().y - room.y
	if over > 0.0:
		scroll.custom_minimum_size.y = maxf(80.0, need - over)
	panel.size = Vector2(minf(room.x, WIDTH), 0.0)
	panel.reset_size()
	panel.size.x = maxf(panel.size.x, minf(room.x, WIDTH))
	panel.position = ((root.size - panel.size) / 2.0).floor()


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
