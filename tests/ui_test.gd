extends "res://addons/forge/test.gd"
## The HUD kit's checks: godot --headless --path . -s tests/ui_test.gd
## Every page of ui/hud_gallery.tscn in both layouts: touch targets, text contrast, words per line (PIP's
## subtitles excepted), the alert's pulse rate, and the colour choke point (no colour literals in ui code).
## Then the play HUD alone: values bound from a fake sim update the meters, clock, mail and cards; every card fits
## a 360 px wide screen; the radio delay matches a known distance.

const Hud := preload("res://ui/hud.gd")
const MAX_WORDS := 8  # Kid UX: at most 8 words per card line
const MIN_CONTRAST := 4.5  # XAG 102 and WCAG 1.4.3 for text (design/research/sizes.md B)
const MAX_FLASHES := 3.0  # per second, Kid UX
const MAX_DRAWS := 40  # the play HUD's share of the A16's frame (the 3D base already takes about 150)
const NARROW := 360.0  # the narrowest phone width in dp a card must fit
const Delay := preload("res://ui/radio_delay.gd")
const Fake := preload("res://ui/fake_state.gd")
const MeterScript := preload("res://ui/components/meter.gd")


func _init() -> void:
	watchdog = 60.0  # the Today list's leave and the power gain's fade wait about 9 s of game time


func play() -> bool:
	# a phone-shaped window (2400 x 1080 is 1600 x 720 on the canvas), so the phone layout is drawn unshrunk
	await shape(SHAPES[1])
	var g: Control = load("res://ui/hud_gallery.tscn").instantiate()
	root.add_child(g)
	await frames(2)
	# the worst backdrops a see-through panel can sit on: the bright horizon haze and the dark shade
	var backdrops: Array[Color] = [Hud.color("horizon"), Hud.color("surface")]
	var buttons := 0
	var labels := 0
	for layout: String in ["laptop", "phone"]:
		for p: String in g.PAGES:
			g.set_view("%s_%s" % [layout, p])
			await frames(2)  # containers sort on the next frame
			var state: Dictionary = g.render_game_to_text()
			check(state.components.size() > 0, "%s_%s shows no component" % [layout, p])
			for n: Node in g.find_children("*", "Control", true, false):
				var c := n as Control
				if not c.is_visible_in_tree():
					continue
				var where := "%s_%s %s" % [layout, p, g.get_path_to(c)]
				if c is Button:
					buttons += 1
					var b := c as Button
					if layout == "phone":
						# measured on the phone's own canvas, not the shrunk preview inside the bezel
						var h: float = b.get_global_rect().size.y / g.screen.scale.y
						check(h >= TARGET, "%s is %.0f scene px tall, a touch target needs %.0f" % [where, h, TARGET])
					if b.text:
						var edge := b.get_theme_color("font_outline_color") if b.get_theme_constant("outline_size") >= 2 else Color.TRANSPARENT
						_contrast(b.get_theme_color("font_color"), b.get_theme_stylebox("normal"), backdrops, where, edge)
				elif c is HBoxContainer:
					_aligned(c as HBoxContainer, where)
				elif c is Label:
					labels += 1
					var l := c as Label
					var words := l.text.split(" ", false).size()
					check(words <= MAX_WORDS or "Bubble" in String(g.get_path_to(c)), "%s has %d words: '%s'" % [where, words, l.text])
					# text over the glass carries a dark edge (the theme's Label outline): it is measured against that edge
					# laid over the panel and the world, since the edge is what touches every letter
					var edge := l.get_theme_color("font_outline_color") if l.get_theme_constant("outline_size") >= 2 or l.has_node("Edge") else Color.TRANSPARENT
					var panel := _panel_of(l)
					var under := backdrops
					if check(panel != null or edge.a > 0.0, "%s sits on the bare world with no panel or edge behind it" % where):
						_contrast(l.get_theme_color("font_color"), panel, under, where, edge)
	check(buttons > 0, "the gallery has buttons")
	check(aligned > 0, "icon rows were measured")
	print("checked %d buttons and %d labels over %d views" % [buttons, labels, g.PAGES.size() * 2])
	var toast: Script = load("res://ui/components/alert_toast.gd")
	var pulse: float = toast.get_script_constant_map().PULSE_SECONDS
	check(1.0 / pulse <= MAX_FLASHES, "the alert pulses %.1f times a second" % (1.0 / pulse))
	pulse = (load("res://ui/components/meter.gd") as Script).get_script_constant_map().PULSE_SECONDS
	check(1.0 / pulse <= MAX_FLASHES, "a low gauge pulses %.1f times a second" % (1.0 / pulse))
	await _draws(g)
	await _apart(g)
	g.queue_free()
	await _bound()
	await _narrow()
	_delay()
	await _sleep_picker()
	_no_colour_literals("res://ui/")
	_no_colour_literals("res://ui/components/")
	_loading_tokens()
	await _mission()  # last: it registers the game's input actions (Tab)
	return true


