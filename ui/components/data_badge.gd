extends "res://ui/hud_panel.gd"
## Workspace rule 4: every data value says where it came from and when. LIVE means fetched now; ARCHIVED
## carries its date. The two differ in icon, word and fill, so colour is never the only signal.

const Hud := preload("res://ui/hud.gd")

@export var live := true
@export var source := "NOAA space weather"
@export var date := ""  # ARCHIVED only: the day the data was saved


func _ready() -> void:
	theme_type_variation = "HudPanel"
	var t := Hud.tag("TagLive", "live", "LIVE") if live else Hud.tag("TagArchive", "archive", "ARCHIVED", "TagText")
	add_child(Hud.row([t, Hud.label(source if live else date, "Caption")], 12))
