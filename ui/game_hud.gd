extends Control
## The play HUD on the visor (design/mockups/hud.png): the status card (sol, clock, three meters), Today's tasks, the
## compass tape, the minimap and the full map (M), the objective's waypoint, PIP's speech bubble, the use prompt,
## visor mail, an alert, and the cards (a choice, the sleep ledger, the causes of a lost mission, where the numbers
## come from, the mission report), the four bars and what hurts under Crew health, and the handbook (ui/handbook.gd: Tab or the book button), with the "New page" note and the check card
## that send the kid to it. It holds no rules: bind() a node with `signal changed(state: Dictionary)` (the sim's state keys) and
## it shows what it gets. Every HUD event emits `cue(name)` once (audio/audio.gd UI_SOUNDS); the sandbox plays it.
## Under a CanvasLayer it fills the screen and draws PHONE_SCALE larger on a touch screen, with margins clear of the
## settings gear and the back swipe; inside another Control (ui/hud_gallery.tscn) it fills that.

signal chosen(id: String, index: int)
signal retry
signal ledger_closed
signal cue(name: String)  # a HUD sound: audio.ui(name)
signal map_toggled(open: bool)
signal marked(at: Variant, id: String)  # the kid's own map mark set (world x, z; a place id or "") or cleared (null)
signal dismissed(line_id: String)  # a fact line (say(id, {fact = true})) closed by Enter or a tap
signal checked(id: String)  # a check answered right (design/plans/mission-1-contracts.md)
signal report_closed(again: bool)  # the mission report's "Keep going" (false) or "Play again" (true)

const Hud := preload("res://ui/hud.gd")
const Delay := preload("res://ui/radio_delay.gd")
const SUPPLIES := ["o2_kg", "water_kg", "food_kg"]
# Crew health is the rules' `health` (design/plans/core-loop-contracts.md): it falls while a need of the hero's is
# not met, and the meter says which in words
const HURTS := {"air": "No air", "thirst": "Thirsty", "hunger": "Hungry", "tired": "Tired", "cold": "Cold", "flare": "Solar storm", "dust": "Toxic dust"}
const HEALTH_DROP := 3.0  # a fall this big between two states shows as "-N" beside the meter
const FLOW_MIN_KW := 0.05  # under this the battery neither charges nor drains
const GAIN_STEP := 1.05  # solar power rising 5% between two states shows as a "+kW" beside the power meter
const GAIN_MIN_KW := 0.1  # and by this much: at dawn a tiny solar number climbs fast in percent
const TOAST_S := 6.0
const NOTE_S := 4.0  # the "New page" note stays this long
const WRONG_S := 1.2  # after a wrong answer PIP's "Not quite" is read before the handbook covers it
const TASKS_HOLD_S := 1.2  # a finished day's list stays up, every box ticked, before it leaves (art direction)
const TASKS_LEAVE_S := 0.45  # its slide and fade out
const TASKS_SLIDE := 24.0  # px it slides left as it goes
const ALERT_GAP_S := 6.0  # the alert and danger cues repeat no more often than this
# px the use prompt stands over the frame's bottom edge: low in the middle, under the hero and over
# the visor's arc and a phone's touch buttons (15 Nov playtest: in the corner a kid never learned E, or the hold)
const PROMPT_UP := 120
# a phone's canvas is shorter (PHONE_SCALE), so there 120 px lands on the hero: the prompt keeps the bottom centre,
# between the stick and the Use button
const PROMPT_UP_TOUCH := 4
const SOURCES_CARD := "res://ui/components/sources_card.tscn"
const PLACES := preload("res://ui/components/full_map.gd").PLACES
# What the "where this comes from" card says beside each number, with its factcheck row
const SOURCES := {
	"battery_pct": "Sunlight 43% of Earth's: NASA fact sheet",  # row 15
	"o2_kg": "0.84 kg each a day: NASA BVAD",  # row 23
	"water_kg": "3.2 kg each a day: NASA BVAD",  # row 25
	"food_kg": "2.39 kg each a day: NASA BVAD",  # row 112
	"dose_msv": "0.67 mSv a day at Gale: SwRI",  # row 32
	"health": "Game rule: falls when a need runs out",
	"suit_air": "A spacewalk lasts 6.5 to 8 h: NASA",  # row 135
	"suit_dust": "Mars dust is likely toxic: NASA",  # row 140
	"flare": "30 chest X-rays, 20 May 2024: JPL",  # row 37
	"panel_dust": "About 0.2% a sol: Lorenz 2021",  # row 180
	"sol": "NASA's first Mars stay: 30 sols",  # ICES-2023-265, workspace fact table
}

