extends Control
## The play HUD on the visor (design/mockups/hud.png): the status card (sol, clock, three meters), Today's tasks, the
## compass tape, the minimap and the full map (M), the objective's waypoint, PIP's speech bubble, the use prompt,
## visor mail, an alert, and the cards (a choice, the sleep ledger, the causes of a lost mission, where the numbers
## come from). It holds no rules: bind() a node with `signal changed(state: Dictionary)` (the sim's state keys) and
## it shows what it gets. Every HUD event emits `cue(name)` once (audio/audio.gd UI_SOUNDS); the sandbox plays it.
## Under a CanvasLayer it fills the screen and draws PHONE_SCALE larger on a touch screen, with margins clear of the
## settings gear and the back swipe; inside another Control (ui/hud_gallery.tscn) it fills that.

signal chosen(id: String, index: int)
signal retry
signal ledger_closed
signal cue(name: String)  # a HUD sound: audio.ui(name)
signal map_toggled(open: bool)
signal dismissed(line_id: String)  # a fact line (say(id, {fact = true})) closed by Enter or a tap

const Hud := preload("res://ui/hud.gd")
const Delay := preload("res://ui/radio_delay.gd")
const SUPPLIES := ["o2_kg", "water_kg", "food_kg"]
# Crew health is radiation only, and reaches 0 at 1 Sv: about +5% lifetime risk of fatal cancer, and what a 500-day
# stay at Gale adds up to (factcheck rows 32, 33). A 30-sol stay at 0.67 mSv a day costs about 2 points.
const DOSE_FULL_MSV := 1000.0
const GAIN_STEP := 1.05  # solar power rising 5% between two states shows as a "+kW" beside the power meter
const GAIN_MIN_KW := 0.1  # and by this much: at dawn a tiny solar number climbs fast in percent
const TOAST_S := 6.0
const ALERT_GAP_S := 6.0  # the alert and danger cues repeat no more often than this
const PLACES := preload("res://ui/components/full_map.gd").PLACES
# What the "where this comes from" card says beside each number, with its factcheck row
const SOURCES := {
	"battery_pct": "Sunlight 43% of Earth's: NASA fact sheet",  # row 15
	"o2_kg": "0.84 kg each a day: NASA BVAD",  # row 23
	"water_kg": "3.2 kg each a day: NASA BVAD",  # row 25
	"food_kg": "2.39 kg each a day: NASA BVAD",  # row 112
	"dose_msv": "0.67 mSv a day at Gale: SwRI",  # row 32
	"health": "0 at 1 Sv, +5% cancer risk: SwRI",  # row 33
	"panel_dust": "About 0.2% a sol: Lorenz 2021",  # row 180
	"sol": "NASA's first Mars stay: 30 sols",  # ICES-2023-265, workspace fact table
}

var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))
var state := {}
var _power_in := 0.0
var _power_hour := 0.0
var stock := {}  # the most of each supply seen so far: Life support's 100%
var start_unix := Time.get_unix_time_from_system()  # sol 1 is the day the game is played
var frame := Control.new()  # everything sits inside its margins
var meters := {}  # power, life, health
var clock: Control  # the status card: sol, time, suit air
var status: Control
var tasks: Control
var compass: Control
var minimap: Control
var waypoint: Control
var prompt: Control
var full_map: Control  # open while the full map shows, else null
var camera: Camera3D
var hero: Node3D
var pip: Node3D
var objective := ""  # the landmark id (or "pip", or a tracked node's name) the waypoint points at, "" for none
var objective_node: Node3D  # a moving objective (set_objective_node), else null
var _task_states := {}  # label_id -> state, as last set
var touch := DisplayServer.is_touchscreen_available():
	set(v):
		touch = v
		if minimap:
			minimap.touch = v
			prompt.touch = v
			# a phone's Use and Hop buttons hold the bottom right, so there the prompt sits at the bottom centre
			prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if v else Control.SIZE_SHRINK_END
			# 48 px under a mouse, 96 scene px for a finger (addons/forge/test.gd TARGET) under PHONE_SCALE
			var b := ceilf(96.0 / Hud.PHONE_SCALE) if v else 48.0
			source_button.custom_minimum_size = Vector2(b, b)
			gear_slot.custom_minimum_size = Vector2(b, b)
			for g: Node in gear_slot.get_children():
				(g as Control).custom_minimum_size = Vector2(b, b)
				(g as Control).size = Vector2(b, b)
