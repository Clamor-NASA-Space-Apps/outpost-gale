extends RefCounted
## The rover's autopilot: aboard, a mark set on the map is where it drives. It plans a way round everything the
## rover cannot drive through and then holds the same stick the kid does (player.gd _drive() asks steer() for the
## input each physics frame), so the speed, turning, braking, dust and sound are the rover's own (rover.gd drive()).
## A move key, a cleared mark, getting out or a cinematic takes the wheel back at once.
## A rover trip's drive-off is its own entry (film(), release()): cine.gd holds that wheel, and no key or mark does.
## PIP's route graph (pip.gd _route) is a dozen hand-placed points checked with PIP's own 0.5 m hull, so it cannot
## serve a body 2.3 m wide: the way is planned on a grid over the patch from the same collision layers instead.

signal note(title: String, text: String)  # a HUD note: it took the wheel, or gave it back and why

const STILL := 2 | 4  # statics and thin things (CONTRACTS.md layers): they stand where they stood
const MOVERS := 16 | 64  # vehicles (PIP) and carriables (the bags)
const TALL := 30.0  # m: the column a cell is checked over, so a roof counts (a cell inside a room touches no wall)
const BLOCK := 8  # cells a side: the survey's first, coarse look
const NOTES := {
	"on": ["Autopilot on", "Move to take the wheel."],
	"off": ["Autopilot off", "You have the wheel."],
	"here": ["We're here!", "You have the wheel."],
	"near": ["Autopilot off", "As near as I can get."],
	"stuck": ["Autopilot off", "I can't get through here."],
}

var world: Node3D
var t: Dictionary  # data/tuning.json rover.autopilot
var busy := Callable()  # true while a cinematic owns the rover (the root sets it): it lets go without a word
var hold := false  # the map is open: a mark set now is driven to once it closes, where the kid can see it start
var hinted := false  # PIP said its "drop a pin" line (the root, once a run)
var on := false
var path := PackedVector2Array()  # the points to drive through (x, z); the last is where it stops
var plan_ms := 0.0  # how long the last plan took (for checks)
var _want: Variant = null  # a mark set aboard and not planned yet
var _goal := Vector2.ZERO
var _i := 0  # the point it steers for
var _frame := -2  # the physics frame steer() last ran
var _best := INF  # nearest it came to the point since it last got anywhere
var _yaw := 0.0  # and its heading then
var _since := 0.0
var _tries := 0
var off := PI  # rad: how far the nose is off the point it steers for (cine.gd films the drive-off once it has come round)
var _backing := false  # backing off a wall to make room to turn
var _shot := false  # a cinematic drives (film()): no key, mark or word until release()
var _hull: CollisionShape3D  # the rover's
var _stop_m := 0.0  # how near the last point it stops
var _near := false  # the rover is within the HUD's reach of the mark
var _done := false  # arrived: braking to a stand before it hands back
var _grids := {}  # an area's rect -> its AStarGrid2D, closed where things stand still
var _column := CylinderShape3D.new()
var _q := PhysicsShapeQueryParameters3D.new()


func _init(w: Node3D, tuning: Dictionary) -> void:
	world = w
	t = tuning


## The map's mark was set (x, z) or cleared (null). The root passes null when nobody is aboard.
func go(at: Variant) -> void:
	if _shot:
		return
	_want = at
	if at == null and driving():
		# the HUD clears a mark the hero reaches (game_hud.gd MARK_REACH_M), a little before the rover stands: that
		# is the arrival, not the kid's hand, and it brakes to its stop first
		if _near:
			_done = true
		else:
			_stop("off")


func driving() -> bool:
	return on and Engine.get_physics_frames() - _frame <= 1


## A cinematic's own drive (cine.gd trip_to): the rover sets off toward `at` now, round everything, until release().
## No key takes this wheel, no mark changes it and nothing is said. False when there is no way at all.
func film(rover: Node3D, at: Vector2) -> bool:
	_shot = true
	_want = null
	_goal = at
	_tries = 0
	off = PI
	on = _plan(rover)
	return on


