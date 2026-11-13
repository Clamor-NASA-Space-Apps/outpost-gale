extends Node
## The main scene: up on the first frame, so the window answers the desktop while the game loads (13 Nov playtest:
## "not responding" from the double-click to the cover). It draws the splash with a bar, reads every model and
## texture in a slice of each frame, then puts the sandbox in. Tests and the tools load sandbox.tscn themselves.

const Cover := preload("res://ui/cover.gd")
const Settings := preload("res://ui/settings.gd")
const SCENE := "res://sandbox/sandbox.tscn"
const FOLDERS := ["res://models/", "res://textures/", "res://data/"]
const KINDS := ["glb", "png", "jpg", "webp", "exr"]

var cover := Cover.new()
var _paths: Array[String] = []
var _done := {}  # path -> the loaded resource, held so the cache keeps it until the sandbox has used it


func _ready() -> void:
	var tool := Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--forge-job="))
	# the web shell's own screen covers the wait in a browser, and a tool run wants the scene as the tests see it
	if tool or OS.has_feature("web"):
		get_tree().change_scene_to_file.call_deferred(SCENE)
		return
	# full screen unless this device chose a window last time (ui/settings.gd); a phone app is always full screen
	if Settings.saved().get("full", true):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	cover.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	add_child(cover)
	for dir: String in FOLDERS:
		for f: String in ResourceLoader.list_directory(dir):
			if f.get_extension() in KINDS:
				_paths.append(dir + f)
	_paths.append(SCENE)  # last: the sandbox itself, loaded once its models are in memory


# ponytail: one load at a time on the main thread, within a slice of each frame. Worker-thread loading
# (load_threaded_request) hung the exported build in a later main-thread load (13 Nov, 4.7.2), so no threads.
func _process(_delta: float) -> void:
	var until := Time.get_ticks_msec() + 50
	while _done.size() < _paths.size() and Time.get_ticks_msec() < until:
		var p: String = _paths[_done.size()]
		_done[p] = load(p)  # held, so the cache keeps it until the sandbox has used it; a failure logs itself
	var k := float(_done.size()) / _paths.size()
	cover.progress(k)
	cover.line.text = "Loading the base... %d%%" % roundi(100.0 * k)
	if _done.size() == _paths.size():
		set_process(false)
		# the sandbox's _ready builds the world from what is now in memory, under its own cover with the same picture
		var t := Time.get_ticks_msec()
		var game: Node = (_done[SCENE] as PackedScene).instantiate()
		get_tree().root.add_child(game)
		print_verbose("boot: loaded in %d ms, the sandbox's _ready took %d ms" % [t, Time.get_ticks_msec() - t])
		get_tree().current_scene = game
		queue_free()
