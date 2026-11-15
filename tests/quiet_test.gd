extends "res://addons/forge/test.gd"
## PIP's quiet rules and the runner's `page` and `check` keys (cine/beats.gd, design/plans/mission-1.md section 2):
## godot --headless --path . --fixed-fps 60 -s tests/quiet_test.gd
## The real runner plays small sequences given through beats.data (the game's own beats stay as they are) and input
## actions move the hero. Walking after a leading PIP the kid hears the step's line and nothing more; standing still
## they hear one call, or two reminders on a place step, and then no more. A beat's pages, its check and its rules
## (`do` apply:, event:, report:) reach the listeners, and the root hands them to the HUD and the rules.

var game: Node3D
var player: Node3D
var pip: Node3D
var beats: Node  # cine/beats.gd, loaded in play(): it names the Forge autoload, which a test compiles before
var lines: Array[String] = []
var crumbs: Array[Vector3] = []  # PIP's tracks, which the following bot walks
var moving := false


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var world: Node3D = game.get_node("World")
	player = game.get_node("Player")
	pip = world.items.get("pip")
	beats = load("res://cine/beats.gd").new()
	beats.name = "QuietBeats"
	game.add_child(beats)
	beats.setup(world, player, game.interactions, game.clock)
	beats.line.connect(func(id: String, _opts: Dictionary) -> void: lines.append(id))
	var nag: Dictionary = beats.data.nag
	var call: String = beats.data.pip.call_line
	check(nag.at_s.size() == 2 and float(nag.at_s[0]) >= 15.0, "two reminders, the first after 15 s or more (%s)" % [nag.at_s])

	# the start only: PIP beside HAB 1 and the hero behind it (pip_test's lead). From here on, input alone
	pip._place(Vector3(9.07, world.height_at(9.07, -3.462), -3.462), deg_to_rad(9.0))
	player.place(Vector3(9.539, world.height_at(9.539, -0.498) + 0.05, -0.498), 171.0)
	await frames(30)

	# following a leading PIP: the step's line, then silence
	beats.data["quiet_lead"] = [{"id": "lead", "line": "t.lead", "allow": [], "objective": "pip",
		"pip": {"follow_me": "lander"}, "wait": {"place": {"at": "lander", "r": 4.0}}}]
	beats.start("quiet_lead")
	var from: Vector3 = player.body.global_position
	await _for(30.0, _follow)
	var walked := _flat(from, player.body.global_position)
	check(beats.beat.get("id", "") == "lead" and walked > 8.0, "the hero follows PIP for 30 s (%.1f m, beat '%s')" % [walked, beats.beat.get("id", "")])
	check(lines == ["t.lead"], "a kid who follows hears the step's line once: no call, no reminder (%s)" % [lines])
	# standing still: PIP waits, calls once, and the step's line comes back
	_stop()
	await _for(30.0)
	check(lines == ["t.lead", call, "t.lead"], "a kid who stops hears one call, then the step's line again (%s)" % [lines])
	crumbs.clear()
	await _for(10.0, _follow)
	_stop()
	check(lines.size() == 3, "following again: silence (%s)" % [lines])
	beats.skip()

	# a place step ignored: two reminders, then none
	lines.clear()
	beats.data["quiet_stand"] = [{"id": "stand", "line": "t.stand", "allow": [], "objective": "solar",
		"wait": {"place": {"at": "solar", "r": 3.0}}}]
	beats.start("quiet_stand")
	await _for(70.0)
	var said := lines.filter(func(id: String) -> bool: return id != "t.stand")
	check(said == nag.place_lines, "standing still for 70 s: exactly two reminders (%s)" % [lines])
	await _for(80.0)
	check(lines == ["t.stand", nag.place_lines[0], "t.stand", nag.place_lines[1], "t.stand"],
		"still two at 150 s, each followed once by the step's line (%s)" % [lines])
	check(pip._sulk <= 0.0, "no sad bounce")
	beats.skip()

	# pages and a check
	lines.clear()
	var pages: Array[String] = []
	var checks: Array = []
	beats.page.connect(func(id: String) -> void: pages.append(id))
	beats.check_offered.connect(func(c: Dictionary) -> void: checks.append(c))
	beats.data["quiet_book"] = [
		{"id": "two", "page": ["a", "b"], "wait": {"time": 0.5}},
		{"id": "one", "page": "c", "wait": {"time": 0.5}},
		{"id": "quiz", "check": {"id": "t1", "q": "t.q", "options": ["t.a", "t.b", "t.c"], "right": 0, "pages": ["a"]}}]
	beats.start("quiet_book")
	check(pages == ["a", "b"], "a beat with page: [a, b] emits page twice as it starts (%s)" % [pages])
	await frames(45)
	check(pages == ["a", "b", "c"], "a beat with one page id emits it (%s)" % [pages])
	await frames(45)
	check(beats.beat.get("id", "") == "quiz" and checks.size() == 1 and checks[0].id == "t1", "a check beat offers its check once (%d)" % checks.size())
	await frames(120)
	beats.notify("dismissed")
	beats.notify("checked:other")
	await frames(5)
	check(beats.beat.get("id", "") == "quiz" and checks.size() == 1, "it waits for its own answer, with no time limit")
	beats.notify("checked:t1")
	await frames(3)
	check(beats.done == ["two", "one", "quiz"] and beats.beat.is_empty(), "checked:t1 ends it (%s)" % [beats.done])
	check(lines.is_empty(), "a check with no line says nothing (%s)" % [lines])

	# the rules' verbs: the whole command reaches the listener, once each, in the beat's order, and says nothing
	var rules: Array[String] = []
	beats.rule.connect(func(id: String) -> void: rules.append(id))
	beats.data["quiet_rules"] = [{"id": "start", "do": ["apply:body_on", "event:o2_leak", "report:mission1"], "wait": {"time": 0.2}}]
	beats.start("quiet_rules")
	await frames(30)
	check(rules == ["apply:body_on", "event:o2_leak", "report:mission1"] and beats.done == ["start"] and lines.is_empty(),
		"apply:, event: and report: each emit rule once, in order (%s)" % [rules])

	# the root's wiring (sandbox.gd _wire)
	var own: Node = game.beats
	var hud: Control = game.hud
	check(own.page.is_connected(hud.unlock_page) and own.check_offered.is_connected(hud.offer_check), "the root hands pages and checks to the HUD")
	own.data["quiet_root"] = [{"id": "answer", "wait": {"action": "checked:w"}}]
	own.start("quiet_root")
	hud.checked.emit("w")
	await frames(3)
	check(own.done.has("answer"), "the HUD's checked reaches the runner as checked:<id>")
	check(not own.rule.get_connections().is_empty(), "the root listens for the story's rules (beats.rule)")
	if not game.offers.is_empty():
		own.choice_offered.emit(game.offers.keys()[0])
		check(hud.card != null, "an offer opens the decision card")
		hud.close_card()
	return true


## `seconds` of play, calling `each` every tick.
func _for(seconds: float, each := Callable()) -> void:
	for i in int(60 * seconds):
		if each.is_valid():
			each.call()
		await frames(1)


## After PIP along its own tracks, stopping 2 m short of it (beats_test's bot).
func _follow() -> void:
	if crumbs.is_empty() or pip.global_position.distance_to(crumbs[-1]) > 0.5:
		crumbs.append(pip.global_position)
	var b: Vector3 = player.body.global_position
	while crumbs.size() > 1 and _flat(crumbs[0], b) < 0.8:
		crumbs.pop_front()
	if _flat(pip.global_position, b) < 2.0:
		_stop()
		return
	var d: Vector3 = crumbs[0] - b
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
