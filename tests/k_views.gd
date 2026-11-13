extends Node3D
## Camera presets on where the power cables plug into their devices, and on the rover's charging post, around the
## real sandbox (capture-view --scene):
##   node ../../tools/capture-view.mjs . captures/k --scene res://tests/k_views.tscn --views jbox,lamp,hab,battery,dish,charger --scale 0.5
## Each view looks at a port empty (world.json cables.ends) from an offset, so it follows the model if it moves:
##   jbox      wing 1's junction box, the header coming in from the battery bank and going on to wing 2
##   lamp      the yard light's feed, from HAB 1
##   hab       HAB 1's east feed box: in from the battery bank, out to the yard light
##   hab_w     HAB 1's west gland box, the line to the greenhouse
##   greenhouse  the greenhouse's back gland
##   battery   the south ends of the three cabinets: HAB 1, the charger and the wing field
##   battery_n the north ends: the north light, the dish and the reactor
##   dish      the dish's feed
##   reactor   the reactor's feed
##   charger   the charging post with the rover parked and plugged in

var game: Node3D
var cam := Camera3D.new()

const SHOTS := {
	# [port ref, camera offset from it, look-at offset from it]
	"jbox": ["wing1:port_w", Vector3(-2.2, 1.4, -1.8), Vector3(0.2, 0.3, 0)],
	"lamp": ["lamp1", Vector3(-1.6, 1.3, 1.4), Vector3(0, 0.4, 0)],
	"hab": ["hab1:port_e1", Vector3(2.2, 1.4, 1.6), Vector3(0, 0.3, 0)],
	"hab_w": ["hab1:port_w", Vector3(-1.8, 1.4, -1.6), Vector3(0, 0.3, 0)],
	"greenhouse": ["greenhouse", Vector3(1.8, 1.4, -1.6), Vector3(0, 0.3, 0)],
	"battery": ["battery2:port_s", Vector3(-1.5, 1.6, 2.6), Vector3(0, 0.3, 0)],
	"battery_n": ["battery2:port_n", Vector3(-1.2, 1.6, -2.8), Vector3(0, 0.3, 0)],
	"dish": ["dish", Vector3(1.8, 1.4, 1.6), Vector3(-0.3, 0.4, 0)],
	"reactor": ["reactor", Vector3(-2.5, 2.0, 2.5), Vector3(0, 0.6, 0)],
	"charger": ["charger:holster", Vector3(1.8, 1.2, 2.4), Vector3(-0.7, -0.2, 0)],
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
	var s: Dictionary = game.render_game_to_text()
	s["charging"] = game.world.charging()
	return s


func busy() -> bool:
	return game.busy()


func set_view(v: String) -> void:
	if not SHOTS.has(v):
		game.set_view(v)
		return
	var port: Node3D = game.world._port(SHOTS[v][0])
	var at: Vector3 = port.global_position + SHOTS[v][2]
	cam.look_at_from_position(port.global_position + SHOTS[v][1], at)
	cam.current = true
