extends Control
## The world waypoint (design/mockups/hud.png): a glowing amber diamond over the objective with its name and distance
## on a glass label above ("Greenhouse  18 m"). Off screen or behind the camera it docks at the screen edge with an
## arrow toward the place (Hud.project, as PIP's bubble). follow(camera, hero) once, then set target and name.

const Hud := preload("res://ui/hud.gd")
const EDGE := 16.0
const ARROW := 22.0
const LIFT := 1.0  # m above the place's ground point, so the diamond floats over a doorway, not in the dust

var camera: Camera3D
var hero: Node3D
var target := Vector3.ZERO
var place := ""
var docked := false
var dir := Vector2.DOWN
var anchor := Vector2.ZERO
var tag: PanelContainer
var name_label: Label
var dist_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("shapes", true)
	name_label = Hud.label("", "HudText")
	dist_label = Hud.label("", "HudNumAmber")
	tag = Hud.panel("HudPanel", Hud.row([name_label, dist_label], 6))
	tag.name = "Waypoint"
	add_child(tag)
	hide()


func follow(cam: Camera3D, body: Node3D) -> void:
	camera = cam
	hero = body


func point(at: Vector3, label: String) -> void:
	target = at
	place = label
	name_label.text = label
	show()
	_place()


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
	dist_label.text = "%d m" % metres()
	tag.size = tag.get_combined_minimum_size()
	if camera == null:
		return
	var p := Hud.project(self, camera, target + Vector3.UP * LIFT, EDGE)
	docked = not p.on
	dir = p.dir
	anchor = p.at
	if docked:
		tag.position = Hud.dock(self, dir, tag.size, EDGE + ARROW)
	else:
		tag.position = (anchor - Vector2(tag.size.x * 0.5, tag.size.y + 16.0)).clamp(Vector2(EDGE, EDGE), size - tag.size - Vector2(EDGE, EDGE))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(tag.position, tag.size)
	if docked:
		var edge := r.get_center() + dir * (minf(r.size.x / maxf(absf(dir.x), 1e-4), r.size.y / maxf(absf(dir.y), 1e-4)) * 0.5)
		Hud.blit_at(self, "arrow", edge + dir * ARROW * 0.5, ARROW * 1.4, Hud.color("primary"), dir.angle())
		return
	Hud.blit_at(self, "glow_dot", anchor, 26.0, Hud.color("hud-glow-amber"))
	Hud.blit_at(self, "diamond", anchor, 13.0, Hud.color("primary"))