func release() -> void:
	_shot = false
	on = false
	_want = null


## The point `m` metres along the way from `from` (the way's end when it is shorter).
func ahead(from: Vector2, m: float) -> Vector2:
	for i in range(_i, path.size()):
		var d := from.distance_to(path[i])
		if d >= m:
			return from.move_toward(path[i], m)
		m -= d
		from = path[i]
	return from


## The stick for this frame: the kid's `keys` (x steers right, y is throttle), or its own while it drives.
func steer(rover: Node3D, keys: Vector2, delta: float) -> Vector2:
	var frame := Engine.get_physics_frames()
	if not _shot and (frame - _frame > 1 or (busy.is_valid() and busy.call())):
		on = false  # nobody drove last frame (the kid got out and in again), or a cinematic has the rover
		_want = null
	_frame = frame
	if _want != null and not hold:
		_start(rover)
	if not on:
		return Vector2.ZERO if _shot else keys
	if keys != Vector2.ZERO and not _shot:
		_stop("off")
		return keys
	var pos := Vector2(rover.global_position.x, rover.global_position.z)
	while _i < path.size() - 1 and pos.distance_to(path[_i]) < float(t.pass_m):
		_i += 1
		_best = INF
	var to := path[_i] - pos
	var d := to.length()
	var last := _i == path.size() - 1
	_near = pos.distance_to(_goal) < float(t.reach_m)
	if _done or (last and d < _stop_m):
		if absf(rover.v) < 0.05:
			_stop("here" if _near else "near")
		return Vector2.ZERO  # the rover's own brakes
	if d < _best - 0.3 or absf(angle_difference(_yaw, rover.yaw)) > 0.1:
		_best = d
		_yaw = rover.yaw
		_since = 0.0
	else:
		_since += delta
		if _since > float(t.stall_s):
			# something came to stand in the way (PIP, a bag): one new plan from here, then the kid's turn
			_tries += 1
			if _tries > 1 or not _plan(rover):
				_stop("stuck")
			return Vector2.ZERO
	var err := angle_difference(rover.yaw, atan2(-to.x, -to.y))  # the rover's nose is its -z
	off = err
	var slow: Array = t.slow_deg
	# the nose swings only where the body has room to: nose on to a wall, a turn on the spot put its corners into
	# the wall (rover.gd drive() turns without asking)
	var room := absf(err) < deg_to_rad(slow[0]) or _turns(rover, signf(err))
	var x := clampf(-err / deg_to_rad(float(t.steer_deg)), -1.0, 1.0) if room else 0.0
	if rover.v < -0.05:
		x = -x  # backing turns the other way, as a car does (rover.gd drive())
	var throttle := 1.0 - clampf(inverse_lerp(slow[0], slow[1], rad_to_deg(absf(err))), 0.0, 1.0)
	if room:
		_backing = false
	elif rover.blocked != "" and rover.v >= 0.0:
		_backing = true  # no room to turn and none ahead (nose on to a wall): back off until there is
	if absf(err) > PI / 2.0 or _backing:
		throttle = -float(t.back)  # the way lies behind: back out in an arc and come round, a three-point turn
	elif not room:
		throttle = float(t.back)  # straight on until there is room to turn
	elif last:
		# what its brakes can take off before the stop, never under a crawl
		throttle = minf(throttle, maxf(sqrt(2.0 * rover.brake * maxf(d - _stop_m, 0.0)) / rover.top, 0.2))
	return Vector2(x, throttle)


