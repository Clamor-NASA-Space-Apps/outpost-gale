extends Control
## The handbook: a two-page spread of what the kid has found out so far (design/plans/mission-1.md section 3), in
## the settings menu's glass: the game shows through, dimmed (ui/settings.gd's scrim), and each part is a glass panel.
## Top left the path and the tab's title, top right four tabs (a "!" marks one with a page not read yet). The left
## page holds the picture; the right page the list of the tab's pages and a panel with the open page's words. The
## Mission log tab counts pages found and learned and lists the decisions made, newest last.
## It shows only what is found (Ravindu, 14 Nov 2026): a page not unlocked has no row and leaves no gap, a tab with
## no page yet is a locked category (its icon faint under a lock, not to be opened), and no count says how many
## pages there are. A tab opens the moment its first page is found; the Mission log is always open.
## Pages come from data/handbook.json. The HUD makes it with .new(), adds it full-rect and keeps it hidden; while it
## is open it takes Esc and the `handbook` action itself (close(), then `closed`). State lasts for the run.
## One layout for every screen (_fit): buttons stay a finger tall under the HUD's phone scale, the columns share
## the width, the picture goes when there is no room for it, and words that do not fit their panel scroll.
## API: design/plans/mission-1-contracts.md.

signal closed

const Hud := preload("res://ui/hud.gd")
const DATA := "res://data/handbook.json"
# Both in px of the 1280 x 720 scene (addons/forge/test.gd TARGET and EDGE), whatever scale the HUD draws at.
const TARGET := 96.0  # every button's height: a 48 dp finger on a phone held sideways
const EDGE := 60.0  # side margins: Android's back swipe starts within this of a side edge
const GAP := 14  # between the columns
const LOCK: Texture2D = preload("res://ui/handbook/lock.svg")

var tabs: Array = []  # [{id, title, icon}], as in the data file
var pages := {}  # id -> its page from the data file
var order: Array[String] = []  # page ids in file order: the order of every list
var _unlocked: Array[String] = []
var _seen: Array[String] = []  # unlocked pages the kid has opened
var _learned: Array[String] = []
var _decisions: Array = []  # [title, choice], oldest first
var _tab := "mars"
var _page := ""

var _path := Hud.label("", "Caption")
var _title := Hud.label("", "Title")
var _foot := Hud.label("", "Caption", true)  # the open page's source, a footnote under the spread
var _tab_buttons := {}  # tab id -> Button
var _marks := {}  # tab id -> its "!" tag
var _locks := {}  # tab id -> its lock sign, shown while the tab has no page
var _tab_icons := {}  # tab id -> its icon, faint while locked
var _rows := {}  # page id -> its Button in the list (the open tab's pages only)
var _picture := MarginContainer.new()  # the left page
var _scroll := ScrollContainer.new()
var _list := Hud.col([], 4)
var _text := MarginContainer.new()  # the right page's panel
var _text_scroll := ScrollContainer.new()  # round it: a narrow phone wraps the words past the panel's height
var _left: Control  # the picture's panel
var _shelf: Control  # the list's panel
var _margin := MarginContainer.new()
var _back := Button.new()
var _target := TARGET  # a button's height in this node's own px (_fit)


func _ready() -> void:
	theme = Hud.THEME  # also right when a test or a tool shows it alone
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	tabs = data.tabs
	for p: Dictionary in data.pages:
		pages[p.id] = p
		order.append(p.id)
	_build()
	resized.connect(_fit)
	hide()


## True when the page was not unlocked before. An id the data file does not hold is a typo in a beat: say so.
func unlock(id: String) -> bool:
	if not pages.has(id):
		push_warning("handbook: no page '%s' in %s" % [id, DATA])
		return false
	if id in _unlocked:
		return false
	_unlocked.append(id)
	_refresh()
	return true


## Stamps pages "Learned" (their check was passed). A learned page is also found.
func learned(ids: Array) -> void:
	for id: String in ids:
		if pages.has(id) and id not in _learned:
			_learned.append(id)
			if id not in _unlocked:
				_unlocked.append(id)
	_refresh()


## Opens on `page` (found on the spot if it was not: the game sends the kid there to read it), or with no page
## on the newest one not read yet, or where the kid left it.
func open(page := "") -> void:
	if pages.has(page):
		if page not in _unlocked:
			_unlocked.append(page)
	else:
		page = _page
		for id: String in _unlocked:
			if id not in _seen:
				page = id
	show()
	_fit()  # the HUD may have changed its scale since, without changing this node's size
	if pages.has(page):
		_tab = pages[page].tab
		_select(page)
	else:
		_show_tab(_tab if _is_open(_tab) else "log")


