extends AnimatableBody3D
## PIP, the base's little helper rover, pottering about on its own (Ravindu, 12 Nov: "like the clapping lady in Clash
## of Clans"). It drives slowly between the stops in data/world.json `pip`, stops and turns its head to look at each
## thing, comes over to a hero who stands still nearby, looks up at a hero who comes close, and keeps out of the way:
## it pauses for a hero in its path, steers round solids, bags and the rover, backs off from a rover on the move, and
## never parks in a doorway or drives into a building. Kinematic: the hero bumps into it and cannot push it.
## The beats (cine/beats.gd) can take it over: drive somewhere and park (order), look at something (point_at), wave,
## or lead the hero ("follow me": it stops and looks back while the hero falls behind), then release it to potter again.
## Motion, lights and a beep only: nothing here changes game state (hard rule 1).
## Speed, acceleration and turn rate: reality.json pip.*; behaviour and timing: world.json `pip` (art direction).

# "pip_go" setting out, "pip_hello" noticing the hero (audio.play); "radio_pip" a chirp on the suit radio when it sets
# out to visit the hero or notices them (audio.radio(): rare, and only once the air is clear)
signal sound(what: String, pos: Vector3)
## It parked at the end of an order from the beats.
signal arrived

const STATICS := 2
const THIN := 4
const HERO := 8
const VEHICLES := 16
const CARRIABLES := 64
const LIFT := 0.03  # m: sweeps start this far up, so a pebble-flat contact with the ground counts as nothing

var world: Node3D
var player: Node3D
var p: Dictionary  # world.json `pip`
var top: float  # m/s
var accel: float  # m/s2
var turn: float  # rad/s, in place
var radius: float  # m, a wheel's (from the model)
var state := "look"  # drive, look, wait, greet, flee; behind (leading, the hero fell back)
var stop := ""  # the stop it drives to or looks at; "hero" for a greeting
var reached: Array[String] = []  # every stop arrived at, in order (for checks)
var passed := 0  # via points driven through (for checks)
var v := 0.0
var yaw := 0.0
var target := Vector3.ZERO
var gaze := Vector3.ZERO  # what the head looks at when nothing nearer is worth it
var led := false  # the beats lead it: no wandering and no visits, it holds still between their orders
var leading := false  # a "follow me" order: it waits while the hero is more than lead_m.x away, goes on within lead_m.y
var lead_m := Vector2.ZERO
var gave_up := 0  # orders it could not get through to and tried again (checks: never)
var _order := {}  # the order it is driving: {at: Vector3, face: Vector3 (INF for the hero), wave: bool}
var _rng := RandomNumberGenerator.new()
var _shape: CollisionShape3D
var _model: Node3D
var _head: Node3D
var _eyes: Array[Node3D] = []
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _bar_lit: Color
var _bar_glow: float
var _wheels: Array[Node3D] = []
var _hubs: Array[Vector3] = []  # each wheel's hub in the body's space
var _doors: Array[Vector2] = []  # doorways to keep clear, (x, z)
var _rooms: Array = []  # buildings to keep out of: [to its own space, its box there with the margin]
var _nodes: Array[Vector3] = []  # the route graph: every stop and via point (world.json `pip`)
var _links: Array = []  # node -> Array of node indices it reaches in a straight, clear line
var _path: Array[Vector3] = []  # the points still to drive through; the last is the target
var _replanned := false
var _time := 0.0
var _timer := 0.0  # seconds left in a look, a wait or a greeting
var _steer := 0.0  # the heading the feelers picked last
var _feel := 0.0  # seconds to the next feeler pass
var _best := INF  # closest it came to the target since `_since`
var _since := 0.0
var _patience := 0.0  # seconds of driving round the hero after a wait ran out
var _still := 0.0  # seconds the hero has stood still
var _greet_cool := 0.0
var _hello_cool := 0.0
var _near := false  # the hero inside notice_m (with hysteresis)
var _flash := 0.0  # seconds of the notice flashes left
var _wiggle := 0.0  # seconds of the happy wiggle left
var _blink := 0.0  # seconds to the next blink
var _blinking := 0.0
var _scan := Vector3.ZERO  # a small glance off the thing it looks at, renewed now and then
var _scan_t := 0.0
var _head_ang := Vector3.ZERO
var _travel := 0.0  # metres since the last wheel print
var _was := Vector3.ZERO


