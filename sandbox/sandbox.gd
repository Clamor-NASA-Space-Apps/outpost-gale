extends Node3D
## The composition root of the walkable test world (BRIEF.md 7b). It builds the world, puts the hero down,
## and owns the debug keys and the tool hooks. It holds no game rules: an interaction does one physical
## thing and nothing here counts, drains or scores (hard rule 1 until 14 Nov).

const Controls := preload("res://player/controls.gd")
const Interactions := preload("res://sandbox/interactions.gd")
const Audio := preload("res://audio/audio.gd")
const Pip := preload("res://sandbox/pip.gd")
const Settings := preload("res://ui/settings.gd")
const SkyClock := preload("res://world/sky_clock.gd")
const Cover := preload("res://ui/cover.gd")
const SimNode := preload("res://sim/sim_node.gd")
const Beats := preload("res://cine/beats.gd")
const Cine := preload("res://cine/cine.gd")
const GameHud := preload("res://ui/game_hud.tscn")
const Hud := preload("res://ui/hud.gd")
const Save := preload("res://sandbox/save.gd")
const Advisor := preload("res://sandbox/advisor.gd")
# the power panel's switches: each one's on and off choice in data/sim.json (the heater: normal heat, turned down)
const PANEL := {"o2_maker": ["o2_maker_on", "o2_maker_off"], "greenhouse": ["greenhouse_on", "greenhouse_off"],
	"recycler": ["recycler_on", "recycler_off"], "heater": ["heater_normal", "heater_low"]}
# sky states: DESIGN.md and its DESIGN.<state>.md siblings, as token files; the sky clock blends them by the sun
const SKIES := ["design", "design.sunset", "design.night", "design.storm"]
const SKY_PHASES := ["noon", "dusk", "night", "storm"]  # where _sky(i) puts the clock: each key at its own look
const HINT_S := 6.0  # s a one-off hint of PIP's stays up (the HUD's toast time; art direction)
const VIEWS := {
	# [from, at] in metres from the patch centre; heights are added from the ground
	"base": [Vector3(27.772, 16, 21.925), Vector3(-2.601, 0, -3.638)],
	"overview": [Vector3(108.646, 150, -17.208), Vector3(-34.569, 0, 5.475)],  # the whole outpost from high up: lander to reactor
	"horizon": [Vector3(-11.638, 1.7, 16.018), Vector3(-10.166, 3, -39.223)],
	"west": [Vector3(-0.215, 1.7, -14.141), Vector3(3.46, 4, 60.2)],  # past the base (turned with it, 14 Nov: no longer toward the setting sun)
	"airlock": [Vector3(7.799, 1.7, 1.296), Vector3(2.469, 1.2, -0.391)],
	"rover": [Vector3(13.3, 3, -18.306), Vector3(6.337, 1.2, -11.128)],
	"greenhouse": [Vector3(9.828, 5.5, 4.518), Vector3(1.721, 0.4, 10.865)],
	"hab_in": [Vector3(1.336, 2, -0.515), Vector3(-2.069, 1.1, -0.28)],  # inside HAB 1: the life-support wall and bunks
	"hab_desk": [Vector3(-0.733, 2, -0.795), Vector3(1.202, 1, 1.835)],  # inside HAB 1: galley, Veggie, desk and map
}
# The play camera inside a room, first person: [item, where the hero stands in its space, yaw from the item's front,
# pitch deg]. Each stands well in from the door looking in (a model's door is on its front, -Z).
const ROOM_VIEWS := {
	"hab_room": ["hab1", Vector3(0.0, 0.3, -0.3), 180.0, -12.0],
	"greenhouse_room": ["greenhouse", Vector3(0.0, 0.22, -0.8), 180.0, -12.0],
	"shelter_room": ["shelter", Vector3(0.0, 0.1, 0.3), 180.0, -12.0],
}

@onready var world: Node3D = $World
@onready var player: Node3D = $Player
var interactions: Node3D
var audio := Audio.new()
var pip: Node3D  # world.json item `pip`, driven by sandbox/pip.gd
var fps_label: Label  # the frame rate on screen, to read off a phone (game-feel-gate row 16)
var tuning: Dictionary
var design: Dictionary
var sky := 0  # the SKIES key that leads the clock's blend
var clock: SkyClock  # world/sky_clock.gd: the hour every part of the look follows
var quality := ""
var overrides := {}  # the player's own graphics knobs on top of the preset (ui/settings.gd)
var settings: CanvasLayer
var view := "default"
var hop := 0  # the next landmark the teleport key goes to
var cover: Cover  # over the screen while new shaders compile (load, a sky or quality switch)
var _warming := false
var _rewarm := false
var _netted: Array[Node3D] = []  # besides the hero, what the safety net watches (_physics_process)
var rescued := 0  # how many times the safety net moved something (tests/edge_test.gd)
var sim: SimNode  # the rules (sim/): every meter; the HUD and the beats only read it or ask it
var hud: Control  # ui/game_hud.tscn: meters, PIP's bubble, compass, maps, cards
var beats: Beats  # cine/beats.gd: PIP's guided sequences from data/beats.json
var cine: Cine  # cine/cine.gd: sleep, rover trips, the launch
var trip_km := 8.8  # the last rover trip's distance, for its title card and the drive home
var lamp_hinted := false  # PIP explains the helmet lights once, the first time they come on by themselves
var offers := {}  # data/beats.json `offers`: what each choice card holds and which rules it sets
var lost := false  # a meter ran out: the mission-lost card is up and the rules stop
var over := false  # Sol 10's night is slept: the Mission 1 report is up, and the end screen comes after it
var ended: ColorRect  # the end screen (end_screen()), null until then
var film := false  # P, or Settings, Demo: no HUD, no touch controls, no frame-rate line, for a screen recording
var beacon: MeshInstance3D  # the kid's map mark in the world: a pillar of the DESIGN.md `light` role, seen from afar
var deadline := {}  # data/sols.json `deadline`: PIP's warnings while a sol's tasks run late
var warned := {}  # "<woke sol>:<line id>" -> true: each warning once a day
var resume := {}  # Continue: the checkpoint to start from (sandbox/save.gd), set by ui/boot.gd before this enters the tree
var advisor := Advisor.new()  # sandbox/advisor.gd: PIP's word and a waypoint when the hero or the base needs something
var asked := ""  # the waypoint the step last asked for: back once the advisor's borrowed one has done its work
var _aboard := false  # the hero is in the rover: boarding fills the suit
var _devil := false  # a dust devil is on the hero now: its first touch dusts the suit, once


