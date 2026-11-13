extends Control
## The visor's two faint arcs (design/mockups/hud.html svg.arcs): one over the top under the compass, one low near the
## bottom with a small tab at its middle. Drawn on the 1920 x 1080 mockup's curves, scaled to the screen.

const Hud := preload("res://ui/hud.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("under", true)  # lines: its own draw call, under the panels (Hud.layer)
	resized.connect(queue_redraw)


## Both arcs and the tab as one list of short lines: one draw call.
func _draw() -> void:
	var k := size / Vector2(1920, 1080)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	_arc(pts, cols, Vector2(430, 128) * k, Vector2(960, 70) * k, Vector2(1490, 128) * k, Hud.color("hud-arc"))
	_arc(pts, cols, Vector2(120, 960) * k, Vector2(960, 1040) * k, Vector2(1800, 960) * k, Hud.color("hud-arc-faint"))
	# the tab under the low arc's middle: its trapezoid as rows of short lines, one px apart
	for y in range(1001, 1011):
		var t := (y - 1001) / 9.0
		pts.append(Vector2(lerpf(930, 938, t), y) * k)
		pts.append(Vector2(lerpf(990, 982, t), y) * k)
		cols.append(Hud.color("hud-stroke"))
	draw_multiline_colors(pts, cols)


## A quadratic curve from a to c bent toward b, as the mockup's SVG Q path, as line segments.
func _arc(pts: PackedVector2Array, cols: PackedColorArray, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var last := a
	for i in range(1, 33):
		var t := i / 32.0
		var p := a.lerp(b, t).lerp(b.lerp(c, t), t)
		pts.append(last)
		pts.append(p)
		cols.append(col)
		last = p
