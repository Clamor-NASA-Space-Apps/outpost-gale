extends "res://addons/forge/test.gd"
## The settings screen (ui/settings.gd): godot --headless --path . -s tests/settings_test.gd --fixed-fps 60
## Four tabs that switch pages, five preset cards, each preset named by every fine-tune row, a fine-tune pick that goes
## on a moment later (or on close) and saves with a "Saved" mark, every former option still there, the Esc chip that
## closes it, the choices kept across a restart (old saves map to the new presets), touch targets on a phone either
## way up, and nothing it adds is game state.

const Settings := preload("res://ui/settings.gd")
const HouseStyle := preload("res://addons/forge/house_style.gd")
const FILE := "user://settings_test.cfg"
const MSAA := {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}

var game: Node3D
var s: CanvasLayer


func _init() -> void:
	watchdog = 240.0


func knob(k: String) -> Dictionary:
	return HouseStyle.knobs(game.design)[k]


## What sets how sharp and how big the 2D is drawn: the canvas transform, the window's stretch, 2D anti-aliasing, the
## HUD's and this screen's own scale.
func _ui_shape() -> Array:
	var v := game.get_viewport()
	return [v.get_final_transform(), v.size, root.content_scale_factor, root.content_scale_size, v.msaa_2d, v.use_hdr_2d,
		v.snap_2d_transforms_to_pixel, game.hud.scale, s.root.scale]


func settle() -> void:
	for i in 600:
		if not game.busy():
			return
		await process_frame
	check(false, "the cover came down")


func start() -> void:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	s = game.settings
	await settle()


func sun() -> DirectionalLight3D:
	for n: Node in game.get_children():
		if n is DirectionalLight3D and n.has_meta("house_rig"):
			return n
	return null


## Pick option `name` of fine-tune row `r` with its segment, as a player would.
func pick(r: String, name: String) -> void:
	var names: Array = Settings.ADVANCED[r].map(func(o: Array) -> String: return o[0])
	var i := names.find(name)
	if check(i >= 0 and s.rows[r][i].is_visible_in_tree(), "%s has a %s segment on screen" % [r, name]):
		s.rows[r][i].pressed.emit()
	check(s.current(r) == i and s.rows[r][i].button_pressed, "%s shows %s picked" % [r, name])


func on_screen(c: Control) -> bool:
	return c.is_visible_in_tree() and root.get_visible_rect().encloses(c.get_global_rect())


