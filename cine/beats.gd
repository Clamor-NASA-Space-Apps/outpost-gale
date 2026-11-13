extends Node
## The beat runner (design/typical-day.md section 2: the kid feels it first, then PIP names it). It plays a sequence
## from data/beats.json (its `_note` holds the schema): each beat runs its commands, gives PIP its order and emits its
## line id, then waits for a place, an action, an event or a time. Actions and events arrive through notify().
## It moves the look clock, PIP, a door and the ghost, and holds no game state: a choice is only offered
## (choice_offered); the rules (lane S) own it and answer with notify("chose:<id>").

signal line(line_id: String)  # for the HUD (lane H): it looks up the words and shows them
signal beat_done(id: String)
signal choice_offered(id: String)
signal finished(sequence: String)

const Ghost := preload("res://cine/beats_ghost.gd")

var world: Node3D
var player: Node3D
var interactions: Node3D
var clock: Node  # world/sky_clock.gd
var pip: Node3D  # sandbox/pip.gd
var data: Dictionary
var ghost: Ghost
var sequence := ""
var beats: Array = []
var beat := {}  # the one waiting now; empty when no sequence plays
var done: Array[String] = []  # every beat ended, in order (checks)
var _index := -1
var _t := 0.0  # s in this beat
var _met := false  # its action or event arrived (ends it on the next physics tick, never inside a caller)
var _turned := 0.0  # rad the player turned the view in this beat
var _cam_yaw := 0.0
var _launch := -1.0  # the hero's crouch timer last tick: its edges are a crouch and a take-off


func setup(w: Node3D, hero: Node3D, uses: Node3D, sky: Node) -> void:
	world = w
	player = hero
	interactions = uses
	clock = sky
	pip = world.items.get("pip")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json"))
	pip.arrived.connect(notify.bind("pip_arrived"))
	ghost = Ghost.new()
	ghost.name = "Ghost"
	add_child(ghost)
	ghost.setup(world, player, JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json")), data.ghost,
		Forge.HouseStyle.load_design("res://design.json"))


func start_opening() -> void:
	start("opening")


func start(name: String) -> void:
	sequence = name
	beats = data[name]
	done.clear()
	_start(0)


## An action or event from the game: "jump", "look", "lift", "use:<what>", "pip_arrived", "chose:<id>". `_info` (which
## bag, which choice) is for listeners to come; a beat matches on the name alone.
func notify(action: String, _info := {}) -> void:
	var w: Dictionary = beat.get("wait", {})
	if not beat.is_empty() and action == w.get("action", w.get("event", "")):
		_met = true


## The interactions' `used` signal: a bag picked up is a lift, anything else a use.
func used(what: String, _pos: Vector3) -> void:
	notify("lift" if what == "bag" else "use:" + what)


func _physics_process(delta: float) -> void:
	_watch()
	ghost.step(delta)
	if beat.is_empty():
		return
	_t += delta
	var w: Dictionary = beat.get("wait", {})
	if w.get("action") == "look":
		if player.cam.idle < 0.2:  # the player's own turning, not the camera's slow glance
			_turned += absf(wrapf(player.cam.yaw - _cam_yaw, -PI, PI))
		_cam_yaw = player.cam.yaw
		_met = _met or _turned >= deg_to_rad(float(data.watch.look_deg))
	if w.has("place"):
		var at := _spot(w.place.at)
		var b: Vector3 = player.body.global_position
		_met = _met or Vector2(b.x - at.x, b.z - at.z).length() < float(w.place.r)
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


func _start(i: int) -> void:
	_index = i
	beat = beats[i]
	_t = 0.0
	_met = false
	_turned = 0.0
	_cam_yaw = player.cam.yaw
	for c: String in beat.get("do", []):
		_do(c)
	_order(beat.get("pip", {}))
	if beat.has("line"):
		line.emit(beat.line)


func _end() -> void:
	var id: String = beat.id
	var next: String = beat.get("then", "")
	var j := _index + 1 if next == "" else beats.find_custom(func(b: Dictionary) -> bool: return b.id == next)
	done.append(id)
	beat = {}
	beat_done.emit(id)
	if j < 0 or j >= beats.size():
		ghost.on = false
		pip.release()
		finished.emit(sequence)
	else:
		_start(j)


func _do(command: String) -> void:
	var arg := command.get_slice(":", 1)
	match command.get_slice(":", 0):
		"clock":
			if arg == "run":
				clock.pinned = false
			elif arg == "skip":
				clock.pinned = false
				clock.skip()
			else:
				clock.jump(arg)
				clock.pinned = true
		"open":
			for part: Node3D in world.items[arg].get_meta("parts"):
				var it: Node = interactions.by_thing.get(part)
				if part.name == &"door" and it and not it.open:
					interactions.use(it)
		"hero":
			var s: Dictionary = data.starts[arg]
			var item: Node3D = world.items[s.item]
			player.place(item.to_global(Vector3(s.at[0], s.at[1], s.at[2])), -rad_to_deg(item.global_rotation.y) + float(s.yaw))
		"ghost":
			ghost.on = arg == "on"
			ghost.visible = ghost.visible and ghost.on
		"offer":
			choice_offered.emit(arg)
		_:
			push_error("beats.json: unknown command %s" % command)


func _order(o: Dictionary) -> void:
	var face := _look(o.point_at) if o.has("point_at") else Vector3.INF
	if o.has("go_to") or o.has("follow_me"):
		var lead := Vector2(data.pip.lead_wait_m, data.pip.lead_resume_m) if o.has("follow_me") else Vector2.ZERO
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
