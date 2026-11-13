extends "res://addons/forge/test.gd"
## The Sol 1 opening plays end to end (cine/beats.gd, data/beats.json):
## godot --headless --path . --fixed-fps 60 -s tests/beats_test.gd
## Input actions walk the hero through it as a kid would: out of the airlock, to PIP, a look round, a hop (the Earth
## ghost beside it rises 0.38 as high and lands sooner), a bag lifted, the choice answered, then after PIP to the day's
## task. Every beat ends, in the data's order, inside its time; PIP never gives up an order, stops for a hero left
## behind and goes on, and is let go at the end. A beat that does not end in time fails the test.

# s each beat may take here: its own wait plus the walking. The opening's whole budget is about five minutes of play
const BUDGET := {"wake": 4, "hatch": 3, "step_out": 20, "pip_hello": 39, "walk_to_me": 20, "look_around": 6,
	"try_jump": 4, "jump_named": 6, "lift": 40, "lift_named": 5, "sun": 10, "choice": 2, "follow_me": 180}

var game: Node3D
var world: Node3D
var player: Node3D
var pip: Node3D
var beats: Node  # cine/beats.gd, loaded in play(): it names the Forge autoload, which a test compiles before
var moving := false


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	player = game.get_node("Player")
	pip = world.items.get("pip")
	# what sandbox.gd adds (the report's lines)
	beats = load("res://cine/beats.gd").new()
	beats.name = "Beats"
	game.add_child(beats)
	beats.setup(world, player, game.interactions, game.clock)
	game.interactions.used.connect(beats.used)
	var lines: Array[String] = []
	var offered: Array[String] = []
	var finished: Array[String] = []
	var arrivals := [0]
	beats.line.connect(func(id: String) -> void: lines.append(id))
	beats.choice_offered.connect(func(id: String) -> void: offered.append(id))
	beats.finished.connect(func(s: String) -> void: finished.append(s))
	pip.arrived.connect(func() -> void: arrivals[0] += 1)
	beats.start_opening()
	var clock: Node = game.clock
	check(clock.pinned and absf(clock.hour() - float(clock._phase_h.dawn)) < 0.01, "the opening pins the look at dawn (%.2f h)" % clock.hour())
	var inside := await _until(func() -> bool: return player.room == "hab1", 1.0)
	check(inside, "the hero starts inside HAB 1 (%s)" % player.room)

	var hatch_it: Node = null
	for part: Node3D in world.items.hab1.get_meta("parts"):
		if part.name == &"door":
			hatch_it = game.interactions.by_thing.get(part)
	check(hatch_it != null and not hatch_it.open, "HAB 1 has a shut outer hatch")
	await _beat("wake")
	await _beat("hatch")
	check(hatch_it != null and hatch_it.open, "the hatch opens on the dawn")
	await _beat("step_out", func() -> void: _steer(Vector3(0.0, 0.0, 4.5)))
	_stop()
	await _beat("pip_hello")
	check(arrivals[0] == 1 and pip.reached[-1] == "order", "PIP rolled up to its spot (%d arrivals) before the beat ended" % arrivals[0])
	await _beat("walk_to_me", func() -> void: _steer(pip.global_position, 2.0))
	_stop()
	await _beat("look_around", func() -> void: player.cam.look(6.0, 0.0))  # its budget is far under its max_s

	# the hop and its Earth ghost
	var y0: float = player.body.global_position.y
	var hero_peak := 0.0
	var hero_air := 0.0
	var ghost_seen := false
	var pressed := [false]
	await _beat("try_jump", func() -> void:
		if not pressed[0]:
			pressed[0] = true
			action(&"jump", true)
			action(&"jump", false))
	for i in 90:  # the rest of the hop
		await frames(1)
		hero_peak = maxf(hero_peak, player.body.global_position.y - y0)
		hero_air += 1.0 / 60.0 if not player.on_floor else 0.0
		ghost_seen = ghost_seen or beats.ghost.visible
	var g: Node3D = beats.ghost
	var expect: float = pow(g._v0, 2.0) / (2.0 * g._g)
	check(ghost_seen, "a ghost shows beside the hero on the hop")
	check(absf(g.peak - expect) < 0.05 * expect, "the ghost rises as high as Earth allows (%.3f m, physics %.3f)" % [g.peak, expect])
	check(hero_peak > 2.0 * g.peak, "the hero on Mars rises well over twice as high (%.3f m against %.3f)" % [hero_peak, g.peak])
	check(g.air < 0.6 * hero_air, "the ghost lands sooner (%.2f s against %.2f)" % [g.air, hero_air])
	print("  hop: hero %.3f m %.2f s, ghost %.3f m %.2f s" % [hero_peak, hero_air, g.peak, g.air])
	await _beat("jump_named")
	check(not g.visible, "the ghost is gone once the lesson is over")

	await _beat("lift", func() -> void:
		var bag := _nearest_bag()
		var t: Node = game.interactions.target
		if t and t.kind == "bag":
			_stop()
			action(&"interact", true)
			action(&"interact", false)
		elif bag:
			_steer(bag.global_position))
	_stop()
	check(game.interactions.carried != null, "the hero lifted a bag")
	await _beat("lift_named")
	await _beat("sun")
	check(not clock.pinned, "the clock runs again: the sun rises and the wings turn")
	check(offered == ["sol1_power"], "the first choice is offered (%s)" % [offered])
	beats.notify("chose:sol1_power")  # the rules' answer (lane S)
	await _beat("choice")

	# follow me: the hero dawdles first, so PIP must stop and wait, then follows PIP's own tracks
	var waited := await _until(func() -> bool: return pip.state == "behind", 40.0)
	check(waited, "PIP stops and looks back when the hero falls behind (state %s)" % pip.state)
	var crumbs: Array[Vector3] = [player.body.global_position, pip.global_position]
	var resumed := [false]
	await _beat("follow_me", func() -> void:
		if pip.global_position.distance_to(crumbs[-1]) > 0.5:
			crumbs.append(pip.global_position)
		resumed[0] = resumed[0] or pip.state == "drive"
		var b: Vector3 = player.body.global_position
		while crumbs.size() > 1 and Vector2(crumbs[0].x - b.x, crumbs[0].z - b.z).length() < 0.8:
			crumbs.pop_front()
		if Vector2(pip.global_position.x - b.x, pip.global_position.z - b.z).length() < 2.0:
			_stop()
		else:
			_steer(crumbs[0]))
	_stop()
	check(resumed[0], "PIP goes on once the hero catches up")

	var ids: Array[String] = []
	var said: Array[String] = []
	for b: Dictionary in beats.data.opening:
		ids.append(b.id)
		if b.has("line"):
			said.append(b.line)
	check(beats.done == ids, "every beat ended, in order (%s)" % [beats.done])
	check(lines == said, "every line id went to the HUD, in order (%d of %d)" % [lines.size(), said.size()])
	check(finished == ["opening"], "the opening finished")
	check(pip.gave_up == 0, "PIP never gave up on an order (%d)" % pip.gave_up)
	check(not pip.led, "PIP is let go to potter about again")
	await frames(120)
	check(pip.state != "behind" and not pip.leading, "and it no longer waits for the hero (%s)" % pip.state)
	return true


