extends "res://ui/hud_panel.gd"
## The choice card: two or three options, each showing what it gains and loses as two short rows, a plus and a minus
## sign with the words (the brief: no free choice; signs, never colour alone). Set `title`, `line` and `options`
## before it enters the tree. options: [{text, gain, lose, costs: {state key or icon: amount}}]; `costs` is the older
## way, an icon and an amount on a red tag (a key from Hud.KEYS gets its icon and unit).
## A check is the same card: `order` holds, for each row shown, the index the caller knows the option by, and
## `chosen` sends that index. `book_button` true adds a Handbook button under the options (signal handbook).
## The look is the play HUD's glass: the card is asked over the game with no scrim, so its panel is the status
## card's and the bubble's (HudPanel), and each option is a see-through row, not a second slab of menu glass laid on
## the first (that pair let 8% of the game through). The words keep the HUD's dark edge (Hud.layer).

signal chosen(index: int)
signal handbook

const Hud := preload("res://ui/hud.gd")

@export var icon_name := "radiation"
@export var title := "Solar storm warning!"
# NASA Orion: the crew build a storm shelter "within an hour" (factcheck row 35)
@export var line := "Build a shelter within an hour."
@export var width := 460.0
var options: Array = [
	{"text": "Hide in the shelter", "costs": {"science": -1}},
	{"text": "Keep working outside", "costs": {"dose_msv": 8, "health": -2}},
]
var tag := "TagDanger"  # the fill behind the title's icon
var order: Array = []  # row shown -> the caller's index; empty: the rows are in the caller's order
var book_button := false
var buttons: Array[Button] = []  # the options, in the order shown
var book: Button  # the Handbook button, or null
const PAD := 10  # round the card's parts, on top of the glass's own small margin
const BAR := 6  # the bar at the left edge of the row in focus
var outline: StyleBox  # the Handbook row: a faint stroke and no fill, so it is not a fourth answer
var plain: StyleBoxFlat  # an answer at rest: the same stroke round darker glass
var lit: StyleBoxFlat  # the row in focus or under the pointer: a teal tint, a bright stroke and the bar


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = width
	# the rows' two looks, from the theme's own parts (it has no glass row variation; the start screen builds its rows
	# the same way): the outline of a choice at rest, and for the row in focus a shape as well as a colour
	outline = Hud.THEME.get_stylebox("disabled", "ChoiceButton")
	plain = outline.duplicate() as StyleBoxFlat
	plain.bg_color = Hud.color("hud-scrim")
	lit = plain.duplicate() as StyleBoxFlat
	lit.bg_color = Hud.color("hud-seg-on")
	lit.border_color = Hud.color("accent")
	lit.border_width_left = BAR
	var rule := ColorRect.new()  # the question above it is the heading, the rows under it the answers
	rule.color = Hud.color("hud-stroke-faint")
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := Hud.col([Hud.row([Hud.tag(tag, icon_name, "", "OnFill", 30), Hud.label(title, "Heading", true)], 12), rule], 12)
	if line:
		body.add_child(Hud.label(line, "", true))
	for i in options.size():
		body.add_child(_choice(i, options[i]))
	if book_button:
		book = _row(outline)
		book.name = "Book"
		var l := Hud.label("Handbook")  # a label, not the button's text: it gets the dark edge
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		book.add_child(l)
		book.pressed.connect(func() -> void: handbook.emit())
		body.add_child(book)
	var pad := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, PAD)
	pad.add_child(body)
	add_child(pad)


## A glass row: a touch target, and the pointer moves the focus, so one row is ever marked.
func _row(rest: StyleBox = plain) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
	for st: String in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, rest)
	for st: String in ["hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, lit)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


## A sign at the end of the row the caller knows as `i` (a cross on a wrong answer): a shape, not a colour.
func mark(i: int, sign_icon := "close") -> void:
	var b := buttons[order.find(i) if order else i]
	if b.has_node("Row/Mark"):
		return
	var m := Hud.icon(sign_icon, 26, "on_surface")
	m.name = "Mark"
	b.get_node("Row").add_child(m)
	Hud.layer(b)


func _choice(i: int, o: Dictionary) -> Button:
	var b := _row()
	var words: Array = [Hud.label(o.get("text", ""), "", true)]
	for k: Array in [["gain", "+ "], ["lose", "- "]]:
		if o.get(k[0], ""):
			words.append(Hud.label(k[1] + o[k[0]], "BubbleText", true))  # the size of PIP's own words
	var text := Hud.col(words, 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kids: Array = [text]
	var costs: Dictionary = o.get("costs", {})
	for k: String in costs:
		var icon: String = Hud.KEYS[k][0] if Hud.KEYS.has(k) else k
		kids.append(Hud.tag("TagDanger", icon, Hud.amount(k, costs[k])))
	var r := Hud.row(kids, 8)
	r.name = "Row"
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 16)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	# a Button sizes to its own text, not its children: grow it when the wrapped words need more lines
	for l: Label in words:
		l.resized.connect(func() -> void:
			b.custom_minimum_size.y = maxf(Hud.BUTTON_H, r.get_combined_minimum_size().y + 24.0))
	b.pressed.connect(func() -> void: chosen.emit(order[i] if order else i))
	buttons.append(b)
	return b
