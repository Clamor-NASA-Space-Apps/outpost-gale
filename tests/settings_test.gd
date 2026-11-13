extends "res://addons/forge/test.gd"
## The settings screen (ui/settings.gd): godot --headless --path . -s tests/settings_test.gd --fixed-fps 60
## Five preset cards, each preset named by every Advanced row, an Advanced choice waits for an Apply that is always on
## screen and then saves with a "Saved" mark, the choices survive a restart (old saves map to the new presets), the
## buttons are touch targets on a phone either way up, and nothing it adds is game state.

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


## Pick option `name` of Advanced row `r` with its arrows, as a player would.
func pick(r: String, name: String) -> void:
	var names: Array = Settings.ADVANCED[r].map(func(o: Array) -> String: return o[0])
	for i in 8:
		var at: int = s.current(r)
		if at >= 0 and names[at] == name:
			return
		(s.rows[r].plus if at < names.find(name) else s.rows[r].minus).pressed.emit()
	check(false, "%s reaches %s" % [r, name])


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

	# the main page: a card per preset, the FPS switch, sound; Advanced folded away and short
	check(s.cards.keys() == game.design.quality.keys(), "a card per preset, weakest first (%s)" % [s.cards.keys()])
	for id: String in s.cards:
		check(Settings.PRESETS.has(id), "preset %s has a name, an icon and a line" % id)
	check(s.cards[game.quality].button_pressed and s.cards[game.quality].get_meta("check").visible, "the preset in force is checked")
	check(not s.advanced.is_visible_in_tree(), "Advanced starts folded")
	check(s.rows.size() <= 6, "at most six Advanced choices (%d)" % s.rows.size())
	for k: String in ["master", "music", "effects"]:
		check(s.sliders.has(k), "a slider for %s" % k)
	await frames(2)
	check(on_screen(s.apply_button) and on_screen(s.reset_button), "Apply and Reset are on screen with nothing changed")

	# every preset names one choice in every row, so no row reads "Custom" before the player touches it
	for id: String in game.design.quality:
		s.cards[id].pressed.emit()
		await settle()
		check(game.quality == id and game.overrides.is_empty(), "the %s card puts its preset on" % id)
		for r: String in s.rows:
			check(s.current(r) >= 0, "%s: the %s row names a choice" % [id, r])
	check(Settings.saved().level == game.quality, "a card is saved")
	check(s.saved_tag.visible, "and says Saved")
	s.cards[HouseStyle.default_quality(game.design)].pressed.emit()
	await settle()

	# 13 Nov playtest: "doesn't show the save button even after I save something"
	s.fold_button.pressed.emit()
	await frames(2)
	check(s.advanced.is_visible_in_tree(), "Advanced folds out")
	var msaa_before := view.msaa_3d
	pick("Anti-aliasing", "8x")
	pick("Shadows", "Off")
	pick("Resolution", "50%")
	pick("Frame cap", "30 fps")
	await frames(2)
	check(view.msaa_3d == msaa_before, "a choice waits for Apply")
	check(s.rows["Anti-aliasing"].wait.visible, "and says so")
	check(on_screen(s.apply_button) and not s.apply_button.disabled, "Apply is offered, on screen")
	s.apply_button.pressed.emit()
	check(game.busy(), "Apply puts the cover up while shaders compile")
	check(s.saved_tag.visible, "Apply says Saved")
	await settle()
	check(view.msaa_3d == MSAA[8], "Apply sets anti-aliasing")
	check(not sun().shadow_enabled, "Apply turns shadows off")
	check(is_equal_approx(view.scaling_3d_scale, 0.5), "Apply sets the resolution (%.2f)" % view.scaling_3d_scale)
	check(Engine.max_fps == 30, "Apply sets the frame cap")
	check(s.apply_button.disabled and on_screen(s.apply_button) and not s.rows["Anti-aliasing"].wait.visible, "nothing waits after Apply")
	check(Settings._same(Settings.saved().overrides.get("msaa"), 8), "the choice is saved (%s)" % [Settings.saved().overrides])
	pick("Effects", "Low")
	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(not s.is_open() and game.busy(), "Esc closes and puts the cover up")
	await settle()
	check(Settings._same(knob("glow").value, 0.0), "Esc applies what waits")  # behind the cover (set_graphics)
	s.open()

	# sound and the FPS switch apply at once
	s.sliders.music.value = 50
	s.sliders.master.value = 20
	await frames(2)
	check(is_equal_approx(game.audio.volume.music, 0.5), "the music slider sets its level")
	var music_db: float = game.audio.t.bus_db.Music + linear_to_db(0.5)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - music_db) < 0.1, "the Music bus follows")
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.2)) < 0.1, "the Master bus follows")
	s.fps_button.pressed.emit()
	check(not game.fps_label.visible and Settings.saved().fps == false, "Show FPS off hides the counter, saved")

	# kept per device, and read back by a fresh start
	var kept: Dictionary = game.overrides.duplicate()
	var level: String = game.quality
	await stop()
	game.free()
	await frames(2)
	await start()
	check(game.quality == level and Settings._same_dict(game.overrides, kept), "a restart starts on the saved choices (%s)" % [game.overrides])
	check(view.msaa_3d == MSAA[int(knob("msaa").value)], "and the engine with them")
	check(is_equal_approx(game.audio.volume.music, 0.5) and not game.fps_label.visible, "and the saved sound and FPS switch")

	# reset, and a preset undoes the player's frame pacing
	s.open()
	s.reset_button.pressed.emit()
	await settle()
	check(game.overrides.is_empty() and s.draft.is_empty(), "reset clears the player's choices")
	check(Engine.max_fps == 0, "and the frame cap with them")
	s.fps_button.pressed.emit()

	# touch targets: a phone in landscape (2400 x 1080, 1600 x 720 on the canvas) and in portrait, Advanced open
	s.phone = true
	s.advanced.visible = true
	for size: Vector2i in [Vector2i(2400, 1080), Vector2i(1080, 2400)]:
		var shown := await shape(size)
		s._fit()
		await frames(2)
		var need := TARGET * minf(shown.size.x, shown.size.y) / 720.0
		var small := []
		for b: Button in s.root.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and b.get_global_rect().size.y < need - 0.5:
				small.append(b.text)
		check(small.is_empty(), "%s: every button is at least %.0f px tall (%s)" % [size, need, small])
		check(shown.encloses(s.panel.get_global_rect()), "%s: the panel fits the screen" % size)
		check(on_screen(s.apply_button), "%s: Apply is on screen" % size)
		for l: Label in s.root.find_children("*", "Label", true, false):
			check(l.text.split(" ", false).size() <= 8, "at most 8 words: '%s'" % l.text)
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
