extends RefCounted
## The morning checkpoint: one JSON file in user://. The root writes it each time a night's sleep starts a new sol's
## beats (sandbox.gd checkpoint()), the start screen reads it for its Continue row (ui/start.gd), and the root takes
## it back in place of the opening (sandbox.gd _resume()). It holds the sol, the rules, the handbook and the root's
## few flags that last across days; nothing of the world's loose things, so a Continue is a fresh morning.

const VERSION := 1  # raise it when a checkpoint's shape changes: an older file is then ignored, never half read

# As ui/settings.gd: "" until first asked, user://save.json in the game, "-" (none) in a test or tool run, so a check
# never reads or overwrites a player's mission. A test that checks saving sets its own file first.
static var file := ""
# "Try this sol again" (sandbox.gd _restart()): the checkpoint the scene's next start takes, as Continue's from boot
static var pending := {}


static func _path() -> String:
	if file == "":
		var tool := Engine.get_main_loop().get_script() != null or Array(OS.get_cmdline_user_args()).any(
			func(a: String) -> bool: return a.begins_with("--forge-job="))
		file = "-" if tool else "user://save.json"
	return file


## The checkpoint, or {} when there is none this build can use: no file, broken JSON, another version, a sol the
## story does not have. Never an error: the menu then has no Continue row.
static func read() -> Dictionary:
	if _path() == "-" or not FileAccess.file_exists(_path()):
		return {}
	var j := JSON.new()  # its parse() fails quietly; JSON.parse_string() logs an error on a broken file
	if j.parse(FileAccess.get_file_as_string(_path())) != OK or not j.data is Dictionary:
		return {}
	var d: Dictionary = j.data
	var sols: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sols.json"))
	if not (d.get("version") is float and int(d.version) == VERSION and d.get("sol") is float and sols.has(str(int(d.sol)))
			and d.get("sim") is String and d.get("handbook") is Dictionary):
		return {}
	d.sim = Marshalls.base64_to_variant(d.sim)
	return d if d.sim is Dictionary else {}


## One write. A failure is ignored: a private browser window has no storage, and the game goes on with no Continue.
## The rules go in as bytes (base64), the rest as plain JSON: a JSON number does not come back exact (sim.gd save()).
static func write(d: Dictionary) -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE) if _path() != "-" else null
	if f:
		f.store_string(JSON.stringify(d.merged({"sim": Marshalls.variant_to_base64(d.sim)}, true), "\t", false))