func setup(w: Node3D, hero: Node3D) -> void:
	world = w
	player = hero
	p = world.data.pip
	top = world.sheet_values["pip.speed"]
	accel = world.sheet_values["pip.accel"]
	turn = deg_to_rad(world.sheet_values["pip.turn"])
	_rng.seed = int(p.seed)
	# it rests on its wheels (_pose), so its sweeps leave the ground out; solids, the hero, bags and the rover block
	collision_mask = STATICS | THIN | HERO | VEHICLES | CARRIABLES
	_shape = find_children("*", "CollisionShape3D", false, false)[0]
	_model = get_child(0)
	_head = find_child("head", true, false)
	for n: String in ["eye_l", "eye_r"]:
		_eyes.append(find_child(n, true, false))
	_bar = find_child("status_bar", true, false)
	for n: Node in find_children("wheel_*", "Node3D", true, false):
		_wheels.append(n)
		_hubs.append(to_local((n as Node3D).global_position))
	radius = maxf(_hubs[0].y, 0.05)  # the model stands its wheels on its origin's floor
	for item: Node3D in world.items.values():
		var leaf := false
		for part: Node3D in item.get_meta("parts"):
			if part.name == &"door":
				_doors.append(Vector2(part.global_position.x, part.global_position.z))
				leaf = true
		if item.get_meta("prefab") in p.rooms:
			# its own box, in its own turned space: a box round a turned dome took in the ground beside it
			var to := item.global_transform.affine_inverse()
			var box := AABB()
			for mi: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
				if mi.mesh:
					box = box.merge((to * mi.global_transform) * mi.get_aabb())
			box = box.grow(float(p.room_margin))
			_rooms.append([to, box])
			if not leaf:  # a doorway with no door leaf (the shelter): the middle of its front, where a model faces
				var d := item.global_transform * Vector3(box.get_center().x, 0.0, box.position.z + float(p.room_margin))
				_doors.append(Vector2(d.x, d.z))
	for s: Dictionary in p.stops:
		_nodes.append(_ground(s.at))
	for v: Array in p.via:
		_nodes.append(_ground(v))
	yaw = rotation.y
	_steer = yaw
	_was = global_position
	_place(global_position, yaw)
	_look_around(float(p.look_s[0]))
	gaze = global_position - global_basis.z * 2.0
	_blink = _rng.randf_range(p.blink_s[0], p.blink_s[1])
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	# the route graph on the first tick, not in setup(): during the sandbox's _ready the physics space still has the
	# items where world.gd first added them, at the origin, and Mont Mercou's hull there cut a via point off (13 Nov)
	if _links.is_empty():
		for i in _nodes.size():
			_links.append(_reach(_nodes[i]))
	_time += delta
	_greet_cool -= delta
	_hello_cool -= delta
	var hero := _hero()
	var to_hero := Vector2(hero.x - global_position.x, hero.z - global_position.z)
	var walking: bool = player.vehicle == null
	_still = _still + delta if walking and player.moved < float(p.still_speed) else 0.0
	# the hero comes close: a beep and two flashes, once per visit
	var near := walking and to_hero.length() < float(p.notice_m) + (1.0 if _near else 0.0)
	if near and not _near and _hello_cool <= 0.0:
		_hello()
	_near = near
	_rover_check()
	match state:
		"look", "greet":
			_brake(delta)
			_timer -= delta
			_face(gaze if state == "look" else hero, delta)
			if state == "look" and _wants_greet(to_hero):
				_greet(hero, to_hero)
			elif _timer <= 0.0:
				_next()
		"wait":
			_brake(delta)
			_timer -= delta
			if not _blocked_by_hero(to_hero):
				state = "drive"
			elif _timer <= 0.0:
				_patience = float(p.patience_s)  # drive round the hero now, as round anything else
				state = "drive"
		"behind":
			_brake(delta)
			_face(hero, delta)
			if to_hero.length() < lead_m.y:
				state = "drive"
				_since = 0.0
		"drive", "flee":
			if state == "drive" and stop != "hero" and _wants_greet(to_hero):
				_greet(hero, to_hero)
			_drive(delta, to_hero)
	_life(delta, hero, to_hero)
	_ground_fx()


