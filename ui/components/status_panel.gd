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
	custom_minimum_size.x = 200  # 300 mockup px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sol_label = Hud.label("%d" % sol, "SolNum")
	sol_label.tooltip_text = "Sol %d of %d" % [sol, sols]
	time_label = Hud.label(time, "HudNumDim")
	var body := Hud.col([Hud.row([Hud.label("Sol", "Cap"), sol_label, Hud.spacer(), Hud.icon("clock", 12, "on_surface_variant"), time_label], 6)], 7)
	for m: Array in [["power", "power", "Power"], ["life", "oxygen", "Life support"], ["health", "health", "Crew health"]]:
		var n: Control = Meter.instantiate()
		n.name = m[2].replace(" ", "")
		n.icon_name = m[1]
		n.title = m[2]
		body.add_child(n)
		meters[m[0]] = n
	suit_label = Hud.label("", "HudNumDim")
	suit = Hud.row([Hud.label("Suit air", "Cap"), Hud.spacer(), suit_label], 6)
	suit.visible = false
	body.add_child(suit)
	add_child(body)


## hour: the sim's clock (Earth hours through the sol). suit_min below 0 hides the suit air.
func show_time(s: int, hour: float, suit_min := -1.0) -> void:
	sol = s
	time = "%02d:%02d" % [int(hour) % 24, int(fposmod(hour, 1.0) * 60.0)]
	sol_label.text = "%d" % s
	time_label.text = time
	suit.visible = suit_min >= 0.0
	if suit.visible:
		suit_label.text = "%d h %02d min" % [int(suit_min) / 60, int(suit_min) % 60]
