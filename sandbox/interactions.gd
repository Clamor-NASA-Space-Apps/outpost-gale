extends Node3D
## The sandbox's physical interactions (BRIEF.md 7b): open the airlock door, pick up and put down a cargo bag, get in
## the rover, draw the toilet's curtain, brush a row of solar panels. Each does one physical thing and changes no game state (hard rule 1).
## Every usable thing is an Interactable node in group `interactable` (CONTRACTS.md). The target is measured to the
## thing's shape, from either side, not to one spot beside it (skills/character-body, Using things): a door that
## offered E at one point outside could not be closed from inside (13 Nov playtest).
## Every use happens at once, with no clip (Ravindu, 14 Nov: "a feature that doesn't exist is better than a broken
## implementation", as Half-Life 2's doors open with no hand on them): a door swings, a bag is in the hands, the hero
## is in the rover. Use spots (data/world.json `uses`) set their props' end state and emit `used(action_id)` at once:
## the rules hook (sim.use, 14 Nov). Only a seat still plays its clips (sit down, stand up), for the story's rests,
## and a `sweep` row its job in fast forward (a wing's panels brushed end to end, Ravindu, 14 Nov: _sweep_start()).

const Rover := preload("res://sandbox/rover.gd")
const CARRIABLES := 64
const WALLS := 2  # what hides a thing from the hands (CONTRACTS.md collision layers: statics)
const FAST := 3.0  # a sweep's clip plays this many times its speed, as a fast forward does (art direction)
const LIMIT := 1.6  # a sweep ends after this many times its own length, whatever held it up: never a trap
const TURN := 4.0  # 1/s: how fast the view comes round behind the hero at a sweep's row (art direction)

## A thing used: its sound name ("door_open", "door_close", "grab", "rover", "rover_exit", "set_down") the
## moment it happens; for a use spot, the row's `kind` (the action id: drink, eat, sample...).
signal used(what: String, pos: Vector3)
const VERBS := ["appear", "take", "turn", "glow", "puff", "pick"]  # what a use spot's `steps` may do to its props


class Interactable extends Node3D:
	var kind: String
	var thing: Node3D  # what moves: the door, the bag, the rover
	var shape: AABB  # the thing's collision box in its own space, so it swings and gathers with the thing
	var shut: Transform3D  # the thing's own transform when closed (in its parent's space): the opening it closes
	var open := false
	var box: Node  # the interactions node, which knows the hero and the world
	var row: Dictionary  # a use spot's world.json `uses` row (kind `spot`)
	var props := {}  # a spot's props by name (row `props`): parts of the item, or made here
	var rest := {}  # prop name -> [transform, visible] before a use: where the reset puts it back

	func prompt() -> String:
		match kind:
			"door": return "Close door" if open else "Open door"
			"curtain": return "Close curtain" if open else "Open curtain"
			"bag": return "Pick up bag"
			"rover": return "Drive rover"
			"spot": return row.prompt
		return ""

	func can_use(_hero: Node3D) -> bool:
		if kind == "spot":  # one use at a time, and never from a seat; a sample taken is gone (row `needs`)
			var needs: String = row.get("needs", "")
			return not box.player.seated and box.player.cut.is_empty() and (needs == "" or (props[needs] as Node3D).visible) \
				and (not row.get("pick", false) or box.world.can_pick(get_parent().name, middle())) \
				and (not row.has("sweep") or box.dusty(self))  # a tray with a head to eat, a row with dust to brush
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

	## A spot's stand point (global, floor origin, facing its -Z), from the row's [x, z, yaw_deg] in the item's space.
	## Without one, where the clip's glove (row `grip`, a clips.json point: `hand`, `wheel`) meets the box's middle,
	## facing the row's `face` (yaw_deg) or, without it, the way the hero comes from; a `seat` row ([x, z]) puts the
	## seated hips there instead.
	func stand() -> Transform3D:
		if row.has("stand"):
			var s: Array = row.stand
			return thing.global_transform * Transform3D(Basis(Vector3.UP, deg_to_rad(s[2])), Vector3(s[0], 0.0, s[1]))
		var at := shape.get_center()
		if row.has("seat"):
			at = Vector3(row.seat[0], 0.0, row.seat[1])
		var b := Basis(Vector3.UP, deg_to_rad(float(row.get("face", 0.0))))
		if not row.has("face"):
			var to := at - thing.to_local(box.player.body.global_position)
			to.y = 0.0
			b = Basis.looking_at(to) if to.length() > 0.01 else Basis.IDENTITY
		var p: Vector3 = box.player.model.point(&"sit_idle", "seat_hip") if row.has("seat") else box.player.model.point(StringName(row.clip), row.get("grip", "hand"))
		return thing.global_transform * Transform3D(b, Vector3(at.x, 0.0, at.z) - b * Vector3(p.x, 0.0, p.z))

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
var design: Dictionary  # the sandbox's look: role materials for the props made here
var _swinging := {}  # door Interactable -> {goal: rad, wait: bool, moved: bool}: doors on their way
var _sweep := {}  # the row being brushed: {it, t, real (s, menus included), from, far, near, face (toward the row), held (the lock before it), puff, left (share of the brushing to do)}
var _glove: BoneAttachment3D  # the hero's hand, where a sweep's `hand` props ride


