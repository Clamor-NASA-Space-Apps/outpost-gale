extends SceneTree
## The base of a headless test. A test file says `extends "res://addons/forge/test.gd"`, writes `func play() -> bool` ending in `return true`, and runs with
##   godot --headless --path . -s tests/<name>.gd      (prints "N failed", exit 1 on a failure)
## It carries what every such test got wrong once: the 64 x 64 headless window, an error inside an awaited
## start that idles forever, and made-up touches that were kinder than a browser's.
## Load scenes with load() inside play(), never preload: a test compiles before the autoloads a scene names exist.
## `Input.mouse_mode` never changes headless; run that part under xvfb-run.

# A phone in landscape is about 360 CSS px tall, half the 720 px base, so a 48 px target is 96 px in the scene.
const TARGET := 96.0
# Android's back swipe starts within 30 dp of a side edge (AOSP config_backGestureInset): 60 px in the scene.
const EDGE := 60.0
const SHAPES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(2400, 1080)]
enum { DOWN, UP, MOVE }

var failed := 0
var watchdog := 20.0  # seconds; set it in _init() for a longer test
var slots: Array[Vector2] = []  # the web build's "previous position", kept by place in the event, not by finger
var errors := Errors.new()


## Counts the errors the engine reports from scripts and shaders (parse errors included).
class Errors extends Logger:
	var count := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT or error_type == ERROR_TYPE_SHADER:
			count += 1


func _initialize() -> void:
	OS.add_logger(errors)  # here, not in _init(): a test may override _init() to set its watchdog
	await process_frame
	# a script error stops this function for good, and the engine would idle forever
	create_timer(watchdog).timeout.connect(func() -> void:
		print("FAIL  the test stopped half way: read the first error above")
		quit(1))
	slots.resize(8)
	await shape(SHAPES[0])
	# A script error ends play() early and hands control back here as if it had finished: without this
	# a test whose scene failed to load printed "0 failed".
	if await play() != true:
		check(false, "play() did not reach its end: read the first error above")
	# a script that fails to parse leaves its node without behaviour and play() still reaches its end: a broken
	# scene printed "0 failed" (12 Nov run). Script and shader errors fail the test; engine noise does not
	if errors.count:
		check(false, "%d script or shader error(s) during the run: read the first one above" % errors.count)
	print("%d failed" % failed)
	quit(1 if failed else 0)


## The test. End it with `return true`: that is how the base knows it was not cut short.
func play() -> bool:
	return true


func check(ok: bool, what: String) -> bool:
	if not ok:
		failed += 1
		print("FAIL  ", what)
	return ok


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## The window takes a frame to resize, and the headless one starts at 64 x 64, where no touch hits anything.
func shape(size: Vector2i) -> Rect2:
	root.size = size
	await process_frame
	await process_frame
	return root.get_visible_rect()


## One browser touch event as the web build turns it into engine events (4.7.2, display_server_web.cpp):
## `relative` is measured from whatever was last in the same place of the event's list, so with two
## fingers moving in turn it is the distance to the other finger. A game that trusts `relative` passes
## an honest test and fails on a phone. `changed` is [[finger index, position in scene pixels], ...].
func browser(kind: int, changed: Array) -> void:
	for i: int in changed.size():
		var pos: Vector2 = root.get_final_transform() * (changed[i][1] as Vector2)
		if kind == MOVE:
			var d := InputEventScreenDrag.new()
			d.index = changed[i][0]
			d.position = pos
			d.relative = pos - slots[i]
			send(d)
		else:
			var t := InputEventScreenTouch.new()
			t.index = changed[i][0]
			t.position = pos
			t.pressed = kind == DOWN
			send(t)
		slots[i] = pos


func finger(index: int, pos: Vector2, down: bool) -> void:
	browser(DOWN if down else UP, [[index, pos]])


func move(index: int, to: Vector2) -> void:
	browser(MOVE, [[index, to]])


func tap(pos: Vector2) -> void:
	finger(0, pos, true)
	finger(0, pos, false)


func click(pos: Vector2) -> void:
	for down: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = root.get_final_transform() * pos
		e.pressed = down
		send(e)


## A new event each time: the engine warns about one object sent twice in a frame.
func action(name: StringName, down := true) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = down
	send(e)


func send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	Input.flush_buffered_events()  # a button answers with an action event of its own
