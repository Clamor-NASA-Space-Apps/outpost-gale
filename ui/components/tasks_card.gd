extends "res://ui/hud_panel.gd"
## "Today" (design/mockups/hud.png): the sol's tasks, each a box and a line. Done: a teal box with a tick, the line
## struck through. Now: an amber box holding a small diamond, the same diamond as the waypoint it leads to. Next: an
## empty box. Shape tells them apart as well as colour (Kid UX). set_tasks([[text, state], ...]) rebuilds the rows.

const Hud := preload("res://ui/hud.gd")
const BOX := 12.0  # 18 mockup px

var tasks: Array = [["Morning check", "done"], ["Pick lettuce", "now"], ["Clean solar panels", "next"]]
var list: VBoxContainer


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	list = Hud.col([], 6)
	add_child(Hud.col([Hud.label("Today", "Cap"), list], 6))
	set_tasks(tasks)


func set_tasks(t: Array) -> void:
	tasks = t
	for c: Node in list.get_children():
		c.queue_free()
	for task: Array in t:
		var state: String = task[1]
		var box := Control.new()
		box.custom_minimum_size = Vector2(BOX, BOX)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.draw.connect(_draw_box.bind(box, state))
		var l := Hud.label(task[0], "HudTextDim" if state == "done" else "HudText", true)
		if state == "done":
			l.draw.connect(func() -> void:
				var w := minf(l.size.x, l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
				l.draw_line(Vector2(0, l.size.y * 0.55), Vector2(w, l.size.y * 0.55), Hud.color("on-surface-variant"), 1.0))
		list.add_child(Hud.row([box, l], 7))


func _draw_box(b: Control, state: String) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(3)
	s.set_border_width_all(1)
	s.draw_center = state == "done"
	s.bg_color = Hud.color("accent")
	s.border_color = Hud.color({"done": "accent", "now": "primary"}.get(state, "on-surface-variant"))
	if state == "now":
		s.shadow_color = Hud.color("hud-glow-amber")
		s.shadow_size = 5
	b.draw_style_box(s, r)
	var c := r.get_center()
	if state == "done":
		b.draw_polyline(PackedVector2Array([c + Vector2(-3.5, 0), c + Vector2(-1, 2.5), c + Vector2(3.5, -2.5)]), Hud.color("on-primary"), 1.5, true)
	elif state == "now":
		var d := 3.0
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), Hud.color("primary"))
