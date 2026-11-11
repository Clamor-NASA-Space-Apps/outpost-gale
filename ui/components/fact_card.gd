extends "res://ui/hud_panel.gd"
## A "Real NASA fact" card. Every line traces to research/junior-astronaut/factcheck.md, and the source
## line names it (workspace rule 3). Mock fact: factcheck row 37 (JPL, June 2024).

const Hud := preload("res://ui/hud.gd")

var lines: Array[String] = [
	"A solar storm hit Mars in May 2024.",
	"Near Curiosity: like 30 chest X-rays.",
	"Big, but not deadly.",
]
@export var source := "Source: NASA JPL, June 2024"
@export var date := "20 May 2024"


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 470
	var body := Hud.col([Hud.row([Hud.tag("Tag", "science", "", "OnFill", 30), Hud.label("Real NASA fact", "Heading")], 12)], 10)
	for l in lines:
		body.add_child(Hud.label(l, "", true))
	body.add_child(Hud.row([Hud.tag("TagArchive", "archive", "ARCHIVED", "TagText"), Hud.label(date, "Caption")], 10))
	body.add_child(Hud.label(source, "Caption"))
	add_child(body)
