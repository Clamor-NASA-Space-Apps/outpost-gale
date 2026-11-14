extends Control
## PIP's speech bubble (design/mockups/hud.png): glass with a teal left edge, "PIP" and a voice wave that moves while
## he talks, the line typed in letter by letter over its own faint copy, so the bubble never changes size. With a
## speaker (follow()) it floats above his head, projected each frame, with a thin line down to a ring on him; off
## screen or behind the camera it docks at the nearest edge with an arrow toward him. Without one it rests at the
## bottom centre, like a subtitle. A short synthesised chirp every few letters reads as his voice.
## A line stays up until the next one or hide_line(). Under the words it can show the keys it teaches (keycaps from
## the atlas; on a touch screen the touch control's icon or a short word), and a fact waits for the player: Enter (or
## a tap on the bubble) first finishes the typing, then dismisses it (signal dismissed).
## `*words*` in a line are its key fact: bold, in the primary colour, and the asterisks never show.

signal finished  # the line is typed out
signal dismissed(line_id: String)

const Hud := preload("res://ui/hud.gd")
const CHARS_PER_S := 30.0
const CHIRP_EVERY := 3  # letters per chirp
# what a key is on a touch screen: an icon of the touch control, or a short word
const TOUCH := {"W": "Stick", "A": "Stick", "S": "Stick", "D": "Stick", "Mouse": "Drag", "Space": "icon:hop",
	"Shift": "Stick far", "E": "icon:use", "M": "Tap map", "Enter": "Tap"}
const WIDTH := 253.0  # 380 mockup px
const TAIL := 60.0  # how far the bubble floats above the point it speaks from
const EDGE := 12.0  # the gap the docked bubble keeps from the screen edge
const ARROW := 30.0  # the docked arrow's length
const BARS := 5

var panel: PanelContainer
var label: RichTextLabel
var wave := Control.new()
var speaker: Node3D
var camera: Camera3D
var head := 0.0  # metres from the speaker's origin to just above its top
var text := ""  # the line as it reads, without the asterisks
var runs: Array = []  # the line in order, [words, marked]: a marked run draws bold in the primary colour
var pieces: Array = []  # what is drawn now, [words, colour, font or null], for the tests
var bold: Font
var typed := 0  # letters shown so far
var docked := false
var dir := Vector2.DOWN  # docked: which way the speaker is
var anchor := Vector2.ZERO  # in this control's space: the point the tail touches
var chirps := 0  # how many have played, for the tests
var line_id := ""
var fact := false  # waits for Enter or a tap
var touch := false
var keys_row: HBoxContainer
var hint_row: HBoxContainer
var _typed := 0.0
var _t := 0.0
var _player := AudioStreamPlayer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("shapes", true)  # the line to PIP, his ring, the teal edge: rects from the atlas (Hud.layer)
	label = RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", get_theme_font("font", "BubbleText"))
	label.add_theme_font_size_override("normal_font_size", get_theme_font_size("font_size", "BubbleText"))
	label.add_theme_color_override("font_outline_color", get_theme_color("font_outline_color", "Label"))
	bold = get_theme_font("font", "MenuTitle")  # the same family at 700
	# the label's dark edge is drawn here, not by Hud.edge (which leaves a label that has an "Edge" alone): that one
	# shapes the whole line in the normal font, so after a bold run it would lie beside the words
	var e := Control.new()
	e.name = "Edge"
	e.show_behind_parent = true
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	e.set_meta("edge_of", true)
	e.draw.connect(_draw_edge.bind(e))
	label.add_child(e)
	label.draw.connect(e.queue_redraw)
	wave.custom_minimum_size = Vector2(22, 12)
	wave.draw.connect(_draw_wave)
	wave.set_meta("shapes", true)
	var who := Hud.row([Hud.icon("pip", 15, "accent"), Hud.label("PIP", "CapLight"), Hud.spacer(), wave], 6)
	keys_row = Hud.row([], 6)
	hint_row = Hud.row([], 6)
	hint_row.alignment = BoxContainer.ALIGNMENT_END
	panel = Hud.panel("HudPanel", Hud.col([who, label, keys_row, hint_row], 6))
	panel.gui_input.connect(_tapped)
	panel.name = "Bubble"
	panel.custom_minimum_size.x = WIDTH
	add_child(panel)
	_player.stream = _chirp()
	_player.bus = &"UI" if AudioServer.get_bus_index(&"UI") >= 0 else &"Master"
	_player.volume_db = -10.0
	add_child(_player)
	hide()


func follow(node: Node3D, cam: Camera3D) -> void:
	speaker = node
	camera = cam
	# the top of what the speaker draws, so the bubble clears his head whatever his model's size
	var top := 0.0
	for m: Node in node.find_children("*", "VisualInstance3D", true, false):
		var v := m as VisualInstance3D
		var box := v.global_transform * v.get_aabb()
		top = maxf(top, box.end.y - node.global_position.y)
	head = top + 0.2


