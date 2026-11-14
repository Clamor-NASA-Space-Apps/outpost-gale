extends Node3D
## Pictures of the cinematics around the real sandbox, for Ravindu (capture-view --scene), until the root wires them:
##   node ../../tools/capture-view.mjs . captures/cine_sleep --scene res://cine/cine_views.tscn --scale 0.5 --views sleep_drone@22,sleep_drone@2,sleep_drone@5,sleep_drone@6.3,wake@6.4,wake_door@6.4
##   node ../../tools/capture-view.mjs . captures/cine_trip --scene res://cine/cine_views.tscn --scale 0.5 --views trip_drive,trip_title -- hour=11
##   node ../../tools/capture-view.mjs . captures/cine_launch --scene res://cine/cine_views.tscn --scale 0.5 --views launch_out,launch_window -- hour=20.5
##   node ../../tools/capture-view.mjs . captures/k --scene res://cine/cine_views.tscn --scale 0.5 --views dawn_reveal,look_around,focus_pip -- hour=6.5 speed=4
## Animation #1 (the opening's step_out), frozen every quarter second: --views anim1@0,anim1@0.25,... -- speed=2
## The sunrise (the opening's pre-dawn 05:48, then the shot runs the clock): --views airlock@5.8,dawn_reveal@1.5,
## dawn_reveal@3.0,dawn_reveal@4.6,dawn_reveal@6.0,sleep_drone@6.05,sleep_drone@6.3 -- speed=4
## The tutorial shots (cine.shot()) start with the hero just out of HAB 1's door, facing out, and hold the picture
## `SHOT_AT` seconds in; `name@s` picks another moment.
## sleep_drone@H: the drone shot where the lapse is at hour H (a night from 22:00); wake: the hero on the bench, filmed
## from across HAB 1; wake_door: standing at the bench facing the open hatch, first person. The others play the real
## shot and hold the picture until it reaches the beat (busy()).

const Cine := preload("res://cine/cine.gd")

var game: Node3D
var cine: Node
var _want := ""  # the beat the picture waits for, "" for none
var _after := 0.0  # seconds into it
var _since := 0.0
var _hold := 0.0  # seconds a pose needs to settle (a sit)
var _start := ""  # a tutorial shot to start once the one on screen is over
var _placed := false  # the hero is out of HAB 1 for it, the lens settling
var _speed := 1.0  # Engine.time_scale between pictures (speed=)
var _opening := false  # anim1@s started the real opening
var _still := false  # hold the game still at the moment asked for (anim1@s, a tutorial shot's name@s)


func _ready() -> void:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("speed="):  # software GL under load draws about 1 fps: game seconds per real frame go up
			_speed = float(a.trim_prefix("speed="))
			Engine.time_scale = _speed
		if a.begins_with("hour="):
			game.clock.pinned = true
			game.clock.set_hour(float(a.trim_prefix("hour=")))
			game.clock.refresh()
	cine = game.get("cine")
	if cine == null:
		cine = Cine.new()
		game.add_child(cine)
		cine.setup(game)
	Forge.register(self)


func _process(delta: float) -> void:
	if _still and _want != "" and cine.beat == _want and _since + delta >= _after:
		Engine.time_scale = 0.001  # the moment asked for, held all but still for its picture (anim1@s): 0 would give the
		# walking hero's physics a zero delta to divide by
	_hold = maxf(_hold - delta, 0.0)
	if _start != "" and not cine.busy():  # the shot before it is over: put the hero out, let the lens settle, go
		if not _placed:
			cine.stand_for_dawn()
			game.set_view("default")  # the shot leaves from the play camera, not a preset view shot before it
			if _start == "focus_pip" and game.pip:
				game.pip.order(game.player.body.global_position + Vector3(1.0, 0.0, 6.0), game.player.body.global_position)
			_hold = 2.0
			_placed = true
		elif _hold == 0.0:
			cine.shot(_start)
			_start = ""
			_placed = false
	_since = _since + delta if _want != "" and cine.beat == _want else 0.0


