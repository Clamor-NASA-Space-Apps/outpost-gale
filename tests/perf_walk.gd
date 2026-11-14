extends SceneTree
## The same scripted run on any commit, so builds compare (design/research/perf-regression-14nov.md): frame times per
## phase on the real screen, with what the game was doing on each frame (beat, cinematic, room, helmet lamps, fade).
##   godot --path . -s tests/perf_walk.gd -- out=/abs/dir [mode=boot|sandbox] [vsync=1] [win=1] [quick=1|2]
## mode=boot starts through ui/boot.tscn as a player does (the opening plays where it exists); sandbox loads the scene
## alone. quick=1 stops as the cover lifts, quick=2 after the opening. Vsync is asked off, but Wayland always syncs:
## pass --display-driver x11 for a frame's real cost. Profile cold for compiles: MESA_SHADER_CACHE_DISABLE=true and
## user://shader_cache moved away; the cache as the cover lifts is copied to <out>/cache_at_play, and
## tools/shader_cache_list.py diffs it against the end to name what compiled in play.
## Writes frames.csv, summary.txt and new_mats.txt (materials first seen in play).

var out := "/tmp/perf"
var mode := "sandbox"
var game: Node
var phase := "load"
var rows := PackedStringArray()
var last := 0
var stats := {}  # phase -> Array of dt ms


var t_phys := 0  # first physics tick of this frame
var t_pre := 0  # process start
var t_post := 0  # process end
var t_draw0 := 0
var draw_ms := 0.0


class Hook extends Node:
	var fn: Callable
	var physics := false
	func _process(_d: float) -> void:
		if not physics:
			fn.call()
	func _physics_process(_d: float) -> void:
		if physics:
			fn.call()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
		elif a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if "vsync=1" in args else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not "win=1" in args:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var h := Hook.new()
	h.fn = _frame
	h.process_priority = 100000
	root.add_child(h)
	var pre := Hook.new()
	pre.fn = func() -> void: t_pre = Time.get_ticks_usec()
	pre.process_priority = -100000
	root.add_child(pre)
	var ph := Hook.new()
	ph.physics = true
	ph.fn = func() -> void:
		if t_phys == 0:
			t_phys = Time.get_ticks_usec()
	ph.process_physics_priority = -100000
	root.add_child(ph)
	RenderingServer.frame_pre_draw.connect(func() -> void: t_draw0 = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: draw_ms = (Time.get_ticks_usec() - t_draw0) / 1000.0)
	_run.call_deferred()