## A line in PIP's voice. `keys`: the key names it teaches ("W", "Mouse", "Space"...); `is_fact`: it waits for
## Enter or a tap.
func speak(line: String, id := "", keys: Array = [], is_fact := false) -> void:
	var parts := line.split("*")
	runs = []
	for i in parts.size():
		if parts[i] != "":
			runs.append([parts[i], i % 2 == 1 and i < parts.size() - 1])  # an asterisk with no partner marks nothing
	text = "".join(parts)
	line_id = id
	fact = is_fact
	typed = 0
	_typed = 0.0
	_show_text()
	for c: Node in keys_row.get_children() + hint_row.get_children():
		c.queue_free()
	var seen := {}
	for k: String in keys:
		var cap := _cap(k)
		if not seen.has(cap):  # W, A, S and D are all "Stick" on a phone
			seen[cap] = true
			keys_row.add_child(_keycap(k))
	keys_row.visible = not keys.is_empty()
	if fact:
		hint_row.add_child(_keycap("Enter"))
		hint_row.add_child(Hud.label("to continue" if touch else "Continue", "HudText"))
	hint_row.visible = fact
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if fact else Control.MOUSE_FILTER_IGNORE  # a fact takes a tap
	Hud.layer(keys_row)
	Hud.layer(hint_row)
	show()
	_place()  # in place on its first frame, not at the corner


func hide_line() -> void:
	hide()
	fact = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cap(k: String) -> String:
	return TOUCH.get(k, k) if touch else k


## A key as a small glass keycap; "Mouse" is a mouse drawing; on a touch screen the control's icon or word.
func _keycap(k: String) -> Control:
	var cap := _cap(k)
	if cap.begins_with("icon:"):
		return Hud.icon(cap.trim_prefix("icon:"), 18, "light")
	if cap == "Mouse":
		return Hud.icon("mouse", 18, "light")
	var key := Hud.panel("HudKey", Hud.label(cap, "HudNum"))
	key.set_meta("icon", true)
	return key


## Enter (not Space, which is the hop), or a tap or click on the bubble: finish the typing first, then dismiss.
func _input(e: InputEvent) -> void:
	if visible and fact and e.is_action_pressed("ui_accept") and not (InputMap.has_action("jump") and e.is_action("jump")):
		get_viewport().set_input_as_handled()
		_dismiss()


