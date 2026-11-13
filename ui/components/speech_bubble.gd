extends Control
## PIP's speech bubble (design/mockups/hud.png): glass with a teal left edge, "PIP" and a voice wave that moves while
## he talks, the line typed in letter by letter over its own faint copy, so the bubble never changes size. With a
## speaker (follow()) it floats above his head, projected each frame, with a thin line down to a ring on him; off
## screen or behind the camera it docks at the nearest edge with an arrow toward him. Without one it rests at the
## bottom centre, like a subtitle. A short synthesised chirp every few letters reads as his voice.

signal finished  # the line has been typed and read

const Hud := preload("res://ui/hud.gd")
const CHARS_PER_S := 30.0
const CHIRP_EVERY := 3  # letters per chirp
const HOLD_MIN_S := 2.5
const HOLD_S_PER_WORD := 0.4  # a slow young reader's pace, so the line stays up long enough
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
var text := ""
var typed := 0  # letters shown so far
var docked := false
var dir := Vector2.DOWN  # docked: which way the speaker is
var anchor := Vector2.ZERO  # in this control's space: the point the tail touches
var chirps := 0  # how many have played, for the tests
var _typed := 0.0
var _hold := 0.0
var _t := 0.0
var _player := AudioStreamPlayer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", get_theme_font("font", "BubbleText"))
	label.add_theme_font_size_override("normal_font_size", get_theme_font_size("font_size", "BubbleText"))
	label.add_theme_color_override("font_outline_color", get_theme_color("font_outline_color", "Label"))
	label.add_theme_constant_override("outline_size", get_theme_constant("outline_size", "Label"))
	wave.custom_minimum_size = Vector2(22, 12)
	wave.draw.connect(_draw_wave)
	var who := Hud.row([Hud.icon("pip", 15, "accent"), Hud.label("PIP", "CapLight"), Hud.spacer(), wave], 6)
	panel = Hud.panel("HudPanel", Hud.col([who, label], 4))
	panel.name = "Bubble"
	panel.custom_minimum_size.x = WIDTH
	panel.draw.connect(_draw_edge)
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


func speak(line: String) -> void:
	text = line
	typed = 0
	_typed = 0.0
	_hold = maxf(HOLD_MIN_S, line.split(" ", false).size() * HOLD_S_PER_WORD)
	_show_text()
	show()
	_place()  # in place on its first frame, not at the corner


func typing() -> bool:
	return visible and typed < text.length()


## The typed letters in ink, the rest as a faint copy: the layout is the whole line from the first letter.
func _show_text() -> void:
	label.clear()
	label.push_color(Hud.color("on-surface"))
	label.add_text(text.substr(0, typed))
	label.pop()
	label.push_color(Hud.color("hud-ink-ghost"))
	label.add_text(text.substr(typed))
	label.pop()


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
	else:
		_hold -= delta
		if _hold <= 0.0:
			hide()
			finished.emit()
			return
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
	var p := Hud.project(self, camera, speaker.global_position + Vector3.UP * head, EDGE)
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
	if not visible or speaker == null:
		return
	var r := Rect2(panel.position, panel.size)
	if docked:
		var edge := r.get_center() + dir * (minf(r.size.x / maxf(absf(dir.x), 1e-4), r.size.y / maxf(absf(dir.y), 1e-4)) * 0.5)
		var side := dir.orthogonal() * 12.0
		draw_colored_polygon(PackedVector2Array([edge + dir * ARROW * 0.8, edge + side, edge - side]), Hud.color("light"))
		return
	var top := Vector2(clampf(anchor.x, r.position.x + 12.0, r.end.x - 12.0), r.end.y)
	draw_line(top, anchor, Hud.color("hud-stroke"), 2.0, true)
	draw_arc(anchor, 4.0, 0.0, TAU, 16, Hud.color("light"), 1.5, true)


## The teal left edge (4 mockup px), inside the glass's rounded corner.
func _draw_edge() -> void:
	panel.draw_rect(Rect2(0, 3, 3, panel.size.y - 6), Hud.color("accent"))


## Five bars that bounce while PIP talks and rest low when he is quiet.
func _draw_wave() -> void:
	var h := wave.size.y
	for i in BARS:
		var k := 0.35 + 0.65 * absf(sin(_t * 9.0 + i * 1.7)) if typing() else 0.3 + 0.1 * (i % 2)
		var bh := maxf(2.0, h * k)
		wave.draw_rect(Rect2(i * 4.5, (h - bh) * 0.5, 2.0, bh), Hud.color("accent"))


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
