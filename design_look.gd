extends Node3D
## The look scene until the sandbox lands: the real ground, the light rig and a row of models to judge them by.
##   godot --path . -- --glb=/abs/a.glb,/abs/b.glb
## Models stand in a row facing south-east, toward Mount Sharp's flanks, each on the ground.

const VIEWS := {
	# eye height behind the row, looking toward Mount Sharp (bearing 140)
	"horizon": [Vector3(-14, 1.7, -14), Vector3(30, 3, 22)],
	"base": [Vector3(-22, 14, -30), Vector3(4, 0, 2)],
	"hero": [],  # in front of the first model in the row
	"prints": [Vector3(-3.0, 1.4, 5.5), Vector3(1.5, 0, 2.0)],
}
var design: Dictionary
var view := "horizon"


func _ready() -> void:
	var opt := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		opt[kv[0]] = kv[1] if kv.size() > 1 else ""
	design = Forge.HouseStyle.load_design(str(opt.get("design", "res://design.json")))
	Forge.HouseStyle.apply_lighting(self, design)
	Forge.HouseStyle.set_quality(self, design, Forge.HouseStyle.default_quality())
	$Terrain.build(design)
	var along := 0.0
	for f: String in str(opt.get("glb", "")).split(",", false):
		var m := Forge.load_glb(f)
		if m == null:
			continue
		Forge.HouseStyle.apply(m, design, true)
		$Row.add_child(m)
		var dir := Vector3(sin(deg_to_rad(140.0)), 0, -cos(deg_to_rad(140.0)))
		var side := Vector3(dir.z, 0, -dir.x)
		var p := side * along + dir * 6.0
		m.position = Vector3(p.x, $Terrain.height_at(p.x, p.z), p.z)
		m.rotation.y = deg_to_rad(-140.0)
		along += 7.0
	# a walk of boot prints and a wheel track, to judge the dust taking a mark
	for i in 16:
		var p := Vector3(-2.0 + i * 0.35, 0, 1.0 + i * 0.2)
		var side := 0.11 if i % 2 else -0.11
		p += Vector3(0.5, 0, -0.87) * side
		$Terrain.mark(Vector3(p.x, 0, p.z), 60.0, "foot_l" if i % 2 else "foot_r")
	for i in 80:
		for w: float in [-1.1, 1.1]:
			$Terrain.mark(Vector3(-4.0 + i * 0.1, 0, 3.5 + w), 90.0, "wheel", 0.3)
	Forge.register(self)
	set_view(view)


func render_game_to_text() -> Dictionary:
	return {"view": view, "ground0": $Terrain.height_at(0, 0), "models": $Row.get_child_count()}


func set_view(v: String) -> void:
	view = v if VIEWS.has(v) else "horizon"
	if view == "hero" and $Row.get_child_count():
		var first: Node3D = $Row.get_child(0)
		var at := first.position + Vector3(0, 1.1, 0)
		var dir := Vector3(sin(deg_to_rad(140.0)), 0, -cos(deg_to_rad(140.0)))
		$Camera3D.look_at_from_position(at + dir * 3.2 + Vector3(dir.z, 0, -dir.x) * 1.2 + Vector3(0, 0.3, 0), at)
		return
	var at: Vector3 = VIEWS[view][1]
	var from: Vector3 = VIEWS[view][0]
	from.y += $Terrain.height_at(from.x, from.z)
	at.y += $Terrain.height_at(at.x, at.z)
	$Camera3D.look_at_from_position(from, at)
