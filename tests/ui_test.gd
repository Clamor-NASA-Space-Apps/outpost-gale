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
const NARROW := 360.0  # the narrowest phone width in dp a card must fit
const Delay := preload("res://ui/radio_delay.gd")
const Fake := preload("res://ui/fake_state.gd")


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
				elif c is Label:
					labels += 1
					var l := c as Label
					var words := l.text.split(" ", false).size()
					check(words <= MAX_WORDS or "Bubble" in String(g.get_path_to(c)), "%s has %d words: '%s'" % [where, words, l.text])
					# text over the glass carries a dark edge (the theme's Label outline): it is measured against that edge
					# laid over the panel and the world, since the edge is what touches every letter
					var edge := l.get_theme_color("font_outline_color") if l.get_theme_constant("outline_size") >= 2 else Color.TRANSPARENT
					var panel := _panel_of(l)
					if check(panel != null or edge.a > 0.0, "%s sits on the bare world with no panel or edge behind it" % where):
						_contrast(l.get_theme_color("font_color"), panel, backdrops, where, edge)
	check(buttons > 0, "the gallery has buttons")
	print("checked %d buttons and %d labels over %d views" % [buttons, labels, g.PAGES.size() * 2])
	var toast: Script = load("res://ui/components/alert_toast.gd")
	var pulse: float = toast.get_script_constant_map().PULSE_SECONDS
	check(1.0 / pulse <= MAX_FLASHES, "the alert pulses %.1f times a second" % (1.0 / pulse))
	g.queue_free()
	await _bound()
	await _narrow()
	_delay()
	await _sleep_picker()
	_no_colour_literals("res://ui/")
	_no_colour_literals("res://ui/components/")
	_loading_tokens()
	return true


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
	check(m.power == 24 and m.health == 99, "bound meters: power %d (want 24), health %d (want 99)" % [m.power, m.health])
	check(h.snapshot().alert == "Solar storm", "a new event raises an alert, got '%s'" % h.snapshot().alert)
	fake.set_values({"battery_pct": 81.6, "o2_kg": 16.7, "dose_msv": 100.0, "sol": 13, "hour": 14.5, "suit_air_min": 300.0})
	var s: Dictionary = h.snapshot()
	check(s.meters.power == 82, "power follows battery_pct: %d" % s.meters.power)
	check(s.meters.life == 50 and s.meters.lifeIcon == "oxygen", "life support is the shortest supply (oxygen at half): %s" % [s.meters])
	check(s.meters.health == 90, "100 mSv takes crew health to 90, got %d" % s.meters.health)
	check(s.sol == 13 and s.time == "14:30" and s.suit == "5 h 00 min", "clock and suit air: %s %s '%s'" % [s.sol, s.time, s.suit])
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
	check(h.snapshot().card == "EventCard" and h.is_open(), "offer_choice opens the choice card")
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
	h.show_causes([{"label": "Rest the oxygen maker", "sol": 4, "effect": {"o2_kg": -6.0}}, {"label": "Greenhouse lights on", "sol": 6, "effect": {"battery_pct": -30.0}}, "Heaters off"])
	await frames(2)
	var chips: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(h.snapshot().card == "MissionLost" and "Rest the oxygen maker" in chips and "Sol 6" in chips and "Heaters off" in chips, "the causes card shows the three causes: %s" % [chips])
	h.show_sources()
	await frames(2)
	var src: Array = h.card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("COMPUTED" in src and "ARCHIVED" in src and "Oxygen 16.7 kg" in src, "the sources card tags each data value: %s" % [src])
	h.source_button.pressed.emit()
	h.close_card()
	h.queue_free()
	fake.queue_free()
	await frames(1)


