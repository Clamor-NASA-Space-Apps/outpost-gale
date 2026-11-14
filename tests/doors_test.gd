extends "res://addons/forge/test.gd"
## The real hero walks into every building a person enters, through its door, and back out:
## godot --headless --path . --fixed-fps 60 -s tests/doors_test.gd
## Doors are opened through the interactions, as a player opens them. The walk is real input: forward from
## 7 m in front of the door until the hero is inside on the floor, then back toward the camera until it is out.
## Into a room (world.json rooms) the stick is aimed through the view at the centre, then at the start, as a player
## steers: a held forward key would keep whatever heading the door frame knocked it to.
## First, using them (skills/character-body, Using things): a grid of standing spots on both sides of each door and of
## HAB 1's toilet curtain, at several headings, each within reach and facing it gets its prompt, shut and open;
## out of reach, facing away or behind a wall gets none; a door opens and closes from either side in any order;
## inside HAB 1, in the room's third-person profile, the body's heading picks the door as it does outside.
## Then, never pushed (13 Nov playtest: HAB 1's hatch swung into the hero at the Sol 1 start and trapped it in the
## frame): the hero stands at points across each doorway and swing path, on both sides, and at the Sol 1 start; each
## door opened and closed there moves the hero no more than PUSH and never leaves it in a collider, a door held at
## the hero finishes once it steps away, and set_door() waits for a clear swing.

const ENTERABLE := ["hab1", "greenhouse", "shelter"]  # world.json items a person walks into
const START := 7.0  # m in front of the building's centre, along its front
const INSIDE := 1.5  # m from the centre that counts as inside
const TURNS := [-20.0, 0.0, 20.0]  # degrees off facing the thing: a player never lines up exactly
const PUSH := 0.03  # m the hero may shift while a door moves: settling, not a shove

var game: Node3D
var world: Node3D
var player: Node3D
var box: Node
var wait := 0  # frames a door or curtain takes to move


func _init() -> void:
	watchdog = 600.0  # game seconds: --fixed-fps 60 runs them faster than real time


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	player = game.get_node("Player")
	box = game.get_node("Interactions")
	# E swings the door at once (no reach clip)
	wait = int(60 * (0.2 + float(game.tuning.interact.move_s)))
	for id: String in ENTERABLE:
		var door := _door(id)
		if door:
			await grid(door, world.items[id])
	await curtain()
	for id: String in ENTERABLE:
		var door := _door(id)
		if door:
			await no_push(door, world.items[id])
			await approach(door)
	await start_spot()
	await set_door()
	await inside_hab()
	for id: String in ENTERABLE:
		var item: Node3D = world.items[id]
		for it: Node in item.find_children("*", "", true, false):
			if it.is_in_group("interactable") and it.kind == "door" and not it.open:
				box.use(it)  # as the player opens it: one press
	await frames(wait)
	for id: String in ENTERABLE:
		var item: Node3D = world.items[id]
		var front := -item.global_basis.z.normalized()  # a model's front faces -Z
		var c := item.global_position
		var start := c + front * START
		player.place(Vector3(start.x, world.height_at(start.x, start.z) + 0.05, start.z), rad_to_deg(atan2(-front.x, front.z)))
		await frames(5)
		var steer: bool = world.data.rooms.has(id)
		var closest := await _walk(player, [] if steer else [&"move_forward"], c, c, 9.0, true)
		var s: Dictionary = player.state().player
		check(closest < INSIDE, "%s: the hero walks in through its door (closest %.2f m from the centre)" % [id, closest])
		check(s.onFloor and s.inside.is_empty(), "%s: inside, on the floor and in no wall (%s)" % [id, s.inside])
		var far := await _walk(player, [] if steer else [&"move_back"], start, c, 12.0, false)
		check(far > START - 1.0, "%s: and walks back out (%.2f m from the centre)" % [id, far])
	return true


