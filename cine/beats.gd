extends Node
## The beat runner (design/typical-day.md section 2: the kid feels it first, then PIP names it). It plays a sequence
## from data/beats.json (its `_note` holds the schema): each beat runs its commands, gives PIP its order and emits its
## line id, then waits for a place, an action, an event or a time. Actions and events arrive through notify().
## It moves the look clock, PIP, a door and the ghost, and holds no game state: a choice is only offered
## (choice_offered); the rules (lane S) own it and answer with notify("chose:<id>").
## A tutorial step teaches like a parent: it allows only the actions it teaches (player.allow), shows their keys, waits
## until the kid really does it. PIP says a step's line once, stays quiet while the kid is on it, and reminds twice at
## most (data/beats.json nag; design/plans/mission-1.md section 2).

## For the HUD: the words by id; opts {keys: key-cap names, fact: true when it waits for a dismiss}
signal line(line_id: String, opts: Dictionary)
signal task(line_id: String)  # the task now; tasks() gives the whole list with its states
signal objective(target: String)  # "pip", a landmark or an item id; "" clears it
signal shot(name: String)  # a camera shot for the cinematics; they answer notify("shot_done:<name>")
signal close_door(item: String)  # a door shut (for listeners: the door itself is shut here)
signal skip_sols(count: int)  # `do: skip:<n>`: quiet sols slept through; the rules count them, the HUD shows the ledger
signal trip(landmark: String)  # `do: trip:<landmark>`: the rover trip (cine.trip_to); it answers notify("arrived:<landmark>")
signal liftoff  # `do: liftoff`: the crew flies home (cine.launch); it answers notify("launched")
signal send_mail  # `do: mail`: a message to Earth leaves now (the HUD's visor mail); its reply comes back as mail_arrived
signal beat_done(id: String)
signal choice_offered(id: String)
signal page(id: String)  # a handbook page a starting beat unlocks (its `page`: one id or a list)
signal check_offered(check: Dictionary)  # a beat's `check` (the sol's question); the HUD answers notify("checked:<id>")
signal finished(sequence: String)

const Ghost := preload("res://cine/beats_ghost.gd")
const REST := "task.sleep"  # a sol's last task: once it is the task now, the day's work is done and the bed is open
const NOT_YET := "sleep.not_yet"

var world: Node3D
var player: Node3D
var interactions: Node3D
var clock: Node  # world/sky_clock.gd
var holds_clock := false  # a clock:<hour> holds the sky (the opening): the rules wait too, so the HUD's hour matches it
var pip: Node3D  # sandbox/pip.gd
var data: Dictionary
var _sols := {}  # data/sols.json, read on the first start_sol()
var sol_key := 1  # the data/sols.json key played last (1: the opening); next_sol() follows it
var ghost: Ghost
var sequence := ""
var beats: Array = []
var beat := {}  # the one waiting now; empty when no sequence plays
var done: Array[String] = []  # every beat ended, in order (checks)
var _index := -1
var _t := 0.0  # s in this beat
var _met := false  # its action or event arrived (ends it on the next physics tick, never inside a caller)
var _ever := {}  # every action and event since the sequence started: a wait's `ever` counts one that came early
var _turned := 0.0  # rad the player turned the view in this beat
var _cam_yaw := 0.0
var _launch := -1.0  # the hero's crouch timer last tick: its edges are a crouch and a take-off
var _got := {}  # the actions and events of this beat's wait that arrived
var _held := {}  # s each watched input was held in this beat
var _task := ""
var _nag := 0  # the reminders said in this beat
var _nag_t := 0.0  # s without progress on this step
var _best := INF  # the nearest the hero came to this beat's place
var _pip_there := false  # PIP reached this beat's order
var _back := INF  # s until the beat's own line comes back after an aside, a reminder or a call
var _walk_to := Vector3.INF  # walk:<spot>: where the hero walks on its own, INF when it does not
var _walk_allowed: Array = []  # the kid's allowed actions, given back when the walk ends
var _leading_out := false  # an outdoor beat waits while PIP leads the hero out (outdoors())

const WATCHED: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "hurry"]
const STICK: Array[StringName] = [&"move_right", &"move_left", &"move_back", &"move_forward"]


