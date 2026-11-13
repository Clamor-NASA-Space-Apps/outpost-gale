extends "res://ui/hud_panel.gd"
## The choice card: two or three options, each showing what it costs as an icon and an amount on a red tag
## (the brief: no free choice). Set `title`, `line` and `options` before it enters the tree.
## options: [{text, costs: {state key or icon: amount}}]; a cost key from Hud.KEYS gets its icon and unit.

signal chosen(index: int)

const Hud := preload("res://ui/hud.gd")

@export var icon_name := "radiation"
@export var title := "Solar storm warning!"
# NASA Orion: the crew build a storm shelter "within an hour" (factcheck row 35)
@export var line := "Build a shelter within an hour."
@export var width := 460.0
var options: Array = [
	{"text": "Hide in the shelter", "costs": {"science": -1}},
	{"text": "Keep working outside", "costs": {"dose_msv": 8, "health": -2}},
]
var buttons: Array[Button] = []


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = width
	var body := Hud.col([Hud.row([Hud.tag("TagDanger", icon_name, "", "OnFill", 30), Hud.label(title, "Heading", true)], 12)], 12)
	if line:
		body.add_child(Hud.label(line, "", true))
	for i in options.size():
		body.add_child(_choice(i, options[i]))
	add_child(body)


func _choice(i: int, o: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ChoiceButton"
	b.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
	var text := Hud.label(o.get("text", ""), "", true)
	var kids: Array = [text]
	var costs: Dictionary = o.get("costs", {})
	for k: String in costs:
		var icon: String = Hud.KEYS[k][0] if Hud.KEYS.has(k) else k
		kids.append(Hud.tag("TagDanger", icon, Hud.amount(k, costs[k])))
	var r := Hud.row(kids, 8)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 16)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	# a Button sizes to its own text, not its children: grow it when the wrapped choice needs a second line
	text.resized.connect(func() -> void:
		b.custom_minimum_size.y = maxf(Hud.BUTTON_H, r.get_combined_minimum_size().y + 24.0))
	b.pressed.connect(func() -> void: chosen.emit(i))
	buttons.append(b)
	return b
