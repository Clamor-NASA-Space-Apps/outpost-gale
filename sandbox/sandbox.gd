extends Node3D
## The composition root of the walkable test world (BRIEF.md 7b). It builds the world, puts the hero down,
## and owns the debug keys and the tool hooks. It holds no game rules: an interaction does one physical
## thing and nothing here counts, drains or scores (hard rule 1 until 14 Nov).

const Controls := preload("res://player/controls.gd")
const Interactions := preload("res://sandbox/interactions.gd")
const Audio := preload("res://audio/audio.gd")
const Pip := preload("res://sandbox/pip.gd")
const Settings := preload("res://ui/settings.gd")
# sky states: DESIGN.md and its DESIGN.<state>.md siblings, as token files
const SKIES := ["design", "design.sunset", "design.night", "design.storm"]
const QUALITIES := ["low", "medium", "high"]
const VIEWS := {
	# [from, at] in metres from the patch centre; heights are added from the ground
	"base": [Vector3(-26, 16, 24), Vector3(4, 0, -2)],
	"horizon": [Vector3(-14, 1.7, -14), Vector3(30, 3, 22)],
	"airlock": [Vector3(-2.5, 1.7, 7.5), Vector3(0, 1.2, 2.5)],
	"rover": [Vector3(-16, 3.0, 8), Vector3(-10, 1.2, 0)],
	"greenhouse": [Vector3(-9.5, 5.5, -1.5), Vector3(-14, 0.4, -6)],
}

@onready var world: Node3D = $World
@onready var player: Node3D = $Player
var interactions: Node3D
var audio := Audio.new()
var pip: Node3D  # world.json item `pip`, driven by sandbox/pip.gd
var fps_label: Label  # the frame rate on screen, to read off a phone (game-feel-gate row 16)
var tuning: Dictionary
var design: Dictionary
var sky := 0
var quality := ""
var overrides := {}  # the player's own graphics knobs on top of the preset (ui/settings.gd)
var settings: CanvasLayer
var view := "default"
var hop := 0  # the next landmark the teleport key goes to
var cover: ColorRect  # over the screen while new shaders compile (load, a sky or quality switch)
var _warming := false
var _rewarm := false


