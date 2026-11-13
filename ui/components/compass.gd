extends Control
## The compass tape (design/mockups/hud.png, top centre): 4 mockup px per degree, a tick every 5 degrees, a number
## every 15, the eight compass letters (N amber), faded toward both ends; a caret under the middle and the heading
## below it ("208°  SSW"). Markers ride the tape at their bearings: the objective as an amber diamond, PIP as a teal
## dot. Set `heading` and `marks` ({objective: bearing or null, pip: bearing or null}) each frame; it redraws itself.

const Hud := preload("res://ui/hud.gd")
const PX_PER_DEG := 4.0 * 720.0 / 1080.0
const TAPE := Vector2(507, 36)  # 760 x 54 mockup px
const FADE := 0.18  # each end fades over this share of the width, as the mockup's mask
const NAMES := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
const POINTS := ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

var heading := 208.0:
	set(v):
		heading = fposmod(v, 360.0)
		_redraw()
var marks := {"objective": 244.0, "pip": 190.0}:
	set(v):
		marks = v
		queue_redraw()
# The tape's words draw in two children, one per font, so the ticks and marks (atlas shapes, here) and each font's
# words batch into a draw call apiece (Hud.layer)
var letters := Control.new()  # N, NE, ... and the heading readout (Exo 2)
var numbers := Control.new()  # 15, 30, ... (Lexend)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TAPE + Vector2(0, 30)  # the caret and the heading under the tape
	set_meta("shapes", true)
	for t: Array in [[letters, "Compass", _draw_letters], [numbers, "CompassSmall", _draw_numbers]]:
		var c: Control = t[0]
		c.set_meta("text_font", t[1])
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.draw.connect(t[2])
		add_child(c)


func _redraw() -> void:
	queue_redraw()
	letters.queue_redraw()
	numbers.queue_redraw()


## "208°  SSW": the heading and its 16-point name.
func readout() -> String:
	return "%d°  %s" % [roundi(heading) % 360, POINTS[roundi(heading / 22.5) % 16]]


func _fade(x: float) -> float:
	var t := x / TAPE.x
	return clampf(minf(t, 1.0 - t) / FADE, 0.0, 1.0)


## Each whole 5 degrees in view: [degrees 0 to 359, x on the tape, fade 0 to 1].
func _ticks() -> Array:
	var out := []
	var mid := TAPE.x * 0.5
	var half_deg := mid / PX_PER_DEG
	var d := ceilf((heading - half_deg) / 5.0) * 5.0
	while d <= heading + half_deg:
		var x := mid + (d - heading) * PX_PER_DEG
		out.append([int(fposmod(d, 360.0)), x, _fade(x)])
		d += 5.0
	return out


func _draw() -> void:
	var mid := TAPE.x * 0.5
	for t: Array in _ticks():
		var card: bool = t[0] % 45 == 0
		var tick := Hud.color("on-surface" if card else "hud-ink-faint")
		tick.a *= t[2]
		Hud.blit(self, "white", Rect2(t[1] - 0.75, 4.0 if card else 5.0, 1.5, 11.0 if card else 7.0), tick)
	for m: String in marks:
		if marks[m] == null:
			continue
		var off := wrapf(float(marks[m]) - heading, -180.0, 180.0)
		var x := clampf(mid + off * PX_PER_DEG, 6.0, TAPE.x - 6.0)  # past the tape's end it waits at the edge
		Hud.blit_at(self, "diamond" if m == "objective" else "dot", Vector2(x, 2.0), 11.0 if m == "objective" else 8.0, Hud.color("primary" if m == "objective" else "accent"))
	# the caret under the middle
	Hud.blit_at(self, "caret", Vector2(mid, TAPE.y + 7.5), 12.0, Hud.color("light"))


func _draw_letters() -> void:
	var f := get_theme_font("font", "Compass")
	var fs := get_theme_font_size("font_size", "Compass")
	for t: Array in _ticks():
		if t[0] % 45 == 0:
			var col := Hud.color("primary" if t[0] == 0 else "on-surface")
			col.a *= t[2]
			_text(letters, f, fs, NAMES[t[0]], Vector2(t[1], 31), col)
	_text(letters, get_theme_font("font", "CompassHeading"), get_theme_font_size("font_size", "CompassHeading"), readout(), Vector2(TAPE.x * 0.5, TAPE.y + 26.0), Hud.color("light"))


func _draw_numbers() -> void:
	var f := get_theme_font("font", "CompassSmall")
	var fs := get_theme_font_size("font_size", "CompassSmall")
	for t: Array in _ticks():
		if t[0] % 45 != 0 and t[0] % 15 == 0:
			var col := Hud.color("hud-ink-dim")
			col.a *= t[2]
			_text(numbers, f, fs, str(t[0]), Vector2(t[1], 29), col)


## Text centred on x, its baseline at y, with the HUD's dark edge so it reads over a bright sky: the words 8 times,
## 1.5 px out all round, then the words, all from one glyph texture (as Hud.edge does for labels).
func _text(on: CanvasItem, f: Font, s: int, t: String, at: Vector2, col: Color) -> void:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var edge := Hud.color("hud-text-edge")
	edge.a = (1.0 - pow(1.0 - edge.a, 1.0 / 3.0)) * col.a
	var o := at - Vector2(w * 0.5, 0)
	for k in 8:
		on.draw_string(f, o + Vector2.from_angle(k * TAU / 8.0) * Hud.EDGE_R, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, edge)
	on.draw_string(f, o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
