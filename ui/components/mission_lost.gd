extends Control
## The mission-lost frame (PG: the crew is always safe) with the replay chain of what led there.
## Mock copy only: win and lose are game code, built on 14 Nov.

const Hud := preload("res://ui/hud.gd")
const Chain := preload("res://ui/components/replay_chain.tscn")

@export var line := "Everyone is safe. The base shut down."
var buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("surface", 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var again := Button.new()
	again.text = "Try again"
	again.icon = load("res://ui/icons/next.svg")
	again.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var log_button := Button.new()
	log_button.text = "Mission log"
	log_button.theme_type_variation = "ChoiceButton"
	for b: Button in [again, log_button]:
		b.custom_minimum_size = Vector2(240, Hud.BUTTON_H)
		buttons.append(b)
	var actions := Hud.row([log_button, again], 16)
	actions.alignment = BoxContainer.ALIGNMENT_END
	var chain: Control = Chain.instantiate()
	var body := Hud.col([
		Hud.row([Hud.tag("TagDanger", "alert", "", "OnFill", 36), Hud.label("Mission lost", "Title")], 14),
		Hud.label(line),
		Hud.label("What led here", "Caption"),
		chain,
		actions,
	], 16)
	var card := Hud.panel("HudPanelLost", body, true)
	card.custom_minimum_size.x = 820
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	add_child(center)
