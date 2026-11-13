extends Node3D
## The sandbox's physical interactions (BRIEF.md 7b): open the airlock door, tilt a solar panel, pick up and put
## down a cargo bag, get in the rover, draw the toilet's curtain. Each does one physical thing and changes no game state (hard rule 1).
## Every usable thing is an Interactable node in group `interactable` (CONTRACTS.md). The target is measured to the
## thing's shape, from either side, not to one spot beside it (skills/character-body, Using things): a door that
## offered E at one point outside could not be closed from inside (13 Nov playtest).

const Rover := preload("res://sandbox/rover.gd")
const CARRIABLES := 64
const WALLS := 2  # what hides a thing from the hands (CONTRACTS.md collision layers: statics)
const POINTED := 2 | 4 | 16 | 64  # what the view's centre can rest on: statics, thin statics, vehicles, carriables

signal used(what: String, pos: Vector3)  # for the sound: "door_open", "door_close", "panel", "bag", "rover", "put_down"


class Interactable extends Node3D:
	var kind: String
	var thing: Node3D  # what moves: the door, the panel, the bag, the rover
	var shape: AABB  # the thing's collision box in its own space, so it swings, tilts and gathers with the thing
	var shut: Transform3D  # the thing's own transform when closed (in its parent's space): the opening it closes
	var open := false
	var step := 0
	var box: Node  # the interactions node, which knows the hero and the world

	func prompt() -> String:
		match kind:
			"door": return "Close door" if open else "Open door"
			"curtain": return "Close curtain" if open else "Open curtain"
			"panel": return "Tilt panel"
			"bag": return "Pick up bag"
			"rover": return "Drive rover"
		return ""

	func can_use(_hero: Node3D) -> bool:
		return not (kind == "bag" and box.carried != null)

	func use(_hero: Node3D) -> void:
		box.use(self)

	## Where its box is: where the thing is now and, while a door or curtain is open, where it closes too, so it is
	## used at its doorway from either side and not only round the jamb it swung behind.
	func poses() -> Array[Transform3D]:
		var now := thing.global_transform
		return [now, thing.get_parent().global_transform * shut] if open and kind in ["door", "curtain"] else [now]

	## The point of the thing's box nearest `p` (global).
	func nearest(p: Vector3) -> Vector3:
		var best := Vector3.INF
		for xf: Transform3D in poses():
			var q := xf * (xf.affine_inverse() * p).clamp(shape.position, shape.end)
			best = q if q.distance_to(p) < best.distance_to(p) else best
		return best

	func middle() -> Vector3:
		return thing.global_transform * shape.get_center()

	## Where the hands at `p` could touch it, in each pose: the nearest point, the middle, and both ends of its longest
	## level side at the hands' height (an open door seen past a jamb shows only its far edge).
	func spots(p: Vector3) -> Array[Vector3]:
		var out: Array[Vector3] = []
		var c := shape.get_center()
		var long := Vector3.AXIS_X if shape.size.x > shape.size.z else Vector3.AXIS_Z
		for xf: Transform3D in poses():
			var l := (xf.affine_inverse() * p).clamp(shape.position, shape.end)
			var a := Vector3(c.x, l.y, c.z)
			var b := a
			a[long] = shape.position[long]
			b[long] = shape.end[long]
			out.append_array([xf * l, xf * c, xf * a, xf * b])
		return out


var world: Node3D
var player: Node3D
var tuning: Dictionary
var target: Interactable = null
var carried: Node3D = null
var prompt_label: Label
var hold: float  # m, the hands' height over the feet (reality.json hero.reach.work)
var by_thing := {}  # thing -> its Interactable, to name what a ray hit