func setup(w: Node3D, p: Node3D, t: Dictionary, sheet: Dictionary) -> void:
	world = w
	player = p
	tuning = t
	design = get_parent().get("design") if get_parent() else {}
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
		if item.is_in_group("carriable"):
			_add("bag", item)
		elif id == "rover":
			item.set_script(Rover)
			item.setup(world, sheet, tuning)
			var it := _add("rover", item)
			it.shape = _hatch(item)
			it.global_position = it.middle()
	# use spots: an empty node at the item's origin is the thing, the row's box its shape (the parts are welded into
	# one mesh, next-lanes.md section 0 finding 3)
	var uses: Dictionary = world.data.get("uses", {})
	var still: Array[Node3D] = []  # props no step moves, shows or hides (a site's flag, a sample case)
	var turned: Array[Node3D] = []  # parts of a still prop that a step moves (the case's lid)
	for id: String in uses:
		if id.begins_with("_") or not world.items.has(id):
			continue
		var item: Node3D = world.items[id]
		var shared := {}  # a prop by name, for a later row of the item that names it with {}: one case for a site's pebbles
		var stepped := []  # every prop name a step of any of the item's rows acts on
		for row: Dictionary in uses[id]:
			stepped.append_array(row.get("steps", []).map(func(s: Array) -> String: return s[2]))
		for row: Dictionary in uses[id]:
			var spot := Node3D.new()
			spot.name = "use_" + row.kind
			item.add_child(spot)
			var it := _add("spot", spot)
			it.row = row
			var specs: Dictionary = row.get("props", {})
			for name: String in specs:
				var spec: Dictionary = specs[name]
				if not spec.is_empty():
					var fixed: bool = not (name in stepped or spec.has("part") or spec.get("hand", false) or spec.get("hidden", false) or name in [row.get("on"), row.get("needs")])
					shared[name] = _prop(item, spec, shared, fixed)
					if fixed:
						still.append(shared[name])
					elif spec.has("in"):
						turned.append(shared[name])
				it.props[name] = shared[name]
			if row.has("on"):  # the box of a prop made here (a pebble on the ground)
				var on: Node3D = it.props[row.on]
				it.shape = (spot.global_transform.affine_inverse() * on.global_transform * _drawn(on)).grow(0.05)
			else:
				var b: Array = row.box
				it.shape = AABB(Vector3(b[0], b[1], b[2]), Vector3(b[3] - b[0], b[4] - b[1], b[5] - b[2]))
			it.global_position = it.middle()
			if row.has("sweep"):  # a 40 m row is used from its end, not its middle (the helmet's look, a guide's aim)
				it.global_position = item.global_transform * Vector3(row.sweep[0], hold, row.sweep[2])
	# a still prop is drawn with its ground cell (world.gd join()): a flag and a case cost no draw call of their own
	var meshes: Array = []
	for prop: Node3D in still:
		meshes.append_array(prop.find_children("*", "MeshInstance3D", true, false).filter(func(mi: MeshInstance3D) -> bool:
			return mi.mesh != null and not turned.any(func(part: Node3D) -> bool: return part == mi or part.is_ancestor_of(mi))))
	world.join(meshes)
	for part: Node3D in turned:
		Forge.HouseStyle.apply(part, design, false)  # it moves, so its detail travels with it (world.gd restyle())
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
## box is the hatch's and its frame's, in the rover's space. The frame was merged into one mesh (world.gd _merge), so
## each part's own mesh is read from the model file; the part's place is still in the tree.
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