## Mission 1's HUD (design/plans/mission-1-contracts.md): a highlighted line, the handbook on Tab and its "New page"
## note, a check answered wrong then right, and a decision card's gain and lose rows.
func _mission() -> void:
	preload("res://player/controls.gd").register(0.2)
	var tab := InputMap.action_get_events(&"handbook")
	check(tab.size() == 1 and (tab[0] as InputEventKey).physical_keycode == KEY_TAB, "the handbook action is Tab")
	var h: Control = load("res://ui/game_hud.tscn").instantiate()
	root.add_child(h)
	await frames(2)
	var b: Control = h.bubble
	var cues: Array[String] = []
	h.cue.connect(func(n: String) -> void: cues.append(n))
	# a highlight: *words* draw bold in the primary colour, and the asterisks show nowhere
	var plain := "Mars gets 43% of Earth's sunlight."
	h.lines["t.light"] = "Mars gets *43%* of Earth's sunlight."
	h.say("t.light")
	await process_frame
	await process_frame
	check(h.snapshot().subtitle == plain and h.line("t.light") == plain, "a highlighted line reads without asterisks: '%s'" % h.snapshot().subtitle)
	check(b.label.get_parsed_text() == plain and b.typed < plain.length(), "the whole line is laid out while it types (%d typed): '%s'" % [b.typed, b.label.get_parsed_text()])
	await create_timer(plain.length() / b.CHARS_PER_S + 0.3).timeout
	var marked: Array = b.pieces.filter(func(p: Array) -> bool: return p[2] != null)
	check(marked == [["43%", Hud.color("primary"), b.bold]], "the marked run is bold in the primary colour: %s" % [b.pieces])
	var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
	var normal: FontVariation = b.label.get_theme_font("normal_font")
	check(int((b.bold as FontVariation).variation_opentype[weight]) >= 700 and int(normal.variation_opentype[weight]) < 600, "bold is a heavier weight of the bubble's font")
	check(b.pieces.size() == 3 and b.pieces[0] == ["Mars gets ", Hud.color("on-surface"), null], "the rest of the line is plain ink: %s" % [b.pieces])
	h.say("follow_me")
	check(b.pieces.all(func(p: Array) -> bool: return p[2] == null), "a line with no asterisks has no bold run")
	h.clear_line()
	# a new page: a note and a cue once, the game never stops, and nothing for a page already there
	cues.clear()
	h.unlock_page("air_tanks")
	check(h.snapshot().note == "New page: " + h.handbook.title("air_tanks") and not h.is_open(), "a new page shows its note and stops nothing: '%s'" % h.snapshot().note)
	check(cues == ["mail"] and h.book_mark.visible == (h.handbook.unread() > 0), "the note plays one cue, and the book shows '!' while a page is unread: %s" % [cues])
	h.note.hide()
	h._cue_at.clear()
	h.unlock_page("air_tanks")
	check(h.snapshot().note == "" and cues == ["mail"], "a page already unlocked shows no second note: '%s' %s" % [h.snapshot().note, cues])
	h.unlock_page("garden")
	await create_timer(h.NOTE_S + 0.2).timeout
	check(h.snapshot().note == "", "the note leaves by itself")
	# Tab and the book button open and close the handbook, and is_open() follows
	for step: Array in [[&"handbook", true], [&"handbook", false], [&"", true], [&"ui_cancel", false]]:
		if step[0] == &"":
			h.book_button.pressed.emit()
		else:
			action(step[0])
			action(step[0], false)
		await process_frame
		await process_frame
		check(h.handbook.visible == step[1] and h.is_open() == step[1] and h.snapshot().handbook.open == step[1],
			"%s leaves the handbook %s (is_open %s)" % [step[0] if step[0] else &"the book button", "open" if step[1] else "closed", h.is_open()])
	# a check: the page first, then the card; wrong sends the kid back to the page, right stamps it, once
	var quiz := {"id": "t1", "q": "Where does our air come from?", "options": ["From Earth", "From *tanks*", "From the wind"], "right": 1, "pages": ["air_tanks", "garden"]}
	var done: Array = []
	h.checked.connect(func(id: String) -> void: done.append(id))
	h.offer_check(quiz)
	await frames(2)
	check(h.handbook.visible and h.snapshot().handbook.page == "air_tanks" and h.snapshot().check == "t1" and h.is_open(), "a check opens the handbook at its page first: %s" % [h.snapshot().handbook])
	h.handbook.close()
	await frames(2)
	var shown: Array = h.card.buttons.map(func(k: Button) -> String: return (k.find_children("*", "Label", true, false)[0] as Label).text)
	var want: Array = h.card.order.map(func(i: int) -> String: return String(quiz.options[i]).replace("*", ""))
	var sorted: Array = h.card.order.duplicate()
	sorted.sort()
	check(h.snapshot().card == "EventCard" and h.modal.visible and not h.handbook.visible and shown == want and sorted == [0, 1, 2],
		"the handbook closed, the check card shows its three options in the card's order: %s %s" % [shown, h.card.order])
	await _glass(h, "the check card")
	h.source_button.pressed.emit()
	check(h.snapshot().check == "t1" and h.snapshot().card == "EventCard", "the '?' leaves a question in place: %s" % h.snapshot().card)
	h.card.book.pressed.emit()
	await frames(2)
	check(h.handbook.visible and not h.modal.visible, "the card's Handbook button opens the handbook over it")
	h.handbook.close()
	await frames(2)
	h.card.buttons[h.card.order.find(0)].pressed.emit()  # wrong
	check(h.snapshot().subtitle == h.line("check.wrong") and done.is_empty() and h.is_open(), "a wrong answer: PIP says '%s', nothing is emitted" % h.snapshot().subtitle)
	var crossed: Array = h.card.buttons.filter(func(k: Button) -> bool: return k.has_node("Row/Mark"))
	check(crossed == [h.card.buttons[h.card.order.find(0)]], "the answer tried carries a cross, a sign and not a colour")
	await create_timer(h.WRONG_S + 0.2).timeout
	check(h.handbook.visible and h.snapshot().handbook.page == "air_tanks", "then the page opens again: %s" % [h.snapshot().handbook])
	h.handbook.close()
	await frames(2)
	check(h.modal.visible and h.snapshot().check == "t1" and not "air_tanks" in h.snapshot().handbook.learned, "and the card is back, nothing stamped yet")
	h.card.buttons[h.card.order.find(1)].pressed.emit()  # right
	await frames(2)
	var learned: Array = h.snapshot().handbook.learned
	check(done == ["t1"] and not h.is_open() and h.snapshot().check == "" and "air_tanks" in learned and "garden" in learned,
		"the right answer emits checked once, stamps its pages and closes: %s %s" % [done, learned])
	check(h._under().all(func(p: Control) -> bool: return p.modulate.a == 1.0), "the HUD under the card is back when it closes")
	# a decision: what each option gains and loses, with its sign, and a way to the handbook
	h.offer_choice("choice_power_morning", [{"text": "follow_me", "gain": "spare air", "lose": "the lettuce waits a day"},
		{"text": "Rest", "gain": "*more* power", "lose": "less air", "costs": {"battery_pct": -20}}], ["garden"])
	await frames(2)
	var rows: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("+ spare air" in rows and "- the lettuce waits a day" in rows and "+ more power" in rows and "-20 %" in rows, "a decision shows each gain and loss with its sign: %s" % [rows])
	check(h.card.buttons.all(func(k: Button) -> bool: return k.size.y >= Hud.BUTTON_H and k.get_global_rect().encloses((k.get_child(0) as Control).get_global_rect())),
		"each option holds its rows and stays a touch target")
	await _glass(h, "the decision card")
	h.card.book.pressed.emit()
	await frames(2)
	check(h.handbook.visible and h.snapshot().handbook.page == "garden" and h.is_open(), "its Handbook button opens the page: %s" % [h.snapshot().handbook])
	h.handbook.close()
	await frames(2)
	check(h.snapshot().card == "EventCard" and h.modal.visible, "and the decision is back when the handbook closes")
	h.offer_choice("choice_power_morning", [{"text": "A"}, {"text": "B"}])
	check(h.card.book == null or not h.card.book.is_inside_tree(), "a decision with no pages has no Handbook button")
	h.close_card()
	h.queue_free()
	await frames(1)


## In the play state no two HUD parts lie on each other, in either layout: the corner panels, the compass, the
## minimap, the gear's place and the "?", the mail, the prompt and the phone's touch controls. PIP's bubble and the
## waypoint float over the world on purpose and are left out.
func _apart(g: Control) -> void:
	var h: Control = g.game_hud
	var gear := Button.new()  # a stand-in for the settings screen's gear, docked as the sandbox docks the real one
	g.add_child(gear)
	h.dock_gear(gear)
	for layout: String in ["laptop", "phone"]:
		g.set_view(layout)
		await process_frame
		await process_frame
		check(h.gear_slot.get_global_rect().encloses(gear.get_global_rect().grow(-0.5)), "%s: the gear sits in its place" % layout)
		var parts := {"status": h.status, "tasks": h.tasks, "alert": h.toast, "compass": h.compass, "minimap": h.minimap,
			"gear": h.gear_slot, "sources": h.source_button, "book": h.book_button, "mail": h.mail, "prompt": h.prompt}
		for i in g.touch.size():
			parts["touch %d" % i] = g.touch[i]
		var names := parts.keys().filter(func(n: String) -> bool: return (parts[n] as Control).is_visible_in_tree())
		for i in names.size():
			for j in range(i + 1, names.size()):
				var a: Rect2 = (parts[names[i]] as Control).get_global_rect()
				var b: Rect2 = (parts[names[j]] as Control).get_global_rect()
				check(not a.intersects(b), "%s: %s %s overlaps %s %s" % [layout, names[i], a, names[j], b])


## The busiest play page (bubble, waypoint, alert, mail, minimap, compass, tasks, prompt all up) in each layout draws
## in at most MAX_DRAWS calls, the gallery's backdrop and touch controls included. Needs a display: under
## `godot --headless` nothing draws, so run it with `xvfb-run -a godot --path . -s tests/ui_test.gd` to measure.
func _draws(g: Control) -> void:
	if DisplayServer.get_name() == "headless":
		print("draw calls: skipped (headless draws nothing; run under xvfb-run to measure)")
		return
	for layout: String in ["laptop", "phone"]:
		g.set_view(layout)
		for i in 3:
			await process_frame
		var n := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("draw calls, %s play page: %d" % [layout, n])
		check(n > 0 and n <= MAX_DRAWS, "the %s play page draws in %d calls, at most %d" % [layout, n, MAX_DRAWS])