func close() -> void:
	if not visible:
		return
	var held := get_viewport().gui_get_focus_owner()
	if held and is_ancestor_of(held):
		held.release_focus()  # a hidden button that kept the focus would still take Space, the hop
	hide()
	closed.emit()


func title(id: String) -> String:
	return pages[id].title if pages.has(id) else id


## A row in the Mission log tab: what was asked and what the kid chose.
func log_decision(title_text: String, choice: String) -> void:
	_decisions.append([title_text, choice])
	_refresh()


## Pages found and not opened yet.
func unread() -> int:
	return _unlocked.filter(func(id: String) -> bool: return id not in _seen).size()


func state() -> Dictionary:
	return {"open": visible, "tab": _tab, "page": _page, "unlocked": _unlocked.duplicate(),
		"learned": _learned.duplicate(), "total": order.size()}


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	for a: StringName in [&"ui_cancel", &"handbook", &"settings"]:
		if InputMap.has_action(a) and e.is_action_pressed(a):
			close()
			get_viewport().set_input_as_handled()  # Esc closes the book, not the book and then the settings
			return


## True for a tab the kid can open: the Mission log, or a tab with a found page.
func _is_open(tab: String) -> bool:
	return tab == "log" or _in_tab(tab).any(func(p: String) -> bool: return p in _unlocked)


func _show_tab(id: String) -> void:
	if not _is_open(id):
		return
	_tab = id
	# the first page of the tab not read yet, else its first found page; none on the log tab
	var first := ""
	for p: String in _in_tab(id):
		if p in _unlocked and (first == "" or (first in _seen and p not in _seen)):
			first = p
	_select(first)


func _select(id: String) -> void:
	_page = id
	if id != "" and id not in _seen:
		_seen.append(id)
	_refresh()
	if is_visible_in_tree():
		var at: Button = _rows.get(id, _tab_buttons[_tab])
		at.grab_focus()  # keys and a gamepad start from the open page
		_reveal()


## Scrolls the list to the open page, over the next three frames: the new rows have no place until the deferred
## layout has run, and the scroll bar learns the new list's length only when the box next sorts or draws, so an
## early try stops short at the old length (measured: 40 px of 640). Another page may be open by then, so each try
## looks the row up again.
func _reveal() -> void:
	for i: int in 3:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if _rows.has(_page):
			_scroll.ensure_control_visible(_rows[_page])


func _in_tab(id: String) -> Array:
	return order.filter(func(p: String) -> bool: return pages[p].tab == id)


func _build() -> void:
	# The settings menu's scrim: the game stays in view, dimmed, and a click never reaches it.
	var scrim := ColorRect.new()
	scrim.color = Hud.color("hud-scrim-menu")
	scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scrim)
	for l: Label in [_path, _title, _foot]:
		Hud.edge(l)  # these sit on the scrim alone, over a bright sky: the HUD's dark edge round the letters

	var tab_row := Hud.row([], 8)
	for t: Dictionary in tabs:
		var b := _button(_show_tab.bind(t.id))
		# locked, it keeps the tab's own flat look (the theme gives a tab no disabled style, and a button's is a slab)
		b.add_theme_stylebox_override("disabled", Hud.THEME.get_stylebox("normal", "TabButton"))
		var art := CenterContainer.new()
		art.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		art.mouse_filter = MOUSE_FILTER_IGNORE
		_tab_icons[t.id] = Hud.icon(t.icon, 44, "on_surface")
		art.add_child(_tab_icons[t.id])
		b.add_child(art)
		_marks[t.id] = _corner(b, Hud.tag("Tag", "", "!"))
		var lock := Hud.icon("close", 30, "on_surface")
		lock.art = LOCK  # this screen's own sign, not in the HUD's atlas (ui/icons is the HUD lane's)
		_locks[t.id] = _corner(b, lock)
		_tab_buttons[t.id] = b
		tab_row.add_child(b)
	var names := Hud.col([_path, _title], 0)
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER

	for sc: ScrollContainer in [_scroll, _text_scroll]:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_text.size_flags_vertical = SIZE_EXPAND_FILL  # at least the panel's height, so a lone line can sit in its middle
	_text_scroll.add_child(_text)
	# The caption under a photo wraps, and a wrapped label asks for a tower of height until it knows its width: the
	# whole screen jumped for a frame or two and Back left it (tests/handbook_test.gd). A scroll box asks its
	# parent for no height, so the left page sits in one that never shows a bar.
	var frame := ScrollContainer.new()
	frame.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	_picture.size_flags_horizontal = SIZE_EXPAND_FILL
	_picture.size_flags_vertical = SIZE_EXPAND_FILL
	frame.add_child(_picture)
	# every part on the menu's glass (hud-glass-menu), so its words read over any sky
	_left = Hud.panel("HudPanelSoft", frame)
	_shelf = Hud.panel("HudPanelSoft", _scroll)
	var right := Hud.panel("HudMenu", _text_scroll)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	var body := Hud.row([_left, _shelf, right], GAP)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	var tab_bar := Hud.panel("HudPanelSoft", tab_row)
	tab_bar.size_flags_vertical = SIZE_SHRINK_CENTER

	_back.text = "Back"
	_back.pressed.connect(close)

	_margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_margin.add_child(Hud.col([Hud.row([names, tab_bar], 16), body, Hud.row([_foot, _back], 16)], 12))
	add_child(_margin)


