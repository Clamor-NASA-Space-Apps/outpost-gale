extends "res://ui/hud_panel.gd"
## "Ask Earth": a message on its way to mission control, with the radio delay as a countdown.
## Static mock: the countdown never ticks here (no timers before 14 Nov).

const Hud := preload("res://ui/hud.gd")

@export var wait := "20:00"
@export var progress := 0.0  # 0 = just sent, 1 = arrived

var track := Control.new()


func _ready() -> void:
	theme_type_variation = "HudPanel"
	track.custom_minimum_size = Vector2(150, 30)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.draw.connect(_draw_track)
	var path := Hud.row([Hud.icon("dish", 30, "accent"), track, Hud.icon("earth", 30, "on_surface")], 8)
	var count := Hud.row([Hud.label("Reaches Earth in", "Caption"), Hud.spacer(), Hud.label(wait, "Number")], 10)
	# workspace fact table: NASA, "a communication delay of up to 20 minutes one way" (factcheck row 13)
	var why := Hud.label("Radio takes up to 20 minutes, one way.", "Caption")
	add_child(Hud.col([Hud.row([Hud.tag("TagLive", "dish", ""), Hud.label("Ask Earth", "Heading")], 10), path, count, why], 6))


func _draw_track() -> void:
	var y := track.size.y * 0.5
	var dashes := 12
	var step := track.size.x / dashes
	for i in dashes:
		track.draw_line(Vector2(i * step + 2, y), Vector2(i * step + step * 0.55, y), Hud.color("outline-variant"), 3.0)
	# the message: a teal diamond, teal because it is live
	var x := clampf(progress, 0.0, 1.0) * (track.size.x - 16.0) + 8.0
	track.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 9), Vector2(x + 9, y), Vector2(x, y + 9), Vector2(x - 9, y)]), Hud.color("accent"))
