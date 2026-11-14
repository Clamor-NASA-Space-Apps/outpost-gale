extends Control
## The first two screens, up while ui/boot.gd loads the game underneath: the team's mark on black with one sweep of
## light across it (about 3 s; any key, click or tap skips it), then the start screen: the hero and PIP under one
## light and a short menu at the bottom left. Keys, a pad, a mouse or a finger all work it.
## The hero and PIP are a still (ui/start_bg.jpg, so the first frame is cheap on the web) and, on a computer, a
## short loop of video over it (ui/start_loop.ogv): both drawn once from the game's own models (tools/start_loop.gd),
## so the start screen itself draws no 3D.

## The kid pressed "Start mission" or "Continue" (`resume` says which). Boot puts the sandbox in once everything is
## loaded.
signal started

const Hud := preload("res://ui/hud.gd")
const Save := preload("res://sandbox/save.gd")
# 96 px tall: a 48 dp target on a phone held sideways (addons/forge/test.gd TARGET)
const ROW := Vector2(380, 96)
# Android's back swipe starts 60 px in from a side (addons/forge/test.gd EDGE): the menu stays clear of it
const MARGIN := Vector2(72, 56)
# One soft band of light, leaning like the mark's blade, masked by the picture's own alpha. At rest the mark is a
# touch under full white, or a light would have nowhere to go on a white C.
const SHINE := """shader_type canvas_item;
uniform float at = -1.0;
void fragment() {
	float band = smoothstep(0.16, 0.0, abs((UV.x + 0.5 * UV.y) / 1.5 - at));
	COLOR.rgb = COLOR.rgb * 0.82 + (1.0 - COLOR.rgb * 0.82) * band * 0.7;
}"""

var splash: ColorRect  # null once the menu has the screen
var shine := ShaderMaterial.new()
var loop := "res://ui/start_loop.ogv"
var video: VideoStreamPlayer  # the hero and PIP alive, over the still; null on a phone or with no file to play
var menu: VBoxContainer
var rows: Array[Button] = []  # Start mission, Credits, Exit; with a checkpoint, Continue first
var checkpoint := {}  # the last morning saved (sandbox/save.gd); empty when there is none to use
var resume := {}  # the checkpoint again once Continue was pressed: boot hands it to the sandbox
var credits: PanelContainer
var back: Button
var bar := ColorRect.new()
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = Hud.THEME
	var picture := TextureRect.new()
	picture.texture = load("res://ui/start_bg.jpg")
	picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(picture)
	_menu()
	_credits()
	# loading, as a thin line along the bottom edge
	bar.color = Hud.color("primary")
	bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bar.offset_top = -4
	bar.anchor_right = 0.0
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bar)
	_splash()
	if OS.has_feature("web"):
		# the page's own loading screen stays up until this one is on the canvas: no black frame between them
		# (web/shell.html; ui/cover.gd makes the same call for the sandbox's cover)
		RenderingServer.frame_post_draw.connect(func() -> void: JavaScriptBridge.eval("window.shellDone && shellDone()", true), CONNECT_ONE_SHOT)


## Loading's share done, 0 to 1 (ui/boot.gd).
func progress(k: float) -> void:
	bar.anchor_right = k
	bar.visible = k < 1.0


## The hero and PIP alive: the loop over the still, filling the screen as the still does (16:9, covering it), faded in
## once it plays. Not on a phone or a tablet, where the processor alone decodes every frame, and not without the
## file: the still stays, and nothing else changes.
func _play() -> void:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios") or not ResourceLoader.exists(loop):
		return
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_COVER
	frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.0
	video = VideoStreamPlayer.new()
	video.stream = load(loop)
	video.loop = true
	video.expand = true
	video.mouse_filter = MOUSE_FILTER_IGNORE
	frame.add_child(video)
	add_child(frame)
	move_child(frame, 1)  # over the still, under the menu
	video.play()
	var t := create_tween()
	t.tween_interval(0.2)  # its first frame is decoded by then
	t.tween_property(frame, "modulate:a", 1.0, 0.6)


