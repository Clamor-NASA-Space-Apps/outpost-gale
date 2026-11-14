extends SceneTree
## Renders the start screen's video loop (ui/start_loop.ogv, played by ui/start.gd) and its still (ui/start_bg.jpg):
## the game's own hero, standing and breathing as the game plays it (player/player.gd whole: its idle clip, its
## breath, its helmet turning to what is worth a look), and PIP beside it, on dust under one lamp. The two glance at
## each other once and PIP blinks. Not shipped (tools/ holds a .gdignore): the game plays the video, never this scene.
## Where things stand and how bright the lamp is: art direction, judged in the picture.
##
## The frames, 1280 x 720 at a fixed 24 a second, on a hidden display (FRAMES + FADE of them, f_000.png on):
##   xvfb-run -a -s "-screen 0 1280x720x24" nice -n 19 godot --display-driver x11 --path . --resolution 1280x720 \
##     --fixed-fps 24 --audio-driver Dummy -s res://tools/start_loop.gd -- /abs/frames/dir
## The loop, Ogg Theora (the engine's own video format), no sound. The last half second is cross-faded into the
## first, so the seam does not show:
##   ffmpeg -framerate 24 -i /abs/frames/dir/f_%03d.png -filter_complex "[0]split=3[a][b][c]; \
##     [a]trim=start_frame=192:end_frame=204,setpts=PTS-STARTPTS[tail];[b]trim=end_frame=12,setpts=PTS-STARTPTS[head]; \
##     [tail][head]xfade=transition=fade:duration=0.5:offset=0[seam];[c]trim=start_frame=12:end_frame=192,setpts=PTS-STARTPTS[body]; \
##     [seam][body]concat=n=2:v=1:a=0" -c:v libtheora -q:v 7 -pix_fmt yuv420p -an ui/start_loop.ogv
## The still, 1920 x 1080: the same godot line with 1920x1080 (twice) and `still` after the folder writes still.png:
##   magick /abs/frames/dir/still.png -strip -quality 90 ui/start_bg.jpg

const FPS := 24
const FRAMES := 192  # the loop: 8 s
const FADE := 12  # more frames after it, cross-faded into its first half second
const WARM := 48  # frames before the first one kept: the hero settles on the ground and its look eases in
const Hud := preload("res://ui/hud.gd")
const Style := preload("res://addons/forge/house_style.gd")  # by path: a -s script compiles before the Forge autoload exists
const EYE := Vector3(-1.25, 1.2, 5.6)  # the lens, and what it looks at
const AIM := Vector3(-1.25, 1.05, 0.0)
const FOV := 30.0
const HERO_YAW := 205.0  # toward the lens, a little turned (CONTRACTS.md yaw)
const PIP_AT := Vector3(-0.85, 0.0, 0.5)
const PIP_YAW := 140.0
const LAMP := Vector3(2.6, 5.0, 3.4)  # above, on the right, and where its beam lands
const LAMP_AIM := Vector3(0.15, 0.6, 0.1)
const MEET := Vector2(2.5, 5.0)  # s into the loop: the two look at each other from, to
const BLINKS := [1.2, 6.4, 6.75]  # s into the loop: PIP's eyes close (the last two a double blink, as in the game)

