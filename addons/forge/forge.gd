extends Node
## The factory's autoload: test hooks for the tools, and the DESIGN.md look.
##
## project.godot:   [autoload]  Forge="*res://addons/forge/forge.gd"
##
## A game registers one object, and tools/capture-view.mjs and tools/feel-probe.mjs drive it:
##   func _ready() -> void: Forge.register(self)
##   func render_game_to_text() -> Dictionary             # required: a snapshot of game state
##   func set_view(view: String) -> void                  # optional: camera to a named preset
##   func place(pos: Vector3, yaw_deg: float) -> void     # optional: put the hero down for a probe row
## Vector3, Vector2 and Color values in the snapshot become arrays in the JSON, so return them as they are.
##
## The look: Forge.HouseStyle.apply(model, design) and Forge.HouseStyle.apply_lighting(self, design).
##
## Without `-- --forge-job=<file>` on the command line this node does nothing, so it can ship in the game.
## The tools start the game with --fixed-fps, which makes every frame one exact step: time is stepped by
## waiting for physics frames, never by a clock.

const HouseStyle := preload("house_style.gd")

var hooks: Object


func register(game: Object) -> void:
	hooks = game


## A .glb from anywhere on disk, for tools that show models the project has not imported.
## Game models live in res:// and load with load() like any scene.
static func load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("could not read %s" % path)
		return null
	return doc.generate_scene(state) as Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--forge-job="):
			process_mode = Node.PROCESS_MODE_ALWAYS
			_run.call_deferred(a.trim_prefix("--forge-job="))


func _run(job_path: String) -> void:
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	var out: String = job.get("out", "captures")
	DirAccess.make_dir_recursive_absolute(out)
	var step_ms := 1000.0 / Engine.physics_ticks_per_second
	var result := {"errors": [], "runs": {}, "views": [], "render": {}, "step_ms": step_ms}
	# the game registers in its own _ready, which can be many frames away while it loads models
	for i in 1200:
		if hooks:
			break
		await get_tree().process_frame
	if hooks == null or not hooks.has_method("render_game_to_text"):
		result.errors.append("the game never called Forge.register(self) with a render_game_to_text() method")
	else:
		await _steps(roundi(float(job.get("advance", 0)) / step_ms))
		for r: Dictionary in job.get("runs", []):
			result.runs[r.id] = await _play(r, out, step_ms, result.errors)
		for v: String in job.get("views", []):
			if hooks.has_method("set_view"):
				hooks.set_view(v)
			await _steps(2)
			if await _shot(out.path_join(v + ".png"), result.errors):
				result.views.append(v)
				# per view: a budget is about what one camera sees, and the last view's count says nothing of the others
				result.render[v] = {
					"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				}
		result.state = _plain(hooks.render_game_to_text())
	var f := FileAccess.open(out.path_join("result.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(result))
	f.close()
	get_tree().quit(1 if result.errors.size() else 0)


func _steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## One probe run: put the hero down, hold and tap inputs per segment, sample the position every step.
## Returns { samples: [[seg, pos, watched]], frames: [png paths] }.
func _play(r: Dictionary, out: String, step_ms: float, errors: Array) -> Dictionary:
	var samples := []
	var frames := []
	var held := {}
	var pos_path: String = r.get("pos", "player.pos")
	var watch: String = r.get("watch", "")
	if r.has("at"):
		if hooks.has_method("place"):
			hooks.place(Vector3(r.at[0], r.at[1], r.at[2]), float(r.get("yaw", 0)))
		else:
			errors.append("%s has `at`, but the game has no place(pos, yaw_deg)" % r.id)
	var shots: Dictionary = r.get("shots", {})
	if shots.has("view") and hooks.has_method("set_view"):
		hooks.set_view(shots.view)
	# a film is about the body: the HUD's buttons in every frame hide it
	var huds := get_tree().root.find_children("*", "CanvasLayer", true, false).filter(func(c: CanvasLayer) -> bool: return shots.has("n") and c.visible)
	for c: CanvasLayer in huds:
		c.hide()
	var sample := func(seg: int) -> void:
		await get_tree().physics_frame
		var s: Dictionary = hooks.render_game_to_text()
		samples.append([seg, _plain(_dig(s, pos_path)), _plain(_dig(s, watch)) if watch else null])
	var segs: Array = r.segs
	for si in segs.size():
		var seg: Dictionary = segs[si]
		var hold: Array = seg.get("hold", [])
		for k: String in held.keys():
			if not hold.has(k):
				_key(k, false)
				held.erase(k)
		for k: String in hold:
			if not held.has(k):
				_key(k, true)
				held[k] = true
		var steps := roundi(float(seg.ms) / step_ms)
		# a tap is down for one step: pressed and released inside one frame, the game can miss it
		var taps: Array = seg.get("tap", []).filter(func(k: String) -> bool: return not held.has(k))
		if taps.size():
			for k: String in taps:
				_key(k, true)
			await sample.call(si)
			for k: String in taps:
				_key(k, false)
			steps -= 1
		if si == int(shots.get("seg", 0)) and shots.has("n"):
			var each := maxi(1, roundi(minf(float(shots.ms), float(seg.ms)) / step_ms / int(shots.n)))
			# a gait is filmed once it is steady, at the end; a jump from its first step, or the film shows the landing
			var lead := 0 if shots.get("start", false) else maxi(0, steps - each * int(shots.n))
			for i in lead:
				await sample.call(si)
			for i in int(shots.n):
				for j in each:
					await sample.call(si)
				var file := out.path_join("%s_%d.png" % [r.id, i])
				if await _shot(file, errors):
					frames.append(file)
			steps = maxi(0, steps - lead - each * int(shots.n))
		for i in steps:
			await sample.call(si)
	for k: String in held.keys():
		_key(k, false)
	if shots.has("view") and hooks.has_method("set_view"):
		hooks.set_view("default")  # or every later row is measured through the film's camera
	for c: CanvasLayer in huds:
		c.show()
	return {"samples": samples, "frames": frames}


## An input action by name, else a key by its Godot name ("W", "Shift", "Space"), so the input map is tested too.
func _key(key: String, down: bool) -> void:
	if InputMap.has_action(key):
		var a := InputEventAction.new()
		a.action = key
		a.pressed = down
		Input.parse_input_event(a)
		return
	var e := InputEventKey.new()
	e.keycode = OS.find_keycode_from_string(key)
	e.physical_keycode = e.keycode
	e.pressed = down
	Input.parse_input_event(e)


func _shot(file: String, errors: Array) -> bool:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex else null
	if img == null or img.is_empty():
		errors.append("no picture for %s: --headless does not draw, the tools start a display for views and films" % file)
		return false
	img.save_png(file)
	return true


static func _dig(d: Variant, path: String) -> Variant:
	for k in path.split("."):
		if d is Dictionary and d.has(k):
			d = d[k]
		else:
			return null
	return d


## Engine types to plain JSON values, all the way down.
static func _plain(v: Variant) -> Variant:
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Vector2:
		return [v.x, v.y]
	if v is Color:
		return "#" + v.to_html(false)
	if v is Dictionary:
		var d := {}
		for k: Variant in v:
			d[str(k)] = _plain(v[k])
		return d
	if v is Array or v is PackedStringArray or v is PackedFloat32Array or v is PackedInt32Array or v is PackedVector3Array:
		var a := []
		for x: Variant in v:
			a.append(_plain(x))
		return a
	if v is StringName:
		return String(v)
	return v
