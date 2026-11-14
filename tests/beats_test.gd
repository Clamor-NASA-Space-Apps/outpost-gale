extends "res://addons/forge/test.gd"
## The Sol 1 opening plays end to end (cine/beats.gd, data/beats.json; the script is design/plans/mission-1.md, Sol 1):
## godot --headless --path . --fixed-fps 60 -s tests/beats_test.gd
## The hero wakes in the airlock and the kid walks out with move and look alone; then input actions take the hero
## through the day as a kid would: to PIP, A and D, S, a look round, a hop (the Earth ghost beside it rises 0.38 as
## high and lands sooner), after PIP round the base (the solar wings, the air tanks and the air maker, the garden),
## the check answered, the choice answered, home after PIP, the sleep. On the way: a teaching line never stops the
## game, each handbook page arrives with its beat, the check waits for its answer and the choice for the check. Every
## beat ends, in the data's order, inside its time; PIP never gives up an order, leads at the hero's pace without
## being caught or calling after a kid who follows, and is let go at the end.

# s each beat may take here: its own wait plus the walking
const BUDGET := {"wake": 40, "outside": 4, "pip_hello": 6, "walk_to_me": 20,
	"side_steps": 10, "back_step": 4, "look_mouse": 6, "try_jump": 4, "jump_fact": 6,
	"follow_solar": 120, "sun_fact": 6, "o2_visit": 120, "tanks_fact": 6, "maker_fact": 6,
	"garden_visit": 180, "garden_fact": 6, "air_check": 2, "choice": 2,
	"day_done": 120, "sleep_hint": 6, "free": 3}
# the handbook pages Sol 1 unlocks, in the order the kid meets them (design/plans/mission-1-contracts.md)
const PAGES: Array[String] = ["thin_air", "pip", "light_on_mars", "weak_sun", "solar_wings", "air_tanks", "air_maker", "garden", "cold_nights"]
const TASKS: Array[String] = ["task.step_outside", "task.learn_moves", "task.tour_base", "task.choose_power", "task.sleep"]

