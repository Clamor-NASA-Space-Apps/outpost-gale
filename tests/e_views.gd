extends Node3D
## Camera presets round the greenhouse glass and HAB 1's windows (lane E), around the real sandbox (capture-view --scene):
##   node ../../tools/capture-view.mjs . captures/e --scene res://tests/e_views.tscn --views gh_30,gh_6 -- sky=night
## sky=sunset (or night, storm) switches the sky first; a view named "night/gh_6" switches it before that view, so one
## run can take every sky (scratchpad runner: one boot instead of one per sky). "day/coat0:gh_5" also sets the glass
## role's weathering share first (until the next sky switch), to compare the dust film. Any other view name goes to the sandbox (greenhouse_room, gh_eye_a).
##   gh_30 .. gh_2   walking up to the greenhouse's side, eye height, any distance in metres from its centre
##   hab_win, hab_win2, hab_win_in   HAB 1's windows from outside, and out through one from inside

var game: Node3D
var cam := Camera3D.new()

# [item, from, at] in the item's own space (y over its origin), so the shots follow the model
const SHOTS := {
	"hab_win": ["hab1", Vector3(4.5, 1.9, 0.0), Vector3(0, 1.85, 0)],  # window 0 (Blender angle 0: local +X)
	"hab_win2": ["hab1", Vector3(3.4, 1.9, 2.1), Vector3(0, 1.85, 0)],  # window at 328 degrees
	"hab_win_in": ["hab1", Vector3(-0.6, 2.0, 0.0), Vector3(2.5, 1.85, 0)],  # from inside, out through window 0
	"solar": ["", Vector3(12, 6.0, 0), Vector3(45, 0.5, 28)],  # world space, over the ground: tests/c_views.gd solar
	"solar_low": ["", Vector3(44.75, 1.6, 4), Vector3(44.75, 1.4, 40)],
	"solar_near": ["", Vector3(23.6, 1.6, 14), Vector3(26.4, 1.3, 40)],
	"solar_near_b": ["", Vector3(23.6, 1.6, 14.03), Vector3(26.4, 1.3, 40.03)],  # 3 cm over: what crawls as the eye moves
}


func _ready() -> void:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("sky="):
			game._sky(game.SKIES.find("design." + a.trim_prefix("sky=")))
	Forge.register(self)
	cam.fov = 60.0
	cam.far = 8000.0
	add_child(cam)


func render_game_to_text() -> Dictionary:
	return game.render_game_to_text()


func busy() -> bool:
	return game.busy()


func set_view(v: String) -> void:
	if "/" in v:
		var sky: int = game.SKIES.find("design" if v.get_slice("/", 0) == "day" else "design." + v.get_slice("/", 0))
		if sky != game.sky:
			game._sky(sky)
		v = v.get_slice("/", 1)
	if v.begins_with("coat"):  # "coat0.15:gh_5": the glass role's weathering share set for a comparison, then the view
		game.design.materials.glass.weathering = float(v.get_slice(":", 0).trim_prefix("coat"))
		game.design.erase("_roles")
		game._restyle()
		game._warm()
		v = v.get_slice(":", 1)
	var r: Array
	if v.begins_with("gh_") and v.trim_prefix("gh_").is_valid_float():
		# walking up to the greenhouse's side (its own +X, away from the door), eye height
		r = ["greenhouse", Vector3(float(v.trim_prefix("gh_")), 1.6, 0.0), Vector3(0, 1.3, 0)]
	elif SHOTS.has(v):
		r = SHOTS[v]
	else:
		cam.current = false
		game.set_view(v)
		return
	var from: Vector3 = r[1]
	var at: Vector3 = r[2]
	if r[0] == "":
		from.y += game.world.height_at(from.x, from.z)
		at.y += game.world.height_at(at.x, at.z)
	else:
		var item: Node3D = game.world.items[r[0]]
		from = item.to_global(from)
		at = item.to_global(at)
	cam.look_at_from_position(from, at)
	cam.current = true