func _physics_process(delta: float) -> void:
	for it: Interactable in _swinging.keys():
		_door_step(it, delta)
	if not _sweep.is_empty():
		_sweep_step(delta)
	var text := ""
	target = null if player.vehicle or carried or not _sweep.is_empty() else _pick()
	if player.vehicle:
		text = "Get out"
	elif carried:
		text = "Put down bag"
	elif target:
		text = target.prompt()
		# a swung door's middle, for the helmet's look; of a long row, the part beside the hero
		target.global_position = target.nearest(player.body.global_position + Vector3.UP * hold) if target.row.has("sweep") else target.middle()
	player.attention = target  # the helmet turns toward what can be used
	if not player.may(&"interact"):
		text = ""  # a tutorial step that blocks E shows no "E Sit" or "E Close door" that would do nothing
	# the key on a keyboard; on a phone the lit interact button says the same
	prompt_label.text = "" if text == "" else ("[E]  " + text if not DisplayServer.is_touchscreen_available() else text)


## What E would use (skills/character-body, Using things). In reach: from the body's axis to the nearest point of the
## thing's box, from either side, with no wall between it and the hands. Of those, the one nearest the body's heading
## inside the cone `cone_deg`. The current target is favoured by `stick_deg`, so two things in reach do not flicker.
func _pick() -> Interactable:
	var hero: Node3D = player.body
	var feet := hero.global_position
	var hands := feet + Vector3.UP * hold
	var head: float = player.model.bounds.end.y
	var from := hands
	var aim := (-hero.global_basis.z * Vector3(1, 0, 1)).normalized()
	var reach: float = tuning.interact.reach
	var space := hero.get_world_3d().direct_space_state
	var near: Array[Interactable] = []
	for it: Interactable in get_tree().get_nodes_in_group("interactable"):
		var q := it.nearest(hands)
		# height counts only past the feet or the head (Source's +use measures height the same way)
		var up := maxf(maxf(feet.y - q.y, q.y - feet.y - head), 0.0)
		if Vector2(Vector2(q.x - feet.x, q.z - feet.z).length(), up).length() < reach and it.can_use(hero) and _seen(space, hands, it):
			near.append(it)
	var half := deg_to_rad(tuning.interact.cone_deg) / 2.0
	var stick := deg_to_rad(tuning.interact.stick_deg)
	var best: Interactable = null
	var best_a := INF
	for it: Interactable in near:
		# the box's point nearest the aim line (near enough: nearest to the aim at the box's distance)
		var to := it.nearest(from + aim * from.distance_to(it.nearest(from))) - from
		to.y = 0.0
		var a := (aim.angle_to(to) if to.length() > 0.01 else 0.0) - (stick if it == target else 0.0)
		# two spots on one line from the hero (the suit rack over the bench, an exact tie) part by where the camera looks: up at
		# the rack picks the rack, down at the bench the bench (a tie went by float noise, 14 Nov)
		if a < half and (a < best_a - TIE or (a < best_a + TIE and _looked(it) < _looked(best))):
			best = it
			best_a = a
	return best


const TIE := 0.001  # rad (0.06 deg): a real tie (one spot over another), not two spots side by side, goes by the camera's view


## How far `it` lies from where the play camera looks, rad.
func _looked(it: Interactable) -> float:
	var lens: Camera3D = player.cam.lens
	return (-lens.global_basis.z).angle_to(it.middle() - lens.global_position)


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


## The interact action: out of the rover, put down what is carried, or use the target. Each at once.
func interact() -> void:
	if not _sweep.is_empty():
		return  # the hero is busy with a row
	if player.vehicle:
		var rover: Node3D = player.vehicle
		player.exit()  # beside its hatch, on the ground (rover.gd exit_point())
		used.emit("rover_exit", rover.global_position)  # not "rover": a beat waiting to board must not end on it
	elif carried:
		_put_down()
	elif target:
		target.use(player.body)