var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
var _cue_at := {}  # cue name -> the time it last played
var mail: Control
var mail_sol := -1  # the sol the mail went out, -1 for none
var toast: Control
var bubble: Control  # PIP's speech bubble (components/speech_bubble.gd)
var source_button := Button.new()
var gear_slot := Control.new()  # where the settings gear sits; dock_gear() puts the real one in it
var modal := Control.new()  # a card and the scrim that keeps clicks off the world behind it
var holder := CenterContainer.new()
var scrim := ColorRect.new()
var side_card := false  # the open card is a choice: compact, beside the hero, clear of PIP's bubble, no scrim
var card: Control  # the open card, or null
var _events := {}
var _failing: Array = []
var _toast_left := 0.0


func _ready() -> void:
	theme = Hud.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_scene("visor_arcs", self).name = "VisorArcs"
	move_child(get_node("VisorArcs"), 0)  # behind everything
	# Containers only, so every part takes its least size again whenever the alert, mail or a task comes and goes.
	# Left: the status card, Today, the alert (clear of the phone's stick). Right: the minimap, the source button under
	# the settings gear's place, the mail below (clear of the phone's action buttons). Bottom right: the use prompt.
	var left := _quiet(Hud.col([], 10))
	status = _scene("status_panel", left)
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clock = status
	meters = status.meters
	tasks = _scene("tasks_card", left)
	tasks.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tasks.hide()
	toast = _scene("alert_toast", left)
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast.hide()
	source_button.name = "SourceButton"
	# the "?" is a label on the button, not its text: then it draws with the other words, not between two shapes
	var q := Hud.label("?", "SolNum")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source_button.add_child(q)
	source_button.tooltip_text = "Where this comes from"
	source_button.theme_type_variation = "ChoiceButton"
	source_button.custom_minimum_size = Vector2(Hud.BUTTON_H, Hud.BUTTON_H)
	source_button.focus_mode = Control.FOCUS_NONE
	source_button.pressed.connect(show_sources)
	# the settings gear and the "?" stack left of the minimap's disc: clear of the disc, the compass and the screen's
	# corner on a laptop and a phone (the gear is the settings screen's own button, docked here by dock_gear())
	gear_slot.name = "GearSlot"
	gear_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons := _quiet(Hud.col([gear_slot, source_button], 12))
	buttons.name = "Buttons"
	buttons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var corner := _quiet(Hud.row([buttons], 14))
	corner.size_flags_horizontal = Control.SIZE_SHRINK_END
	minimap = _scene("minimap", corner)
	minimap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	minimap.pressed.connect(open_map)
	var right := _quiet(Hud.col([corner], 12))
	mail = _scene("ask_earth", right)
	mail.size_flags_horizontal = Control.SIZE_SHRINK_END
	mail.hide()
	for c: Control in [left, right]:
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var top := _quiet(Hud.row([left, Hud.spacer(), right], 16))
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt = load("res://ui/components/prompt.tscn").instantiate()
	prompt.size_flags_horizontal = Control.SIZE_SHRINK_END
	frame.add_child(_quiet(Hud.col([top, prompt], 0)))
	frame.get_child(0).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	compass = _scene("compass")
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	compass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	compass.hide()  # shown once a camera is bound (bind_view)
	waypoint = _scene("waypoint", self)
	bubble = _scene("speech_bubble", self)
	bubble.dismissed.connect(func(id: String) -> void: dismissed.emit(id))  # over the whole screen: it follows PIP, or docks at an edge
	waypoint.avoid = bubble.panel
	modal.name = "Modal"
	modal.hide()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Hud.color("hud-scrim")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(scrim)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(holder)
	get_viewport().size_changed.connect(_fit)
	_fit()
	touch = touch
	# draw order for batching (Hud.layer): each layer's panels, then its shapes, then its words by font; the waypoint
	# and PIP's bubble ride over the panels, the cards and the map over everything
	# (layers 100 apart: a layer's panels, shapes and every font rank fit under the next; 0 is under them all)
	Hud.layer(self, 1)
	Hud.layer(waypoint, 101)
	Hud.layer(bubble, 101)
	Hud.layer(modal, 201)