func render_game_to_text() -> Dictionary:
	var s: Dictionary = game.render_game_to_text()
	s.merge(cine.state())
	return s


func busy() -> bool:
	return game.busy() or _hold > 0.0 or _start != "" or (_want != "" and (cine.beat != _want or _since < _after))


const SHOT_AT := {"dawn_reveal": 3.6, "look_around": 3.6, "focus_pip": 1.5}


func set_view(v: String) -> void:
	Engine.time_scale = _speed
	if v.begins_with("anim1@"):  # animation #1 (cine step_out) s seconds in, the real opening playing
		if not _opening:
			_opening = true
			game.beats.start_opening()
		_want = "step_out"
		_after = float(v.get_slice("@", 1))
		_still = true
		return
	if cine.cfg.shots.has(v.get_slice("@", 0)):
		var name := v.get_slice("@", 0)
		if cine.beat != name:
			_start = name
		_still = true
		_want = name
		_after = float(v.get_slice("@", 1)) if "@" in v else float(SHOT_AT[name])
		return
	if "@" in v:
		game.clock.pinned = true
		game.clock.set_hour(float(v.get_slice("@", 1)))
		game.clock.refresh()
		v = v.get_slice("@", 0)
		if v != "sleep_drone":
			game._warm()  # the drone shot keeps its probes, as the lapse holds them
	_want = ""
	var hab: Node3D = game.world.items.hab1
	match v:
		"sleep_drone":
			cine.drone(clampf(fposmod(game.clock.hour() - 22.0, 24.0) / 8.5, 0.0, 1.0))
			cine.cam.make_current()
		"wake":
			cine._seat()
			var w: Array = cine.cfg.sleep.wake_cam
			cine.cam.look_at_from_position(hab.to_global(cine._v(w[0])), hab.to_global(cine._v(w[1])))
			cine.cam.make_current()
			_hold = float(game.player.model.clips.sit_down.length) + 0.5
		"wake_door":
			var player: Node3D = game.player
			player.sit(false)
			var b: Array = cine.cfg.sleep.bench
			var at := hab.to_global(Vector3(b[0] + b[3] * 0.6, cine.cfg.sleep.deck_y, b[2] + b[4] * 0.6))
			var to: Vector3 = hab.to_global(Vector3(cine.cfg.sleep.hatch[0], 0.0, cine.cfg.sleep.hatch[1])) - at
			player.place(at, -rad_to_deg(atan2(-to.x, -to.z)))
			player.cam.pitch = 0.0
			for it: Node in get_tree().get_nodes_in_group("interactable"):
				if it.kind == "door" and hab.is_ancestor_of(it) and not it.open:
					game.interactions.use(it)
			player.cam.lens.make_current()
			_hold = 1.5
		"hatch":  # out of HAB 1's open hatch at eye height, straight along the door's way (the sunrise, since 14 Nov)
			for it: Node in get_tree().get_nodes_in_group("interactable"):
				if it.kind == "door" and hab.is_ancestor_of(it) and not it.open:
					game.interactions.use(it)
			cine.cam.look_at_from_position(hab.to_global(Vector3(0.0, 1.65, -1.2)), hab.to_global(Vector3(0.0, 2.6, -60.0)))
			cine.cam.make_current()
			_hold = 1.5
		"trip_drive", "trip_title":
			if not cine.busy():
				game.player.enter(game.world.items.rover)
				cine.trip_to("lander")  # a field site needs the root net on world.bound(p)
			_want = v
			_after = 2.0 if v == "trip_drive" else 0.5
		"launch_out", "launch_window":
			if not cine.busy():
				cine.launch()
			_want = v
			_after = float(cine.cfg.launch.ignite_s) + 2.5 if v == "launch_out" else float(cine.cfg.launch.window_s) * 0.9
		_:
			game.set_view(v)