func use(it: Interactable) -> void:
	var s: float = tuning.interact.move_s
	match it.kind:
		"spot":
			if it.row.has("sweep"):
				_sweep_start(it)
			else:
				_play(it)
			return
		"door":
			_swing(it, not it.open, false)
			return  # its sound plays when it starts to move
		"curtain":  # slides along its rail, motion only (hard rule 1)
			it.open = not it.open
			var axis: int = it.thing.get_meta("rail")
			var to: Vector3 = it.thing.scale
			to[axis] = float(tuning.interact.curtain_gather) if it.open else 1.0
			create_tween().tween_property(it.thing, "scale", to, s)
		"bag":
			# in the hands at once: the player holds it out in front, where the carry clip's arms are (player.gd _carry())
			carried = it.thing
			(carried as CollisionObject3D).collision_layer = 0
			carried.reparent(player.body)
			used.emit("grab", carried.global_position)
			return
		"rover":
			player.enter(it.thing)
			used.emit("rover", it.thing.global_position)  # once aboard: a trip may start on it (Sol 9)
			return
	used.emit(it.kind, it.thing.global_position)


## Opens or closes `item_id`'s door as E does, with its sound and motion, but never on the hero: it waits until the
## hero is clear of its whole swing before it starts (the tutorial shutting HAB 1's hatch behind the hero).
func set_door(item_id: String, open: bool) -> void:
	for part: Node3D in world.items[item_id].get_meta("parts"):
		var it: Interactable = by_thing.get(part)
		if it and it.kind == "door" and it.open != open:
			_swing(it, open, true)


## A door never pushes or traps the hero (13 Nov playtest: HAB 1's hatch swung into the hero at the Sol 1 start
## and shoved it into the frame; 14 Nov: held half shut at the hero, it boxed the hero in). It swings the way its
## frame lets it (inward: outward its leaf meets the frame's stop). E's swing that would meet the hero passes it, its
## leaf's collision off until it stops; `wait` (the tutorial) holds the swing until the hero is clear of it instead.
## The bodies are AnimatableBody3D moved by transform: the engine pushes a body out of one moved into it.
func _swing(it: Interactable, open: bool, wait: bool) -> void:
	if _swinging.has(it) and _swinging[it].ghost:
		_ghost(it, true)  # pressed again mid-pass: solid again first
	it.open = open
	var ghost := not wait and not _clear(it, open)
	_swinging[it] = {"goal": _goal(it, open), "wait": wait, "moved": false, "ghost": ghost}
	if ghost:
		_ghost(it, false)
	_door_step(it, 1.0 / Engine.physics_ticks_per_second)  # the first step now: the sound starts with the press


## A leaf's collision on (`solid`) or off, its layers kept on the body in between.
func _ghost(it: Interactable, solid: bool) -> void:
	for b: CollisionObject3D in it.thing.find_children("*", "CollisionObject3D", true, false):
		if not solid:
			b.set_meta("layer", b.collision_layer)
			b.collision_layer = 0
		elif b.has_meta("layer"):
			b.collision_layer = b.get_meta("layer")


func _goal(it: Interactable, open: bool) -> float:
	return it.shut.basis.get_euler().y + (deg_to_rad(float(tuning.interact.door_open_deg)) if open else 0.0)


## Whether `it` can swing all the way to open (or shut) without meeting the hero, in 5 degree steps.
func _clear(it: Interactable, open: bool) -> bool:
	var now: float = it.thing.rotation.y
	var goal := _goal(it, open)
	var n := ceili(absf(goal - now) / deg_to_rad(5.0))
	for i in n + 1:
		if _hits_hero(it, lerpf(now, goal, float(i) / maxf(n, 1))):
			return false
	return true


func _door_step(it: Interactable, delta: float) -> void:
	var m: Dictionary = _swinging[it]
	var now: float = it.thing.rotation.y
	if m.wait:
		if not _clear(it, it.open):
			return
		m.wait = false
	var to := move_toward(now, m.goal, deg_to_rad(float(tuning.interact.door_open_deg)) / float(tuning.interact.move_s) * delta)
	if not m.ghost and _hits_hero(it, to):
		return  # held at the hero: it walked into the swing, and walks on
	it.thing.rotation.y = to
	if not m.moved:
		m.moved = true
		used.emit("door_open" if it.open else "door_close", it.thing.global_position)
	if to == m.goal:
		if m.ghost and _hits_hero(it, to):
			return  # solid again once the hero has stepped out of where it stopped
		if m.ghost:
			_ghost(it, true)
		_swinging.erase(it)