func setup(w: Node3D, hero: Node3D, uses: Node3D, sky: Node) -> void:
	world = w
	player = hero
	interactions = uses
	clock = sky
	pip = world.items.get("pip")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json"))
	pip.arrived.connect(notify.bind("pip_arrived"))
	pip.back_m = float(data.pip.back_m)
	pip.back_s = float(data.pip.back_s)
	pip.back_lead = float(data.pip.back_lead_s)
	ghost = Ghost.new()
	ghost.name = "Ghost"
	add_child(ghost)
	ghost.setup(world, player, JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json")), data.ghost,
		Forge.HouseStyle.load_design("res://design.json"))


func start_opening() -> void:
	sol_key = 1
	start("opening")


## A played sol past the first (data/sols.json): the composition root calls it once the kid has woken from a night
## on `sol`. False when that sol has no beats.
func start_sol(sol: int) -> bool:
	_load_sols()
	if not _sols.has(str(sol)):
		return false
	sol_key = sol
	data["sol%d" % sol] = _sols[str(sol)]
	start("sol%d" % sol)
	return true


## The sol whose beats come after the ones played last (data/sols.json keys), -1 after the last.
func next_sol() -> int:
	_load_sols()
	var next := -1
	for k: String in _sols:
		if k.is_valid_int() and int(k) > sol_key and (next < 0 or int(k) < next):
			next = int(k)
	return next


func _load_sols() -> void:
	if _sols.is_empty():
		_sols = JSON.parse_string(FileAccess.get_file_as_string("res://data/sols.json"))


func start(name: String) -> void:
	sequence = name
	_ever = {}
	beats = data[name]
	done.clear()
	_start(0)


## An action or event from the game: "jump", "look", "lift", "use:<what>", "pip_arrived", "chose:<id>", "dismissed",
## "shot_done:<name>", "map_open", "map_closed". `_info` (which bag, which choice) is for listeners to come; a beat
## matches on the name alone.
func notify(action: String, _info := {}) -> void:
	if not sequence.is_empty():
		_ever[action] = true
	if action == "pip_arrived":
		_pip_there = true
	var want := _wants()
	if beat.is_empty() or action not in want:
		return
	_got[action] = true
	_met = _met or want.all(func(a: String) -> bool: return _got.has(a))


## The names this beat waits for, all of them: its wait's action or event (one or a list), a fact's dismiss and a
## check's answer.
func _wants() -> Array:
	var w: Dictionary = beat.get("wait", {})
	var out: Array = []
	for k: String in ["action", "event"]:
		if w.has(k):
			out += w[k] if w[k] is Array else [w[k]]
	if beat.get("fact", false):
		out.append("dismissed")
	if beat.has("check"):
		out.append("checked:" + str(beat.check.id))
	return out


## Today's list for the HUD: every task of the sequence in order, done, now or next. Once the rest is the task, the
## day's list is over and only the rest is left (the HUD sees the rows go and plays the list out).
func tasks() -> Array:
	if _task == REST:
		return [{"label_id": REST, "state": "now"}]
	var out: Array = []
	var state := "done"  # before the task now; all of them once the sequence is over
	for b: Dictionary in beats:
		if not b.has("task") or out.any(func(t: Dictionary) -> bool: return t.label_id == b.task):
			continue
		if b.task == _task:
			state = "now"
		out.append({"label_id": b.task, "state": state})
		if state == "now":
			state = "next"
	return out


## The bed is for after the sol's work (14 Nov playtest: a kid slept through Sol 1 and skipped sols): open once only
## the rest is left, or when no sequence plays (after the last sol, or the tutorial skipped from Settings).
func may_sleep() -> bool:
	return sequence.is_empty() or _task == REST


## The bed used too early: PIP says why, then this step's own line comes back.
func refuse_sleep() -> void:
	aside(NOT_YET)


## PIP says `id` between the step's own lines (a warning, a reason), and the step's line comes back after.
func aside(id: String) -> void:
	_say(id, true)


## Out of every room and clear of every door by data outdoors.clear_m: where an outdoor beat or shot may run.
func outdoors() -> bool:
	if player.room != "":
		return false
	var b: Vector3 = player.body.global_position
	for it: Node in get_tree().get_nodes_in_group("interactable"):
		var at: Vector3 = (it as Node3D).global_position
		if it.get("kind") == "door" and Vector2(b.x - at.x, b.z - at.z).length() < float(data.outdoors.clear_m):
			return false
	return true