var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))
var state := {}
var _power_in := 0.0
var _power_hour := 0.0
var _health := -1.0  # the last state's, -1 before the first: a loaded game shows no drop
var stock := {}  # the most of each supply seen so far: Life support's 100%
var start_unix := Time.get_unix_time_from_system()  # sol 1 is the day the game is played
var frame := Control.new()  # everything sits inside its margins
var meters := {}  # power, life, health, air: the HUD's four bars, and there are no others
var clock: Control  # the status card: sol, time, suit air
var status: Control
var report: Control  # the base report card (key R): what makes and uses power and supplies right now
var _rules: Object  # what bind() listens to, or its `sim`: asked for flows() while the report is open
var tasks: Control
var _tasks_out: Tween  # the finished list leaving, then the next one coming in
var compass: Control
var minimap: Control
var waypoint: Control
var marker: Control  # the kid's own map mark: a light ring, apart from PIP's amber objective
var mark = null  # its world x, z, or null
var mark_id := ""  # the place it names, "" for open ground
const MARK_REACH_M := 4.0  # within this the mark is reached and clears itself
const SAME_PLACE_M := 20.0  # a mark this near the objective is the same place: one tag, not two (a place's middle and its landmark differ by metres)
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
			# a finger has no keys to read, and no Esc for settings: there the gear stays and the key caps go
			gear_hold.visible = v
			var up := PROMPT_UP_TOUCH if v else PROMPT_UP
			prompt.offset_top = -up
			prompt.offset_bottom = -up
			for k: Control in [book_key, source_key]:
				k.visible = not v
			# 48 px under a mouse, 96 scene px for a finger (addons/forge/test.gd TARGET) under PHONE_SCALE
			var b := ceilf(96.0 / Hud.PHONE_SCALE) if v else 48.0
			source_button.custom_minimum_size = Vector2(b, b)
			book_button.custom_minimum_size = Vector2(b, b)
			gear_slot.custom_minimum_size = Vector2(b, b)
			for g: Node in gear_hold.get_children():
				(g as Control).custom_minimum_size = Vector2(b, b)
				(g as Control).size = Vector2(b, b)
