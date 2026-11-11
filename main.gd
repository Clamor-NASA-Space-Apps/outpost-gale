extends Node3D


func _ready() -> void:
	Forge.register(self)


# What the tools read in place of a screenshot. Keep it small and true.
func render_game_to_text() -> Dictionary:
	return {}


func set_view(_view: String) -> void:
	pass
