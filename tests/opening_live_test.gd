extends "res://addons/forge/test.gd"
## The opening as a person starts it: through ui/boot.tscn, the main scene, so boot.gd builds the sandbox and
## sandbox.gd starts the real beats and shots in the frame the world is built (beats_test wires its own, three frames
## later). Runs headless, and on a display the same way (xvfb-run -a ... godot --display-driver x11 ... -s this file).
## 14 Nov playtest, twice: the walk-out ran under the loading cover and timed out; then the rover's body, still at the
## origin for the first physics tick, shoved the hero off the airlock spot and the walk out met the wall beside the hatch.


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	change_scene_to_file("res://ui/boot.tscn")
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
	# a kid told to step outside holds W, a real key, through the automatic walk
	_key(KEY_W, true)
	var out := false
	for i in 60 * 40:
		await physics_frame
		if beats.beat.get("id", "") == "outside":
			out = beats.outdoors()
			break
	_key(KEY_W, false)
	check(out, "the hero is outdoors when the hatch closes behind him (%s at %s)" % [beats.beat.get("id", ""), player.body.global_position])
	for i in 60 * 20:
		if beats.beat.get("id", "") == "walk_to_me":
			break
		await physics_frame
	at = player.body.global_position
	_key(KEY_W, true)
	await frames(90)
	_key(KEY_W, false)
	check(player.body.global_position.distance_to(at) > 0.5, "and walks on the kid's own key once PIP asks (%s)" % beats.beat.get("id", ""))
	return true


func _key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	send(e)