## Whether the door's collision at rotation `y` would touch the hero (a 2 cm gap counts).
func _hits_hero(it: Interactable, y: float) -> bool:
	var hero: CharacterBody3D = player.body
	if hero.collision_layer == 0:
		return false
	var thing: Node3D = it.thing
	var at: Transform3D = thing.get_parent().global_transform * Transform3D(Basis(Vector3.UP, y - thing.rotation.y) * thing.basis, thing.position)
	var space := hero.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = hero.collision_layer
	q.margin = 0.02
	for cs: CollisionShape3D in thing.find_children("*", "CollisionShape3D", true, false):
		q.shape = cs.shape
		q.transform = at * thing.global_transform.affine_inverse() * cs.global_transform
		if space.intersect_shape(q, 1).size():
			return true
	return false


## Down in front of the hero at once, on the floor under it (a room's deck, or its rest in the dust outside), where
## its box meets nothing: over another bag or against a wall, the nearest free spot round it, in rings of 15 cm;
## with none within 0.75 m it stays in the hands (14 Nov playtest: a bag set down on a bag sank into it).
func _put_down() -> void:
	var bag := carried
	var hero: Node3D = player.body
	var cs: CollisionShape3D = bag.find_children("*", "CollisionShape3D", true, false)[0]
	var local := bag.global_transform.affine_inverse() * cs.global_transform
	var space := hero.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.collision_mask = WALLS | world.THIN | CARRIABLES
	q.exclude = [hero.get_rid(), (bag as CollisionObject3D).get_rid()]
	var b := Basis(Vector3.UP, hero.global_rotation.y)
	var ahead: Vector3 = hero.global_position - hero.global_basis.z * (float(tuning.interact.carry_ahead) + 0.4)
	for ring in 6:
		for k in maxi(ring * 6, 1):
			var at := ahead + Vector3.RIGHT.rotated(Vector3.UP, TAU * k / maxi(ring * 6, 1)) * ring * 0.15
			if ((at - hero.global_position) * Vector3(1, 0, 1)).length() < float(player.breadth) / 2.0 + 0.3:
				continue  # never on the hero's feet
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * hold, at + Vector3.DOWN * 2.0, 1 | WALLS, [hero.get_rid()]))
			if down.is_empty() or (down.normal as Vector3).y < 0.9:
				continue
			var rest := Transform3D(b, down.position)
			q.transform = rest * local
			q.transform.origin.y += 0.02  # resting on the floor is not in it
			if not space.intersect_shape(q, 1).is_empty():
				continue
			bag.reparent(world)
			bag.global_transform = rest
			if (down.collider as CollisionObject3D).collision_layer & 1:
				world.rest(bag)  # in the dust under all of it, not on the height at its middle
			(bag as CollisionObject3D).collision_layer = CARRIABLES
			carried = null
			used.emit("set_down", bag.global_position)
			return


## A use spot, at once: its sound, then each step's end state (a lettuce head picked, a lamp lit, a dish turned to
## Earth), and `used`. A prop no `keep` holds goes back where it rested, so only what lasts is seen to change. A seat
## still sits the hero down (sit_down, then sit_idle until a move key: the story's rests).
func _play(it: Interactable) -> void:
	var row := it.row
	if row.has("seat"):
		var st := it.stand()
		var front := -st.basis.z
		player.place(Vector3(st.origin.x, player.body.global_position.y, st.origin.z), -rad_to_deg(atan2(-front.x, -front.z)))
		player.sit(true)
	if row.has("sound"):
		world.sound.emit(row.sound, it.middle())
	for name: String in it.props:
		var p: Node3D = it.props[name]
		it.rest[name] = [p.transform, p.visible]
	for s: Array in row.get("steps", []):
		_step(it, s)
	_reset(it)
	used.emit(row.kind, it.middle())