var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
var _cue_at := {}  # cue name -> the time it last played
var mail: Control
var mail_sol := -1  # the sol the mail went out, -1 for none
var toast: Control
var bubble: Control  # PIP's speech bubble (components/speech_bubble.gd)
var note: Control  # "New page: <title>", a few seconds, never a stop
var note_label: Label
var source_button := Button.new()
var book_button := Button.new()  # opens and closes the handbook
var book_mark: Label  # its "!": a page not read yet
var handbook: Control = preload("res://ui/handbook.gd").new()
var check := {}  # the check on its card now (design/plans/mission-1-contracts.md "A check"), {} for none
var gear_slot := Control.new()  # where the settings gear sits; dock_gear() puts the real one in it
# the gear itself, shown only on a touch screen: a keyboard has Esc (15 Nov playtest), but the slot keeps its room so
# the book and "?" stay clear of the compass
var gear_hold := Control.new()
var book_key: Control  # the key caps on the book and the "?": a kid clicks nothing while the mouse looks around
var source_key: Control
var modal := Control.new()  # a card and the scrim that keeps clicks off the world behind it
var holder := CenterContainer.new()
var scrim := ColorRect.new()
var side_card := false  # the open card is a choice: compact, beside the hero, clear of PIP's bubble, no scrim
var card: Control  # the open card, or null
var _events := {}
var _failing: Array = []
var _leak := false
var _toast_left := 0.0
var _note_left := 0.0


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
	# the base report: in the middle, over the play HUD, hidden until its key
	report = preload("res://ui/components/base_report.gd").new()
	report.hide()
	var mid := _quiet(CenterContainer.new())
	mid.z_index = 200
	add_child(mid)
	mid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mid.add_child(report)
	tasks = _scene("tasks_card", left)
	tasks.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tasks.hide()
	toast = _scene("alert_toast", left)
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast.hide()
	note_label = Hud.label("", "HudText")
	note = Hud.panel("HudPanel", note_label)
	note.name = "Note"
	note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	note.hide()
	left.add_child(note)
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
	book_button.name = "BookButton"
	book_button.tooltip_text = "Handbook"
	book_button.theme_type_variation = "ChoiceButton"
	book_button.custom_minimum_size = Vector2(Hud.BUTTON_H, Hud.BUTTON_H)
	book_button.focus_mode = Control.FOCUS_NONE
	book_button.pressed.connect(_toggle_handbook)
	# an open book (ui/icons/book.svg): two boxes side by side read as "00" (15 Nov playtest)
	var pages := CenterContainer.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.add_child(Hud.icon("book", 30, "on-surface"))
	book_button.add_child(pages)
	book_key = _key_cap(book_button, "handbook")
	source_key = _key_cap(source_button, "sources")
	gear_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_hold.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gear_slot.add_child(gear_hold)
	book_mark = Hud.label("!", "KeyAmber")
	book_mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	book_mark.hide()
	book_button.add_child(book_mark)
	# the book stands left of the "?", under the compass's end: a third row pushed the mail onto a phone's action
	# buttons, and beside the gear it lay on the compass
	gear_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	var buttons := _quiet(Hud.col([gear_slot, _quiet(Hud.row([book_button, source_button], 12))], 12))
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
	frame.add_child(_quiet(Hud.col([top], 0)))
	frame.get_child(0).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the use prompt, low in the middle: it takes its least size and grows up and out from that point
	prompt = load("res://ui/components/prompt.tscn").instantiate()
	frame.add_child(prompt)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	compass = _scene("compass")
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	compass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	compass.hide()  # shown once a camera is bound (bind_view)
	waypoint = _scene("waypoint", self)
	marker = load("res://ui/components/waypoint.tscn").instantiate()
	marker.shape = "ring"
	marker.tint = "light"
	marker.glow = "hud-glow"
	marker.dist_style = "HudNum"
	add_child(marker)
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
	Hud.layer(marker, 101)
	Hud.layer(bubble, 101)
	Hud.layer(modal, 201)
	# the handbook: the whole screen, over the cards (a check's card waits under it). Added after the layering above:
	# it is a screen of its own (ui/handbook.gd), drawn in the order it builds its parts
	handbook.name = "Handbook"
	handbook.z_as_relative = false
	handbook.z_index = 301
	add_child(handbook)
	handbook.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	handbook.closed.connect(_handbook_closed)


## A key cap in a HUD button's lower right corner, naming the key `action` is bound to (player/controls.gd).
func _key_cap(b: Button, action: String) -> Control:
	var events: Array = InputMap.action_get_events(action) if InputMap.has_action(action) else []
	var k: Key = (events[0] as InputEventKey).physical_keycode if events and events[0] is InputEventKey else preload("res://player/controls.gd").KEYS[action][0]
	var cap := Hud.panel("HudKey", Hud.label(OS.get_keycode_string(k), "KeyText"))
	cap.name = "Key"
	cap.set_meta("icon", true)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cap)
	cap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cap.offset_left = 6.0  # a little past the corner, like a sticker, so it never sits on the icon
	cap.offset_right = 6.0
	cap.offset_top = 6.0
	cap.offset_bottom = 6.0
	cap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	b.tooltip_text += " (%s)" % OS.get_keycode_string(k)
	return cap


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
	_rules = node.sim if "sim" in node else node  # the base report asks the rules themselves for their flows()
	node.changed.connect(show_state)
	if node.has_method("state"):
		show_state(node.state())


## The base report card (ui/components/base_report.gd), opened and closed by its key. The game runs on under it.
func toggle_report() -> void:
	report.visible = not report.visible
	_show_report()


