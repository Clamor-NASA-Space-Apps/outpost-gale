extends "res://addons/forge/test.gd"
## PIP wanders on its own and keeps out of the way:
## godot --headless --path . --fixed-fps 60 -s tests/pip_test.gd
## A minute alone: it moves, reaches several stops, never overlaps a solid, a bag, the rover or the hero, never
## enters a building or parks in a doorway, and nothing but PIP moves (no game state). Then the hero: in its path
## (it waits), standing still nearby (it comes over and looks up), coming close (a beep).

const SOLID := 2 | 4 | 8 | 16 | 64  # statics, thin, hero, vehicles, carriables (CONTRACTS.md)


func _init() -> void:
	watchdog = 300.0


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var world: Node3D = game.get_node("World")
	var player: Node3D = game.get_node("Player")
	var pip: Node3D = world.items.get("pip")
	if not check(pip != null and pip.has_method("state_text"), "the sandbox drives PIP with sandbox/pip.gd"):
		return true
	var sounds: Array[String] = []
	pip.sound.connect(func(what: String, _at: Vector3) -> void: sounds.append(what))
	var keys: Array = game.render_game_to_text().keys()
	var others := {}  # every other mover's place: PIP must change nothing but itself
	for id: String in world.items:
		if id != "pip":
			others[id] = (world.items[id] as Node3D).global_transform
	# a minute alone: the hero far away at the patch edge
	var edge: Dictionary = world.landmark("edge")
	player.place(edge.pos, edge.yaw)
	var start: Vector3 = pip.global_position
	var far := 0.0
	var hits := 0
	var inside := 0
	var parked_in_door := 0
	var states := {}
	for i in 60 * 60:
		await frames(1)
		far = maxf(far, pip.global_position.distance_to(start))
		states[pip.state] = true
		hits += 1 if _overlaps(pip) else 0
		var at := Vector2(pip.global_position.x, pip.global_position.z)
		for r: Array in pip._rooms:
			var l: Vector3 = r[0] * Vector3(at.x, 0.0, at.y)
			var b: AABB = r[1].grow(-float(pip.p.room_margin))
			inside += 1 if l.x > b.position.x and l.x < b.end.x and l.z > b.position.z and l.z < b.end.z else 0
		if pip.state == "look":
			for d: Vector2 in pip._doors:
				parked_in_door += 1 if at.distance_to(d) < float(pip.p.door_clear_m) * 0.9 else 0
	var stops := {}
	for s: String in pip.reached:
		stops[s] = true
	check(far > 3.0, "PIP moves on its own (%.1f m from where it started)" % far)
	check(stops.size() >= 2 and pip.reached.size() + pip.passed >= 4, "it reaches several points in 60 s (stops %s, via points %d)" % [pip.reached, pip.passed])
	check(states.has("look") and states.has("drive"), "it drives and stops to look (%s)" % [states.keys()])
	check(hits == 0, "it never overlaps a solid, a bag, the rover or the hero (%d frames)" % hits)
	check(inside == 0, "it never enters a building (%d frames)" % inside)
	check(parked_in_door == 0, "it never parks in a doorway (%d frames)" % parked_in_door)
	check(sounds.has("pip_go"), "a beep when it sets out (%s)" % [sounds])
	var moved := []
	for id: String in others:
		if not (world.items[id] as Node3D).global_transform.is_equal_approx(others[id]):
			moved.append(id)
	check(moved.is_empty(), "nothing but PIP moved: no game state (%s)" % [moved])
	check(game.render_game_to_text().keys() == keys, "render_game_to_text keeps its keys")
	check(not _wheels_still(pip), "its wheels turn as it drives")

	# the hero steps into its path: it waits, never touching
	var waited := false
	for tries in 4:
		await _until(pip, func() -> bool: return pip.state == "drive" and pip.v > 0.3, 20.0)
		var ahead: Vector3 = pip.global_position - pip.global_basis.z * 1.2
		player.place(Vector3(ahead.x, world.height_at(ahead.x, ahead.z) + 0.05, ahead.z), 0.0)
		for i in 60:
			await frames(1)
			waited = waited or pip.state == "wait"
			hits += 1 if _overlaps(pip) else 0
		if waited:
			break
	check(waited, "a hero in its path makes it wait")
	check(hits == 0, "and it never touches the hero")
	# the hero stands still nearby: it comes over, looks up, beeps
	player.place(edge.pos, edge.yaw)
	await _until(pip, func() -> bool: return pip.state == "look", 30.0)
	var near: Vector3 = pip.global_position + Vector3(4.0, 0.0, 0.0)
	if pip._no_go(Vector2(near.x, near.z)):
		near = pip.global_position - Vector3(4.0, 0.0, 0.0)
	pip._greet_cool = 0.0
	pip._hello_cool = 0.0
	sounds.clear()
	player.place(Vector3(near.x, world.height_at(near.x, near.z) + 0.05, near.z), 0.0)
	var greeted := await _until(pip, func() -> bool: return pip.state == "greet", 25.0)
	var gap: float = Vector2(pip.global_position.x - near.x, pip.global_position.z - near.z).length()
	check(greeted, "a hero standing still nearby gets a visit")
	check(gap > 1.0 and gap < 2.5, "it parks beside the hero, not on it (%.2f m)" % gap)
	check(sounds.has("pip_hello"), "and beeps hello (%s)" % [sounds])
	check(pip._near, "its head is on the hero")
	return true


## PIP's hull, 3% smaller (a touch is not an overlap), against everything it must keep out of.
func _overlaps(pip: Node3D) -> bool:
	var cs: CollisionShape3D = pip._shape
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cs.shape
	q.collision_mask = SOLID
	q.exclude = [pip.get_rid()]
	q.transform = pip.global_transform.scaled_local(Vector3.ONE * 0.97) * cs.transform
	return not pip.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _wheels_still(pip: Node3D) -> bool:
	for w: Node3D in pip._wheels:
		if not w.basis.is_equal_approx(Basis()):
			return false
	return true


func _until(_pip: Node3D, ok: Callable, seconds: float) -> bool:
	for i in int(60 * seconds):
		if ok.call():
			return true
		await frames(1)
	return ok.call()
