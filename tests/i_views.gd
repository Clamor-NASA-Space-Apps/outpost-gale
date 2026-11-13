extends Node3D
## Close views of the rooms' fit-out (lane I, 13 Nov), around the real sandbox (capture-view --scene):
##   node ../../tools/capture-view.mjs . captures/i --scene res://tests/i_views.tscn --views wc_in,wc_floor,galley,veggie,cab --scale 0.5
## board=open or board=shut: once the game is up, the hero boards the rover through its hatch (interactions.gd), and
## the clock stops with the hatch wide open (the hand on it) or swinging shut behind the hero aboard; with
## --advance 6000 the shots come after that:
##   ... --views hatch,hatch_near -- board=open
## lights=new previews the proposed room lighting (not the game's look until Ravindu approves it): the ceiling
## panels glow warm white instead of the status-light cyan, and the rooms' flat fill (their probe's ambient) drops,
## so light comes from the panels. Views are [item, from, at] in the item's own space; any other name goes to the
## sandbox's own set_view().

const VIEWS := {
	"wc_in": ["hab1", Vector3(-0.95, 1.9, -0.31), Vector3(-2.1, 0.7, -0.68)],  # into the toilet, curtain open
	"wc_floor": ["hab1", Vector3(-1.15, 1.45, -0.37), Vector3(-1.85, 0.4, -0.6)],
	"galley": ["hab1", Vector3(0.55, 1.55, 0.1), Vector3(1.8, 0.6, 0.3)],
	"veggie": ["hab1", Vector3(1.2, 1.75, -0.2), Vector3(1.98, 1.45, -0.29)],
	"bunks": ["hab1", Vector3(0.1, 1.5, 0.1), Vector3(-1.4, 1.2, 1.05)],
	"hatch": ["rover", Vector3(1.9, 2.5, 5.6), Vector3(0.0, 1.5, 1.8)],  # the rear hatch, from behind and to the side
	"hatch_near": ["rover", Vector3(-1.1, 2.1, 3.6), Vector3(0.2, 1.7, 1.8)],
	"cab": ["rover", Vector3(0.45, 2.3, -0.35), Vector3(-0.5, 1.85, -1.4)],  # from the passenger's seat, at the yoke
}
## The proposal's numbers: the lighting.room colour as an LED panel, and the share of the rooms' ambient kept
const LAMP := "#f4efe6"
const LAMP_GLOW := 2.0
const AMBIENT_KEPT := 0.45
const FALLOFF := 2.0  # the room light's omni_attenuation (1 is the engine's): bright under the lamp, dimmer at the walls
const LIGHT_GAIN := 1.6  # its energy, so the floor under it keeps today's brightness

var game: Node3D
var cam := Camera3D.new()
var lights := "now"
var board := ""
var _boarding := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lights="):
			lights = a.trim_prefix("lights=")
		if a.begins_with("board="):
			board = a.trim_prefix("board=")
	game = load("res://sandbox/sandbox.tscn").instantiate()
	add_child(game)
	Forge.register(self)
	process_priority = 100  # after the sky clock, which sets the probes' ambient
	cam.fov = 70.0
	add_child(cam)
	var cur := game.world.items["hab1"].find_child("curtain", true, false) as Node3D
	if cur:
		cur.visible = false  # the toilet's curtain, as if gathered open


func busy() -> bool:
	return game.busy()


func render_game_to_text() -> Dictionary:
	var s: Dictionary = game.render_game_to_text()
	s["lights"] = lights
	# the deck's height over the ground under it, lowest first, around HAB 1's floor: a gap under a few mm lets the
	# ground show through the deck in stripes (the toilet's floor, 13 Nov playtest)
	var hab: Node3D = game.world.items["hab1"]
	var gaps := []
	for r in [0.5, 1.2, 1.8, 2.3]:
		for a in range(0, 360, 15):
			var p: Vector3 = hab.global_transform * Vector3(r * cos(deg_to_rad(a)), 0.4, r * sin(deg_to_rad(a)))
			gaps.append([snappedf(p.y - game.world.height_at(p.x, p.z), 0.001), r, a])
	gaps.sort()
	s["deckOverGround"] = gaps.slice(0, 16)
	return s