func _splash() -> void:
	splash = ColorRect.new()
	# black, the one colour not from the theme: the team asked for its mark on black, and it is the team's card,
	# not a part of the game's look. Read from where the engine's own splash takes it, so the two cannot differ
	splash.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	splash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)  # it stops the mouse: no click reaches the menu under it
	add_child(splash)
	var mark := Control.new()
	mark.set_anchors_and_offsets_preset(PRESET_CENTER)
	mark.mouse_filter = MOUSE_FILTER_IGNORE
	splash.add_child(mark)
	var logo := TextureRect.new()
	logo.texture = load("res://ui/clamor_logo.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.position = Vector2(-130, -190)
	logo.size = Vector2(260, 260)
	shine.shader = Shader.new()
	shine.shader.code = SHINE
	logo.material = shine
	mark.add_child(logo)
	var spaced := FontVariation.new()
	spaced.base_font = load("res://ui/fonts/Exo2-wght.ttf")
	spaced.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	spaced.spacing_glyph = 20
	var team := Hud.label("CLAMOR")
	team.add_theme_font_override("font", spaced)
	team.add_theme_font_size_override("font_size", 40)
	team.add_theme_color_override("font_color", Hud.color("on_surface"))
	team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team.position = Vector2(-300, 96)
	team.size = Vector2(600, 56)
	mark.add_child(team)
	# no fade in: the engine's boot splash and the web page's loading screen show this same frame (ui/boot_splash.png)
	_tween = create_tween()
	_tween.tween_interval(0.4)
	_tween.tween_method(func(v: float) -> void: shine.set_shader_parameter("at", v), -0.2, 1.2, 1.3)
	_tween.tween_interval(0.7)
	_tween.tween_property(splash, "modulate:a", 0.0, 0.5)
	_tween.tween_callback(_open)


## The menu takes the screen.
func _open() -> void:
	_tween.kill()
	splash.queue_free()
	splash = null
	rows[0].grab_focus()
	_play()


func _input(e: InputEvent) -> void:
	if splash:
		# every press is the splash's while it is up: a tap also arrives as a mouse click a moment later, and that
		# click would land on a menu row if the splash went at once. So it fades, quickly, and still takes the press
		if e.is_pressed() and not e.is_echo() and (e is InputEventKey or e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventJoypadButton):
			get_viewport().set_input_as_handled()
			if splash.modulate.a == 1.0:
				_tween.kill()
				_tween = create_tween()
				_tween.tween_property(splash, "modulate:a", 0.0, 0.15)
				_tween.tween_callback(_open)
	elif credits.visible and e.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_credits(false)


func _menu() -> void:
	var cap := Hud.label("JUNIOR ASTRONAUT MISSION TRAINER", "CapLight")
	cap.add_theme_font_size_override("font_size", 14)  # the HUD's caps are sized for a corner of the screen
	menu = Hud.col([cap], 6)
	var title := Hud.label("Outpost Gale", "Heading")
	title.add_theme_font_size_override("font_size", 56)
	menu.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	menu.add_child(gap)
	rows = [_row("Start mission", _start.bind({})), _row("Credits", _show_credits.bind(true)), _row("Exit", get_tree().quit)]
	rows[2].visible = not OS.has_feature("web")  # a page has nothing to exit to
	checkpoint = Save.read()
	if not checkpoint.is_empty():
		rows.push_front(_row("Continue: Sol %d" % checkpoint.sol, _start.bind(checkpoint)))
	for b in rows:
		menu.add_child(b)
	menu.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	menu.grow_vertical = GROW_DIRECTION_BEGIN
	menu.position += Vector2(MARGIN.x, -MARGIN.y)
	add_child(menu)


func _credits() -> void:
	back = _row("Back", _show_credits.bind(false))
	var lines: Array = [Hud.label("Credits", "MenuTitle"), Hud.label("Team Clamor", "MenuStrong")]
	for t: String in ["Data and photos: NASA. Not endorsed by NASA.", "Built with AI assistance. Sources: the project page."]:
		lines.append(Hud.label(t, "MenuText"))
	for l: Label in lines.slice(1):
		l.add_theme_font_size_override("font_size", 17)  # menu text is sized for a settings row; this is all there is to read
	lines.append(back)
	credits = Hud.panel("HudMenu", Hud.col(lines, 14))
	# where the menu was, so the hero stays in view
	credits.set_anchors_and_offsets_preset(PRESET_BOTTOM_LEFT)
	credits.grow_vertical = GROW_DIRECTION_BEGIN
	credits.position += Vector2(MARGIN.x, -MARGIN.y)
	credits.visible = false
	add_child(credits)


func _show_credits(on: bool) -> void:
	credits.visible = on
	menu.visible = not on  # hidden rows take no focus, so the keys stay on Back
	(back if on else rows[-2]).grab_focus()  # Credits


## From Sol 1 (`saved` empty) or from the checkpoint. The checkpoint itself stays until the next morning's.
func _start(saved: Dictionary) -> void:
	resume = saved
	# on the row pressed (Continue is the first row when there is one); read only while boot still loads: the sandbox
	# comes in by itself after
	rows[0 if saved == checkpoint else 1].text = "Loading..."
	started.emit()


## A menu row: dark glass, and on the row in focus a teal tint with a bar at its left edge (a shape, not only a
## colour). The mouse moves the focus too, so one row is ever marked.
func _row(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = ROW
	b.add_theme_font_override("font", Hud.THEME.get_font("font", "Heading"))
	b.add_theme_font_size_override("font_size", 28)
	for c: String in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(c, Hud.color("on_surface_variant"))
	for c: String in ["font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Hud.color("on_surface"))
	var plain := StyleBoxFlat.new()
	plain.bg_color = Hud.color("hud_glass_menu")
	plain.content_margin_left = 30
	var lit := plain.duplicate() as StyleBoxFlat
	lit.bg_color = Hud.color("hud_seg_on")
	lit.border_color = Hud.color("accent")
	lit.border_width_left = 6
	for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, plain)
	b.add_theme_stylebox_override("focus", lit)  # drawn over the plain one
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(on)
	return b
