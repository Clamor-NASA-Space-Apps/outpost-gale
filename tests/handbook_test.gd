extends "res://addons/forge/test.gd"
## The handbook (ui/handbook.gd, data/handbook.json): the data file is sound, and the screen does what
## design/plans/mission-1-contracts.md says: unlock, "???" for a page not found, open on a page, the Learned stamp,
## the decision log, finger-sized buttons, close.
##   godot --headless --path . --fixed-fps 60 -s tests/handbook_test.gd

# the only ids a beat may name (the contracts)
const IDS := {
	"mars": ["light_on_mars", "thin_air", "weak_sun", "cold_nights", "dust", "solar_storms", "gale_lake"],
	"base": ["air_tanks", "air_maker", "garden", "seeds", "water", "solar_wings", "reactor", "oxygen_valve", "radio",
		"storm_shelter", "rover"],
	"explorers": ["pip", "mission_control", "opportunity", "insight", "curiosity"],
}


func play() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/handbook.json"))
	check(data.tabs.map(func(t: Dictionary) -> String: return t.id) == ["mars", "base", "explorers", "log"], "the four tabs, in order")
	for t: Dictionary in data.tabs:
		check(ResourceLoader.exists("res://ui/icons/%s.svg" % t.icon), "tab %s has an icon in ui/icons" % t.id)
	check(data.pages.size() == 23, "23 pages, found %d" % data.pages.size())
	for tab: String in IDS:
		var got: Array = data.pages.filter(func(p: Dictionary) -> bool: return p.tab == tab).map(func(p: Dictionary) -> String: return p.id)
		check(got == IDS[tab], "tab %s holds the contract's pages in order: %s" % [tab, got])
	for p: Dictionary in data.pages:
		var id: String = p.id
		check(p.title != "" and p.kid != "", id + " has a title and a kid line")
		check(p.lines.size() >= 1 and p.lines.size() <= 3 and "" not in p.lines, id + " has 1 to 3 lines")
		check("factcheck row" in p.source, id + " names its factcheck rows")
		check(ResourceLoader.exists("res://ui/icons/%s.svg" % p.get("icon", "")), id + " has an icon for its list row")
		check(p.photo == "" or ResourceLoader.exists(p.photo), id + ": its photo is imported: " + p.photo)
		check((p.photo == "") == (p.credit == ""), id + ": a photo and its credit come together")
		check("\u2014" not in JSON.stringify(p) and "\u2013" not in JSON.stringify(p), id + " has no long dash")

	var book: Control = load("res://ui/handbook.gd").new()
	root.add_child(book)
	await frames(2)
	check(not book.visible, "hidden until opened")
	check(book.unlock("air_tanks") == true, "a new page unlocks")
	check(book.unlock("air_tanks") == false, "the same page does not unlock twice")
	check(book.unread() == 1, "one page not read yet")
	check(book.title("air_tanks") == "Air in tanks", "title() gives the page's title")

	var closes := [0]
	book.closed.connect(func() -> void: closes[0] += 1)
	book.open("air_tanks")
	await frames(2)
	var s: Dictionary = book.state()
	check(s.open and s.tab == "base" and s.page == "air_tanks" and s.total == 23 and s.unlocked == ["air_tanks"],
		"open(id) shows that page on its tab: %s" % s)
	check(book.unread() == 0, "an opened page is read")
	check("Air in tanks" in _words(book) and data.pages[7].lines[0] in _words(book), "the page's title and lines are on screen")
	check((book._rows["air_tanks"] as Button).button_pressed, "the open page is marked in the list")
	var locked: Button = book._rows["air_maker"]
	check(locked.text == "???" and locked.disabled, "a page not found reads ??? and cannot be opened")
	check("The air maker" not in _words(book), "a page not found keeps its title to itself")

	check("Learned" not in _words(book), "no stamp before the check is passed")
	book.learned(["air_tanks"])
	await frames(2)
	check("Learned" in _words(book) and book.state().learned == ["air_tanks"], "learned() stamps the page")

	book.unlock("dust")
	await frames(2)
	check((book._marks["mars"] as Control).visible and not (book._marks["base"] as Control).visible,
		"a tab with a page not read shows its ! mark")

	book.log_decision("Power for one today", "Run the air maker")
	(book._tab_buttons["log"] as Button).pressed.emit()
	await frames(2)
	check(book.state().tab == "log", "the log tab opens")
	check("Run the air maker" in _words(book) and "Power for one today" in _words(book), "a decision shows in the log")
	check("2 of 23" in _words(book) and "1 of 23" in _words(book), "the log counts pages found and learned")

	for tab: String in ["log", "mars", "base", "explorers"]:
		(book._tab_buttons[tab] as Button).pressed.emit()
		await frames(2)
		for b: Button in book.find_children("*", "Button", true, false):
			if b.is_visible_in_tree():
				check(b.size.y >= TARGET, "%s tab: button '%s' is %d px tall, under %d" % [tab, b.text, b.size.y, TARGET])
		check(book.get_rect().encloses(book._back.get_global_rect()), "%s tab: Back stays on the screen" % tab)

	book.close()
	check(closes[0] == 1 and not book.visible and not book.state().open, "close() hides it and emits closed")
	book.close()
	check(closes[0] == 1, "closing a closed book emits nothing")

	book.unlock("radio")
	book.open()
	await frames(2)
	check(book.state().page == "radio" and book.state().tab == "base", "open() goes to the newest page not read")
	var radio: Dictionary = data.pages[15]
	check(("Source: " + radio.source) in _words(book), "the page's source is on screen")
	check(_words(book).any(func(w: String) -> bool: return w.begins_with(radio.shows) and w.ends_with(radio.credit)),
		"what the photo shows and whose it is are on screen")

	# on the laptop's screen every page's words fit their panel with no scrolling, and nothing is pushed off
	for p: Dictionary in data.pages:
		book.open(p.id)
		await frames(2)
		check(book._text.size.y <= book._text_scroll.size.y, "%s: its words fit the panel (%d px in %d)" % [p.id, book._text.size.y, book._text_scroll.size.y])
		check(book._picture.size.y <= book._left.size.y, "%s: its picture and caption fit the left page (%d px in %d)" % [p.id, book._picture.size.y, book._left.size.y])
		check(book.get_rect().encloses(book._back.get_global_rect()), "%s: Back stays on the screen: %s in %s" % [p.id, book._back.get_global_rect(), book.get_rect()])
	check(book.state().unlocked.size() == 23 and book.unread() == 0, "every page opened: all found, none unread")

	# keys and a gamepad: the focus starts on the open page, moves along the list, and Enter (or A) opens a page
	book.open("rover")
	await frames(3)
	check(root.gui_get_focus_owner() == book._rows["rover"], "the open page's row holds the focus")
	check(book._scroll.get_global_rect().encloses(book._rows["rover"].get_global_rect()), "the list scrolls to the open page, the last of eleven: row %s in %s" % [book._rows["rover"].get_global_rect(), book._scroll.get_global_rect()])
	_press(&"ui_up")
	await frames(2)
	check(root.gui_get_focus_owner() == book._rows["storm_shelter"], "up moves the focus to the page above")
	_press(&"ui_accept")
	await frames(2)
	check(book.state().page == "storm_shelter", "accept opens the focused page")
	book.open("curiosity")

	book.close()
	book.open()
	await frames(2)
	check(book.state().page == "curiosity", "open() with nothing new comes back where the kid left it")
	_press(&"ui_cancel")
	await frames(2)
	check(closes[0] == 3 and not book.visible, "Esc closes it")

	# In the HUD on a phone: drawn Hud.PHONE_SCALE larger in a box that much smaller (ui/game_hud.gd _fit). Buttons
	# stay a finger tall on the screen and everything stays on it, on a wide phone and on a 4:3 tablet.
	var Hud: Script = load("res://ui/hud.gd")
	var hud := Control.new()
	hud.scale = Vector2.ONE * Hud.PHONE_SCALE
	root.remove_child(book)
	hud.add_child(book)
	root.add_child(hud)
	for screen: Vector2 in [Vector2(1560, 720), Vector2(1280, 720), Vector2(960, 720)]:
		await shape(Vector2i(screen))
		hud.size = screen / Hud.PHONE_SCALE
		for id: String in ["radio", "gale_lake", "pip"]:
			book.open(id)
			await frames(3)
			var what := "%s at %d x %d on a phone" % [id, screen.x, screen.y]
			for b: Button in book.find_children("*", "Button", true, false):
				if b.is_visible_in_tree():
					check(b.get_global_rect().size.y >= TARGET, "%s: button '%s' is %d px tall on the screen" % [what, b.text, b.get_global_rect().size.y])
			check(Rect2(Vector2.ZERO, screen).encloses(book._back.get_global_rect()), "%s: Back stays on the screen" % what)
			check(book._text_scroll.get_global_rect().size.x >= 300, "%s: the words get %d px of width" % [what, book._text_scroll.get_global_rect().size.x])
			check(book._back.get_global_rect().end.x <= screen.x - EDGE and book._scroll.get_global_rect().position.x >= EDGE, "%s: nothing to press in the back swipe's edge" % what)
	return true


func _press(action: StringName) -> void:
	for down: bool in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)


## Every word on screen: labels and button texts.
func _words(book: Control) -> Array:
	var out := []
	for c: Control in book.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and (c is Label or c is Button):
			out.append(c.get("text"))
	return out
