extends Node3D
## The sandbox's physical interactions (BRIEF.md 7b): open the airlock door, tilt a solar panel, pick up and put
## down a cargo bag, get in the rover, draw the toilet's curtain. Each does one physical thing and changes no game state (hard rule 1).
## Every usable thing is an Interactable node in group `interactable` (CONTRACTS.md). The target is measured to the
## thing's shape, from either side, not to one spot beside it (skills/character-body, Using things): a door that
## offered E at one point outside could not be closed from inside (13 Nov playtest).
## Use spots (data/world.json `uses`) play a clip, run their props through a timeline of verbs and, once the clip
## has run to its end, emit `used(action_id)`: the rules hook (sim.use, 14 Nov). Their sound plays at the start.

const Rover := preload("res://sandbox/rover.gd")
const CARRIABLES := 64
const WALLS := 2  # what hides a thing from the hands (CONTRACTS.md collision layers: statics)
# Art direction for the hands (second playtest, 13 Nov: doors, the rover and bags moved with no hands on them):
const GRIP := 0.35  # share of the reach clip (clips.json interact, which names no work_at) when the glove is on the handle
const PICK := &"kneel_pick"  # down to a bag on the ground and up again: its glove is at 0.44 m at work_at
const FADE_S := 0.3  # s of the fade to dark and back through the rover's hatch
const HATCH_OPEN_S := 0.45  # s the rover's hatch swings before the fade: most of its way (tuning.interact.move_s is all of it)

## A thing used: its sound name ("door_open", "door_close", "panel", "grab", "rover", "set_down") the moment it
## happens (a door's when it starts to move, a bag's when the glove takes it or it lands); for a use spot, the row's `kind` (the action id: drink, eat, sample...) once its clip has run to its end.
signal used(what: String, pos: Vector3)
const VERBS := ["appear", "take", "turn", "glow", "puff"]  # what a use spot's `steps` may do to its props