## Holds `keys` (or, with none, steers the stick toward `goal`) for `seconds`; the closest (or farthest) the hero came
## to `c` across the ground.
func _walk(player: Node3D, keys: Array, goal: Vector3, c: Vector3, seconds: float, closest: bool) -> float:
	for k: StringName in keys:
		action(k, true)
	var best := INF if closest else 0.0
	for i in int(60 * seconds):
		if keys.is_empty():
			var to: Vector3 = goal - player.body.global_position
			to.y = 0.0
			var v: Vector3 = player.cam.ground_basis().inverse() * to.normalized() if to.length() > 0.3 else Vector3.ZERO  # there: stand
			_stick(Vector2(v.x, v.z))
		await frames(1)
		var p: Vector3 = player.body.global_position
		var d := Vector2(p.x - c.x, p.z - c.z).length()
		best = minf(best, d) if closest else maxf(best, d)
	for k: StringName in keys:
		action(k, false)
	_stick(Vector2.ZERO)
	await frames(2)
	return best


func _stick(v: Vector2) -> void:
	for a: Array in [[&"move_right", v.x], [&"move_left", -v.x], [&"move_back", v.y], [&"move_forward", -v.y]]:
		var e := InputEventAction.new()
		e.action = a[0]
		e.strength = maxf(a[1], 0.0)
		e.pressed = a[1] > 0.0
		send(e)


func _door(id: String) -> Node3D:
	for it: Node in world.items[id].find_children("*", "", true, false):
		if it.is_in_group("interactable") and it.kind == "door":
			return it
	return null


## A thin thing's frame while shut: origin at its box's middle, x across it, z out of its face (its thinnest level axis).
func _frame(it: Node3D) -> Transform3D:
	var s: AABB = it.shape
	var n := Vector3.AXIS_X if s.size.x < s.size.z else Vector3.AXIS_Z
	var b: Basis = it.thing.global_basis.orthonormalized()
	var z: Vector3 = b[n] * Vector3(1, 0, 1)
	return Transform3D(Basis(Vector3.UP.cross(z.normalized()), Vector3.UP, z.normalized()), it.middle())


## The floor under (x, z), from the thing's height down: a deck indoors, the ground outside.
func _floor(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 3.0, 1 | 2)
	var hit: Dictionary = player.body.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(at.x, world.height_at(at.x, at.z), at.z)


## Stands the hero at `at` facing the nearest point of `it` turned by `turn` degrees; false where a body cannot stand.
func _stand(it: Node3D, at: Vector3, turn: float) -> bool:
	var to: Vector3 = it.nearest(at + Vector3.UP * box.hold) - at
	player.place(at + Vector3.UP * 0.05, rad_to_deg(atan2(to.x, -to.z)) + turn)
	await frames(4)
	var p: Vector3 = player.body.global_position
	return Vector2(p.x - at.x, p.z - at.z).length() < 0.15 and player.state().player.inside.is_empty()


## Spots `d` m off the face of a shut `it` on side `side` (+1 along the frame's z), `t` of its width across.
func _spot(f: Transform3D, w: float, side: int, d: float, t: float) -> Vector3:
	return _floor(f * Vector3(t * w, 0, side * d))


## Every spot in front of `it` on both sides that a body can stand on gets `prompt`, at every turn.
func _sweep(it: Node3D, f: Transform3D, w: float, prompt: String, dists: Array, label: String) -> void:
	for side in [-1, 1]:
		var stood := 0
		var missed: Array[String] = []
		var spots := 0
		for d: float in dists:
			for t: float in [-0.35, 0.0, 0.35]:
				spots += 1
				var at := _spot(f, w, side, d, t)
				var all := true
				for turn: float in TURNS:
					if not await _stand(it, at, turn):
						all = false
						break
					if box.target != it or it.prompt() != prompt:
						missed.append("d %.1f t %.2f turn %d (%s)" % [d, t, turn, box.target.name if box.target else "nothing"])
				stood += 1 if all else 0
		check(stood * 2 >= spots, "%s side %d: a body stands on most spots (%d of %d)" % [label, side, stood, spots])
		check(missed.is_empty(), "%s side %d: every spot in reach and facing it offers %s %s" % [label, side, prompt, missed])


## Uses whatever the finder picked from `at` facing `it`, as E does, and checks it was `it`.
func _press(it: Node3D, at: Vector3, label: String) -> void:
	await _stand(it, at, 0.0)
	check(box.target == it, "%s: the prompt is %s's (got %s)" % [label, it.name, box.target.name if box.target else "nothing"])
	box.interact()
	await frames(wait)


