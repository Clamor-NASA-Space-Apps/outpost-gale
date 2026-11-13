extends TextureRect
## A HUD icon that draws its tint as the draw's own colour, not as the node's modulate: the 2D renderer batches draws
## from one texture only while their nodes' modulate is the same, so icons tinted by modulate cost a draw call each.
## Set `art` (an atlas region, ui/atlas.gd) and `tint`; the TextureRect's own texture stays empty.

var art: Texture2D:
	set(v):
		art = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()


func _draw() -> void:
	if art == null:
		return
	# keep aspect, centred (the old TextureRect stretch mode)
	var s := art.get_size()
	var k := minf(size.x / s.x, size.y / s.y)
	var r := Rect2((size - s * k) * 0.5, s * k)
	var at := art as AtlasTexture
	if at:
		draw_texture_rect_region(at.atlas, r, at.region, tint)
	else:
		draw_texture_rect(art, r, false, tint)