## The play HUD bound to a fake sim: every value it is sent shows, and each card opens, answers and closes.
func _bound() -> void:
	var h: Control = load("res://ui/game_hud.tscn").instantiate()
	var fake: Node = Fake.new()
	root.add_child(fake)
	root.add_child(h)
	h.start_unix = 1794657600.0  # 14 Nov 2026 12:00 UTC
	await frames(1)
	h.bind(fake)
	var m: Dictionary = h.snapshot().meters
	check(m.power == 24 and m.health == 82, "bound meters: power %d (want 24), health %d (want 82)" % [m.power, m.health])
	check(not h.meters.health.gain.visible, "the first state shows no drop in health")
	check(h.snapshot().alert == "Solar storm", "a new event raises an alert, got '%s'" % h.snapshot().alert)
	fake.set_values({"battery_pct": 81.6, "o2_kg": 16.7, "health": 70.4, "sol": 13, "hour": 14.5, "suit_air_min": 300.0, "body": false, "hurt": ""})
	var s: Dictionary = h.snapshot()
	check(s.meters.power == 82, "power follows battery_pct: %d" % s.meters.power)
	check(s.meters.life == 50 and s.meters.lifeIcon == "oxygen", "life support is the shortest supply (oxygen at half): %s" % [s.meters])
	check(s.meters.health == 70 and h.meters.health.gain.visible and h.meters.health.gain.text == "-12",
		"crew health is the rules' health, and a drop shows beside it: %d '%s'" % [s.meters.health, h.meters.health.gain.text])
	# the HUD shows the sky's local time: the rules' 14.5 Earth hours into a 24.66 h sol are 14:06 on a 24 h dial
	check(s.sol == 13 and s.time == "14:06" and s.suit == "5 h 00 min", "clock and suit air: %s %s '%s'" % [s.sol, s.time, s.suit])
	check(not "!" in h.meters.power.num.text, "the low mark goes when power recovers")
	var cues: Array[String] = []
	h.cue.connect(func(n: String) -> void: cues.append(n))
	fake.set_values({"battery_pct": 10.0, "failing": ["o2_kg"]})
	check(h.meters.power.num.text == "10%!" and h.snapshot().alert == "Oxygen ran out!", "low power shows its mark, a failing supply an alert: %s %s" % [h.meters.power.num.text, h.snapshot().alert])
	check(cues == ["danger"], "a supply at zero plays the danger cue once, got %s" % [cues])
	fake.set_values({"failing": []})
	fake.set_values({"failing": ["water_kg"]})
	check(cues == ["danger"], "a second danger within %.0f s stays quiet, got %s" % [h.ALERT_GAP_S, cues])
	h._cue_at.danger = -1e9  # as if the gap had passed
	fake.set_values({"failing": []})
	fake.set_values({"failing": ["food_kg"]})
	check(cues == ["danger", "danger"], "after the gap the danger cue plays again, got %s" % [cues])
	await _hud_parts(h, cues)
	h.say("no_such_line")
	check(h.snapshot().subtitle == "TBD at event: no_such_line", "say() shows the placeholder line: '%s'" % h.snapshot().subtitle)
	await _speech(h)
	await _pip_away(h)
	h.send_mail()
	var mail: Dictionary = h.snapshot().mail
	var want := Delay.minutes(h.game_unix())
	check(mail.sent == "14:30" and absf(mail.minutes - want) < 0.1, "mail sent at 14:30 with %.1f min each way: %s" % [want, mail])
	var back: float = 14.5 + 2.0 * want / 60.0
	check(mail.reply == "%02d:%02d" % [int(back), roundi(fposmod(back, 1.0) * 60.0)], "the reply time is two delays later: %s" % mail.reply)
	var got: Array = []
	h.chosen.connect(func(id: String, i: int) -> void: got.append([id, i]))
	h.offer_choice("choice_power_morning", [{"text": "follow_me", "costs": {"battery_pct": -20}}, {"text": "Rest", "costs": {"food_kg": -1}}, {"text": "Wait", "costs": {"health": -1}}])
	await frames(2)
	check(h.snapshot().card == "EventCard" and h.is_open(), "offer_choice opens the choice card: %s %s" % [h.snapshot().card, h.is_open()])
	var buttons: Array[Button] = h.card.buttons
	check(buttons.size() == 3 and buttons[0].find_children("*", "Label", true, false)[0].text == h.lines.follow_me, "options read their text from lines.json")
	click(buttons[1].get_global_rect().get_center())
	await frames(2)
	check(got == [["choice_power_morning", 1]] and not h.is_open(), "a click on option 2 emits chosen and closes: %s" % [got])
	var closed := [false]
	h.ledger_closed.connect(func() -> void: closed[0] = true)
	h.show_ledger({"sols": 3, "o2_kg": -5.0, "water_kg": -19.3, "nonsense": 4})
	await frames(2)
	var rows: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("-5 kg" in rows and "-19.3 kg" in rows and "Oxygen" in rows, "the ledger lists its supplies: %s" % [rows])
	h.card.button.pressed.emit()
	check(closed[0] and not h.is_open(), "the ledger closes")
	await _body(h, fake)
	var causes := [{"label": "Rest the oxygen maker", "sol": 4, "effect": {"o2_kg": -6.0}}, {"label": "Greenhouse lights on", "sol": 6, "effect": {"battery_pct": -30.0}}, "Heaters off"]
	h.show_causes(causes)
	await frames(2)
	var chips: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(h.snapshot().card == "MissionLost" and "Rest the oxygen maker" in chips and "Sol 6" in chips and "Heaters off" in chips, "the causes card shows the three causes: %s" % [chips])
	check(h.card.buttons[0].text == "Try this sol again", "the lost card's button says what it does: '%s'" % h.card.buttons[0].text)
	var tries := [0]
	h.retry.connect(func() -> void: tries[0] += 1)
	h.show_causes(causes, "Start again")
	await frames(2)
	check(h.card.buttons[0].text == "Start again", "show_causes takes the retry button's words: '%s'" % h.card.buttons[0].text)
	h.card.buttons[0].pressed.emit()
	check(tries[0] == 1 and not h.is_open(), "and that button emits retry and closes the card")
	h.show_causes(causes)
	await frames(2)
	h.card.buttons[1].pressed.emit()
	check(h.handbook.visible, "the lost card's Mission log opens the handbook, where the decisions are")
	h.handbook.close()
	await frames(2)
	check(h.snapshot().card == "MissionLost" and h.modal.visible, "and the lost card is back after it")
	h.close_card()
	await _report(h, causes)
	h.show_sources()
	await frames(2)
	var src: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("COMPUTED" in src and "ARCHIVED" in src and "Oxygen 16.7 kg" in src, "the sources card tags each data value: %s" % [src])
	check(h.SOURCES.health in src and h.SOURCES.suit_air in src and h.SOURCES.suit_dust in src and h.SOURCES.flare in src,
		"the sources card says crew health is a game rule, with the suit, dust and storm facts: %s" % [src])
	check(h.SOURCES.values().all(func(t: String) -> bool: return t.split(" ", false).size() <= MAX_WORDS), "every source line has at most %d words" % MAX_WORDS)
	h.source_button.pressed.emit()
	h.close_card()
	h.queue_free()
	fake.queue_free()
	await frames(1)


