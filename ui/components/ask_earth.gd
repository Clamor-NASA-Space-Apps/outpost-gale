extends "res://ui/hud_panel.gd"
## Visor mail: a message to mission control and when the reply can come back. The delay is the real one-way
## light time for the game's date (ui/radio_delay.gd, from JPL's planet orbits), labelled COMPUTED with that date
## (workspace rule 4). The diamond rides to Earth and back as the clock moves (set_now).

const Hud := preload("res://ui/hud.gd")
const Delay := preload("res://ui/radio_delay.gd")

@export var sent_hour := 7.0
@export var now_hour := 7.15
@export var date_unix := 1794657600.0  # 14 Nov 2026 12:00 UTC, the event's first day; the HUD passes the game's date

var minutes := 0.0  # one way
var track := Control.new()
var sent_label: Label
var reply_label: Label
var way_label: Label
var date_label: Label


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 220  # its captions wrap, so they ask for no width of their own
	track.custom_minimum_size = Vector2(100, 18)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.draw.connect(_draw_track)
	sent_label = Hud.label("", "HudNumAmber")
	reply_label = Hud.label("", "HudNumAmber")
	way_label = Hud.label("", "HudSmall", true)
	date_label = Hud.label("", "HudSmall", true)
	var path := Hud.row([Hud.icon("dish", 16, "accent"), track, Hud.icon("earth", 16, "on_surface")], 6)
	add_child(Hud.col([
		Hud.row([Hud.icon("dish", 13, "light"), Hud.label("Mail to Earth", "CapLight")], 6),
		path,
		Hud.row([Hud.label("Sent", "HudSmall"), sent_label], 5),
		Hud.row([Hud.label("Reply about", "HudSmall"), reply_label], 5),
		way_label,
		Hud.row([Hud.tag("TagArchive", "clock", "COMPUTED", "CapInk", 12), date_label], 6),
	], 6))
	send(sent_hour, date_unix)


## A message leaves at `hour` (Mars clock) on the day `unix`.
func send(hour: float, unix: float) -> void:
	sent_hour = hour
	date_unix = unix
	minutes = Delay.minutes(unix)
	# the sim's clock counts Earth hours through a 24.66 h sol, so the delay's minutes add on as they are
	sent_label.text = _clock(hour)
	reply_label.text = _clock(hour + 2.0 * minutes / 60.0)
	way_label.text = "Radio takes %d min each way" % roundi(minutes)
	date_label.text = "%s, JPL orbits" % Hud.date(unix)
	set_now(now_hour)


## The clock now, counted from the sent sol's midnight (the next sol's 01:00 is 1 + one sol's hours).
func set_now(hour: float) -> void:
	now_hour = hour
	track.queue_redraw()


## 0 just sent, 0.5 at Earth, 1 the reply is home.
func progress() -> float:
	return clampf((now_hour - sent_hour) * 60.0 / (2.0 * maxf(minutes, 0.01)), 0.0, 1.0)


static func _clock(hour: float) -> String:
	var m := roundi(fposmod(hour, 24.0) * 60.0)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


func _draw_track() -> void:
	var y := track.size.y * 0.5
	var dashes := 12
	var step := track.size.x / dashes
	for i in dashes:
		track.draw_line(Vector2(i * step + 2, y), Vector2(i * step + step * 0.55, y), Hud.color("hud-ink-faint"), 1.5)
	# the message: a teal diamond out to Earth, then the reply back; it points the way it travels, so the
	# direction reads without colour
	var p := progress()
	var there := 1.0 - absf(1.0 - 2.0 * p)
	var x := there * (track.size.x - 16.0) + 8.0
	var dir := 1.0 if p < 0.5 else -1.0
	track.draw_colored_polygon(PackedVector2Array([Vector2(x - 5 * dir, y - 6), Vector2(x + 7 * dir, y), Vector2(x - 5 * dir, y + 6)]), Hud.color("accent"))
