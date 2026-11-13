extends Control
## The mission-lost frame (PG: the crew is always safe) with the replay chain of what led there.
## Set `steps` (replay_chain.gd's shape) and `width` before it enters the tree; narrower than 600 px it stacks.

const Hud := preload("res://ui/hud.gd")
const Chain := preload("res://ui/components/replay_chain.tscn")

signal retry
signal open_log

@export var line := "Everyone is safe. The base shut down."
@export var width := 820.0
var steps: Array = []  # empty keeps the chain's mock steps
var buttons: Array[Button] = []
var card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("hud-scrim-strong")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var again := Button.new()
	again.text = "Try again"
	again.icon = load("res://ui/icons/next.svg")
	again.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var log_button := Button.new()
	log_button.text = "Mission log"
	log_button.theme_type_variation = "ChoiceButton"
	again.pressed.connect(func() -> void: retry.emit())
	log_button.pressed.connect(func() -> void: open_log.emit())
	var narrow := width < 600.0
	for b: Button in [again, log_button]:
		b.custom_minimum_size = Vector2(0 if narrow else 240, Hud.BUTTON_H)
		buttons.append(b)
	var actions := BoxContainer.new()  # an HBoxContainer cannot be turned upright
	actions.vertical = narrow
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 16)
	for b: Button in [log_button, again]:
		actions.add_child(b)
	var chain: Control = Chain.instantiate()
	chain.stacked = narrow
	if steps:
		chain.steps = steps
	var body := Hud.col([
		Hud.row([Hud.tag("TagDanger", "alert", "", "OnFill", 36), Hud.label("Mission lost", "Title", true)], 14),
		Hud.label(line, "", true),
		Hud.label("What led here", "Caption"),
		chain,
		actions,
	], 16)
	card = Hud.panel("HudPanelLost", body)
	card.custom_minimum_size.x = width
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	add_child(center)