## The hero's helmet, or the rover's cab while the hero drives.
func _hero() -> Vector3:
	return (player.vehicle.global_position if player.vehicle else player.body.global_position) + Vector3.UP * 1.6


func _wants_greet(to_hero: Vector2) -> bool:
	return not led and _still > float(p.still_s) and _greet_cool <= 0.0 and to_hero.length() < float(p.greet_m) \
		and to_hero.length() > float(p.greet_stand_m) + 0.5


func _greet(hero: Vector3, to_hero: Vector2) -> void:
	_go("hero", hero + Vector3(-to_hero.x, 0.0, -to_hero.y).normalized() * float(p.greet_stand_m))
	if state == "drive":
		sound.emit("radio_pip", global_position)
	else:
		_greet_cool = float(p.greet_cool_s)  # no way there: try again later, not every frame


func _go(name: String, at: Vector3) -> void:
	at.y = world.height_at(at.x, at.z)
	if _no_go(Vector2(at.x, at.z)):
		_look_around(1.0)
		return
	stop = name
	target = at
	_path = _route(global_position, at)
	_replanned = false
	state = "drive"
	_best = INF
	_since = 0.0
	sound.emit("pip_go", global_position)


func _ground(at: Array) -> Vector3:
	return Vector3(at[0], world.height_at(at[0], at[1]), at[1])


## The nodes `from` reaches in a clear straight line.
func _reach(from: Vector3) -> Array[int]:
	var out: Array[int] = []
	for j in _nodes.size():
		if _nodes[j].distance_to(from) > 0.01 and _clear(from, _nodes[j]):
			out.append(j)
	return out


## A straight drive from a to b passes no solid (with `clearance` either side), no doorway and no building. Movers
## (the hero, bags, the rover) are left to the feelers: they move.
func _clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var n := ceili(d.length() / 0.25)
	for i in n + 1:
		var at := a.lerp(b, float(i) / n)
		if _no_go(Vector2(at.x, at.z)):
			return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape.shape
	q.collision_mask = STATICS | THIN
	q.motion = b - a
	var side := Vector3(-d.z, 0.0, d.x).normalized() * float(p.clearance)
	for o: Vector3 in [Vector3.ZERO, side, -side]:
		q.transform = _at(a + o, atan2(-d.x, -d.z)) * _shape.transform
		if get_world_3d().direct_space_state.cast_motion(q)[0] < 1.0:
			return false
	return true


## The shortest way from `from` to `to` through the route graph (Dijkstra over a dozen or two nodes), else straight.
func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	if _clear(from, to):
		return [to]
	var a := _reach(from)
	var b := _reach(to)
	var dist: Array[float] = []
	var prev: Array[int] = []
	dist.resize(_nodes.size())
	prev.resize(_nodes.size())
	dist.fill(INF)
	prev.fill(-1)
	for i in a:
		dist[i] = from.distance_to(_nodes[i])
	var done: Array[bool] = []
	done.resize(_nodes.size())
	done.fill(false)
	var best := -1
	var best_len := INF
	while true:
		var u := -1
		for i in _nodes.size():
			if not done[i] and dist[i] < INF and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0:
			break
		done[u] = true
		if u in b and dist[u] + _nodes[u].distance_to(to) < best_len:
			best_len = dist[u] + _nodes[u].distance_to(to)
			best = u
		for j: int in _links[u]:
			var l := dist[u] + _nodes[u].distance_to(_nodes[j])
			if l < dist[j]:
				dist[j] = l
				prev[j] = u
	var out: Array[Vector3] = [to]
	while best >= 0:
		out.push_front(_nodes[best])
		best = prev[best]
	return out  # ponytail: no way found drives straight at it and leaves the rest to the feelers and stuck_s


