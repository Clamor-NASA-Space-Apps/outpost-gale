extends "res://ui/hud_panel.gd"
## The status card (design/mockups/hud.png, top left): the sol and the Mars clock, then Power, Life support and Crew
## health as slim meters, and the suit's air while it runs down. show_time() updates it in place.

const Hud := preload("res://ui/hud.gd")
const Meter := preload("res://ui/components/meter.tscn")

@export var sol := 3
@export var sols := 30  # NASA's first Mars surface stay: 30 sols (workspace fact table, ICES-2023-265)
@export var time := "06:52"

var meters := {}  # power, life, health
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
	var top := Hud.row([Hud.label("Sol", "Cap"), sol_label, Hud.spacer(), Hud.icon("clock", 12, "on_surface_variant"), time_label], 6)
	top.name = "SolRow"
	var body := Hud.col([top], 7)
	# Life support is the shortest of air, water and food (game_hud.gd): "Supplies"; Crew health is the radiation dose
	for m: Array in [["power", "power", "Power", "Power"], ["life", "oxygen", "Life support", "Supplies"], ["health", "health", "Crew health", "Health"]]:
		var n: Control = Meter.instantiate()
		n.name = m[2].replace(" ", "")
		n.icon_name = m[1]
		n.title = m[2]
		n.word = m[3]
		body.add_child(n)
		meters[m[0]] = n
	suit_label = Hud.label("", "HudNumDim")
	suit = Hud.row([Hud.label("Suit air", "Cap"), Hud.spacer(), suit_label], 6)
	suit.visible = false
	body.add_child(suit)
	add_child(body)
	# one or two digits take the same room, so the row never shifts when the sol reaches 10; and the words line up
	sol_label.custom_minimum_size.x = _wide(sol_label, "88")
	var words: Array = meters.values().map(func(n: Control) -> float: return _wide(n.name_label, n.word))
	for n: Control in meters.values():
		n.name_label.custom_minimum_size.x = words.max()


static func _wide(l: Label, text: String) -> float:
	return ceilf(l.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)


## hour: the sim's clock (Earth hours through the sol). suit_min below 0 hides the suit air.
func show_time(s: int, hour: float, suit_min := -1.0) -> void:
	sol = s
	time = "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]
	sol_label.text = "%d" % s
	time_label.text = time
	suit.visible = suit_min >= 0.0
	if suit.visible:
		suit_label.text = "%d h %02d min" % [int(suit_min) / 60, int(suit_min) % 60]
