extends Control
## The visor's two faint arcs (design/mockups/hud.html svg.arcs): one over the top under the compass, one low near the
## bottom with a small tab at its middle. Drawn on the 1920 x 1080 mockup's curves, scaled to the screen.

const Hud := preload("res://ui/hud.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var k := size / Vector2(1920, 1080)
	_arc(Vector2(430, 128) * k, Vector2(960, 70) * k, Vector2(1490, 128) * k, Hud.color("hud-arc"))
	_arc(Vector2(120, 960) * k, Vector2(960, 1040) * k, Vector2(1800, 960) * k, Hud.color("hud-arc-faint"))
	var tab := PackedVector2Array([Vector2(930, 1001), Vector2(990, 1001), Vector2(982, 1010), Vector2(938, 1010)])
	for i in tab.size():
		tab[i] *= k
	draw_colored_polygon(tab, Hud.color("hud-stroke"))


## A quadratic curve from a to c bent toward b, as the mockup's SVG Q path.
func _arc(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	draw_polyline(pts, col, 1.0, true)