func setup(w: Node3D, p: Node3D, t: Dictionary, sheet: Dictionary) -> void:
	world = w
	player = p
	tuning = t
	hold = 1.0
	for r: Dictionary in sheet.rows:
		if r.id == "hero.reach.work":
			hold = r.value
	for id: String in world.items:
		var item: Node3D = world.items[id]
		for part: Node3D in item.get_meta("parts"):
			if part.name == "door":
				_add("door", part)
			elif part.name == "curtain":
				# its origin is on the rail at the jamb; it gathers there along the rail, its longest level axis
				var aabb: AABB = (part as MeshInstance3D).get_aabb()
				part.set_meta("rail", Vector3.AXIS_X if aabb.size.x > aabb.size.z else Vector3.AXIS_Z)
				_add("curtain", part)
			elif str(part.name).begins_with("panel_"):
				part.set_meta("rest", part.rotation.x)
				_add("panel", part)
		if item.is_in_group("carriable"):
			_add("bag", item)
		elif id == "rover":
			item.set_script(Rover)
			item.setup(world, sheet, tuning)
			var it := _add("rover", item)
			it.shape = _hatch(item)
			it.global_position = it.middle()
	var layer := CanvasLayer.new()
	add_child(layer)
	prompt_label = Label.new()
	prompt_label.theme = load("res://ui/theme.tres")
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_top = -150
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(prompt_label)


## An interactable for `thing`, under its item (a door's stays put while it swings); its box from the thing's
## collision shapes, else its meshes.
func _add(kind: String, thing: Node3D) -> Interactable:
	var it := Interactable.new()
	it.kind = kind
	it.thing = thing
	it.box = self
	it.name = "%s_%s" % [kind, thing.name]
	it.add_to_group("interactable")
	it.shut = thing.transform
	var inv := thing.global_transform.affine_inverse()
	var shapes: Array = thing.find_children("*", "CollisionShape3D", true, false)
	var from: Array = shapes if shapes.size() else ([thing] + thing.find_children("*", "MeshInstance3D", true, false)).filter(
		func(n: Node) -> bool: return n is MeshInstance3D and (n as MeshInstance3D).mesh != null)
	for i in from.size():
		var n: Node3D = from[i]
		var b: AABB = inv * n.global_transform * ((n as CollisionShape3D).shape.get_debug_mesh().get_aabb() if n is CollisionShape3D else (n as MeshInstance3D).get_aabb())
		it.shape = b if i == 0 else it.shape.merge(b)
	(thing if kind in ["bag", "rover"] else _item_of(thing)).add_child(it)
	it.global_position = it.middle()
	by_thing[thing] = it
	return it


## The rover is boarded at its rear hatch, as a pressurised rover is (NASA's SEV: a rear hatch or suitports), so its
## box is the hatch's, in the rover's space. The drawn hatch was merged into one mesh (world.gd _merge), so each
## part's own mesh is read from the model file; the part's place is still in the tree.
func _hatch(rover: Node3D) -> AABB:
	var src: Node = load(world.data.prefabs[rover.get_meta("prefab")]).instantiate()
	var inv := rover.global_transform.affine_inverse()
	var out := AABB()
	var parts := rover.find_children("hatch*", "MeshInstance3D", true, false)
	for i in parts.size():
		var mesh: MeshInstance3D = src.find_child(parts[i].name, true, false)  # by name: rover.gd adds its own nodes
		var b: AABB = inv * (parts[i] as Node3D).global_transform * mesh.get_aabb()
		out = b if i == 0 else out.merge(b)
	src.free()
	if parts.is_empty():
		push_warning("the rover model has no hatch part: boarded anywhere round its hull")
		return (by_thing[rover] as Interactable).shape
	return out


func _item_of(n: Node) -> Node3D:
	while n.get_parent() != world:
		n = n.get_parent()
	return n


func _physics_process(_delta: float) -> void:
	var text := ""
	target = null if player.vehicle or carried else _pick()
	if player.vehicle:
		text = "Get out"
	elif carried:
		text = "Put down bag"
	elif target:
		text = target.prompt()
		target.global_position = target.middle()  # a swung door's middle, for the helmet's look
	player.attention = target  # the helmet turns toward what can be used
	# the key on a keyboard; on a phone the lit interact button says the same
	prompt_label.text = "" if text == "" else ("[E]  " + text if not DisplayServer.is_touchscreen_available() else text)


