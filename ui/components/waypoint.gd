extends Control
## The world waypoint (design/mockups/hud.png): a glowing amber diamond over the objective with its name and distance
## on a glass label above ("Greenhouse  18 m"). Off screen or behind the camera it docks at the screen edge with an
## arrow toward the place (Hud.project, as PIP's bubble). follow(camera, hero) once, then set target and name.

const Hud := preload("res://ui/hud.gd")
const EDGE := 16.0
const ARROW := 22.0
const DOT := 26.0  # the glowing dot; docked, it sits past the arrow, nearest the edge
const LIFT := 1.0  # m above the place's ground point, so the diamond floats over a doorway, not in the dust

var camera: Camera3D
var hero: Node3D
var target := Vector3.ZERO
var node: Node3D  # a moving objective (point_node), followed every frame
var below := false  # the label hangs under the place, not over it (PIP's bubble already sits over PIP)
var place := ""
var docked := false
var dir := Vector2.DOWN
var anchor := Vector2.ZERO
var tag: PanelContainer
var name_label: Label
var dist_label: Label
var avoid: Control  # PIP's bubble panel: the label steps clear of it (game_hud sets it)
var stacked := false  # the label stepped over the bubble: the bubble's arrow points the way, the dot rides the label
# its look: PIP's objective is an amber diamond; the kid's own map mark is a light ring (game_hud.gd marker)
var shape := "diamond"
var tint := "primary"
var glow := "hud-glow-amber"
var dist_style := "HudNumAmber"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("shapes", true)
	name_label = Hud.label("", "HudText")
	dist_label = Hud.label("", dist_style)
	tag = Hud.panel("HudPanel", Hud.row([name_label, dist_label], 6))
	tag.name = "Waypoint"
	add_child(tag)
	hide()


func follow(cam: Camera3D, body: Node3D) -> void:
	camera = cam
	hero = body


func point(at: Vector3, label: String) -> void:
	node = null
	target = at
	place = label
	name_label.text = label
	show()
	_place()


## Other words over the same place ("Drink water, then Eat a meal": several needs at once).
func rename(label: String) -> void:
	place = label
	name_label.text = label


## Follow a moving thing (PIP): the diamond rides over it and the distance counts live.
func point_node(n: Node3D, label: String) -> void:
	point(n.global_position, label)
	node = n


func metres() -> int:
	if hero == null:
		return 0
	var d := hero.global_position - target
	d.y = 0.0
	return roundi(d.length())


func _process(_delta: float) -> void:
	if visible:
		_place()


func _place() -> void:
	if node and is_instance_valid(node):
		target = node.global_position
	dist_label.text = Hud.distance(metres())
	tag.size = tag.get_combined_minimum_size()
	if camera == null:
		return
	var p := Hud.project(self, camera, target + Vector3.UP * (0.0 if below else LIFT), EDGE)
	docked = not p.on
	dir = p.dir
	anchor = p.at
	if docked:
		tag.position = Hud.dock(self, dir, tag.size, EDGE + ARROW + DOT)
	else:
		var off := Vector2(tag.size.x * 0.5, -16.0) if below else Vector2(tag.size.x * 0.5, tag.size.y + 16.0)
		tag.position = (anchor - off).clamp(Vector2(EDGE, EDGE), size - tag.size - Vector2(EDGE, EDGE))
	# PIP's bubble docks toward him too, often where this label is: the label steps over it, toward the middle
	stacked = false
	if avoid and avoid.is_visible_in_tree():
		var b := Rect2(avoid.position, avoid.size).grow(6.0)
		stacked = Rect2(tag.position, tag.size).intersects(b)
		if stacked:
			tag.position.y = b.end.y if tag.position.y + tag.size.y * 0.5 < size.y * 0.5 else b.position.y - tag.size.y
	queue_redraw()


func _draw() -> void:
	var r := Rect2(tag.position, tag.size)
	if docked and stacked:
		var dot := Vector2(r.position.x - DOT * 0.5, r.get_center().y)
		Hud.blit_at(self, "glow_dot", dot, DOT, Hud.color(glow))
		Hud.blit_at(self, shape, dot, 13.0, Hud.color(tint))
		return
	if docked:
		var edge := r.get_center() + dir * (minf(r.size.x / maxf(absf(dir.x), 1e-4), r.size.y / maxf(absf(dir.y), 1e-4)) * 0.5)
		Hud.blit_at(self, "arrow", edge + dir * ARROW * 0.5, ARROW * 1.4, Hud.color(tint), dir.angle())
		var dot := edge + dir * (ARROW + DOT * 0.5)
		Hud.blit_at(self, "glow_dot", dot, DOT, Hud.color(glow))
		Hud.blit_at(self, shape, dot, 13.0, Hud.color(tint))
		return
	Hud.blit_at(self, "glow_dot", anchor, 26.0, Hud.color(glow))
	Hud.blit_at(self, shape, anchor, 13.0, Hud.color(tint))