func _show_report() -> void:
	# ponytail: the card redraws on every state while it is open; fill it only on a change if that ever costs
	if report.visible and _rules and _rules.has_method("flows"):
		report.show_flows(_rules.flows())


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
	var health := float(s.get("health", 100.0))
	meters.health.value = roundi(health)
	if _health - health >= HEALTH_DROP:
		meters.health.bump("-%d" % roundi(_health - health))
	_health = health
	status.hurt(HURTS.get(s.get("hurt", ""), ""))
	var net := float(s.get("net_kw", float(s.get("power_in_kw", 0.0)) - float(s.get("power_out_kw", 0.0))))
	status.flow.text = ("Steady" if absf(net) < FLOW_MIN_KW else "%s %+.1f kW" % ["Charging" if net > 0.0 else "Draining", net])
	status.show_body(s)
	_show_report()
	# the suit's air shows while it runs down (outside), and hides once it is topped up again; with the body's
	# gauges up, the suit's gauge says it
	var suit := float(s.get("suit_air_min", -1.0))
	stock.suit = maxf(stock.get("suit", 0.0), suit)
	# the Mars clock: 24 local hours a sol, the sky's own time (the rules count Earth hours through a 24.66 h sol)
	clock.show_time(int(s.sol), float(s.hour) * 24.0 / Hud.SOL_H, suit if suit < stock.suit and not status.body_on else -1.0)
	if mail_sol >= 0:
		var was: float = mail.progress()
		mail.set_now(float(s.hour) + (int(s.sol) - mail_sol) * Hud.SOL_H)
		if was < 1.0 and mail.progress() >= 1.0:
			_cue("mail")  # the reply is home
	var now := {}
	for e: Dictionary in s.get("events", []):
		now[e.id] = true
		if not _events.has(e.id):
			# a keyboard player cannot click the "?" while the mouse looks around: name its key
			var how := "Tap ?" if touch else "Press %s" % (source_key.get_child(0) as Label).text
			alert(e.label, "%s data. %s for its source." % ["LIVE" if e.live else "ARCHIVED", how])
	_events = now
	var failing: Array = s.get("failing", [])
	for k: String in failing:
		if k not in _failing:
			alert("%s ran out!" % Hud.KEYS.get(k, ["", k])[1], line("failing_" + k), "danger")
	_failing = failing.duplicate()
	# the leak is a flag in the state, not an event: it gets its own alert, once, when it starts
	var leak := bool(s.get("leak", false))
	if leak and not _leak:
		alert("Oxygen leak!", "The oxygen tank is dropping fast.", "danger")
	_leak = leak


## PIP's line by id, from data/lines.json, as it reads: without the asterisks that mark its key words (only PIP's
## bubble draws those). A missing id still shows, as its own placeholder.
func line(id: String) -> String:
	return _words(lines.get(id, "TBD at event: " + id))


## A card's words: a line id or plain words, without the asterisks.
func _words(t: String) -> String:
	return String(lines.get(t, t)).replace("*", "")


## PIP says a line from data/lines.json. It stays until the next line or clear_line(). opts: `keys`, the keys it
## teaches (["W"], ["A", "D"], ["Mouse"], ["Space"], ["Shift"], ["E"], ["M"]), drawn as keycaps under the words (on a
## phone, the touch control's icon or word); `fact` true: it waits for Enter or a tap, then emits dismissed(line_id).
func say(line_id: String, opts := {}) -> void:
	_cue("pip_open")
	bubble.touch = touch
	bubble.speak(lines.get(line_id, line(line_id)), line_id, opts.get("keys", []), opts.get("fact", false))


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
	gear_hold.add_child(gear)
	gear.position = Vector2.ZERO
	gear.theme_type_variation = &"ChoiceButton"  # the same glass key as the "?" under it
	touch = touch  # sizes it as the "?" beside it
	Hud.layer(gear, 1)


## The play camera and the hero's body: the compass, the minimap, the waypoint and distances follow them.
func bind_view(cam: Camera3D, body: Node3D) -> void:
	camera = cam
	hero = body
	waypoint.follow(cam, body)
	marker.follow(cam, body)
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
	waypoint.point_node(node, _words(label_id) if label_id else ("PIP" if node == pip else PLACES.get(id, id.capitalize())))


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


