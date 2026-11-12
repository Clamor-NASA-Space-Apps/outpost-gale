extends Node3D
## The sandbox's physical interactions (BRIEF.md 7b): open the airlock door, tilt a solar panel, pick up and put
## down a cargo bag, get in the rover. Each does one physical thing and changes no game state (hard rule 1).
## Every usable thing is an Interactable node in group `interactable` (CONTRACTS.md); the target is the nearest
## one within reach and inside a cone ahead of the hero.

const Rover := preload("res://sandbox/rover.gd")
const CARRIABLES := 64

signal used(what: String, pos: Vector3)  # for the sound: "door_open", "door_close", "panel", "bag", "rover", "put_down"


class Interactable extends Node3D:
	var kind: String
	var thing: Node3D  # what moves: the door, the panel, the bag, the rover
	var open := false
	var step := 0
	var box: Node  # the interactions node, which knows the hero and the world

	func prompt() -> String:
		match kind:
			"door": return "Close door" if open else "Open door"
			"panel": return "Tilt panel"
			"bag": return "Pick up bag"
			"rover": return "Drive rover"
		return ""

	func can_use(_hero: Node3D) -> bool:
		return not (kind == "bag" and box.carried != null)

	func use(_hero: Node3D) -> void:
		box.use(self)


var world: Node3D
var player: Node3D
var tuning: Dictionary
var target: Interactable = null
var carried: Node3D = null
var prompt_label: Label


func setup(w: Node3D, p: Node3D, t: Dictionary, sheet: Dictionary) -> void:
	world = w
	player = p
	tuning = t
	for id: String in world.items:
		var item: Node3D = world.items[id]
		for part: Node3D in item.get_meta("parts"):
			if part.name == "door":
				_add("door", part, item.to_local(part.global_position) + Vector3(0.5, 1.0, -0.6))
			elif str(part.name).begins_with("panel_"):
				part.set_meta("rest", part.rotation.x)
				_add("panel", part, item.to_local(part.global_position) + Vector3(0, -0.6, 0.9))
		if item.is_in_group("carriable"):
			_add("bag", item, Vector3(0, 0.2, 0))
		elif id == "rover":
			item.set_script(Rover)
			item.setup(world, sheet, tuning)
			_add("rover", item, Rover.HATCH * 0.55 + Vector3(0, 1.0, 0))
	var layer := CanvasLayer.new()
	add_child(layer)
	prompt_label = Label.new()
	prompt_label.theme = load("res://ui/theme.tres")
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_top = -150
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(prompt_label)


## An interactable at `local`, in the space of the thing's item, so a door's prompt point stays put while it swings.
func _add(kind: String, thing: Node3D, local: Vector3) -> void:
	var it := Interactable.new()
	it.kind = kind
	it.thing = thing
	it.box = self
	it.name = "%s_%s" % [kind, thing.name]
	it.add_to_group("interactable")
	var item: Node3D = thing if kind in ["bag", "rover"] else _item_of(thing)
	item.add_child(it)
	it.position = local


func _item_of(n: Node) -> Node3D:
	while n.get_parent() != world:
		n = n.get_parent()
	return n


func _physics_process(_delta: float) -> void:
	target = null
	var text := ""
	if player.vehicle:
		text = "Get out"
	elif carried:
		text = "Put down bag"
	else:
		var hero: Node3D = player.body
		var fwd := -hero.global_basis.z
		var best: float = tuning.interact.reach
		for it: Interactable in get_tree().get_nodes_in_group("interactable"):
			var to := it.global_position - hero.global_position
			to.y = 0.0
			var d := to.length()
			if d < best and (d < 0.3 or rad_to_deg(fwd.angle_to(to.normalized())) < tuning.interact.cone_deg / 2.0) and it.can_use(hero):
				best = d
				target = it
		if target:
			text = target.prompt()
	# the key on a keyboard; on a phone the lit interact button says the same
	prompt_label.text = "" if text == "" else ("[E]  " + text if not DisplayServer.is_touchscreen_available() else text)


## The interact action: out of the rover, put down what is carried, or use the target.
func interact() -> void:
	if player.vehicle:
		player.exit()
	elif carried:
		_put_down()
	elif target:
		target.use(player.body)


func use(it: Interactable) -> void:
	var s: float = tuning.interact.move_s
	match it.kind:
		"door":
			it.open = not it.open
			create_tween().tween_property(it.thing, "rotation:y", deg_to_rad(tuning.interact.door_open_deg) if it.open else 0.0, s)
		"panel":
			var tilts: Array = tuning.interact.panel_tilts
			it.step = (it.step + 1) % tilts.size()
			create_tween().tween_property(it.thing, "rotation:x", deg_to_rad(tilts[it.step]), s)
		"bag":
			carried = it.thing
			(carried as CollisionObject3D).collision_layer = 0
			carried.reparent(player.body, false)
			carried.position = Vector3(0, _hold_height(), -tuning.interact.carry_ahead)
			carried.rotation = Vector3.ZERO
		"rover":
			player.enter(it.thing)
	used.emit(("door_open" if it.open else "door_close") if it.kind == "door" else it.kind, it.thing.global_position)


## Hands at the suited work zone (reality.json hero.reach.work), less half the bag so it rests on them.
func _hold_height() -> float:
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json"))
	for r: Dictionary in sheet.rows:
		if r.id == "hero.reach.work":
			return r.value - 0.15
	return 1.0


func _put_down() -> void:
	var hero: Node3D = player.body
	var at: Vector3 = hero.global_position - hero.global_basis.z * (float(tuning.interact.carry_ahead) + 0.4)
	carried.reparent(world, false)
	carried.global_position = Vector3(at.x, world.height_at(at.x, at.z), at.z)
	carried.global_rotation = Vector3(0, hero.global_rotation.y, 0)
	world.rest(carried)  # in the dust under all of it, not on the height at its middle
	used.emit("put_down", carried.global_position)
	(carried as CollisionObject3D).collision_layer = CARRIABLES
	carried = null


func state() -> Dictionary:
	return {"interaction": {"target": str(target.name) if target else "", "prompt": prompt_label.text},
		"carry": str(carried.name) if carried else ""}
