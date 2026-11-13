extends "res://addons/forge/test.gd"
## The Sol 1 opening plays end to end (cine/beats.gd, data/beats.json):
## godot --headless --path . --fixed-fps 60 -s tests/beats_test.gd
## The hero walks out of the airlock on its own (input blocked), the hatch shuts, the real dawn shot catches the sun
## breaking over the crater rim; then input actions walk the hero through the rest as a kid would: to PIP, A and D, S, a look
## round, a hop (the Earth ghost beside it rises 0.38 as high and lands sooner), a hurry, a bag lifted, the map, after
## PIP to the solar farm, the facts dismissed, the choice answered, then after PIP to the greenhouse. On the way: a
## blocked action does nothing, an ignored step makes PIP plead louder and calm down once the kid does it, a fact
## waits for its dismiss. Every beat ends, in the data's order, inside its time; PIP never gives up an order, leads
## at the hero's pace without being caught, and is let go at the end.

# s each beat may take here: its own wait plus the walking
const BUDGET := {"wake": 4, "hatch": 3, "walk_out": 20, "outside": 12, "pip_hello": 32, "walk_to_me": 20,
	"side_steps": 60, "back_step": 4, "look_shot": 4, "look_mouse": 6, "try_jump": 4, "jump_fact": 6, "hurry": 10,
	"lift": 40, "lift_fact": 2, "map": 2, "map_close": 2, "follow_solar": 120, "sun_fact": 2, "o2_lead": 2,
	"lamps_lead": 2, "choice": 2, "follow_me": 180}

var game: Node3D
var world: Node3D
var player: Node3D
var pip: Node3D
var beats: Node  # cine/beats.gd, loaded in play(): it names the Forge autoload, which a test compiles before
var moving := false
var lines: Array[String] = []
var shots: Array[String] = []


