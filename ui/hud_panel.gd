extends PanelContainer
## A HUD panel. The theme draws the glass (tint, stroke, glow). A flat style (the menus) gets its top highlight here, a
## faint line inside the top edge in the variation's "highlight" colour; the play HUD's nine-patches carry it baked in.


func _draw() -> void:
	var col := get_theme_color("highlight", theme_type_variation)
	if col.a <= 0.0 or get_theme_stylebox("panel") is StyleBoxTexture:
		return  # an atlas nine-patch has its highlight baked in (ui/atlas.gd)
	var r := float((get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left) if get_theme_stylebox("panel") is StyleBoxFlat else 0.0
	draw_line(Vector2(r, 1.5), Vector2(size.x - r, 1.5), col, 1.0)