## A sweep row (data/world.json uses `sweep`: a wing's panels brushed), the same every time and in fast forward: the
## hero goes to the row's far end, then comes back along it facing the row, the row's clip looping with its `hand`
## props in the glove, the row's dust thinning as the brush goes (world/sky_clock.gd brush()). The line is on the side
## the panels lean to (the trackers turn them east in the morning, west after noon): from their high side the brush
## would be at their backs, and the kid would watch a row's underside come clean (14 Nov pictures). Game time runs
## fast meanwhile, for the sky and the rules alike (the clock's rush; tuning.json interact.clean_*), so the job costs
## what that time costs. The kid's input is held. The hero is set along the line, never walked: a post or a panel
## in the way cannot stop it, and the job ends on the clock (LIMIT), the hero at the near end and `used` told once.
func _sweep_start(it: Interactable) -> void:
	var s: Array = it.row.sweep
	var xf := it.thing.global_transform
	var z := float(s[2])
	var panel := it.get_parent().find_child("panel_*", true, false) as Node3D
	var lean: float = xf.basis.z.dot(panel.global_basis.y) if panel else 0.0  # its face is its +Y
	if absf(lean) > 0.05:
		z = absf(z) * signf(lean)
	var ends: Array[Vector3] = [xf * Vector3(s[0], 0.0, z), xf * Vector3(s[1], 0.0, z)]
	var from: Vector3 = player.body.global_position
	if from.distance_to(ends[0]) > from.distance_to(ends[1]):
		ends.reverse()
	_sweep = {"it": it, "t": 0.0, "real": 0.0, "from": from, "far": ends[1], "near": ends[0],
		"face": xf.basis * Vector3(0.0, 0.0, -z) * Vector3(1, 0, 1), "held": player.allowed.duplicate(), "puff": 0.0, "left": 1.0}
	player.allow(["none"])
	player.speed = 0.0
	if _glove == null:
		_glove = BoneAttachment3D.new()
		_glove.bone_name = player.model.clips[it.row.clip].get("hand_bone", "hand_r")
		player.model.skeleton.add_child(_glove)
	for name: String in it.props:
		if it.row.props[name].get("hand", false):
			var p: Node3D = it.props[name]
			if p.get_parent() != _glove:
				p.reparent(_glove, false)
				p.transform = p.get_meta("local")
			p.visible = true
	if it.row.has("sound"):
		world.sound.emit(it.row.sound, from)
	if _clock():
		_clock().rush = float(tuning.interact.clean_min) / 60.0 / float(tuning.interact.clean_s)


func _sweep_step(delta: float) -> void:
	var c := _sweep
	var k: Dictionary = tuning.interact
	var clock := _clock()
	c.real += delta
	if not (clock and clock.paused):
		c.t += delta  # a menu holds the clock, and the job with it
	var u: float = c.t / float(k.clean_s)
	if u >= 1.0 or c.real >= float(k.clean_s) * LIMIT:
		_sweep_end()
		return
	var run: float = k.clean_run
	var at: Vector3 = (c.from as Vector3).lerp(c.far, smoothstep(0.0, 1.0, u / run)) if u < run else (c.far as Vector3).lerp(c.near, (u - run) / (1.0 - run))
	_sweep_put(at, (c.far - c.from) * Vector3(1, 0, 1) if u < run else c.face)
	player.cam.yaw = lerp_angle(player.cam.yaw, atan2(-c.face.x, -c.face.z), 1.0 - exp(-TURN * delta))  # the row in view
	var model: Node3D = player.model
	var clip := StringName(c.it.row.clip)
	if model.act(clip):
		model.timer = float(model.clips[clip].length) / FAST
	if model.phase == "act":
		model.tree.advance(delta * (FAST - 1.0))
	if u >= run:
		if clock:  # the row's dust thins as the brush goes: each step keeps the share of it still to brush
			var left: float = (1.0 - u) / (1.0 - run)
			clock.brush(c.it.middle(), left / c.left)
			c.left = left
		c.puff -= delta
		if c.puff <= 0.0:
			c.puff = float(k.clean_every)
			world.puff(_glove.global_position, Vector3.UP * 0.4, 1.0)


## The hero on the ground at `at`, facing along `to`.
func _sweep_put(at: Vector3, to: Vector3) -> void:
	player.body.global_position = Vector3(at.x, world.height_at(at.x, at.z) + 0.01, at.z)
	if to.length() > 0.01:
		player.yaw = atan2(-to.x, -to.z)


func _sweep_end() -> void:
	var c := _sweep
	var it: Interactable = c.it
	_sweep = {}
	_sweep_put(c.near, c.face)
	for name: String in it.props:
		if it.row.props[name].get("hand", false):
			(it.props[name] as Node3D).visible = false
	player.model.timer = 0.0  # the clip ends with the job
	if player.allowed == ["none"]:
		player.allow(c.held)  # unless a beat set its own lock meanwhile
	if _clock():
		_clock().rush = 0.0
	used.emit(it.row.kind, it.middle())


## Whether a sweep row has dust left to brush: the look's own count per row (world/sky_clock.gd). No clock: always.
func dusty(it: Interactable) -> bool:
	return _clock() == null or _clock().dusty(it.middle())


func _clock() -> Node:
	return get_parent().get("clock") if get_parent() else null