func _ready() -> void:
	# the project keeps its folder name, the user:// folder where each device saves its settings
	DisplayServer.window_set_title("Outpost Gale")
	tuning = JSON.parse_string(FileAccess.get_file_as_string("res://data/tuning.json"))
	Controls.register(tuning.input.stick_deadzone)
	design = _design(SKIES[0])
	# one rig for the whole sol: the day's materials, with the night's lamps and real sky, turned by the clock. Its
	# stars run on the clock's own seconds (timeScale 1)
	var night := _design("design.night")
	design.lighting.lamp = night.lighting.lamp
	design.lighting.celestial = night.lighting.celestial.duplicate()
	design.lighting.celestial.timeScale = 1
	Forge.HouseStyle.apply_lighting(self, design)
	# this device's last choice (ui/settings.gd), else the preset for it: `phone` on a phone (the A16)
	var saved := Settings.saved()
	quality = saved.get("level", "")
	if not design.quality.has(quality):
		quality = Forge.HouseStyle.default_quality(design)
	overrides = saved.get("overrides", {})
	Forge.HouseStyle.set_quality(self, design, quality, overrides)
	world.build(design)
	var s: Dictionary = world.landmark("spawn")
	player.bound = world.bound()
	for id: String in world.data.rooms:
		if world.items.has(id):  # skips the _note
			player.rooms[id] = {"node": world.items[id], "areas": world.data.rooms[id]}
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
	cover = Cover.new()
	top.add_child(cover)
	settings = Settings.new()
	add_child(settings)
	settings.setup(self)
	clock = SkyClock.new()
	clock.name = "SkyClock"
	add_child(clock)
	var keys := {}
	for k: String in SKIES:
		keys[k] = _design(k)
	clock.setup(self, world, design, keys, tuning.sky)
	clock.phase_changed.connect(func(state: String) -> void:
		sky = SKIES.find(state)
		audio.sky(state, clock.hour() >= 12.0))  # the sun going down has its music; the sunset key leads at dawn too
	interactions.used.connect(clock.used)  # a tilted panel sheds its dust
	sky = SKIES.find(clock.state)
	# the tools want repeatable pictures: the hour stays put in a tool run, and `hour=H` pins it anywhere
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--forge-job="):
			clock.pinned = true
		elif a.begins_with("hour="):
			clock.pinned = true
			clock.set_hour(float(a.trim_prefix("hour=")))
			clock.refresh()
	_wire()
	_warm()
	for n: Node3D in world.items.values():
		if n.is_in_group("vehicle") or n.is_in_group("carriable"):
			_netted.append(n)  # the rover, PIP, the bags
	Forge.register(self)


func _process(_delta: float) -> void:
	# time waits while the player cannot act: the look clock and the rules alike
	clock.paused = settings.is_open() or cover.visible or hud.is_open() or hud.map_open()
	# the beats wait behind the loading cover: the opening's walk-out ran out of time under it and the next beat shut
	# the hatch on the hero (14 Nov playtest)
	beats.process_mode = Node.PROCESS_MODE_DISABLED if cover.visible else Node.PROCESS_MODE_INHERIT
	# a menu or an overlay is up: the cursor shows and a click cannot capture it; play takes it back (14 Nov playtest:
	# the cursor hidden over Settings and the map)
	if overlay() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# up all night: the sky waits at dawn with the rules. A sleep (or its picker), a trip and the launch own the hour
	clock.paused = clock.paused or sim.sim.awake_left() <= 0.0 or cine.holds_time()
	sim.paused = clock.paused or lost  # one time: the rules run exactly when the sky does, at its pace (sim.pace)
	hud.visible = not settings.is_open()
	(fps_label.get_parent() as CanvasLayer).visible = not film  # the HUD, PIP's words and the frame-rate line
	# empty when nothing is in reach (the HUD draws its own E key), and through a cinematic: the bed's "Sleep" stood
	# over the night's time-lapse (15 Nov playtest)
	# with the hold's ring: empty on a thing that needs E held, filling while it is (interactions.hold_shown())
	hud.show_prompt("" if cine.busy() else interactions.prompt_label.text.trim_prefix("[E]  "), interactions.hold_shown())
	# worn out (the rules' `weak`: low Crew health, an empty gauge): no hurry, a slower walk (player.gd weak)
	player.weak = sim.sim.weak() if sim.sim.has_method("weak") else 0.0
	if not cine.busy():
		world.room_shadow(player.room != "")  # indoors the sun's shadow reaches the room only (world.gd)
	var h := clock.hour()
	fps_label.text = "%d fps  %s  %s %02d:%02d" % [Engine.get_frames_per_second(), quality, clock.phase(), int(h), int(fmod(h, 1.0) * 60.0)]


