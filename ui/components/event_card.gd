extends "res://ui/hud_panel.gd"
## The choice card: two or three options, each showing what it gains and loses as two short rows, a plus and a minus
## sign with the words (the brief: no free choice; signs, never colour alone). Set `title`, `line` and `options`
## before it enters the tree. options: [{text, gain, lose, costs: {state key or icon: amount}}]; `costs` is the older
## way, an icon and an amount on a red tag (a key from Hud.KEYS gets its icon and unit).
## A check is the same card: `order` holds, for each row shown, the index the caller knows the option by, and
## `chosen` sends that index. `book_button` true adds a Handbook button under the options (signal handbook).

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


func _ready() -> void:
	theme_type_variation = "HudMenu"
	custom_minimum_size.x = width
	var body := Hud.col([Hud.row([Hud.tag(tag, icon_name, "", "OnFill", 30), Hud.label(title, "Heading", true)], 12)], 12)
	if line:
		body.add_child(Hud.label(line, "", true))
	for i in options.size():
		body.add_child(_choice(i, options[i]))
	if book_button:
		book = Button.new()
		book.name = "Book"
		book.text = "Handbook"
		book.theme_type_variation = "ChoiceButton"
		book.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
		book.pressed.connect(func() -> void: handbook.emit())
		body.add_child(book)
	add_child(body)


func _choice(i: int, o: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ChoiceButton"
	b.custom_minimum_size = Vector2(0, Hud.BUTTON_H)
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
