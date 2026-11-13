extends SceneTree
## Bakes the minimap's picture: the base from straight above at noon, north up, the whole 400 m ground patch
## (data/terrain.json, half 200 m: data/world.json `bound`) in one square, saved to ui/map/base.png. Run it again
## when the base changes (a moved building, a new prop); the HUD reads the picture, never the scene.
##   xvfb-run -a nice -n 10 godot --path . --resolution 1024x1024 -s res://tools/bake_minimap.gd -- hour=12

const OUT := "res://ui/map/base.png"
const HALF := 200.0  # m: the ground patch's half width (data/terrain.json), the picture's half width
const HIGH := 80.0  # m above the patch centre: over every roof, near enough that no visibility range hides a thing


func _initialize() -> void:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	while game.busy():
		await process_frame
	game.player.visible = false  # the picture is the place, not who stands in it
	if game.pip:
		game.pip.visible = false
	for n: Node in game.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for n: Node in game.find_children("*", "WorldEnvironment", true, false):
		(n as WorldEnvironment).environment.fog_enabled = false  # from above, the haze would wash the base out
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = HALF * 2.0
	cam.near = 1.0
	cam.far = HIGH + 60.0
	game.add_child(cam)
	cam.global_position = Vector3(0.0, HIGH, 0.0)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # straight down, the picture's top toward -Z (north)
	cam.make_current()
	for i in 20:
		await process_frame
	var img := root.get_texture().get_image()
	var side := mini(img.get_width(), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	var err := img.save_png(ProjectSettings.globalize_path(OUT))
	print("minimap: %s %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)