func grid(door: Node3D, item: Node3D) -> void:
	var id := str(item.name)
	var f := _frame(door)
	var w: float = maxf(door.shape.size.x, door.shape.size.z)
	var reach: float = game.tuning.interact.reach
	await _sweep(door, f, w, "Open door", [0.5, 0.9, 1.2], id + " shut")
	# out of reach, and facing away, get nothing
	for side in [-1, 1]:
		await _stand(door, _spot(f, w, side, reach + 0.6, 0.0), 0.0)
		check(box.target != door, "%s side %d: %.1f m off, out of reach, no prompt" % [id, side, reach + 0.6])
		await _stand(door, _spot(f, w, side, 0.9, 0.0), 180.0)
		check(box.target != door, "%s side %d: facing away, no prompt" % [id, side])
	var inner := 1 if (f * Vector3(0, 0, 1)).distance_to(item.global_position) < (f * Vector3(0, 0, -1)).distance_to(item.global_position) else -1
	var inside := _spot(f, w, inner, 0.9, 0.0)
	var outside := _spot(f, w, -inner, 0.9, 0.0)
	await _press(door, inside, id + " open from inside")
	check(door.open, "%s: opened from inside" % id)
	await _sweep(door, f, w, "Close door", [0.6, 1.0], id + " open")
	await _press(door, inside, id + " close from inside")
	check(not door.open, "%s: closed from inside" % id)
	await _press(door, outside, id + " open from outside")
	check(door.open, "%s: opened from outside" % id)
	await _press(door, inside, id + " close from inside after")
	check(not door.open, "%s: closed from inside after opening from outside" % id)
	await _press(door, inside, id + " open from inside again")
	await _press(door, outside, id + " close from outside")
	check(not door.open, "%s: opened from inside, closed from outside" % id)


## HAB 1's toilet curtain from the room and from its stall; from outside the hull, in reach but behind the wall, none.
func curtain() -> void:
	var it: Node3D = null
	for n: Node in get_nodes_in_group("interactable"):
		if n.kind == "curtain":
			it = n
	if not check(it != null, "HAB 1 has a toilet curtain to use"):
		return
	var hab: Node3D = world.items["hab1"]
	var r: float = world.data.rooms.hab1[0].circle[2]
	var f := _frame(it)
	var w: float = maxf(it.shape.size.x, it.shape.size.z)
	var stood := 0  # the stall side is the toilet itself: no body stands there, so the room side carries this
	for side in [-1, 1]:
		var missed: Array[String] = []
		for d: float in [0.5, 0.9]:
			for t: float in [-0.3, 0.0, 0.3]:
				var at := _spot(f, w, side, d, t)
				if Vector2(at.x - hab.global_position.x, at.z - hab.global_position.z).length() > r - 0.3:
					continue  # past the hull: the wall check below
				for turn: float in TURNS:
					if not await _stand(it, at, turn):
						break
					stood += 1
					if box.target != it:
						missed.append("d %.1f t %.2f turn %d (%s)" % [d, t, turn, box.target.name if box.target else "nothing"])
		check(missed.is_empty(), "curtain side %d: every spot in the room in reach and facing it offers it %s" % [side, missed])
	check(stood >= 9, "the curtain is tried from %d standing spots and headings in the room" % stood)
	# outside the hull, beside the curtain
	var c: Vector3 = it.middle()
	var out := (c - hab.global_position) * Vector3(1, 0, 1)
	var at := _floor(hab.global_position + out.normalized() * (r + 0.4))
	await _stand(it, at, 0.0)
	var q: Vector3 = it.nearest(at + Vector3.UP * box.hold)
	var gap := Vector2(q.x - at.x, q.z - at.z).length()
	check(gap < float(game.tuning.interact.reach), "a spot outside HAB 1's wall is within reach of the curtain (%.2f m)" % gap)
	check(box.target != it, "and gets no prompt through the wall (got %s)" % [box.target.name if box.target else "nothing"])


## Inside HAB 1, facing the door with the view turned away from it: the room's third-person profile is on, and the
## heading, not the view, picks the door (the view no longer chooses since first person indoors was dropped, 14 Nov).
func inside_hab() -> void:
	var door := _door("hab1")
	var f := _frame(door)
	var hab: Node3D = world.items["hab1"]
	var inner := 1 if (f * Vector3(0, 0, 1)).distance_to(hab.global_position) < (f * Vector3(0, 0, -1)).distance_to(hab.global_position) else -1
	var at := _spot(f, 1.0, inner, 1.0, 0.0)
	await _stand(door, at, 0.0)
	player.cam.yaw += PI / 2.0  # the view a quarter turn off: it must not matter
	await frames(30)
	check(player.room == "hab1" and player.cam.indoor > 0.9, "inside HAB 1 the view is in the room's profile (room %s, indoor %.2f)" % [player.room, player.cam.indoor])
	check(not player.state().cam.inside, "and the lens is in no solid")
	check(box.target == door, "the body facing the door, the view turned away: the door is offered (got %s)" % [box.target.name if box.target else "nothing"])
	box.interact()
	await frames(wait)
	check(door.open, "E opens it")
	box.interact()
	await frames(wait)
	check(not door.open, "and closes it")