## The safety net (CONTRACTS.md): a body found under the ground or past world.bound() goes back on top at the nearest
## spot inside. The bound and the braking keep everything on the real ground, so this is for what nobody foresaw (a
## body pushed through a floor). The hero moves behind a short fade when that is far, so no teleport shows.
func _physics_process(_delta: float) -> void:
	# behind the shelter's water walls the rules halve the dose (sim shelter knob)
	var inside: bool = player.room == "shelter"
	if inside != bool(sim.sim.knobs.sheltered):
		sim.apply("shelter_in" if inside else "shelter_out")
	# the body (design/plans/core-loop-contracts.md): out of every room and the rover the suit's air runs down, a
	# hurry on foot costs more of it, and a dust devil's first touch coats the suit
	var rules: Object = sim.sim
	var out: bool = player.room == "" and player.vehicle == null
	rules.eva(out)
	rules.effort = rules.n("body", "effort_hurry") if player.hurrying_on_foot() else 1.0
	# the rover's cab has its own air: boarding tops the suit up, so a trip's walk at the far end starts full (the only
	# other air points are in the buildings, 8.8 km behind at Mont Mercou)
	if player.vehicle != null and not _aboard and rules.knobs.body:
		sim.use("refill_air")
	_aboard = player.vehicle != null
	var near: bool = out and world.dust.devil_near(player.body.global_position)
	if near and not _devil:
		rules.dust_hit()
		advisor.devil = true
	_devil = near
	if player.vehicle == null:
		var p: Vector3 = player.body.global_position
		var to := _net(p)
		if to != p:
			rescued += 1
		if to.distance_to(p) > float(world.data.bound.fade_over):
			_flash()
			player.place(to, -rad_to_deg(player.yaw))
		elif to != p:
			player.body.global_position = to
			player.body.velocity.y = maxf(player.body.velocity.y, 0.0)
	for n: Node3D in _netted:
		if n.get_parent() == world or n.is_in_group("vehicle"):  # a bag in the hands rides the hero
			var to := _net(n.global_position)
			if to != n.global_position:
				rescued += 1
				n.global_position = to


## The nearest spot to `p` inside world.bound(), lifted onto the ground when it is under it by more than `below`.
func _net(p: Vector3) -> Vector3:
	var r: Rect2 = world.bound(0.0, p)  # the base, or the field site the hero is at
	var q := Vector2(p.x, p.z).clamp(r.position, r.end)
	var ground: float = world.height_at(q.x, q.y)
	if q == Vector2(p.x, p.z) and p.y >= ground - float(world.data.bound.below):
		return p
	return Vector3(q.x, maxf(p.y, ground), q.y)


func _flash() -> void:
	cover.color = Color(Color.html(design.colors.surface), 1.0)
	cover.visible = true
	var t := create_tween()
	t.tween_property(cover, "color:a", 0.0, float(world.data.bound.fade_s))
	t.tween_callback(func() -> void: cover.visible = _warming)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("film"):
		set_film(not film)  # before the shot check: a cinematic is what gets filmed
		return
	if cine.busy() or lost:
		return  # E mid-shot would take the hero out of the rover; after a loss a sleep would heal a crew called home
	if e.is_action_pressed("interact"):
		interactions.interact()  # out of the rover, put down the bag, or use what is in reach
	elif e.is_action_pressed("fullscreen"):
		settings.full_screen()
	# the debug keys only in a debug run: G beside WASD steps a playtester up to Max unasked (a Mac at 21 fps, 14 Nov)
	elif not OS.is_debug_build():
		return
	elif e.is_action_pressed("debug_sky"):
		clock.skip()  # a short time-lapse to the next phase: dawn, noon, dusk, night, a storm
	elif e.is_action_pressed("debug_quality"):
		var levels: Array = design.quality.keys()
		set_graphics(levels[(levels.find(quality) + 1) % levels.size()], {})
	elif e.is_action_pressed("debug_teleport"):
		var names: Array = world.data.landmarks.keys()
		hop = (hop + 1) % names.size()
		var l: Dictionary = world.landmark(names[hop])
		player.place(l.pos, l.yaw)


## A clean picture for a screen recording: no HUD, no frame-rate line, no touch controls. P or Settings, Demo.
func set_film(on: bool) -> void:
	film = on
	player.touch.visible = not on and DisplayServer.is_touchscreen_available()


func _design(name: String) -> Dictionary:
	var file := "res://%s.json" % name
	return Forge.HouseStyle.load_design(file if FileAccess.file_exists(file) else "res://design.json")


## The clock straight to where SKIES key `i` is the whole look (tests, captures): day at noon, the sunset at its own
## sun, the night at its own hour, the storm at noon. The probes redraw behind the cover.
func _sky(i: int) -> void:
	clock.jump(SKY_PHASES[i % SKIES.size()])
	_warm()


