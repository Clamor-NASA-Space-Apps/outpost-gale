extends Control
## The end card. As it comes: the mission-lost frame (PG: the crew is always safe) with the replay chain of what led
## there. game_hud.show_report() fills the same card for a mission complete: a calm frame, its lines, the meters.
## Set `steps` (replay_chain.gd's shape) and the rest before it enters the tree; narrower than 600 px it stacks.

const Hud := preload("res://ui/hud.gd")
const Chain := preload("res://ui/components/replay_chain.tscn")
const Status := preload("res://ui/components/status_panel.gd")

signal retry  # the main button: "Try this sol again", or the report's "Keep going"
signal open_log  # the other one: "Mission log", or the report's "Play again"

@export var title := "Mission lost"
@export var line := "Everyone is safe. The base shut down."
@export var caption := "What led here"
@export var retry_label := "Try this sol again"
@export var log_label := "Mission log"
@export var lost := true  # false: the report, with no danger tag or frame, and no chain when it has no steps
@export var width := 820.0
var steps: Array = []  # empty keeps the chain's mock steps
var lines: Array = []  # more lines under `line`
var meters := {}  # {power, life, health} in percent: drawn as the HUD's meters
var buttons: Array[Button] = []
var card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("hud-scrim-strong")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var again := Button.new()
	again.text = retry_label
	again.icon = load("res://ui/icons/next.svg")
	again.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var log_button := Button.new()
	log_button.text = log_label
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
	var body := Hud.col([Hud.row([Hud.tag("TagDanger" if lost else "Tag", "alert" if lost else "check", "", "OnFill", 36), Hud.label(title, "Title", true)], 14)], 16)
	for t: String in [line] + lines:
		if t:
			body.add_child(Hud.label(t, "", true))
	if meters:
		var row := BoxContainer.new()
		row.vertical = narrow
		row.add_theme_constant_override("separation", 20)
		for m: Array in Status.METERS:
			var n: Control = Status.Meter.instantiate()
			n.icon_name = m[1]
			n.title = m[2]
			n.word = m[3]
			n.value = roundi(float(meters.get(m[0], 0)))
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(n)
		body.add_child(row)
	if lost or steps:
		var chain: Control = Chain.instantiate()
		chain.stacked = narrow
		if steps:
			chain.steps = steps
		body.add_child(Hud.label(caption, "Caption"))
		body.add_child(chain)
	body.add_child(actions)
	card = Hud.panel("HudPanelLost" if lost else "HudMenu", body)
	card.custom_minimum_size.x = width
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	add_child(center)
