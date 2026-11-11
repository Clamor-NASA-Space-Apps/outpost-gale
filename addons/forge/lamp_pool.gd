extends Node
## Lights only the lamps nearest the camera (DESIGN.md quality `lamps`). The renderer shades every lamp
## that reaches a mesh on every pixel of it, so a phone pays for each one, and a far lamp adds little.
## Lamps come from HouseStyle.make_lamp(), which puts them in GROUP and notes their full energy.

const GROUP := &"forge_lamps"

var count := 0


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var lamps := get_tree().get_nodes_in_group(GROUP)
	lamps.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	for i in lamps.size():
		var lamp: OmniLight3D = lamps[i]
		var full: float = lamp.get_meta("energy")
		# half a second to fade, so a lamp joining or leaving the nearest few is never a pop
		lamp.light_energy = move_toward(lamp.light_energy, full if i < count else 0.0, full * delta * 2.0)
		lamp.visible = lamp.light_energy > 0.0


func _exit_tree() -> void:
	for lamp: OmniLight3D in get_tree().get_nodes_in_group(GROUP):
		lamp.light_energy = lamp.get_meta("energy")
		lamp.visible = true
