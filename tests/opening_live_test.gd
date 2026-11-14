extends "res://addons/forge/test.gd"
## The opening as a person starts it: through ui/boot.tscn, the main scene, so boot.gd builds the sandbox and
## sandbox.gd starts the real beats and shots in the frame the world is built (beats_test wires its own, three frames
## later). Runs headless, and on a display the same way (xvfb-run -a ... godot --display-driver x11 ... -s this file).
## 14 Nov playtest, twice: the walk-out ran under the loading cover and timed out; then the rover's body, still at the
## origin for the first physics tick, shoved the hero off the airlock spot and the walk out met the wall beside the hatch.
## Since the script went (14 Nov evening): the kid walks out with a real W key, and the sun's first sliver must clear
## the crater rim, straight out of the hatch, 30 to 60 s after the cover lifts (data/cine.json opening).


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	change_scene_to_file("res://ui/boot.tscn")
	# past the team's logo and the start screen (ui/start.gd) as a kid gets past them: any key, then Enter on Start
	while current_scene == null or current_scene.get("start") == null or not current_scene.start.is_inside_tree():
		await process_frame
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	while current_scene.start.splash:
		await process_frame
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	while current_scene == null or current_scene.get("beats") == null:
		await process_frame
	var game: Node = current_scene
	var player: Node = game.player
	var beats: Node = game.beats
	var hab: Node3D = game.world.items.hab1
	var s: Dictionary = beats.data.starts.airlock
	var spot: Vector3 = hab.to_global(Vector3(s.at[0], s.at[1], s.at[2]))
	while game.cover.visible:
		await physics_frame
	# the first playable frame (skills/guided-tutorial rows 2 and 9)
	var at: Vector3 = player.body.global_position
	check(beats.beat.get("id", "") == "wake" and beats._t < 0.1, "the opening waits behind the cover (%s, %.1f s in)" % [beats.beat.get("id", ""), beats._t])
	check(Vector2(at.x - spot.x, at.z - spot.z).length() < 0.1, "the hero wakes on the airlock spot (%.2f m off, at %s)" % [Vector2(at.x - spot.x, at.z - spot.z).length(), at])
	var hatch: Vector3 = hab.to_global(Vector3(0.0, 0.0, -2.2)) - at
	var off := absf(wrapf(atan2(-hatch.x, -hatch.z) - player.yaw, -PI, PI))
	check(off < deg_to_rad(15.0), "facing the hatch (%.0f deg off)" % rad_to_deg(off))
	# the view itself, at the real start: a camera that is nowhere drew sky from every side (15 Nov playtest)
	var lens: Camera3D = root.get_viewport().get_camera_3d()
	var from: Vector3 = at + Vector3.UP * float(player.cam.eye.y)
	check(lens.global_position.is_finite() and lens.global_position.distance_to(from) < 0.6, "the view is from the hero's own eye in HAB 1 (lens at %s, eye at %s)" % [lens.global_position, from])
	var ahead := Vector2(-lens.global_basis.z.x, -lens.global_basis.z.z).normalized().dot(Vector2(hatch.x, hatch.z).normalized())
	check(ahead > 0.9, "and it looks at the hatch (%.2f)" % ahead)
	await frames(120)
	check(lens.global_position.is_finite() and is_finite(float(player.cam.dist)), "and it stays somewhere two seconds on (lens at %s, arm %s)" % [lens.global_position, player.cam.dist])
	check(hab.get_meta("parts").any(func(p: Node3D) -> bool: return p.name == &"door"), "HAB 1 has its hatch")
	# no script: a kid holds W, a real key, and walks out on their own; the clock runs from this frame
	var clock: Node = game.clock
	var cine: Node = game.cine
	var h0: float = clock.hour()
	var f0 := Engine.get_physics_frames()
	check(not clock.pinned and not clock.driven, "the opening holds no hour")
	_key(KEY_W, true)
	var out := false
	for i in 60 * 30:
		await physics_frame
		if beats.beat.get("id", "") != "wake":
			out = player.room == ""
			break
	_key(KEY_W, false)
	check(out, "the kid walked out of HAB 1 on their own (%s at %s)" % [beats.beat.get("id", ""), player.body.global_position])
	check(clock.hour() > h0, "the clock runs while the kid walks out (%.4f to %.4f)" % [h0, clock.hour()])
	# the sunrise, seen from just out of the hatch: the first sliver clears the rim in the planned window
	var o: Dictionary = cine.cfg.opening
	var eye: Vector3 = cine._at(o.eye)
	var rise := -1.0
	for i in 60 * 90:
		var r: float = clock.disc_deg(clock.hour())
		if cine.sun_clear(clock.hour(), eye) > -r * (1.0 - 2.0 * float(o.sliver)):
			rise = (Engine.get_physics_frames() - f0) / 60.0
			break
		await physics_frame
	check(rise >= 30.0 and rise <= 60.0, "the sun's first sliver clears the rim %.1f s after the cover lifts (wanted 30 to 60)" % rise)
	var sun: Vector3 = load("res://addons/forge/house_style.gd").sun_at(clock._C, clock.hour())
	var door: Vector3 = -hab.global_basis.z
	check(absf(rad_to_deg(Vector2(door.x, door.z).angle_to(Vector2(sun.x, sun.z)))) < 5.0, "and it rises straight out of HAB 1's hatch")
	check(absf(game.sim.sim.local_hour() - clock.hour()) < 0.05, "the HUD's hour is the sky's (%.2f, %.2f)" % [game.sim.sim.local_hour(), clock.hour()])
	return true


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	send(e)