## The compass, minimap, waypoint, Today, prompt and full map follow a stand-in camera and hero; each HUD event
## plays its own cue once.
func _hud_parts(h: Control, cues: Array[String]) -> void:
	var cam := Camera3D.new()
	var body := Node3D.new()
	var pip := Node3D.new()
	for n: Node3D in [cam, body, pip]:
		root.add_child(n)
	body.position = Vector3(0, 0, 9)  # the spawn
	body.rotation.y = -deg_to_rad(270.0)  # facing west
	cam.position = Vector3(0, 1.6, 9)
	cam.rotation.y = body.rotation.y
	pip.position = Vector3(-5, 0, 4)
	h.bind_view(cam, body)
	h.bind_speaker(pip, cam)
	cues.clear()
	h.set_objective("greenhouse")  # (-11, 5.2): 11.7 m away, a little north of west
	h.set_objective("greenhouse")
	await process_frame
	await process_frame
	var s: Dictionary = h.snapshot()
	check(s.heading.begins_with("270°") and s.heading.ends_with("W"), "the compass reads the camera's heading: '%s'" % s.heading)
	check(s.objective.m == 12 and s.objective.label == "Greenhouse" and not s.objective.docked, "the waypoint names the place and its distance on screen: %s" % [s.objective])
	var want := Hud.bearing(Vector3(-11, 0, 5.2 - 9))
	check(absf(float(h.compass.marks.objective) - want) < 0.5, "the compass marks the objective at %.0f, want %.0f" % [h.compass.marks.objective, want])
	var d: Vector2 = h.minimap.to_disc(Vector2(-11, 5.2), 999.0)
	check(d.y < 0.0 and absf(d.x) < absf(d.y), "on the minimap the objective ahead is up: %s" % d)
	check(s.area == "Landing plain", "the area under the minimap: %s" % s.area)
	body.rotation.y = 0.0
	cam.rotation.y = 0.0  # now facing north: the greenhouse is behind-left, off screen
	cam.position = Vector3(0, 1.6, 9)
	await process_frame
	await process_frame
	check(h.snapshot().objective.docked, "off screen the waypoint docks at an edge")
	h.set_tasks([{"label_id": "morning_check", "state": "now"}, {"label_id": "brush_dust", "state": "next"}])
	h.set_tasks([{"label_id": "morning_check", "state": "done"}, {"label_id": "brush_dust", "state": "now"}])
	check(h.snapshot().tasks.size() == 2 and h.snapshot().tasks[0][1] == "done", "Today lists the tasks: %s" % [h.snapshot().tasks])
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
	action(&"ui_cancel")
	action(&"ui_cancel", false)
	await process_frame
	check(not h.map_open(), "Esc closes the map")
	h.complete_objective()
	check(h.snapshot().objective.is_empty(), "a done objective clears its waypoint")
	h.say("follow_me")
	h.offer_choice("choice_power_morning", [{"text": "A", "costs": {}}, {"text": "B", "costs": {}}])
	h.card.chosen.emit(0)
	h.show_ledger({"sols": 1})
	h.close_card()
	h.bubble.hide()
	var want_cues := ["objective_new", "task_tick", "map_open", "map_close", "objective_done", "pip_open", "choice_open", "choice_made", "ledger_open"]
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
	await frames(roundi(60.0 * b.HOLD_MIN_S) + 10)
	check(done[0] and h.snapshot().subtitle == "", "the bubble goes once read and says so")
	cam.queue_free()
	pip.queue_free()


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
			c.options.append({"text": "A third choice with longer words", "costs": {"o2_kg": -2.5, "battery_pct": -10}})
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
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	check(bg.to_html(false) == Hud.color("surface").to_html(false), "the boot splash colour %s is not the surface token" % bg.to_html(false))


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
		var flat := s as StyleBoxFlat
		if flat and flat.draw_center and flat.bg_color.a > 0.0:
			return flat
		at = at.get_parent()
	return null


func _contrast(text: Color, style: StyleBox, backdrops: Array[Color], where: String, edge := Color.TRANSPARENT) -> void:
	var flat := style as StyleBoxFlat
	if not check(flat != null or edge.a > 0.0, "%s has no flat style to measure" % where):
		return
	for under: Color in backdrops:
		var bg := under.lerp(Color(flat.bg_color, 1.0), flat.bg_color.a) if flat else under
		bg = bg.lerp(Color(edge, 1.0), edge.a)
		var r := _ratio(text, bg)
		check(r >= MIN_CONTRAST, "%s text contrast %.2f:1 over %s" % [where, r, under.to_html(false)])


func _ratio(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## ui/theme.tres (from design.json) is the one place HUD colours come from. theme_builder.gd reads the
## tokens, so it is the one script allowed to make colours; Color.TRANSPARENT is allowed everywhere.
func _no_colour_literals(dir: String) -> void:
	var re := RegEx.create_from_string("Color\\(|Color\\.(?!TRANSPARENT)[A-Z]|#[0-9a-fA-F]{6}\\b|Color\\.html|color\\(\"[^\"]+\", *[0-9.]+\\)")
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f == "theme_builder.gd":
			continue
		var src := FileAccess.get_file_as_string(dir + f)
		for line: String in src.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			check(re.search(line) == null, "%s%s has a colour literal: %s" % [dir, f, line.strip_edges()])
