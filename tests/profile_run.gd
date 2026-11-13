extends "res://addons/forge/test.gd"
## Frame profile of a scripted play route on the real screen: one CSV row per drawn frame, tagged with what the
## route and the game did on it, then direct timings of the suspect calls. Not a pass/fail test.
##   nice -n 5 taskset -c 2-7 godot --path . -s tests/profile_run.gd -- out=/abs/dir [passes=2] [max=1] [vsync=1]
## sweep=1 adds a GPU sweep at the spawn view: the high preset with one knob changed at a time, or one layer hidden
## (<out>/sweep.csv: median GPU and frame ms over 120 frames). The renderer's GPU timer works in Compatibility.
## Never --headless (nothing is drawn) and never --fixed-fps (frame time is the measurement). Vsync is off unless
## vsync=1, so a frame shows its real cost, not the screen's 16.7 ms. max=1 maximises the window.
## Writes <out>/frames.csv, <out>/bench.csv and <out>/meta.txt. Physics ticks are timed apart: `ph_script_ms` is
## every _physics_process of the frame's ticks, `ph_tail_ms` the scene tree after them, `ph_step_ms` the engine step.
## The `mon_process_ms` and `mon_physics_ms` monitors are the worst in the last second, not this frame's (4.7.2).
## `render_gpu_ms` is the GL timer of a recent frame; a rare value over 1000 is a bad read, drop it.
## Temporary timing in game code goes in Engine meta "prof" ({name: usec}); the `extra` column lists it per frame.

const HouseStyle := preload("res://addons/forge/house_style.gd")  # the Forge autoload is unknown while a test compiles

var game: Node3D
var skies: Array
var world: Node3D
var player: Node3D
var box: Node3D
var out_dir := "user://profile"
var passes := 2

var rows := PackedStringArray()
var phase := "load"
var pass_no := 0
var tags: Array[String] = []
var last_pre := 0
var pre_at := 0
var last_phys := 0
var trail_up_ms := 0.0
var contacts := -1
var trail_centre := Vector2.ZERO
var shown := 1.0
var live := 0
var streams := 0
var sys := {"cpu_mhz": 0.0, "gpu_mhz": 0.0, "pkg_c": 0.0}
var frame := 0
var t0 := 0
var hooks: Array[Node] = []
var ph_at := 0
var ph_script := 0
var ph_end := 0
var ph_tail := 0  # after the scripts, before the engine step: transform flush, timers, tweens, deferred calls
var step_from := 0
var ph_step := 0  # the engine step (Jolt), up to the next tick or the frame's process


class Hook extends Node:
	var fn: Callable
	var physics := false
	func _process(_d: float) -> void:
		if not physics:
			fn.call()
	func _physics_process(_d: float) -> void:
		if physics:
			fn.call()


func _init() -> void:
	watchdog = 900.0


func play() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.trim_prefix("out=")
		elif a.begins_with("passes="):
			passes = int(a.trim_prefix("passes="))
		elif a == "max=1":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var vsync := "vsync=1" in OS.get_cmdline_user_args()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var t_load := Time.get_ticks_usec()
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	t_load = Time.get_ticks_usec() - t_load
	world = game.world
	skies = game.get_script().get_script_constant_map().SKIES
	player = game.player
	box = game.interactions
	player.footstep.connect(func(_p: Vector3, _y: float, _f: String) -> void: tag("step"))
	box.used.connect(func(what: String, _p: Vector3) -> void: tag("use_" + what))
	world.sound.connect(func(what: String, _p: Vector3) -> void: tag("snd_" + what))
	var pre := Hook.new()
	pre.fn = _pre
	pre.process_priority = -100000
	root.add_child(pre)
	var post := Hook.new()
	post.fn = _post
	post.process_priority = 100000
	root.add_child(post)
	var ph_pre := Hook.new()
	ph_pre.physics = true
	ph_pre.fn = func() -> void:
		ph_at = Time.get_ticks_usec()
		_close_step(ph_at)
	ph_pre.process_physics_priority = -100000
	root.add_child(ph_pre)
	var ph_post := Hook.new()
	ph_post.physics = true
	ph_post.fn = func() -> void:
		ph_end = Time.get_ticks_usec()
		ph_script += ph_end - ph_at
		_tail.call_deferred()
	ph_post.process_physics_priority = 100000
	root.add_child(ph_post)
	hooks = [pre, post, ph_pre, ph_post]
	Engine.set_meta("prof", {})
	contacts = world._drawn.hash()
	trail_centre = world.terrain.trail_centre
	t0 = Time.get_ticks_usec()
	last_pre = t0

	for p in passes:
		pass_no = p + 1
		await route()
	if "sweep=1" in OS.get_cmdline_user_args():
		_write("sweep.csv", "\n".join(await sweep()) + "\n")
	phase = "bench"
	var bench := await benchmarks()
	var meta := "load_ms=%.0f\nwindow=%s\nvsync=%s\nrenderer=%s\nadapter=%s\ngpu_time_ms_seen=%s\n" % [t_load / 1000.0,
		root.get_visible_rect().size, vsync, RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name(), RenderingServer.viewport_get_measured_render_time_gpu(vp)]
	_write("frames.csv", "frame,t_s,pass,phase,quality,sky,dt_ms,proc_ms,phys_steps,mon_process_ms,mon_physics_ms,render_cpu_ms,render_gpu_ms,draw_calls,objects,primitives,obj_count,nodes,orphans,mem_static_mb,tex_mb,vid_mb,trail_up_ms,cpu_mhz,gpu_mhz,pkg_c,gait,ph_script_ms,ph_tail_ms,ph_step_ms,tags,extra\n" + "\n".join(rows) + "\n")
	_write("bench.csv", "call,n,mean_ms,max_ms\n" + "\n".join(bench) + "\n")
	_write("meta.txt", meta)
	print("profile written to ", out_dir)
	for h in hooks:
		h.queue_free()
	game.queue_free()
	Engine.remove_meta("prof")
	await frames(2)
	return true


