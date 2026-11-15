extends "res://ui/hud_panel.gd"
## "Today" (design/mockups/hud.png): the sol's tasks, each a box and a line. Done: a teal box with a tick, the line
## struck through. Now: an amber box holding a small diamond, the same diamond as the waypoint it leads to. Next: an
## empty box. Urgent (a need of the hero or the base, on top): the alert mark, no box. Shape tells them apart as well
## as colour (Kid UX). set_tasks([[text, state], ...]) rebuilds the rows.

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
		box.set_meta("icon", true)  # Hud.row centres it on the line's capitals
		box.set_meta("shapes", true)
		box.draw.connect(_draw_box.bind(box, state))
		var l := Hud.label(task[0], "HudTextDim" if state == "done" else "HudText", true)
		var row := Hud.row([box, l], 7)
		if state == "done":
			# the strike over the words: its own node, drawn after all the text (meta "over", Hud.layer), so every
			# struck line in the HUD shares one draw call and no font's batch is broken
			var strike := Control.new()
			strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
			strike.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			strike.set_meta("over", true)
			strike.draw.connect(func() -> void:
				var w := minf(l.size.x, l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
				Hud.blit(strike, "white", Rect2(0, l.size.y * 0.55, w, 1.0), Hud.color("on-surface-variant")))
			l.add_child(strike)
			l.resized.connect(strike.queue_redraw)
		list.add_child(row)
	Hud.layer(list)


func _draw_box(b: Control, state: String) -> void:
	var r := Rect2(Vector2.ZERO, b.size).grow(2.0)  # the atlas box has a px of air round its 12 px square
	var c := b.size * 0.5
	if state == "urgent":
		Hud.blit(b, "glow_dot", r.grow(5.0), Hud.color("hud-glow-danger"))
		Hud.blit_at(b, "icon_alert", c, 16.0, Hud.color("danger"))
		return
	if state == "now":
		Hud.blit(b, "glow_dot", r.grow(5.0), Hud.color("hud-glow-amber"))
	if state == "done":
		Hud.blit(b, "box_fill", r, Hud.color("accent"))
		Hud.blit_at(b, "icon_check", c, 11.0, Hud.color("on-primary"))
	else:
		Hud.blit(b, "box_line", r, Hud.color("primary" if state == "now" else "on-surface-variant"))
	if state == "now":
		Hud.blit_at(b, "diamond", c, 7.0, Hud.color("primary"))