func _shut(door: Node3D) -> void:
	box._swinging.erase(door)
	door.open = false
	door.thing.rotation.y = door.shut.basis.get_euler().y


## Swings `door` the other way with the hero where it stands (the door's own motion: E also steps the hero out of
## the swing, start_spot() checks that); a line in `bad` if the door moved the hero or left it in a collider.
func _use_still(door: Node3D, label: String, bad: Array[String]) -> void:
	var settle := await _settled()
	var p0: Vector3 = player.body.global_position
	box._swing(door, not door.open, false)
	var worst := Vector3.ZERO
	for i in wait:
		await frames(1)
		var d: Vector3 = (player.body.global_position - p0).abs()
		worst = Vector3(maxf(worst.x, Vector2(d.x, d.z).length()), maxf(worst.y, d.y), 0)
	var inside: Array = player.state().player.inside
	if Vector2(worst.x, worst.y).length() > PUSH or not inside.is_empty():
		bad.append("%s: moved %.3f m (across %.3f, up or down %.3f; settled in %d frames), inside %s" % [label, Vector2(worst.x, worst.y).length(), worst.x, worst.y, settle, inside])


## Waits until the hero is still (under 2 mm in 5 frames, at most 2 s): a spot put down on a lip or a step of the
## graded ground settles for a while, and that is not the door's doing. The frames it took.
func _settled() -> int:
	for i in 24:
		var p: Vector3 = player.body.global_position
		await frames(5)
		if player.body.global_position.distance_to(p) < 0.002:
			return i * 5
	return 120


func no_push(door: Node3D, item: Node3D) -> void:
	var id := str(item.name)
	var f := _frame(door)
	var w: float = maxf(door.shape.size.x, door.shape.size.z)
	var bad: Array[String] = []
	var tried := [0, 0]
	var held := 0
	for side in [-1, 1]:
		for d: float in [0.0, 0.35, 0.75, 1.15]:
			for t: float in [-0.4, 0.0, 0.4]:
				var at := _spot(f, w, side, d, t)
				var label := "%s side %d d %.2f t %.2f" % [id, side, d, t]
				# opened with the hero here: it swings away from the hero
				_shut(door)
				if d > 0.0 and await _stand(door, at, 0.0):
					tried[0] += 1
					await _use_still(door, label + " open", bad)
				# opened from the other side, it swings toward here; closed with the hero here, in its swing path
				_shut(door)
				await _stand(door, _spot(f, w, -side, 1.0, 0.0), 0.0)
				box._swing(door, true, false)
				await frames(wait)
				if not await _stand(door, at, 0.0):
					continue  # where the open door or the frame is
				tried[1] += 1
				var passing: bool = not box._clear(door, false)
				await _use_still(door, label + " close", bad)
				held += int(passing)
				check(absf(door.thing.rotation.y - door.shut.basis.get_euler().y) < 0.01, "%s: it shuts all the way, through the hero's place if it must (at %.0f deg)" % [label, rad_to_deg(door.thing.rotation.y)])
	_shut(door)
	check(tried[0] >= 8 and tried[1] >= 8, "%s: the hero stands at %d spots to open it and %d in its swing to close it" % [id, tried[0], tried[1]])
	check(held > 0, "%s: some spots are in the swing, where the closing leaf passes the hero, never held half shut (%d)" % [id, held])
	check(bad.is_empty(), "%s: no door push moves the hero over %.2f m or leaves it in a collider %s" % [id, PUSH, bad])