## The interactions' `used` signal: a bag picked up is a lift, anything else a use.
func used(what: String, _pos: Vector3) -> void:
	notify("lift" if what == "grab" else "use:" + what)


func _physics_process(delta: float) -> void:
	_watch()
	ghost.step(delta)
	if beat.is_empty():
		return
	_t += delta
	if _leading_out:
		if outdoors():
			_leading_out = false
			_t = 0.0
			_enter()
		return
	_auto_walk()
	_inputs(delta)
	_plead(delta)
	var w: Dictionary = beat.get("wait", {})
	if "look" in _wants():
		if player.cam.idle < 0.2:  # the player's own turning, not the camera's slow glance
			_turned += absf(wrapf(player.cam.yaw - _cam_yaw, -PI, PI))
			_nag_t = 0.0
		_cam_yaw = player.cam.yaw
		_met = _met or _turned >= deg_to_rad(float(data.watch.look_deg))
	if w.has("place"):
		var at := _spot(w.place.at)
		var b: Vector3 = player.body.global_position
		var d := Vector2(b.x - at.x, b.z - at.z).length()
		_met = _met or d < float(w.place.r)
		if d < _best - 1.0:  # the kid is on the way: no reminder
			_best = d
			_nag_t = 0.0
		# a kid who followed PIP all the way and stands beside it has arrived, from whichever side: outside the place's
		# circle the step never ended, and PIP only pleaded "Over here!" at a kid already there
		if beat.get("pip", {}).has("follow_me") and _pip_there:
			var p: Vector3 = pip.global_position
			_met = _met or Vector2(b.x - p.x, b.z - p.z).length() < float(data.pip.lead_wait_m)
	if w.has("ever"):
		var names: Array = w.ever if w.ever is Array else [w.ever]
		_met = _met or names.all(func(a: String) -> bool: return _ever.has(a))
	if _met or _t >= float(w.get("time", INF)) or _t >= float(w.get("max_s", INF)):
		_end()


## The hero's crouch and take-off, from its crouch timer (player.gd `launch`): the ghost follows, and a take-off is
## the jump action.
func _watch() -> void:
	var l: float = player.launch
	if l >= 0.0 and _launch < 0.0:
		ghost.crouch()
	elif l < 0.0 and _launch >= 0.0 and player.body.velocity.y > 0.0:
		ghost.take_off()
		notify("jump")
	_launch = l


## The watched inputs held long enough to count (data watch.hold_s): a move key, or hurry while really hurrying.
func _inputs(delta: float) -> void:
	var want := _wants()
	for a in WATCHED:
		if a in want and player.may(a) and (player.hurrying and player.moved > player.walk * 1.1 if a == "hurry" else Input.is_action_pressed(a)):
			_held[a] = _held.get(a, 0.0) + delta
			_nag_t = 0.0  # on it: no reminder
			if _held[a] >= float(data.watch.hold_s):
				notify(a)


## A step the kid is not doing (design/plans/mission-1.md section 2): one reminder at each of nag.at_s seconds without
## progress, then none for this beat; a leading PIP's reminder is its call. Progress starts the count again: nearer
## the place, a watched key held, the view turning (set where those are read), or beside the leading PIP. A beat with
## a job for the kid (keys, an objective, a lead or its own nag lines) reminds; a fact, a shot or a plain wait never.
func _plead(delta: float) -> void:
	_back -= delta
	if _back <= 0.0:
		_back = INF
		_say(beat.line)
	var lead: bool = beat.get("pip", {}).has("follow_me")
	var n: Dictionary = data.nag
	if _nag >= n.at_s.size() or beat.get("fact", false) or not (lead or beat.has("keys") or beat.get("objective") != null or beat.has("nag")):
		return
	var gap: Vector3 = player.body.global_position - pip.global_position
	_nag_t = 0.0 if lead and Vector2(gap.x, gap.z).length() < float(data.pip.lead_resume_m) else _nag_t + delta
	if _nag_t < float(n.at_s[_nag]):
		return
	_nag += 1
	pip.nag(_nag, n)
	_say(data.pip.call_line if lead else beat.get("nag", n.place_lines if beat.get("wait", {}).has("place") else n.lines)[_nag - 1], true)


