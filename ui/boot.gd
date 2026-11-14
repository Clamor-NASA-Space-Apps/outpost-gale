extends Node
## The main scene: up on the first frame, so the window (or the browser tab) answers while the game loads (13 Nov
## playtest: "not responding" from the double-click to the cover; 14 Nov: "Page Unresponsive" in Brave). It shows the
## team's logo and then the start screen (ui/start.gd), reads every model and texture in a slice of each frame under
## them, and puts the sandbox in once all is loaded and the kid has pressed Start. Tests and the tools load
## sandbox.tscn themselves.

const Start := preload("res://ui/start.gd")
const Settings := preload("res://ui/settings.gd")
const SCENE := "res://sandbox/sandbox.tscn"
const FOLDERS := ["res://models/", "res://textures/", "res://data/"]
const KINDS := ["glb", "png", "jpg", "webp", "exr"]

var start := Start.new()
var _go := false  # the kid pressed Start: the sandbox comes in when the loading is done
var _paths: Array[String] = []
var _done := {}  # path -> the loaded resource, held so the cache keeps it until the sandbox has used it


func _ready() -> void:
	var tool := Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--forge-job="))
	# a tool run wants the scene as the tests see it. A browser loads in slices too: the whole base in one frame
	# held the page long enough for Brave to offer to kill it (14 Nov, venue playtest); the start screen takes over
	# from the shell's screen on its first drawn frame (start.gd)
	if tool:
		get_tree().change_scene_to_file.call_deferred(SCENE)
		return
	# full screen unless this device chose a window last time (ui/settings.gd); a phone app is always full screen.
	# A page may go full screen only inside a press (the shell asks on a phone's first touch)
	if not OS.has_feature("web") and Settings.saved().get("full", true):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	start.name = "Start"
	start.started.connect(func() -> void: _go = true)
	add_child(start)
	for dir: String in FOLDERS:
		for f: String in ResourceLoader.list_directory(dir):
			if f.get_extension() in KINDS:
				_paths.append(dir + f)
	_paths.append(SCENE)  # last: the sandbox itself, loaded once its models are in memory


# ponytail: one load at a time on the main thread, within a slice of each frame. Worker-thread loading
# (load_threaded_request) hung the exported build in a later main-thread load (13 Nov, 4.7.2), so no threads.
func _process(_delta: float) -> void:
	# a short slice while the logo's light sweeps: 50 ms of loading in every frame would leave it under 20 frames a second
	var until := Time.get_ticks_msec() + (8 if start.splash else 50)
	while _done.size() < _paths.size() and Time.get_ticks_msec() < until:
		var p: String = _paths[_done.size()]
		_done[p] = load(p)  # held, so the cache keeps it until the sandbox has used it; a failure logs itself
	start.progress(float(_done.size()) / _paths.size())
	if _go and _done.size() == _paths.size():
		set_process(false)
		# the sandbox's _ready builds the world from what is now in memory, under its own cover with the same picture
		var t := Time.get_ticks_msec()
		var game: Node = (_done[SCENE] as PackedScene).instantiate()
		# the frame the sandbox comes in draws no 3D: its build and its first 3D frame (the sky, the probe, the post
		# passes compiling) were one 16 s block on the web, and a browser offers to kill a page that stops that long
		var vp := get_viewport()  # held here: boot is freed before the frame is drawn
		vp.disable_3d = true
		RenderingServer.frame_post_draw.connect(func() -> void: vp.disable_3d = false, CONNECT_ONE_SHOT)
		get_tree().root.add_child(game)
		print_verbose("boot: loaded in %d ms, the sandbox's _ready took %d ms" % [t, Time.get_ticks_msec() - t])
		get_tree().current_scene = game
		queue_free()
