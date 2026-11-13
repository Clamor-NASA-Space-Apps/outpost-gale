extends Node3D
## Pictures of the cinematics around the real sandbox, for Ravindu (capture-view --scene), until the root wires them:
##   node ../../tools/capture-view.mjs . captures/cine_sleep --scene res://cine/cine_views.tscn --scale 0.5 --views sleep_drone@22,sleep_drone@2,sleep_drone@5,sleep_drone@6.3,wake@6.4,wake_door@6.4
##   node ../../tools/capture-view.mjs . captures/cine_trip --scene res://cine/cine_views.tscn --scale 0.5 --views trip_drive,trip_title -- hour=11
##   node ../../tools/capture-view.mjs . captures/cine_launch --scene res://cine/cine_views.tscn --scale 0.5 --views launch_out,launch_window -- hour=20.5
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


func _ready() -> void:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	for a in OS.get_cmdline_user_args():
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
	_hold = maxf(_hold - delta, 0.0)
	_since = _since + delta if _want != "" and cine.shot == _want else 0.0


func render_game_to_text() -> Dictionary:
	var s: Dictionary = game.render_game_to_text()
	s.merge(cine.state())
	return s


func busy() -> bool:
	return game.busy() or _hold > 0.0 or (_want != "" and (cine.shot != _want or _since < _after))


func set_view(v: String) -> void:
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