## Sizes for this screen. The HUD draws itself larger on a phone (Hud.PHONE_SCALE), so a finger's height and the
## swipe margin are fewer of this node's px there; the list takes a fifth of the width, the picture about half of
## what is left, and on a screen too narrow for a picture worth looking at (a tablet) the words get its room.
func _fit() -> void:
	if not is_inside_tree():
		return
	var k := get_global_transform().get_scale().y
	_target = ceilf(TARGET / k)
	var edge := ceilf(EDGE / k)
	for side: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + side, int(edge))
	for side: String in ["top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, int(24 / k))
	for b: Button in _tab_buttons.values():
		b.custom_minimum_size = Vector2(_target, _target)
	for b: Button in _rows.values():
		b.custom_minimum_size.y = _target
	_back.custom_minimum_size = Vector2(_target * 2.3, _target)
	_shelf.custom_minimum_size.x = clampf(size.x * 0.22, 210.0, 280.0)
	var picture := minf((size.x - 2.0 * edge - _shelf.custom_minimum_size.x - 2.0 * GAP) * 0.52, 450.0)
	_left.custom_minimum_size.x = picture
	_left.visible = picture >= 220.0


## What changes with the state: the title, the "!" marks, the list, and both pages. Nothing is drawn while it is
## hidden (a page unlocks in the middle of play); open() draws it.
func _refresh() -> void:
	if not visible or _tab_buttons.is_empty():
		return
	if not _is_open(_tab):  # nothing found yet in the tab it starts on: the log is always open
		_tab = "log"
		_page = ""
	var tab_title := ""
	for t: Dictionary in tabs:
		var b: Button = _tab_buttons[t.id]
		var open_tab := _is_open(t.id)
		b.disabled = not open_tab
		b.focus_mode = FOCUS_ALL if open_tab else FOCUS_NONE
		b.tooltip_text = t.title if open_tab else "Locked"
		(_tab_icons[t.id] as CanvasItem).set("tint", Hud.color("on_surface" if open_tab else "hud-ink-ghost"))
		(_locks[t.id] as Control).visible = not open_tab
		(_marks[t.id] as Control).visible = _in_tab(t.id).any(func(p: String) -> bool: return p in _unlocked and p not in _seen)
		b.set_pressed_no_signal(t.id == _tab)
		if t.id == _tab:
			tab_title = t.title
	_path.text = "HANDBOOK / " + tab_title.to_upper()
	_title.text = tab_title
	_foot.text = ""

	_clear(_list)
	_rows.clear()
	for id: String in _in_tab(_tab):
		if id not in _unlocked:
			continue  # no row, no gap: nothing says there is more to find
		var b := _button(_select.bind(id))
		b.custom_minimum_size.y = _target
		b.text = pages[id].title
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.mouse_filter = MOUSE_FILTER_PASS  # a finger dragging on a row scrolls the list
		b.add_theme_font_size_override("font_size", Hud.THEME.get_font_size("font_size", "Caption"))
		b.add_theme_constant_override("icon_max_width", 30)
		b.set_pressed_no_signal(id == _page)
		b.icon = Hud.icon_texture(pages[id].get("icon", "science"))
		if id not in _seen:
			_corner(b, Hud.tag("Tag", "", "!"))
		elif id in _learned:
			_corner(b, Hud.icon("check", 22, "accent"))
		_rows[id] = b
		_list.add_child(b)
	_shelf.visible = _tab != "log"

	_clear(_picture)
	_clear(_text)
	if pages.has(_page):
		_picture.add_child(_art(pages[_page]))
		_text.add_child(_words(pages[_page]))
		_foot.text = "Source: " + pages[_page].source
	elif _unlocked.is_empty() and _decisions.is_empty():  # the first look, before anything is learned
		_picture.add_child(_stand_in("pip", "Your handbook"))
		var hello := Hud.label("PIP will fill this as you learn.", "Heading", true)
		hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.add_child(hello)
	else:
		_picture.add_child(_counts())
		_text.add_child(_log())


## The left page: the page's photo over what it shows and whose it is (a space station photo is never passed off
## as our base), or the page's icon and title where there is no photo (never an empty hole).
func _art(p: Dictionary) -> Control:
	var tex: Texture2D = load(p.photo) if p.get("photo", "") != "" and ResourceLoader.exists(p.photo) else null
	if tex == null:
		return _stand_in(p.get("icon", "science"), p.title)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = SIZE_EXPAND_FILL
	r.mouse_filter = MOUSE_FILTER_IGNORE
	var caption := Hud.label("%s. Credit: %s" % [p.get("shows", p.title), p.credit], "Caption", true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return Hud.col([r, caption], 6)


func _stand_in(icon_name: String, words: String) -> Control:
	var caption := Hud.label(words, "Heading")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := CenterContainer.new()
	c.add_child(Hud.col([Hud.icon(icon_name, 144, "light"), caption], 16))
	return c


## The right page: title, lines and the kid version (the source is the footnote, the photo credit sits under it).
func _words(p: Dictionary) -> Control:
	var head: Array = [Hud.label(p.title, "Heading", true)]
	if p.id in _learned:
		head.append(Hud.tag("TagLive", "check", "Learned"))
	var box := Hud.col([Hud.row(head, 10)], 8)
	for line: String in p.lines:
		box.add_child(Hud.label(line, "", true))
	box.add_child(Hud.panel("HudPanelSoft", Hud.col([Hud.label("KID VERSION", "AccentText"), Hud.label(p.kid, "", true)], 0)))
	return box


## The Mission log's left page: how much of the handbook is found and learned.
func _counts() -> Control:
	var box := Hud.col([], 28)
	for c: Array in [["science", "Pages found", _unlocked.size()], ["check", "Pages learned", _learned.size()]]:
		var number := Hud.label(str(c[2]), "BigNumber")  # never "of 23": how many there are stays a secret
		box.add_child(Hud.row([Hud.icon(c[0], 44, "light"), Hud.col([Hud.label(c[1], "Heading"), number], 0)], 16))
	var centre := CenterContainer.new()
	centre.add_child(box)
	return centre


## The Mission log's right page: each decision and what was chosen, newest last (the panel scrolls past six or so).
func _log() -> Control:
	var box := Hud.col([Hud.label("Your decisions", "Heading")], 12)
	if _decisions.is_empty():
		box.add_child(Hud.label("No decisions yet. Each choice you make is written here.", "", true))
	for i: int in _decisions.size():
		var number := Hud.label(str(i + 1), "SmallNumber")
		number.custom_minimum_size.x = 28
		number.size_flags_vertical = SIZE_SHRINK_BEGIN
		var words := Hud.col([Hud.label(_decisions[i][0], "Caption", true), Hud.label(_decisions[i][1], "", true)], 0)
		words.size_flags_horizontal = SIZE_EXPAND_FILL
		box.add_child(Hud.row([number, words], 10))
	return box


## A tab or a list row: a switch that looks open while its page is (the theme's TabButton).
func _button(on: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "TabButton"
	b.toggle_mode = true
	b.pressed.connect(on)
	return b


## A small sign in a button's top right corner ("!" for not read, a tick for learned). It grows left and down from
## the corner, whatever size the theme gives it once it is in the tree.
func _corner(b: Button, mark: Control) -> Control:
	mark.mouse_filter = MOUSE_FILTER_IGNORE
	mark.anchor_left = 1.0
	mark.anchor_right = 1.0
	mark.grow_horizontal = GROW_DIRECTION_BEGIN
	for side: String in ["left", "right"]:
		mark.set("offset_" + side, -4.0)
	for side: String in ["top", "bottom"]:
		mark.set("offset_" + side, 4.0)
	b.add_child(mark)
	return mark


func _clear(n: Node) -> void:
	for c: Node in n.get_children():
		n.remove_child(c)
		c.queue_free()
