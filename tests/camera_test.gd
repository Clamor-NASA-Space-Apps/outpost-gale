extends "res://addons/forge/test.gd"
## The play camera on its worst spots (Ravindu, 14 Nov: "whenever the camera hits an object behind it, the camera
## glitches ... we don't need to show the skeleton of the model ... camera never hits any object or glitch"):
## godot --headless --path . --fixed-fps 60 -s tests/camera_test.gd
## At each spot, with real keys: the view turned once round each way with the look keys, level, looking up and looking
## down, then the hero walked back, forth and sideways while the view keeps turning. On every frame the near plane's
## own sphere at the lens is clear of every solid and every thin thing (nothing is cut open), and the lens never moves
## more than STEP; it never changes its distance by more than POP (a cut-in), and it rests REST clear of every solid.
## POP is not asked while a pitch key is held: looking up swings the arm down onto the ground, and the lens then
## slides in along it as fast as the key turns it (h / sin(pitch): 0.3 m a frame at 20 degrees), which is the
## player's own move, in one glide; STEP still holds there.

const REST := 0.15  # m from the lens to every solid once it has settled: tuning.json camera.clear, less a cast's skin
const POP := 0.2  # m the lens may come in or go out along its arm in a frame: feel_rate's 0.125, and 7 cm of a cut
const STEP := 0.45  # m the lens may move in a frame: a key turn swings a 5 m arm 0.2 m, the feelers add 0.125, a hurry 0.03;
# a look up slides it along the ground at up to 0.42
# [name, item or "" for the ground, where the hero stands (the item's space, or world x, z), yaw from the item's front]
const SPOTS := [
	["HAB 1, inside by the hatch", "hab1", Vector3(0.0, 0.3, -1.3), 0.0],
	["HAB 1, mid-room", "hab1", Vector3(0.3, 0.3, 0.6), 90.0],
	["HAB 1, outside its hatch", "hab1", Vector3(0.4, 0.0, -3.4), 180.0],
	["the storm shelter, in its doorway", "shelter", Vector3(0.0, 0.1, -1.5), 180.0],
	["the storm shelter, inside", "shelter", Vector3(0.6, 0.1, 0.4), 90.0],
	["along the shelter's bag wall", "shelter", Vector3(2.9, 0.0, 0.3), 0.0],
	["between the rover and HAB 1", "", Vector3(7.7, 0.0, 7.2), 90.0],
	["by HAB 1's wall and the oxygen maker", "", Vector3(-2.6, 0.0, 4.3), 0.0],
	["by the lamp post east of HAB 1", "", Vector3(5.0, 0.0, 3.6), 45.0],
]

var game: Node3D
var player: Node3D
var cam: Node3D
var down := {}
var space: PhysicsDirectSpaceState3D
var ball := PhysicsShapeQueryParameters3D.new()
var m := {}  # this spot's tallies


func _init() -> void:
	watchdog = 1500.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	player = game.player
	cam = player.cam
	space = game.world.get_world_3d().direct_space_state
	ball.shape = SphereShape3D.new()
	ball.exclude = cam.excluded
	game.pip.process_mode = Node.PROCESS_MODE_DISABLED  # it wanders: a robot driving through the test is not the camera's doing
	for it: Node in get_nodes_in_group("interactable"):
		if it.kind == "door" and not it.open:
			game.interactions.use(it)  # the doorways open, as in play
	await frames(60)
	for s: Array in SPOTS:
		await spot(s)
	# what the feelers cost a physics tick by the lamp post, to weigh against the frame budget (skills/frame-budget):
	# printed, not checked
	if cam.has_method("_feelers"):
		var t0 := Time.get_ticks_usec()
		for i in 200:
			cam._feelers(player.body.global_position + Vector3.UP * 1.55, 4.2)
		print("  the feelers take %.0f us a tick outdoors" % ((Time.get_ticks_usec() - t0) / 200.0))
	return true


