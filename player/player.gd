extends Node3D
## STAND-IN from section 1: a capsule that stands where it is put and never moves, with the methods the
## sandbox calls (CONTRACTS.md). The player lane replaces this file with the real body, camera and touch.
## Every measured row of the reality sheet fails against it, which is the point: the probe is wired.

var body: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	body = CharacterBody3D.new()
	body.name = "Hero"
	body.collision_layer = 8
	body.collision_mask = 1 | 2 | 4 | 16 | 64
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.89
	col.shape = cap
	col.position.y = 0.945
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.89
	mi.mesh = mesh
	mi.position.y = 0.945
	body.add_child(mi)
	add_child(body)
	camera = Camera3D.new()
	camera.far = 8000.0
	add_child(camera)


func _physics_process(_delta: float) -> void:
	var at := body.global_position
	camera.look_at_from_position(at + body.global_basis.z * 4.2 + Vector3(0, 2.2, 0), at + Vector3(0, 1.5, 0))


func place(pos: Vector3, yaw_deg: float) -> void:
	body.global_position = pos
	body.rotation.y = -deg_to_rad(yaw_deg)
	body.velocity = Vector3.ZERO


func enter(_vehicle: Node3D) -> void:
	pass


func exit() -> void:
	pass


func state() -> Dictionary:
	return {
		"player": {"pos": body.global_position, "speed": 0.0, "onFloor": body.is_on_floor(), "gait": "idle", "inside": []},
		"cam": {"inside": false, "dist": 4.2}, "heroScreen": 0.0,
		"interaction": {"target": "", "prompt": ""}, "carry": "", "vehicle": {"driving": false, "speed": 0.0},
	}
