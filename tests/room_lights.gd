extends "res://addons/forge/test.gd"
## Every room is lit by its own light, at noon, at night and in the storm, on every quality preset (14 Nov playtest:
## HAB 1 at night had glowing ceiling panels and no light):
##   godot --headless --path . --fixed-fps 60 -s tests/room_lights.gd          (every preset and sky: the lights' state)
##   xvfb-run -a godot --display-driver x11 --path . --fixed-fps 60 -s tests/room_lights.gd -- pixels   (the laptop
##   preset in each sky, and the floor's pixels too: software GL draws a few frames a second)
## For each room: its RoomLight is visible, at its full energy, on the rooms' layer only, and (pixels) the floor in the
## play view is brighter with it than with it masked off for a frame.

const ROOMS := 1 << 3  # world.gd ROOMS
const VIEWS := {"hab1": "hab_room", "greenhouse": "greenhouse_room", "shelter": "shelter_room"}
const LIFT := 0.02  # the least the light adds to the floor's mean, 0 to 1 per channel


func _init() -> void:
	watchdog = 1800.0


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await _settle(game)
	var pixels := "pixels" in OS.get_cmdline_user_args()
	for sky: int in [0, 2, 3]:  # noon, night and the storm (sandbox SKIES)
		for level: String in (["laptop"] if pixels else game.design.quality.keys()):
			print("  %s, %s" % [game.SKIES[sky], level])
			game.set_graphics(level, {}, true, false)  # no warm-up: a compile in a test only costs time
			game.clock.jump(game.SKY_PHASES[sky])
			game.clock.pinned = true
			await _settle(game)
			for id: String in VIEWS:
				game.set_view(VIEWS[id])
				await frames(45)  # the lamp pool fades a lamp in over half a second
				var l: OmniLight3D = game.world.items[id].get_node("RoomLight")
				var what := "%s, %s, %s" % [id, game.SKIES[sky], level]
				check(l.visible and l.light_energy > 0.0 and l.light_energy >= float(l.get_meta("energy")) * 0.9,
					"%s: the room light is on (visible %s, energy %.2f of %.2f)" % [what, l.visible, l.light_energy, float(l.get_meta("energy"))])
				check(l.light_cull_mask == ROOMS, "%s: the room light reaches the rooms' layer only (mask %d)" % [what, l.light_cull_mask])
				if not pixels:
					continue
				var lit := await _floor(game)
				l.light_cull_mask = 0
				var dark := await _floor(game)
				l.light_cull_mask = ROOMS
				check(lit - dark > LIFT, "%s: the floor is lit by the room light (%.3f with it, %.3f without)" % [what, lit, dark])
	# a night's sleep dims HAB 1's light for the time-lapse (cine.gd _room_light): it is back once the hero is up
	print("  after a night's sleep")
	game.set_view("hab_room")
	await frames(10)
	game.cine.sleep(&"night")
	await frames(5)
	for i in 60 * 120:
		if game.cine.beat == "":
			break
		await frames(1)
	check(game.cine.beat == "", "the sleep ended (beat '%s')" % game.cine.beat)
	await frames(45)
	var hab: OmniLight3D = game.world.items["hab1"].get_node("RoomLight")
	check(hab.visible and hab.light_energy > 0.0 and is_equal_approx(float(hab.get_meta("energy")), float(hab.get_meta("full", hab.get_meta("energy")))),
		"after a sleep HAB 1's light is back at full (energy %.2f, meta %.2f of %.2f)" % [hab.light_energy, float(hab.get_meta("energy")), float(hab.get_meta("full", -1.0))])
	return true


func _settle(game: Node3D) -> void:
	await frames(3)
	while game.busy():
		await frames(1)
	await frames(3)


## The mean of a patch of floor beside the hero, low left of the play view (clear of the hero and the HUD).
func _floor(_game: Node3D) -> float:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	var s := Vector2(img.get_size())
	var sum := 0.0
	var n := 0
	for y in range(int(s.y * 0.72), int(s.y * 0.86), 4):
		for x in range(int(s.x * 0.18), int(s.x * 0.34), 4):
			var c := img.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
			n += 1
	return sum / maxf(n, 1)
