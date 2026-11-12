extends Node3D
## A light fixture for the player alone: flat ground, the light rig, the hero and the Forge hooks. Films and
## probe rows run here (a row's `scene`) when the whole world is too slow to draw, as on a software renderer.
## View `hero` films from the side, close, tracking the body: feet, stride and hop read there.

var side: Camera3D


func _ready() -> void:
	var design := Forge.HouseStyle.load_design("res://design.json")
	Forge.HouseStyle.apply_lighting(self, design)
	Forge.HouseStyle.set_quality(self, design, "phone")
	var ground := StaticBody3D.new()
	ground.collision_layer = 1  # CONTRACTS.md: ground
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(200, 1, 200)
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = Vector2(200, 200)
	mesh.material_override = Forge.HouseStyle.role(design, "dust")
	ground.add_child(mesh)
	add_child(ground)
	side = Camera3D.new()
	add_child(side)
	$Player.place(Vector3.ZERO, 0)
	Forge.register(self)


func _physics_process(_delta: float) -> void:
	var at: Vector3 = $Player.body.global_position
	side.look_at_from_position(at + Vector3(3.2, 1.0, 0), at + Vector3(0, 0.9, 0))


func render_game_to_text() -> Dictionary:
	return $Player.state()


func place(pos: Vector3, yaw_deg: float) -> void:
	$Player.place(pos, yaw_deg)


## `hero`: the side view. `carry`: the side view with a cargo bag hung on the hero, as the interactions do.
func set_view(v: String) -> void:
	if v == "carry" and not $Player.carried:
		var bag := StaticBody3D.new()
		bag.collision_layer = 0
		bag.add_to_group("carriable")
		bag.add_child(Forge.HouseStyle.apply(load("res://models/prop_cargo_bag.glb").instantiate(), Forge.HouseStyle.load_design("res://design.json")))
		for c: CollisionObject3D in bag.find_children("*", "CollisionObject3D", true, false):
			c.collision_layer = 0  # a carried bag never pushes its carrier
		$Player.body.add_child(bag)
	if v in ["hero", "carry"]:
		side.make_current()
	else:
		$Player.cam.lens.make_current()
