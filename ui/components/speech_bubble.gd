extends Control
## PIP's speech bubble: a full-rect overlay holding one panel. With a speaker (follow()) the panel sits above the
## speaker's head, projected to the screen each frame, with a tail down to it; when the speaker is off screen or behind
## the camera the panel docks at the nearest screen edge with an arrow toward him. Without one it rests at the bottom
## centre, like a subtitle. Text types in letter by letter with a short synthesised chirp every few letters, so it
## reads as his voice. Colours come from the HudPanel style in ui/theme.tres.

signal finished  # the line has been typed and read

const Hud := preload("res://ui/hud.gd")
const CHARS_PER_S := 30.0
const CHIRP_EVERY := 3  # letters per chirp
const HOLD_MIN_S := 2.5
const HOLD_S_PER_WORD := 0.4  # a slow young reader's pace, so the line stays up long enough
const MAX_W := 440.0
const TAIL := 26.0  # how far the panel floats above the point it speaks from
const EDGE := 12.0  # the gap the docked panel keeps from the screen edge
const ARROW := 30.0  # the docked arrow's length

var panel: PanelContainer
var label: Label
var speaker: Node3D
var camera: Camera3D
var head := 0.0  # metres from the speaker's origin to just above its top
var docked := false
var dir := Vector2.DOWN  # docked: which way the speaker is
var anchor := Vector2.ZERO  # in this control's space: the point the tail touches
var chirps := 0  # how many have played, for the tests
var _typed := 0.0
var _hold := 0.0
var _player := AudioStreamPlayer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = Hud.label("", "", true)
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # the layout holds while letters appear
	panel = Hud.panel("HudPanel", Hud.row([Hud.icon("pip", 34, "accent"), label], 12))
	panel.name = "Bubble"
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


func speak(text: String) -> void:
	label.text = text
	label.visible_characters = 0
	_typed = 0.0
	_hold = maxf(HOLD_MIN_S, text.split(" ", false).size() * HOLD_S_PER_WORD)
	var w := label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	panel.custom_minimum_size.x = clampf(w + 90.0, 160.0, MAX_W)  # 90: the icon, the gap and the panel's margins
	show()
	_place()  # in place on its first frame, not at the corner


func typing() -> bool:
	return visible and label.visible_characters < label.text.length()


func _process(delta: float) -> void:
	if not visible:
		return
	var n := label.text.length()
	if label.visible_characters < n:
		_typed += delta * CHARS_PER_S
		var before := label.visible_characters
		label.visible_characters = mini(int(_typed), n)
		for i in range(before, label.visible_characters):
			if label.text[i] != " " and i % CHIRP_EVERY == 0:
				_play_chirp()
				break  # one chirp a frame at most
	else:
		_hold -= delta
		if _hold <= 0.0:
			hide()
			finished.emit()
			return
	_place()


func _place() -> void:
	panel.size = panel.get_combined_minimum_size()
	var box := Rect2(Vector2.ZERO, size)
	var ps := panel.size
	docked = false
	if speaker == null or camera == null or not is_instance_valid(speaker):
		anchor = Vector2(size.x * 0.5, size.y)
		panel.position = Vector2((size.x - ps.x) * 0.5, size.y - ps.y)
		queue_redraw()
		return
	var world := speaker.global_position + Vector3.UP * head
	var local := camera.global_transform.affine_inverse() * world
	var to_view := get_global_transform_with_canvas().affine_inverse()
	if local.z < 0.0:
		anchor = to_view * camera.unproject_position(world)
	docked = local.z >= 0.0 or not box.grow(-EDGE).has_point(anchor)
	if docked:
		# toward him on the screen's plane. From behind the camera only his side counts, so the bubble docks at the
		# left or right edge's middle, clear of a phone's stick and buttons in the bottom corners
		if local.z < 0.0:
			dir = Vector2(local.x, -local.y).normalized()
		else:
			dir = Vector2(signf(local.x), 0.0) if absf(local.x) > 0.05 else Vector2.DOWN
		var c := size * 0.5
		var half := (size - ps) * 0.5 - Vector2(EDGE, EDGE) - dir.abs() * ARROW  # room for the arrow on screen
		var t := minf(half.x / maxf(absf(dir.x), 1e-4), half.y / maxf(absf(dir.y), 1e-4))
		panel.position = c + dir * t - ps * 0.5
	else:
		panel.position = Vector2(anchor.x - ps.x * 0.5, anchor.y - TAIL - ps.y)
		panel.position = panel.position.clamp(Vector2(EDGE, EDGE), size - ps - Vector2(EDGE, EDGE))
	queue_redraw()


## The tail (a wedge from the panel to the speaker) or, docked, an arrow on the panel's side that faces him.
func _draw() -> void:
	if not visible or speaker == null:
		return
	var style := panel.get_theme_stylebox("panel", "HudPanel") as StyleBoxFlat
	var r := Rect2(panel.position, panel.size)
	if docked:
		var c := r.get_center()
		var edge := c + dir * (minf(r.size.x / maxf(absf(dir.x), 1e-4), r.size.y / maxf(absf(dir.y), 1e-4)) * 0.5)
		var side := dir.orthogonal() * 16.0
		draw_colored_polygon(PackedVector2Array([edge + dir * ARROW, edge + side, edge - side]), style.border_color)
		return
	var base := Vector2(clampf(anchor.x, r.position.x + 20.0, r.end.x - 20.0), r.end.y - 2.0)
	var pts := PackedVector2Array([base + Vector2(-12, 0), base + Vector2(12, 0), anchor])
	draw_colored_polygon(pts, style.bg_color)
	draw_polyline(PackedVector2Array([pts[0], anchor, pts[1]]), style.border_color, 2.0, true)


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
