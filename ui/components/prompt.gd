extends "res://ui/hud_panel.gd"
## The use prompt: the key in an amber chip and what it does, big, low in the middle of the screen (ui/game_hud.gd
## places it), so a kid reads it over the world and learns the key (15 Nov playtest: in the corner, small, the hold
## was missed). On a touch screen the chip shows the Use button's icon, since there is no E to press. say("") hides
## it. A target that needs a hold reads "Hold: ..." and a ring round the chip fills as the key stays down.

const Hud := preload("res://ui/hud.gd")
# The ring is dots from the HUD's atlas, not draw_arc: two arcs cost 7 draw calls here (measured, 15 Nov: the phone's
# play page went from 39 to 46, over tests/ui_test.gd MAX_DRAWS), and atlas dots batch with the icons for none
const RING_DOTS := 24
const RING_W := 5.0  # a dot: big enough to see fill from across the room
const KEY_PX := 22  # the key's letter, and PromptText's 13 px raised to read as an overlay (theme sizes stay for cards)
const TEXT_PX := 22

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
	var e := Hud.label("E", "KeyAmber")
	e.add_theme_font_size_override("font_size", KEY_PX)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var chip := Hud.row([e, Hud.icon("use", KEY_PX, "primary")], 0)
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	key = Hud.panel("HudKeyAmber", chip)
	key.custom_minimum_size = Vector2(KEY_PX * 1.6, KEY_PX * 1.6)
	ring.add_child(key)
	ring.set_meta("icon", true)
	ring.set_meta("shapes", true)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	line = Hud.label("", "PromptText")
	line.add_theme_font_size_override("font_size", TEXT_PX)
	add_child(Hud.row([ring, line], 12))
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