## The first message-queue flush after the physics scripts: what ran since them is the scene tree's tail.
func _tail() -> void:
	step_from = Time.get_ticks_usec()
	ph_tail += step_from - ph_end


func _close_step(now: int) -> void:
	if step_from > 0:
		ph_step += now - step_from
		step_from = 0


func tag(t: String) -> void:
	tags.append(t)


## Runs first in every frame's process step: closes the previous frame's row (its dt runs from the last pre
## to this one, so it holds that frame's process, its render, and this frame's physics), then takes over the
## trail map's upload so its cost is timed.
func _pre() -> void:
	var now := Time.get_ticks_usec()
	_close_step(now)
	var t: Node3D = world.terrain
	if t.trail_centre != trail_centre:
		trail_centre = t.trail_centre
		tag("trail_move")
	trail_up_ms = 0.0
	if t.trail_dirty:
		var s := Time.get_ticks_usec()
		t._upload()
		trail_up_ms = (Time.get_ticks_usec() - s) / 1000.0
		tag("trail_up")
	_check_contacts("contacts_phys")
	if game.cover.visible:
		tag("cover")  # a shader warm-up behind the cover (sandbox _warm()): its long frames are hidden
	pre_at = now


## Runs last in the process step: reads the monitors and writes the row of this frame.
func _post() -> void:
	_check_contacts("contacts_proc")
	var now := Time.get_ticks_usec()
	var dt := (pre_at - last_pre) / 1000.0
	last_pre = pre_at
	var phys := Engine.get_physics_frames()
	var steps := phys - last_phys
	last_phys = phys
	var d: Node3D = world.dust
	if d._live.size() > live:
		tag("puff")
	live = d._live.size()
	if d._streams.size() != streams:
		tag("stream_new")
	streams = d._streams.size()
	if player.shown != shown:
		tag("hero_fade_%.2f" % player.shown)
	shown = player.shown
	frame += 1
	if frame % 30 == 0:
		_sys()
	var vp := root.get_viewport_rid()
	var P := Performance
	rows.append("%d,%.3f,%d,%s,%s,%s,%.3f,%.3f,%d,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d,%d,%.1f,%.1f,%.1f,%.3f,%.0f,%.0f,%.1f,%s,%.3f,%.3f,%.3f,%s,%s" % [
		frame, (now - t0) / 1e6, pass_no, phase, game.quality, skies[game.sky], dt, (now - pre_at) / 1000.0, steps,
		P.get_monitor(P.TIME_PROCESS) * 1000.0, P.get_monitor(P.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
		P.get_monitor(P.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), P.get_monitor(P.RENDER_TOTAL_OBJECTS_IN_FRAME),
		P.get_monitor(P.RENDER_TOTAL_PRIMITIVES_IN_FRAME), P.get_monitor(P.OBJECT_COUNT), P.get_monitor(P.OBJECT_NODE_COUNT),
		P.get_monitor(P.OBJECT_ORPHAN_NODE_COUNT), P.get_monitor(P.MEMORY_STATIC) / 1048576.0,
		P.get_monitor(P.RENDER_TEXTURE_MEM_USED) / 1048576.0, P.get_monitor(P.RENDER_VIDEO_MEM_USED) / 1048576.0,
		trail_up_ms, sys.cpu_mhz, sys.gpu_mhz, sys.pkg_c, player.gait, ph_script / 1000.0, ph_tail / 1000.0, ph_step / 1000.0, "+".join(tags), _extra()])
	tags.clear()
	ph_script = 0
	ph_tail = 0
	ph_step = 0


func _extra() -> String:
	var acc: Dictionary = Engine.get_meta("prof")
	var parts := PackedStringArray()
	for k: String in acc:
		parts.append("%s=%.3f" % [k, acc[k] / 1000.0])
	acc.clear()
	return ";".join(parts)


func _check_contacts(what: String) -> void:
	var c: int = world._drawn.hash()  # the carriables drawn into the contact map, redrawn on a change
	if c != contacts:
		contacts = c
		tag(what)


## CPU clock (mean of the cores), GPU clock and package temperature, from sysfs (Linux only, else zeros).
func _sys() -> void:
	var sum := 0.0
	var n := 0
	for i in 8:
		var f := "/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq" % i
		if FileAccess.file_exists(f):
			sum += float(FileAccess.get_file_as_string(f))
			n += 1
	sys.cpu_mhz = sum / maxi(n, 1) / 1000.0
	sys.gpu_mhz = float(FileAccess.get_file_as_string("/sys/class/drm/card1/gt_act_freq_mhz")) if FileAccess.file_exists("/sys/class/drm/card1/gt_act_freq_mhz") else 0.0
	for z in 8:
		var base := "/sys/class/thermal/thermal_zone%d/" % z
		if FileAccess.file_exists(base + "type") and FileAccess.get_file_as_string(base + "type").strip_edges() == "x86_pkg_temp":
			sys.pkg_c = float(FileAccess.get_file_as_string(base + "temp")) / 1000.0


func _write(file: String, text: String) -> void:
	var f := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func secs(s: float) -> void:
	await frames(int(s * Engine.physics_ticks_per_second))


func hold(actions: Array, s: float) -> void:
	for a: StringName in actions:
		action(a, true)
	await secs(s)
	for a: StringName in actions:
		action(a, false)


func press(a: StringName, what: String) -> void:
	tag(what)
	action(a, true)
	await frames(1)
	action(a, false)


## Stands the hero a metre off the first interactable of `kind` (and `thing`, if named), facing the nearest point of
## its shape, and returns it (interact_test.gd's face()): off a door's or a panel row's face, at the rover's hatch,
## beside a bag.
func face(kind: String, thing := "") -> Node3D:
	for it: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if it.kind == kind and (thing == "" or str(it.thing.name) == thing):
			var s: AABB = it.shape
			var n := Vector3.AXIS_X if s.size.x < s.size.z else Vector3.AXIS_Z
			var off: Vector3 = (it.thing.global_basis[n] * Vector3(1, 0, 1)).normalized() * (s.size[n] / 2.0 + 1.0)
			var from: Vector3 = it.thing.exit_point() if kind == "rover" else it.middle() + (off if kind != "bag" else Vector3(0.7, 0, 0.7))
			var to: Vector3 = it.nearest(from + Vector3.UP * box.hold) - from
			game.place(Vector3(from.x, 0, from.z), rad_to_deg(atan2(to.x, -to.z)))
			return it
	return null


## Uses `it` through the interact key, or directly if the hero's finder did not pick it (still one use).
func use(it: Node3D, what: String) -> void:
	await frames(3)
	tag(what)
	if box.target == it:
		action(&"interact", true)
		await frames(1)
		action(&"interact", false)
	else:
		tag("direct")
		box.use(it)
		await frames(1)


func route() -> void:
	game.place(world.landmark("spawn").pos, world.landmark("spawn").yaw)
	phase = "stand"
	await secs(5)
	phase = "walk"
	await hold([&"move_forward"], 4)
	await hold([&"move_forward", &"move_right"], 4)
	await hold([&"move_forward"], 4)
	phase = "hurry"
	await hold([&"move_forward", &"hurry"], 4)
	await hold([&"move_forward", &"hurry", &"move_left"], 4)
	await hold([&"move_forward", &"hurry"], 4)
	phase = "hop"
	action(&"move_forward", true)
	for i in 4:
		await press(&"jump", "jump")
		await secs(1.5)
	action(&"move_forward", false)
	phase = "shadow_off"  # a walk with the sun's shadow off, then on again, same route
	var sun: DirectionalLight3D = null
	for n in game.get_children():
		if n is DirectionalLight3D and n.has_meta("house_rig"):
			sun = n
	game.place(world.landmark("spawn").pos, world.landmark("spawn").yaw)
	await secs(0.5)
	if sun:
		sun.shadow_enabled = false
		await _warmed()  # the game turns shadows off only through a quality preset, which warms its shaders
	await hold([&"move_forward", &"move_right"], 5)
	phase = "shadow_on"
	if sun:
		sun.shadow_enabled = true
		await _warmed()
	game.place(world.landmark("spawn").pos, world.landmark("spawn").yaw)
	await secs(0.5)
	await hold([&"move_forward", &"move_right"], 5)
	phase = "carry"
	var bag := face("bag", "bag1")
	await use(bag, "pick_up")
	await hold([&"move_forward"], 3)
	await press(&"interact", "put_down")
	await secs(2)
	phase = "door"
	var door := face("door")
	await use(door, "door_open")
	await secs(1)
	var hab: Node3D = world.items.hab1
	var to: Vector3 = hab.global_position - player.body.global_position
	game.place(player.body.global_position, rad_to_deg(atan2(to.x, -to.z)))
	await hold([&"move_forward"], 3)
	await secs(1)
	await hold([&"move_back"], 4)
	door = face("door")
	await use(door, "door_close")
	await secs(1)
	phase = "sky"
	action(&"move_forward", true)
	for i in 4:
		await press(&"debug_sky", "sky")
		await secs(3)
	action(&"move_forward", false)
	phase = "quality"
	action(&"move_forward", true)
	for i in 3:
		await press(&"debug_quality", "quality")
		await secs(4)
	action(&"move_forward", false)
	phase = "rover"
	var rover := face("rover")
	await use(rover, "enter")
	await hold([&"move_forward", &"hurry", &"move_left"], 9)
	await hold([&"move_forward", &"hurry"], 11)
	await secs(1)
	await press(&"interact", "exit")
	await secs(2)


## The game's warm-up after a change the route made by hand, waited out (the frames are tagged `cover`).
func _warmed() -> void:
	game._warm()
	while game.busy():
		await process_frame


## Every preset, then one knob at a time from the gaming preset, at the play camera over the base; vsync off reads best.
func sweep() -> PackedStringArray:
	phase = "sweep"
	var out := PackedStringArray(["knob,gpu_median_ms,gpu_p90_ms,frame_median_ms,draw_calls,primitives"])
	var env: Environment = null
	for n in game.get_children():
		if n is WorldEnvironment and n.has_meta("house_rig"):
			env = n.environment
	var q: Dictionary = game.design.quality
	var knobs: Array = []
	for level: String in q:
		knobs.append([level + " preset", level, null])
	for change: Array in [["msaa", 0], ["msaa", 2], ["scale", 0.75], ["scale", 0.5], ["shadows", 0], ["shadows", 1],
			["shadowMap", 2048], ["shadowMap", 1024], ["shadowFilter", 0], ["shadowFilter", 2], ["glow", 0],
			["detail", "code"], ["detail", "off"], ["aniso", 0], ["aniso", 1], ["aniso", 3], ["ground", "cheap"],
			["ground", "flat"], ["pixels", 0.6], ["pixels", 1.0], ["pixels", 1.4], ["particles", 0.5], ["msaa", 8],
			["shadows", 4], ["shadowFilter", 5], ["ssao", true], ["aniso", 4]]:
		var k: Dictionary = q.gaming.duplicate()
		k[change[0]] = change[1]
		q["sweep"] = k
		knobs.append(["gaming, %s=%s" % change, "sweep", null])
		knobs[-1][2] = k
	var hide := {"terrain hidden": world.terrain, "dust hidden": world.dust, "rocks hidden": world.rocks,
		"hero hidden": player.model}
	for name: String in hide:
		knobs.append([name, "gaming", hide[name]])
	knobs.append(["base cells hidden", "gaming", "cells"])
	knobs.append(["fog off", "gaming", "fog"])
	knobs.append(["sky off (clear colour)", "gaming", "sky"])
	knobs.append(["ground detail_strength 0", "gaming", "ground"])
	game.place(world.landmark("spawn").pos, world.landmark("spawn").yaw)
	await secs(3)
	var vp := root.get_viewport_rid()
	for k: Array in knobs:
		if k[1] == "sweep":
			q["sweep"] = k[2]
		HouseStyle.set_quality(game, game.design, k[1])
		game._restyle()  # the world's own knobs (ground, trail, particles)
		var what: Variant = k[2]
		var mode: String = what if what is String else ""
		if what is Node3D:
			(what as Node3D).visible = false
		elif mode == "cells":
			for c: Node3D in world._cells:
				c.visible = false
		elif mode == "fog" and env:
			env.fog_enabled = false
		elif mode == "sky" and env:
			env.background_mode = Environment.BG_COLOR
		elif mode == "ground":
			world.terrain.material.set_shader_parameter("detail_strength", 0.0)
		tag("sweep:" + k[0])
		for i in 60:
			await process_frame
		var gpu: Array[float] = []
		var dts: Array[float] = []
		var last := Time.get_ticks_usec()
		for i in 120:
			await process_frame
			var now := Time.get_ticks_usec()
			dts.append((now - last) / 1000.0)
			last = now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		gpu.sort()
		dts.sort()
		out.append("\"%s\",%.2f,%.2f,%.2f,%d,%d" % [k[0], gpu[60], gpu[108], dts[60],
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		if what is Node3D:
			(what as Node3D).visible = true
		elif mode == "cells":
			for c: Node3D in world._cells:
				c.visible = true
		elif mode == "fog" and env:
			env.fog_enabled = true
		elif mode == "sky" and env:
			env.background_mode = Environment.BG_SKY
		elif mode == "ground":
			world.terrain.material.set_shader_parameter("detail_strength", 1.0)
	q.erase("sweep")
	HouseStyle.set_quality(game, game.design, "gaming")
	game._restyle()
	return out


## Direct timings of the suspect calls, each on the warm game: [call, n, mean ms, max ms].
func benchmarks() -> PackedStringArray:
	var out := PackedStringArray()
	var t: Node3D = world.terrain
	var hero: Vector3 = player.body.global_position
	out.append(_time("terrain.mark foot (CPU loop)", 50, func() -> void: t.mark(hero, 0.0, "foot_l")))
	out.append(_time("terrain.mark wheel (CPU loop)", 50, func() -> void: t.mark(hero, 0.0, "wheel", 0.3)))
	out.append(_time("terrain._upload (changed tiles)", 10, func() -> void: t.mark(hero, 0.0, "foot_l"); t._upload()))
	out.append(_time("terrain._move_trail", 3, func() -> void: t._move_trail(t.trail_centre + Vector2(20, 0))))
	out.append(_time("world._contacts() full redraw (load only; a bag redraws its spot)", 3, func() -> void: world._contacts()))
	out.append(_time("world.puff foot", 20, func() -> void: world.puff(hero, Vector3(1, 0, 0), 0.3, "foot")))
	out.append(_time("world.touch + movers", 50, _touch.bind(hero)))
	world._touch.erase(self)
	out.append(_time("world.wheel_rest", 100, func() -> void: world.wheel_rest(hero.x, hero.z, 0.5, 0.55)))
	var rv: Node3D = world.items.rover
	out.append(_time("rover._pose (6 wheels + belly)", 50, func() -> void: rv._pose(rv.global_position, rv.yaw)))
	out.append(_time("audio._one_shot", 10, func() -> void: game.audio._one_shot("chirp", "UI", -80.0)))
	out.append(_time("world.restyle(design)", 3, func() -> void: world.restyle(game.design)))
	out.append(_time("player.restyle(design)", 3, func() -> void: player.restyle(game.design)))
	out.append(_time("HouseStyle.set_quality(gaming)", 3, func() -> void: HouseStyle.set_quality(game, game.design, "gaming")))
	out.append(_time("HouseStyle.apply_lighting", 3, func() -> void: HouseStyle.apply_lighting(game, game.design)))
	out.append(_time("render_game_to_text", 5, func() -> void: game.render_game_to_text()))
	await frames(5)
	return out


func _touch(hero: Vector3) -> void:
	world.touch(self, PackedVector4Array([Vector4(hero.x, hero.z, 0.5, 0.9)]))
	world._process(0.0)


func _time(what: String, n: int, fn: Callable) -> String:
	var total := 0.0
	var worst := 0.0
	for i in n:
		var s := Time.get_ticks_usec()
		fn.call()
		var ms := (Time.get_ticks_usec() - s) / 1000.0
		total += ms
		worst = maxf(worst, ms)
	return "\"%s\",%d,%.3f,%.3f" % [what, n, total / n, worst]