## The hero's needs (design/plans/core-loop-contracts.md, H): the suit's air, what hurts in words, the
## power's flow, the four bars and the hold ring on the prompt.
func _body(h: Control, fake: Node) -> void:
	var st: Control = h.status
	fake.emit_state()  # the checks before this one set the clock by hand
	check(h.snapshot().body == {} and h.snapshot().health_note == "Suit air 5 h 00 min",
		"with the body off the suit's time shows under Crew health: %s '%s'" % [h.snapshot().body, h.snapshot().health_note])
	await frames(2)
	var off: Vector2 = st.size  # the card's one size: checked again healthy and hurting, below
	fake.set_values({"body": true, "outside": false, "suit_air": 1.0, "body_water": 0.2, "body_food": 0.7, "body_rest": 0.55, "suit_dust": 0.4})
	await frames(2)
	var b: Dictionary = h.snapshot().body
	check(b == {"air": 100, "water": 20, "food": 70, "rest": 55, "dusty": false} and h.snapshot().suit == "",
		"the rules' needs reach the HUD, and a clean suit shows no dust mark: %s" % [b])
	check(h.get_global_rect().encloses(st.get_global_rect()), "the status card is on screen: %s" % [st.get_global_rect()])
	# at most four progress bars on the whole HUD, all full size (Ravindu, 15 Nov 2026), and no small gauges
	var all_bars: Array = _bars(h)
	var four: Array = h.meters.values()
	check(h.meters.keys() == ["power", "life", "health", "air"] and all_bars.size() == 4 and four.all(func(m: Control) -> bool: return m in all_bars and not m.compact),
		"the HUD has four bars and no others: %s" % [all_bars.map(func(n: Node) -> String: return str(n.name))])
	check(four.all(func(m: Control) -> bool: return m.size == four[0].size and m.bar.size == four[0].bar.size and m.bar.size.x >= 60.0),
		"all four are one size: %s" % [four.map(func(m: Control) -> Vector2: return m.bar.size)])
	fake.set_values({"body_water": 0.9, "body_food": 0.1, "outside": true, "suit_dust": 0.6})
	await frames(2)
	b = h.snapshot().body
	check(b.air == 100 and b.dusty and h.meters.air.value == 100, "a full suit is a full bar, and a dusty suit shows its mark: %s" % [b])
	check(st.size == off, "the card is the same size healthy as with the body off: %s, %s" % [st.size, off])
	fake.set_values({"outside": false, "suit_air": 0.1, "suit_dust": 0.0})
	check(h.meters.air.value == 10 and h.meters.air.low() and "!" in h.meters.air.num.text and not h.snapshot().body.dusty,
		"a suit nearly empty shows it on its bar, with a '!': '%s'" % h.meters.air.num.text)
	fake.set_values({"suit_air": 0.5})
	# what hurts, in words; a small fall or a rise shows no "-N"
	h.meters.health.gain.text = ""
	fake.set_values({"hurt": "air", "health": 68.0})
	check(h.snapshot().hurt == "No air" and h.snapshot().health_note == "Falling: No air" and h.meters.health.name_label.text == "Crew health" and h.meters.health.gain.text == "",
		"what hurts goes under the meter, which keeps its name, and 2 points down is no bump: '%s'" % h.snapshot().health_note)
	fake.set_values({"hurt": "flare", "health": 90.0})
	await frames(2)
	check(h.snapshot().hurt == "Solar storm" and h.meters.health.gain.text == "", "a rise shows no drop: '%s'" % h.meters.health.gain.text)
	# the worst the card ever holds: every need empty, the longest reason, a drop and a gain showing, a dusty suit
	fake.set_values({"body_water": 0.0, "body_food": 0.0, "body_rest": 0.0, "suit_air": 0.0, "suit_dust": 1.0, "health": 14.0, "battery_pct": 3.0, "o2_kg": 0.5})
	h.meters.power.bump("+10.0 kW")
	await frames(2)
	check(h.meters.health.gain.visible and st.size == off, "and the same size hurting, with a drop and a gain showing: %s, %s" % [st.size, off])
	fake.set_values({"body_water": 0.9, "body_food": 0.1, "body_rest": 0.55, "suit_air": 0.5, "suit_dust": 0.0, "health": 90.0, "battery_pct": 81.6, "o2_kg": 16.7})
	var bars: Array = h.meters.values().map(func(m: Control) -> float: return m.bar.size.x)
	check(bars.min() >= 60.0 and is_equal_approx(bars.min(), bars.max()), "under the longest word the three bars stay in line: %s" % [bars])
	# a phone's canvas is 1115 px wide under PHONE_SCALE, its compass 507 in the middle, its margin 48: 256 px are left
	check(st.size.x <= 256.0, "and the card stays clear of a phone's compass (%.0f px wide, 256 at most)" % st.size.x)
	fake.set_values({"hurt": ""})
	check(h.snapshot().hurt == "" and h.snapshot().health_note == "Steady", "nothing hurts: the line under the meter says so: '%s'" % h.snapshot().health_note)
	check(h.HURTS.keys().all(func(k: String) -> bool: return k in ["air", "thirst", "hunger", "tired", "cold", "flare", "dust"]), "every hurt the rules name has its words")
	# an oxygen leak: a danger alert once, when it starts
	h.toast.hide()
	h._cue_at.clear()
	var cues: Array[String] = []
	var hear := func(n: String) -> void: cues.append(n)
	h.cue.connect(hear)
	fake.set_values({"leak": true})
	var said: String = h.snapshot().alert
	h.toast.hide()
	fake.set_values({"leak": true, "hour": 14.6})
	check(said == "Oxygen leak!" and cues == ["danger"] and h.snapshot().alert == "", "a leak raises one danger alert when it starts: '%s' %s" % [said, cues])
	h.cue.disconnect(hear)
	fake.set_values({"leak": false})
	# the battery's flow
	fake.set_values({"net_kw": 2.1})
	var up: String = h.snapshot().flow
	fake.set_values({"net_kw": -3.4})
	check(up == "Charging +2.1 kW" and h.snapshot().flow == "Draining -3.4 kW", "power shows its flow in words and kW: '%s', '%s'" % [up, h.snapshot().flow])
	# an old state, without the new keys
	h.show_state({"sol": 1, "hour": 8.0, "battery_pct": 50.0, "o2_kg": 10.0, "water_kg": 10.0, "food_kg": 10.0})
	check(h.snapshot().meters.health == 100 and h.snapshot().body == {} and h.snapshot().flow == "Steady", "a state without the new keys still shows: %s" % [h.snapshot().meters])
	fake.emit_state()
	# the base report: its key opens it, and what it stacks is the rules' own net
	var key := InputEventAction.new()
	key.action = "report"
	key.pressed = true
	h._input(key)
	await frames(2)
	var rep: Control = h.report
	var net: float = rep._sum(rep.flows.power.makes) - rep._sum(rep.flows.power.uses)
	check(rep.is_visible_in_tree() and is_equal_approx(net, float(fake.values.net_kw)) and rep.lines.net.text == "Net %+.1f kW" % float(fake.values.net_kw),
		"the report opens on its key, and its power segments sum to the state's net: %.2f, '%s'" % [net, rep.lines.net.text])
	var chips: int = rep.legends.makes.get_child_count() + rep.legends.uses.get_child_count()
	check(chips == rep.flows.power.makes.size() + rep.flows.power.uses.size(), "every segment has its label under the bar (%d)" % chips)
	var long: Array = rep.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.split(" ", false).size() > MAX_WORDS)
	check(long.is_empty() and h.get_global_rect().encloses(rep.get_global_rect()), "its lines are short and it is on screen: %s" % [long.map(func(l: Label) -> String: return l.text)])
	var sim: RefCounted = load("res://sim/sim.gd").new()
	sim.step(3.0)
	var real: Dictionary = sim.flows()
	check(is_equal_approx(rep._sum(real.power.makes) - rep._sum(real.power.uses), float(sim.state().net_kw)) and is_equal_approx(real.power.net_kw, float(sim.state().net_kw)),
		"the rules' flows sum to the rules' net (%.2f kW)" % float(sim.state().net_kw))
	h._input(key)
	check(not rep.visible, "and the same key closes it")
	# the hold ring
	var p: Control = h.prompt
	h.show_prompt("Drink water", 0.0)
	await frames(2)
	var chip: Vector2 = p.key.size
	check(h.snapshot().prompt == "Drink water" and h.snapshot().hold == 0.0 and p.line.text == "Hold: Drink water",
		"a target that needs a hold says so, its ring empty: '%s' %s" % [p.line.text, h.snapshot().hold])
	check(p.ring.size.x >= chip.length() and p.ring.size.y >= chip.length() and p.get_global_rect().encloses(p.ring.get_global_rect()),
		"the ring goes round the key chip inside the prompt (ring %s, chip %s)" % [p.ring.size, chip])
	h.show_prompt("Drink water", 0.5)
	check(h.snapshot().hold == 0.5 and p.hold == 0.5, "the hold's progress reaches the ring: %s" % p.hold)
	h.show_prompt("Drink water", 3.0)
	check(p.hold == 1.0, "and never passes full: %s" % p.hold)
	h.show_prompt("Open the door")
	await frames(2)
	check(h.snapshot().hold == -1.0 and p.line.text == "Open the door" and p.ring.custom_minimum_size == Vector2.ZERO, "a plain press has no ring and no 'Hold': '%s'" % p.line.text)
	h.show_prompt("")


## Everything on the HUD that reads as a progress bar and can be seen: the meters and any engine range.
func _bars(h: Control) -> Array:
	return h.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		return n is Control and (n as Control).is_visible_in_tree() and (n is Range or n.get_script() == MeterScript))


