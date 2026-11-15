extends "res://ui/hud_panel.gd"
## The status card (top left): the sol and the Mars clock, then the HUD's four bars, all one size: Power, Life
## support, Crew health and Suit air, named as PIP names them. Under Power its flow in words; under Crew health
## what is costing it ("Falling: Thirsty") or the suit's air time. Water, food and rest move Crew health and show
## there, in the Today list and in the base report: the HUD has at most four progress bars (Ravindu, 15 Nov 2026:
## "a kid cannot handle more than that").
## The card is one size for the whole game (15 Nov playtest: rows came and went, a reason replaced a name, and the
## card grew and shrank with the numbers): every line has its slot from the start, and the lines under the meters
## clip instead of pushing the card wider.

const Hud := preload("res://ui/hud.gd")
const Meter := preload("res://ui/components/meter.tscn")
# key, icon, tooltip, word
const METERS := [["power", "power", "Power", "Power"], ["life", "oxygen", "Life support", "Life support"],
	["health", "health", "Crew health", "Crew health"], ["air", "oxygen", "Suit air", "Suit air"]]
const DUSTY := 0.5  # suit_dust from which the dust mark shows
# px: the names and numbers (the theme's are 9 and 11). A phone's compass and stick leave the card no more room
# (tests/ui_test.gd _apart), so this is as big as four bars and their two lines go
const TEXT_PX := 13

@export var sol := 3
@export var sols := 30  # NASA's first Mars surface stay: 30 sols (workspace fact table, ICES-2023-265)
@export var time := "06:52"

var meters := {}  # power, life, health, air
var flow: Label  # under Power: "Draining -3.4 kW"
var note: Label  # under Crew health: "Falling: Thirsty", or the suit's air time
var hurting := ""  # what is costing health, "" for nothing
var suit_text := ""  # "5 h 00 min" while the suit's air runs down and the body rules are off
var body_on := false
var body := {}  # the hero's needs in percent (air, water, food, rest, dusty), {} while the rules do not run them
var dust: Control  # "Dusty!", beside the clock
var dusty := false
var sol_label: Label
var time_label: Label


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 252  # under a phone's 256 px beside its compass; the bars take what the words leave
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sol_label = Hud.label("%d" % sol, "SolNum")
	time_label = Hud.label(time, "HudNumDim")
	# "SOL", the number, the clock icon and the time all centred on one line (mockup .status .sol, align-items: center)
	dust = Hud.row([Hud.icon("storm", 12, "primary"), Hud.label("Dusty!", "Cap")], 4)
	var top := Hud.row([Hud.label("Sol", "Cap"), sol_label, Hud.spacer(), dust, Hud.icon("clock", 12, "on_surface_variant"), time_label], 6)
	top.name = "SolRow"
	var rows := Hud.col([top], 4)
	for m: Array in METERS:
		# a meter and the line under it sit tight, so the line reads as that meter's
		var pair := Hud.col([], 0)
		rows.add_child(pair)
		var n: Control = Meter.instantiate()
		n.name = m[2].replace(" ", "")
		n.icon_name = m[1]
		n.title = m[2]
		n.word = m[3]
		n.text_px = TEXT_PX
		pair.add_child(n)
		meters[m[0]] = n
		if m[0] == "power":
			flow = _line(pair)
		elif m[0] == "health":
			note = _line(pair)
	add_child(rows)
	# one or two digits take the same room, so the row never shifts when the sol reaches 10; and the words line up
	sol_label.custom_minimum_size.x = _wide(sol_label, "88")
	var w: float = meters.values().map(func(n: Control) -> float: return _wide(n.name_label, n.word)).max()
	for n: Control in meters.values():
		n.name_label.custom_minimum_size.x = w
	show_body({})
	_note()


## A small line under a meter. It clips, so its words can never push the card wider.
func _line(parent: Control) -> Label:
	var l := Hud.label("", "Cap")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.clip_text = true
	parent.add_child(l)
	return l


## What is costing health ("Thirsty"), on the line under Crew health and in the warning colour; "" clears it.
## The meter keeps its name.
func hurt(text: String) -> void:
	hurting = text
	_note()


func _note() -> void:
	note.text = "Falling: %s" % hurting if hurting else ("Suit air %s" % suit_text if suit_text else "Steady")
	if hurting:
		note.add_theme_color_override("font_color", Hud.color("primary"))
	else:
		note.remove_theme_color_override("font_color")


## The hero's body from the rules' state: the suit's air on the fourth bar (full unless the state says less), the
## dust mark, and the needs kept for the snapshot.
func show_body(s: Dictionary) -> void:
	body_on = bool(s.get("body", false))
	meters.air.value = roundi(100.0 * float(s.get("suit_air", 1.0)))
	dusty = body_on and float(s.get("suit_dust", 0.0)) >= DUSTY
	dust.modulate.a = 1.0 if dusty else 0.0  # faded, not hidden: the mark keeps its place in the row
	body = {"air": meters.air.value, "water": roundi(100.0 * float(s.get("body_water", 1.0))), "food": roundi(100.0 * float(s.get("body_food", 1.0))),
		"rest": roundi(100.0 * float(s.get("body_rest", 1.0))), "dusty": dusty} if body_on else {}


static func _wide(l: Label, text: String) -> float:
	return ceilf(l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)


## hour: the Mars clock (24 local hours a sol, the sky's time). suit_min below 0 shows no suit air time.
func show_time(s: int, hour: float, suit_min := -1.0) -> void:
	sol = s
	time = "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]
	sol_label.text = "%d" % s
	time_label.text = time
	suit_text = "%d h %02d min" % [int(suit_min) / 60, int(suit_min) % 60] if suit_min >= 0.0 else ""
	_note()
