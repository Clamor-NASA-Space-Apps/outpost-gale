extends Node3D
## The composition root of the walkable test world (BRIEF.md 7b). It builds the world, puts the hero down,
## and owns the debug keys and the tool hooks. It holds no game rules: an interaction does one physical
## thing and nothing here counts, drains or scores (hard rule 1 until 14 Nov).

const Controls := preload("res://player/controls.gd")
const Interactions := preload("res://sandbox/interactions.gd")
const Audio := preload("res://audio/audio.gd")
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
var fps_label: Label  # the frame rate on screen, to read off a phone (game-feel-gate row 16)
var tuning: Dictionary
var design: Dictionary
var sky := 0
var quality := ""
var view := "default"
var hop := 0  # the next landmark the teleport key goes to


func _ready() -> void:
	tuning = JSON.parse_string(FileAccess.get_file_as_string("res://data/tuning.json"))
	Controls.register(tuning.input.stick_deadzone)
	design = _design(SKIES[0])
	Forge.HouseStyle.apply_lighting(self, design)
	quality = Forge.HouseStyle.default_quality()
	Forge.HouseStyle.set_quality(self, design, quality)
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
	var layer := CanvasLayer.new()
	add_child(layer)
	fps_label = Label.new()
	fps_label.theme = load("res://ui/theme.tres")
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -260
	fps_label.offset_top = 12
	fps_label.offset_right = -16
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(fps_label)
	# a boot pressed into soft dust leaves a print and lifts a little cloud
	player.footstep.connect(func(pos: Vector3, yaw: float, foot: String) -> void:
		world.mark(pos, yaw, foot)
		# the foot meets the ground at about the body's speed (contract: the contact velocity)
		world.puff(pos, player.body.velocity, 0.3, "foot"))
	Forge.register(self)


func _process(_delta: float) -> void:
	fps_label.text = "%d fps  %s  %s" % [Engine.get_frames_per_second(), quality, SKIES[sky].trim_prefix("design.").replace("design", "day")]


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("interact"):
		interactions.interact()  # out of the rover, put down the bag, or use what is in reach
	elif e.is_action_pressed("debug_sky"):
		_sky(sky + 1)
	elif e.is_action_pressed("debug_quality"):
		quality = QUALITIES[(QUALITIES.find(quality) + 1) % QUALITIES.size()]
		Forge.HouseStyle.set_quality(self, design, quality)
		_restyle()
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
	Forge.HouseStyle.set_quality(self, design, quality)
	_restyle()


func _restyle() -> void:
	world.restyle(design)
	player.restyle(design)


func render_game_to_text() -> Dictionary:
	var s: Dictionary = player.state()
	s.merge(interactions.state(), true)
	s.merge(audio.state())
	s.merge({"sky": SKIES[sky], "quality": quality, "fps": Engine.get_frames_per_second(), "view": view})
	return s


func place(pos: Vector3, yaw_deg: float) -> void:
	pos.y = world.height_at(pos.x, pos.z) + maxf(pos.y, 0.0)
	player.place(pos, yaw_deg)


func set_view(v: String) -> void:
	view = v
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