## The mission complete card: its words, the three meters, the causes, and its two buttons.
func _report(h: Control, causes: Array) -> void:
	var got: Array = []
	h.report_closed.connect(func(again: bool) -> void: got.append(again))
	var d := {"title": "Mission 1 complete", "lines": ["follow_me", "You kept the base *alive*."], "meters": {"power": 64.2, "life": 71, "health": 82},
		"causes": causes, "pages": [7, 12]}
	for again: bool in [true, false]:
		h.show_report(d)
		await frames(2)
		var words: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		check(h.snapshot().card == "MissionLost" and h.is_open() and "Mission 1 complete" in words and h.line("follow_me") in words and "You kept the base alive." in words
			and "Handbook pages found: 7 of 12" in words and "Sol 6" in words and "64%" in words and "82%" in words and not "Mission lost" in words,
			"the report shows its title, lines, meters, pages and causes: %s" % [words])
		check(words.all(func(t: String) -> bool: return t.split(" ", false).size() <= MAX_WORDS), "no line of the report has more than %d words" % MAX_WORDS)
		var buttons: Array[Button] = h.card.buttons
		check(buttons.map(func(k: Button) -> String: return k.text) == ["Keep going", "Play again"], "its two buttons: %s" % [buttons.map(func(k: Button) -> String: return k.text)])
		check(buttons.all(func(k: Button) -> bool: return k.size.y >= Hud.BUTTON_H and get_root().get_visible_rect().encloses(k.get_global_rect())), "both are touch targets on screen")
		buttons[1 if again else 0].pressed.emit()
		check(got == ([true] if again else [true, false]) and not h.is_open(), "%s emits report_closed(%s) and closes: %s" % [buttons[1 if again else 0].text, again, got])
	h.show_report({})
	await frames(2)
	check(h.card.buttons.size() == 2 and h.card.find_children("*", "HBoxContainer", true, false).all(func(n: Node) -> bool: return not "meter.gd" in String((n.get_script() as Script).resource_path if n.get_script() else "")),
		"an empty report still has its two buttons, and no meters or chain")
	h.close_card()


## The compass, minimap, waypoint, Today, prompt and full map follow a stand-in camera and hero; each HUD event
## plays its own cue once.
func _hud_parts(h: Control, cues: Array[String]) -> void:
	var cam := Camera3D.new()
	var body := Node3D.new()
	var pip := Node3D.new()
	for n: Node3D in [cam, body, pip]:
		root.add_child(n)
	# the spawn and the greenhouse after the whole base turned -99 deg to face the sunrise (tools/rotate_base.py)
	body.position = Vector3(8.889, 0, -1.408)  # the spawn
	body.rotation.y = -deg_to_rad(171.0)  # facing the greenhouse: south
	cam.position = Vector3(8.889, 1.6, -1.408)
	cam.rotation.y = body.rotation.y
	pip.position = Vector3(4.73, 0, 4.31)
	h.bind_view(cam, body)
	h.bind_speaker(pip, cam)
	cues.clear()
	h.set_objective("greenhouse")  # (6.856, 10.051): 11.6 m away, a little west of south
	h.set_objective("greenhouse")
	await process_frame
	await process_frame
	var s: Dictionary = h.snapshot()
	check(s.heading.begins_with("171°") and s.heading.ends_with("S"), "the compass reads the camera's heading: '%s'" % s.heading)
	check(s.objective.m == 12 and s.objective.label == "Greenhouse" and not s.objective.docked, "the waypoint names the place and its distance on screen: %s" % [s.objective])
	var want := Hud.bearing(Vector3(6.856 - 8.889, 0, 10.051 + 1.408))
	check(absf(float(h.compass.marks.objective) - want) < 0.5, "the compass marks the objective at %.0f, want %.0f" % [h.compass.marks.objective, want])
	var d: Vector2 = h.minimap.to_disc(Vector2(6.856, 10.051), 999.0)
	check(d.y < 0.0 and absf(d.x) < absf(d.y), "on the minimap the objective ahead is up: %s" % d)
	check(s.area == "Landing plain", "the area under the minimap: %s" % s.area)
	# the kid's own mark dropped on the objective's place shows one tag, not two; elsewhere it shows its own
	h.set_mark(Vector2(6.856, 10.051), "greenhouse", "Greenhouse")
	await process_frame
	await process_frame
	check(h.waypoint.visible and not h.marker.visible, "a mark on the objective's own place adds no second tag")
	h.set_mark(Vector2(60.0, 40.0), "", "Marker")
	await process_frame
	await process_frame
	check(h.marker.visible, "a mark somewhere else shows its own tag")
	h.set_mark(null)
	await process_frame
	body.rotation.y = -deg_to_rad(261.0)
	cam.rotation.y = body.rotation.y  # now facing west: the greenhouse is behind-left, off screen
	cam.position = Vector3(8.889, 1.6, -1.408)
	await process_frame
	await process_frame
	check(h.snapshot().objective.docked, "off screen the waypoint docks at an edge")
	h._cue_at.clear()  # a test runs events faster than a person: forget the 0.15 s no-stacking window between them
	h.set_tasks([{"label_id": "morning_check", "state": "now"}, {"label_id": "brush_dust", "state": "next"}])
	check(h.tasks.is_visible_in_tree(), "Today shows as soon as a task is set")
	h.set_tasks([{"label_id": "morning_check", "state": "done"}, {"label_id": "brush_dust", "state": "now"}])
	check(h.snapshot().tasks.size() == 2 and h.snapshot().tasks[0][1] == "done", "Today lists the tasks: %s" % [h.snapshot().tasks])
	# the day's work done (the beats keep only the rest): the list stays up ticked, slides and fades out, then the rest
	# comes in alone; a list all done leaves for good (14 Nov playtest: the done list just stayed up)
	var x0: float = h.tasks.position.x
	h.set_tasks([{"label_id": "task.sleep", "state": "now"}])
	check(h.snapshot().tasks.size() == 2 and h.snapshot().tasks.all(func(r: Array) -> bool: return r[1] == "done"),
		"the finished list stays up, every box ticked: %s" % [h.snapshot().tasks])
	await create_timer(h.TASKS_HOLD_S + h.TASKS_LEAVE_S * 0.6).timeout
	check(h.tasks.modulate.a < 0.9 and h.tasks.position.x < x0 - 1.0, "then it slides out and fades (alpha %.2f, x %.0f from %.0f)" % [h.tasks.modulate.a, h.tasks.position.x, x0])
	await create_timer(h.TASKS_LEAVE_S + 0.5).timeout
	await process_frame
	check(h.snapshot().tasks == [[h.line("task.sleep"), "now"]] and h.tasks.modulate.a > 0.99 and is_equal_approx(h.tasks.position.x, x0),
		"and only the rest comes back, in place (%s, x %.0f)" % [h.snapshot().tasks, h.tasks.position.x])
	h._cue_at.clear()  # game time runs far ahead of the cue's real-time 0.15 s window here (it failed under load)
	h.set_tasks([{"label_id": "task.sleep", "state": "done"}])
	await create_timer(h.TASKS_HOLD_S + h.TASKS_LEAVE_S + 0.3).timeout
	check(not h.tasks.visible, "a list all done leaves for good")
	# the sol row sits the same with one digit or two, and each meter names itself in a word (14 Nov playtest: "Sol 41"
	# looked unbalanced; kids could not tell Life support from Crew health)
	h.clock.show_time(4, 10.0)
	await process_frame
	await process_frame
	var one: Vector2 = h.clock.time_label.global_position
	var box1: float = h.clock.sol_label.size.x
	h.clock.show_time(24, 10.0)
	await process_frame
	await process_frame
	check(h.clock.time_label.global_position.is_equal_approx(one) and is_equal_approx(h.clock.sol_label.size.x, box1), "the clock does not move when the sol reaches two digits")
	var words: Array = h.meters.values().map(func(m: Control) -> String: return m.name_label.text if m.name_label.is_visible_in_tree() else "")
	check(words == ["Power", "Life support", "Crew health", "Suit air"], "the meters are named as PIP names them: %s" % [words])
	# a brushed wing's "+kW" fades beside the power number and gives the bar its width back (14 Nov playtest: "the power
	# bar is getting shorter and shorter")
	var power: Control = h.meters.power
	var bar_w: float = power.bar.size.x
	power.bump("+0.4 kW")
	await create_timer(3.6).timeout
	await process_frame
	await process_frame
	check(is_equal_approx(power.bar.size.x, bar_w), "the power bar is as long after a gain shows as before (%.0f, was %.0f)" % [power.bar.size.x, bar_w])
	h.show_prompt("Open the greenhouse")
	check(h.snapshot().prompt == "Open the greenhouse", "the use prompt shows")
	h.show_prompt("")
	check(h.snapshot().prompt == "", "an empty prompt hides it")
	action(&"map")
	action(&"map", false)
	await process_frame
	check(h.map_open() and h.snapshot().map, "M opens the full map")
	var lbl: Array = h.full_map.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("Mont Mercou  8.8 km" in lbl and "Curiosity  14.3 km" in lbl and "ARCHIVED" in lbl, "the map names the field sites with their real distances: %s" % [lbl])
	await _far_cry_map(h)
	action(&"ui_cancel")
	action(&"ui_cancel", false)
	await process_frame
	check(not h.map_open(), "Esc closes the map")
	# a moving objective: PIP, followed live
	pip.position = Vector3(-3, 0, -2)
	h._cue_at.clear()
	h.set_objective("pip")
	await process_frame
	await process_frame
	var m1: int = h.snapshot().objective.m
	pip.position = Vector3(-19.29, 0, 6.09)
	await process_frame
	await process_frame
	var m2: int = h.snapshot().objective.m
	check(h.snapshot().objective.label == "PIP" and m2 > m1 + 10, "the waypoint follows PIP: %d m, then %d m" % [m1, m2])
	var want_pip := Hud.bearing(Vector3(-19.29, 0, 6.09) - body.position)
	check(absf(float(h.compass.marks.objective) - want_pip) < 1.0, "the compass mark follows PIP (%.0f, want %.0f)" % [h.compass.marks.objective, want_pip])
	h.complete_objective()
	check(h.snapshot().objective.is_empty(), "a done objective clears its waypoint")
	h.say("follow_me")
	h.offer_choice("choice_power_morning", [{"text": "A", "costs": {}}, {"text": "B", "costs": {}}])
	h.card.chosen.emit(0)
	h.show_ledger({"sols": 1})
	h.close_card()
	h.bubble.hide()
	# the objective_new inside the map: the kid's own mark set there (_far_cry_map)
	# the second tick: the rest itself ticked done (the day's list leaving ticks inside the first one's 0.15 s window)
	var want_cues := ["objective_new", "objective_new", "task_tick", "task_tick", "map_open", "objective_new", "map_close", "objective_new", "objective_done", "pip_open", "choice_open", "choice_made", "ledger_open"]
	check(cues == want_cues, "each HUD event plays its cue once:\n  got  %s\n  want %s" % [cues, want_cues])
	var audio: Script = load("res://audio/audio.gd")
	for n: String in want_cues + ["mail", "alert", "danger", "tick", "select"]:
		check(audio.UI_SOUNDS.has(n), "audio.gd UI_SOUNDS has the cue '%s'" % n)
	var made: Dictionary = load("res://ui/ui_sounds.gd").build()
	for n: String in audio.UI_SOUNDS:
		var w: AudioStreamWAV = made.get(n)
		check(w != null and w.get_length() > 0.02 and w.get_length() < 1.5, "the cue '%s' is made and short (%s s)" % [n, w.get_length() if w else 0.0])
	for n: Node in [cam, body, pip]:
		n.queue_free()