## The next stop: none of the last two it saw, nearer ones more often (each stop's weight over `near_m` plus the
## distance), so it potters round the base and only now and then sets off on a long trip.
func _next() -> void:
	if led:  # an order cut short (a flee, no way through) is driven again; with none it holds still
		if _order.is_empty():
			_timer = INF
		else:
			_go("order", _order.at)
		return
	var recent := reached.slice(-2) + [stop]
	var stops: Array = p.stops.filter(func(s: Dictionary) -> bool: return s.id not in recent)
	var weights: Array[float] = []
	var total := 0.0
	for s: Dictionary in stops:
		var d := Vector2(s.at[0] - global_position.x, s.at[1] - global_position.z).length()
		weights.append(float(s.get("weight", 1.0)) * float(p.near_m) / (float(p.near_m) + d))
		total += weights[-1]
	var pick := _rng.randf() * total
	for i in stops.size():
		pick -= weights[i]
		if pick <= 0.0 or i == stops.size() - 1:
			var s: Dictionary = stops[i]
			_go(s.id, Vector3(s.at[0], 0.0, s.at[1]))
			var l: Array = s.look
			gaze = Vector3(l[0], world.height_at(l[0], l[1]) + float(l[2]), l[1])
			return


func _look_around(seconds: float) -> void:
	state = "look"
	_timer = seconds


func _arrive() -> void:
	reached.append(stop)
	if stop == "order":
		state = "greet" if _order.face == Vector3.INF else "look"  # greet: turned to the hero, head up and tilted
		gaze = _order.face if _order.face != Vector3.INF else _hero()
		_timer = INF
		if _order.wave:
			wave()
		_order = {}
		leading = false
		arrived.emit()
	elif stop == "hero":
		state = "greet"
		_timer = float(p.greet_s)
		_greet_cool = float(p.greet_cool_s)
		_wiggle = float(p.wiggle_s)
		if _hello_cool <= 0.0:
			_hello()
	else:
		_look_around(_rng.randf_range(p.look_s[0], p.look_s[1]))


func _hello() -> void:
	_hello_cool = float(p.hello_cool_s)
	_flash = float(p.flashes) / float(p.flash_hz)
	_wiggle = maxf(_wiggle, float(p.wiggle_s) * 0.5)
	sound.emit("pip_hello", global_position)
	sound.emit("radio_pip", global_position)


## A rover on the move within flee_m: get out to the side it is on, away from the rover's path.
func _rover_check() -> void:
	var rover: Node3D = world.items.get("rover")
	if rover == null or state == "flee" or absf(float(rover.get("v") if rover.get("v") != null else 0.0)) < 0.2:
		return
	var off := global_position - rover.global_position
	off.y = 0.0
	if off.length() > float(p.flee_m):
		return
	var side := rover.global_basis.x * signf(off.dot(rover.global_basis.x) + 1e-3)
	stop = "flee"
	target = global_position + (side + off.normalized()).normalized() * float(p.flee_m) * 0.5
	_path = [target]
	state = "flee"
	_best = INF
	_since = 0.0