var hero: Node3D
var _gaze := Node3D.new()  # what the hero's helmet turns to (player.gd `attention`)
var _pip: Dictionary  # data/world.json `pip`: how its head turns, its eyes blink and its bar glows in the game
var _head: Node3D
var _head_ang := Vector3.ZERO
var _eyes: Array[Node] = []
var _bar: StandardMaterial3D
var _glow: float
var _t := -float(WARM) / FPS  # s into the loop


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame  # the window has its size from here on
	root.msaa_3d = Viewport.MSAA_4X
	var size := root.get_visible_rect().size
	var world := Node3D.new()
	root.add_child(world)
	hero = Node3D.new()
	hero.set_script(load("res://player/player.gd"))
	world.add_child(hero)
	hero.allowed = ["none"]  # a key pressed during the render moves nobody
	hero.touch.visible = false
	var design: Dictionary = hero.design
	# surfaces and glow as the laptop preset draws them. Not set_quality(): it also sets the window's pacing
	var look: Dictionary = design.quality.get("laptop", {})
	design["_quality"] = look
	var rig := Style.apply_lighting(world, design)
	(rig.sun as Light3D).visible = false
	var env: Environment = (rig.world as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR  # an environment's own colour is black: a dark stage, not Mars
	env.ambient_light_energy = 0.05
	env.fog_enabled = false
	env.glow_enabled = float(look.get("glow", 0)) > 0.0
	env.glow_intensity = float(look.get("glow", 0))
	var ground := StaticBody3D.new()
	ground.collision_layer = 1  # CONTRACTS.md: ground
	var slab := CollisionShape3D.new()
	slab.shape = BoxShape3D.new()
	slab.shape.size = Vector3(40, 1, 40)
	slab.position.y = -0.5
	ground.add_child(slab)
	var dust := MeshInstance3D.new()
	dust.mesh = PlaneMesh.new()
	dust.mesh.size = Vector2(40, 40)
	dust.material_override = Style.role(design, "dust", true)
	ground.add_child(dust)
	world.add_child(ground)
	hero.place(Vector3.ZERO, HERO_YAW)
	world.add_child(_gaze)
	_gaze.position = EYE
	hero.attention = _gaze
	var pip: Node3D = load("res://models/vehicle_pip.glb").instantiate()
	Style.apply(pip, design)
	pip.position = PIP_AT
	pip.rotation.y = deg_to_rad(PIP_YAW)
	world.add_child(pip)
	_pip = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json")).pip
	_head = pip.find_child("head", true, false)
	_eyes = [pip.find_child("eye_l", true, false), pip.find_child("eye_r", true, false)]
	# its own copy of the light role, as sandbox/pip.gd keeps one: the glow pulses on this bar alone
	var bar := pip.find_child("status_bar", true, false) as MeshInstance3D
	_bar = bar.get_active_material(0).duplicate()
	_glow = _bar.emission_energy_multiplier
	bar.set_surface_override_material(0, _bar)
	var lamp := SpotLight3D.new()
	lamp.light_color = Hud.color("on_surface")  # the theme's warm white, the menu's own ink
	lamp.light_energy = 7.5
	lamp.spot_range = 14.0
	lamp.spot_angle = 16.0
	lamp.spot_attenuation = 0.6
	lamp.spot_angle_attenuation = 2.5
	lamp.shadow_enabled = true
	world.add_child(lamp)
	lamp.look_at_from_position(LAMP, LAMP_AIM)
	# a faint cool fill from the lens's side, so the shadowed half of the suit is a shape and not a hole
	var fill := OmniLight3D.new()
	fill.light_color = env.ambient_light_color  # the design's ambient colour, as the rig set it
	fill.light_energy = 0.6
	fill.omni_range = 12.0
	fill.position = Vector3(-3.0, 1.6, 4.0)
	world.add_child(fill)
	var lens := Camera3D.new()
	lens.fov = FOV
	world.add_child(lens)
	lens.look_at_from_position(EYE, AIM)
	lens.make_current()  # over the hero's own follow camera
	# the lamp's haze: a soft cone of its colour laid over the picture, from its side of the frame
	var fade := Gradient.new()
	var glow := lamp.light_color
	glow.a = 0.29
	fade.set_color(0, glow)
	glow.a = 0.0
	fade.set_color(1, glow)
	var cone := GradientTexture2D.new()
	cone.gradient = fade
	cone.fill = GradientTexture2D.FILL_RADIAL
	cone.fill_from = Vector2(0.5, 0.0)
	cone.fill_to = Vector2(1.0, 0.0)
	var haze := TextureRect.new()
	haze.texture = cone
	haze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	haze.material = CanvasItemMaterial.new()
	haze.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	haze.position = Vector2(size) * Vector2(0.2, -0.2)
	haze.size = Vector2(size) * Vector2(1.1, 1.9)
	root.add_child(haze)
	var still := args.size() > 1 and args[1] == "still"
	for i in WARM + (0 if still else FRAMES + FADE):
		await process_frame
		# checked once the engine's first uneven frames are over, on the last one before the frames that are kept
		if i == WARM - 1 and not still and not is_equal_approx(root.get_process_delta_time(), 1.0 / FPS):
			push_error("start_loop: run with --fixed-fps %d, or the frames are not %d a second" % [FPS, FPS])
		_step(root.get_process_delta_time())
		if i >= WARM:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/f_%03d.png" % [args[0], i - WARM])
	if still:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[0] + "/still.png")
	quit()


func _step(delta: float) -> void:
	_t += delta
	# both look out at whoever is looking, and now and then at each other: the hero down at PIP (the life layer
	# eases the turn), PIP up at the helmet
	var meet := _t >= MEET.x and _t < MEET.y
	_gaze.position = _head.global_position.lerp(EYE, 0.15) if meet else EYE  # a glance down, not a turn of the whole body
	var helmet: Vector3 = hero.body.global_position + Vector3.UP * hero.model.bounds.end.y * 0.9
	# PIP as sandbox/pip.gd idles it: its head turning to what it looks at, a blink now and then, a slow glow
	var d := (_head.get_parent() as Node3D).global_transform.affine_inverse() * (helmet if meet else EYE) - _head.position
	var yaw := deg_to_rad(float(_pip.head_yaw_deg))
	var pitch := deg_to_rad(float(_pip.head_pitch_deg))
	var want := Vector3(clampf(atan2(d.y, Vector2(d.x, d.z).length()), -pitch, pitch), clampf(atan2(-d.x, -d.z), -yaw, yaw), 0.0)
	_head_ang = _head_ang.move_toward(want, deg_to_rad(float(_pip.head_deg_s)) * delta)
	_head.rotation = _head_ang
	var open := 1.0
	for b: float in BLINKS:
		if _t >= b and _t < b + float(_pip.blink_close_s):
			open = 1.0 - sin(PI * (_t - b) / float(_pip.blink_close_s)) * 0.85
	for e: Node3D in _eyes:
		e.scale.y = open
	_bar.emission_energy_multiplier = _glow * (0.75 + 0.25 * sin(TAU * float(_pip.glow_hz) * _t))