class Interactable extends Node3D:
	var kind: String
	var thing: Node3D  # what moves: the door, the panel, the bag, the rover
	var shape: AABB  # the thing's collision box in its own space, so it swings, tilts and gathers with the thing
	var shut: Transform3D  # the thing's own transform when closed (in its parent's space): the opening it closes
	var open := false
	var step := 0
	var box: Node  # the interactions node, which knows the hero and the world
	var row: Dictionary  # a use spot's world.json `uses` row (kind `spot`)
	var props := {}  # a spot's props by name (row `props`): parts of the item, or made here
	var rest := {}  # prop name -> [transform, visible] before a use: where the reset puts it back

	func prompt() -> String:
		match kind:
			"door": return "Close door" if open else "Open door"
			"curtain": return "Close curtain" if open else "Open curtain"
			"panel": return "Tilt panel"
			"bag": return "Pick up bag"
			"rover": return "Drive rover"
			"spot": return row.prompt
		return ""

	func can_use(_hero: Node3D) -> bool:
		if kind == "spot":  # one use at a time, and never from a seat; a sample taken is gone (row `needs`)
			var needs: String = row.get("needs", "")
			return not box.player.seated and box.player.cut.is_empty() and box.playing == null and (needs == "" or (props[needs] as Node3D).visible)
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
var playing: Interactable = null  # the use spot whose clip and props are playing
var _left := 0.0  # s of its clip left
var _tweens: Array[Tween] = []  # the playing spot's timeline and its steps' motions: all stopped by a reset
var _ride := {}  # prop -> the node it rides with after a `take` (the glove, the tongs, a tube)
var _sockets := {}  # bone name -> its BoneAttachment3D on the hero: where hand props go
var _swinging := {}  # door Interactable -> {goal: rad, wait: bool, delay: s, moved: bool}: doors on their way
var _seq := 0.0  # s left of a pick-up, a put-down or a trip through the rover's hatch: E waits for it
var _rover_hatch: Interactable  # the rover's hatch leaf, swung by _swing() as a door is; never a target itself
var _fade: ColorRect  # the hatch's fade to dark


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
			elif str(part.name).begins_with("panel_"):
				part.set_meta("rest", part.rotation.x)
				_add("panel", part)
		if item.is_in_group("carriable"):
			_add("bag", item).row = {"clip": String(PICK)}  # its stand() puts the kneeling glove on the bag
		elif id == "rover":
			item.set_script(Rover)
			item.setup(world, sheet, tuning)
			var it := _add("rover", item)
			it.shape = _hatch(item)
			it.global_position = it.middle()
			var leaf := item.find_child("hatch", true, false) as Node3D  # world.json `moving`: it keeps its own node
			if leaf:
				_rover_hatch = Interactable.new()
				_rover_hatch.kind = "hatch"
				_rover_hatch.thing = leaf
				_rover_hatch.shut = leaf.transform
				item.add_child(_rover_hatch)
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
					shared[name] = _prop(item, spec, shared, StringName(row.get("clip", "")), fixed)
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
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


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
	_seq = maxf(_seq - delta, 0.0)
	for it: Interactable in _swinging.keys():
		_door_step(it, delta)
	var text := ""
	if playing and not playing.row.has("seat") and _left > 0.15 and player.cut.get("clip") != StringName(playing.row.clip):
		_reset(playing)  # a move key cut the clip short: no action done, every prop back
	_left -= delta
	# while a spot plays it stays the target (no prompt): what was used is still known when its action is done
	target = playing if playing else (null if player.vehicle or carried else _pick())
	if player.vehicle:
		text = "Get out"
	elif carried:
		text = "Put down bag"
	elif target and not playing:
		text = target.prompt()
		target.global_position = target.middle()  # a swung door's middle, for the helmet's look
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
		# a spot on a bigger usable thing (clean a panel row that also tilts) counts `favour_deg` nearer the aim, or
		# the row's box, round it on every side, would always take the prompt from it
		var a := (aim.angle_to(to) if to.length() > 0.01 else 0.0) - (stick if it == target else 0.0) - deg_to_rad(float(it.row.get("favour_deg", 0.0)))
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
	if _seq > 0.0:
		return  # a pick-up, a put-down or the hatch is under way
	if player.vehicle:
		# the reverse of boarding: the hatch opens, out through it in a fade, and it shuts once the hero is clear
		_hatch_swing(true)
		_seq = HATCH_OPEN_S + FADE_S * 2.0
		var tw := create_tween()
		tw.tween_interval(HATCH_OPEN_S)
		var rover: Node3D = player.vehicle
		tw.tween_callback(func() -> void: _hatch_fade(func() -> void:
			player.exit()
			_hatch_swing(false, true)
			used.emit("rover_exit", rover.global_position)))  # not "rover": a beat waiting to board must not end on it
	elif carried:
		_put_down()
	elif target and not playing:
		target.use(player.body)


func use(it: Interactable) -> void:
	if it.kind == "spot":
		_play(it)
		return
	var s: float = tuning.interact.move_s
	if it.kind in ["curtain", "panel"]:
		player.act()  # the reach clip, only when something is really used
	match it.kind:
		"door":
			# the hand goes to the handle (out of the swing first), then the door moves: never by itself
			var length: float = _reach_door(it)
			_swing(it, not it.open, false, length * GRIP)
			return  # its sound plays when it starts to move
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
			_pick_up(it)
			return
		"rover":
			# to the hatch, a hand on it and it swings open, then through it in a fade: the hero is aboard when the view
			# comes back, and the hatch shuts behind (14 Nov playtest: "entering the rover is instant, no animation")
			var length: float = player.perform(&"interact", Transform3D(Basis.looking_at(-it.thing.global_basis.z * Vector3(1, 0, 1)), it.thing.exit_point()))
			_seq = length * GRIP + HATCH_OPEN_S + FADE_S * 2.0
			var tw := create_tween()
			tw.tween_interval(length * GRIP)
			tw.tween_callback(func() -> void:
				if length > 0.0 and player.cut.get("clip") != &"interact":
					_fade_out()  # walked off before the hand was on the hatch: not boarded
					tw.kill()
					return
				_hatch_swing(true))
			tw.tween_interval(HATCH_OPEN_S)
			tw.tween_callback(func() -> void:
				_hatch_fade(func() -> void:
					player.enter(it.thing)
					_hatch_swing(false)
					used.emit("rover", it.thing.global_position)))  # once aboard: a trip may start on it (Sol 9)
			return
	used.emit(it.kind, it.thing.global_position)