func _drive(delta: float, to_hero: Vector2) -> void:
	# through each via point without stopping, to the last one
	while _path.size() > 1 and Vector2(_path[0].x - global_position.x, _path[0].z - global_position.z).length() < float(p.via_m):
		_path.pop_front()
		passed += 1
		_best = INF
	var aim: Vector3 = _path[0] if _path.size() else target
	var to := Vector2(aim.x - global_position.x, aim.z - global_position.z)
	var dist := to.length()
	var left := dist + (0.0 if _path.size() < 2 else 10.0)  # only the last point slows it
	if _path.size() < 2 and dist < float(p.arrive_m):
		if state == "flee":
			_look_around(1.0)
			gaze = global_position - global_basis.z * 2.0
		else:
			_arrive()
		return
	if leading and state == "drive" and to_hero.length() > lead_m.x:
		state = "behind"  # stop and look back; a beep the first time in a while
		if _hello_cool <= 0.0:
			_hello()
		return
	_patience -= delta
	if state == "drive" and _patience <= 0.0 and _blocked_by_hero(to_hero):
		state = "wait"
		_timer = float(p.wait_s)
		gaze = _hero()
		return
	# no progress for a while (a bag on the spot, a dead end): give up and go somewhere else
	_since += delta
	if dist < _best - 0.3:
		_best = dist
		_since = 0.0
	elif _since > float(p.stuck_s):
		if _replanned:
			gave_up += 1 if led else 0
			_look_around(1.0)
		else:
			_replanned = true  # something moved into the way: one new route from here, then give up
			_path = _route(global_position, target)
			_best = INF
			_since = 0.0
		return
	_feel -= delta
	if _feel <= 0.0:
		_feel = float(p.feel_s)
		_steer = _feelers(atan2(-to.x, -to.y))
	var err := wrapf(_steer - yaw, -PI, PI)
	var new_yaw := yaw + clampf(err, -turn * delta, turn * delta)
	# slower in a turn, and slowing to a stop at the target
	var want := top * clampf(cos(err) * 1.5 - 0.5, 0.0, 1.0)
	want = minf(want, sqrt(2.0 * accel * maxf(left - float(p.arrive_m) * 0.5, 0.0)))
	v = move_toward(v, want, accel * delta)
	_move(new_yaw, v * delta)


## The heading nearest `want` whose way ahead is clear of solids, the hero, doorways and buildings. Feelers fan out
## from the wanted heading; none clear means turn round.
func _feelers(want: float) -> float:
	var reach := float(p.feeler_m)
	for k: int in range(0, 8):
		for s: float in ([1.0] if k == 0 else [1.0, -1.0]):
			var h := want + s * deg_to_rad(25.0) * k
			var dir := Vector3(-sin(h), 0.0, -cos(h))
			var end := global_position + dir * reach
			var here := Vector2(global_position.x, global_position.z)
			if not _no_go(here) and [0.1, 0.5, 1.0].any(func(f: float) -> bool: return _no_go(here.lerp(Vector2(end.x, end.z), f))):
				continue
			if not test_move(_at(global_position, yaw), dir * reach):
				return h
	return yaw + PI


func _no_go(at: Vector2) -> bool:
	for d in _doors:
		if at.distance_to(d) < float(p.door_clear_m):
			return true
	for r: Array in _rooms:
		var l: Vector3 = r[0] * Vector3(at.x, 0.0, at.y)
		var b: AABB = r[1]
		if l.x > b.position.x and l.x < b.end.x and l.z > b.position.z and l.z < b.end.z:
			return true
	return false


func _blocked_by_hero(to_hero: Vector2) -> bool:
	if player.vehicle or to_hero.length() > float(p.yield_m):
		return false
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	return fwd.dot(to_hero.normalized()) > cos(deg_to_rad(float(p.yield_deg)))


## Turns to `new_yaw` and moves `step` metres ahead, each only if it stays clear of everything it must not touch.
func _move(new_yaw: float, step: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape.shape
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	q.transform = _at(global_position, new_yaw) * _shape.transform
	if space.intersect_shape(q, 1).is_empty():
		yaw = wrapf(new_yaw, -PI, PI)
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var moved := 0.0
	if step > 0.0:
		var to := global_position + dir * step
		# into a doorway or a building never; out of one (a flee or a greeting that ended there) always
		var into := _no_go(Vector2(to.x, to.z)) and not _no_go(Vector2(global_position.x, global_position.z))
		if test_move(_at(global_position, yaw), dir * step) or into:
			v = 0.0
		else:
			moved = step
	_place(global_position + dir * moved, yaw)


func _brake(delta: float) -> void:
	v = move_toward(v, 0.0, accel * delta)
	_move(yaw, v * delta)


## Turns on the spot toward a point (stopped at a stop: the head alone cannot see behind).
func _face(at: Vector3, delta: float) -> void:
	var to := Vector2(at.x - global_position.x, at.z - global_position.z)
	var err := wrapf(atan2(-to.x, -to.y) - yaw, -PI, PI)
	if absf(err) > deg_to_rad(float(p.face_deg)):
		_move(yaw + clampf(err, -turn * delta, turn * delta), 0.0)


## A flat transform at `at` facing `heading`, lifted off the ground a little: what the sweeps test.
func _at(at: Vector3, heading: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, heading), at + Vector3.UP * LIFT)


