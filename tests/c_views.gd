extends Node3D
## Camera presets for the edge of the ground, the wing field and Mont Mercou, around the real sandbox (capture-view --scene):
##   node ../../tools/capture-view.mjs . captures/c --scene res://tests/c_views.tscn --views edge,edge_far,solar,mercou -- sky=sunset
## sky=sunset (or night, storm) switches the sky first; knob=name:value sets one graphics knob (knob=shadows:0). Views (eye height is 1.6 m over the ground at `from`):
##   edge      at the east boundary (x 190) looking out over the patch's end, where it meets the backdrop
##   edge_n    at the north boundary looking along it, the seam running across the frame
##   edge_far  from 60 m inside, a little up, looking at the edge and the skyline past it
##   edge_sw   at the south-west corner, where the backdrop stood highest over the patch's edge (2.3 m)
##   edge_low  knee height at the boundary looking out: the seam closest to the eye
##   solar, solar_low, solar_end   the wing field from the base side, from between two rows, along a row
##   solar_a, solar_b  one view 3 cm apart, to diff: thin parts that alias shimmer between them
##   solar_near, solar_near_b  beside the first row looking along it, 3 cm apart: where a walker saw the "tear"
##   solar_edge  a row's long edge from about a metre
##   mercou, mercou_w, mercou_n, mercou_low  the butte from the base, the far side, the north, and low at its foot

var game: Node3D
var cam := Camera3D.new()

const SHOTS := {
	# [from, at]: x, z in metres; y over the ground at that spot
	"edge": [Vector3(189, 1.6, 10), Vector3(230, -2.0, 14)],
	"edge_n": [Vector3(20, 1.6, -189), Vector3(80, 0.0, -199)],
	"edge_far": [Vector3(130, 6.0, -30), Vector3(210, 0.0, 0)],
	"edge_sw": [Vector3(-188, 1.6, 186), Vector3(-215, -1.0, 205)],
	"edge_low": [Vector3(189.5, 0.4, -40), Vector3(205, -0.6, -36)],
	"solar": [Vector3(12, 6.0, 0), Vector3(45, 0.5, 28)],
	"solar_low": [Vector3(44.75, 1.6, 4), Vector3(44.75, 1.4, 40)],
	"solar_end": [Vector3(76, 2.2, 54), Vector3(40, 1.0, 22)],
	"solar_a": [Vector3(18, 1.7, 30), Vector3(60, 1.2, 26)],  # solar_a and _b 3 cm apart: what shimmers as the eye moves
	"solar_b": [Vector3(18, 1.7, 30.03), Vector3(60, 1.2, 26.03)],
	"solar_near": [Vector3(23.6, 1.6, 14), Vector3(26.4, 1.3, 40)],  # walking beside the first row, the face grazing
	"solar_near_b": [Vector3(23.6, 1.6, 14.03), Vector3(26.4, 1.3, 40.03)],
	"solar_edge": [Vector3(24.3, 1.5, 17), Vector3(24.8, 1.5, 21)],  # a panel's long edge from 1 m: rail, backsheet, glass
	"mercou": [Vector3(-22, 2.0, 20), Vector3(-40, 1.5, 38)],
	"mercou_w": [Vector3(-62, 2.5, 58), Vector3(-40, 1.0, 38)],
	"mercou_low": [Vector3(-24, 0.6, 28), Vector3(-34, 0.3, 36)],
	"mercou_n": [Vector3(-56, 2.0, 18), Vector3(-40, 1.0, 38)],
}


func _ready() -> void:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("sky="):
			game._sky(game.SKIES.find("design." + a.trim_prefix("sky=")))
		elif a.begins_with("knob="):  # knob=shadows:0, to tell a shadow artefact from a model one
			var kv := a.trim_prefix("knob=").split(":")
			game.set_graphics(game.quality, {kv[0]: str_to_var(kv[1])})
	Forge.register(self)
	cam.fov = 60.0
	cam.far = 8000.0
	add_child(cam)


func render_game_to_text() -> Dictionary:
	var s: Dictionary = game.render_game_to_text()
	s["machines"] = game.world.machines.state()
	return s


func busy() -> bool:
	return game.busy()


func set_view(v: String) -> void:
	if not SHOTS.has(v):
		game.set_view(v)
		return
	var from: Vector3 = SHOTS[v][0]
	var at: Vector3 = SHOTS[v][1]
	from.y += game.world.height_at(from.x, from.z)
	at.y += game.world.height_at(at.x, at.z)
	cam.look_at_from_position(from, at)
	cam.current = true