func _tapped(e: InputEvent) -> void:
	if fact and ((e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch) and e.is_pressed():
		panel.accept_event()
		_dismiss()


func _dismiss() -> void:
	if typing():
		typed = text.length()
		_typed = typed
		_show_text()
		finished.emit()
		return
	hide_line()
	dismissed.emit(line_id)


func typing() -> bool:
	return visible and typed < text.length()


## The typed letters in ink (a marked run bold, in the primary colour), the rest as a faint copy in the same fonts:
## the layout is the whole line from the first letter.
func _show_text() -> void:
	label.clear()
	pieces = []
	var at := 0
	for r: Array in runs:
		var words: String = r[0]
		var n := clampi(typed - at, 0, words.length())
		var font: Font = bold if r[1] else null
		if font:
			label.push_font(font)
		_put(words.substr(0, n), Hud.color("primary" if r[1] else "on-surface"), font)
		_put(words.substr(n), Hud.color("hud-ink-ghost"), font)
		if font:
			label.pop()
		at += words.length()


func _put(words: String, col: Color, font: Font) -> void:
	if words == "":
		return
	label.push_color(col)
	label.add_text(words)
	label.pop()
	pieces.append([words, col, font])


## The dark edge round the letters, as Hud.edge draws it (the same words 8 times, 1.5 px out, from the label's own
## glyph textures), laid out run by run in each run's font. Words not typed yet get an edge as faint as they are.
func _draw_edge(e: Control) -> void:
	if text == "" or not label.is_visible_in_tree():
		return
	var s := label.get_theme_font_size("normal_font_size")
	var p := TextParagraph.new()
	for r: Array in runs:
		p.add_string(r[0], bold if r[1] else label.get_theme_font("normal_font"), s)
	p.width = label.size.x
	p.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var col := label.get_theme_color("font_outline_color")
	col.a = 1.0 - pow(1.0 - col.a, 1.0 / 3.0)  # about three copies overlap at a letter's edge
	var faint := col
	faint.a *= Hud.color("hud-ink-ghost").a
	var ts := TextServerManager.get_primary_interface()
	var ci := e.get_canvas_item()
	var y := 0.0
	for i in p.get_line_count():
		var w := p.get_line_width(i)
		var rid := p.get_line_rid(i)
		var span := p.get_line_range(i)
		# where the typed words end on this line, in px from its start
		var cut := w
		if typed < span.y:
			cut = 0.0 if typed <= span.x else ts.shaped_text_get_grapheme_bounds(rid, typed).x
		for k in 8:
			var o := Vector2(0.0, y + p.get_line_ascent(i)) + Vector2.from_angle(k * TAU / 8.0) * Hud.EDGE_R
			if cut >= w:
				ts.shaped_text_draw(rid, ci, o, -1.0, -1.0, col)  # all typed: no clip (a clip cuts the last glyph)
			elif cut > 0.0:
				ts.shaped_text_draw(rid, ci, o, -1.0, cut - 0.5, col)
			if cut < w:
				ts.shaped_text_draw(rid, ci, o, maxf(cut, 0.01), -1.0, faint)
		y += p.get_line_size(i).y


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if typed < text.length():
		_typed += delta * CHARS_PER_S
		var before := typed
		typed = mini(int(_typed), text.length())
		for i in range(before, typed):
			if text[i] != " " and i % CHIRP_EVERY == 0:
				_play_chirp()
				break  # one chirp a frame at most
		if typed != before:
			_show_text()
			if typed == text.length():
				finished.emit()
	wave.queue_redraw()
	_place()


func _place() -> void:
	panel.size = panel.get_combined_minimum_size()
	var ps := panel.size
	docked = false
	if speaker == null or camera == null or not is_instance_valid(speaker):
		anchor = Vector2(size.x * 0.5, size.y)
		panel.position = Vector2((size.x - ps.x) * 0.5, size.y - ps.y - EDGE)
		queue_redraw()
		return
	# a cinematic shot draws through its own camera: projected through the idle play camera, the ring hung over empty ground
	var cam: Camera3D = camera if camera.current or get_viewport().get_camera_3d() == null else get_viewport().get_camera_3d()
	var p := Hud.project(self, cam, speaker.global_position + Vector3.UP * head, EDGE)
	anchor = p.at
	docked = not p.on
	if docked:
		dir = p.dir
		panel.position = Hud.dock(self, dir, ps, EDGE + ARROW)  # room for the arrow on screen
	else:
		panel.position = Vector2(anchor.x - ps.x * 0.5, anchor.y - TAIL - ps.y)
		panel.position = panel.position.clamp(Vector2(EDGE, EDGE), size - ps - Vector2(EDGE, EDGE))
	queue_redraw()


## The thin line down to a ring on PIP or, docked, an arrow on the side that faces him.
func _draw() -> void:
	if not visible:
		return
	var r := Rect2(panel.position, panel.size)
	# the teal left edge (4 mockup px), inside the glass's rounded corner; drawn here, over the panel's nine-patch
	Hud.blit(self, "white", Rect2(r.position + Vector2(0, 3), Vector2(3, r.size.y - 6)), Hud.color("accent"))
	if speaker == null:
		return
	if docked:
		var edge := r.get_center() + dir * (minf(r.size.x / maxf(absf(dir.x), 1e-4), r.size.y / maxf(absf(dir.y), 1e-4)) * 0.5)
		var side := dir.orthogonal() * 12.0
		Hud.blit_at(self, "arrow", edge + dir * ARROW * 0.4, ARROW * 1.1, Hud.color("light"), dir.angle())
		return
	var top := Vector2(clampf(anchor.x, r.position.x + 12.0, r.end.x - 12.0), r.end.y)
	# the line down to PIP: an atlas bar turned along it, then a ring on him
	var v := anchor - top
	draw_set_transform(top, v.angle())
	Hud.blit(self, "white", Rect2(0, -1, v.length(), 2), Hud.color("hud-stroke"))
	draw_set_transform(Vector2.ZERO)
	Hud.blit_at(self, "ring", anchor, 11.0, Hud.color("light"))


## Five bars that bounce while PIP talks and rest low when he is quiet.
func _draw_wave() -> void:
	var h := wave.size.y
	for i in BARS:
		var k := 0.35 + 0.65 * absf(sin(_t * 9.0 + i * 1.7)) if typing() else 0.3 + 0.1 * (i % 2)
		var bh := maxf(2.0, h * k)
		Hud.blit(wave, "white", Rect2(i * 4.5, (h - bh) * 0.5, 2.0, bh), Hud.color("accent"))


func _play_chirp() -> void:
	chirps += 1
	_player.pitch_scale = randf_range(0.85, 1.25)
	_player.play()


## A 50 ms rising blip, made once: no file to license, and it plays in a web build's Sample mode.
static func _chirp() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.05)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += TAU * lerpf(1400.0, 2200.0, t) / rate
		var env := sin(PI * t)  # fades in and out, so it never clicks
		data.encode_s16(i * 2, int(sin(phase) * env * 0.5 * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s
