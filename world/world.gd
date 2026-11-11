extends Node3D
## The world: terrain, then every item in data/world.json on the ground. A prefab whose model is not in
## models/ yet stands in as a labelled box of its real size, so the sandbox runs before the models land.

const Terrain := preload("res://world/terrain.gd")
const GROUND := 1
const STATICS := 2

var data: Dictionary
var terrain: Node3D
var items: Dictionary = {}  # id -> Node3D


func build(design: Dictionary) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(design)
	for it: Dictionary in data.items:
		var node := _prefab(it.prefab, design)
		node.name = it.id
		var p := Vector3(it.pos[0], 0, it.pos[1])
		p.y = height_at(p.x, p.z)
		node.position = p
		node.rotation.y = -deg_to_rad(float(it.get("yaw", 0)))
		add_child(node)
		items[it.id] = node


func restyle(design: Dictionary) -> void:
	terrain.restyle(design)
	for n: Node3D in items.values():
		Forge.HouseStyle.apply(n, design, true)


func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


## {pos: Vector3 on the ground, yaw: degrees}
func landmark(name: String) -> Dictionary:
	var l: Array = data.landmarks.get(name, data.landmarks.spawn)
	return {"pos": Vector3(l[0], height_at(l[0], l[1]), l[1]), "yaw": float(l[2])}


func _prefab(id: String, design: Dictionary) -> Node3D:
	var file: String = data.prefabs.get(id, "")
	if ResourceLoader.exists(file):
		var m: Node3D = load(file).instantiate()
		Forge.HouseStyle.apply(m, design, true)
		return m
	return _standin(id, design)


func _standin(id: String, design: Dictionary) -> Node3D:
	var size: Array = data.standin.get(id, [1, 1, 1])
	var s := Vector3(size[0], size[1], size[2])
	var body := StaticBody3D.new()
	body.collision_layer = STATICS
	body.collision_mask = 0
	var box := BoxMesh.new()
	box.size = s
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position.y = s.y / 2.0
	mi.material_override = Forge.HouseStyle.role(design, "trim")
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = s
	col.shape = shape
	col.position.y = s.y / 2.0
	body.add_child(col)
	var label := Label3D.new()
	label.text = id + " (stand-in)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = s.y + 0.4
	label.font_size = 48
	body.add_child(label)
	return body