func _frame() -> void:
	var now := Time.get_ticks_usec()
	if last == 0:
		last = now
		return
	var dt := (now - last) / 1000.0
	last = now
	var phys_ms := (t_pre - t_phys) / 1000.0 if t_phys > 0 else 0.0
	var proc_ms := (now - t_pre) / 1000.0
	t_phys = 0
	var P := Performance
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
	var ctx := ""
	if game:
		var b: Variant = game.get("beats")
		var c: Variant = game.get("cine")
		var pl: Variant = game.get("player")
		ctx = "%s|%s|%s|%s|%.2f" % [b.beat.get("id", "") if b else "", c.beat if c else "", pl.room if pl else "", pl.lamps.on if pl and pl.get("lamps") else "", pl.shown if pl else -1.0]
	rows.append("%s,%.3f,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d" % [ctx, Time.get_unix_time_from_system(), phase, dt, phys_ms, proc_ms, draw_ms, cpu, gpu, P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.OBJECT_NODE_COUNT)])
	if not stats.has(phase):
		stats[phase] = []
	stats[phase].append([dt, gpu, P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func secs(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		if Engine.get_process_frames() % 60 == 0:
			_new_mats()


var seen := {}  # material id -> true, once the cover is gone
var mat_log := PackedStringArray()


## Materials on screen-capable nodes that were not there when play began (a compile in play is one of these, or a
## new light/probe combination of an old one).
func _new_mats() -> void:
	if game == null:
		return
	var first := seen.is_empty()
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		var ms: Array = [g.material_override, g.material_overlay]
		if g is MeshInstance3D and g.mesh:
			for i in g.mesh.get_surface_count():
				ms.append(g.get_active_material(i))
		elif g is MultiMeshInstance3D and g.multimesh and g.multimesh.mesh:
			for i in g.multimesh.mesh.get_surface_count():
				ms.append(g.multimesh.mesh.surface_get_material(i))
		elif g is GPUParticles3D and g.draw_pass_1:
			for i in g.draw_pass_1.get_surface_count():
				ms.append(g.draw_pass_1.surface_get_material(i))
		elif g is Label3D or g is Sprite3D:
			ms.append(g)  # their material is internal
		for m in ms:
			if m == null or seen.has(m.get_instance_id()):
				continue
			seen[m.get_instance_id()] = true
			if not first:
				var what: String = (m.shader.resource_path if m is ShaderMaterial and m.shader else m.get_class())
				mat_log.append("%.3f %s %s %s visible=%s" % [Time.get_unix_time_from_system(), phase, root.get_path_to(g), what, g.is_visible_in_tree()])


func hold(actions: Array, s: float) -> void:
	for a: StringName in actions:
		if InputMap.has_action(a):
			Input.action_press(a)
	await secs(s)
	for a: StringName in actions:
		if InputMap.has_action(a):
			Input.action_release(a)


func _find_game() -> Node:
	for n in root.get_children():
		if n.has_method("busy") and n.get("world") != null:
			return n
	return null


func _run() -> void:
	if mode == "boot":
		change_scene_to_file("res://ui/boot.tscn")
	else:
		root.add_child(load("res://sandbox/sandbox.tscn").instantiate())
	while true:
		await process_frame
		game = _find_game()
		if game and not game.busy():
			break
	phase = "settle"
	_new_mats()
	# what compiled before play: the cache as the cover lifts (diffed against the end, scratchpad cachelist.py)
	OS.execute("cp", ["-r", ProjectSettings.globalize_path("user://shader_cache"), out.path_join("cache_at_play")])
	await secs(2.0)
	if "quick=1" in OS.get_cmdline_user_args():
		_write()
		quit()
		return
	var p: Node = game.get("player")
	if mode == "boot":
		phase = "opening"  # whatever the game does on its own from the start (Sol 1 opening where it exists)
		await secs(25.0)
		if "quick=2" in OS.get_cmdline_user_args():
			_write()
			quit()
			return
	if p.get("allowed") != null:
		p.allowed.clear()  # a lesson may hold the keys; the walk below needs all of them
	phase = "stand"
	await secs(5.0)
	phase = "walk"
	await hold([&"move_forward"], 5.0)
	phase = "walk_turn"
	await hold([&"move_forward", &"look_right"], 6.0)
	phase = "hurry_turn"
	await hold([&"move_forward", &"hurry", &"look_left"], 6.0)
	phase = "look_round"
	await hold([&"look_right"], 6.0)
	phase = "back"
	await hold([&"move_back", &"look_left"], 4.0)
	phase = "sky_skip"  # the debug time-lapse to the next phase, twice, walking
	var clock: Node = game.get("clock")
	Input.action_press(&"move_forward")
	for i in 2:
		if clock:
			clock.skip()
		await secs(6.0)
	Input.action_release(&"move_forward")
	phase = "end"
	var f := FileAccess.open(out.path_join("new_mats.txt"), FileAccess.WRITE)
	f.store_string("
".join(mat_log) + "
")
	f.close()
	_write()
	quit()


func _write() -> void:
	var f := FileAccess.open(out.path_join("frames.csv"), FileAccess.WRITE)
	f.store_string("ctx,unix,phase,dt_ms,phys_ms,proc_ms,prev_draw_ms,render_cpu_ms,gpu_ms,draw_calls,primitives,nodes\n" + "\n".join(rows) + "\n")
	f.close()
	var lines := PackedStringArray(["phase,frames,median_ms,p95_ms,p99_ms,max_ms,over33,over50,gpu_median_ms,draws_median"])
	var all: Array = []
	for ph: String in stats:
		if ph in ["load", "end"]:
			continue
		lines.append(_line(ph, stats[ph]))
		if ph != "settle":
			all.append_array(stats[ph])
	lines.append(_line("ALL(play)", all))
	var s := "\n".join(lines) + "\nadapter=%s screen=%s\n" % [RenderingServer.get_video_adapter_name(), root.get_visible_rect().size]
	print(s)
	f = FileAccess.open(out.path_join("summary.txt"), FileAccess.WRITE)
	f.store_string(s)
	f.close()


func _line(ph: String, a: Array) -> String:
	var dts: Array = a.map(func(r: Array) -> float: return r[0])
	var gp: Array = a.map(func(r: Array) -> float: return r[1])
	var dc: Array = a.map(func(r: Array) -> float: return r[2])
	dts.sort()
	gp.sort()
	dc.sort()
	var n := dts.size()
	var q := func(arr: Array, k: float) -> float: return arr[clampi(int(k * (arr.size() - 1)), 0, arr.size() - 1)]
	return "%s,%d,%.2f,%.2f,%.2f,%.1f,%d,%d,%.2f,%d" % [ph, n, q.call(dts, 0.5), q.call(dts, 0.95), q.call(dts, 0.99),
		dts[-1], dts.filter(func(x: float) -> bool: return x > 33.3).size(), dts.filter(func(x: float) -> bool: return x > 50.0).size(),
		q.call(gp, 0.5), q.call(dc, 0.5)]
