extends Control
## The sleep picker: two cards, "Night" (ends at the fixed wake call) and "Nap 20 min" (design/plans/next-lanes.md
## section 3, decided 13 Nov). Each card leads with a drawn icon (a moon, a clock with a 20 minute wedge), so the
## shape tells them apart and colour is never the only signal. Not wired into play: sleeping is game code (14 Nov).
## Arrows move focus, ui_accept picks, ui_cancel or "Not now" closes; taps and clicks press the cards.

signal chosen(kind: StringName)
signal cancelled

const Hud := preload("res://ui/hud.gd")
const CARD := Vector2(200, 190)  # above the 96 px touch target in both layouts
const ICON := 96.0

var cards: Array[Button] = []
var not_now := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the scrim takes every click while the picker is open, so nothing behind it gets used by accident
	var scrim := ColorRect.new()
	scrim.color = Hud.color("scrim")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var row := Hud.row([_card(&"night", "Night", _draw_moon), _card(&"nap", "Nap 20 min", _draw_nap)], 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	not_now.text = "Not now"
	not_now.theme_type_variation = "ChoiceButton"
	not_now.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
	not_now.pressed.connect(_cancel)
	var title := Hud.row([Hud.icon("clock", 30, "accent"), Hud.label("Sleep how long?", "Heading")], 12)
	var card := Hud.panel("HudPanel", Hud.col([title, row, not_now], 16), true)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	add_child(center)
	# pinned by hand: the full-width "Not now" reaches right of Night, and the engine's geometric search took
	# it for Night's right neighbour, so Right jumped down instead of across
	var night := cards[0]
	var nap := cards[1]
	night.focus_neighbor_right = night.get_path_to(nap)
	nap.focus_neighbor_left = nap.get_path_to(night)
	for b: Button in cards:
		b.focus_neighbor_bottom = b.get_path_to(not_now)
	not_now.focus_neighbor_top = not_now.get_path_to(night)


func open() -> void:
	show()
	cards[0].grab_focus()


func close() -> void:
	hide()


func _card(kind: StringName, text: String, painter: Callable) -> Button:
	var b := Button.new()
	b.name = String(kind).capitalize()
	b.theme_type_variation = "ChoiceButton"
	b.custom_minimum_size = CARD
	var art := Control.new()
	art.custom_minimum_size = Vector2(ICON, ICON)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.draw.connect(painter.bind(art))
	var body := Hud.col([art, Hud.label(text, "Heading")], 10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	(body.get_child(1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 12)
	for n: Control in [body, art, body.get_child(1)]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the button under them takes the tap
	b.add_child(body)
	b.pressed.connect(_choose.bind(kind))
	cards.append(b)
	return b


func _choose(kind: StringName) -> void:
	close()
	chosen.emit(kind)


func _cancel() -> void:
	close()
	cancelled.emit()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


## A crescent: the outer circle's arc where a same-size circle shifted right does not cover it, back along that
## circle's own arc. Built as one polygon, so it needs no background colour to cut the bite out.
func _draw_moon(c: Control) -> void:
	var r := ICON * 0.4
	var o := c.size * 0.5
	var d := r * 0.75  # how far the biting circle sits to the right: smaller is a thinner moon
	var phi := acos(d / (2.0 * r))
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(o + Vector2.from_angle(lerpf(phi, TAU - phi, i / 24.0)) * r)
	for i in 25:
		pts.append(o + Vector2(d, 0) + Vector2.from_angle(lerpf(PI + phi, PI - phi, i / 24.0)) * r)
	c.draw_colored_polygon(pts, Hud.color("accent"))
	# two small stars, so "night" reads even to a kid who has not met a crescent yet
	for s: Vector3 in [Vector3(0.8, 0.24, 10.0), Vector3(0.9, 0.52, 7.0)]:
		_star(c, Vector2(s.x, s.y) * ICON, s.z)


func _star(c: Control, at: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * (k if i % 2 == 0 else k * 0.35))
	c.draw_colored_polygon(pts, Hud.color("on_surface"))


## A clock face with the 20 minutes filled as a wedge from twelve o'clock: a third of the dial.
func _draw_nap(c: Control) -> void:
	var r := ICON * 0.42
	var o := c.size * 0.5
	var wedge := PackedVector2Array([o])
	for i in 17:
		wedge.append(o + Vector2.from_angle(-PI / 2.0 + TAU / 3.0 * i / 16.0) * r)
	c.draw_colored_polygon(wedge, Hud.color("accent"))
	c.draw_arc(o, r, 0.0, TAU, 48, Hud.color("on_surface"), 4.0, true)
	for i in 12:
		var a := Vector2.from_angle(i * TAU / 12.0)
		c.draw_line(o + a * r * (0.72 if i % 3 == 0 else 0.84), o + a * r, Hud.color("on_surface"), 3.0)
	c.draw_circle(o, 4.0, Hud.color("on_surface"))