## The Sol 1 opening: the hero starts in HAB 1's airlock and the hatch opens (data/beats.json `starts.airlock`).
func start_spot() -> void:
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).starts.airlock
	var item: Node3D = world.items[s.item]
	var door := _door(s.item)
	_shut(door)
	player.place(item.to_global(Vector3(s.at[0], s.at[1], s.at[2])), -rad_to_deg(item.global_rotation.y) + float(s.yaw))
	await frames(30)
	var bad: Array[String] = []
	await _use_still(door, "the Sol 1 start", bad)
	check(door.open and bad.is_empty(), "the hatch opens at the Sol 1 start without moving the hero %s" % [bad])
	# as the tutorial and E open it: the hand to the handle, a step back out of the swing, then all the way open
	_shut(door)
	var start: Vector3 = item.to_global(Vector3(s.at[0], s.at[1], s.at[2]))
	player.place(start, -rad_to_deg(item.global_rotation.y) + float(s.yaw))
	await frames(30)
	var p0: Vector3 = player.body.global_position
	box.use(door)
	await frames(wait + 30)
	var goal: float = door.shut.basis.get_euler().y + deg_to_rad(float(game.tuning.interact.door_open_deg))
	var moved: float = Vector2(player.body.global_position.x - p0.x, player.body.global_position.z - p0.z).length()
	check(absf(door.thing.rotation.y - goal) < 0.02, "E at the Sol 1 start: the hatch opens all the way (%.0f of %.0f deg)" % [rad_to_deg(door.thing.rotation.y), rad_to_deg(goal)])
	check(moved < 0.9 and player.state().player.inside.is_empty(), "the hero only steps back out of its swing (%.2f m), in no collider" % moved)
	_shut(door)


## set_door(): opens and closes with its sound, and a close waits until the hero is clear of the swing.
func set_door() -> void:
	var door := _door("hab1")
	var f := _frame(door)
	var hab: Node3D = world.items["hab1"]
	var inner := 1 if (f * Vector3(0, 0, 1)).distance_to(hab.global_position) < (f * Vector3(0, 0, -1)).distance_to(hab.global_position) else -1
	var heard: Array[String] = []
	var hear := func(what: String, _p: Vector3) -> void: heard.append(what)
	box.used.connect(hear)
	_shut(door)
	await _stand(door, _spot(f, 1.0, -inner, 0.9, 0.0), 0.0)
	box.set_door("hab1", true)
	await frames(wait)
	check(door.open and absf(door.thing.rotation.y) > 1.0 and heard == ["door_open"], "set_door opens it, with its sound (%s)" % [heard])
	# the hero steps in, into the open hatch's swing, and the tutorial shuts it behind them
	var swung: float = door.thing.rotation.y
	if not check(await _stand(door, _spot(f, 1.0, inner, 0.75, 0.0), 0.0), "the hero stands inside in the hatch's swing"):
		return
	heard.clear()
	await frames(10)
	var p0: Vector3 = player.body.global_position
	box.set_door("hab1", false)
	await frames(wait)
	check(not door.open and is_equal_approx(door.thing.rotation.y, swung) and heard.is_empty(), "set_door waits while the hero is in the swing (%.0f deg, %s)" % [rad_to_deg(door.thing.rotation.y), heard])
	check(player.body.global_position.distance_to(p0) < PUSH, "and does not move the hero (%.3f m)" % player.body.global_position.distance_to(p0))
	await _stand(door, _spot(f, 1.0, inner, 2.4, 0.0), 0.0)
	await frames(wait)
	check(absf(door.thing.rotation.y) < 0.01 and heard == ["door_close"], "once the hero is clear it shuts, with its sound (%s)" % [heard])
	box.set_door("hab1", false)
	await frames(2)
	check(heard == ["door_close"], "set_door to the state it is in does nothing")
	box.used.disconnect(hear)


## Only E opens a door (second playtest, 13 Nov: "every door opens by itself as the hero approaches"): the hero
## walks at a shut door from 3 m out, on both sides, and up against it; it stays shut.
func approach(door: Node3D) -> void:
	var f := _frame(door)
	for side in [-1, 1]:
		_shut(door)
		var at := _spot(f, 1.0, side, 3.0, 0.0)
		if not await _stand(door, at, 0.0):
			continue
		action(&"move_forward", true)
		await frames(150)
		action(&"move_forward", false)
		await frames(5)
		check(not door.open and is_equal_approx(door.thing.rotation.y, door.shut.basis.get_euler().y), "%s side %d: walked up to, the door stays shut: only E opens it" % [door.name, side])
	_shut(door)