## The body can swing its nose toward `side` (1: yaw grows) from where it stands: turned a little that way, its hull
## meets nothing taller than it climbs (the same things the grid closes).
func _turns(rover: Node3D, side: float) -> bool:
	_q.shape = _hull.shape
	_q.collision_mask = STILL | MOVERS
	for deg: float in t.turn_look_deg:
		var b := Basis(Vector3.UP, side * deg_to_rad(deg)) * rover.global_basis
		_q.transform = Transform3D(b, rover.global_position + Vector3.UP * float(rover.climb)) * _hull.transform
		if not world.get_world_3d().direct_space_state.intersect_shape(_q, 1).is_empty():
			return false
	return true


func _start(rover: Node3D) -> void:
	_goal = _want
	_want = null
	_tries = 0
	# a field site's mark, seen from the base (or the other way), is a rover trip's job (cine.gd trip_to), not a
	# drive: not a word, the story's beats speak there
	if world.bound(0.0, Vector3(_goal.x, 0.0, _goal.y)) != world.bound(0.0, rover.global_position):
		on = false
	elif _plan(rover):
		on = true
		note.emit(NOTES.on[0], NOTES.on[1])
	else:
		_stop("stuck")


func _stop(why: String) -> void:
	on = false
	if not _shot:
		note.emit(NOTES[why][0], NOTES[why][1])


## The way from the rover to `_goal`, or to the nearest spot it can reach: a grid over the area the rover is in
## (world.bound()), a cell closed where anything taller than the rover climbs stands within `clear_m` of it, the
## cells next to those dearer (`near_cost`), so it keeps a turn's room where there is room and still gets out of a
## tight parking spot. What stands still is surveyed once an area; PIP and the bags are closed for this plan only.
func _plan(rover: Node3D) -> bool:
	var t0 := Time.get_ticks_usec()
	var cell := float(t.cell_m)
	var climb := float(rover.climb)
	var rect: Rect2 = world.bound(float(world.data.bound.reach) + cell, rover.global_position)
	_q.exclude = [rover.get_rid()]
	_hull = rover.find_children("*", "CollisionShape3D", false, false)[0]
	_column.radius = float(t.clear_m)
	_column.height = TALL
	if not _grids.has(rect):
		_grids[rect] = _survey(rect, cell, climb)
	var grid: AStarGrid2D = _grids[rect]
	var undo: Array = []  # [cell, it was solid, its weight]: what this plan changed, newest last
	var reach := ceili((float(t.clear_m) + 1.0) / cell)  # PIP and a bag are under 2 m across
	for m: Node3D in world.get_tree().get_nodes_in_group("vehicle") + world.get_tree().get_nodes_in_group("carriable"):
		var c := Vector2i(((Vector2(m.global_position.x, m.global_position.z) - rect.position) / cell).floor())
		for x in range(c.x - reach, c.x + reach + 1):
			for y in range(c.y - reach, c.y + reach + 1):
				if m != rover and grid.is_in_boundsv(Vector2i(x, y)) and _closed(grid, Vector2i(x, y), climb, MOVERS):
					_close(grid, Vector2i(x, y), undo)
	var last := grid.region.size - Vector2i.ONE
	var from := Vector2i(((Vector2(rover.global_position.x, rover.global_position.z) - rect.position) / cell).floor()).clamp(Vector2i.ZERO, last)
	var to := Vector2i(((_goal - rect.position) / cell).floor()).clamp(Vector2i.ZERO, last)
	undo.append([from, grid.is_point_solid(from), grid.get_point_weight_scale(from)])
	grid.set_point_solid(from, false)  # parked beside something (the charger): it may still leave
	var ids := grid.get_id_path(from, to, true)  # partial: a mark inside a building ends at the nearest free cell
	# the grid's way runs in eight directions: keep only corners with a clear straight line between them.
	# ponytail: the far end first, then half as far each miss, so a corner may come a little early; every cell tried
	# in turn took most of a 100 ms plan
	path = PackedVector2Array()
	var a := 0
	while a < ids.size() - 1:
		var b := ids.size() - 1
		while b > a + 1 and not _open(grid, ids[a], ids[b]):
			b = (a + b) >> 1
		path.append(grid.get_point_position(ids[b]))
		a = b
	undo.reverse()
	for u: Array in undo:
		grid.set_point_solid(u[0], u[1])
		grid.set_point_weight_scale(u[0], u[2])
	plan_ms = (Time.get_ticks_usec() - t0) / 1000.0
	if ids.is_empty():
		return false
	if path.is_empty():
		path.append(grid.get_point_position(ids[0]))
	# the mark itself, not its cell's middle, and a stop short of it; a way that ends elsewhere is driven to its end
	_stop_m = cell / 2.0
	if ids[-1] == to and rect.has_point(_goal):
		path[-1] = _goal
		_stop_m = float(t.arrive_m)
	_i = 0
	_done = false
	_backing = false
	_best = INF
	_since = 0.0
	return true


