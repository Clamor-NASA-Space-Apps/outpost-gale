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
		queue_redraw()
var marks := {"objective": 244.0, "pip": 190.0}:
	set(v):
		marks = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TAPE + Vector2(0, 30)  # the caret and the heading under the tape


## "208°  SSW": the heading and its 16-point name.
func readout() -> String:
	return "%d°  %s" % [roundi(heading) % 360, POINTS[roundi(heading / 22.5) % 16]]


func _fade(x: float) -> float:
	var t := x / TAPE.x
	return clampf(minf(t, 1.0 - t) / FADE, 0.0, 1.0)


func _draw() -> void:
	var mid := TAPE.x * 0.5
	var half_deg := mid / PX_PER_DEG
	var big := get_theme_font("font", "Compass")
	var big_size := get_theme_font_size("font_size", "Compass")
	var small := get_theme_font("font", "CompassSmall")
	var small_size := get_theme_font_size("font_size", "CompassSmall")
	var d := ceilf((heading - half_deg) / 5.0) * 5.0
	while d <= heading + half_deg:
		var a := int(fposmod(d, 360.0))
		var x := mid + (d - heading) * PX_PER_DEG
		var k := _fade(x)
		var card := a % 45 == 0
		var tick := Hud.color("on-surface" if card else "hud-ink-faint")
		tick.a *= k
		draw_rect(Rect2(x - 0.75, 4.0 if card else 5.0, 1.5, 11.0 if card else 7.0), tick)
		if card:
			var col := Hud.color("primary" if a == 0 else "on-surface")
			col.a *= k
			_text(big, big_size, NAMES[a], Vector2(x, 31), col)
		elif a % 15 == 0:
			var col := Hud.color("hud-ink-dim")
			col.a *= k
			_text(small, small_size, str(a), Vector2(x, 29), col)
		d += 5.0
	for m: String in marks:
		if marks[m] == null:
			continue
		var off := wrapf(float(marks[m]) - heading, -180.0, 180.0)
		var x := clampf(mid + off * PX_PER_DEG, 6.0, TAPE.x - 6.0)  # past the tape's end it waits at the edge
		var c := Vector2(x, 2.0)
		if m == "objective":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), Hud.color("primary"))
		else:
			draw_circle(c, 3.5, Hud.color("accent"))
	# the caret and the heading under it
	var cy := TAPE.y + 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(mid, cy), Vector2(mid + 5.5, cy + 7), Vector2(mid - 5.5, cy + 7)]), Hud.color("light"))
	_text(get_theme_font("font", "CompassHeading"), get_theme_font_size("font_size", "CompassHeading"), readout(), Vector2(mid, cy + 22), Hud.color("light"))


## Text centred on x, its baseline at y, with the HUD's dark edge so it reads over a bright sky.
func _text(f: Font, s: int, t: String, at: Vector2, col: Color) -> void:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var edge := Hud.color("hud-text-edge")
	edge.a *= col.a
	draw_string_outline(f, at - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, 3, edge)
	draw_string(f, at - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
