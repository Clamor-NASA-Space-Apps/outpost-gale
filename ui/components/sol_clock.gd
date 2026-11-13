extends "res://ui/hud_panel.gd"
## The sol counter, the Mars clock and the suit's air left. show_time() updates them in place.

const Hud := preload("res://ui/hud.gd")

@export var sol := 12
@export var sols := 30  # NASA's first Mars surface stay: 30 sols (workspace fact table, ICES-2023-265)
@export var time := "14:05"

var sol_label: Label
var time_label: Label
var suit: PanelContainer  # hidden until the state carries suit air
var suit_label: Label


func _ready() -> void:
	theme_type_variation = "HudPanel"
	sol_label = Hud.label("%d" % sol, "BigNumber")
	time_label = Hud.label(time, "SmallNumber")
	var count := Hud.row([sol_label, Hud.label("of %d" % sols, "Caption")], 8)
	count.alignment = BoxContainer.ALIGNMENT_END
	var clock := Hud.row([Hud.icon("sun", 26), time_label], 6)
	suit_label = Hud.label("", "TagText")
	suit = Hud.panel("HudPanelSoft", Hud.row([Hud.icon("oxygen", 22, "accent"), Hud.label("Suit", "Caption"), suit_label], 6))
	suit.visible = false
	var top := Hud.row([Hud.col([Hud.label("Sol", "Caption"), count], 0), Hud.col([Hud.spacer(), clock], 0)], 22)
	add_child(Hud.col([top, suit], 6))


## hour: 0 to 24 on the Mars clock. suit_min below 0 hides the suit air.
func show_time(s: int, hour: float, suit_min := -1.0) -> void:
	sol = s
	time = "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]
	sol_label.text = "%d" % s
	time_label.text = time
	suit.visible = suit_min >= 0.0
	if suit.visible:
		suit_label.text = "%d h %02d min" % [int(suit_min) / 60, int(suit_min) % 60]
