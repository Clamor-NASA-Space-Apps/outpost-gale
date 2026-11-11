extends ColorRect
## The visor overlay: put it over the 3D view and under the HUD panels. Colours from the theme.

const Hud := preload("res://ui/hud.gd")

@export var tint_name := "surface"
@export var rim_name := "primary"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/visor.gdshader")
	m.set_shader_parameter("tint", Hud.color(tint_name))
	m.set_shader_parameter("rim", Hud.color(rim_name))
	material = m
	resized.connect(func() -> void: m.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0)))
