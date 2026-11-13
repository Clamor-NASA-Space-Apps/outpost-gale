extends "res://addons/forge/test.gd"
## Every use spot (data/world.json `uses`) is picked from where its hero stands, plays its clip, names its action
## once the clip has run, and puts every prop back: godot --headless --path . --fixed-fps 60 -s tests/uses_test.gd

var game: Node3D
var box: Node3D


func _init() -> void:
	watchdog = 900.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	box = game.interactions
	game.clock.pinned = true  # Earth's place in the sky holds still while the dish turns to it
	var spots: Array = game.get_tree().get_nodes_in_group("interactable").filter(func(it: Node) -> bool: return it.kind == "spot")
	var rows := 0
	for id: String in game.world.data.uses:
		if not id.begins_with("_"):
			rows += (game.world.data.uses[id] as Array).size()
	check(spots.size() == rows, "one spot per uses row (%d spots, %d rows)" % [spots.size(), rows])
	for it: Node3D in spots:
		for s: Array in it.row.get("steps", []):
			check(s[1] in box.VERBS and it.props.has(s[2]), "%s: step %s names a known verb and prop" % [it.row.kind, s])
	var heard: Array = []
	box.used.connect(func(what: String, _pos: Vector3) -> void: heard.append(what))
	var keys: Array = game.render_game_to_text().keys()
	for it: Node3D in spots:
		if it.row.kind == "bed":
			continue  # the sleep picker's spot: tests/sleep_test.gd
		heard.clear()
		await one(it, heard)
	var extra: Array = game.render_game_to_text().keys().filter(func(k: String) -> bool: return not k in keys)
	check(extra.is_empty(), "no new state keys (%s)" % [extra])
	return true


## Stands the hero at the spot's stand point facing its box, uses it, and checks what it did.
func one(it: Node3D, heard: Array) -> void:
	var row: Dictionary = it.row
	var name := "%s on %s" % [row.kind, it.get_parent().name]
	var player: Node3D = game.player
	var st: Transform3D = it.stand()
	var at := st.origin
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	at.y = maxf(at.y, game.world.height_at(at.x, at.z)) + 1.5  # under a room's roof: the floor, not the roof
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1 | 2, [player.body.get_rid()]))
	at.y = (hit.position.y if hit else game.world.height_at(at.x, at.z)) + 0.05
	var to: Vector3 = it.middle() - at
	player.place(at, rad_to_deg(atan2(to.x, -to.z)))
	await frames(40)
	if player.body.global_position.distance_to(at) > 3.0:
		# the sandbox's safety net (sandbox.gd, world.bound()) keeps the hero on the base's patch for now
		print("SKIP  %s: the hero cannot stand at %s yet (put back at %s)" % [name, at, player.body.global_position])
		return
	var down: Vector3 = it.middle() - player.cam.lens.global_position
	player.cam.pitch = -atan2(-down.y, Vector2(down.x, down.z).length())
	await frames(1)
	box.target = null  # walked up fresh and looking at it: the last pick's stick does not carry over
	await frames(5)
	if not check(box.target == it, "%s: the target from its stand (got %s, hero at %s, spot at %s, room '%s')" % [name, box.target.row.kind + "@" + str(box.target.middle()) if box.target and box.target.kind == "spot" else str(box.target), player.body.global_position, it.middle(), player.room]):
		return
	check(box.prompt_label.text.ends_with(row.prompt), "%s: the prompt says %s ('%s')" % [name, row.prompt, box.prompt_label.text])
	var rest := {}
	for p: String in it.props:
		rest[p] = [(it.props[p] as Node3D).transform, (it.props[p] as Node3D).visible]
	var dish: Node3D = it.props.get("dish")
	box.interact()
	await frames(2)
	if row.has("seat"):
		check(player.seated, "%s: the hero sits" % name)
	else:
		check(player.cut.get("clip") == StringName(row.clip), "%s: E plays %s (cut %s)" % [name, row.clip, player.cut])
	check(heard.is_empty(), "%s: no action before the clip has run (%s)" % [name, heard])
	if dish:
		await frames(220)  # 0.2 of the 1.6 s clip, then 3 s to Earth, held there `hold_s`
		check(absf(dish.rotation.x - box._earth_x()) < 0.03, "%s: the dish points at Earth's elevation (%.2f, want %.2f)" % [name, dish.rotation.x, box._earth_x()])
	for i in 900:
		if box.playing == null:
			break
		await frames(1)
	await frames(60 + 200 * int(dish != null))  # turned parts ease back (the dish over its back_s)
	check(heard == [row.kind], "%s: used names the action once, at the end (%s)" % [name, heard])
	for p: String in it.props:
		var n: Node3D = it.props[p]
		var spec: Dictionary = row.props[p]
		if spec.get("keep", false):
			continue
		check(n.visible == rest[p][1], "%s: %s shown as before (%s)" % [name, p, n.visible])
		check(n.transform.origin.distance_to(rest[p][0].origin) < 0.002 and n.transform.basis.is_equal_approx(rest[p][0].basis), "%s: %s back where it rested" % [name, p])
	if row.has("needs"):
		check(not it.props[row.needs].visible and not it.can_use(player.body), "%s: the %s is taken and the spot used up" % [name, row.needs])
	for p: String in it.props:
		if row.props[p].get("keep", false) and p != row.get("needs", ""):
			check((it.props[p] as Node3D).visible, "%s: %s stays (%s)" % [name, p, row.props[p]])
	if player.seated:
		action(&"move_forward")
		await frames(3)
		action(&"move_forward", false)
		await frames(120)
		check(not player.seated, "%s: a move key stands the hero up" % name)
