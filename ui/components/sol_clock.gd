extends "res://ui/hud_panel.gd"
## The sol counter and the Mars clock. Mock values only: the sol clock is game code, built on 14 Nov.

const Hud := preload("res://ui/hud.gd")

@export var sol := 12
@export var sols := 30  # NASA's first Mars surface stay: 30 sols (workspace fact table, ICES-2023-265)
@export var time := "14:05"


func _ready() -> void:
	theme_type_variation = "HudPanel"
	var count := Hud.row([Hud.label("%d" % sol, "BigNumber"), Hud.label("of %d" % sols, "Caption")], 8)
	count.alignment = BoxContainer.ALIGNMENT_END
	var clock := Hud.row([Hud.icon("sun", 26), Hud.label(time, "SmallNumber")], 6)
	add_child(Hud.row([Hud.col([Hud.label("Sol", "Caption"), count], 0), Hud.col([Hud.spacer(), clock], 0)], 22))