## A line with this beat's keys and fact; `aside` (a warning, a reminder, a call) gives way to the beat's own line
## after back_s.
func _say(id: String, aside := false) -> void:
	var opts := {"keys": beat.get("keys", []), "fact": beat.get("fact", false)}
	line.emit(id, opts)
	if aside and beat.has("line"):
		_back = float(data.nag.back_s)


func _start(i: int) -> void:
	_index = i
	beat = beats[i]
	_leading_out = false
	_t = 0.0
	_met = false
	_turned = 0.0
	_cam_yaw = player.cam.yaw
	_got = {}
	_held = {}
	_best = INF
	_pip_there = false
	_back = INF
	_nag = 0
	_nag_t = 0.0
	# a beat that needs the hero outdoors (an outdoor shot) never runs indoors: PIP leads the way out first, and the
	# beat starts once the hero is out (skills/guided-tutorial row 3)
	if beat.get("outdoors", false) and not outdoors():
		_leading_out = true
		player.allow(["move", "look"])
		if world.items.has(player.room):
			_do("open:" + player.room)  # the way out stands open
		_order({"follow_me": data.outdoors.spot})
		_say(data.pip.call_line, true)
		return
	_enter()


## The beat's own start: its allowed actions, commands, PIP's order, task, objective, line, pages and check.
func _enter() -> void:
	if beat.has("allow"):
		player.allow(beat.allow)
	for c: String in beat.get("do", []):
		_do(c)
	_order(beat.get("pip", {}))
	if beat.has("task") and beat.task != _task:
		_task = beat.task
		task.emit(_task)
	if beat.has("objective"):
		objective.emit(beat.objective if beat.objective != null else "")
	if beat.has("line"):
		_say(beat.line)
	var pages: Variant = beat.get("page", [])
	for id: String in pages if pages is Array else [pages]:
		page.emit(id)
	if beat.has("check"):
		check_offered.emit(beat.check)


## walk:<spot>: the move keys pressed toward the spot, the way the kid would steer, so the real controller walks the
## hero at walk speed with its clips and footsteps; pressed again every tick, so a key the kid lets go of meanwhile
## cannot stop it. Within 0.3 m it stands (a place wait ends the beat before that).
func _auto_walk() -> void:
	if _walk_to == Vector3.INF:
		return
	var d: Vector3 = _walk_to - player.body.global_position
	var stick := Vector2.ZERO
	if Vector2(d.x, d.z).length() > 0.3:
		var local: Vector3 = player.cam.ground_basis().inverse() * Vector3(d.x, 0.0, d.z)
		stick = Vector2(local.x, local.z).normalized()
	for i in 4:
		var push := maxf([stick.x, -stick.x, stick.y, -stick.y][i], 0.0)
		if push > 0.0:
			Input.action_press(STICK[i], push)
		else:
			Input.action_release(STICK[i])


func _stop_walk() -> void:
	if _walk_to == Vector3.INF:
		return
	_walk_to = Vector3.INF
	for a in STICK:
		Input.action_release(a)
	player.allowed = _walk_allowed


## Ends the running sequence at once (Settings, Demo: skip the tutorial): the hero is free and the clock runs.
func skip() -> void:
	if sequence.is_empty():
		return
	_stop_walk()
	beat = {}
	holds_clock = false
	clock.pinned = false
	ghost.on = false
	pip.release()
	player.allow([])
	_task = ""
	task.emit("")
	objective.emit("")
	var was := sequence
	sequence = ""
	finished.emit(was)


func _end() -> void:
	_stop_walk()
	var id: String = beat.id
	var next: String = beat.get("then", "")
	var j := _index + 1 if next == "" else beats.find_custom(func(b: Dictionary) -> bool: return b.id == next)
	done.append(id)
	beat = {}
	beat_done.emit(id)
	if j < 0 or j >= beats.size():
		ghost.on = false
		pip.release()
		player.allow([])
		_task = ""
		task.emit("")
		objective.emit("")
		finished.emit(sequence)
	else:
		_start(j)