## Something on `mask` taller than the rover climbs stands within `clear_m` of the cell's middle. From the climb
## height up: a low rock or a build pad is ground to its wheels (rover.gd _pose).
func _closed(grid: AStarGrid2D, id: Vector2i, climb: float, mask: int) -> bool:
	var c := grid.get_point_position(id)
	_q.shape = _column
	_q.collision_mask = mask
	_q.transform = Transform3D(Basis(), Vector3(c.x, world.height_at(c.x, c.y) + climb + TALL / 2.0, c.y))
	return not world.get_world_3d().direct_space_state.intersect_shape(_q, 1).is_empty()


## Closes a cell and makes the open cells round it dearer; `undo` takes what each was before.
func _close(grid: AStarGrid2D, id: Vector2i, undo: Array) -> void:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var n := id + Vector2i(dx, dy)
			if grid.is_in_boundsv(n):
				undo.append([n, grid.is_point_solid(n), grid.get_point_weight_scale(n)])
				if n == id:
					grid.set_point_solid(n)
				else:
					grid.set_point_weight_scale(n, float(t.near_cost))


## An area's grid with every cell closed by what stands still (buildings, solar rows, posts, tall rocks). Most of the
## plain is empty, so a block of cells is asked about in one go first: 34,000 single looks took half a second.
func _survey(rect: Rect2, cell: float, climb: float) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i((rect.size / cell).floor()))
	grid.cell_size = Vector2(cell, cell)
	grid.offset = rect.position + grid.cell_size / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var size := grid.region.size
	var box := BoxShape3D.new()
	var space := world.get_world_3d().direct_space_state
	for bx in range(0, size.x, BLOCK):
		for by in range(0, size.y, BLOCK):
			var hi := Vector2i(mini(bx + BLOCK, size.x), mini(by + BLOCK, size.y)) - Vector2i.ONE
			var a := grid.get_point_position(Vector2i(bx, by))
			var b := grid.get_point_position(hi)
			var low := INF
			for p: Vector2 in [a, b, Vector2(a.x, b.y), Vector2(b.x, a.y), (a + b) / 2.0]:
				low = minf(low, world.height_at(p.x, p.y))
			box.size = Vector3(b.x - a.x + 2.0 * _column.radius, TALL, b.y - a.y + 2.0 * _column.radius)
			_q.shape = box
			_q.collision_mask = STILL
			_q.transform = Transform3D(Basis(), Vector3((a.x + b.x) / 2.0, low + climb + TALL / 2.0, (a.y + b.y) / 2.0))
			if space.intersect_shape(_q, 1).is_empty():
				continue
			for x in range(bx, hi.x + 1):
				for y in range(by, hi.y + 1):
					if _closed(grid, Vector2i(x, y), climb, STILL):
						_close(grid, Vector2i(x, y), [])
	return grid


## A straight line between two cells crosses only open ground, with room.
func _open(grid: AStarGrid2D, a: Vector2i, b: Vector2i) -> bool:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(1, n):
		var id := Vector2i(Vector2(a).lerp(Vector2(b), float(k) / n).round())
		if grid.is_point_solid(id) or grid.get_point_weight_scale(id) > 1.0:
			return false
	return true