## The rover's hatch open or shut, with a door's motion and sounds (_swing()); `wait` holds it until the hero is clear.
func _hatch_swing(open: bool, wait := false) -> void:
	if _rover_hatch:
		_swing(_rover_hatch, open, wait)


## Dark over FADE_S, `then` at the darkest, light again: stepped through the open hatch.
func _hatch_fade(then: Callable) -> void:
	_seq = maxf(_seq, FADE_S * 2.0)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_S)
	tw.tween_callback(then)
	tw.tween_property(_fade, "modulate:a", 0.0, FADE_S)


## A pick-up, a put-down or a trip through the hatch is under way (E waits for it).
func busy() -> bool:
	return _seq > 0.0


func _fade_out() -> void:
	_seq = 0.0
	_fade.modulate.a = 0.0


## The reach for a door's handle: the hero turns to it in place, or, standing where the door will swing, first steps
## back out of the swing (a person opening a door toward them steps aside); its length, 0 if refused.
func _reach_door(it: Interactable) -> float:
	var thing: Node3D = it.thing
	var free: float = it.shape.position.x if absf(it.shape.position.x) > absf(it.shape.end.x) else it.shape.end.x
	var handle := thing.global_transform * Vector3(free * 0.85, hold, it.shape.get_center().z)
	var hinge := thing.global_position
	var feet: Vector3 = player.body.global_position
	var at := feet
	var shut: Transform3D = thing.get_parent().global_transform * it.shut
	# how far into the swing's side of the shut face the feet are (a positive turn swings a leaf on -x to +z)
	var side: float = ((shut.affine_inverse() * feet).z - it.shape.get_center().z) * -signf(free) * signf(float(tuning.interact.door_open_deg))
	var out := (feet - hinge) * Vector3(1, 0, 1)
	var leaf := 0.0  # the farthest the leaf reaches from its hinge
	for i in 8:
		var c := it.shape.get_endpoint(i)
		leaf = maxf(leaf, Vector2(c.x, c.z).length())
	var clear := leaf + float(player.breadth) / 2.0 + 0.03
	if side > -float(player.breadth) / 2.0 and out.length() < clear and out.length() > 0.01:
		at = hinge + out.normalized() * clear
		at.y = feet.y
	var to := (handle - at) * Vector3(1, 0, 1)
	var length: float = player.perform(&"interact", Transform3D(Basis.looking_at(to) if to.length() > 0.01 else player.body.global_basis, at))
	if length > 0.0 and at != feet:
		# the whole step out of the swing, past perform's glide_max (sized for use spots): short of it the door
		# stalls part open at the hero (the Sol 1 start is 0.7 m inside it). Still a slide that walls stop.
		player.cut.move = (at - feet) * Vector3(1, 0, 1)
	return length


## Down to the bag, the glove on it at the clip's work_at, up with it, and into the carry on the chest.
func _pick_up(it: Interactable) -> void:
	var bag: Node3D = it.thing
	var length: float = player.perform(PICK, it.stand())
	if length == 0.0:
		return
	carried = bag
	_seq = length
	var grab: float = float(player.model.clips[PICK].work_at) * length
	var tw := create_tween()
	tw.tween_interval(grab)
	tw.tween_callback(func() -> void:
		if player.cut.get("clip") != PICK:
			carried = null  # walked off before the glove reached it
			_seq = 0.0
			tw.kill()
			return
		(bag as CollisionObject3D).collision_layer = 0
		used.emit("grab", bag.global_position)
		var from := bag.global_position
		var glove := _socket(PICK)
		var lift := create_tween()
		lift.tween_method(func(k: float) -> void: bag.global_position = from.lerp(glove.global_position, smoothstep(0.0, 1.0, k)), 0.0, 1.0, 0.25)
		lift.tween_callback(func() -> void: _ride[bag] = glove))
	tw.tween_interval(maxf(length - grab - 0.25, 0.0))
	# from the glove to the chest's hold, then the player carries it there (player.gd _carry())
	var from := []
	tw.tween_callback(func() -> void:
		_ride.erase(bag)
		from.append(bag.global_transform))
	tw.tween_method(func(k: float) -> void:
		var hold_at: Transform3D = player.model.bag_transform()
		bag.global_transform = (from[0] as Transform3D).interpolate_with(Transform3D(hold_at.basis, hold_at.origin - hold_at.basis * _centre(bag)), smoothstep(0.0, 1.0, k)), 0.0, 1.0, 0.25)
	tw.tween_callback(func() -> void: bag.reparent(player.body))