## PIP's bubble: it types in with chirps, rides above PIP while he is in view, docks at the edge toward him when he
## is behind the camera, and goes once read.
func _speech(h: Control) -> void:
	var b: Control = h.bubble
	var cam := Camera3D.new()
	var pip := Node3D.new()
	root.add_child(cam)
	root.add_child(pip)
	pip.position = Vector3(0.0, -0.5, -5.0)
	h.bind_speaker(pip, cam)
	var done := [false]
	b.finished.connect(func() -> void: done[0] = true)
	h.say("follow_me")
	await process_frame  # the bubble places itself in _process: a physics step alone may not run one (AGENTS.md)
	await process_frame
	var text: String = h.lines.follow_me
	check(h.snapshot().subtitle == text, "say() reads data/lines.json")
	check(b.typed < text.length(), "the line types in, not all at once (%d of %d)" % [b.typed, text.length()])
	var p: Rect2 = Rect2(b.panel.position, b.panel.size)
	check(not b.docked and p.end.y < b.anchor.y and absf(b.anchor.x - b.size.x * 0.5) < 2.0, "PIP in view: the bubble %s sits above him at %s" % [p, b.anchor])
	await frames(roundi(60.0 * text.length() / b.CHARS_PER_S) + 5)
	check(b.typed == text.length() and b.chirps >= 3, "typed out with chirps (%d letters, %d chirps)" % [b.typed, b.chirps])
	pip.position = Vector3(3.0, 0.0, 4.0)  # behind the camera, to its right
	await process_frame
	await process_frame
	p = Rect2(b.panel.position, b.panel.size)
	var edge := minf(minf(p.position.x, p.position.y), minf(b.size.x - p.end.x, b.size.y - p.end.y))
	check(b.docked and b.dir.x > 0.0 and edge <= b.EDGE + b.ARROW + 1.0, "PIP behind: the bubble docks at an edge (%s, gap %.0f) pointing %s" % [p, edge, b.dir])
	check(done[0], "the bubble says when the line is typed out")
	await frames(300)  # five seconds: a line no longer times out
	check(h.snapshot().subtitle == text, "the line stays up until the next one")
	h.clear_line()
	check(h.snapshot().subtitle == "", "clear_line() takes it down")
	pip.position = Vector3(0.0, -0.5, -5.0)
	# the keys a line teaches, as keycaps under the words; on a phone W, A, S and D are one "Stick"
	h.say("follow_me", {"keys": ["W", "A", "S", "D"]})
	await process_frame
	check(h.snapshot().bubble.keys == 4, "four keycaps under the words: %s" % [h.snapshot().bubble])
	h.touch = true
	h.say("follow_me", {"keys": ["W", "A", "S", "D", "Mouse"]})
	await process_frame
	check(h.snapshot().bubble.keys == 2, "on a phone, one stick and one drag: %s" % [h.snapshot().bubble])
	h.touch = false
	h.say("follow_me", {"keys": ["Mouse", "Space"]})
	await process_frame
	var caps: Array = b.keys_row.get_children().filter(func(k: Node) -> bool: return not k.is_queued_for_deletion())
	check(caps.size() == 2 and caps[0] is TextureRect and caps[1] is PanelContainer, "a mouse drawing and a Space keycap: %s" % [caps])
	# a fact waits: Enter first finishes the typing, then dismisses; a tap dismisses too
	var gone: Array[String] = []
	h.dismissed.connect(func(id: String) -> void: gone.append(id))
	h.say("event_dust_storm", {"fact": true})
	await process_frame
	action(&"ui_accept")
	action(&"ui_accept", false)
	await process_frame
	check(b.typed == b.text.length() and b.visible and gone.is_empty(), "Enter during the typing finishes the line, keeps it up")
	action(&"ui_accept")
	action(&"ui_accept", false)
	await process_frame
	check(gone == ["event_dust_storm"] and not b.visible, "a second Enter dismisses the fact: %s" % [gone])
	h.say("event_flare_x12", {"fact": true})
	await frames(roundi(60.0 * b.text.length() / b.CHARS_PER_S) + 5)
	await frames(240)
	check(b.visible, "a fact stays until it is dismissed")
	tap(b.panel.get_global_rect().get_center())
	await process_frame
	check(gone.back() == "event_flare_x12" and not b.visible, "a tap on the bubble dismisses a fact: %s" % [gone])
	cam.queue_free()
	pip.queue_free()


