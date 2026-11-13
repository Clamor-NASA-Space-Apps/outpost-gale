extends Control
## The play HUD on the visor: three meters, the sol clock and suit air, PIP's subtitles, visor mail, an alert, and
## the cards (a choice, the sleep ledger, the causes of a lost mission, where the numbers come from). It holds no
## rules: bind() a node with `signal changed(state: Dictionary)` (the sim's state keys) and it shows what it gets.
## Under a CanvasLayer it fills the screen and draws PHONE_SCALE larger on a touch screen, with margins clear of the
## settings gear and the back swipe; inside another Control (ui/hud_gallery.tscn) it fills that.

signal chosen(id: String, index: int)
signal retry
signal ledger_closed

const Hud := preload("res://ui/hud.gd")
const Delay := preload("res://ui/radio_delay.gd")
const SUPPLIES := ["o2_kg", "water_kg", "food_kg"]
# Crew health is radiation only, and reaches 0 at 1 Sv: about +5% lifetime risk of fatal cancer, and what a 500-day
# stay at Gale adds up to (factcheck rows 32, 33). A 30-sol stay at 0.67 mSv a day costs about 2 points.
const DOSE_FULL_MSV := 1000.0
const TOAST_S := 6.0
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
var stock := {}  # the most of each supply seen so far: Life support's 100%
var start_unix := Time.get_unix_time_from_system()  # sol 1 is the day the game is played
var frame := Control.new()  # everything sits inside its margins
var meters := {}  # power, life, health
var clock: Control
var mail: Control
var mail_sol := -1  # the sol the mail went out, -1 for none
var toast: Control
var bubble: Control  # PIP's speech bubble (components/speech_bubble.gd)
var source_button := Button.new()
var modal := Control.new()  # a card and the scrim that keeps clicks off the world behind it
var holder := CenterContainer.new()
var card: Control  # the open card, or null
var _events := {}
var _failing: Array = []
var _toast_left := 0.0


func _ready() -> void:
	theme = Hud.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	# Containers only, so every part takes its least size again whenever the alert, mail or a subtitle comes and goes.
	# Left: the meters, the alert below (clear of the phone's stick). Right: the clock and the source button beside
	# the settings gear, the mail below (clear of the phone's action buttons). Bottom: PIP's subtitle.
	var left := _quiet(Hud.col([], 12))
	var status: Control = _scene("status_panel", left)
	status.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	meters = {"power": status.get_node("Meters/Power"), "life": status.get_node("Meters/LifeSupport"), "health": status.get_node("Meters/CrewHealth")}
	toast = _scene("alert_toast", left)
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast.hide()
	source_button.name = "SourceButton"
	source_button.text = "?"
	source_button.tooltip_text = "Where this comes from"
	source_button.theme_type_variation = "ChoiceButton"
	source_button.custom_minimum_size = Vector2(Hud.BUTTON_H, Hud.BUTTON_H)
	source_button.focus_mode = Control.FOCUS_NONE
	source_button.pressed.connect(show_sources)
	var gap := Control.new()  # the settings gear's place (ui/settings.gd)
	gap.custom_minimum_size = Vector2(Hud.BUTTON_H, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons := _quiet(Hud.row([], 16))
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_END
	clock = _scene("sol_clock", buttons)
	clock.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	buttons.add_child(source_button)
	buttons.add_child(gap)
	source_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var right := _quiet(Hud.col([buttons], 16))
	mail = _scene("ask_earth", right)
	mail.size_flags_horizontal = Control.SIZE_SHRINK_END
	mail.hide()
	for c: Control in [left, right]:
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var top := _quiet(Hud.row([left, Hud.spacer(), right], 16))
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bubble = _scene("speech_bubble", self)  # over the whole screen: it follows PIP, or docks at an edge
	modal.name = "Modal"
	modal.hide()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Hud.color("scrim")
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(scrim)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(holder)
	get_viewport().size_changed.connect(_fit)
	_fit()


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
		mail.set_now(float(s.hour) + (int(s.sol) - mail_sol) * Hud.SOL_H)
	var now := {}
	for e: Dictionary in s.get("events", []):
		now[e.id] = true
		if not _events.has(e.id):
			alert(e.label, "%s data. Tap ? for its source." % ("LIVE" if e.live else "ARCHIVED"))
	_events = now
	var failing: Array = s.get("failing", [])
	for k: String in failing:
		if k not in _failing:
			alert("%s ran out!" % Hud.KEYS.get(k, ["", k])[1], line("failing_" + k))
	_failing = failing.duplicate()


## PIP's line by id, from data/lines.json. A missing id still shows, as its own placeholder.
func line(id: String) -> String:
	return lines.get(id, "TBD at event: " + id)


func say(line_id: String) -> void:
	bubble.speak(line(line_id))


## PIP speaks from `node`, seen through `camera`: his bubble rides above him on screen.
func bind_speaker(node: Node3D, camera: Camera3D) -> void:
	bubble.follow(node, camera)


func alert(title: String, text := "") -> void:
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
	c.chosen.connect(func(i: int) -> void:
		close_card()
		chosen.emit(id, i))
	_open(c)


## The sleep ledger: the sim's skip_sols() result.
func show_ledger(d: Dictionary) -> void:
	var c: Control = load("res://ui/components/ledger_card.tscn").instantiate()
	c.ledger = d
	c.closed.connect(func() -> void:
		close_card()
		ledger_closed.emit())
	_open(c)


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
		card.queue_free()
		card = null
	modal.hide()


func is_open() -> bool:
	return modal.visible


func _open(c: Control, full := false) -> void:
	close_card()
	card = c
	if "width" in c:
		c.width = minf(c.width, size.x - 40.0)
	(modal if full else holder).add_child(c)
	modal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # a card is used with the pointer
	var b := c.find_children("*", "Button", true, false)
	if b:
		(b[0] as Button).grab_focus.call_deferred()  # keys and a gamepad work at once


## The icon of the meter an entry cost most.
func _icon_of(effect: Dictionary) -> String:
	var worst := ""
	for k: String in effect:
		if Hud.KEYS.has(k) and (worst == "" or absf(effect[k]) > absf(effect[worst])):
			worst = k
	return Hud.KEYS[worst][0] if worst else "alert"


func _process(delta: float) -> void:
	if toast.visible:
		_toast_left -= delta
		toast.visible = _toast_left > 0.0


## For render_game_to_text(): what the HUD shows now.
func snapshot() -> Dictionary:
	return {
		"meters": {"power": meters.power.value, "life": meters.life.value, "lifeIcon": meters.life.icon_name, "health": meters.health.value},
		"sol": clock.sol, "time": clock.time, "suit": clock.suit_label.text if clock.suit.visible else "",
		"subtitle": bubble.label.text if bubble.visible else "",
		"bubble": {"typed": bubble.label.visible_characters, "docked": bubble.docked, "at": bubble.panel.position.round()} if bubble.visible else {},
		"alert": toast.title if toast.visible else "",
		"mail": {"sent": mail.sent_label.text, "reply": mail.reply_label.text, "minutes": snappedf(mail.minutes, 0.1)} if mail.visible else {},
		"card": String(card.name) if card else "",
	}
