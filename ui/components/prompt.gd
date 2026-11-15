extends "res://ui/hud_panel.gd"
## The use prompt (design/mockups/hud.png, bottom right): the key in an amber chip and what it does. On a touch screen
## the chip shows the Use button's icon, since there is no E to press. say("") hides it. A target that needs a hold
## reads "Hold: ..." and a ring round the chip fills as the key stays down.

const Hud := preload("res://ui/hud.gd")
# The ring is dots from the HUD's atlas, not draw_arc: two arcs cost 7 draw calls here (measured, 15 Nov: the phone's
# play page went from 39 to 46, over tests/ui_test.gd MAX_DRAWS), and atlas dots batch with the icons for none
const RING_DOTS := 24
const RING_W := 3.5  # a dot

var touch := false:
	set(v):
		touch = v
		if key:
			key.get_child(0).get_child(0).visible = not v
			key.get_child(0).get_child(1).visible = v
var key: PanelContainer
var line: Label
var text := ""  # the words as given, without "Hold"
var hold := -1.0  # 0 to 1: how far the hold is; -1 for a plain press
var ring := CenterContainer.new()  # holds the chip, and draws the ring round it


func _ready() -> void:
	theme_type_variation = "HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	key = Hud.panel("HudKeyAmber", Hud.row([Hud.label("E", "KeyAmber"), Hud.icon("use", 14, "primary")], 0))
	ring.add_child(key)
	ring.set_meta("icon", true)
	ring.set_meta("shapes", true)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	line = Hud.label("", "PromptText")
	add_child(Hud.row([ring, line], 8))
	touch = touch
	hide()


func say(words: String, held := -1.0) -> void:
	held = clampf(held, 0.0, 1.0) if held >= 0.0 else -1.0
	if words == text and held == hold:
		return  # the root says it every frame
	text = words
	hold = held
	line.text = ("Hold: " if hold >= 0.0 else "") + words
	visible = words != ""
	# the ring goes round the chip's corners, and the row makes room for it
	var d := ceilf(key.get_combined_minimum_size().length() + 2.0 * RING_W)
	ring.custom_minimum_size = Vector2(d, d) if hold >= 0.0 else Vector2.ZERO
	ring.queue_redraw()


func _draw_ring() -> void:
	if hold < 0.0:
		return
	var r := (minf(ring.size.x, ring.size.y) - RING_W) * 0.5
	for i in RING_DOTS:
		# clockwise from the top: a dot lights once the hold has passed it
		var at := ring.size * 0.5 + Vector2.from_angle(TAU * i / RING_DOTS - PI * 0.5) * r
		Hud.blit_at(ring, "dot", at, RING_W, Hud.color("primary" if float(i) / RING_DOTS < hold else "hud-track"))