func _ready() -> void:
	tuning = JSON.parse_string(FileAccess.get_file_as_string("res://data/tuning.json"))
	Controls.register(tuning.input.stick_deadzone)
	design = _design(SKIES[0])
	Forge.HouseStyle.apply_lighting(self, design)
	# this device's last choice (ui/settings.gd), else the preset for it: `low` on a phone (the A16)
	var saved := Settings.saved()
	quality = saved.get("level", "")
	if not design.quality.has(quality):
		quality = Forge.HouseStyle.default_quality()
	overrides = saved.get("overrides", {})
	Forge.HouseStyle.set_quality(self, design, quality, overrides)
	world.build(design)
	var s: Dictionary = world.landmark("spawn")
	player.place(s.pos, s.yaw)
	interactions = Interactions.new()
	interactions.name = "Interactions"
	add_child(interactions)
	interactions.setup(world, player, tuning, JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json")))
	add_child(audio)
	audio.setup(world, player, tuning.audio)
	interactions.used.connect(audio.used)
	world.sound.connect(audio.play)  # the base's own machines (a servo starting)
	world.hero = player.body  # the solar trackers hold still while the hero stands at them
	pip = world.items.get("pip")
	if pip:
		pip.set_script(Pip)  # PIP wanders on its own (sandbox/pip.gd): motion and a beep, no game state
		pip.setup(world, player)
		pip.sound.connect(audio.play)
	var layer := CanvasLayer.new()
	add_child(layer)
	fps_label = Label.new()
	fps_label.theme = load("res://ui/theme.tres")
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -440
	fps_label.offset_top = 12
	fps_label.offset_right = -180  # left of the settings gear (101 px and its margin on a phone)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(fps_label)
	# a boot pressed into soft dust leaves a print and lifts a little cloud
	player.footstep.connect(func(pos: Vector3, yaw: float, foot: String) -> void:
		world.mark(pos, yaw, foot)
		# a planted boot is nearly still: only the push-off scuffs a little grit back, low and behind the heel. The
		# body's own velocity threw it ahead, between the legs and toward a camera in front (13 Nov playtest: "sparks")
		world.puff(pos, -player.body.velocity * float(world.data.contact.foot_kick), 0.3, "foot"))
	var top := CanvasLayer.new()
	top.layer = 128
	add_child(top)
	cover = ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(cover)
	settings = Settings.new()
	add_child(settings)
	settings.setup(self)
	_warm()
	Forge.register(self)


func _process(_delta: float) -> void:
	fps_label.text = "%d fps  %s  %s" % [Engine.get_frames_per_second(), quality, SKIES[sky].trim_prefix("design.").replace("design", "day")]


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("interact"):
		interactions.interact()  # out of the rover, put down the bag, or use what is in reach
	elif e.is_action_pressed("debug_sky"):
		_sky(sky + 1)
	elif e.is_action_pressed("debug_quality"):
		set_graphics(QUALITIES[(QUALITIES.find(quality) + 1) % QUALITIES.size()], {})
	elif e.is_action_pressed("debug_teleport"):
		var names: Array = world.data.landmarks.keys()
		hop = (hop + 1) % names.size()
		var l: Dictionary = world.landmark(names[hop])
		player.place(l.pos, l.yaw)


func _design(name: String) -> Dictionary:
	var file := "res://%s.json" % name
	return Forge.HouseStyle.load_design(file if FileAccess.file_exists(file) else "res://design.json")


func _sky(i: int) -> void:
	sky = i % SKIES.size()
	design = _design(SKIES[sky])
	Forge.HouseStyle.apply_lighting(self, design)
	Forge.HouseStyle.set_quality(self, design, quality, overrides)
	_restyle()
	_warm()
	audio.sky(SKIES[sky])  # the sun going down has its music


## A preset with the player's knobs on top (CONTRACTS.md, Graphics settings). `restyle` for a knob the world reads
## (trail, particles, ground), `warm` for one that compiles shaders: the cover hides the compile.
func set_graphics(level: String, over: Dictionary, restyle := true, warm := true) -> void:
	quality = level
	overrides = over
	Forge.HouseStyle.set_quality(self, design, quality, overrides)
	if restyle:
		_restyle()
	if warm:
		_warm()


## Every shader the scene can show compiles now, behind the cover, not on its first sight in play (the web build keeps
## no shader cache: skills/frame-budget). The stage stands inside the reflection probe, so the probe's variants
## compile too, and the hero's fade copy is drawn with it.
func _warm() -> void:
	cover.color = Color.html(design.colors.surface)
	cover.visible = true
	if _warming:
		_rewarm = true  # a second switch while the first warms: once more when it ends
		return
	_warming = true
	var fade := ShaderMaterial.new()
	fade.shader = player.fading
	var at := Transform3D(Basis(), world.get_node("Probe").global_position)
	world.dust.warm(at * Vector3(0, 0, -8))
	await Forge.HouseStyle.warm(self, design, at, [fade])
	while _rewarm:
		_rewarm = false
		await Forge.HouseStyle.warm(self, design, at, [fade])
	_warming = false
	var t := create_tween()
	t.tween_property(cover, "color:a", 0.0, 0.25)
	t.tween_callback(func() -> void: cover.visible = _warming)


func _restyle() -> void:
	world.restyle(design)
	player.restyle(design)


## True while the cover is up (Forge waits for it before a picture).
func busy() -> bool:
	return cover.visible


func render_game_to_text() -> Dictionary:
	var s: Dictionary = player.state()
	s.merge(interactions.state(), true)
	s.merge(audio.state())
	if pip:
		s.merge(pip.state_text())
	s.merge({"sky": SKIES[sky], "quality": quality, "fps": Engine.get_frames_per_second(), "view": view})
	return s


func place(pos: Vector3, yaw_deg: float) -> void:
	pos.y = world.height_at(pos.x, pos.z) + maxf(pos.y, 0.0)
	player.place(pos, yaw_deg)


func set_view(v: String) -> void:
	view = v
	if v == "settings":
		settings.open()  # over the play view, for a picture of it
		return
	if v == "storm":
		_sky(SKIES.find("design.storm"))
		v = "horizon"
	if not VIEWS.has(v):
		view = "default" if v != "hero" else "hero"
		$ViewCam.current = false
		if v == "hero":
			var b: Node3D = player.body
			$ViewCam.look_at_from_position(b.global_position - b.global_basis.z * 3.0 + Vector3(1.0, 1.4, 0), b.global_position + Vector3(0, 1.1, 0))
			$ViewCam.current = true
		return
	var from: Vector3 = VIEWS[v][0]
	var at: Vector3 = VIEWS[v][1]
	from.y += world.height_at(from.x, from.z)
	at.y += world.height_at(at.x, at.z)
	$ViewCam.look_at_from_position(from, at)
	$ViewCam.current = true