func play() -> bool:
	DirAccess.remove_absolute(FILE)
	Settings.file = FILE
	await start()
	var view := game.get_viewport()
	check(not s.is_open(), "closed at start")
	click(s.gear.get_global_rect().get_center())
	await frames(1)
	check(s.is_open(), "the gear opens it")
	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(not s.is_open(), "Esc closes it")
	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(s.is_open(), "Esc opens it")

	# the Graphics tab: a card per preset, fine tune beside; the other tabs hold sound, keys and the screen switches
	await frames(2)
	check(s.page == 0 and s.pages[0].is_visible_in_tree() and s.tabs[0].button_pressed, "it opens on Graphics")
	check(s.cards.keys() == game.design.quality.keys(), "a card per preset, weakest first (%s)" % [s.cards.keys()])
	for id: String in s.cards:
		check(Settings.PRESETS.has(id) and on_screen(s.cards[id]), "preset %s has a name, an icon and a line, on screen" % id)
	check(s.cards[game.quality].button_pressed and s.cards[game.quality].get_meta("check").visible, "the preset in force is checked")
	check(s.rows.size() == Settings.ADVANCED.size() and s.rows.size() <= 6, "six fine-tune rows (%d)" % s.rows.size())
	for r: String in s.rows:  # every option of the old Advanced rows is a segment
		check(s.rows[r].size() == Settings.ADVANCED[r].size() and s.rows[r].all(func(b: Button) -> bool: return b.is_visible_in_tree()), "%s shows every option" % r)
	var tab_has := [s.cards.values()[0], s.sliders.music, null, s.fps_buttons[0]]
	for i: int in s.tabs.size():
		s.tabs[i].pressed.emit()
		await frames(2)
		check(s.page == i and s.tabs[i].button_pressed and s.pages.filter(func(p: Control) -> bool: return p.visible).size() == 1, "tab %s opens its page alone" % s.tabs[i].text)
		if tab_has[i]:
			check(on_screen(tab_has[i]), "tab %s holds its options" % s.tabs[i].text)
	check(s.pages[2].find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == "E"), "Controls lists the keys (E for Use)")
	for k: String in ["master", "music", "effects", "interface"]:
		check(s.sliders.has(k), "a slider for %s" % k)
	var cues: Array[String] = []
	s.cue.connect(func(n: String) -> void: cues.append(n))
	s.tabs[1].mouse_entered.emit()
	s.tabs[1].pressed.emit()
	s.tabs[0].pressed.emit()
	check(cues == ["tick", "select", "select"], "a hover ticks, a pick selects (%s)" % [cues])
	check(OS.has_feature("web_ios") or s.full_buttons.size() == 2, "a full screen switch")
	s.tabs[0].pressed.emit()
	await frames(2)
	check(on_screen(s.close_button) and s.close_button.get_global_rect().size.y >= 48.0, "the Esc chip is on screen, a 48 px target")
	click(s.close_button.get_global_rect().get_center())
	await frames(1)
	check(not s.is_open(), "the Esc chip closes it")
	s.open()
	await frames(2)

	# every preset names one choice in every row, so no row reads "Custom" before the player touches it; and a preset
	# touches the 3D picture only: the HUD and this screen keep their size and sharpness (14 Nov playtest, 94.png)
	var ui := _ui_shape()
	for id: String in game.design.quality:
		s.cards[id].pressed.emit()
		await settle()
		check(game.quality == id and game.overrides.is_empty(), "the %s card puts its preset on" % id)
		check(_ui_shape() == ui, "%s leaves the 2D as it was (%s, was %s)" % [id, _ui_shape(), ui])
		for r: String in s.rows:
			check(s.current(r) >= 0, "%s: the %s row names a choice" % [id, r])
	check(Settings.saved().level == game.quality, "a card is saved")
	check(s.saved_tag.visible, "and says Saved")
	s.cards[HouseStyle.default_quality(game.design)].pressed.emit()
	await settle()

	# a fine-tune pick goes on a moment later, behind the cover, and says Saved
	var msaa_before := view.msaa_3d
	pick("Anti-aliasing", "8x")
	pick("Shadows", "Off")
	pick("Resolution", "50%")
	pick("Frame cap", "30 fps")
	await frames(2)
	check(view.msaa_3d == msaa_before and s.waiting(), "the picks wait a moment, so they share one cover")
	await s.timer.timeout
	check(game.busy(), "then go on behind the cover while shaders compile")
	check(s.saved_tag.visible, "and say Saved")
	await settle()
	check(view.msaa_3d == MSAA[8], "Apply sets anti-aliasing")
	check(not sun().shadow_enabled, "Apply turns shadows off")
	check(is_equal_approx(view.scaling_3d_scale, 0.5), "Apply sets the resolution (%.2f)" % view.scaling_3d_scale)
	check(Engine.max_fps == 30, "Apply sets the frame cap")
	check(not s.waiting(), "nothing waits after")
	check(Settings._same(Settings.saved().overrides.get("msaa"), 8), "the choice is saved (%s)" % [Settings.saved().overrides])
	pick("Effects", "Low")
	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(not s.is_open() and game.busy(), "Esc closes and puts the cover up")
	await settle()
	check(Settings._same(knob("glow").value, 0.0), "Esc applies what waits at once")  # behind the cover (set_graphics)
	s.open()

	# sound and the FPS switch apply at once
	s.sliders.music.value = 50
	s.sliders.master.value = 20
	s.sliders.interface.value = 30
	await frames(2)
	check(is_equal_approx(game.audio.volume.interface, 0.3) and is_equal_approx(Settings.saved().volume.interface, 0.3), "the interface slider sets and saves its level")
	check(is_equal_approx(game.audio.volume.music, 0.5), "the music slider sets its level")
	var music_db: float = game.audio.t.bus_db.Music + linear_to_db(0.5)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - music_db) < 0.1, "the Music bus follows")
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.2)) < 0.1, "the Master bus follows")
	s.fps_buttons[1].pressed.emit()
	check(not game.fps_label.visible and Settings.saved().fps == false and s.fps_buttons[1].button_pressed, "Show FPS off hides the counter, saved")

	# kept per device, and read back by a fresh start
	var kept: Dictionary = game.overrides.duplicate()
	var level: String = game.quality
	await stop()
	game.free()
	await frames(2)
	await start()
	check(game.quality == level and Settings._same_dict(game.overrides, kept), "a restart starts on the saved choices (%s)" % [game.overrides])
	check(view.msaa_3d == MSAA[int(knob("msaa").value)], "and the engine with them")
	check(is_equal_approx(game.audio.volume.music, 0.5) and is_equal_approx(game.audio.volume.get("interface", 0.0), 0.3) and not game.fps_label.visible, "and the saved sound and FPS switch")

	# reset, and a preset undoes the player's frame pacing
	s.open()
	s.cards[game.quality].pressed.emit()  # the card in force is the reset
	await settle()
	check(game.overrides.is_empty() and s.draft.is_empty(), "its preset card clears the player's choices")
	check(Engine.max_fps == 0, "and the frame cap with them")
	s.fps_buttons[0].pressed.emit()

	# touch targets: a phone in landscape (2400 x 1080, 1600 x 720 on the canvas) and in portrait, every tab
	s.phone = true
	for size: Vector2i in [Vector2i(2400, 1080), Vector2i(1080, 2400)]:
		var shown := await shape(size)
		var need := TARGET * minf(shown.size.x, shown.size.y) / 720.0
		for i: int in s.tabs.size():
			s.show_tab(i)
			s._fit()
			await frames(2)
			var small := []
			for b: Button in s.root.find_children("*", "Button", true, false):
				var r := b.get_global_rect()
				if b.is_visible_in_tree() and minf(r.size.x, r.size.y) < need - 0.5:
					small.append("%s %s" % [b.text, r.size])
			check(small.is_empty(), "%s %s: every button is at least %.0f px (%s)" % [size, s.tabs[i].text, need, small])
			check(shown.encloses(s.panel.get_global_rect()), "%s %s: the panel fits the screen" % [size, s.tabs[i].text])
			check(on_screen(s.close_button), "%s: the Esc chip is on screen" % size)
			if i == 0:
				# a phone gets "<  High  >" steppers, one touch target high (56 dp at most), never the 96 px squares
				var dp := 2.0 * minf(shown.size.x, shown.size.y) / 720.0  # canvas px per dp: TARGET (96) is 48 dp
				for r: String in s.steppers:
					var row: Control = s.steppers[r][3]
					var arrows: Control = s.steppers[r][0].get_parent()
					check(row.is_visible_in_tree() and not s.rows[r][0].is_visible_in_tree(), "%s %s: a stepper, not a switch" % [size, r])
					check(arrows.get_global_rect().size.y <= 56.0 * dp + 0.5, "%s %s: the stepper is %.0f px, at most 56 dp" % [size, r, arrows.get_global_rect().size.y])
					# a sideways phone puts the name over the stepper: 13 dp of words, then the 48 dp stepper
					var most := (66.0 if s.wide else 56.0) * dp
					check(row.get_global_rect().size.y <= most + 0.5, "%s %s: the row is %.0f px, at most %.0f" % [size, r, row.get_global_rect().size.y, most])
				if size.x > size.y:
					var need_h: float = s.pages[0].get_combined_minimum_size().y
					check(need_h <= s.scroll.size.y + 0.5, "%s: the Graphics tab fits with no scrolling (%.0f of %.0f px)" % [size, need_h, s.scroll.size.y])
				var deck: Control = s.cards.values()[0].get_parent()
				check(deck.get_global_rect().size.y <= 2.0 * 90.0 * 2.0 * minf(shown.size.x, shown.size.y) / 720.0 + 0.5, "%s: the device cards stay low (%s)" % [size, deck.get_global_rect().size])
		for l: Label in s.root.find_children("*", "Label", true, false):
			check(l.text.split(" ", false).size() <= 8, "at most 8 words: '%s'" % l.text)
	# a stepper walks the options and stops at the ends
	var r0: String = s.steppers.keys()[0]
	s.choose(r0, 0)
	s.steppers[r0][2].pressed.emit()
	check(s.current(r0) == 1 and s.steppers[r0][1].text == Settings.ADVANCED[r0][1][0], "> steps %s to its second option (%s)" % [r0, s.steppers[r0][1].text])
	s.steppers[r0][0].pressed.emit()
	check(s.current(r0) == 0 and s.steppers[r0][0].disabled, "< steps back, and stops at the first")
	s.show_tab(0)
	await shape(SHAPES[0])
	s.phone = false
	s._fit()

	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(not s.is_open(), "Esc closes it again")
	var allowed: Array = load("res://tests/run.gd").get_script_constant_map().ALLOWED
	for k: String in game.render_game_to_text():
		check(k in allowed, "render_game_to_text() has '%s': no game state" % k)
	await stop()

	# a save from before the five presets: its level maps across, its hidden knobs are dropped
	var c := ConfigFile.new()
	c.set_value("graphics", "level", "high")
	c.set_value("graphics", "overrides", {"detail": "off", "msaa": 4})
	c.save(FILE)
	var old := Settings.saved()
	check(old.level == "gaming" and old.overrides.is_empty(), "an old save maps to a new preset, no hidden knobs (%s)" % [old])
	DirAccess.remove_absolute(FILE)
	return true


## The sounds stop as on a window close, so the audio server lets go of them before the game goes.
func stop() -> void:
	game.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames(2)