## The hero looking away: PIP behind the hero or behind the camera still has his words and his "PIP 12 m" marker on
## screen, apart; a choice card opens beside the hero and leaves PIP's bubble and the middle third uncovered.
func _pip_away(h: Control) -> void:
	var b: Control = h.bubble
	var w: Control = h.waypoint
	var cam := Camera3D.new()
	var body := Node3D.new()
	var pip := Node3D.new()
	for n: Node3D in [cam, body, pip]:
		root.add_child(n)
	cam.position = Vector3(0, 2, 4)
	h.bind_view(cam, body)
	h.bind_speaker(pip, cam)
	h.set_objective_node(pip, "", "pip")
	h.say("follow_me")
	var screen := Rect2(Vector2.ZERO, h.size)
	for at: Vector3 in [Vector3(0, 0, -6), Vector3(4, 0, 9), Vector3(-4, 0, 9), Vector3(0, 0, 9)]:  # behind the hero, then behind the camera
		pip.position = at
		await frames(2)
		var bub := Rect2(b.panel.position, b.panel.size)
		var tag := Rect2(w.tag.position, w.tag.size)
		check(b.visible and screen.encloses(bub), "PIP at %s: his bubble %s is on screen" % [at, bub])
		check(w.visible and screen.encloses(tag) and not tag.intersects(bub), "PIP at %s: his marker %s is on screen, clear of the bubble %s" % [at, tag, bub])
		if at.z > cam.position.z:
			check(b.docked and w.docked and b.dir.y > 0.0 and bub.end.y > h.size.y * 0.6, "PIP behind the camera docks on the bottom edge: %s %s" % [bub, b.dir])
			if at.x != 0.0:
				check(signf(bub.get_center().x - h.size.x * 0.5) == signf(at.x), "PIP behind the camera at %s docks on his side: %s" % [at, bub])
	for at: Vector3 in [Vector3(2.5, 0, -3), Vector3(-2.5, 0, -3), Vector3(4, 0, 9)]:
		pip.position = at
		await frames(2)
		h.offer_choice("choice_power_morning", [{"text": "follow_me", "costs": {"battery_pct": -20}}, {"text": "Rest", "costs": {"food_kg": -1}}, {"text": "Wait", "costs": {"health": -1}}])
		await frames(2)
		var card := Rect2(h.card.position, h.card.size)
		var bub := Rect2(b.panel.position, b.panel.size)
		var middle := Rect2(h.size.x / 3.0, 0, h.size.x / 3.0, h.size.y)
		check(h.is_open() and screen.encloses(card) and not card.intersects(bub), "PIP at %s: the choice card %s leaves his bubble %s clear" % [at, card, bub])
		check(not card.intersects(middle) and not h.scrim.visible, "the choice card %s stays out of the hero's middle third, with no scrim" % [card])
		for btn: Button in h.card.buttons:
			check(btn.size.y >= 48.0, "a choice is %.0f px tall, a touch target needs 48" % btn.size.y)
		h.close_card()
	h.clear_line()
	h.clear_objective()
	for n: Node in [cam, body, pip]:
		n.queue_free()


## The map, Far Cry style (Ravindu, 14 Nov): one view from the crater to the base, zoom clamped at both ends, a drag
## pans, a click on a place's label marks it (the same input a finger or a mouse gives), a second click on the mark
## clears it, and the compass carries the mark's distance.
func _far_cry_map(h: Control) -> void:
	var fm: Control = h.full_map
	await process_frame
	await process_frame
	var mid: Vector2 = fm.view.size * 0.5
	fm.zoom_at(1e6, mid)
	check(is_equal_approx(fm.zoom, fm.ZOOM_MAX), "zooming in stops at %.1f px a metre (%.2f)" % [fm.ZOOM_MAX, fm.zoom])
	fm.zoom_at(1e-6, mid)
	check(is_equal_approx(fm.zoom, fm.zoom_min()) and fm.zoom_min() * 192000.0 < fm.view.size.x * 1.05, "zooming out stops with the whole crater in view (%.4f)" % fm.zoom)
	await process_frame
	var far: Array = fm.labels.map(func(l: Array) -> String: return l[0])
	check("mercou" in far and "sharp" in far and not "greenhouse" in far, "zoomed out: the crater's places, not the base's (%s)" % [far])
	fm.recenter()
	await process_frame
	var near: Array = fm.labels.map(func(l: Array) -> String: return l[0])
	check("solar" in near and "greenhouse" in near, "at the base: its places (%s)" % [near])
	var c0: Vector2 = fm.center
	var press: Vector2 = fm.view.get_global_transform_with_canvas() * mid
	for e: InputEvent in _drag_events(press, press + Vector2(60, 0)):
		send(e)
	await process_frame
	check(fm.center.x < c0.x - 5.0 and fm.mark == null, "a drag pans the map and marks nothing (%.0f to %.0f)" % [c0.x, fm.center.x])
	fm.recenter()
	await process_frame
	var at = fm.screen_of("solar")
	click(at)
	await process_frame
	await process_frame
	check(h.mark != null and h.mark_id == "solar" and h.snapshot().mark.label == "Solar farm", "a click on Solar farm marks it (%s)" % [h.snapshot().get("mark")])
	check(String(h.snapshot().mark.compass).ends_with(" m") and h.compass.marks.mark != null, "the compass shows the mark and its distance (%s)" % h.snapshot().mark.compass)
	click(fm.view.get_global_transform_with_canvas() * fm.to_view(fm.mark))
	await process_frame
	check(h.mark == null and h.snapshot().mark.is_empty(), "a second click on the mark clears it")


func _drag_events(from: Vector2, to: Vector2) -> Array[InputEvent]:
	var k := root.get_final_transform()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = k * from
	var move := InputEventMouseMotion.new()
	move.position = k * to
	move.relative = to - from
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = k * to
	return [down, move, up]


## A side card wears the play HUD's glass: the status card's panel, see-through rows (never the menu's slab on a
## slab), words with the dark edge, a row in focus marked by a bar as well as a tint, rows a finger can hit on a
## phone, and nothing of the HUD showing through it.
func _glass(h: Control, what: String) -> void:
	await process_frame
	await process_frame
	var c: Control = h.card
	check(c.theme_type_variation == &"HudPanel" and c.get_theme_stylebox("panel") == h.status.get_theme_stylebox("panel") and not h.scrim.visible,
		"%s is on the play HUD's glass panel, with no scrim (%s)" % [what, c.theme_type_variation])
	var menu := Hud.color("hud-glass-menu").a
	var through := 1.0 - _fill_of(c.get_theme_stylebox("panel")).a
	for b: Button in c.buttons + [c.book]:
		var rest := b.get_theme_stylebox("normal") as StyleBoxFlat
		var lit := b.get_theme_stylebox("focus") as StyleBoxFlat
		check(through * (1.0 - rest.bg_color.a) > 1.0 - menu, "%s: a row lets more of the game through than menu glass (%.2f)" % [what, through * (1.0 - rest.bg_color.a)])
		check(lit.border_width_left >= 4 and lit.border_width_left > rest.border_width_left and lit.bg_color != rest.bg_color,
			"%s: the row in focus has a bar at its left edge as well as a tint" % what)
		check(b.size.y * Hud.PHONE_SCALE >= TARGET, "%s: a row is %.0f scene px tall on a phone, a finger needs %.0f" % [what, b.size.y * Hud.PHONE_SCALE, TARGET])
	for l: Label in c.find_children("*", "Label", true, false):
		check(l.has_node("Edge") or String(l.theme_type_variation).begins_with("OnFill"), "%s: '%s' has the dark edge" % [what, l.text])
	var r := c.get_global_rect()
	check(h._under().all(func(p: Control) -> bool: return p.modulate.a == (0.0 if p.get_global_rect().intersects(r) else 1.0)),
		"%s: no HUD part shows through it" % what)
	check(get_root().get_visible_rect().encloses(r), "%s %s is on screen" % [what, r])


## Each card at the width of a 360 dp phone: it asks for no more, and nothing in it spills past its edge.
func _narrow() -> void:
	var box := Control.new()
	box.size = Vector2(NARROW, 720)
	root.add_child(box)
	for n: String in ["event_card", "ledger_card", "sources_card", "mission_lost", "ask_earth", "alert_toast", "tasks_card", "status_panel", "full_map"]:
		var c: Control = load("res://ui/components/%s.tscn" % n).instantiate()
		if "width" in c:
			c.width = NARROW
		if n == "event_card":
			c.options.append({"text": "A third choice with longer words", "costs": {"o2_kg": -2.5, "battery_pct": -10},
				"gain": "spare air for a day", "lose": "the lettuce waits a day"})
		box.add_child(c)
		await frames(2)
		var card: Control = c.card if n in ["mission_lost", "full_map"] else c
		if not n in ["mission_lost", "full_map"]:
			c.size = Vector2(NARROW, 0)
			c.reset_size()
		await frames(2)
		var r := card.get_global_rect()
		check(r.size.x <= NARROW + 0.5, "%s is %.0f px wide at a %.0f px screen" % [n, r.size.x, NARROW])
		for k: Node in card.find_children("*", "Control", true, false):
			var kc := k as Control
			if kc.is_visible_in_tree() and not _in_scroll(kc, card):
				var kr := kc.get_global_rect()
				check(r.grow(1.0).encloses(kr), "%s: %s spills out of the card (%s in %s)" % [n, card.get_path_to(kc), kr, r])
		c.queue_free()
	box.queue_free()


