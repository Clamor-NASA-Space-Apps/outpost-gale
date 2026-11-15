extends Node3D
## Lane U's use spots mid-use, for the look check (capture-view --scene):
##   node ../../tools/capture-view.mjs . captures/u --scene res://tests/u_views.tscn --views sample@mercou:0.62 --scale 0.5
## A view is kind@item:at: the hero stands at that item's first spot of that kind, uses it, and the shot is taken at
## `at` of the clip, from beside and behind the hero; kind@item:at:side puts the lens on the hero's left (side -1).

var game: Node3D
var cam := Camera3D.new()
var _wait := 0.0


func _ready() -> void:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	Forge.register(self)
	cam.fov = 55.0
	add_child(cam)


func render_game_to_text() -> Dictionary:
	return game.render_game_to_text()


func busy() -> bool:
	return game.busy() or _wait > 0.0


func _process(delta: float) -> void:
	_wait -= delta


func set_view(v: String) -> void:
	var p := v.split(":")
	var kind := p[0].get_slice("@", 0)
	var item: Node3D = game.world.items.get(p[0].get_slice("@", 1))
	var it: Node3D = null
	for n: Node3D in game.get_tree().get_nodes_in_group("interactable"):
		if n.kind == "spot" and n.row.kind == kind and item and n.get_parent() == item:
			it = n
			break
	if it == null:
		cam.current = false
		game.set_view(v)
		return
	game.clock.pinned = true
	_wait = 99.0  # busy until the shot is set up and the clip has run to `at`
	var st: Transform3D = it.stand()
	var at := st.origin
	var space := game.get_world_3d().direct_space_state
	at.y = maxf(at.y, game.world.height_at(at.x, at.z)) + 1.5
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1 | 2, [game.player.body.get_rid()]))
	at.y = hit.position.y if hit else at.y - 1.5
	var to: Vector3 = it.middle() - at
	game.player.place(at + Vector3.UP * 0.05, rad_to_deg(atan2(to.x, -to.z)))
	for i in 40:  # settled on the floor: a body still falling refuses a clip
		await get_tree().physics_frame
	var side := float(p[2]) if p.size() > 2 else 1.0
	var b: Basis = game.player.body.global_basis
	cam.look_at_from_position(game.player.body.global_position + b.x * 0.9 * side + b.z * 0.9 + Vector3.UP * 1.7, it.middle())
	cam.current = true
	it.use(game.player.body)  # this spot, whatever the aim picks beside it
	_wait = 2.1 * (float(p[1]) if p.size() > 1 else 0.5)
