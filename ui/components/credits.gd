extends Control
## The credits screen. Lines follow assets-cache/CREDITS.md and the workspace rules: AI use is said
## (rule 6), and nothing suggests NASA made or endorsed this (rule 5). Update with CREDITS.md.

const Hud := preload("res://ui/hud.gd")

var rows: Array = [
	["Data", "NASA, NOAA space weather"],
	["3D models", "Kenney (CC0), full list on project page"],
	["Fonts", "Exo 2 and Lexend (OFL)"],
	["Engine", "Godot Engine (MIT)"],
	["AI use", "Built with AI help, see project page"],
	["Our work", "Open source, Apache-2.0"],
]
var buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("scrim_full")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	for r: Array in rows:
		grid.add_child(Hud.label(r[0], "Caption"))
		grid.add_child(Hud.label(r[1]))
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, Hud.BUTTON_H)
	buttons.append(back)
	var foot := Hud.row([Hud.label("Not made or endorsed by NASA.", "Caption"), Hud.spacer(), back], 16)
	var card := Hud.panel("HudPanel", Hud.col([Hud.label("Credits", "Title"), grid, foot], 18), true)
	card.custom_minimum_size.x = 760
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(card)
	add_child(center)
