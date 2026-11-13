extends PanelContainer
## A HUD panel. The theme draws the glass (tint, stroke, glow); this adds the top highlight, a faint line inside the
## top edge, in the variation's "highlight" colour (a flat style has one border colour, so it cannot carry it).


func _draw() -> void:
	var col := get_theme_color("highlight", theme_type_variation)
	if col.a <= 0.0:
		return
	var r := float((get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left) if get_theme_stylebox("panel") is StyleBoxFlat else 0.0
	draw_line(Vector2(r, 1.5), Vector2(size.x - r, 1.5), col, 1.0)