## A bag's drawn centre in its own space (player.gd _carry() holds it there).
func _centre(bag: Node3D) -> Vector3:
	for mi: MeshInstance3D in bag.find_children("*", "MeshInstance3D", true, false):
		return bag.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb().get_center()
	return Vector3.ZERO


## Opens or closes `item_id`'s door as E does, with its sound and motion, but never on the hero: it waits until the
## hero is clear of its whole swing before it starts (the tutorial shutting HAB 1's hatch behind the hero).
func set_door(item_id: String, open: bool) -> void:
	for part: Node3D in world.items[item_id].get_meta("parts"):
		var it: Interactable = by_thing.get(part)
		if it and it.kind == "door" and it.open != open:
			_swing(it, open, true)


## A door never pushes or traps the hero (13 Nov playtest: HAB 1's hatch swung into the hero at the Sol 1 start
## and shoved it into the frame). It swings the way its frame lets it (inward: outward its leaf meets the frame's
## stop), and it moves a step a frame only where its shape at the next step is clear of the hero, so it stops at the
## hero and goes on once the way is clear.
## The bodies are AnimatableBody3D moved by transform: the engine pushes a body out of one moved into it.
func _swing(it: Interactable, open: bool, wait: bool, delay := 0.0) -> void:
	it.open = open
	var goal := it.shut.basis.get_euler().y + (deg_to_rad(float(tuning.interact.door_open_deg)) if open else 0.0)
	_swinging[it] = {"goal": goal, "wait": wait, "delay": delay, "moved": false}
	_door_step(it, 1.0 / Engine.physics_ticks_per_second)  # the first step now: the sound starts with the press


func _door_step(it: Interactable, delta: float) -> void:
	var m: Dictionary = _swinging[it]
	if m.delay > 0.0:
		# ponytail: a press then a step at once still opens it (a kid's E then W, audio_test): kept on purpose
		m.delay -= delta
		return  # the hand is on its way to the handle
	var now: float = it.thing.rotation.y
	if m.wait:
		var n := ceili(absf(m.goal - now) / deg_to_rad(5.0))
		for i in n + 1:
			if _hits_hero(it, lerpf(now, m.goal, float(i) / maxf(n, 1))):
				return
		m.wait = false
	var to := move_toward(now, m.goal, deg_to_rad(float(tuning.interact.door_open_deg)) / float(tuning.interact.move_s) * delta)
	if _hits_hero(it, to):
		return  # held at the hero
	it.thing.rotation.y = to
	if not m.moved:
		m.moved = true
		used.emit("door_open" if it.open else "door_close", it.thing.global_position)
	if to == m.goal:
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