func spot(s: Array) -> void:
	var at: Vector3 = s[2]
	var yaw: float = s[3]
	if s[1] != "":
		var item: Node3D = game.world.items[s[1]]
		at = item.to_global(at)
		yaw += -rad_to_deg(item.global_rotation.y)
	else:
		at.y = game.world.height_at(at.x, at.z) + 0.05
	player.place(at, yaw)
	await frames(60)
	if not check(player.inside().is_empty(), "%s: the hero stands clear there (%s)" % [s[0], player.inside()]):
		return
	m = {"frames": 0, "lens": Vector3.INF, "dist": cam.dist, "step": 0.0, "pop": 0.0, "pop_at": "", "near": 0, "near_in": "", "thin": 0, "thin_in": "",
		"cut": 0, "cut_in": "", "still": 0}
	var room: bool = player.room != ""
	# round each way, level, then looking up, then down
	for pitch: Array in [[KEY_I, 0], [KEY_I, 24], [KEY_K, 48]]:
		await hold([pitch[0]], pitch[1])
		await hold([KEY_L], 170)
		await hold([KEY_J], 170)
		await hold([], 40)
	await hold([KEY_I], 24)
	# the hero moves while the view turns: back, forth and sideways
	for keys: Array in [[KEY_S, KEY_L], [KEY_W, KEY_L], [KEY_A, KEY_J], [KEY_D, KEY_J], [KEY_S], [KEY_W]]:
		await hold(keys, 70)
		await hold([], 40)
	print("  %-38s %s: step %.3f, pop %.3f (%s), %d frames cut %s, %d resting near a solid %s, %d in a thin thing %s" % [s[0], "room" if room else "open", m.step, m.pop, m.pop_at,
		m.cut, m.cut_in, m.near, m.near_in, m.thin, m.thin_in])
	check(m.cut == 0, "%s: the near plane never reaches a solid (%d of %d frames: %s)" % [s[0], m.cut, m.frames, m.cut_in])
	check(m.near == 0, "%s: settled, the lens rests %.2f m clear of every solid (%d frames nearer: %s)" % [s[0], REST, m.near, m.near_in])
	check(m.thin == 0, "%s: the near plane never reaches a thin thing (%d frames: %s)" % [s[0], m.thin, m.thin_in])
	check(m.pop <= POP, "%s: the lens never pops along its arm (%.3f m in a frame, at most %.2f; %s)" % [s[0], m.pop, POP, m.pop_at])
	check(m.step <= STEP, "%s: the lens never jumps (%.3f m in a frame, at most %.2f)" % [s[0], m.step, STEP])


## `keys` held for `n` frames, the camera read on each.
func hold(keys: Array, n: int) -> void:
	for k: Key in keys:
		_key(k, true)
	for i in n:
		await frames(1)
		_read()
	for k: Key in keys:
		_key(k, false)


func _read() -> void:
	var lens: Vector3 = cam.lens.global_position
	m.frames += 1
	if m.lens != Vector3.INF:
		m.step = maxf(m.step, lens.distance_to(m.lens))
	m.lens = lens
	if absf(cam.dist - m.dist) > m.pop and not down.get(KEY_I, false) and not down.get(KEY_K, false):
		m.pop = absf(cam.dist - m.dist)
		m.pop_at = "%.2f to %.2f m, yaw %.0f, pitch %.0f, hero %.1f, %.1f, keys %s" % [m.dist, cam.dist, rad_to_deg(cam.yaw), rad_to_deg(cam.pitch),
			player.body.global_position.x, player.body.global_position.z, down.keys().filter(func(k: Key) -> bool: return down[k]).map(func(k: Key) -> String: return OS.get_keycode_string(k))]
	m.dist = cam.dist
	ball.transform = Transform3D(Basis(), lens)
	ball.shape.radius = cam._near_radius() - cam.arm.margin  # the near plane's own sphere: inside it, a thing is cut open
	ball.collision_mask = cam.SOLIDS
	var hit := space.intersect_shape(ball, 1)
	if hit:
		m.cut += 1
		if m.cut_in == "":
			m.cut_in = "%s, yaw %.0f, pitch %.0f, dist %.2f" % [_name(hit[0].collider), rad_to_deg(cam.yaw), rad_to_deg(cam.pitch), cam.dist]
	# at rest: no key held for a third of a second (a cut is eased over the last of the arm's sphere, note_clear)
	m.still = m.still + 1 if down.values().all(func(on: bool) -> bool: return not on) else 0
	ball.shape.radius = REST
	hit = space.intersect_shape(ball, 1)
	if hit and m.still > 20:
		m.near += 1
		if m.near_in == "":
			m.near_in = "%s, yaw %.0f, pitch %.0f, dist %.2f" % [_name(hit[0].collider), rad_to_deg(cam.yaw), rad_to_deg(cam.pitch), cam.dist]
	ball.shape.radius = cam._near_radius() - cam.arm.margin
	ball.collision_mask = cam.THIN
	hit = space.intersect_shape(ball, 1)
	if hit and hit[0].collider.name != &"feet":  # a lamp's `feet` is the hull round its tripod (world.gd), mostly air
		m.thin += 1
		if m.thin_in == "":
			m.thin_in = "%s, yaw %.0f, dist %.2f" % [_name(hit[0].collider), rad_to_deg(cam.yaw), cam.dist]


func _name(n: Node) -> String:
	return str(n.get_path()).get_slice("/World/", 1)


## A real key, sent only when it changes.
func _key(code: Key, on: bool) -> void:
	if down.get(code, false) == on:
		return
	down[code] = on
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = on
	send(e)