## A preset with the player's knobs on top (CONTRACTS.md, Graphics settings). `restyle` for a knob the world reads
## (trail, particles, ground), `warm` for one that compiles shaders: the cover hides the compile.
func set_graphics(level: String, over: Dictionary, restyle := true, warm := true) -> void:
	quality = level
	overrides = over
	if warm:
		# the cover is drawn before the switch, which can stall for seconds while shaders compile (13 Nov playtest:
		# "not responding"): the player sees the bar, not a frozen frame
		_cover_up()
		cover.progress(0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		if quality != level or overrides != over:
			return  # a later switch came in while this one waited; it puts its own on
	Forge.HouseStyle.set_quality(self, design, quality, overrides)
	if restyle:
		_restyle()
	if warm:
		_warm()


## PIP's warnings while a sol's tasks run late (skills/guided-tutorial row 6): at the deadline's hours of the day the
## kid woke on, and at the rules' hold before the next wake. A storm outside gets its own two, once a day each: the dark
## and the panels (rows 16, 183, 210).
func _warn(st: Dictionary) -> void:
	var r: Object = sim.sim
	var day: int = r.woke_sol
	var hour: float = r.local_hour() + (24.0 if int(st.sol) > day else 0.0)  # past midnight is still the same day
	var says: Array[String] = []
	if not beats.sequence.is_empty() and not beats.may_sleep():
		var due := ""  # only the latest hour passed: a day that starts late does not hear the earlier ones
		for w: Array in deadline.get("warn", []):
			if hour >= float(w[0]):
				due = w[1]
		if r.awake_left() <= 0.0:
			due = deadline.get("dawn", "")
		says.append(due)
	if float(st.tau) > float(r.n("power", "tau_clear")) * 3.0 and player.room == "" and not player.vehicle:
		says.append_array(["storm.dark", "storm.panels"])
	for id: String in says:
		var key := "%d:%s" % [day, id]
		if id != "" and not warned.has(key):
			warned[key] = true
			beats.aside(id)
			return  # one at a time: the next comes on the next state


## A one-off hint from PIP outside the beats (the helmet lights, the autopilot): said, then gone by itself. Left to
## hud.say() alone it stayed for good, since only the next line clears the bubble and free play has none (15 Nov
## playtest: the autopilot's line still up after getting out of the rover). The step's own line comes back after it.
func _hint(id: String, keys: Array) -> void:
	hud.say(id, {"keys": keys})
	_unsay(id)


## PIP's line `id` goes after its few seconds, unless PIP has said something else since.
func _unsay(id: String) -> void:
	await get_tree().create_timer(HINT_S, false, true).timeout
	if hud.bubble.line_id != id:
		return  # PIP has said something else since
	if beats.beat.has("line"):
		hud.say(beats.beat.line, {"keys": beats.beat.get("keys", []), "fact": beats.beat.get("fact", false)})
	else:
		hud.clear_line()


## A menu or an overlay is up: the cursor is the player's, and a click does not capture it (follow_cam.may_capture).
func overlay() -> bool:
	return settings.is_open() or cover.visible or hud.is_open() or hud.map_open() or cine.picker.visible


## A meter at 0 is the end, PG (design/story.md section 3): Mission Control calls the crew home and the card shows the
## three choices that cost most (sim.top_causes), or what ran out when no choice did. Never a silent 0% (14 Nov
## playtest: Sol 39 with life support at 0% and nothing happening).
func _lose(failing: Array) -> void:
	lost = true
	beats.skip()
	var causes: Array = sim.sim.top_causes(3)
	if causes.is_empty():
		causes = failing.map(func(k: String) -> String: return "%s ran out" % Hud.KEYS.get(k, ["", k])[1])
	# the button says what it does: with no morning saved yet (Sol 1) it starts the mission again
	hud.show_causes(causes, "Start again" if Save.read().is_empty() else "Try this sol again")


## The scene again from `saved`, a checkpoint (the lost card's "Try this sol again": this morning, as Continue), or
## from Sol 1's opening when it is empty (no morning saved yet; the report's "Play again"), as the start menu does.
func _restart(saved: Dictionary) -> void:
	Save.pending = saved
	get_tree().reload_current_scene()


## The end of what there is to play (Mission 1, Sols 1 to 10): black, a few warm words, and one button (a tap, a click,
## Enter or Space) back to the start menu. The world stops behind it, so no meter runs out under it and PIP stays quiet.
func end_screen() -> void:
	if ended:
		return
	beats.skip()
	ended = ColorRect.new()
	ended.color = Color.BLACK
	ended.theme = Hud.THEME
	ended.process_mode = Node.PROCESS_MODE_ALWAYS
	ended.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := Button.new()
	back.text = hud.line("end.back")
	back.icon = load("res://ui/icons/next.svg")
	back.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	back.custom_minimum_size = Vector2(280, Hud.BUTTON_H)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().paused = false  # a pause outlives the scene
		get_tree().change_scene_to_file("res://ui/boot.tscn"))
	var words := Hud.col([], 20)
	for id: String in ["end.title", "end.body", "end.thanks"]:
		var l := Hud.label(hud.line(id), "Title" if id == "end.title" else "", true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 480
		words.add_child(l)
	words.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(words)
	ended.add_child(center)
	cover.get_parent().add_child(ended)  # over the cover too: a Continue lands here while the scene still warms
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back.grab_focus.call_deferred()  # after the report card's own close lets go of the focus
	get_tree().paused = true


## The story's word to the rules (cine/beats.gd `rule`: a beat's do apply:<choice>, event:<event>, report:<id>).
func _rule(id: String) -> void:
	var arg := id.get_slice(":", 1)
	match id.get_slice(":", 0):
		"apply":
			sim.apply(arg)
		"event":
			sim.start(arg)
		"report":
			if not lost:
				var book: Dictionary = hud.handbook.state()
				hud.show_report({"title": "report.title", "lines": ["report.line1", "report.line2", "report.line3"],
					"meters": {"power": hud.meters.power.value, "life": hud.meters.life.value, "health": hud.meters.health.value},
					"causes": sim.sim.top_causes(3), "pages": [book.unlocked.size(), book.total]})


## The power panel's card (used("panel")): one row for each switch, to flip it from where it stands now, with what
## that gains and costs, and "Leave it". It is an offer like the story's (`offers`), so hud.chosen applies it.
func _panel() -> void:
	var options: Array = []
	for dev: String in PANEL:
		var on: Dictionary = sim.sim.d.choices.get(PANEL[dev][0], {}).get("set", {})
		var is_on: bool = not on.is_empty() and on.keys().all(func(k: String) -> bool: return sim.sim.knobs.get(k) == on[k])
		var to := "off" if is_on else "on"
		if sim.sim.d.choices.has(PANEL[dev][1 if is_on else 0]):
			options.append({"text": "panel.%s.%s" % [dev, to], "gain": "panel.%s.%s_gain" % [dev, to],
				"lose": "panel.%s.%s_lose" % [dev, to], "apply": [PANEL[dev][1 if is_on else 0]]})
	options.append({"text": "panel.close"})
	offers["panel"] = {"title": "panel.title", "options": options}
	hud.offer_choice("panel.title", options)


## The Today list: what the hero or the base needs now on top, marked urgent, then the day's own tasks. While PIP's
## waypoint is on a need's fix and more needs wait, its label names them too ("Drink water, then Eat a meal"; 15 Nov
## playtest: thirsty and hungry, the waypoint said "Drink" alone).
func _tasks() -> void:
	var needs: Array = advisor.tasks.map(func(fix: String) -> Dictionary:
		return {"label_id": "need.task." + fix.trim_prefix("use:"), "state": "urgent"})
	hud.set_tasks(needs + beats.tasks())
	var fix: String = advisor.NEEDS.get(advisor.goal, "")
	if fix == "" or hud.objective != fix:
		return
	_point(fix)  # its own name back, when the others have cleared
	var rest: Array = needs.filter(func(n: Dictionary) -> bool: return n.label_id != "need.task." + fix.trim_prefix("use:"))
	var first: String = hud.line("need.task." + fix.trim_prefix("use:"))
	if rest.size() == 1:
		hud.waypoint.rename(hud.line("need.then") % [first, hud.line(rest[0].label_id)])
	elif rest.size() > 1:
		hud.waypoint.rename(hud.line("need.more") % [first, rest.size()])


## The bed asks (cine.gd): no sleep with this room's door open, the air would go out all night. PIP says so, kindly,
## and the waypoint goes on the door; shut, it lets go (the `used` wiring) and the bed works. A refusal with a
## warning, not a loss in the morning: a kid learns from the warning (15 Nov playtest).
func may_sleep() -> bool:
	for part: Node3D in world.items[player.room].get_meta("parts") if world.items.has(player.room) else []:
		var it: Node3D = interactions.by_thing.get(part)
		if it and it.kind == "door" and it.open:
			advisor.say.call("need.door")
			hud.set_objective_node(it, "need.task.door", "door")
			return false
	return true


## The waypoint on `t`: "" for none, "pip", a landmark, an item, or use:<kind> for the nearest spot of that kind.
func _point(t: String) -> void:
	if t == "":
		hud.clear_objective()
	elif t in ["rover", "reactor"] and world.items.has(t):
		# the rover itself, wherever it stands now, before the landmark of the same name (its parking spot): a kid who
		# had driven it somewhere was sent to the empty parking place, "Rover 2 m" over bare ground (15 Nov playtest:
		# "the game itself cannot identify where the rover is"). Boarded at its rear hatch, so the waypoint stands
		# on the hatch, not on its middle, where it led a kid to the nose and no prompt. The reactor's landmark is a
		# viewpoint 21 m short of it: Sol 2's step asks the kid to stand at the reactor itself (15 Nov playtest)
		hud.set_objective_node(interactions.by_thing.get(world.items[t], world.items[t]), "", t)
	elif t.begins_with("use:"):
		# the thing a step asks the kid to use, wherever the kid is: the nearest spot of that kind that can be used
		# now, named by its own prompt. PIP said "press E" for things a building away (15 Nov playtest: "pressing E
		# outside does nothing", the radio to ask Earth a question)
		var best: Node3D = null
		for it: Node3D in interactions.by_thing.values():
			if it.kind == "spot" and it.row.kind == t.trim_prefix("use:") and it.can_use(player.body) \
					and (best == null or it.global_position.distance_to(player.body.global_position) < best.global_position.distance_to(player.body.global_position)):
				best = it
		if best:
			hud.set_objective_node(best, String(best.row.get("prompt", t)), t)
	elif t == "pip" or world.data.landmarks.has(t):
		hud.set_objective(t)
	elif world.items.has(t):
		hud.set_objective_node(world.items[t], "", t)


## Every shader the scene can show compiles now, behind the cover, not on its first sight in play (the web build keeps
## no shader cache: skills/frame-budget). The stage stands inside the reflection probe, so the probe's variants
## compile too, and the hero's fade copy is drawn with it.
func _warm() -> void:
	_cover_up()
	if _warming:
		_rewarm = true  # a second switch while the first warms: once more when it ends
		return
	_warming = true
	# the hero's two shaders: the fade, and the solid one, which no mesh wears while the hero is hidden (the opening
	# starts in HAB 1 with the lens close: its first sight at the hatch was a 0.5 s compile in play, 14 Nov)
	var fade := ShaderMaterial.new()
	fade.shader = player.fading
	var solid := ShaderMaterial.new()
	solid.shader = player.HeroShader
	var at := _probe_view()
	world.dust.warm(at * Vector3(0, 0, -8))
	cover.progress(0.0)
	await Forge.HouseStyle.warm(self, design, at, [fade, solid], 3, cover.progress)
	while _rewarm:
		_rewarm = false
		await Forge.HouseStyle.warm(self, design, at, [fade, solid], 3, cover.progress)
	_warming = false
	var t := create_tween()
	t.tween_property(cover, "color:a", 0.0, 0.25)
	t.tween_callback(func() -> void:
		cover.visible = _warming
		if not _warming:
			cover.finish()
			audio.lift())  # silent until the player first sees the base


func _cover_up() -> void:
	cover.color = Color.html(design.colors.surface)
	cover.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # nothing to look at behind it


func _restyle() -> void:
	world.restyle(design)
	player.restyle(design)
	if clock:
		clock.restyled()  # the world's lamps, probes' ambient and weather follow the hour again


## True while the cover is up (Forge waits for it before a picture).
func busy() -> bool:
	return cover.visible


## Sol 1 as a person starts it: the hour shortly before sunrise (cine.dawn_hour(), the sky and the rules alike, and
## running from the first frame), then PIP's beats.
func start_opening() -> void:
	clock.set_hour(clock.hours - clock.hour() + cine.dawn_hour())
	clock.refresh()
	_sync_rules()
	beats.start_opening()


## The morning's checkpoint (sandbox/save.gd), written as a night's sleep starts sol `sol`'s beats: the rules, the
## handbook and the few flags here that last across days. Taken before that sol's first beat runs, so Continue starts
## the beat on the same numbers (Sol 6's first beat sleeps three quiet sols on). Never after the mission is lost: the
## last good morning stays, to try again from.
func checkpoint(sol: int) -> void:
	if not lost:
		Save.write({"version": Save.VERSION, "sol": sol, "sim": sim.save(), "handbook": hud.handbook.save(),
			"warned": warned, "lamp_hinted": lamp_hinted, "trip_km": trip_km, "storm": clock.storm_on})


## Continue (ui/start.gd): the checkpoint's morning in place of the opening. The flags, the hero where the opening
## wakes it (in HAB 1, so the rules' first word finds nobody out in a storm), the rules, the sky at the rules' hour
## with its storm, the handbook, then that sol's beats. The world is a fresh morning's.
func _resume() -> void:
	if int(resume.sol) > Save.LAST_SOL:
		end_screen()  # a morning saved past Mission 1 by an older build: those sols are not finished
		return
	warned = resume.get("warned", {})
	lamp_hinted = resume.get("lamp_hinted", false)
	trip_km = resume.get("trip_km", trip_km)
	beats._do("hero:airlock")
	sim.load(resume.sim)
	if not (resume.sim.knobs as Dictionary).has("body"):
		sim.apply("body_on")  # a morning saved before the body's rules (15 Nov): past Sol 1's lesson, so they run
	clock.storm_on = resume.get("storm", false)
	clock.storm = 1.0 if clock.storm_on else 0.0
	clock.set_hour(clock.hours - clock.hour() + sim.sim.local_hour())
	clock.refresh()
	hud.load_handbook(resume.handbook)
	beats.start_sol(int(resume.sol))


## The warm-up's camera: inside the base's reflection probe, looking at HAB 1, so HAB 1's and the greenhouse's room
## probes are in view and get drawn (the base turned to face the sunrise, 14 Nov: looking north missed them).
func _probe_view() -> Transform3D:
	var p: Vector3 = world.get_node("Probe").global_position
	var hab: Vector3 = world.items.hab1.global_position
	return Transform3D(Basis.looking_at(Vector3(hab.x - p.x, 0.0, hab.z - p.z)), p)


## One time for the sky and the HUD: the rules take the look clock's hour of the sol (the rules count Earth hours
## through a 24.66 h sol, the look 24 local hours).
func _sync_rules() -> void:
	sim.sim.hour = clock.hour() * sim.sim.n("clock", "sol_h") / 24.0


func render_game_to_text() -> Dictionary:
	var s: Dictionary = player.state()
	s.merge(interactions.state(), true)
	s.merge(cine.state())
	s["hud"] = hud.snapshot()
	s["sim"] = sim.sim.state()
	s.merge(audio.state())
	if pip:
		s.merge(pip.state_text())
	s.merge({"sky": clock.report(), "quality": quality, "fps": Engine.get_frames_per_second(), "view": view})
	return s


func place(pos: Vector3, yaw_deg: float) -> void:
	pos.y = world.height_at(pos.x, pos.z) + maxf(pos.y, 0.0)
	player.place(pos, yaw_deg)


func set_view(v: String) -> void:
	if "@" in v:  # "base@18.2": the view at that local hour, pinned (a sol of captures)
		clock.pinned = true
		clock.set_hour(float(v.get_slice("@", 1)))
		clock.refresh()
		set_view(v.get_slice("@", 0))
		_warm()  # the probes redraw under the new sky, then hand back the camera this view chose
		return
	view = v
	if v == "settings":
		settings.open()  # over the play view, for a picture of it
		return
	if ROOM_VIEWS.has(v):
		var f: Array = ROOM_VIEWS[v]
		var item: Node3D = world.items[f[0]]
		$ViewCam.current = false
		player.place(item.to_global(f[1]), -rad_to_deg(item.global_rotation.y) + float(f[2]))
		player.cam.pitch = deg_to_rad(f[3])
		return
	if v in world.data.views and v != "_note":  # [item, from, at] in the item's own space (data/world.json views)
		var r: Array = world.data.views[v]
		var item: Node3D = world.items[r[0]]
		$ViewCam.look_at_from_position(item.to_global(Vector3(r[1][0], r[1][1], r[1][2])), item.to_global(Vector3(r[2][0], r[2][1], r[2][2])))
		$ViewCam.current = true
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


## The game's parts plugged together: the rules, the HUD, PIP's beats and the cinematics (design/plans/event-ready.md).
## Each part owns its folder; this is the only place they meet.
func _wire() -> void:
	sim = SimNode.new()
	sim.name = "Sim"
	add_child(sim)
	hud = GameHud.instantiate()
	var layer := fps_label.get_parent() as CanvasLayer
	layer.layer = 101  # over settings (100) so its docked gear shows; hidden while settings is open; under the cover (128)
	layer.add_child(hud)
	fps_label.get_parent().move_child(fps_label, -1)
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)  # the minimap owns the top right now
	fps_label.offset_top = -40
	fps_label.offset_left = 12
	fps_label.offset_right = 460
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	interactions.prompt_label.visible = false
	sim.pace = clock.pace
	_sync_rules()
	hud.bind(sim)
	hud.bind_view(player.cam.lens, player.body)
	player.cam.may_capture = func() -> bool: return not overlay()
	# the kid's own map mark (ui/components/full_map.gd): a beacon in the world, and an event for the beats
	beacon = MeshInstance3D.new()
	beacon.name = "MarkBeacon"
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.12
	pillar.bottom_radius = 0.12
	pillar.height = 40.0  # over the habitats and the crater's dust from across the base (art direction)
	pillar.radial_segments = 8
	beacon.mesh = pillar
	beacon.material_override = Forge.HouseStyle.role(design, "light")
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	world.add_child(beacon)
	hud.marked.connect(func(at: Variant, id: String) -> void:
		beacon.visible = at != null
		if at == null:
			return
		var p: Vector2 = at
		var half := float(world.data.play_half)
		var ground: float = world.height_at(p.x, p.y) if absf(p.x) < half and absf(p.y) < half else 0.0
		beacon.global_position = Vector3(p.x, ground + pillar.height * 0.5, p.y)
		beacon.visible = absf(p.x) < half and absf(p.y) < half  # a far site is beyond the camera's reach: the compass points
		beats.notify("waypoint_set")
		if id != "":
			beats.notify("waypoint_set:" + id))
	if pip:
		hud.bind_speaker(pip, player.cam.lens)
	hud.cue.connect(audio.ui)
	settings.cue.connect(audio.ui)
	hud.dock_gear(settings.gear)
	# only the ids the rules know reach them: `used` also carries sound names (door_open, bag)
	var uses: Dictionary = sim.sim.d.uses
	interactions.used.connect(func(what: String, _pos: Vector3) -> void:
		if uses.has(what):
			sim.use(what))
	beats = Beats.new()
	beats.name = "Beats"
	add_child(beats)
	beats.setup(world, player, interactions, clock)
	interactions.used.connect(beats.used)
	beats.line.connect(hud.say)
	# free time: PIP's "sleep when you're ready" does not hang over the bed's own prompt (14 Nov playtest)
	beats.beat_done.connect(func(id: String) -> void:
		if id == "sleep_hint":
			hud.clear_line())
	beats.finished.connect(func(_s: String) -> void: hud.clear_line())  # PIP's last "This way!" stayed up for good
	offers = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).get("offers", {})
	offers.erase("_note")  # a string: the chosen handler below called .get() on it and a click on a choice did nothing
	beats.page.connect(hud.unlock_page)
	beats.check_offered.connect(hud.offer_check)
	hud.checked.connect(func(id: String) -> void: beats.notify("checked:" + id))
	# the options go as they are (text, gain, lose), with the offer's handbook pages
	beats.choice_offered.connect(func(id: String) -> void:
		var o: Dictionary = offers.get(id, {})
		hud.offer_choice(o.get("title", id), o.get("options", []), o.get("pages", [])))
	hud.chosen.connect(func(title: String, index: int) -> void:
		for id: String in offers:
			if offers[id].get("title", id) == title:
				var picked: Dictionary = offers[id].options[index]
				for rule: String in picked.get("apply", []):
					sim.apply(rule)
				# what moved, in words: the rules' own answer is numbers no kid reads (15 Nov audit)
				if not picked.get("apply", []).is_empty():
					hud.alert(hud.line(picked.text), hud.line(picked.lose) if picked.has("lose") else "")
				if id == "panel":
					return  # the power panel's own card: no step waits for it, and it is no decision for the log
				var said: String = picked.get("text", "")
				hud.log_decision(hud.lines.get(title, title), hud.lines.get(said, said))  # the words, as the card showed them
				beats.notify("chose:" + id))
	cine = Cine.new()
	cine.name = "Cine"
	add_child(cine)
	cine.setup(self)
	cine.slept.connect(func(kind: StringName, _hours: float) -> void:
		if lost:
			return  # no sleep counts after a loss: it heals, and the lost mission would run on
		sim.use("sleep_night" if kind == &"night" else "nap")
		# the rules count the lapse in Earth hours; the HUD takes the sky's minute after it. Never across a midnight
		# (a field trip's sols), never a tool's pinned hour
		if not clock.pinned and absf(sim.sim.local_hour() - clock.hour()) < 0.5:
			_sync_rules())
	cine.slept.connect(func(_kind: StringName, _hours: float) -> void:
		world.regrow(sim.sim.sol, sim.sim.n("crop", "ready_days")))  # cut lettuce grows back on the rules' sols
	# a night's sleep ends the sol's beats and starts the next sol's (data/sols.json), once the lapse is over and the
	# rules have counted the new sol (the connection above runs first). The next is the key after the one just played,
	# never the rules' sol alone: a sol with no beats (7, 8) slept into must not jump over the story's next day
	cine.slept.connect(func(kind: StringName, _h: float) -> void:
		if kind != &"night":
			return
		while cine.busy():
			await get_tree().process_frame
		if lost:
			return  # the night ran a meter out: the lost card stays, and no new day starts under it
		# up an hour or more late (a late bedtime still gets a full night, sim.json sleep_h): a calm note saying when, so
		# the later clock makes sense. Not an alert, and not for a few minutes: it showed red after every night (15 Nov)
		if sim.sim.hour > sim.sim.n("clock", "wake_hour") + 1.0:
			var h := sim.sim.local_hour()
			hud.notice(hud.line("sleep.woke_late") % ("%02d:%02d" % [int(h) % 24, int(fposmod(h, 1.0) * 60.0)]), 8.0)
		beats.notify("slept")
		await get_tree().physics_frame
		await get_tree().physics_frame
		var next := beats.next_sol()
		if next < 0:
			# Mission 1 is all there is to play (beats.LAST_SOL): its report, then the end screen. No checkpoint, so
			# Continue still offers Sol 10's morning
			over = true
			_rule("report:mission1")
			return
		if sim.sim.sol < next:
			sim.skip_sols(next - sim.sim.sol)  # the rules catch up, so the HUD's sol is the story's
			if lost:
				return
		checkpoint(next)
		beats.start_sol(next))
	cine.arrived.connect(func(l: String) -> void:
		hud.set_mark(null)  # the kid's pin was for the place left behind: at the other end of a trip it pointed nowhere
		player.bound = world.bound(0.0, player.body.global_position)
		beats.notify("arrived:" + l))
	beats.trip.connect(func(l: String) -> void:
		var site: Dictionary = world.data.sites.get(l.trim_prefix("site_").trim_suffix("_rover"), {})
		if site.has("km"):
			trip_km = float(site.km)  # the trip home shows the same distance
		cine.trip_to(l, {"sol": sim.sim.sol, "km": trip_km}))
	beats.liftoff.connect(cine.launch)
	cine.launched.connect(func() -> void: beats.notify("launched"))
	# the tutorial: PIP's beats drive the Today list, the waypoint and the camera shots; the HUD and the shots answer
	beats.task.connect(func(_id: String) -> void: _tasks())
	advisor.listed = _tasks
	# the step's own waypoint wins over one PIP borrowed for a need, and is kept for when a later one lets go
	beats.objective.connect(func(t: String) -> void:
		asked = t
		advisor.goal = ""
		_point(t))
	advisor.say = func(id: String) -> void:
		beats.aside(id)
		if id in ["need.dusty", "need.devil"]:
			hud.unlock_page("toxic_dust")  # the first dusty suit is where the kid meets it; no step says it before
		if not beats.beat.has("line"):
			_unsay(id)  # free time: no step's line comes back over it, and it would stay up for good
	advisor.point = func(t: String) -> void: _point(t if t != "" else asked)
	advisor.dusty = sim.sim.n("body", "dusty")
	for k: String in ["o2_kg", "water_kg", "food_kg"]:
		advisor.stock[k] = sim.sim.n("start", k)
	# used: its waypoint has done its work, the step's and PIP's alike
	interactions.used.connect(func(what: String, _pos: Vector3) -> void:
		if asked == "use:" + what:
			asked = ""
		if hud.objective == "use:" + what:
			hud.clear_objective()
		advisor.used(what)
		if what == "door_close" and hud.objective == "door":
			_point(asked)  # the door the bed asked for is shut: the step's own waypoint again
		if what == "panel" and not hud.is_open():
			_panel())
	beats.rule.connect(_rule)
	hud.report_closed.connect(func(again: bool) -> void:
		if again:
			_restart({})  # Play again: a fresh mission
		elif over:
			end_screen()  # after Sol 10 there is nothing more to keep going to
		else:
			beats.notify("report_closed"))  # Keep going: the story runs on
	hud.dismissed.connect(func(_id: String) -> void: beats.notify("dismissed"))
	hud.map_toggled.connect(func(open: bool) -> void: beats.notify("map_open" if open else "map_closed"))
	beats.shot.connect(cine.shot)
	cine.shot_done.connect(func(n: String) -> void: beats.notify("shot_done:" + n))
	# the sols past the first (data/sols.json): Earth's mail, the rules' events, quiet sols skipped with the ledger
	beats.send_mail.connect(hud.send_mail)
	hud.cue.connect(func(n: String) -> void:
		if n == "mail":
			beats.notify("mail_arrived"))
	sim.changed.connect(func(st: Dictionary) -> void:
		# the loss first, before anything else acts on the state (a sleep heals even at health 0)
		if not st.failing.is_empty() and not lost:
			_lose(st.failing)
		for e: Dictionary in st.events:
			beats.notify("event:" + String(e.id))
		if not advisor.feed(st, overlay() or cine.busy() or lost):
			_warn(st))  # one line at a time: the storm's and the deadline's wait for the next state
	deadline = JSON.parse_string(FileAccess.get_file_as_string("res://data/sols.json")).get("deadline", {})
	hud.retry.connect(func() -> void: _restart(Save.read()))  # this morning again; none saved yet (Sol 1): the start
	player.lamps_changed.connect(func(on: bool, auto: bool) -> void:
		if on and auto and not lamp_hinted:
			lamp_hinted = true
			_hint("hint.suit_lights", ["H"]))
	beats.skip_sols.connect(func(n: int) -> void:
		var ledger := sim.skip_sols(n)
		if not lost:  # a meter that ran out on the way keeps its lost card: the ledger replaced it (15 Nov audit)
			hud.show_ledger(ledger))
	hud.ledger_closed.connect(func() -> void: beats.notify("ledger_closed"))
	# the rover's autopilot (sandbox/rover_pilot.gd): a mark set aboard is where it drives, a cleared one hands the
	# wheel back; it says on the HUD when it takes over and when it lets go
	var auto: RefCounted = preload("res://sandbox/rover_pilot.gd").new(world, tuning.rover.autopilot)
	player.pilot = auto
	auto.busy = cine.busy
	auto.note.connect(func(title: String, text: String) -> void: hud.alert(title, text, "objective_new"))
	hud.marked.connect(func(at: Variant, _id: String) -> void: auto.go(at if player.vehicle else null))
	hud.map_toggled.connect(func(open: bool) -> void: auto.hold = open)
	# PIP teaches it once, the first time the kid sits in the rover with the wheel theirs
	interactions.used.connect(func(what: String, _pos: Vector3) -> void:
		if what != "rover" or auto.hinted:
			return
		await get_tree().create_timer(1.0, false, true).timeout  # a beat may answer the boarding with a trip (Sol 9)
		if player.vehicle and not cine.busy() and not auto.hinted:
			auto.hinted = true
			_hint("hint.autopilot", ["M"]))
	# the opening plays when a person starts the game (through ui/boot.tscn), never in a test script (no current
	# scene) or a tool run (--forge-job)
	if resume.is_empty():
		resume = Save.pending  # _restart(): the lost card's "Try this sol again"
	Save.pending = {}
	if not resume.is_empty():
		_resume.call_deferred()  # Continue: the checkpoint's morning in the opening's place, at the same moment
	elif get_tree().current_scene != null and not Array(OS.get_cmdline_user_args()).any(
			func(a: String) -> bool: return a.begins_with("--forge-job=")):
		start_opening.call_deferred()
