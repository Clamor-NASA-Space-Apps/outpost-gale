extends "res://ui/hud_panel.gd"
## "Where this comes from": every number on screen with where it comes from (workspace rule 3), and each data
## value's LIVE, ARCHIVED or COMPUTED tag with its date (rule 4). Set `rows` before it enters the tree:
## [[icon, what, source, tag], ...], tag "" (a rule from a source), "live", "archived" or "computed".

signal closed

const Hud := preload("res://ui/hud.gd")
const TAGS := {
	"live": ["TagLive", "live", "LIVE", "OnFill"],
	"archived": ["TagArchive", "archive", "ARCHIVED", "TagText"],
	"computed": ["TagArchive", "clock", "COMPUTED", "TagText"],
}

@export var width := 560.0
@export var list_h := 320.0  # the rows scroll inside this height (a finger drags them on a phone)
var rows: Array = [
	["battery", "Battery 24%", "Sunlight 43% of Earth's: NASA fact sheet", ""],
	["oxygen", "Oxygen 50 kg", "0.84 kg each a day: NASA BVAD", ""],
	["dish", "Radio 11 min each way", "for 14 Nov 2026, JPL orbits", "computed"],
	["radiation", "Solar storm", "JPL: Curiosity RAD, 20 May 2024", "archived"],
]
var button := Button.new()


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = width
	var list := Hud.col([], 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = list_h
	scroll.add_child(list)
	var body := Hud.col([Hud.row([Hud.tag("Tag", "science", "", "OnFill", 30), Hud.label("Where this comes from", "Heading", true)], 12), scroll], 10)
	for r: Array in rows:
		var text := Hud.col([Hud.label(r[1], "", true), Hud.label(r[2], "Caption", true)], 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kids: Array = [Hud.icon(r[0], 28), text]
		if TAGS.has(r[3]):
			var t: Array = TAGS[r[3]]
			kids.append(Hud.tag(t[0], t[1], t[2], t[3]))
		list.add_child(Hud.row(kids, 10))
	button.text = "Got it"
	button.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
	button.pressed.connect(func() -> void: closed.emit())
	body.add_child(button)
	add_child(body)
