extends "res://ui/hud_panel.gd"
## The status card (design/mockups/hud.png, top left): the sol and the Mars clock, then Power, Life support and Crew
## health as slim meters, Power's flow in words under it, what hurts in place of Health's name (hurt), the hero's
## own needs as a row of small gauges and the dusty suit's mark beside the clock (show_body), and the suit's air
## while it runs down. show_time() updates it in place. A phone has room for two more lines here and 20 px more
## width before the card meets the stick or the compass (tests/ui_test.gd _apart), so the gauges carry no words.

const Hud := preload("res://ui/hud.gd")
const Meter := preload("res://ui/components/meter.tscn")
# key, icon, tooltip, word. Life support is the shortest of air, water and food (game_hud.gd): "Supplies"
const METERS := [["power", "power", "Power", "Power"], ["life", "oxygen", "Life support", "Supplies"], ["health", "health", "Crew health", "Health"]]
const NEEDS := [["air", "oxygen", "Suit air", ""], ["water", "water", "Water", ""], ["food", "food", "Food", ""], ["rest", "clock", "Rest", ""]]
const LOW_NEED := 25  # percent: under it a need's gauge pulses and shows "!"
const DUSTY := 0.5  # suit_dust from which the dust mark shows

@export var sol := 3
@export var sols := 30  # NASA's first Mars surface stay: 30 sols (workspace fact table, ICES-2023-265)
@export var time := "06:52"

var meters := {}  # power, life, health
var flow: Label  # under Power: "Draining -3.4 kW"
var hurting := ""  # the words in place of Health's name, "" for none
var needs: Control  # the hero's body: suit air, water, food, rest; hidden until the rules run it
var gauges := {}  # air, water, food, rest
var dust: Control  # "Dusty!", beside the clock
var _word_w := 0.0  # the meters' words all take the widest one's room
var sol_label: Label
var time_label: Label
var suit: Control  # hidden until the state carries suit air that is running down
var suit_label: Label


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 236  # 300 mockup px, plus room for each meter's word
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sol_label = Hud.label("%d" % sol, "SolNum")
	time_label = Hud.label(time, "HudNumDim")
	# "SOL", the number, the clock icon and the time all centred on one line (mockup .status .sol, align-items: center)
	dust = Hud.row([Hud.icon("storm", 12, "primary"), Hud.label("Dusty!", "Cap")], 4)
	dust.hide()
	var top := Hud.row([Hud.label("Sol", "Cap"), sol_label, Hud.spacer(), dust, Hud.icon("clock", 12, "on_surface_variant"), time_label], 6)
	top.name = "SolRow"
	var body := Hud.col([top], 7)
	for m: Array in METERS:
		meters[m[0]] = _meter(m, body)
		if m[0] == "power":
			flow = Hud.label("", "Cap")
			flow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			body.add_child(flow)
	needs = Hud.row([], 10)
	needs.name = "Needs"
	for m: Array in NEEDS:
		var n := _meter(m, needs, true)
		n.low_below = LOW_NEED
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gauges[m[0]] = n
	needs.hide()
	body.add_child(needs)
	suit_label = Hud.label("", "HudNumDim")
	suit = Hud.row([Hud.label("Suit air", "Cap"), Hud.spacer(), suit_label], 6)
	suit.visible = false
	body.add_child(suit)
	add_child(body)
	# one or two digits take the same room, so the row never shifts when the sol reaches 10; and the words line up
	sol_label.custom_minimum_size.x = _wide(sol_label, "88")
	_word_w = meters.values().map(func(n: Control) -> float: return _wide(n.name_label, n.word)).max()
	hurt("")


func _meter(m: Array, parent: Control, compact := false) -> Control:
	var n: Control = Meter.instantiate()
	n.name = m[2].replace(" ", "")
	n.icon_name = m[1]
	n.title = m[2]
	n.word = m[3]
	n.compact = compact
	parent.add_child(n)
	return n


## What hurts ("Thirsty"), in place of Health's name and in the warning colour; "" puts the name back. The three
## words keep one width, so the bars stay in line under a long one.
func hurt(text: String) -> void:
	hurting = text
	var l: Label = meters.health.name_label
	l.text = text if text else meters.health.word
	if text:
		l.add_theme_color_override("font_color", Hud.color("primary"))
	else:
		l.remove_theme_color_override("font_color")
	for n: Control in meters.values():
		n.name_label.custom_minimum_size.x = maxf(_word_w, _wide(l, l.text))


## The hero's needs from the rules' state: hidden while its `body` is off. Suit air shows outside or when not full.
func show_body(s: Dictionary) -> void:
	needs.visible = bool(s.get("body", false))
	gauges.air.value = roundi(100.0 * float(s.get("suit_air", 1.0)))
	gauges.air.visible = bool(s.get("outside", false)) or gauges.air.value < 100
	for k: String in ["water", "food", "rest"]:
		gauges[k].value = roundi(100.0 * float(s.get("body_" + k, 1.0)))
	dust.visible = needs.visible and float(s.get("suit_dust", 0.0)) >= DUSTY


static func _wide(l: Label, text: String) -> float:
	return ceilf(l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)


## hour: the Mars clock (24 local hours a sol, the sky's time). suit_min below 0 hides the suit air.
func show_time(s: int, hour: float, suit_min := -1.0) -> void:
	sol = s
	time = "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]
	sol_label.text = "%d" % s
	time_label.text = time
	suit.visible = suit_min >= 0.0
	if suit.visible:
		suit_label.text = "%d h %02d min" % [int(suit_min) / 60, int(suit_min) % 60]
