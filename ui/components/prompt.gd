extends "res://ui/hud_panel.gd"
## The use prompt (design/mockups/hud.png, bottom right): the key in an amber chip and what it does. On a touch screen
## the chip shows the Use button's icon, since there is no E to press. say("") hides it.

const Hud := preload("res://ui/hud.gd")

var touch := false:
	set(v):
		touch = v
		if key:
			key.get_child(0).get_child(0).visible = not v
			key.get_child(0).get_child(1).visible = v
var key: PanelContainer
var line: Label


func _ready() -> void:
	theme_type_variation = "HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	key = Hud.panel("HudKeyAmber", Hud.row([Hud.label("E", "KeyAmber"), Hud.icon("use", 14, "primary")], 0))
	key.set_meta("icon", true)
	line = Hud.label("", "PromptText")
	add_child(Hud.row([key, line], 8))
	touch = touch
	hide()


func say(text: String) -> void:
	line.text = text
	visible = text != ""
