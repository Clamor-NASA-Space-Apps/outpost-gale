extends "res://addons/forge/test.gd"
## Every use spot (data/world.json `uses`) is picked from where its hero stands, plays its clip, names its action
## once the clip has run, and puts every prop back; a wing's row is brushed whole in fast forward (sweep()):
## godot --headless --path . --fixed-fps 60 -s tests/uses_test.gd

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
		if it.row.kind == "bed" or it.row.has("sweep"):
			continue  # the sleep picker's spot: tests/sleep_test.gd; a wing's row: sweep() below
		heard.clear()
		await one(it, heard)
	await sweep(spots.filter(func(it: Node) -> bool: return it.row.has("sweep")), heard)
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
	player.cam.snap(player.yaw)  # walked up to it: the view behind the hero, not the last check's leftover yaw
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
	box.interact()
	await frames(2)
	if row.has("seat"):
		check(player.seated, "%s: the hero sits" % name)
	else:
		check(player.cut.is_empty(), "%s: E plays no clip (cut %s)" % [name, player.cut])
	check(heard == [row.kind], "%s: used names the action once, at once (%s)" % [name, heard])
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


## A wing's row (Ravindu, 14 Nov): E brushes the whole row by itself in fast forward and never tilts a panel. One
## press, `clean_panel` once, the data's game minutes on the rules' own clock, control back in seconds, that row
## clean on screen and the next still dusty, and no second clean of a clean row.
func sweep(rows: Array, heard: Array) -> void:
	var player: Node3D = game.player
	var clock: Node = game.clock
	var sim: Object = game.sim.sim
	var k: Dictionary = game.tuning.interact
	if not check(rows.size() == 6, "six wing rows to brush (%d)" % rows.size()):
		return
	var it: Node3D = rows[0]
	var other: Node3D = rows[1]
	var s: Array = it.row.sweep
	var shown := func(row: Node3D) -> Array: return clock._panels.filter(func(p: Dictionary) -> bool: return p.row == row.get_parent()).map(func(p: Dictionary) -> float: return p.shown)
	check(not it.can_use(player.body), "a row with no dust offers no clean")
	sim.panel_dust = 0.33  # the morning after the night gust (sim.json dust_gust)
	await frames(15)
	check((shown.call(it) as Array).min() > 0.9 and clock.dusty(it.middle()), "the rules' dust shows on the row (%s)" % [(shown.call(it) as Array).min()])
	# offered from anywhere along the row: its end, its middle, and its back
	for at: Array in [[s[0], s[2]], [0.0, s[2]], [8.0, -float(s[2])]]:
		var p: Vector3 = it.thing.global_transform * Vector3(at[0], 0.0, at[1])
		var to: Vector3 = it.thing.global_transform * Vector3(at[0], 0.0, 0.0) - p
		player.place(Vector3(p.x, game.world.height_at(p.x, p.z) + 0.05, p.z), rad_to_deg(atan2(to.x, -to.z)))
		await frames(30)
		box.target = null
		await frames(5)
		check(box.target == it and box.prompt_label.text.ends_with("Clean panels"), "the row offers its clean from %s ('%s')" % [at, box.prompt_label.text])
	var start: Vector3 = player.body.global_position
	var tilts: Array = game.world.machines.panels.map(func(p: Dictionary) -> float: return (p.node as Node3D).rotation.x)
	var before: Dictionary = sim.state()
	var t0: Array = [sim.now(), clock.hours]
	clock.pinned = false  # the job runs the clock
	heard.clear()
	box.interact()
	await frames(10)
	var turned := 0.0
	for i in tilts.size():
		turned = maxf(turned, absf((game.world.machines.panels[i].node as Node3D).rotation.x - tilts[i]))
	check(turned < deg_to_rad(0.5), "E tilts no panel (%.2f deg)" % rad_to_deg(turned))
	check(heard.is_empty() and player.allowed == ["none"] and box.target == null, "the job is under way and the kid's input is held (%s, %s)" % [heard, player.allowed])
	var n := 10
	var part := -1.0
	while heard.is_empty() and n < 480:
		await frames(1)
		n += 1
		if n == 200:  # in the brushing: the brush in the glove, the row's coat part gone
			part = (shown.call(it) as Array).max()
			check((it.props.brush as Node3D).visible and player.model.phase == "act", "the brush is in the glove and the clip plays (%s)" % player.model.phase)
	check(part > 0.1 and part < 0.9, "the row's dust thins as the brush goes (%.2f of the coat part way)" % part)
	await frames(2)
	check(heard == ["clean_panel"], "one E brushes the row and names the action once (%s)" % [heard])
	check(n <= float(k.clean_s) * 60.0 + 20.0 and player.allowed.is_empty(), "control is back after %.1f s (%s)" % [n / 60.0, player.allowed])
	var end: Vector3 = player.body.global_position
	var at_end: Vector3 = it.thing.global_transform.affine_inverse() * end  # the end nearer the back's x = 8, on either side
	check(absf(at_end.x - float(s[1])) < 0.5 and absf(absf(at_end.z) - absf(float(s[2]))) < 0.5 and player.state().player.inside.is_empty() and not (it.props.brush as Node3D).visible,
		"the hero is back at the row's near end, in no wall, the brush put away (%s in the row's space, from %s)" % [at_end, start])
	var face: Vector3 = (it.get_parent().find_child("panel_*", true, false) as Node3D).global_basis.y
	var lean: float = it.thing.global_basis.z.dot(face)
	check(absf(lean) < 0.05 or signf(lean) == signf(at_end.z), "on the side the panels lean to, where their faces show (lean %.2f, hero z %.2f)" % [lean, at_end.z])
	var after: Dictionary = sim.state()
	var sol_h: float = sim.n("clock", "sol_h")
	var took: Array = [(sim.now() - t0[0]) * 24.0 / sol_h * 60.0, (clock.hours - t0[1]) * 60.0]
	check(absf(took[0] - float(k.clean_min)) < 1.5 and absf(took[1] - float(k.clean_min)) < 1.5, "the row took %s game minutes on the rules' clock and the sky's (%.1f, %.1f)" % [k.clean_min, took[0], took[1]])
	check(after.water_kg < before.water_kg and after.o2_kg <= before.o2_kg and after.food_kg < before.food_kg, "that time cost its supplies (water %.2f to %.2f kg)" % [before.water_kg, after.water_kg])
	check(absf(after.panel_dust - 0.33 * (1.0 - float(sim.d.uses.clean_panel.clean))) < 0.002, "the rules' dust fell by a sixth (%.4f)" % after.panel_dust)
	await frames(10)
	check((shown.call(it) as Array).max() < 0.01 and not clock.dusty(it.middle()), "the brushed row is clean on screen (%s)" % [(shown.call(it) as Array).max()])
	check((shown.call(other) as Array).min() > 0.9 and clock.dusty(other.middle()), "the next row is still dusty (%s)" % [(shown.call(other) as Array).min()])
	heard.clear()
	check(not it.can_use(player.body) and box.target != it, "a clean row offers no second clean (target %s)" % [box.target])
	box.interact()
	await frames(30)
	check(heard.is_empty(), "and E there does nothing (%s)" % [heard])
	clock.pinned = true