func _scene(n: String, parent: Control = null) -> Control:
	var c: Control = load("res://ui/components/%s.tscn" % n).instantiate()
	(parent if parent else frame).add_child(c)
	return c


## A layout box lets clicks through to the world (only the HUD's buttons and panels stop them).
func _quiet(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The same sizing as the settings screen (ui/settings.gd _fit), so the HUD and the gear line up.
func _fit() -> void:
	var m := Vector2.ZERO
	if get_parent() is CanvasLayer:
		var phone := DisplayServer.is_touchscreen_available()
		var s := get_viewport().get_visible_rect().size
		var k := maxf(1.0, minf(s.x, s.y) / 720.0) * (Hud.PHONE_SCALE if phone else 1.0)
		scale = Vector2(k, k)
		position = Vector2.ZERO
		size = s / k
		m = Vector2(60.0 / Hud.PHONE_SCALE if phone else 24.0, 20.0)
	else:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = m.x
	frame.offset_top = m.y
	frame.offset_right = -m.x
	frame.offset_bottom = -m.y


## Listen to the rules: `node` has `signal changed(state: Dictionary)`.
func bind(node: Object) -> void:
	node.changed.connect(show_state)
	if node.has_method("state"):
		show_state(node.state())


func show_state(s: Dictionary) -> void:
	state = s
	meters.power.value = roundi(float(s.battery_pct))
	# the sun climbs a fraction of a percent a state; a step this big is a hand at work (a brushed wing). Solar only:
	# the reactor's steady 10 kW hid a wing's +0.4 kW
	var power_in := float(s.get("solar_in_kw", 0.0))
	var hour := float(s.sol) * Hud.SOL_H + float(s.hour)
	if power_in > _power_in * GAIN_STEP and power_in - _power_in > GAIN_MIN_KW and hour - _power_hour < 0.05:  # never in a time-lapse
		meters.power.bump("+%.1f kW" % (power_in - _power_in))
	_power_in = power_in
	_power_hour = hour
	# Life support is the supply that is shortest against the most we have had, and shows that supply's icon
	var worst := ""
	var left := 1.0
	for k: String in SUPPLIES:
		var v := float(s[k])
		stock[k] = maxf(stock.get(k, 0.0), v)
		var f: float = v / stock[k] if stock[k] > 0.0 else 0.0
		if worst == "" or f < left:
			worst = k
			left = f
	meters.life.value = roundi(100.0 * left)
	meters.life.set_icon(Hud.KEYS[worst][0])
	meters.health.value = roundi(100.0 * clampf(1.0 - float(s.dose_msv) / DOSE_FULL_MSV, 0.0, 1.0))
	# the suit's air shows while it runs down (outside), and hides once it is topped up again
	var suit := float(s.get("suit_air_min", -1.0))
	stock.suit = maxf(stock.get("suit", 0.0), suit)
	clock.show_time(int(s.sol), float(s.hour), suit if suit < stock.suit else -1.0)
	if mail_sol >= 0:
		var was: float = mail.progress()
		mail.set_now(float(s.hour) + (int(s.sol) - mail_sol) * Hud.SOL_H)
		if was < 1.0 and mail.progress() >= 1.0:
			_cue("mail")  # the reply is home
	var now := {}
	for e: Dictionary in s.get("events", []):
		now[e.id] = true
		if not _events.has(e.id):
			alert(e.label, "%s data. Tap ? for its source." % ("LIVE" if e.live else "ARCHIVED"))
	_events = now
	var failing: Array = s.get("failing", [])
	for k: String in failing:
		if k not in _failing:
			alert("%s ran out!" % Hud.KEYS.get(k, ["", k])[1], line("failing_" + k), "danger")
	_failing = failing.duplicate()


## PIP's line by id, from data/lines.json. A missing id still shows, as its own placeholder.
func line(id: String) -> String:
	return lines.get(id, "TBD at event: " + id)


## PIP says a line from data/lines.json. It stays until the next line or clear_line(). opts: `keys`, the keys it
## teaches (["W"], ["A", "D"], ["Mouse"], ["Space"], ["Shift"], ["E"], ["M"]), drawn as keycaps under the words (on a
## phone, the touch control's icon or word); `fact` true: it waits for Enter or a tap, then emits dismissed(line_id).
func say(line_id: String, opts := {}) -> void:
	_cue("pip_open")
	bubble.touch = touch
	bubble.speak(line(line_id), line_id, opts.get("keys", []), opts.get("fact", false))


func clear_line() -> void:
	bubble.hide_line()


## PIP speaks from `node`, seen through `camera`: his bubble rides above him on screen.
func bind_speaker(node: Node3D, cam: Camera3D) -> void:
	pip = node
	bubble.follow(node, cam)


## The settings screen's gear button lives in the HUD's button column (left of the minimap), so it never sits on
## the minimap or the compass: ui/settings.gd stops placing it once it has moved.
func dock_gear(gear: Button) -> void:
	gear.get_parent().remove_child(gear)
	gear_slot.add_child(gear)
	gear.position = Vector2.ZERO
	gear.theme_type_variation = &"ChoiceButton"  # the same glass key as the "?" under it
	touch = touch  # sizes it as the "?" beside it
	Hud.layer(gear, 1)


## The play camera and the hero's body: the compass, the minimap, the waypoint and distances follow them.
func bind_view(cam: Camera3D, body: Node3D) -> void:
	camera = cam
	hero = body
	waypoint.follow(cam, body)
	compass.show()


## The objective: a landmark from data/world.json `landmarks`, named by a data/lines.json id (or by the place's own
## name when label_id is ""). The waypoint, the compass and the maps point at it.
func set_objective(landmark_id: String, label_id := "") -> void:
	if landmark_id == "pip" and pip:
		set_objective_node(pip, label_id, "pip")
		return
	if not world.landmarks.has(landmark_id):
		push_error("hud: no landmark '%s' in data/world.json" % landmark_id)
		return
	if landmark_id != objective:
		_cue("objective_new")
	objective = landmark_id
	objective_node = null
	var l: Array = world.landmarks[landmark_id]
	# landmarks carry no height; near the base the hero's own height is close enough for a marker floating over it
	waypoint.point(Vector3(l[0], hero.global_position.y if hero else 0.0, l[1]), line(label_id) if label_id else PLACES.get(landmark_id, landmark_id.capitalize()))


## A moving objective: the waypoint, the compass mark and the maps follow `node` every frame ("PIP  12 m").
func set_objective_node(node: Node3D, label_id := "", id := "") -> void:
	if id == "":
		id = String(node.name)
	if id != objective:
		_cue("objective_new")
	objective = id
	objective_node = node
	waypoint.point_node(node, line(label_id) if label_id else ("PIP" if node == pip else PLACES.get(id, id.capitalize())))


## Where the objective is now (world x, z), or null.
func _objective_xz() -> Variant:
	if objective_node and is_instance_valid(objective_node):
		return Vector2(objective_node.global_position.x, objective_node.global_position.z)
	if objective and world.landmarks.has(objective):
		var l: Array = world.landmarks[objective]
		return Vector2(l[0], l[1])
	return null


## The objective reached: its warm cue, and the waypoint goes.
func complete_objective() -> void:
	if objective:
		_cue("objective_done")
	clear_objective()


func clear_objective() -> void:
	objective = ""
	objective_node = null
	waypoint.hide()


## Today's list: [{label_id, state: "done" | "now" | "next"}], words from data/lines.json. It shows as soon as it has
## a task; a new task arrives with the objective_new cue, a task newly done ticks (task_tick).
func set_tasks(list: Array) -> void:
	var now := {}
	for t: Dictionary in list:
		now[t.label_id] = t.state
	if now.keys().any(func(id: String) -> bool: return not _task_states.has(id)):
		_cue("objective_new")
	if now.keys().any(func(id: String) -> bool: return now[id] == "done" and _task_states.get(id, "") != "done"):
		_cue("task_tick")
	_task_states = now
	tasks.set_tasks(list.map(func(t: Dictionary) -> Array: return [line(t.label_id), t.state]))
	tasks.visible = not list.is_empty()


## The use prompt at the bottom right ("Open the greenhouse"); "" hides it.
func show_prompt(text: String) -> void:
	prompt.say(text)


func map_open() -> bool:
	return full_map != null


## The full map over the play view; M, Esc, its close chip or a second M closes it.
func open_map() -> void:
	if full_map:
		return
	full_map = load("res://ui/components/full_map.tscn").instantiate()
	full_map.width = minf(720.0, size.x - 40.0)
	full_map.height = size.y
	full_map.touch = touch
	_map_marks()
	full_map.closed.connect(close_map)
	add_child(full_map)
	Hud.layer(full_map, 301)
	_take_pointer()  # the map is used with the pointer
	_cue("map_open")
	map_toggled.emit(true)


func close_map() -> void:
	if not full_map:
		return
	full_map.queue_free()
	full_map = null
	_give_pointer()
	_cue("map_close")
	map_toggled.emit(false)


func _map_marks() -> void:
	if hero:
		full_map.hero = Vector2(hero.global_position.x, hero.global_position.z)
		full_map.yaw = Hud.bearing(-hero.global_transform.basis.z)
	full_map.pip = Vector2(pip.global_position.x, pip.global_position.z) if pip else null
	full_map.objective = _objective_xz()


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("map") and not e.is_echo():
		if full_map:
			close_map()
		else:
			open_map()
		get_viewport().set_input_as_handled()
	elif full_map and (e.is_action_pressed("ui_cancel") or InputMap.has_action("settings") and e.is_action_pressed("settings")):
		close_map()  # Esc closes the map before it would open the settings
		get_viewport().set_input_as_handled()


## Every HUD event's sound, once: the same cue twice in a moment plays once, and the alert and danger cues wait
## ALERT_GAP_S between them.
func _cue(n: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var gap := ALERT_GAP_S if n in ["alert", "danger"] else 0.15
	if now - float(_cue_at.get(n, -1e9)) < gap:
		return
	_cue_at[n] = now
	cue.emit(n)


func alert(title: String, text := "", sound := "alert") -> void:
	_cue(sound)
	toast.say(title, text)
	toast.show()
	_toast_left = TOAST_S


## Visor mail: a message to Earth leaves now, and the card says when the reply can come.
func send_mail() -> void:
	mail_sol = int(state.get("sol", 1))
	mail.now_hour = float(state.get("hour", 0.0))
	mail.send(mail.now_hour, game_unix())
	mail.show()


func close_mail() -> void:
	mail_sol = -1
	mail.hide()


## The calendar moment the game is at: sol 1 is the day it is played, and each sol is 24.66 Earth hours.
func game_unix() -> float:
	return start_unix + ((int(state.get("sol", 1)) - 1) * Hud.SOL_H) * 3600.0


## A choice card. `id` names the question in data/lines.json; options: [{text, costs: {state key: amount}}], two or
## three, each text a line id or plain words. Picking one emits chosen(id, index).
func offer_choice(id: String, options: Array) -> void:
	var c: Control = load("res://ui/components/event_card.tscn").instantiate()
	c.icon_name = "alert"
	c.title = line(id)
	c.line = ""
	c.options = options.map(func(o: Dictionary) -> Dictionary:
		var t: String = o.get("text", "")
		return {"text": lines.get(t, t), "costs": o.get("costs", {})})
	c.width = minf(c.width, size.x / 3.0 - 24.0)  # a side third: the hero stays in the middle one
	c.chosen.connect(func(i: int) -> void:
		close_card()
		_cue("choice_made")
		chosen.emit(id, i))
	_open(c, false, true)
	_cue("choice_open")


## The sleep ledger: the sim's skip_sols() result.
func show_ledger(d: Dictionary) -> void:
	var c: Control = load("res://ui/components/ledger_card.tscn").instantiate()
	c.ledger = d
	c.closed.connect(func() -> void:
		close_card()
		ledger_closed.emit())
	_open(c)
	_cue("ledger_open")


## The mission-lost card with what led there: the sim's top_causes() ({label, sol, effect}) or plain strings.
func show_causes(list: Array) -> void:
	var c: Control = load("res://ui/components/mission_lost.tscn").instantiate()
	c.steps = list.map(func(e: Variant) -> Array:
		if e is Dictionary:
			return [_icon_of(e.get("effect", {})), e.get("label", ""), "Sol %d" % e.sol if e.has("sol") else ""]
		return ["alert", str(e), ""])
	c.retry.connect(func() -> void:
		close_card()
		retry.emit())
	_open(c, true)


## Every number on screen and where it comes from.
func show_sources() -> void:
	var s := state
	var rows: Array = [
		["battery", "Battery %d%%" % meters.power.value, SOURCES.battery_pct, ""],
		["health", "Crew health %d%%" % meters.health.value, SOURCES.health, ""],
	]
	for k: String in SUPPLIES + ["dose_msv", "panel_dust"]:
		if s.has(k):
			var v: float = float(s[k]) * Hud.KEYS[k][3]
			rows.append([Hud.KEYS[k][0], "%s %s %s" % [Hud.KEYS[k][1], Hud.num(v), Hud.KEYS[k][2]], SOURCES[k], ""])
	rows.append(["clock", "Sol %d of 30" % int(s.get("sol", 1)), SOURCES.sol, ""])
	var unix := game_unix()
	rows.append(["dish", "Radio %d min each way" % roundi(Delay.minutes(unix)), "for %s, JPL orbits" % Hud.date(unix), "computed"])
	for e: Dictionary in s.get("events", []):
		rows.append(["alert", e.label, e.source, "live" if e.live else "archived"])
	var c: Control = load("res://ui/components/sources_card.tscn").instantiate()
	c.rows = rows
	c.list_h = maxf(160.0, size.y - 260.0)
	c.closed.connect(close_card)
	_open(c)


func close_card() -> void:
	if card:
		card.name = &"Closed"  # freed at the frame's end: the next card in the same parent keeps its own name (snapshot)
		card.queue_free()
		card = null
		_give_pointer()
	side_card = false
	modal.hide()


## The pointer for a card or the map, and the mouse look back when they close (Ravindu, 14 Nov: after a choice the view
## no longer turned until a click, which read as the game locking the camera). A close comes from a click or a key,
## so a browser allows the capture there.
var _looked := false


func _take_pointer() -> void:
	_looked = _looked or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _give_pointer() -> void:
	if _looked and not (card or full_map):
		_looked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return modal.visible


func _open(c: Control, full := false, side := false) -> void:
	close_card()
	card = c
	side_card = side
	if "width" in c:
		c.width = minf(c.width, size.x - 40.0)
	(modal if full or side else holder).add_child(c)
	scrim.visible = not side  # a choice is asked over the play view: PIP's words and the hero stay in sight
	Hud.layer(c, 201)
	modal.show()
	if side:
		_place_side()
	_take_pointer()  # a card is used with the pointer
	var b := c.find_children("*", "Button", true, false)
	if b:
		(b[0] as Button).grab_focus.call_deferred()  # keys and a gamepad work at once


## A choice stands in a side third, mid height, on the side away from PIP's bubble; if the bubble still reaches it
## (docked on that side), it steps above or below the bubble. The middle third, where the hero is, stays clear.
func _place_side() -> void:
	const GAP := 16.0
	card.size = card.get_combined_minimum_size()
	var s := card.size
	var y := clampf((size.y - s.y) * 0.5, GAP, maxf(GAP, size.y - s.y - GAP))
	var spots: Array[Vector2] = [Vector2(size.x - s.x - GAP, y), Vector2(GAP, y)]
	var b := Rect2(bubble.panel.position, bubble.panel.size).grow(8.0) if bubble.visible else Rect2()
	if b.has_area() and b.get_center().x > size.x * 0.5:
		spots.reverse()
	card.position = spots[0]
	for p: Vector2 in spots:
		if not Rect2(p, s).intersects(b):
			card.position = p
			return
	var up := b.position.y - s.y - GAP
	card.position.y = up if up >= GAP or b.get_center().y > size.y * 0.5 else b.end.y + GAP
	card.position.y = clampf(card.position.y, GAP, maxf(GAP, size.y - s.y - GAP))


## The icon of the meter an entry cost most.
func _icon_of(effect: Dictionary) -> String:
	var worst := ""
	for k: String in effect:
		if Hud.KEYS.has(k) and (worst == "" or absf(effect[k]) > absf(effect[worst])):
			worst = k
	return Hud.KEYS[worst][0] if worst else "alert"


func _process(delta: float) -> void:
	# when the objective is PIP and his bubble is over him, the waypoint's label hangs under him instead
	waypoint.below = objective_node != null and objective_node == pip and bubble.visible and not bubble.docked
	if card and side_card:
		_place_side()
	_follow_view()
	if toast.visible:
		_toast_left -= delta
		toast.visible = _toast_left > 0.0


## The compass and the minimap turn with the camera; their markers ride with the objective and PIP.
func _follow_view() -> void:
	if camera == null or hero == null:
		return
	var heading := Hud.bearing(-camera.global_transform.basis.z)
	var at := hero.global_position
	var obj = _objective_xz()
	var p = Vector2(pip.global_position.x, pip.global_position.z) if pip else null
	compass.heading = heading
	compass.marks = {"objective": Hud.bearing(Vector3(obj.x - at.x, 0, obj.y - at.z)) if obj != null else null,
		"pip": Hud.bearing(Vector3(p.x - at.x, 0, p.y - at.z)) if p != null else null}
	minimap.show_view(heading, {"x": at.x, "z": at.z, "yaw": Hud.bearing(-hero.global_transform.basis.z)}, {"objective": obj, "pip": p}, _area(at))


## The area under the minimap: a field site's name when the hero is at one (world.json `sites`), else the base's plain.
func _area(at: Vector3) -> String:
	for id: String in ["mercou", "curiosity"]:
		var c: Array = world.sites[id].centre
		if Vector2(at.x, at.z).distance_to(Vector2(c[0], c[1])) < 1000.0:
			return String(world.sites[id].label).get_slice(",", 0)
	return "Landing plain"


## For render_game_to_text(): what the HUD shows now.
func snapshot() -> Dictionary:
	return {
		"meters": {"power": meters.power.value, "life": meters.life.value, "lifeIcon": meters.life.icon_name, "health": meters.health.value},
		"sol": clock.sol, "time": clock.time, "suit": clock.suit_label.text if clock.suit.visible else "",
		"subtitle": bubble.text if bubble.visible else "",
		"bubble": {"typed": bubble.typed, "docked": bubble.docked, "at": bubble.panel.position.round(), "fact": bubble.fact,
			"keys": bubble.keys_row.get_children().filter(func(k: Node) -> bool: return not k.is_queued_for_deletion()).size()} if bubble.visible else {},
		"heading": compass.readout() if compass.visible else "",
		"area": minimap.area,
		"objective": {"id": objective, "label": waypoint.place, "m": waypoint.metres(), "docked": waypoint.docked} if objective else {},
		"tasks": tasks.tasks if tasks.visible else [],
		"prompt": prompt.line.text if prompt.visible else "",
		"map": full_map != null,
		"alert": toast.title if toast.visible else "",
		"mail": {"sent": mail.sent_label.text, "reply": mail.reply_label.text, "minutes": snappedf(mail.minutes, 0.1)} if mail.visible else {},
		"card": String(card.name) if card else "",
	}
