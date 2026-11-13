extends ColorRect
## The cover over the screen while shaders compile (sandbox._warm(), HouseStyle.warm()): a line and a bar driven by
## the warm-up's real progress, over the splash picture on the first load. The boot splash (native) and the web
## shell's loading screen (web/shell.html) show the same picture in the same place, so from the click to play the
## player sees one screen whose bar changes words. Without a warm-up it is a plain fade (the safety net's _flash()).

const Hud := preload("res://ui/hud.gd")

var picture := TextureRect.new()
var box := VBoxContainer.new()
var line := Label.new()
var bar := ProgressBar.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # a click while it is up is not a click on the world
	theme = Hud.THEME
	# the boot splash, drawn the way the engine draws it (stretch mode Keep: whole, centred), until the first warm-up
	picture.texture = load(ProjectSettings.get_setting("application/boot_splash/image"))
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	# low and centred, where the web shell draws its own bar
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -260
	box.offset_right = 260
	box.offset_bottom = -72
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	add_child(box)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 22)
	line.add_theme_color_override("font_outline_color", Hud.color("surface"))
	line.add_theme_constant_override("outline_size", 6)  # readable over the bright sky of the picture too
	box.add_child(line)
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false  # the line says it in words
	var track := StyleBoxFlat.new()
	track.bg_color = Hud.color("surface-container", 0.9)
	track.border_color = Hud.color("primary", 0.6)
	track.set_border_width_all(2)
	track.set_corner_radius_all(9)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Hud.color("primary")
	fill.set_corner_radius_all(9)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	if OS.has_feature("web"):
		# the shell's loading screen stays up until this cover is on the canvas: no black frame between them
		RenderingServer.frame_post_draw.connect(func() -> void: JavaScriptBridge.eval("window.shellDone && shellDone()", true), CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	box.modulate.a = color.a  # the fade tweens the cover's colour; the bar and picture go with it
	picture.modulate.a = color.a


## The warm-up's progress, 0 to 1 (HouseStyle.warm()'s `progress`).
func progress(v: float) -> void:
	box.visible = true
	bar.value = v * 100.0
	line.text = "Building the base... %d%%" % roundi(v * 100.0)


## The warm-up is over: the next cover is a plain one.
func finish() -> void:
	box.visible = false
	picture.visible = false