## On its four wheels at `at`: height from the ground under each, pitch and roll from front against back, left
## against right.
func _place(at: Vector3, heading: float) -> void:
	var flat := Basis(Vector3.UP, heading)
	var front := 0.0
	var back := 0.0
	var left := 0.0
	var right := 0.0
	for h in _hubs:
		var g := at + flat * Vector3(h.x, 0.0, h.z)
		var y: float = world.height_at(g.x, g.z)
		if h.z < 0.0:
			front += y / 2.0
		else:
			back += y / 2.0
		if h.x > 0.0:
			right += y / 2.0
		else:
			left += y / 2.0
	var axle := absf(_hubs[0].z) * 2.0
	var track := absf(_hubs[0].x) * 2.0
	var pitch := atan2(front - back, axle)
	var roll := atan2(right - left, track)
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, heading, roll)), Vector3(at.x, (front + back) / 2.0, at.z))


## The head, eyes, status bar, wiggle and wheels: what makes it read as alive.
func _life(delta: float, hero: Vector3, to_hero: Vector2) -> void:
	# head: at the hero while near, else at the thing, with a small glance aside now and then
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = _rng.randf_range(p.glance_s[0], p.glance_s[1])
		var g: float = p.glance_m
		_scan = Vector3(_rng.randf_range(-g, g), _rng.randf_range(-g, g) * 0.5, _rng.randf_range(-g, g))
	var look := gaze + _scan
	if _near or state in ["greet", "wait", "behind"]:
		look = hero
	elif state in ["drive", "flee"]:
		look = global_position - global_basis.z * 3.0 + _scan * 0.5
	var d := (_head.get_parent() as Node3D).global_transform.affine_inverse() * look - _head.position
	var lim := deg_to_rad(float(p.head_yaw_deg))
	var want := Vector3(clampf(atan2(d.y, Vector2(d.x, d.z).length()), -deg_to_rad(float(p.head_pitch_deg)), deg_to_rad(float(p.head_pitch_deg))),
		clampf(atan2(-d.x, -d.z), -lim, lim), deg_to_rad(float(p.tilt_deg)) * (1.0 if state == "greet" else 0.0))
	_head_ang = _head_ang.move_toward(want, deg_to_rad(float(p.head_deg_s)) * delta)
	_head.rotation = _head_ang
	# eyes: a blink now and then, sometimes a double
	_blink -= delta
	if _blink <= 0.0:
		_blinking = float(p.blink_close_s)
		_blink = _rng.randf_range(p.blink_s[0], p.blink_s[1]) if _rng.randf() > float(p.double_blink) else float(p.blink_close_s) * 2.5
	_blinking -= delta
	var open := 1.0 - clampf(sin(PI * clampf(1.0 - _blinking / float(p.blink_close_s), 0.0, 1.0)), 0.0, 1.0) * 0.85 if _blinking > 0.0 else 1.0
	for e in _eyes:
		e.scale.y = open
	# status bar: a slow glow, two quick flashes on noticing the hero (never over 3 a second, AGENTS.md)
	_flash -= delta
	var k := 0.75 + 0.25 * sin(TAU * float(p.glow_hz) * _time)
	if _flash > 0.0:
		k = 1.0 if fmod(_flash * float(p.flash_hz), 1.0) > 0.5 else 0.3
	_glow(k)
	# a happy wiggle: the model rocks on its wheels, the body (and its collision) stays put
	_wiggle -= delta
	_model.rotation.y = sin(TAU * float(p.wiggle_hz) * _wiggle) * deg_to_rad(float(p.wiggle_deg)) if _wiggle > 0.0 else 0.0