## Today's list: [{label_id, state: "done" | "now" | "next" | "urgent"}], words from data/lines.json. An urgent row is
## a need (thirst, suit air), not a task of the day: it comes and goes without the list counting as finished. It shows as soon as it has
## a task; a new task arrives with the objective_new cue, a task newly done ticks (task_tick).
func set_tasks(list: Array) -> void:
	var now := {}
	for t: Dictionary in list:
		now[t.label_id] = t.state
	if now.keys().any(func(id: String) -> bool: return not _task_states.has(id)):
		_cue("objective_new")
	if now.keys().any(func(id: String) -> bool: return now[id] == "done" and _task_states.get(id, "") != "done"):
		_cue("task_tick")
	var rows: Array = list.map(func(t: Dictionary) -> Array: return [line(t.label_id), t.state])
	# a finished list (every box ticked, or its rows gone because the day's work is over) leaves with a slide and a
	# fade, ticked to the end, and the next list comes in after it (14 Nov playtest: the done list just stayed up)
	var ended: bool = tasks.visible and not tasks.tasks.is_empty() and (_task_states.keys().any(
		func(id: String) -> bool: return not now.has(id) and _task_states[id] != "urgent") or list.all(func(t: Dictionary) -> bool: return t.state == "done"))
	var was: Dictionary = _task_states
	_task_states = now
	if _tasks_out:
		_tasks_out.kill()
		_settle_tasks()
	if not ended:
		tasks.set_tasks(rows)
		tasks.visible = not list.is_empty()
		return
	var labels := {}
	for id: String in was:
		labels[line(id)] = now.get(id, "done")
	if was.keys().any(func(id: String) -> bool: return was[id] != "done" and not now.has(id)):
		_cue("task_tick")  # the last task left the list done: it ticks like any other
	tasks.set_tasks(tasks.tasks.map(func(r: Array) -> Array: return [r[0], labels.get(r[0], "done")]))
	var next := rows.filter(func(r: Array) -> bool: return r[1] != "done")
	_tasks_out = create_tween()
	_tasks_out.tween_interval(TASKS_HOLD_S)
	_tasks_out.tween_method(_slide_tasks.bind(tasks.position.x), 0.0, 1.0, TASKS_LEAVE_S).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tasks_out.tween_callback(func() -> void:
		_settle_tasks()
		tasks.visible = not next.is_empty()
		if tasks.visible:
			tasks.set_tasks(next)
			tasks.modulate.a = 0.0)
	_tasks_out.tween_property(tasks, "modulate:a", 1.0, 0.25)


## The Today card `k` of the way out (0 in place, 1 gone) from its laid-out x. Set every frame, so the box that lays
## it out cannot pull it back mid-slide.
func _slide_tasks(k: float, x0: float) -> void:
	tasks.position.x = x0 - TASKS_SLIDE * k
	tasks.modulate.a = 1.0 - k


func _settle_tasks() -> void:
	tasks.modulate.a = 1.0
	(tasks.get_parent() as Container).queue_sort()  # its column puts it back where it belongs


## The use prompt at the bottom right ("Open the greenhouse"); "" hides it. `hold` 0 to 1: the target needs the key
## held, and the ring round the key is that far (0 before the press); -1 for a plain press.
func show_prompt(text: String, hold := -1.0) -> void:
	prompt.say(text, hold)


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
	full_map.marked.connect(func(at: Variant, id: String, label: String) -> void: set_mark(at, id, label))
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
	full_map.mark = mark
	full_map.mark_id = mark_id


## The kid's own waypoint, from a tap on the map: one at a time, on the compass with its distance, at the screen's
## edge when off screen, and (through `marked`, the root) as a beacon in the world. null clears it.
func set_mark(at: Variant, id := "", label := "") -> void:
	mark = at
	mark_id = id if at != null else ""
	if at == null:
		marker.hide()
	else:
		marker.point(Vector3(at.x, hero.global_position.y if hero else 0.0, at.y), label)
		_cue("objective_new")
	if full_map:
		full_map.mark = mark
		full_map.mark_id = mark_id
		full_map.refresh()
	marked.emit(at, mark_id)


func _input(e: InputEvent) -> void:
	if handbook.visible:
		return  # Tab and Esc close it in its own _input (ui/handbook.gd), which runs before this one; M waits
	if InputMap.has_action("report") and e.is_action_pressed("report") and not e.is_echo() and is_visible_in_tree() and not full_map:
		toggle_report()
		get_viewport().set_input_as_handled()
		return
	if InputMap.has_action("handbook") and e.is_action_pressed("handbook") and not e.is_echo() and is_visible_in_tree() and not full_map:
		open_handbook()
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("sources") and e.is_action_pressed("sources") and not e.is_echo() and is_visible_in_tree() and not full_map:
		# the "?" by its key: in play the mouse turns the view, so a click never reaches the button (15 Nov playtest).
		# It toggles its own card and never replaces another one (a ledger, a check)
		if card and card.scene_file_path == SOURCES_CARD:
			close_card()
		elif card == null:
			show_sources()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("map") and not e.is_echo():
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


## A choice card. `id` names the question in data/lines.json; options: [{text, gain, lose}], two or three, each a
## line id or plain words (`costs: {state key: amount}` still shows, as tags). `pages`: handbook pages that help; the
## card then has a Handbook button that opens the first and comes back. Picking one emits chosen(id, index).
func offer_choice(id: String, options: Array, pages: Array = []) -> void:
	var c := _card(line(id), options, pages)
	c.icon_name = "alert"
	c.chosen.connect(func(i: int) -> void:
		close_card()
		_cue("choice_made")
		chosen.emit(id, i))
	_open(c, false, true)
	_cue("choice_open")