func set_view(v: String) -> void:
	if lights == "new":
		_proposal.call_deferred()  # after the view's own restyle, if it made one
	if not VIEWS.has(v):
		game.set_view(v)
		return
	var item: Node3D = game.world.items[VIEWS[v][0]]
	cam.look_at_from_position(item.global_transform * VIEWS[v][1], item.global_transform * VIEWS[v][2])
	cam.current = true


## The ceiling panels drawn again in a warm white glow, 2 mm under the model's cyan ones and a little bigger, so they
## cover them (the model's own are merged with every other `light` part at load); the rooms' probes keep AMBIENT_KEPT
## of their fill (_process: the sky clock sets it again as the hour moves), and each room light falls off faster and
## shines brighter (FALLOFF, LIGHT_GAIN), so the light pools under the panels instead of filling the room evenly.
## In the game this would be a DESIGN.md role (`lamp`) on the panels in the recipes, a lower room ambient and an
## attenuation on the room lights (DESIGN.md lighting.room): the same meshes and lights, one material more. Panels as the recipes place them, in each item's own space:
## HAB 1's four (forge/hab_interior.py, 1.4 m out at 45 + 90k degrees, under the ceiling at 2.72 m), the shelter's one.
func _proposal() -> void:
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color.html(LAMP)
	lamp.emission_enabled = true
	lamp.emission = Color.html(LAMP)
	lamp.emission_energy_multiplier = LAMP_GLOW
	var panels := {"shelter": [[Vector3(0, 2.467, -0.1), 0.0, Vector3(0.845, 0.012, 0.205)]], "hab1": []}
	for k in 4:
		var a := deg_to_rad(45.0 + 90.0 * k)
		panels.hab1.append([Vector3(1.4 * cos(a), 2.688, -1.4 * sin(a)), a, Vector3(0.125, 0.012, 0.705)])
	for id: String in panels:
		var item: Node3D = game.world.items[id]
		if not item.has_meta("lane_i"):
			item.set_meta("lane_i", true)
			for p: Array in panels[id]:
				var box := BoxMesh.new()
				box.size = p[2]
				var mi := MeshInstance3D.new()
				mi.mesh = box
				mi.material_override = lamp
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.layers = 1 << 3  # world.gd ROOMS, where the room light and probe reach
				mi.transform = Transform3D(Basis(Vector3.UP, p[1]), p[0])
				item.add_child(mi)


func _process(_delta: float) -> void:
	if lights != "new":
		return
	for id: String in ["hab1", "shelter"]:
		for p: ReflectionProbe in game.world.items[id].find_children("Probe_*", "ReflectionProbe", false, false):
			if not is_equal_approx(p.ambient_color_energy, p.get_meta("lane_i", -1.0)):  # the clock's own value: cut it
				p.ambient_color_energy *= AMBIENT_KEPT
				p.set_meta("lane_i", p.ambient_color_energy)
		for l: OmniLight3D in game.world.items[id].find_children("RoomLight", "OmniLight3D", false, false):
			if not l.has_meta("lane_i"):
				l.set_meta("lane_i", true)
				l.omni_attenuation = FALLOFF
				l.set_meta("energy", float(l.get_meta("energy", l.light_energy)) * LIGHT_GAIN)  # what the lamp pool fades to
				l.light_energy *= LIGHT_GAIN


func _physics_process(_delta: float) -> void:
	if board == "" or Engine.time_scale < 1.0 or game.busy():
		return
	var box: Node3D = game.interactions
	var rover: Node3D = game.world.items["rover"]
	if not _boarding:
		_boarding = true
		game.place(rover.exit_point() * Vector3(1, 0, 1), 0.0)  # place() puts it on the ground
		box.use(box.by_thing[rover])
		return
	var leaf: Node3D = box._rover_hatch.thing
	var open := absf(leaf.rotation.y - box._rover_hatch.shut.basis.get_euler().y)
	if (board == "open" and open > deg_to_rad(90.0)) or (board == "shut" and game.player.vehicle and box._fade.modulate.a < 0.05 and open > 0.5):
		Engine.time_scale = 0.001  # held here for the shots (at 0 the rover's springs divide by a zero step and its wheels vanish)