func _do(command: String) -> void:
	var arg := command.get_slice(":", 1)
	match command.get_slice(":", 0):
		"clock":
			holds_clock = arg.is_valid_float()
			if arg == "run":
				clock.pinned = false
			elif arg == "skip":
				clock.pinned = false
				clock.skip()
			elif arg.is_valid_float():  # an hour of this sol (the opening's pre-dawn: data/beats.json _note)
				clock.set_hour(clock.hours - clock.hour() + float(arg))
				clock.refresh()
				clock.pinned = true
			else:
				clock.jump(arg)
				clock.pinned = true
		"open":  # the airlock cycles it open: no hand reach, no hero glide (set_door waits for a clear swing)
			interactions.set_door(arg, true)
		"close":
			if interactions.has_method("set_door"):
				interactions.set_door(arg, false)  # waits until the hero is clear of the swing
			else:
				push_warning("beats: interactions has no set_door, %s stays open" % arg)
			close_door.emit(arg)
		"shot":
			shot.emit(arg)
		"mail":
			send_mail.emit()
		"skip":
			skip_sols.emit(int(arg))
		"trip":
			trip.emit(arg)
		"liftoff":
			liftoff.emit()
		"walk":
			_walk_to = _spot(Array(arg.split_floats(",")) if "," in arg else arg)
			_walk_allowed = player.allowed
			# the controller reads the move keys through player.may(); set straight, not by allow(), so the touch
			# stick and the key caps stay hidden. Looking stays the kid's (skills/guided-tutorial row 1): the
			# steering follows the view each tick
			player.allowed = ["move", "look"]
		"hero":
			var s: Dictionary = data.starts[arg]
			var item: Node3D = world.items[s.item]
			player.place(item.to_global(Vector3(s.at[0], s.at[1], s.at[2])), -rad_to_deg(item.global_rotation.y) + float(s.yaw))
			player.cam.snap(player.yaw)  # the view, and the helmet with it, faces the way the hero does: the way out
		"ghost":
			ghost.on = arg == "on"
			ghost.visible = ghost.visible and ghost.on
		"offer":
			choice_offered.emit(arg)
		_:
			push_error("beats.json: unknown command %s" % command)


func _order(o: Dictionary) -> void:
	if o.get("release", false):  # free play: back to pottering about
		pip.release()
		return
	if o.has("place"):  # unseen, over a night: a sol may end with PIP far from the base
		pip._place(_spot(o.place), pip.yaw)
	var face := _look(o.point_at) if o.has("point_at") else Vector3.INF
	if o.has("go_to") or o.has("follow_me"):
		var lead := Vector3(data.pip.lead_wait_m, data.pip.lead_resume_m, data.pip.lead_near_m) if o.has("follow_me") else Vector3.ZERO
		pip.order(_spot(o.get("go_to", o.get("follow_me"))), face, o.get("wave", false), lead)
		return
	if o.has("point_at"):
		pip.point_at(face)
	if o.get("wave", false):
		pip.wave()


## A spot on the ground: [x, z], `pip`, `hero`, a PIP stop id, a landmark or an item id.
func _spot(s: Variant) -> Vector3:
	if s is Array:
		return Vector3(s[0], world.height_at(s[0], s[1]), s[1])
	if s == "pip":
		return pip.global_position
	if s == "hero":
		return player.body.global_position
	for stop: Dictionary in pip.p.stops:
		if stop.id == s:
			return _spot(stop.at)
	if world.data.landmarks.has(s):
		return world.landmark(s).pos
	if world.items.has(s):
		return (world.items[s] as Node3D).global_position
	push_error("beats.json: no spot %s" % s)
	return player.body.global_position


## A point to look at: [x, z, height], `hero` (the helmet), a PIP stop id (what it looks at there) or an item id.
func _look(s: Variant) -> Vector3:
	if s is Array:
		return Vector3(s[0], world.height_at(s[0], s[1]) + float(s[2]), s[1])
	if s == "hero":
		return player.body.global_position + Vector3.UP * 1.6
	for stop: Dictionary in pip.p.stops:
		if stop.id == s:
			return _look(stop.look)
	return _spot(s) + Vector3.UP