## One step's end state. appear [prop]: shown. turn [prop, axis, deg]: turned `deg` from where it rested about its
## own x, y or z (`earth`: the elevation that points at Earth now). glow [prop, on]: shown or hidden (a lit pane).
## puff [prop]: a puff of dust there. pick [prop]: a lettuce head cut off the tray (row `pick`: none left to eat hides
## the prompt). take: nothing (it was a prop moving into the glove, with the clip).
func _step(it: Interactable, s: Array) -> void:
	var p: Node3D = it.props[s[2]]
	match s[1]:
		"appear":
			p.visible = true
		"turn":
			var axis: int = ["x", "y", "z"].find(s[3])
			var rest: Transform3D = it.rest[s[2]][0]
			var deg := _earth_x() - rest.basis.get_euler()[axis] if str(s[4]) == "earth" else deg_to_rad(float(s[4]))
			p.set_indexed("rotation:" + str(s[3]), rest.basis.get_euler()[axis] + deg)
		"glow":
			p.visible = bool(s[3])
		"puff":
			world.puff(p.global_position, Vector3.UP * 0.4, 1.0)
		"pick":  # the nearest head on the tray is cut (world.pick())
			var sim: Node = get_parent().get("sim") if get_parent() else null
			if world.pick(it.get_parent().name, it.middle(), int(sim.sim.sol) if sim else 1).is_empty():
				p.visible = false


## Every prop of a spot back where it rested, but a `keep` prop keeps what it became.
func _reset(it: Interactable) -> void:
	var specs: Dictionary = it.row.get("props", {})
	for name: String in it.rest:
		var p: Node3D = it.props[name]
		var was: Array = it.rest[name]
		if not specs[name].get("keep", false):
			p.visible = was[1]
			p.transform = was[0]
	it.rest.clear()


## The rotation about x that points the comms dish at Earth now (rad): Earth's elevation in the night design's real
## sky at the clock's hour (house_style.gd _sky_frame, as sun_at() does for the sun), between 5 and 85 degrees. The
## dish rests at rotation -(90 - elevation) (forge/building_dish.py). Elevation only: its turret is welded to the mount.
func _earth_x() -> float:
	var C: Dictionary = design.get("lighting", {}).get("celestial", {})
	var hour: float = _clock().hour() if _clock() else 12.0
	var earth: Array = C.get("planets", []).filter(func(q: Dictionary) -> bool: return q.get("name") == "Earth")
	var el := 40.0
	if earth.size():
		var f := Forge.HouseStyle._sky_frame(C)
		var d: Vector3 = (f.frame as Basis).transposed() * f.dir.call([earth[0].ra, earth[0].dec])
		var th := atan2(f.sun_eq.y, f.sun_eq.x) + deg_to_rad((hour - 12.0) * 15.0)
		var lat: float = f.lat
		el = rad_to_deg(asin(d.dot(Vector3(cos(lat) * cos(th), cos(lat) * sin(th), sin(lat)))))
	return -deg_to_rad(90.0 - clampf(el, 5.0, 85.0))