var game: Node3D
var world: Node3D
var player: Node3D
var pip: Node3D
var beats: Node  # cine/beats.gd, loaded in play(): it names the Forge autoload, which a test compiles before
var moving := false
var out_leg := 0  # _walk_out_by_look(): 0 to the hatch, 1 out past it, 2 after PIP
var crumbs: Array[Vector3] = []  # PIP's tracks, which a following bot walks
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
	# the HUD's part, played here: the pages are collected, and the check is answered further down as a kid would
	var pages: Array[String] = []
	var asked: Array[Dictionary] = []
	beats.page.connect(func(id: String) -> void: pages.append(id))
	beats.check_offered.connect(func(c: Dictionary) -> void: asked.append(c))
	# Sol 1 as the sandbox starts it: shortly before sunrise, the clock running (sandbox.gd start_opening)
	var clock: Node = game.clock
	var cine: Node = game.cine
	clock.set_hour(clock.hours - clock.hour() + cine.dawn_hour())
	clock.refresh()
	game._sync_rules()
	beats.start_opening()
	check(not beats.may_sleep(), "no sleep while Sol 1's tasks are left")
	var eye: Vector3 = cine._at(cine.cfg.opening.eye)
	var h0: float = clock.hour()
	check(not clock.pinned and not clock.driven, "the opening holds no hour: the clock runs from the first frame")
	check(cine.sun_clear(h0, eye) < 0.0, "it wakes before the sunrise: the sun %.1f deg under the rim" % cine.sun_clear(h0, eye))
	check(clock.report().sun_el > -12.0, "and not in the night: twilight (sun %.1f deg)" % clock.report().sun_el)
	check(absf(game.sim.sim.local_hour() - h0) < 0.02, "the HUD's hour is the sky's (%.2f, %.2f)" % [game.sim.sim.local_hour(), h0])
	var inside := await _until(func() -> bool: return player.room == "hab1", 1.0)
	check(inside, "the hero starts inside HAB 1 (%s)" % player.room)
	var hatch_it: Node = null
	for part: Node3D in world.items.hab1.get_meta("parts"):
		if part.name == &"door":
			hatch_it = game.interactions.by_thing.get(part)
	# row 2: the first playable frame faces the way out, the hatch in the frame, and the hatch faces the sunrise
	var wake_lens: Camera3D = player.cam.lens
	var wake_hatch: Vector3 = world.items.hab1.to_global(Vector3(0.0, 1.0, -2.2))
	var half := deg_to_rad(wake_lens.fov) / 2.0 * 1.7  # the frame's half-width at 16:9
	var off := (-wake_lens.global_basis.z).angle_to(wake_hatch - wake_lens.global_position)
	check(off < half, "the hero wakes facing HAB 1's hatch: it is %.0f deg off the view's centre" % rad_to_deg(off))
	var sun: Vector3 = load("res://addons/forge/house_style.gd").sun_at(clock._C, h0 + 0.7)
	var door: Vector3 = -world.items.hab1.global_basis.z
	var to_sun := rad_to_deg(Vector2(door.x, door.z).angle_to(Vector2(sun.x, sun.z)))
	check(absf(to_sun) < 5.0, "HAB 1's hatch faces the sunrise (%.1f deg off its bearing)" % to_sun)
	await frames(2)
	check(hatch_it != null and hatch_it.open, "the hatch stands open from the start")
	# PIP waits where the sun comes up (15 Nov: at its airlock stop it stood in the left of the frame, and a kid
	# looking at it missed the sunrise). The spot is world numbers (data/beats.json wake): they go stale if the base
	# turns again, and these fail until they are derived again from the hatch and the sun's bearing at this hour
	var dawn: Vector3 = load("res://addons/forge/house_style.gd").sun_at(clock._C, h0)
	var hatch_at: Vector3 = world.items.hab1.to_global(Vector3(cine.cfg.sleep.hatch[0], 0.0, cine.cfg.sleep.hatch[1]))
	var first: Dictionary = beats.data.opening[0].pip
	var out := Vector2(first.go_to[0] - hatch_at.x, first.go_to[1] - hatch_at.z)
	var stale := rad_to_deg(out.angle_to(Vector2(dawn.x, dawn.z)))
	check(absf(stale) < 3.0 and out.length() > 7.0 and out.length() < 9.0,
		"PIP's first spot is on the line from the hatch to the sunrise, 7 to 9 m out (%.1f deg off it, %.1f m)" % [stale, out.length()])
	check(first.place == first.go_to and _flat(pip.global_position, Vector3(first.go_to[0], 0.0, first.go_to[1])) < 0.6,
		"and PIP stands there from the first frame (%.1f m off)" % _flat(pip.global_position, Vector3(first.go_to[0], 0.0, first.go_to[1])))
	# a kid who turns round first (rows 1, 8): look input turns the view 180 deg, then the kid walks out with move and
	# look alone; nothing walks them
	var turned := [0.0, player.cam.yaw]
	var at: Vector3 = player.body.global_position
	await _until(func() -> bool: return turned[0] >= PI, 4.0, func() -> void:
		turned[0] += absf(wrapf(player.cam.yaw - turned[1], -PI, PI))
		turned[1] = player.cam.yaw
		action(&"look_left", true))
	action(&"look_left", false)
	check(turned[0] >= PI * 0.95, "look input turned the view round in the wake (%.0f deg)" % rad_to_deg(turned[0]))
	await frames(60)
	check(player.body.global_position.distance_to(at) < 0.05 and beats.beat.get("id", "") == "wake", "nothing walks the hero: the wake waits for the kid")
	out_leg = 0
	await _beat("wake", _walk_out_by_look)
	_stop()
	action(&"look_left", false)
	action(&"look_right", false)
	var past: float = (player.body.global_position - wake_hatch).dot(door)
	check(player.room == "" and past > 0.5, "the kid walked out with move and look alone (room '%s', %.1f m past the hatch)" % [player.room, past])
	check(clock.hour() > h0, "the clock ran meanwhile (%.3f to %.3f)" % [h0, clock.hour()])
	# out of the hatch and looking straight ahead: PIP in the middle of the frame, on the sun's bearing
	player.cam.snap(atan2(-door.x, -door.z))
	await frames(3)
	var now_sun: Vector3 = load("res://addons/forge/house_style.gd").sun_at(clock._C, clock.hour())
	var to_pip := Vector2(pip.global_position.x - hatch_at.x, pip.global_position.z - hatch_at.z)
	var off_sun := rad_to_deg(to_pip.angle_to(Vector2(now_sun.x, now_sun.z)))
	check(absf(off_sun) < 10.0, "from the hatch PIP stands on the sun's bearing (%.1f deg off it)" % off_sun)
	var pip_at: Vector3 = pip.global_position + Vector3.UP * 0.4
	var in_frame: Vector2 = wake_lens.unproject_position(pip_at) / root.get_visible_rect().size
	check(not wake_lens.is_position_behind(pip_at) and in_frame.x > 1.0 / 3.0 and in_frame.x < 2.0 / 3.0 and in_frame.y > 0.0 and in_frame.y < 1.0,
		"the kid steps out facing PIP in the middle third of the frame (at %.2f, %.2f of it)" % [in_frame.x, in_frame.y])
	var sees := PhysicsRayQueryParameters3D.create(wake_lens.global_position, pip_at)
	sees.exclude = [player.body.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(sees)
	check(hit.is_empty() or hit.collider == pip or pip.is_ancestor_of(hit.collider), "with nothing between the lens and PIP (%s)" % [hit.get("collider")])
	await _beat("outside")
	await frames(30)
	check(not hatch_it.open, "the hatch shut behind the hero")
	var lessons: Array = beats.data.opening.map(func(b: Dictionary) -> String: return b.id)
	check(lessons.slice(0, 4) == ["wake", "outside", "pip_hello", "walk_to_me"], "no scripted walk or shot in the opening (%s)" % [lessons.slice(0, 4)])
	check(not shots.has("step_out") and not shots.has("look_around"), "no camera shot in Sol 1's opening (%s)" % [shots])
	await _beat("pip_hello")
	check(pip.reached.size() > 0 and pip.reached[-1] == "order", "PIP waits at its spot by the door for the hello")
	check(targets.has("pip") and tasks.has("task.learn_moves"), "PIP is the objective and learning to move the task (%s, %s)" % [targets, tasks])
	await _beat("walk_to_me", func() -> void: _steer(pip.global_position, 2.0))
	_stop()

	# PIP says a step's line once and waits for the kid (its quiet rules have their own test, tests/quiet_test.gd)
	await _beat("side_steps", func() -> void:
		if not Input.is_action_pressed(&"move_left") and not beats._got.has("move_left"):
			action(&"move_left", true)
		elif beats._got.has("move_left") and Input.is_action_pressed(&"move_left"):
			action(&"move_left", false)
			action(&"move_right", true))
	action(&"move_right", false)
	await _beat("back_step", func() -> void:
		if not Input.is_action_pressed(&"move_back"):
			action(&"move_back", true))
	action(&"move_back", false)
	await frames(30)

	await _beat("look_mouse", func() -> void: player.cam.look(6.0, 0.0))

	# the hop and its Earth ghost
	check(pages == PAGES.slice(0, 2), "stepping out and PIP's hello each left a page, the jump's not yet (%s)" % [pages])
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
	# PIP names what the kid felt, and never stops the game for it: no dismiss, the line shows for its time
	check(beats.beat.get("id", "") == "jump_fact" and lines[-1] == "sol1.weigh_less" and pages[-1] == "light_on_mars",
		"after the hop PIP names the gravity and its page lands (%s, %s)" % [lines[-1], pages[-1]])
	await _beat("jump_fact")

	# the tour. After PIP to the solar wings: it leads at the hero's pace and the hero never catches it
	var gap := [INF]
	var ahead := [false]
	crumbs = [player.body.global_position, pip.global_position]
	await _beat("follow_solar", func() -> void:
		var d: float = _flat(pip.global_position, player.body.global_position)
		var to_hero: Vector3 = player.body.global_position - pip.global_position
		# the hero behind it, once it got ahead (not PIP driving past the kid at the start)
		var behind: bool = pip.leading and pip.state == "drive" and pip._ahead(Vector2(to_hero.x, to_hero.z)) < 0.0
		ahead[0] = ahead[0] or behind and d > 2.5
		if behind and ahead[0]:
			gap[0] = minf(gap[0], d)
		# a kid following keeps about PIP's own lead distance (beats.json pip lead_near_m), not one standing on PIP
		# (pip_test walks into it)
		_follow_crumbs(float(beats.data.pip.lead_near_m)))
	_stop()
	check(gap[0] > 1.5, "a hero walking after PIP never comes within 1.5 m while it leads (%.2f m)" % gap[0])
	check(not lines.has("pip.this_way"), "PIP makes no 'this way' call while the kid follows")
	check(tasks[-1] == "task.tour_base" and targets.has("pip"), "the tour is the task, PIP the objective (%s)" % tasks[-1])
	await _beat("sun_fact")  # the hero stands and reads: nothing to dismiss
	check(pages.slice(-2) == ["weak_sun", "solar_wings"], "the solar wings left their two pages (%s)" % [pages])
	# a new lead: the last one's tracks walked the hero straight into PIP; PIP's own spot first, or a hero just past
	# PIP's resume distance and a PIP waiting for him stand still for good
	crumbs = [player.body.global_position, pip.global_position]
	await _beat("o2_visit", _follow_crumbs)
	_stop()
	await _beat("tanks_fact")
	await _beat("maker_fact")
	check(pages.slice(-2) == ["air_tanks", "air_maker"], "the tanks and the air maker left a page each (%s)" % [pages])

	# follow me: the hero dawdles first, so PIP must stop and wait, then follows PIP's own tracks
	crumbs = [player.body.global_position, pip.global_position]
	var waited := await _until(func() -> bool: return pip.state == "behind", 40.0, func() -> void:
		if pip.global_position.distance_to(crumbs[-1]) > 0.5:
			crumbs.append(pip.global_position))  # its tracks from the start: the way round the battery bank too
	check(waited, "PIP stops and looks back when the hero falls behind (state %s)" % pip.state)
	var resumed := [false]
	await _beat("garden_visit", func() -> void:
		resumed[0] = resumed[0] or pip.state == "drive"
		_follow_crumbs())
	_stop()
	check(resumed[0], "PIP goes on once the hero catches up")
	check(asked.is_empty() and offered.is_empty(), "no question and no choice before the garden was shown")
	await _beat("garden_fact")

	# the check: one question once its pages were shown; it waits for the answer, and the choice waits behind it
	await frames(60 * 2)
	var words: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/lines.json"))
	if check(asked.size() == 1 and beats.beat.get("id", "") == "air_check" and offered.is_empty(), "the check is asked once and waits for its answer, the choice behind it (%s)" % [asked]):
		var c: Dictionary = asked[0]
		var options: Array = c.get("options", [])
		check(c.get("id", "") == "sol1" and options.size() == 3 and int(c.get("right", -1)) == 0 and words.get(options[0], "") == "Tanks from Earth",
			"it is Sol 1's question with three answers, the tanks the right one (%s)" % [c])
		check(([c.get("q", "")] + options).all(func(id: String) -> bool: return words.has(id)), "its question and answers have words in data/lines.json")
		var holds: Array = c.get("pages", [])
		check(holds == ["air_tanks", "air_maker", "garden"] and holds.all(func(id: String) -> bool: return pages.has(id)),
			"the pages that hold the answer were unlocked before it was asked (%s)" % [holds])
	await _beat("air_check", func() -> void: beats.notify("checked:sol1"))  # the HUD's answer once the kid got it right

	# the decision: last, with what each option gains and loses (no number until the rules give one)
	check(offered == ["sol1_power"], "the power choice comes last, after the tour and the check (%s)" % [offered])
	var offer: Dictionary = game.offers.sol1_power
	check(offer.options.size() == 2 and offer.options.all(func(o: Dictionary) -> bool:
		return words.has(o.text) and words.has(o.get("gain", "")) and words.has(o.get("lose", "")) and not o.get("apply", []).is_empty()),
		"each option says what it gains and what it loses, and sets a rule")
	check(offer.get("pages", []).all(func(id: String) -> bool: return pages.has(id)) and not offer.get("pages", []).is_empty(), "its handbook pages are unlocked by now (%s)" % [offer.get("pages", [])])
	check(beats.tasks().map(func(t: Dictionary) -> String: return t.label_id) == TASKS, "the Today list is Sol 1's five tasks (%s)" % [beats.tasks()])
	# the sandbox's own handler of a click on the card runs clean (a string `_note` among the offers broke it: a script
	# error, and the opening never got past the choice)
	check(not beats.may_sleep(), "no sleep while the choice waits")
	game.hud.chosen.emit(offer.title, 0)
	beats.notify("chose:sol1_power")  # the rules' answer (lane S)
	await _beat("choice")

	# the day's work done: the Today list keeps only the rest, PIP says so at once and leads to HAB 1, and the bed opens
	# (14 Nov playtest: "I was just sitting there. PIP was silent")
	check(beats.beat.get("id", "") == "day_done" and lines[-1] == "sleep.day_done", "PIP says the work is done at once (%s)" % lines[-1])
	check(beats.tasks() == [{"label_id": "task.sleep", "state": "now"}] and targets[-1] == "hab1", "only the rest is left, HAB 1 the objective (%s, %s)" % [beats.tasks(), targets[-1]])
	check(beats.may_sleep(), "the bed opens once the work is done")
	await frames(30)
	check(pip.leading, "PIP leads the way to HAB 1")
	crumbs = [player.body.global_position, pip.global_position]
	await _beat("day_done", _follow_crumbs)
	_stop()
	await _beat("sleep_hint", func() -> void: beats.notify("dismissed"))
	await frames(5)
	check(not pip.led, "PIP is let go to potter about in free play")
	check(player.allowed.is_empty(), "every action works in free play")
	beats.notify("slept")  # cine.slept, a night
	await _beat("free")

	check(pages == PAGES, "Sol 1 unlocked its nine handbook pages, in order (%s)" % [pages])
	var ids: Array[String] = []
	var own: Array[String] = []
	for b: Dictionary in beats.data.opening:
		ids.append(b.id)
		if b.has("line"):
			own.append(b.line)
	check(beats.done == ids, "every beat ended, in order (%s)" % [beats.done])
	# reminders and calls aside (PIP's quiet rules), and a step's own line said again after one
	var said_own := lines.filter(func(id: String) -> bool: return own.has(id))
	var firsts: Array[String] = []
	for id: String in said_own:
		if firsts.is_empty() or firsts[-1] != id:
			firsts.append(id)
	check(firsts == own, "every beat's line went to the HUD, in order (%s)" % [firsts])
	check(finished == ["opening"], "the opening finished on the sleep")
	check(pip.gave_up == 0, "PIP never gave up on an order (%d)" % pip.gave_up)
	check(player.allowed.is_empty(), "every action works again after the opening")
	check(beats.tasks().all(func(t: Dictionary) -> bool: return t.state == "done") and tasks[-1] == "" and targets[-1] == "",
		"the task list is all done and the objective cleared (%s)" % [beats.tasks()])
	# kid UX: a line is at most 8 words with at most two highlights, and only the day's last line waits for a dismiss
	var long := own.filter(func(id: String) -> bool:
		var text: String = words.get(id, "")
		return text == "" or text.split(" ", false).size() > 8 or text.count("*") not in [0, 2, 4])
	check(long.is_empty(), "every line of Sol 1 is 8 words at most, two highlights at most (%s)" % [long])
	var stops: Array = beats.data.opening.filter(func(b: Dictionary) -> bool: return b.get("fact", false)).map(func(b: Dictionary) -> String: return b.id)
	check(stops.is_empty(), "no line stops the game, the sleep hint included (%s)" % [stops])
	await frames(120)
	check(pip.state != "behind" and not pip.leading, "and it no longer waits for the hero (%s)" % pip.state)

	return true


## A kid after PIP with move and look only: the view turned toward PIP with the look keys, forward held.
func _walk_out_by_look() -> void:
	# through the hatch first (in HAB 1's space: the door on its -Z front), then after PIP
	var hab: Node3D = world.items.hab1
	var marks: Array[Vector3] = [hab.to_global(Vector3(0.0, 0.0, -1.6)), hab.to_global(Vector3(0.0, 0.0, -5.0)), pip.global_position]
	while out_leg < 2 and _flat(marks[out_leg], player.body.global_position) < 0.6:
		out_leg += 1
	var to: Vector3 = marks[out_leg] - player.body.global_position
	var err := wrapf(atan2(-to.x, -to.z) - player.cam.yaw, -PI, PI)
	action(&"look_left", err > 0.1)
	action(&"look_right", err < -0.1)
	var go: bool = absf(err) < 0.6 and (out_leg < 2 or _flat(pip.global_position, player.body.global_position) > 2.0)
	if go != moving:
		moving = go
		action(&"move_forward", go)


## After PIP along its own tracks, stopping `near` m short of it.
func _follow_crumbs(near := 2.0) -> void:
	if crumbs.is_empty() or pip.global_position.distance_to(crumbs[-1]) > 0.5:
		crumbs.append(pip.global_position)
	var b: Vector3 = player.body.global_position
	while crumbs.size() > 1 and _flat(crumbs[0], b) < 0.8:
		crumbs.pop_front()
	if _flat(pip.global_position, b) < near:
		_stop()
	else:
		_steer(crumbs[0])


## Waits for beat `id` to end, calling `each` every tick; past its BUDGET it fails.
func _beat(id: String, each := Callable()) -> void:
	if not check(beats.beat.get("id", "") == id, "beat %s is playing (now '%s')" % [id, beats.beat.get("id", "")]):
		return
	if id != "look_shot":  # row 1: the view is the kid's in every beat; only a playing shot takes it
		var y0: float = player.cam.yaw
		action(&"look_right", true)
		await frames(6)
		action(&"look_right", false)
		check(absf(wrapf(player.cam.yaw - y0, -PI, PI)) > deg_to_rad(3.0), "look input turns the view during %s (%.1f deg)" % [id, rad_to_deg(wrapf(player.cam.yaw - y0, -PI, PI))])
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_physics_frames()
	var ok := await _until(func() -> bool: return beats.done.has(id), float(BUDGET[id]), each)
	var h: Vector3 = player.body.global_position
	print("  %-12s %5.1f s game, %5.1f s real, PIP gave up %d" % [id, (Engine.get_physics_frames() - f0) / 60.0, (Time.get_ticks_msec() - t0) / 1000.0, pip.gave_up])
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