## The side card a decision and a check share: a side third wide, so the hero stays in the middle one (`share` of
## the screen's width; a check stops the game and has a longer question, so it may take up to half).
func _card(title: String, options: Array, pages: Array, share := 1.0 / 3.0) -> Control:
	var c: Control = load("res://ui/components/event_card.tscn").instantiate()
	c.title = title
	c.line = ""
	c.options = options.map(func(o: Dictionary) -> Dictionary:
		return {"text": _words(o.get("text", "")), "gain": _words(o.get("gain", "")), "lose": _words(o.get("lose", "")),
			"costs": o.get("costs", {})})
	c.width = minf(c.width, size.x * share - 24.0)
	c.book_button = not pages.is_empty()
	if pages:
		c.handbook.connect(open_handbook.bind(pages[0]))
	return c


## A check (contracts, "A check"): the handbook opens at the page that holds the answer; closed, it leaves the
## question with its options in a shuffled order. Right: the pages are stamped and checked(id) goes out. Wrong: PIP
## says so, the page opens again, and the card is back after it. No penalty, as many tries as it takes.
## A test picks option k of `check.options` with card.buttons[card.order.find(k)].
func offer_check(c: Dictionary) -> void:
	var order: Array = range(c.options.size())
	order.shuffle()
	var k := _card(line(c.q), order.map(func(i: int) -> Dictionary: return {"text": c.options[i]}), c.get("pages", []), 0.5)
	k.icon_name = "science"
	k.tag = "Tag"
	k.order = order
	k.chosen.connect(_answer)
	_open(k, false, true)
	check = c
	_cue("choice_open")
	if k.book_button:
		open_handbook(c.pages[0])


func _answer(i: int) -> void:
	var c := check
	if i == int(c.right):
		handbook.learned(c.get("pages", []))
		close_card()
		_cue("objective_done")
		checked.emit(c.id)
		return
	say("check.wrong")
	card.mark(i)  # a cross stays on the answer tried
	if not card.book_button:
		return
	for b: Button in card.buttons:
		b.disabled = true  # no second answer while PIP's line is read
	var k := card.get_instance_id()  # not the card: freed before the timer, it comes back null, as "no card" does
	get_tree().create_timer(WRONG_S).timeout.connect(func() -> void:
		if card and card.get_instance_id() == k:  # still this check
			for b: Button in card.buttons:
				b.disabled = false
			open_handbook(c.pages[0]))


## The handbook over everything, at `page` ("" for where it was). An open card waits hidden under it and is back
## when it closes: a key could still press a card left in sight.
func open_handbook(page := "") -> void:
	if handbook.visible:
		return
	handbook.open(page)
	modal.hide()
	_take_pointer()
	_cue("map_open")


func _toggle_handbook() -> void:
	if handbook.visible:
		handbook.close()
	else:
		open_handbook()


func _handbook_closed() -> void:
	modal.visible = card != null
	_focus_card()
	_give_pointer()
	_cue("map_close")
	book_mark.visible = handbook.unread() > 0


## A page lands in the handbook: a note for a few seconds and the "!" on the book button. Never a stop.
func unlock_page(id: String) -> void:
	if not handbook.unlock(id):
		return
	notice("%s: %s" % [line("hud.new_page"), handbook.title(id)])
	book_mark.visible = handbook.unread() > 0


## A calm note on the glass for `seconds`: news, not a danger (alert() is the red one, for a meter or a hazard).
func notice(text: String, seconds := NOTE_S) -> void:
	note_label.text = text
	note.show()
	_note_left = seconds
	_cue("mail")


func log_decision(title: String, choice: String) -> void:
	handbook.log_decision(title, choice)


## A checkpoint's handbook back in (sandbox.gd, Continue), with the "!" on the book button for a page not read yet.
func load_handbook(d: Dictionary) -> void:
	handbook.load(d)
	book_mark.visible = handbook.unread() > 0


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
## Its main button reads `retry_label` and emits retry.
func show_causes(list: Array, retry_label := "Try this sol again") -> void:
	var c := _end_card(list)
	c.retry_label = retry_label
	c.retry.connect(func() -> void:
		close_card()
		retry.emit())
	c.open_log.connect(open_handbook)  # the decisions made are in the handbook; the card is back when it closes
	_open(c, true)


