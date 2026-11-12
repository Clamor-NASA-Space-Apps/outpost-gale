extends "res://addons/forge/test.gd"
## The settings screen (ui/settings.gd): godot --headless --path . -s tests/settings_test.gd --fixed-fps 60
## Every knob has a row, a row's buttons change the knob and the engine, a shader knob waits for Apply, reset goes
## back to the preset, the choices survive a restart, the buttons are touch targets on a phone either way up,
## and nothing it adds is game state.

const Settings := preload("res://ui/settings.gd")
const HouseStyle := preload("res://addons/forge/house_style.gd")
const FILE := "user://settings_test.cfg"
const MSAA := {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}

var game: Node3D
var s: CanvasLayer


func _init() -> void:
	watchdog = 180.0


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

	var kn := HouseStyle.knobs(game.design)
	for k: String in kn:
		if check(s.rows.has(k), "a row for knob %s" % k):
			check(s.rows[k].mark.get_parent().get_parent().is_visible_in_tree(), "the %s row is shown" % k)
	for k: String in ["master", "music", "effects"]:
		check(s.sliders.has(k), "a slider for %s" % k)

	# a live knob: the engine changes at once, the row says it differs from the preset
	var before: Variant = knob("msaa").value
	s.rows.msaa.plus.pressed.emit()
	check(not Settings._same(knob("msaa").value, before), "msaa steps up (%s to %s)" % [before, knob("msaa").value])
	check(view.msaa_3d == MSAA[int(knob("msaa").value)], "the viewport's msaa follows (%d)" % view.msaa_3d)
	check(s.rows.msaa.mark.visible, "msaa is marked changed")
	s.rows.scale.minus.pressed.emit()
	check(knob("scale").value < 1.0 and is_equal_approx(view.scaling_3d_scale, knob("scale").value), "the 3D scale follows (%.2f)" % view.scaling_3d_scale)
	s.rows.shadowMap.minus.pressed.emit()
	check(int(sun().get_meta("shadow_map")) == int(knob("shadowMap").value), "the sun's shadow map follows (%s)" % sun().get_meta("shadow_map"))
	check(not game.busy(), "a live knob raises no cover")

	# a shader knob waits for Apply, then compiles behind the cover
	before = knob("shadows").value
	s.rows.shadows.minus.pressed.emit()
	check(Settings._same(knob("shadows").value, before) and s.rows.shadows.wait.visible, "shadows wait for Apply")
	check(not s.apply_button.disabled, "Apply is offered")
	s.apply_button.pressed.emit()
	check(not Settings._same(knob("shadows").value, before), "Apply sets shadows (%s)" % knob("shadows").value)
	check(game.busy(), "the cover is up while shaders compile")
	await settle()
	check(s.apply_button.disabled and not s.rows.shadows.wait.visible, "nothing waits after Apply")
	s.rows.fog.toggle.pressed.emit()
	s.rows.fog.toggle.pressed.emit()
	check(s.pending.is_empty(), "a toggle pressed twice is back where it was")

	# sound
	s.sliders.music.value = 50
	s.sliders.master.value = 20
	await frames(2)
	check(is_equal_approx(game.audio.volume.music, 0.5), "the music slider sets its level")
	var music_db: float = game.audio.t.bus_db.Music + linear_to_db(0.5)
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - music_db) < 0.1, "the Music bus follows")
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.2)) < 0.1, "the Master bus follows")

	# kept per device, and read back by a fresh start
	var saved := Settings.saved()
	check(saved.level == game.quality, "the level is saved")
	check(saved.overrides.size() == game.overrides.size() and game.overrides.keys().all(
		func(k: String) -> bool: return Settings._same(saved.overrides.get(k), game.overrides[k])), "the knobs are saved (%s)" % [saved.overrides])
	check(is_equal_approx(saved.volume.music, 0.5) and is_equal_approx(saved.volume.master, 0.2), "the levels are saved")
	var kept: Dictionary = game.overrides.duplicate()
	await stop()
	game.free()
	await frames(2)
	await start()
	check(game.overrides.size() == kept.size() and kept.keys().all(
		func(k: String) -> bool: return Settings._same(knob(k).value, kept[k])), "a restart starts on the saved knobs")
	check(view.msaa_3d == MSAA[int(knob("msaa").value)], "and the engine with them")
	check(is_equal_approx(game.audio.volume.music, 0.5), "and the saved music level")

	# reset and presets
	s.open()
	s.reset_button.pressed.emit()
	await settle()
	check(game.overrides.is_empty(), "reset clears the player's knobs")
	for k: String in HouseStyle.KNOBS:
		check(Settings._same(knob(k).value, knob(k).preset), "after reset %s is the preset's" % k)
		check(not s.rows[k].mark.visible, "after reset %s is not marked" % k)
	s.presets.low.pressed.emit()
	await settle()
	check(game.quality == "low" and int(knob("shadowMap").value) == 1024, "the Low preset is in force")
	check(Settings.saved().level == "low", "and saved")

	# touch targets: a phone in landscape (2400 x 1080, 1600 x 720 on the canvas) and in portrait
	s.phone = true
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
		for l: Label in s.root.find_children("*", "Label", true, false):
			check(l.text.split(" ", false).size() <= 8, "at most 8 words: '%s'" % l.text)
	await shape(SHAPES[0])

	action(&"settings")
	await frames(1)
	action(&"settings", false)
	check(not s.is_open(), "Esc closes it again")
	var allowed: Array = load("res://tests/run.gd").get_script_constant_map().ALLOWED
	for k: String in game.render_game_to_text():
		check(k in allowed, "render_game_to_text() has '%s': no game state" % k)
	DirAccess.remove_absolute(FILE)
	await stop()
	return true


## The sounds stop as on a window close, so the audio server lets go of them before the game goes.
func stop() -> void:
	game.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames(2)
