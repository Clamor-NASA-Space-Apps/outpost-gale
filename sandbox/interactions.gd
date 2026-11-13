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
const POINTED := 2 | 4 | 16 | 64  # what the view's centre can rest on: statics, thin statics, vehicles, carriables

## A thing used: its sound name ("door_open", "door_close", "panel", "bag", "rover", "put_down") the moment it is
## used; for a use spot, the row's `kind` (the action id: drink, eat, sample...) once its clip has run to its end.
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
	for id: String in uses:
		if id.begins_with("_") or not world.items.has(id):
			continue
		var item: Node3D = world.items[id]
		var shared := {}  # a prop by name, for a later row of the item that names it with {}: one case for a site's pebbles
		for row: Dictionary in uses[id]:
			var spot := Node3D.new()
			spot.name = "use_" + row.kind
			item.add_child(spot)
			var it := _add("spot", spot)
			it.row = row
			var specs: Dictionary = row.get("props", {})
			for name: String in specs:
				if not (specs[name] as Dictionary).is_empty():
					shared[name] = _prop(item, specs[name], shared, StringName(row.get("clip", "")))
				it.props[name] = shared[name]
			if row.has("on"):  # the box of a prop made here (a pebble on the ground)
				var on: Node3D = it.props[row.on]
				it.shape = (spot.global_transform.affine_inverse() * on.global_transform * _drawn(on)).grow(0.05)
			else:
				var b: Array = row.box
				it.shape = AABB(Vector3(b[0], b[1], b[2]), Vector3(b[3] - b[0], b[4] - b[1], b[5] - b[2]))
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


func _physics_process(delta: float) -> void:
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
	if player.vehicle:
		player.exit()
	elif carried:
		_put_down()
	elif target and not playing:
		target.use(player.body)


func use(it: Interactable) -> void:
	if it.kind == "spot":
		_play(it)
		return
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
func _prop(item: Node3D, spec: Dictionary, made: Dictionary, clip: StringName) -> Node3D:
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
		Forge.HouseStyle.apply(n, design, false)
		if spec.has("like"):
			var slot: Node = item.find_child(spec.like, true, false)
			k = (slot.get_child(0) as Node3D).scale.x if slot and slot.get_child_count() else k
	else:
		n = Node3D.new()
		for m: Dictionary in spec.meshes:
			n.add_child(_mesh(m, bool(spec.get("clean", false))))
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
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.layers = int(spec.get("layer", 1))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if spec.get("hand", false) else mi.cast_shadow
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


func _mesh(m: Dictionary, clean: bool) -> MeshInstance3D:
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
			return _role(mi, m, clean)
	if m.has("rot"):
		mi.rotation_degrees = Vector3(m.rot[0], m.rot[1], m.rot[2])
	return _role(mi, m, clean)


func _role(mi: MeshInstance3D, m: Dictionary, clean: bool) -> MeshInstance3D:
	mi.material_override = Forge.HouseStyle.role(design, m.role, false, clean)
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