## What E would use (skills/character-body, Using things). In reach: from the body's axis to the nearest point of the
## thing's box, from either side, with no wall between it and the hands. Of those, in first person what the view's
## centre rests on, else the one nearest the aim inside the aim cone; in third person the aim is the body's heading
## and the cone `cone_deg`. The current target is favoured by `stick_deg`, so two things in reach do not flicker.
func _pick() -> Interactable:
	var hero: Node3D = player.body
	var feet := hero.global_position
	var hands := feet + Vector3.UP * hold
	var head: float = player.model.bounds.end.y
	var first: bool = player.room != ""
	var lens: Camera3D = player.cam.lens
	var from := lens.global_position if first else hands
	var aim := -lens.global_basis.z if first else (-hero.global_basis.z * Vector3(1, 0, 1)).normalized()
	var reach: float = tuning.interact.reach
	var space := hero.get_world_3d().direct_space_state
	var near: Array[Interactable] = []
	for it: Interactable in get_tree().get_nodes_in_group("interactable"):
		var q := it.nearest(hands)
		# height counts only past the feet or the head (Source's +use measures height the same way)
		var up := maxf(maxf(feet.y - q.y, q.y - feet.y - head), 0.0)
		if Vector2(Vector2(q.x - feet.x, q.z - feet.z).length(), up).length() < reach and it.can_use(hero) and _seen(space, hands, it):
			near.append(it)
	if first:
		var ray := PhysicsRayQueryParameters3D.create(from, from + aim * (from.distance_to(hands) + reach), POINTED, [hero.get_rid()])
		var hit := space.intersect_ray(ray)
		var pointed: Interactable = _owner(hit.collider) if hit else null
		if pointed in near:
			return pointed
	var half := deg_to_rad(tuning.interact.aim_deg if first else tuning.interact.cone_deg) / 2.0
	var stick := deg_to_rad(tuning.interact.stick_deg)
	var best: Interactable = null
	var best_a := INF
	for it: Interactable in near:
		# the box's point nearest the aim line (near enough: nearest to the aim at the box's distance)
		var to := it.nearest(from + aim * from.distance_to(it.nearest(from))) - from
		if not first:
			to.y = 0.0
		var a := (aim.angle_to(to) if to.length() > 0.01 else 0.0) - (stick if it == target else 0.0)
		if a < half and a < best_a:
			best = it
			best_a = a
	return best


## In sight of the hands: any of its spots with no wall in the way (Source drops a pick "behind glass or a grate").
## The thing's own body does not hide it.
func _seen(space: PhysicsDirectSpaceState3D, from: Vector3, it: Interactable) -> bool:
	for p: Vector3 in it.spots(from):
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, p, WALLS, [player.body.get_rid()]))
		if hit.is_empty() or _owner(hit.collider) == it:
			return true
	return false


## The interactable whose thing `n` is part of, or null.
func _owner(n: Node) -> Interactable:
	while n and not by_thing.has(n):
		n = n.get_parent()
	return by_thing[n] if n else null


## The interact action: out of the rover, put down what is carried, or use the target.
func interact() -> void:
	if player.vehicle:
		player.exit()
	elif carried:
		_put_down()
	elif target:
		target.use(player.body)


func use(it: Interactable) -> void:
	player.act()  # the reach clip, only when something is really used
	var s: float = tuning.interact.move_s
	match it.kind:
		"door":
			it.open = not it.open
			create_tween().tween_property(it.thing, "rotation:y", deg_to_rad(tuning.interact.door_open_deg) if it.open else 0.0, s)
		"curtain":  # slides along its rail, motion only (hard rule 1)
			it.open = not it.open
			var axis: int = it.thing.get_meta("rail")
			var to: Vector3 = it.thing.scale
			to[axis] = float(tuning.interact.curtain_gather) if it.open else 1.0
			create_tween().tween_property(it.thing, "scale", to, s)
		"panel":
			var tilts: Array = tuning.interact.panel_tilts
			it.step = (it.step + 1) % tilts.size()
			create_tween().tween_property(it.thing, "rotation:x", deg_to_rad(tilts[it.step]), s)
		"bag":
			carried = it.thing
			(carried as CollisionObject3D).collision_layer = 0
			carried.reparent(player.body, false)
			carried.position = Vector3(0, hold - 0.15, -tuning.interact.carry_ahead)  # less half the bag, so it rests on the hands
			carried.rotation = Vector3.ZERO
		"rover":
			player.enter(it.thing)
	used.emit(("door_open" if it.open else "door_close") if it.kind == "door" else it.kind, it.thing.global_position)


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
