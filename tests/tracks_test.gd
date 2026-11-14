extends "res://addons/forge/test.gd"
## The rover's ruts in the trail map (world/terrain.gd rut()): wherever a wheel rolled the dust is pressed, in one
## unbroken line along that wheel's own way, whoever drives; nothing is pressed away from a wheel; standing presses
## nothing new. godot --headless --path . --fixed-fps 60 -s tests/tracks_test.gd

const PRESSED := 0.1  # a print's depth that counts as one: half the faintest rut (tuning rover.track_depth 0.5), faded
const ENDS := 0.3  # m at each end of a wheel's way left out: the next print is laid once the wheel is 0.12 m on

var game: Node3D
var world: Node3D
var rover: Node3D
var t: Node3D  # world/terrain.gd
var ways: Array = []  # each wheel's way over the ground since the last put-down: PackedVector2Array (x, z)
var near := {}  # the map's 4 px cells within 0.25 m of anywhere a wheel has been


func _init() -> void:
	watchdog = 300.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	world = game.world
	rover = world.items.rover
	t = world.terrain
	game.pip.process_mode = Node.PROCESS_MODE_DISABLED  # its own prints are pip_test's
	game.player.enter(rover)  # no walk up to the hatch: the boots' prints are not the rover's
	await frames(3)
	t.trail.fill(Color(0, 0, 0))  # the hero's first step where the game put it down
	check(rover.wheels.size() == 6, "the rover has six wheels (%d)" % rover.wheels.size())

	# the autopilot's start: it turns as it pulls away, where the prints once lay across the wheels' way
	_begin()
	var reactor: Vector3 = world.landmark("reactor").pos
	game.hud.set_mark(Vector2(reactor.x, reactor.z))
	var far := 0.0
	var was: Vector3 = rover.global_position
	while far < 30.0 and ways[0].size() < 3600:
		await _drive(1)
		far += Vector2(rover.global_position.x - was.x, rover.global_position.z - was.z).length()
		was = rover.global_position
	check(far >= 30.0 and game.player.pilot.driving(), "the autopilot drives its first 30 m (%.1f m)" % far)
	game.hud.set_mark(null)
	await _drive(240)
	_judge("the autopilot")
	await _stand()

	# put down on open ground as a trip puts it down (cine.gd): no rut between there and here
	rover.yaw = PI / 2.0
	rover.v = 0.0
	rover._apply(rover._pose(Vector3(45.0, 0.0, -45.0), rover.yaw))
	game.player.cam.snap(rover.yaw)
	await frames(60)
	_begin()
	action(&"move_forward")
	await _drive(180)
	action(&"move_left")
	await _drive(240)
	action(&"move_forward", false)  # slowing with the lock held, then a turn on the spot
	await _drive(300)
	action(&"move_left", false)
	action(&"move_back")
	await _drive(180)
	action(&"move_right")
	await _drive(180)
	action(&"move_back", false)
	action(&"move_right", false)
	await _drive(240)
	check(rover.blocked == "" and absf(rover.v) < 0.01, "the keyed drive met nothing and has stopped (blocked '%s')" % rover.blocked)
	_judge("the keys (ahead, a turn, a spin, back, a turn backing)")
	await _stand()
	return true


## A new set of ways: the wheels were put down here.
func _begin() -> void:
	ways.clear()
	for h: Vector3 in rover.hubs:
		ways.append(PackedVector2Array())
	_note()


func _drive(n: int) -> void:
	for i in n:
		await physics_frame
		_note()


## Where each wheel stands on the ground now.
func _note() -> void:
	for i in rover.hubs.size():
		var p: Vector3 = rover.global_transform * Vector3(rover.hubs[i].x, 0.0, rover.hubs[i].z)
		var at := Vector2(p.x, p.z)
		if ways[i].is_empty() or ways[i][-1].distance_to(at) > 0.005:
			ways[i].append(at)
			var c := Vector2i((at / t.TRAIL_MPX / 4.0).floor())
			for x in range(-2, 3):
				for y in range(-2, 3):
					near[c + Vector2i(x, y)] = true


## Every wheel's way is pressed from end to end, and nothing is pressed anywhere else.
func _judge(what: String) -> void:
	var bare := 0.0  # m of the wheels' ways with no print
	var worst := 0.0  # the longest bare stretch
	var total := 0.0
	var where := ""
	for i in ways.size():
		var way: PackedVector2Array = ways[i]
		var length := 0.0
		for k in range(1, way.size()):
			length += way[k].distance_to(way[k - 1])
		var run := 0.0
		var gone := 0.0
		for k in range(1, way.size()):
			var step := way[k].distance_to(way[k - 1])
			gone += step
			if gone < ENDS or gone > length - ENDS:
				continue
			total += step
			var d := _depth(way[k])
			if d >= PRESSED or d < 0.0:
				run = 0.0
				continue
			bare += step
			run += step
			if run > worst:
				worst = run
				where = "wheel %d at %s" % [i + 1, way[k].snapped(Vector2.ONE * 0.1)]
	check(total > 40.0, "%s: the wheels' ways are measured (%.0f m)" % [what, total])
	check(bare == 0.0, "%s: every wheel's way is one unbroken rut (%.1f of %.0f m bare, the longest gap %.2f m, %s)" % [what, bare, total, worst, where])
	var stray := _strays()
	check(stray.n == 0, "%s: nothing is pressed away from a wheel's way (%d map pixels, the first at %s)" % [what, stray.n, stray.at])


## Aboard with no key for five seconds: the map does not change.
func _stand() -> void:
	await frames(30)
	var before: PackedByteArray = t.trail.get_data()
	await frames(300)
	check(t.trail.get_data() == before, "standing five seconds presses nothing new")


## The map's depth at a world point, the deepest of the pixel and its neighbours; -1 outside the map's square.
func _depth(at: Vector2) -> float:
	var g := Vector2i((at / t.TRAIL_MPX).round())
	if not Rect2i(t.trail_win, Vector2i(t.trail_px, t.trail_px)).grow(-2).has_point(g):
		return -1.0
	var d := 0.0
	for x in range(-1, 2):
		for y in range(-1, 2):
			d = maxf(d, t.trail.get_pixel(posmod(g.x + x, t.trail_px), posmod(g.y + y, t.trail_px)).r)
	return d


## Pressed map pixels further than a print's reach from anywhere a wheel has been.
func _strays() -> Dictionary:
	var out := {"n": 0, "at": ""}
	var px: int = t.trail_px
	for ty in range(0, px, 64):
		for tx in range(0, px, 64):
			var tile: PackedByteArray = t.trail.get_region(Rect2i(tx, ty, 64, 64)).get_data()
			if tile.count(0) == tile.size():
				continue
			for k in tile.size():
				if tile[k] > 5:
					# the map wraps: the world pixel this one holds now (terrain.gd mark())
					var g := Vector2i(t.trail_win.x + posmod(tx + k % 64 - t.trail_win.x, px), t.trail_win.y + posmod(ty + (k >> 6) - t.trail_win.y, px))
					if not near.has(Vector2i((Vector2(g) / 4.0).floor())):
						out.n += 1
						if out.at == "":
							out.at = str((Vector2(g) * t.TRAIL_MPX).snapped(Vector2.ONE * 0.1))
	return out