func _init() -> void:
	watchdog = 900.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	player = game.get_node("Player")
	pip = world.items.get("pip")
	# what sandbox.gd adds (the report's wiring lines); the cinematics answer a shot at once here
	beats = load("res://cine/beats.gd").new()
	beats.name = "Beats"
	game.add_child(beats)
	beats.setup(world, player, game.interactions, game.clock)
	game.interactions.used.connect(beats.used)
	var offered: Array[String] = []
	var finished: Array[String] = []
	var tasks: Array[String] = []
	var targets: Array[String] = []
	beats.line.connect(func(id: String, _opts: Dictionary) -> void: lines.append(id))
	beats.task.connect(func(id: String) -> void: tasks.append(id))
	beats.objective.connect(func(t: String) -> void: targets.append(t))
	beats.shot.connect(func(n: String) -> void: shots.append(n))
	beats.choice_offered.connect(func(id: String) -> void: offered.append(id))
	beats.finished.connect(func(s: String) -> void: finished.append(s))
	game.hud.map_toggled.connect(func(open: bool) -> void: beats.notify("map_open" if open else "map_closed"))
	beats.start_opening()
	var clock: Node = game.clock
	var wake_h: float = float(Array(beats.data.opening[0].do).filter(func(c: String) -> bool: return c.begins_with("clock:"))[0].get_slice(":", 1))
	var cine: Node = game.cine
	var rim_eye: Vector3 = cine._at(cine.cfg.shots.dawn_reveal.keys[int(cine.cfg.shots.dawn_reveal.sunrise.key)].eye)
	check(clock.pinned and absf(clock.hour() - wake_h) < 0.01, "the opening pins the look at its pre-dawn hour (%.2f h)" % clock.hour())
	check(cine.sun_clear(clock.hour(), rim_eye) < -2.0, "it wakes before the sunrise: the sun %.1f deg under the rim" % cine.sun_clear(clock.hour(), rim_eye))
	check(clock.report().sun_el > -12.0, "and not in the night: blue twilight (sun %.1f deg)" % clock.report().sun_el)
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

	# the real dawn shot (asked for the moment the walk ends): it holds the clock and runs it to the sunrise
	beats.shot.connect(func(n: String) -> void:
		if n == "dawn_reveal":
			cine.shot(n))
	cine.shot_done.connect(func(n: String) -> void: beats.notify("shot_done:" + n))
	# the walk out is the hero's own: the kid's keys do nothing, the controller walks at walk speed
	var at: Vector3 = player.body.global_position
	var top := [0.0]
	var tried := [0]
	await _beat("walk_out", func() -> void:
		top[0] = maxf(top[0], player.moved)
		tried[0] += 1
		if tried[0] == 30:
			action(&"move_back", true)  # a kid pulling back: the walk goes on
		elif tried[0] == 60:
			action(&"move_back", false))
	check(player.body.global_position.distance_to(at) > 6.0, "the hero walked out on its own (%.1f m)" % player.body.global_position.distance_to(at))
	check(top[0] > player.walk * 0.8 and top[0] < player.walk * 1.15, "at walk speed (%.2f of %.2f m/s)" % [top[0], player.walk])
	check(not player.touch.stick.visible, "the touch stick stays hidden: the kid is not steering")
	check(player.allowed == ["none"], "input is blocked again after the walk (%s)" % [player.allowed])
	check(player.room == "", "the hero is outside (%s)" % player.room)
	await _beat("outside")
	await frames(30)
	check(not hatch_it.open, "the hatch shut behind the hero")
	check(cine.sun_clear(clock.hour(), rim_eye) > 1.0, "the sun stands over the rim when the shot hands back (%.1f deg)" % cine.sun_clear(clock.hour(), rim_eye))
	check(clock.pinned, "and the look holds there until the lessons let it run")
	var lessons: Array = beats.data.opening.map(func(b: Dictionary) -> String: return b.id)
	check(lessons.slice(0, 5) == ["wake", "hatch", "walk_out", "outside", "pip_hello"], "control returns with PIP's hello (%s)" % [lessons.slice(0, 5)])
	await _beat("pip_hello", _answer.bind("focus_pip"))
	check(pip.reached[-1] == "order", "PIP rolled up to its spot before the beat ended")
	check(targets.has("pip") and tasks.has("task.meet_pip"), "PIP is the objective and meeting it the task (%s, %s)" % [targets, tasks])
	await _beat("walk_to_me", func() -> void: _steer(pip.global_position, 2.0))
	_stop()

	# ignored: PIP pleads louder, then calms down once the kid does it
	var level := [0]
	var sulked := [false]
	var pleas := await _until(func() -> bool: return beats._nag >= 3, 50.0, func() -> void:
		sulked[0] = sulked[0] or pip._sulk > 0.0)
	var said := lines.filter(func(id: String) -> bool: return id.begins_with("nag."))
	check(pleas and said == ["nag.gentle", "nag.loud", "nag.sad"], "an ignored step pleads gently, louder, then sad (%s)" % [said])
	await frames(2)
	check(sulked[0] or pip._sulk > 0.0, "PIP bounces sadly at the third plea")
	await frames(60 * 5)
	check(lines[-1] == "sol1.keys_ad", "the step's own line comes back after a plea (%s)" % lines[-1])
	await _beat("side_steps", func() -> void:
		level[0] = maxi(level[0], beats._nag)
		if not Input.is_action_pressed(&"move_left") and not beats._got.has("move_left"):
			action(&"move_left", true)
		elif beats._got.has("move_left") and Input.is_action_pressed(&"move_left"):
			action(&"move_left", false)
			action(&"move_right", true))
	action(&"move_right", false)
	check(beats._nag == 0 and pip._sulk <= 0.0, "calm again once the kid did it")
	await _beat("back_step", func() -> void:
		if not Input.is_action_pressed(&"move_back"):
			action(&"move_back", true))
	action(&"move_back", false)
	await frames(30)

	# a shot: nothing moves the hero or the view
	var yaw0: float = player.cam.yaw
	at = player.body.global_position
	await _hold(&"look_left", 0.5)
	await _hold(&"move_forward", 0.5)
	check(absf(player.cam.yaw - yaw0) < 0.01 and player.body.global_position.distance_to(at) < 0.05, "during a shot the keys do nothing")
	await _beat("look_shot", _answer.bind("look_around"))
	await _beat("look_mouse", func() -> void: player.cam.look(6.0, 0.0))

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
	# a fact waits for its dismiss, however long
	await frames(60 * 4)
	check(beats.beat.get("id", "") == "jump_fact", "a fact waits for its dismiss (%s)" % beats.beat.get("id", ""))
	await _beat("jump_fact", func() -> void: beats.notify("dismissed"))

	# hurry somewhere open, then the bag
	await _beat("hurry", func() -> void:
		if not Input.is_action_pressed(&"hurry"):
			action(&"hurry", true)
		_steer(_ground(8.0, 14.0)))
	action(&"hurry", false)
	_stop()
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
	await _beat("lift_fact", func() -> void: beats.notify("dismissed"))
	await _beat("map", func() -> void:
		action(&"map", true)
		action(&"map", false))
	await _beat("map_close", func() -> void:
		action(&"map", true)
		action(&"map", false))
	check(not game.hud.map_open(), "the map closed again")
	check(offered.is_empty(), "no choice before PIP has shown the power")

	# after PIP to the solar farm: it leads at the hero's pace and the hero never catches it
	var gap := [INF]
	var ahead := [false]
	await _beat("follow_solar", func() -> void:
		var d: float = _flat(pip.global_position, player.body.global_position)
		var to_hero: Vector3 = player.body.global_position - pip.global_position
		# the hero behind it, once it got ahead (not PIP driving past the kid at the start)
		var behind: bool = pip.leading and pip.state == "drive" and pip._ahead(Vector2(to_hero.x, to_hero.z)) < 0.0
		ahead[0] = ahead[0] or behind and d > 2.5
		if behind and ahead[0]:
			gap[0] = minf(gap[0], d)
		if d < 2.0:  # a kid following, not one standing on PIP (pip_test walks into it)
			_stop()
		else:
			_steer(pip.global_position))
	_stop()
	check(gap[0] > 1.5, "a hero walking after PIP never comes within 1.5 m while it leads (%.2f m)" % gap[0])
	check(lines.has("pip.this_way"), "PIP calls 'this way' while it leads")
	for id: String in ["sun_fact", "o2_lead", "lamps_lead"]:
		check(offered.is_empty(), "no choice yet at %s" % id)
		await _beat(id, func() -> void: beats.notify("dismissed"))
	check(not clock.pinned, "the clock runs again: the sun rises and the wings turn")
	check(offered == ["sol1_power"], "the first choice is offered after its lead-in (%s)" % [offered])
	# the sandbox's own handler of a click on the card runs clean (a string `_note` among the offers broke it: a script
	# error, and the opening never got past the choice)
	game.hud.chosen.emit(game.offers.sol1_power.title, 0)
	beats.notify("chose:sol1_power")  # the rules' answer (lane S)
	await _beat("choice")

	# follow me: the hero dawdles first, so PIP must stop and wait, then follows PIP's own tracks
	var crumbs: Array[Vector3] = [player.body.global_position, pip.global_position]
	var waited := await _until(func() -> bool: return pip.state == "behind", 40.0, func() -> void:
		if pip.global_position.distance_to(crumbs[-1]) > 0.5:
			crumbs.append(pip.global_position))  # its tracks from the start: the way round the battery bank too
	check(waited, "PIP stops and looks back when the hero falls behind (state %s)" % pip.state)
	var resumed := [false]
	await _beat("follow_me", func() -> void:
		if pip.global_position.distance_to(crumbs[-1]) > 0.5:
			crumbs.append(pip.global_position)
		resumed[0] = resumed[0] or pip.state == "drive"
		var b: Vector3 = player.body.global_position
		while crumbs.size() > 1 and _flat(crumbs[0], b) < 0.8:
			crumbs.pop_front()
		if _flat(pip.global_position, b) < 2.0:
			_stop()
		else:
			_steer(crumbs[0]))
	_stop()
	check(resumed[0], "PIP goes on once the hero catches up")

	var ids: Array[String] = []
	var own: Array[String] = []
	for b: Dictionary in beats.data.opening:
		ids.append(b.id)
		if b.has("line"):
			own.append(b.line)
	check(beats.done == ids, "every beat ended, in order (%s)" % [beats.done])
	var said_own := lines.filter(func(id: String) -> bool: return not id.begins_with("nag.") and id != "pip.this_way")
	var firsts: Array[String] = []
	for id: String in said_own:
		if firsts.is_empty() or firsts[-1] != id:
			firsts.append(id)
	check(firsts == own, "every beat's line went to the HUD, in order (%s)" % [firsts])
	check(finished == ["opening"], "the opening finished")
	check(pip.gave_up == 0, "PIP never gave up on an order (%d)" % pip.gave_up)
	check(not pip.led, "PIP is let go to potter about again")
	check(player.allowed.is_empty(), "every action works again after the opening")
	check(beats.tasks().all(func(t: Dictionary) -> bool: return t.state == "done") and tasks[-1] == "" and targets[-1] == "",
		"the task list is all done and the objective cleared (%s)" % [beats.tasks()])
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


## The cinematics' answer to a shot, once it was asked for.
func _answer(name: String) -> void:
	if shots.has(name):
		beats.notify("shot_done:" + name)


func _hold(a: StringName, seconds: float) -> void:
	action(a, true)
	await frames(int(60 * seconds))
	action(a, false)
	await frames(2)


## Walks the hero toward `at` the way a player does: the view turned that way, the forward key held; stops within `near`.
func _steer(at: Vector3, near := 0.3) -> void:
	if _flat(at, player.body.global_position) < near:
		_stop()
		return
	var d: Vector3 = at - player.body.global_position
	player.cam.yaw = atan2(-d.x, -d.z)
	if not moving:
		moving = true
		action(&"move_forward", true)


func _stop() -> void:
	if moving:
		moving = false
		action(&"move_forward", false)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, world.height_at(x, z), z)


func _nearest_bag() -> Node3D:
	var best: Node3D = null
	for n: Node in get_nodes_in_group("carriable"):
		var b := n as Node3D
		if best == null or b.global_position.distance_to(player.body.global_position) < best.global_position.distance_to(player.body.global_position):
			best = b
	return best