## The mission complete card. d: {title, lines: [line ids or plain words], meters: {power, life, health} in percent,
## causes: as show_causes takes, pages: [found, total]}; every key may be left out. "Keep going" emits
## report_closed(false), "Play again" report_closed(true).
func show_report(d: Dictionary) -> void:
	var c := _end_card(d.get("causes", []))
	c.lost = false
	c.title = _words(d.get("title", "Mission complete"))
	c.line = ""
	c.lines = (d.get("lines", []) as Array).map(func(t: String) -> String: return _words(t))
	var pages: Array = d.get("pages", [])
	if pages.size() == 2:
		c.lines.append("Handbook pages found: %d of %d" % [int(pages[0]), int(pages[1])])
	c.meters = d.get("meters", {})
	c.caption = "What cost you most"
	c.retry_label = "Keep going"
	c.log_label = "Play again"
	for again: bool in [false, true]:
		(c.open_log if again else c.retry).connect(func() -> void:
			close_card()
			report_closed.emit(again))
	_open(c, true)
	_cue("objective_done")


## The end card (components/mission_lost.gd) with its chain of causes.
func _end_card(causes: Array) -> Control:
	var c: Control = load("res://ui/components/mission_lost.tscn").instantiate()
	c.steps = causes.map(func(e: Variant) -> Array:
		if e is Dictionary:
			return [_icon_of(e.get("effect", {})), e.get("label", ""), "Sol %d" % e.sol if e.has("sol") else ""]
		return ["alert", str(e), ""])
	return c


## Every number on screen and where it comes from.
func show_sources() -> void:
	if side_card:
		return  # a question waits for its answer: this card would take its place and the day would never go on
	var s := state
	var rows: Array = [
		["battery", "Battery %d%%" % meters.power.value, SOURCES.battery_pct, ""],
		["health", "Crew health %d%%" % meters.health.value, SOURCES.health, ""],
		["radiation", "Solar storm outside the shelter", SOURCES.flare, "archived"],
	]
	if status.body_on:
		rows.append(["oxygen", "Suit air %d%%" % meters.air.value, SOURCES.suit_air, ""])
		rows.append(["storm", "Suit dust %d%%" % roundi(100.0 * float(s.get("suit_dust", 0.0))), SOURCES.suit_dust, ""])
	for k: String in SUPPLIES + ["dose_msv", "panel_dust"]:
		if s.has(k):
			var v: float = float(s[k]) * Hud.KEYS[k][3]
			rows.append([Hud.KEYS[k][0], "%s %s %s" % [Hud.KEYS[k][1], Hud.num(v), Hud.KEYS[k][2]], SOURCES[k], ""])
	rows.append(["clock", "Sol %d of 30" % int(s.get("sol", 1)), SOURCES.sol, ""])
	var unix := game_unix()
	rows.append(["dish", "Radio %d min each way" % roundi(Delay.minutes(unix)), "for %s, JPL orbits" % Hud.date(unix), "computed"])
	for e: Dictionary in s.get("events", []):
		rows.append(["alert", e.label, e.source, "live" if e.live else "archived"])
	# the real records behind the solar storm (data/nasa.json: NASA DONKI and RadLab, saved 15 Nov and shipped with
	# the game, so nothing calls NASA in play), each with its own source line; our own averages say so
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/nasa.json")).records.values():
		if r.get("show", true):
			rows.append(["radiation", "%s: %s %s" % [r.label, r.value, r.unit], r.source, "computed" if r.checked == "our maths" else "archived"])
	var c: Control = load(SOURCES_CARD).instantiate()
	c.rows = rows
	c.list_h = maxf(160.0, size.y - 260.0)
	c.closed.connect(close_card)
	_open(c)


func close_card() -> void:
	if side_card:
		for p: Control in _under():
			p.modulate.a = 1.0
	if card:
		card.name = &"Closed"  # freed at the frame's end: the next card in the same parent keeps its own name (snapshot)
		card.queue_free()
		card = null
		check = {}
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
	if _looked and not (card or full_map or handbook.visible):
		_looked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return modal.visible or handbook.visible


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
	_focus_card()


## The HUD parts a side card can lie on.
func _under() -> Array:
	return [status, tasks, toast, note, minimap, gear_slot.get_parent(), mail, prompt, compass]