## Waits for beat `id` to end, calling `each` every tick; past its BUDGET it fails.
func _beat(id: String, each := Callable()) -> void:
	if not check(beats.beat.get("id", "") == id, "beat %s is playing (now '%s')" % [id, beats.beat.get("id", "")]):
		return
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_physics_frames()
	var ok := await _until(func() -> bool: return beats.done.has(id), float(BUDGET[id]), each)
	var h: Vector3 = player.body.global_position
	print("  %-12s %5.1f s game, %5.1f s real" % [id, (Engine.get_physics_frames() - f0) / 60.0, (Time.get_ticks_msec() - t0) / 1000.0])
	check(ok, "beat %s ends within %d s (hero at %.1f, %.1f; PIP %s at %.1f, %.1f)" % [id, BUDGET[id], h.x, h.z, pip.state,
		pip.global_position.x, pip.global_position.z])


func _until(ok: Callable, seconds: float, each := Callable()) -> bool:
	for i in int(60 * seconds):
		if ok.call():
			return true
		if each.is_valid():
			each.call()
		await frames(1)
	return ok.call()


## Walks the hero toward `at` the way a player does: the view turned that way, the forward key held; stops within `near`.
func _steer(at: Vector3, near := 0.3) -> void:
	var d: Vector3 = at - player.body.global_position
	if Vector2(d.x, d.z).length() < near:
		_stop()
		return
	player.cam.yaw = atan2(-d.x, -d.z)
	if not moving:
		moving = true
		action(&"move_forward", true)


func _stop() -> void:
	if moving:
		moving = false
		action(&"move_forward", false)


func _nearest_bag() -> Node3D:
	var best: Node3D = null
	for n: Node in get_nodes_in_group("carriable"):
		var b := n as Node3D
		if best == null or b.global_position.distance_to(player.body.global_position) < best.global_position.distance_to(player.body.global_position):
			best = b
	return best
