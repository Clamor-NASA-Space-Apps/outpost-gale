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
var _last := Time.get_ticks_msec()  # the frame before this one, for the --verbose frame log
var _second := Time.get_ticks_msec()
var _frames := 0
var _worst := 0
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
	# a short slice while the logo's light sweeps and while the kid is on the menu: 50 ms of loading in every frame
	# left it under 20 frames a second, and the rows answered late (14 Nov playtest: "it took some time for us to
	# change them"). The long slice only once Start is pressed and there is nothing left to answer
	var until := Time.get_ticks_msec() + (50 if _go else 8)
	while _done.size() < _paths.size() and Time.get_ticks_msec() < until:
		var p: String = _paths[_done.size()]
		var t0 := Time.get_ticks_msec()
		_done[p] = load(p)  # held, so the cache keeps it until the sandbox has used it; a failure logs itself
		if Time.get_ticks_msec() - t0 > 30:
			print_verbose("boot: %s took %d ms to load" % [p, Time.get_ticks_msec() - t0])  # one load no slice can cut
	# with --verbose: how the screens ran while the base loaded (frames in each second, and the longest one)
	var now := Time.get_ticks_msec()
	_worst = maxi(_worst, now - _last)
	_last = now
	_frames += 1
	if now - _second >= 1000:
		print_verbose("boot: %d frames in the last second, the longest %d ms, %d of %d loaded" % [_frames, _worst, _done.size(), _paths.size()])
		_second = now
		_frames = 0
		_worst = 0
	start.progress(float(_done.size()) / _paths.size())
	if _go and _done.size() == _paths.size():
		set_process(false)
		# the sandbox's _ready builds the world from what is now in memory, under its own cover with the same picture
		var t := Time.get_ticks_msec()
		var game: Node = (_done[SCENE] as PackedScene).instantiate()
		game.set("resume", start.resume)  # Continue's checkpoint, or nothing: Sol 1's opening (sandbox.gd _wire())
		# the frame the sandbox comes in draws no 3D: its build and its first 3D frame (the sky, the probe, the post
		# passes compiling) were one 16 s block on the web, and a browser offers to kill a page that stops that long
		var vp := get_viewport()  # held here: boot is freed before the frame is drawn
		vp.disable_3d = true
		RenderingServer.frame_post_draw.connect(func() -> void: vp.disable_3d = false, CONNECT_ONE_SHOT)
		get_tree().root.add_child(game)
		print_verbose("boot: loaded in %d ms, the sandbox's _ready took %d ms" % [t, Time.get_ticks_msec() - t])
		get_tree().current_scene = game
		queue_free()