## A spot's prop from its row spec, in the item's space: `part` (a node of the item, or of the prop `in`), `model`
## (a GLB path, `scale`, or the scale of `like`'s plant: a slot's lettuce), or `meshes` (built-in shapes in roles:
## {box: size | cyl: [r, h] | torus: [inner, outer] | line: [from, to], r, at, rot, role}). `at` [x, y, z], `rot`
## degrees, `ground` sets it on the terrain (`at`'s y over it), `hidden` until a step shows it, `hand` rides in the glove
## during a sweep and is unseen otherwise, `solid` gives
## it a box to walk into, `layer` its
## render layers (2: the ground's family, a pebble).
func _prop(item: Node3D, spec: Dictionary, made: Dictionary, still := false) -> Node3D:
	if spec.has("part"):
		var owner: Node3D = made[spec["in"]] if spec.has("in") else item
		var part: Node3D = owner.find_child(spec.part, true, false)
		assert(part != null, "uses: no part %s" % spec.part)
		return part
	var n: Node3D
	var k := float(spec.get("scale", 1.0))
	if spec.has("model"):
		n = (load(spec.model) as PackedScene).instantiate()
		for b: Node in n.find_children("*", "CollisionObject3D", true, false):
			b.free()  # a pebble's import body (-convcol) sat on layer 1: something to stand on in the tongs
		Forge.HouseStyle.apply(n, design, still)  # still: the cell's own world-space materials, so it merges into them
		if spec.has("like"):
			var slot: Node = item.find_child(spec.like, true, false)
			k = (slot.get_child(0) as Node3D).scale.x if slot and slot.get_child_count() else k
	else:
		n = Node3D.new()
		for m: Dictionary in spec.meshes:
			n.add_child(_mesh(m, bool(spec.get("clean", false)), still))
	# placed in the item's space but kept out of its subtree: a case on the ground is not one of the item's feet,
	# and the item's merge and checks see only its own model
	var a: Array = spec.get("at", [0, 0, 0])
	var local := Transform3D(Basis.from_euler(Vector3(spec.rot[0], spec.rot[1], spec.rot[2]) * PI / 180.0, EULER_ORDER_YXZ) if spec.has("rot") else Basis.IDENTITY, Vector3(a[0], a[1], a[2]))
	add_child(n)
	n.set_meta("local", local)  # a `hand` prop's place in the glove (_sweep_start())
	n.global_transform = item.global_transform * local
	n.scale = Vector3.ONE * k
	if spec.get("ground", false):
		var g := n.global_position
		n.global_position.y = world.height_at(g.x, g.z) + float(a[1])  # `at`'s y: how far over the ground
	var pieces := n.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D)
	if not still and pieces.size() > 1 and not spec.has("model"):
		# a prop that moves as one (the valve wheel) is drawn as one mesh per material, its pieces kept hidden
		world._merge(pieces, n)
		for mi: MeshInstance3D in pieces:
			mi.visible = false
	# on the ground, as world.gd _item(): each shadow split draws a caster again, and a pebble's shadow is a few pixels
	var low: bool = spec.get("ground", false) and _drawn(n).size.y * k < float(world.data.shadow_min)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.layers = int(spec.get("layer", 1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if low and not still else mi.cast_shadow
	if spec.get("solid", false):  # walked into, not through: a box on the thin layer (CONTRACTS.md collision layers)
		var body := StaticBody3D.new()
		body.collision_layer = world.THIN
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		var d := _drawn(n)
		box_shape.size = d.size
		col.shape = box_shape
		col.position = d.get_center()
		body.add_child(col)
		n.add_child(body)
	n.visible = not spec.get("hidden", false) and not spec.get("hand", false)  # a `hand` prop shows only in the glove, during a sweep
	return n


func _mesh(m: Dictionary, clean: bool, still: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var at: Array = m.get("at", [0, 0, 0])
	mi.position = Vector3(at[0], at[1], at[2])
	if m.has("box"):
		var b := BoxMesh.new()
		b.size = Vector3(m.box[0], m.box[1], m.box[2])
		mi.mesh = b
	elif m.has("torus"):
		var t := TorusMesh.new()
		t.inner_radius = m.torus[0]
		t.outer_radius = m.torus[1]
		mi.mesh = t
	else:  # a rod: cyl [r, h] standing on y, or a line between two points
		var c := CylinderMesh.new()
		c.radial_segments = 12
		c.top_radius = m.cyl[0] if m.has("cyl") else m.r
		c.bottom_radius = c.top_radius
		c.height = m.cyl[1] if m.has("cyl") else 1.0
		mi.mesh = c
		if m.has("line"):
			var p0 := Vector3(m.line[0][0], m.line[0][1], m.line[0][2])
			var p1 := Vector3(m.line[1][0], m.line[1][1], m.line[1][2])
			c.height = p0.distance_to(p1)
			var y := (p1 - p0).normalized()
			var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
			mi.transform = Transform3D(Basis(x, y, x.cross(y)), (p0 + p1) / 2.0)
			return _role(mi, m, clean, still)
	if m.has("rot"):
		mi.rotation_degrees = Vector3(m.rot[0], m.rot[1], m.rot[2])
	return _role(mi, m, clean, still)


func _role(mi: MeshInstance3D, m: Dictionary, clean: bool, still: bool) -> MeshInstance3D:
	mi.material_override = Forge.HouseStyle.role(design, m.role, still, clean)
	return mi


## A prop's drawn box in its own space.
func _drawn(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var b: AABB = n.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			out = b if first else out.merge(b)
			first = false
	return out


func state() -> Dictionary:
	return {"interaction": {"target": str(target.name) if target else "", "prompt": prompt_label.text},
		"carry": str(carried.name) if carried else ""}
