extends PanelContainer
## A HUD panel. The theme draws the box with two cut corners; this adds the visor display's corner
## brackets on the two square corners, in the panel variation's "bracket" colour.

@export var brackets := true

const ARM := 18.0
const GAP := 5.0
const WIDTH := 3.0


func _draw() -> void:
	if not brackets:
		return
	var col := get_theme_color("bracket", theme_type_variation)
	var r := Rect2(Vector2.ZERO, size).grow(GAP)
	var a := r.position
	var b := r.end
	draw_polyline([a + Vector2(0, ARM), a, a + Vector2(ARM, 0)], col, WIDTH)
	draw_polyline([b - Vector2(0, ARM), b, b - Vector2(ARM, 0)], col, WIDTH)