## Down on one knee, the bag from the chest to the glove, let go beside the hero at work_at, and it falls the last
## few centimetres under Mars gravity onto its rest in the dust (world.rest()), with a puff.
func _put_down() -> void:
	var bag := carried
	var hero: Node3D = player.body
	var length: float = player.perform(PICK, hero.global_transform)
	_seq = length + 0.6
	bag.reparent(self)
	var from := bag.global_transform
	var tw := create_tween()
	var grip := _socket(PICK)
	tw.tween_method(func(k: float) -> void: bag.global_position = from.origin.lerp(grip.global_position, smoothstep(0.0, 1.0, k)), 0.0, 1.0, maxf(float(player.model.clips[PICK].work_at) * length, 0.05))
	tw.tween_callback(func() -> void:
		# beside the knee, clear of the body: the drop must not land on the hero
		var p := bag.global_position
		var away := (p - hero.global_position) * Vector3(1, 0, 1)
		away = away if away.length() > 0.05 else -hero.global_basis.z
		var at: Vector3 = hero.global_position + away.normalized() * maxf(away.length(), float(player.breadth) / 2.0 + 0.3)
		var held := bag.global_transform
		bag.global_transform = Transform3D(Basis(Vector3.UP, hero.global_rotation.y), Vector3(at.x, world.height_at(at.x, at.z), at.z))
		world.rest(bag)  # in the dust under all of it, not on the height at its middle
		var rest := bag.global_transform
		bag.global_transform = held
		carried = null
		var fall := sqrt(2.0 * maxf(held.origin.y - rest.origin.y, 0.01) / float(player.gravity))
		var drop := create_tween()
		drop.tween_property(bag, "global_transform", rest, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drop.tween_callback(func() -> void:
			bag.reparent(world)
			(bag as CollisionObject3D).collision_layer = CARRIABLES
			world.puff(rest.origin, Vector3.UP * 0.2, 0.5)
			used.emit("set_down", rest.origin)))


## A use spot: the hero glides to its stand and plays its clip (or sits), its sound starts, and its `steps` run on
## one timeline as fractions of the clip: [at, verb, prop, args...]. Once the clip has run to its end the action is
## done (`used`); `hold_s` after the last step every prop goes back to where it was, but a `keep` prop keeps its state.
func _play(it: Interactable) -> void:
	var row := it.row
	var length := 0.0
	if row.has("seat"):
		var st := it.stand()
		var front := -st.basis.z
		player.place(Vector3(st.origin.x, player.body.global_position.y, st.origin.z), -rad_to_deg(atan2(-front.x, -front.z)))
		player.sit(true)
		length = float(player.model.clips.sit_down.length)
	elif str(row.get("clip", "")) != "":
		length = player.perform(StringName(row.clip), it.stand())
		if length == 0.0:
			return
	if row.has("sound"):
		world.sound.emit(row.sound, it.middle())  # the sound now; `used` names the action once it is done
	if length == 0.0:
		used.emit(row.kind, it.middle())  # a spot with no motion (a bed: the cine takes over)
		return
	for name: String in it.props:
		var p: Node3D = it.props[name]
		it.rest[name] = [p.transform, p.visible]
	playing = it
	_left = length
	var timeline := _tween().set_parallel(true)
	var end := length
	for s: Array in row.get("steps", []):
		var at := float(s[0]) * length
		timeline.tween_callback(_step.bind(it, s)).set_delay(at)
		end = maxf(end, at + (float(s[3]) if s.size() > 3 and s[1] in ["appear", "take"] else float(s[5]) if s.size() > 5 else 0.0))
	timeline.tween_callback(_done.bind(it)).set_delay(maxf(length - 0.1, 0.0))
	timeline.tween_callback(_reset.bind(it)).set_delay(end + float(row.get("hold_s", 0.1)))  # the props' last pose held


func _done(it: Interactable) -> void:
	if it == playing and (player.seated if it.row.has("seat") else player.cut.get("clip") == StringName(it.row.clip)):
		used.emit(it.row.kind, it.middle())


## One step of a spot's timeline. appear [prop, s]: grows from nothing. take [prop, s, to]: eases to `to` (the
## glove, `hand`, or another prop) and rides with it. turn [prop, axis, deg, s]: to `deg` from where it rested about
## its own x, y or z (`earth`: the elevation that points at Earth now). glow [prop, on]: shown or hidden (a lit
## pane). puff [prop]: a puff of dust there.
func _step(it: Interactable, s: Array) -> void:
	var p: Node3D = it.props[s[2]]
	match s[1]:
		"appear":
			var full := p.scale
			p.scale = full * 0.01
			p.visible = true
			_tween().tween_property(p, "scale", full, float(s[3]))
		"take":
			var to: Node3D = _socket(StringName(it.row.clip)) if s.size() < 5 or s[4] == "hand" else it.props[s[4]]
			var from := p.global_position
			_ride.erase(p)
			var tw := _tween()
			tw.tween_method(func(k: float) -> void: p.global_position = from.lerp(to.global_position, smoothstep(0.0, 1.0, k)), 0.0, 1.0, float(s[3]))
			tw.tween_callback(func() -> void: _ride[p] = to)
		"turn":
			var axis: int = ["x", "y", "z"].find(s[3])
			var rest: Transform3D = it.rest[s[2]][0]
			var deg := _earth_x() - rest.basis.get_euler()[axis] if str(s[4]) == "earth" else deg_to_rad(float(s[4]))
			_tween().tween_property(p, "rotation:" + str(s[3]), rest.basis.get_euler()[axis] + deg, float(s[5]))
		"glow":
			p.visible = bool(s[3])
		"puff":
			world.puff(p.global_position, Vector3.UP * 0.4, 1.0)


## Every prop of a spot back where it rested (turned parts ease back), but a `keep` prop keeps what it became.
func _reset(it: Interactable) -> void:
	if it == playing:
		playing = null
		_left = 0.0
	for tw: Tween in _tweens:
		tw.kill()  # a step still moving, or one yet to come, would undo the reset
	_tweens.clear()
	var specs: Dictionary = it.row.get("props", {})
	for name: String in it.rest:
		var p: Node3D = it.props[name]
		_ride.erase(p)
		var was: Array = it.rest[name]
		if not specs[name].get("keep", false):
			p.visible = was[1]
		if p.transform.basis.is_equal_approx(was[0].basis):
			p.transform = was[0]
		else:
			create_tween().tween_property(p, "transform", was[0], float(specs[name].get("back_s", 0.5)))
	it.rest.clear()


func _tween() -> Tween:
	_tweens.append(create_tween())
	return _tweens[-1]


func _process(_delta: float) -> void:
	for p: Node3D in _ride:
		if is_instance_valid(_ride[p]):
			p.global_position = _ride[p].global_position


## The rotation about x that points the comms dish at Earth now (rad): Earth's elevation in the night design's real
## sky at the clock's hour (house_style.gd _sky_frame, as sun_at() does for the sun), between 5 and 85 degrees. The
## dish rests at rotation -(90 - elevation) (forge/building_dish.py). Elevation only: its turret is welded to the mount.
func _earth_x() -> float:
	var C: Dictionary = design.get("lighting", {}).get("celestial", {})
	var hour: float = get_parent().clock.hour() if get_parent() and get_parent().get("clock") else 12.0
	var earth: Array = C.get("planets", []).filter(func(q: Dictionary) -> bool: return q.get("name") == "Earth")
	var el := 40.0
	if earth.size():
		var f := Forge.HouseStyle._sky_frame(C)
		var d: Vector3 = (f.frame as Basis).transposed() * f.dir.call([earth[0].ra, earth[0].dec])
		var th := atan2(f.sun_eq.y, f.sun_eq.x) + deg_to_rad((hour - 12.0) * 15.0)
		var lat: float = f.lat
		el = rad_to_deg(asin(d.dot(Vector3(cos(lat) * cos(th), cos(lat) * sin(th), sin(lat)))))
	return -deg_to_rad(90.0 - clampf(el, 5.0, 85.0))


## The hero's glove for a clip (clips.json `hand_bone`, else the right hand): a bone attachment hand props ride on.
func _socket(clip: StringName) -> Node3D:
	var bone: String = player.model.clips.get(clip, {}).get("hand_bone", "hand_r")
	if not _sockets.has(bone):
		var a := BoneAttachment3D.new()
		a.name = "socket_" + bone
		a.bone_name = bone
		player.model.skeleton.add_child(a)
		_sockets[bone] = a
	return _sockets[bone]


## A spot's prop from its row spec, in the item's space: `part` (a node of the item, or of the prop `in`), `model`
## (a GLB path, `scale`, or the scale of `like`'s plant: a slot's lettuce), or `meshes` (built-in shapes in roles:
## {box: size | cyl: [r, h] | torus: [inner, outer] | line: [from, to], r, at, rot, role}). `at` [x, y, z], `rot`
## degrees, `ground` sets it on the terrain (`at`'s y over it), `hand` puts it in the glove, `hidden` until a step shows it, `solid` gives
## it a box to walk into, `layer` its
## render layers (2: the ground's family, a pebble).
func _prop(item: Node3D, spec: Dictionary, made: Dictionary, clip: StringName, still := false) -> Node3D:
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
	if spec.get("hand", false):
		_socket(clip).add_child(n)
		n.transform = local
	else:
		add_child(n)
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
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if spec.get("hand", false) or (low and not still) else mi.cast_shadow
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
	n.visible = not spec.get("hidden", false)
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
