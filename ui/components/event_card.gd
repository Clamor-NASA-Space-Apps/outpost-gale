extends "res://ui/hud_panel.gd"
## An event with two choices. Every choice shows what it costs, as an icon and a number on a red tag
## (the brief: no free choice). Mock copy only: events and their costs are game rules, built on 14 Nov.

const Hud := preload("res://ui/hud.gd")

@export var icon_name := "radiation"
@export var title := "Solar storm warning!"
# NASA Orion: the crew build a storm shelter "within an hour" (factcheck row 35)
@export var line := "Build a shelter within an hour."
# [text, [[cost icon, amount], ...]]
var choices: Array = [
	["Hide in the shelter", [["science", -1]]],
	["Keep working outside", [["health", -2]]],
]
var buttons: Array[Button] = []


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 460
	var body := Hud.col([
		Hud.row([Hud.tag("TagDanger", icon_name, "", "OnFill", 30), Hud.label(title, "Heading")], 12),
		Hud.label(line, "", true),
	], 12)
	for c: Array in choices:
		body.add_child(_choice(c[0], c[1]))
	add_child(body)


func _choice(text: String, costs: Array) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ChoiceButton"
	b.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
	var kids: Array = [Hud.label(text), Hud.spacer()]
	for cost: Array in costs:
		kids.append(Hud.tag("TagDanger", cost[0], "%d" % cost[1]))
	var r := Hud.row(kids, 8)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 16)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	buttons.append(b)
	return b