func _glow(k: float) -> void:
	# its own copy of the light role, made again after a sky switch put the shared one back
	if _bar.get_surface_override_material(0) != _bar_mat:
		var m := _bar.get_active_material(0) as StandardMaterial3D
		if m == null:
			return
		_bar_mat = m.duplicate()
		_bar_mat.resource_name = "light_pip"
		_bar_lit = _bar_mat.albedo_color
		_bar_glow = float(m.get_meta("glow", _bar_mat.emission_energy_multiplier))  # the full glow, not the sky clock's daytime glimmer
		_bar.set_surface_override_material(0, _bar_mat)
	_bar_mat.albedo_color = _bar_lit * Color(k, k, k)
	_bar_mat.emission_energy_multiplier = _bar_glow * k


## Wheels turned by the distance each one rolled (skid steering: the outside pair rolls forward in a turn), prints
## behind the rear pair, and its contact shadow.
func _ground_fx() -> void:
	var at := global_position
	var fwd := -global_basis.z
	var step := Vector3(at.x - _was.x, 0.0, at.z - _was.z)
	var ahead := step.dot(Vector3(fwd.x, 0.0, fwd.z).normalized())
	var dyaw := wrapf(yaw - get_meta("last_yaw", yaw), -PI, PI)
	set_meta("last_yaw", yaw)
	_was = at
	for i in _wheels.size():
		_wheels[i].rotate_object_local(Vector3.RIGHT, -(ahead + dyaw * _hubs[i].x) / radius)
	_travel += absf(ahead)
	if _travel >= float(p.track_every):
		_travel = 0.0
		for i in _hubs.size():
			if _hubs[i].z > 0.0:
				world.mark(global_transform * Vector3(_hubs[i].x, 0.0, _hubs[i].z), -rad_to_deg(yaw), "wheel", float(p.track_width), float(p.track_depth))
	var s: Array = p.shade
	var discs := PackedVector4Array()
	for z: float in [-1.0, 1.0]:
		var c := global_transform * Vector3(0.0, 0.0, absf(_hubs[0].z) * z)
		discs.append(Vector4(c.x, c.z, s[0], s[1]))
	world.touch(self, discs)


## The beats' order: drive to `at` and park, then look at `face` (INF: at the hero) and wave if asked. `lead` makes it
## a "follow me" (x: wait when the hero is this far, y: go on once back within this). Emits `arrived` on parking.
func order(at: Vector3, face := Vector3.INF, wave_after := false, lead := Vector2.ZERO) -> void:
	led = true
	leading = lead != Vector2.ZERO
	lead_m = lead
	_order = {"at": at, "face": face, "wave": wave_after}
	stop = ""
	_go("order", at)
	if stop != "order":  # the spot is in a doorway or a building (the beats' data): it parks where it is
		push_warning("PIP: order to %s is a no-go spot, arriving where it is" % at)
		stop = "order"
		_arrive()


## The beats: stop where it is and turn to look at `at`.
func point_at(at: Vector3) -> void:
	led = true
	leading = false
	_order = {}
	gaze = at
	_look_around(INF)


## A hello: two flashes, a beep and a wiggle.
func wave() -> void:
	_hello()
	_wiggle = float(p.wiggle_s)


## The beats are done with it: back to pottering about.
func release() -> void:
	led = false
	leading = false
	_order = {}
	_look_around(1.0)


func state_text() -> Dictionary:
	var at := global_position
	return {"pip": {"pos": [snappedf(at.x, 0.01), snappedf(at.z, 0.01)], "state": state, "stop": stop, "speed": snappedf(v, 0.01), "reached": reached.size()}}