## Keys and a gamepad work on the open card at once.
func _focus_card() -> void:
	var b: Array = card.find_children("*", "Button", true, false) if card else []
	if b:
		# held but not drawn until a key moves it: a lit first row read as the answer already picked
		(b[0] as Button).grab_focus.call_deferred(true)


## A choice stands in a side third, mid height, on the side away from PIP's bubble; if the bubble still reaches it
## (docked on that side), it steps above or below the bubble. The middle third, where the hero is, stays clear.
func _place_side() -> void:
	const GAP := 16.0
	card.size = card.get_combined_minimum_size()
	# a card taller than the screen (three long options on a phone) shrinks to fit: a smaller target beats an option
	# off screen, and a check has no other way out
	var k := minf(1.0, (size.y - 2.0 * GAP) / card.size.y)
	card.scale = Vector2(k, k)
	var s := card.size * k
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
		# what the card stands on goes while it is up: through its glass the minimap's words ran across the question
		var r := card.get_global_rect()
		for p: Control in _under():
			p.modulate.a = 0.0 if p.get_global_rect().intersects(r) else 1.0
	_follow_view()
	if toast.visible:
		_toast_left -= delta
		toast.visible = _toast_left > 0.0
	if note.visible:
		_note_left -= delta
		note.visible = _note_left > 0.0


## The compass and the minimap turn with the camera; their markers ride with the objective and PIP.
func _follow_view() -> void:
	if camera == null or hero == null:
		return
	var heading := Hud.bearing(-camera.global_transform.basis.z)
	var at := hero.global_position
	var obj = _objective_xz()
	var p = Vector2(pip.global_position.x, pip.global_position.z) if pip else null
	if mark != null and Vector2(at.x, at.z).distance_to(mark) < MARK_REACH_M:
		_cue("objective_done")
		set_mark(null)  # reached
	# the kid's mark on the very place PIP's objective points at would say it twice ("Reactor 75 m" over "Reactor
	# 75 m", 15 Nov playtest, the pin dropped on the reactor for the autopilot): the objective's tag speaks for both
	if mark != null:
		marker.visible = obj == null or (mark as Vector2).distance_to(obj) > SAME_PLACE_M
	compass.heading = heading
	compass.marks = {"objective": Hud.bearing(Vector3(obj.x - at.x, 0, obj.y - at.z)) if obj != null else null,
		"pip": Hud.bearing(Vector3(p.x - at.x, 0, p.y - at.z)) if p != null else null,
		"mark": Hud.bearing(Vector3(mark.x - at.x, 0, mark.y - at.z)) if mark != null else null}
	compass.mark_text = Hud.distance(Vector2(at.x, at.z).distance_to(mark)) if mark != null else ""
	minimap.show_view(heading, {"x": at.x, "z": at.z, "yaw": Hud.bearing(-hero.global_transform.basis.z)}, {"objective": obj, "pip": p, "mark": mark}, _area(at))


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
		"sol": clock.sol, "time": clock.time, "suit": clock.suit_text,
		"hurt": status.hurting, "flow": status.flow.text, "health_note": status.note.text,
		# the hero's needs in percent, {} while the rules do not run them; only the suit's air has a bar
		"body": status.body,
		"subtitle": bubble.text if bubble.visible else "",
		"bubble": {"typed": bubble.typed, "docked": bubble.docked, "at": bubble.panel.position.round(), "fact": bubble.fact,
			"keys": bubble.keys_row.get_children().filter(func(k: Node) -> bool: return not k.is_queued_for_deletion()).size()} if bubble.visible else {},
		"heading": compass.readout() if compass.visible else "",
		"area": minimap.area,
		"objective": {"id": objective, "label": waypoint.place, "m": waypoint.metres(), "docked": waypoint.docked} if objective else {},
		"tasks": tasks.tasks if tasks.visible else [],
		"prompt": prompt.text if prompt.visible else "", "hold": prompt.hold if prompt.visible else -1.0,
		"map": full_map != null,
		"mark": {"id": mark_id, "label": marker.place, "m": marker.metres(), "compass": compass.mark_text} if mark != null else {},
		"alert": toast.title if toast.visible else "",
		"mail": {"sent": mail.sent_label.text, "reply": mail.reply_label.text, "minutes": snappedf(mail.minutes, 0.1)} if mail.visible else {},
		"card": String(card.name) if card else "",
		"check": check.get("id", ""),
		"note": note_label.text if note.visible else "",
		"handbook": handbook.state(),
	}
