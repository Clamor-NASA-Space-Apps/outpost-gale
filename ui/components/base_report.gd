extends "res://ui/hud_panel.gd"
## The base report (15 Nov playtest: "what is going on in my base right now, what costs, what earns"): a card over
## the HUD, opened and closed with one key. Power as two stacked bars (what makes it, what uses it) and the net;
## each supply with what is left, what a sol uses and makes, and how many sols it lasts; what pulls Crew health down
## and what raises it. Every number is the rules' own (sim.gd flows()): show(flows) and nothing is worked out here
## but sums. A segment is told by its pattern and its label in the line under the bar, never by colour alone.

const Hud := preload("res://ui/hud.gd")
const BAR_H := 12.0
# what the rules call each thing -> the word a kid reads
const NAMES := {"solar": "Solar", "reactor": "Reactor", "hab": "Base", "heater": "Heat", "o2_maker": "Oxygen maker",
	"moxie": "MOXIE", "greenhouse": "Greenhouse", "recycler": "Recycler"}
const SUPPLIES := {"o2_kg": "Oxygen", "water_kg": "Water", "food_kg": "Food"}
const HURTS := {"air": "No suit air", "thirst": "Thirsty", "hunger": "Hungry", "tired": "Tired", "cold": "Base is cold",
	"flare": "Solar storm", "dust": "Dust inside"}
const FILLS := ["light", "primary", "on_surface", "accent", "on_surface_variant", "light"]  # theme tokens, in turn

var flows := {}
var bars := {}  # makes, uses -> the Control that draws the stack
var lines := {}  # net, each supply and its rates, hurts -> its Label
var legends := {}  # makes, uses -> the flow of "pattern, name, kW" chips under the bar
var scale_kw := 1.0  # both bars share one scale, so their lengths compare


func _ready() -> void:
	theme_type_variation = "HudPanel"
	custom_minimum_size.x = 340
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := Hud.col([Hud.label("Base report", "HudText")], 5)
	body.add_child(Hud.label("Power", "Cap"))
	for k: String in ["makes", "uses"]:
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, BAR_H)
		bar.draw.connect(_draw_stack.bind(bar, k))
		bars[k] = bar
		body.add_child(Hud.label("Makes, kW" if k == "makes" else "Uses, kW", "HudNumDim"))
		body.add_child(bar)
		legends[k] = HFlowContainer.new()
		legends[k].add_theme_constant_override("h_separation", 12)
		body.add_child(legends[k])
	lines["net"] = _line(body)
	body.add_child(Hud.label("Life support", "Cap"))
	for k: String in SUPPLIES:
		lines[k] = _line(body)
		lines[k + "_rate"] = _line(body)
	body.add_child(Hud.label("Crew health", "Cap"))
	lines["hurts"] = _line(body)
	_line(body).text = "Raise it: drink, eat, sleep, refill air"
	add_child(body)


func _line(parent: Control) -> Label:
	var l := Hud.label("", "HudNumDim")
	l.clip_text = true  # the card is one width whatever the numbers
	parent.add_child(l)
	return l


## f: the rules' flows() (sim/sim.gd).
func show_flows(f: Dictionary) -> void:
	flows = f
	var p: Dictionary = f.power
	scale_kw = maxf(maxf(_sum(p.makes), _sum(p.uses)), 0.001)
	for k: String in ["makes", "uses"]:
		for c: Node in legends[k].get_children():
			c.free()
		var i := 0
		for n: String in p[k]:
			var swatch := Control.new()
			swatch.custom_minimum_size = Vector2(BAR_H, BAR_H)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			swatch.draw.connect(_fill.bind(swatch, i))
			legends[k].add_child(Hud.row([swatch, Hud.label("%s %.1f" % [NAMES.get(n, n), p[k][n]], "HudNumDim")], 4))
			i += 1
		bars[k].queue_redraw()
	lines.net.text = "Net %+.1f kW" % (_sum(p.makes) - _sum(p.uses))
	for k: String in SUPPLIES:
		var s: Dictionary = f.supplies[k]
		var loss: float = float(s.uses) - float(s.makes)
		var lasts := "lasts %d sols" % floori(float(s.left) / loss) if loss > 0.001 else "not falling"
		lines[k].text = "%s %d kg, %s" % [SUPPLIES[k], roundi(s.left), lasts]
		lines[k + "_rate"].text = "   uses %.1f kg, makes %.1f a sol" % [s.uses, s.makes]
	var hurts: Array = f.hurts.keys().map(func(n: String) -> String: return HURTS.get(n, n))
	lines.hurts.text = "Falling: %s" % ", ".join(hurts) if hurts else "Nothing is hurting the crew"


static func _sum(d: Dictionary) -> float:
	var t := 0.0
	for k: String in d:
		t += float(d[k])
	return t


## One stacked bar: a segment per source, in the order its legend names them.
func _draw_stack(bar: Control, k: String) -> void:
	Hud.pill(bar, Rect2(Vector2.ZERO, bar.size), Hud.color("hud-track"))
	if not flows.has("power"):
		return
	var x := 0.0
	var i := 0
	for n: String in flows.power[k]:
		var w: float = bar.size.x * float(flows.power[k][n]) / scale_kw
		_fill(bar, i, Rect2(x, 0, maxf(w - 1.0, 0.0), BAR_H))
		x += w
		i += 1


## The i-th segment's look, on a bar or on its legend swatch: every second one is hatched, so two neighbours are
## told apart without colour.
func _fill(on: Control, i: int, r := Rect2()) -> void:
	if r.size == Vector2.ZERO:
		r = Rect2(Vector2.ZERO, on.size)
	var token: String = FILLS[i % FILLS.size()]
	Hud.blit(on, "white", r, Hud.color(token, 0.4 if i % 2 else 1.0))
	if i % 2:
		for hx in range(1, int(r.size.x) - 1, 4):
			Hud.blit(on, "white", Rect2(r.position.x + hx, 0, 1.5, r.size.y), Hud.color(token))