## Under a ScrollContainer below `top`: clipped by it, so it may reach past the card.
func _in_scroll(n: Node, top: Node) -> bool:
	var at := n.get_parent()
	while at and at != top:
		if at is ScrollContainer:
			return true
		at = at.get_parent()
	return false


## The JPL elements put Earth and Mars 0.642 au apart on 12 Jan 2025, that opposition's closest approach.
func _delay() -> void:
	var au := Delay.au(1736683200.0)  # 12 Jan 2025 12:00 UTC
	check(absf(au - 0.642) < 0.003, "Earth-Mars on 12 Jan 2025 is %.4f au, want 0.642" % au)
	var m := Delay.minutes(1794657600.0)
	check(absf(m - 10.98) < 0.1, "the radio delay on 14 Nov 2026 is %.2f min, want 10.98" % m)


## The sleep picker alone: big cards, arrows move focus, accept and taps pick, cancel closes.
func _sleep_picker() -> void:
	var p: Control = load("res://ui/components/sleep_picker.tscn").instantiate()
	root.add_child(p)
	var got: Array[StringName] = []
	p.chosen.connect(func(kind: StringName) -> void: got.append(kind))
	p.cancelled.connect(func() -> void: got.append(&"cancelled"))
	p.open()
	await frames(2)
	var night: Button = p.cards[0]
	var nap: Button = p.cards[1]
	for b: Button in [night, nap, p.not_now]:
		var s := b.get_global_rect().size
		check(minf(s.x, s.y) >= TARGET or b == p.not_now and s.y >= Hud.BUTTON_H, "sleep picker %s is %s, a target needs %.0f" % [b.name, s, TARGET])
	check(night.has_focus(), "the picker opens with Night in focus")
	for step: Array in [[&"ui_right", nap], [&"ui_left", night], [&"ui_down", p.not_now]]:
		action(step[0])
		action(step[0], false)
		await frames(1)
		check((step[1] as Button).has_focus(), "%s moves the picker's focus to %s" % [step[0], (step[1] as Button).name])
	for want: StringName in [&"night", &"nap"]:
		p.open()
		await frames(1)
		if want == &"nap":
			action(&"ui_right")
			action(&"ui_right", false)
		action(&"ui_accept")
		action(&"ui_accept", false)
		await frames(1)
		check(got.back() == want, "ui_accept on the card emits chosen(%s), got %s" % [want, got])
		check(not p.visible, "the picker closes after a choice")
	p.open()
	await frames(2)
	tap(nap.get_global_rect().get_center())
	await frames(1)
	check(got.back() == &"nap", "a tap on Nap emits chosen(nap), got %s" % [got])
	p.open()
	await frames(1)
	action(&"ui_cancel")
	action(&"ui_cancel", false)
	await frames(1)
	check(got.back() == &"cancelled" and not p.visible, "ui_cancel closes the picker and emits cancelled, got %s" % [got])
	p.queue_free()


## The web shell (web/shell.html) and the boot splash colour (project.godot) cannot read design.json, so they hold
## copies of its tokens: the loading screens must not drift from the HUD.
func _loading_tokens() -> void:
	var colors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design.json")).colors
	var found := RegEx.create_from_string("--([a-z-]+): (#[0-9a-f]{6});").search_all(FileAccess.get_file_as_string("res://web/shell.html"))
	check(found.size() >= 4, "web/shell.html declares its colour tokens")
	for m: RegExMatch in found:
		check(colors.get(m.get_string(1), "") == m.get_string(2), "web/shell.html --%s is %s, design.json says %s" % [m.get_string(1), m.get_string(2), colors.get(m.get_string(1), "nothing")])
	# the boot splash is the team's mark on black (ui/boot_splash.png, ui/start.gd), not a part of the game's look
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	check(bg == Color.BLACK, "the boot splash colour %s is not black, as its picture is" % bg.to_html(false))


var aligned := 0


## An icon beside text sits on the text's capitals (Hud.nudge), within 2 px.
func _aligned(b: HBoxContainer, where: String) -> void:
	var label: Label = null
	for k: Node in b.get_children():
		if k is Label:
			label = k
			break
	if label == null or not label.is_visible_in_tree():
		return
	var k := label.get_global_transform_with_canvas().get_scale().y
	if b.name == "SolRow":
		# the status card's top row: every word's capitals and every icon on the row's own centre
		var mid := b.get_global_rect().get_center().y
		for n: Node in b.get_children():
			var c := n as Control
			if not c.is_visible_in_tree() or not (c is Label or c is TextureRect):
				continue
			var y := c.get_global_rect().get_center().y + (Hud.cap_drop(c as Label) * k if c is Label else 0.0)
			check(absf(y - mid) <= 2.0, "%s: %s sits %.1f px off the row's centre" % [where, (c as Label).text if c is Label else "the icon", y - mid])
	var caps := label.get_global_rect().get_center().y + Hud.cap_drop(label) * k
	for n: Node in b.get_children():
		if (n is TextureRect or n.has_meta("icon")) and (n as Control).is_visible_in_tree():
			aligned += 1
			var y := (n as Control).get_global_rect().get_center().y
			check(absf(y - caps) <= 2.0, "%s: an icon sits %.1f px off the capitals of '%s'" % [where, y - caps, label.text])


## The style a text sits on: its own button, or the nearest panel above it with a fill.
func _panel_of(n: Control) -> StyleBox:
	var at: Node = n
	while at is Control:
		var c := at as Control
		var s: StyleBox = null
		if c is Button:
			s = c.get_theme_stylebox("normal")
		elif c is PanelContainer:
			s = c.get_theme_stylebox("panel")
		if s and _fill_of(s).a > 0.0:
			return s
		at = at.get_parent()
	return null


## The colour a style fills its middle with: a flat style's bg, or an atlas nine-patch's centre pixel (ui/atlas.gd).
func _fill_of(s: StyleBox) -> Color:
	if s is StyleBoxFlat:
		var f := s as StyleBoxFlat
		return f.bg_color if f.draw_center else Color.TRANSPARENT
	if s is StyleBoxTexture:
		var t := s as StyleBoxTexture
		if not _images.has(t.texture):
			_images[t.texture] = t.texture.get_image()
		var img: Image = _images[t.texture]
		var c := t.region_rect.get_center()
		return img.get_pixel(int(c.x), int(c.y)).srgb_to_linear().linear_to_srgb() if img else Color.TRANSPARENT
	return Color.TRANSPARENT


var _images := {}


func _contrast(text: Color, style: StyleBox, backdrops: Array[Color], where: String, edge := Color.TRANSPARENT) -> void:
	var fill := _fill_of(style) if style else Color.TRANSPARENT
	if not check(fill.a > 0.0 or edge.a > 0.0, "%s has no style to measure" % where):
		return
	for under: Color in backdrops:
		var bg := under.lerp(Color(fill, 1.0), fill.a)
		bg = bg.lerp(Color(edge, 1.0), edge.a)
		var r := _ratio(text, bg)
		check(r >= MIN_CONTRAST, "%s text contrast %.2f:1 over %s" % [where, r, under.to_html(false)])


func _ratio(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## ui/theme.tres (from design.json) is the one place HUD colours come from. theme_builder.gd and atlas.gd (the shapes
## it bakes) read the tokens, so they are the scripts allowed to make colours; Color.TRANSPARENT and Color.WHITE (no
## tint: an atlas shape keeps its own colour) are allowed everywhere.
func _no_colour_literals(dir: String) -> void:
	var re := RegEx.create_from_string("Color\\(|Color\\.(?!TRANSPARENT|WHITE)[A-Z]|#[0-9a-fA-F]{6}\\b|Color\\.html|color\\(\"[^\"]+\", *[0-9.]+\\)")
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f in ["theme_builder.gd", "atlas.gd"]:
			continue
		var src := FileAccess.get_file_as_string(dir + f)
		for line: String in src.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			check(re.search(line) == null, "%s%s has a colour literal: %s" % [dir, f, line.strip_edges()])
