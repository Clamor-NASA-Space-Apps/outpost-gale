extends Node3D
## Camera presets for the rover and the doorways, around the real sandbox (capture-view --scene):
##   node ../../tools/capture-view.mjs . captures/rover --scene res://tests/rover_views.tscn --views side,front,seat --advance 1200 -- mode=drive
## sky=night (or sunset, storm) switches the sky first, to judge the dust in that light.
## mode: park (the rover as placed), drive (the hero drives it east, starting at top speed), rock (the same, over a
## 0.3 m rock under the left wheels: the front pair is on it about 0.6 s in, the middle 1.15 s, the back 1.7 s).
## Views follow the rover: side, front (three-quarter from ahead), seat (close on the windscreen), low (wheels at
## ground level), trail (low behind the left wheels, on the grit); and fixed: gh_in, gh_out (greenhouse vestibule floor), hab_a, hab_b (habitat door frame, door open).

var game: Node3D
var cam := Camera3D.new()
var mode := "park"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.trim_prefix("mode=")
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("sky="):
			game._sky(game.SKIES.find("design." + a.trim_prefix("sky=")))
	Forge.register(self)
	cam.fov = 60.0
	cam.far = 8000.0
	add_child(cam)
	var rover: Node3D = game.world.items["rover"]
	var hab: Node3D = game.world.items["hab1"]
	var door := hab.find_child("door", true, false) as Node3D
	door.rotation.y += deg_to_rad(100)
	if mode in ["drive", "rock"]:
		rover.yaw = -PI / 2.0
		# already at top speed: software rendering under xvfb draws about a frame a second, so a run-up is too dear
		rover._apply(rover._pose(Vector3(-18.5 if mode == "rock" else -22.0, 0.0, 18.0), rover.yaw))
		rover.v = rover.top
		if mode == "rock":
			_rock(Vector3(-15.0, 0.0, 17.0), 0.3)
		game.player.enter(rover)
		Input.action_press(&"move_forward")
	if mode != "park":
		# the run-up on the phone preset (llvmpipe drew a frame in 3 s on high), the shots on the game's own
		Forge.HouseStyle.set_quality(game, game.design, "phone")
		game._restyle()


## A small rock from the rock models, solid, in the rover's way.
func _rock(at: Vector3, tall: float) -> void:
	var m: Node3D = load("res://models/rock_boulder_a.glb").instantiate()
	Forge.HouseStyle.apply(m, game.design, true)
	var box: AABB = game.world.drawn(m) if m.is_inside_tree() else AABB()
	add_child(m)
	box = game.world.drawn(m)
	m.scale = Vector3.ONE * (tall / box.size.y)
	m.global_position = Vector3(at.x, game.world.height_at(at.x, at.z) - box.position.y * m.scale.y, at.z)
	var points := PackedVector3Array()
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		for v in mi.mesh.get_faces():
			points.append(m.global_transform.affine_inverse() * mi.global_transform * v)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.collision_layer = 2 | 256
	body.add_child(col)
	m.add_child(body)
	game.world.items["rover"].add_collision_exception_with(body)


func _physics_process(_delta: float) -> void:
	if mode == "haze":  # a wheel's stream standing still in front of the side view, to judge its look alone
		var r: Node3D = game.world.items["rover"]
		var p: Vector3 = r.global_transform * Vector3(-4.0, 0.0, 0.0)
		p.y = game.world.height_at(p.x, p.z)
		game.world.stream("test", p, r.global_basis.z * 2.8, 1.0)


func render_game_to_text() -> Dictionary:
	var s: Dictionary = game.render_game_to_text()
	var r: Node3D = game.world.items["rover"]
	s["rover"] = {"pos": r.global_position, "v": r.v, "onRock": r.on_rock, "blocked": r.blocked, "tilt": r.global_basis.get_euler()}
	return s


var _shot := false


func set_view(v: String) -> void:
	if not _shot and mode != "park":
		_shot = true
		Forge.HouseStyle.set_quality(game, game.design, game.quality)
		game._restyle()
	var r: Node3D = game.world.items["rover"]
	var t: Transform3D = r.global_transform
	var shots := {
		"side": [Vector3(-8.0, 1.6, 0.0), Vector3(0, 1.3, 0)],
		"front": [Vector3(-5.0, 2.2, -6.5), Vector3(0, 1.4, 0)],
		"seat": [Vector3(-2.4, 2.3, -4.2), Vector3(-0.5, 1.9, -0.8)],
		"low": [Vector3(-4.5, 0.35, 1.2), Vector3(-1.0, 0.4, -0.5)],
		"back": [Vector3(3.0, 2.0, 7.0), Vector3(0, 1.0, 0)],
		"trail": [Vector3(-2.5, 0.7, 4.5), Vector3(-0.6, 0.2, 2.0)],  # low behind the left wheels: the grit stream
	}
	var gh: Node3D = game.world.items["greenhouse"]
	var hab: Node3D = game.world.items["hab1"]
	var fixed := {
		"gh_in": [gh, Vector3(0.5, 1.5, -0.8), Vector3(0.0, 0.2, -3.6)],
		"gh_out": [gh, Vector3(-0.3, 1.4, -6.6), Vector3(0.0, 0.2, -3.9)],
		"hab_a": [hab, Vector3(-1.6, 1.5, -4.4), Vector3(-0.6, 1.2, -2.55)],
		"hab_b": [hab, Vector3(1.2, 1.4, -4.0), Vector3(-0.6, 1.0, -2.5)],
		"hab_in": [hab, Vector3(0.3, 1.7, 1.2), Vector3(0.0, 0.3, -2.4)],
	}
	if shots.has(v):
		cam.look_at_from_position(t * shots[v][0], t * shots[v][1])
	elif fixed.has(v):
		var n: Node3D = fixed[v][0]
		cam.look_at_from_position(n.global_transform * fixed[v][1], n.global_transform * fixed[v][2])
	else:
		game.set_view(v)
		return
	cam.current = true
