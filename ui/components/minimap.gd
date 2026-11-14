extends VBoxContainer
## The minimap (design/mockups/hud.png, top right): a round disc of the base picture baked by tools/bake_minimap.gd
## that turns with the camera, so ahead is up; the hero's arrow in the middle, the objective (amber diamond) and PIP
## (teal dot) at their places, held on the rim when further than the disc shows; N on the rim where north is. Under
## it the area's name and the M key that opens the full map. A tap on the disc opens it too (signal pressed).
## Set `heading`, `hero` ({x, z, yaw}) and `marks` ({objective: Vector2 or null, pip: Vector2 or null}, world x, z).

signal pressed

const Hud := preload("res://ui/hud.gd")
const MAP := preload("res://ui/map/base.png")
const PICTURE_M := 400.0  # the picture's width in metres (tools/bake_minimap.gd HALF x 2)
const DISC := 157.0  # 236 mockup px
const SHOWS_M := 120.0  # metres across the disc: the whole base and its near pads

var heading := 0.0
var hero := {"x": 0.0, "z": 0.0, "yaw": 0.0}
var marks := {"objective": null, "pip": null}
var area := "Landing plain"
var touch := false:  # a touch screen shows "Tap" in place of the M key
	set(v):
		touch = v
		if key:
			key.visible = not v
			hint.text = "Tap for map" if v else "Map"
var disc := Control.new()
var key: Control
var hint: Label
var area_label: Label
var _mat := ShaderMaterial.new()


func _ready() -> void:
	add_theme_constant_override("separation", 5)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(DISC, DISC)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.tooltip_text = "Map"
	disc.mouse_filter = Control.MOUSE_FILTER_STOP
	disc.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			disc.accept_event()
			pressed.emit())
	var pic := ColorRect.new()  # the picture, drawn by the shader
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat.shader = load("res://ui/minimap.gdshader")
	_mat.set_shader_parameter("map", MAP)
	_mat.set_shader_parameter("span", SHOWS_M / PICTURE_M)
	_mat.set_shader_parameter("ground", Hud.color("surface-container"))
	_mat.set_shader_parameter("rim", Hud.color("hud-scrim-menu"))
	pic.material = _mat
	pic.set_meta("under", true)  # its own shader: one draw call, under the shapes (Hud.layer)
	disc.add_child(pic)
	var marks_layer := Control.new()  # over the picture: the ring, N, the markers and the hero
	marks_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks_layer.draw.connect(_draw_marks.bind(marks_layer))
	marks_layer.set_meta("shapes", true)
	disc.add_child(marks_layer)
	var north := Control.new()  # the N, in its own node so the font's words batch apart from the atlas shapes
	north.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	north.set_meta("text_font", "CompassNorth")
	north.draw.connect(_draw_north.bind(north))
	disc.add_child(north)
	add_child(disc)
	area_label = Hud.label(area, "CapInk")
	key = Hud.panel("HudKey", Hud.label("M", "KeyText"))
	key.set_meta("icon", true)
	hint = Hud.label("Map", "Cap")
	var row := Hud.row([area_label, key, hint], 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	touch = touch


func show_view(h: float, at: Dictionary, m: Dictionary, area_name: String) -> void:
	heading = h
	hero = at
	marks = m
	if area_name != area:
		area = area_name
		area_label.text = area
	_mat.set_shader_parameter("centre", Vector2(0.5 + hero.x / PICTURE_M, 0.5 + hero.z / PICTURE_M))
	_mat.set_shader_parameter("turn", deg_to_rad(heading))
	disc.get_child(1).queue_redraw()
	disc.get_child(2).queue_redraw()


## A world point (x, z) on the disc, relative to its centre, and whether it fits inside `r`.
func to_disc(p: Vector2, r: float) -> Vector2:
	var v := (p - Vector2(hero.x, hero.z)) * (DISC / SHOWS_M)
	v = v.rotated(-deg_to_rad(heading))
	return v.limit_length(r)


func _draw_marks(c: Control) -> void:
	var o := c.size * 0.5
	var r := DISC * 0.5
	Hud.blit_at(c, "disc_ring", o, 172.0 * (r - 1.0) / 78.5)  # the atlas ring is 78.5 px round in 172
	if marks.get("objective") != null:
		Hud.blit_at(c, "diamond", o + to_disc(marks.objective, r - 8.0), 11.0, Hud.color("primary"))
	if marks.get("pip") != null:
		Hud.blit_at(c, "dot", o + to_disc(marks.pip, r - 6.0), 8.0, Hud.color("accent"))
	if marks.get("mark") != null:
		Hud.blit_at(c, "ring", o + to_disc(marks.mark, r - 8.0), 12.0, Hud.color("light"))
	# the hero: an arrow at the middle, pointing where the hero faces against where the camera looks
	Hud.blit_at(c, "hero", o, 19.0, Hud.color("light"), deg_to_rad(float(hero.yaw) - heading))


func _draw_north(c: Control) -> void:
	var o := c.size * 0.5
	var f := get_theme_font("font", "CompassNorth")
	var fs := get_theme_font_size("font_size", "CompassNorth")
	var north := o + Vector2(0, -(DISC * 0.5 - 12.0)).rotated(-deg_to_rad(heading))
	var w := f.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	c.draw_string(f, north + Vector2(-w.x * 0.5, w.y * 0.3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Hud.color("primary"))
