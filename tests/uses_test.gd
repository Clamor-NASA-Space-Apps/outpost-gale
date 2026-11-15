extends "res://addons/forge/test.gd"
## Every use spot (data/world.json `uses`) is picked from where its hero stands, names its action once (on the press,
## or after its `hold_s` of E held), and puts every prop back; a wing's row is cleared by its wiper at a button's press (wiper()):
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
	# a spot's box lies on the thing it names, never in the air beside it: the waypoint and PIP point at its middle
	# (15 Nov playtest: "the item itself should be the waypoint, not the approximate location"). The row's own box,
	# before it grows to the least size E needs, and a hand's breadth round it (a screen or a plate on a wall is drawn
	# in front of what is solid); a wing's button stands on a post that is drawn, not solid
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var adrift: Array[String] = []
	for it: Node3D in spots:
		if not it.row.has("box") or it.row.has("wiper"):
			continue
		var b: Array = it.row.box
		var shape := BoxShape3D.new()
		shape.size = Vector3(b[3] - b[0], b[4] - b[1], b[5] - b[2]) + Vector3.ONE * 0.2
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = it.thing.global_transform * Transform3D(Basis(), Vector3(b[0] + b[3], b[1] + b[4], b[2] + b[5]) / 2.0)
		q.collision_mask = 1 | 2 | 4  # the ground (a pebble to sample), statics, thin statics
		if space.intersect_shape(q, 1).is_empty():
			adrift.append("%s on %s" % [it.row.kind, it.get_parent().name])
	check(adrift.is_empty(), "every use spot's box touches the thing it names (%s)" % [adrift])
	# and each thing a step sends the kid to says what it is: a word on it (15 Nov playtest: "Drink what? Eat what?")
	var unnamed: Array[String] = []
	for it: Node3D in spots:
		if it.row.kind in ["drink", "eat", "radio", "brush", "bed", "panel", "o2_valve"] or (it.row.kind == "refill_air" and it.get_parent().name != "hab1"):
			var words := 0
			for spec: Dictionary in it.row.get("props", {}).values():
				words += spec.get("meshes", []).filter(func(m: Dictionary) -> bool: return m.has("text")).size()
			if words == 0:
				unnamed.append("%s on %s" % [it.row.kind, it.get_parent().name])
	check(unnamed.is_empty(), "every spot a step leads to carries its name (%s; HAB 1's air valves say AIR IN in the model)" % [unnamed])
	var heard: Array = []
	box.used.connect(func(what: String, _pos: Vector3) -> void: heard.append(what))
	var keys: Array = game.render_game_to_text().keys()
	for it: Node3D in spots:
		if it.row.kind == "bed" or it.row.has("wiper"):
			continue  # the sleep picker's spot: tests/sleep_test.gd; a wing's row: wiper() below
		heard.clear()
		await one(it, heard)
	# a prop that stands outdoors is never a swept (`clean`) surface: those are drawn with the rooms' fit-out, which
	# is hidden from afar (world.json swept_range_m), and the wipers' consoles came and went with the camera's place
	# (15 Nov playtest: "the wiper push button randomly vanishes")
	var outdoors: Array[String] = []
	for id: String in game.world.data.uses:
		if id == "_note" or game.world.data.rooms.has(id):
			continue
		for row: Dictionary in game.world.data.uses[id]:
			for name: String in row.get("props", {}):
				var spec: Dictionary = row.props[name]
				if spec.get("clean", false) and not spec.get("hidden", false) and not spec.get("hand", false):
					outdoors.append("%s %s" % [id, name])
	check(outdoors.is_empty(), "no always-shown outdoor prop is a swept surface (%s)" % [outdoors])
	# every step that waits for a use has a waypoint to the thing: PIP said "press E" for things a building away, with
	# no way to know where (15 Nov playtest)
	var kinds := {}
	for id: String in game.world.data.uses:
		if id != "_note":
			for row: Dictionary in game.world.data.uses[id]:
				kinds[row.kind] = true
	var seqs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sols.json"))
	seqs["1"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/beats.json")).opening
	var lost: Array[String] = []
	for key: String in seqs:
		if not key.is_valid_int():
			continue
		for b: Dictionary in seqs[key]:
			var w: Variant = b.get("wait", {}).get("action", [])
			for a: String in (w if w is Array else [w]):
				# the one step with none sends the kid to the handbook, which says where (Sol 4's valve, keys Tab)
				if a.begins_with("use:") and (a == "use:rover" or kinds.has(a.trim_prefix("use:"))) \
						and b.get("objective") == null and not "Tab" in b.get("keys", []):
					lost.append("sol %s %s" % [key, b.id])
	check(lost.is_empty(), "every step that waits for a use has a waypoint to it (%s)" % [lost])
	game.beats.objective.emit("use:radio")
	var mark: Node3D = game.hud.objective_node
	check(mark != null and mark.row.kind == "radio", "a step that asks for the radio puts its waypoint on a radio")
	game.interactions.used.emit("radio", Vector3.ZERO)
	check(game.hud.objective == "", "and the waypoint goes once the radio is used (%s)" % game.hud.objective)
	await wiper(spots.filter(func(it: Node) -> bool: return it.row.has("wiper")), heard)
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
	# a hold row (`hold_s`): E stays down that long, a ring on the HUD, and nothing is used before it is full
	var hold_s := float(row.get("hold_s", 0.0))
	check(box.hold_shown() == (0.0 if hold_s > 0.0 else -1.0), "%s: the ring shows before the press only on a hold row (%s)" % [name, box.hold_shown()])
	if hold_s > 0.0:
		Input.action_press(&"interact")
	var stood: Vector3 = player.body.global_position
	box.interact()
	await frames(2)
	if hold_s > 0.0:
		check(heard.is_empty() and box.hold > 0.0, "%s: held, nothing is used yet (%s, hold %.2f)" % [name, heard, box.hold])
		await frames(int(hold_s * 60.0) + 2)
		Input.action_release(&"interact")
	# no spot moves the hero: the Sit spots left a kid walking seated in the air, and the wiper's button slid the hero
	# to itself from 1.6 m off (15 Nov)
	await frames(20)
	check(player.body.global_position.distance_to(stood) < 0.05, "%s: E leaves the hero where it stood (%.2f m off)" % [name, player.body.global_position.distance_to(stood)])
	check(heard == [row.kind], "%s: used names the action once, on the press or when the hold is full (%s)" % [name, heard])
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


## A wing's row (Ravindu, 15 Nov): each has a wiper bar parked at its control post. E at the post's button, from an
## arm's length, plays the press where the hero stands, the bar crosses the row and parks at the other end, `clean_panel` is told
## once when it gets there, that row is clean on screen and the next still dusty. No tilt, no camera change, no jump
## of the clock, no second run on a clean row; the next run sends the bar back.
func wiper(rows: Array, heard: Array) -> void:
	var player: Node3D = game.player
	var clock: Node = game.clock
	var sim: Object = game.sim.sim
	if not check(rows.size() == 6 and box._wipers.size() == 6, "six wing rows, each with a wiper (%d rows, %d wipers)" % [rows.size(), box._wipers.size()]):
		return
	for row: Node3D in rows:
		var bar: Node3D = box._wipers[row].bar
		var on: Vector3 = (box._wipers[row].panel as Node3D).to_local(bar.global_position)
		check(bar.is_inside_tree() and bar.visible and absf(on.x - float(box._wipers[row].ends[0])) < 0.01 and row.props.has("post"),
			"%s: a bar parked at the post's end of its panel, and a post (%s on the panel)" % [row.get_parent().name, on])
	var it: Node3D = rows[0]
	var other: Node3D = rows[1]
	var w: Dictionary = box._wipers[it]
	var shown := func(row: Node3D) -> Array: return clock._panels.filter(func(p: Dictionary) -> bool: return p.row == row.get_parent()).map(func(p: Dictionary) -> float: return p.shown)
	var st: Transform3D = it.stand()
	var front: Vector3 = -st.basis.z
	var off: Vector3 = st.origin - front * 0.3 + st.basis.x * 0.3  # walked up to the post, not onto the stand
	player.place(Vector3(off.x, game.world.height_at(off.x, off.z) + 0.05, off.z), rad_to_deg(atan2(front.x, -front.z)))
	await frames(30)
	check(not it.can_use(player.body) and box.target != it, "a row with no dust offers no wiper")
	sim.panel_dust = 0.33  # the morning after the night gust (sim.json dust_gust)
	box.target = null
	await frames(15)
	check((shown.call(it) as Array).min() > 0.9 and clock.dusty(it.middle()), "the rules' dust shows on the row (%s)" % [(shown.call(it) as Array).min()])
	check(box.target == it and box.prompt_label.text.ends_with("Run the wiper"), "the post offers the wiper ('%s')" % box.prompt_label.text)
	# only from an arm's length: from further off E slid the hero to the button, a teleport (15 Nov playtest)
	var far: Vector3 = st.origin - front * 1.1
	player.place(Vector3(far.x, game.world.height_at(far.x, far.z) + 0.05, far.z), rad_to_deg(atan2(front.x, -front.z)))
	box.target = null
	await frames(15)
	check(box.target != it, "from 1.5 m off the post offers nothing (%s)" % [box.target])
	player.place(Vector3(off.x, game.world.height_at(off.x, off.z) + 0.05, off.z), rad_to_deg(atan2(front.x, -front.z)))
	await frames(90)  # put down and settled: a body still landing refuses the press clip
	check(box.target == it, "and from beside it again it does (%s)" % [box.target])
	var stood: Vector3 = player.body.global_position
	var tilts: Array = game.world.machines.panels.map(func(p: Dictionary) -> float: return (p.node as Node3D).rotation.x)
	var cam: Camera3D = root.get_camera_3d()
	var t0: float = sim.now()
	heard.clear()
	box.interact()
	await frames(30)
	var at: Vector3 = player.body.global_position
	check(at.distance_to(stood) < 0.05 and player.model.phase == "act",
		"E: the hero presses from where it stood, moved nowhere (%.2f m off, %s)" % [at.distance_to(stood), player.model.phase])
	check(heard.is_empty() and player.allowed.is_empty() and not it.can_use(player.body), "nothing is told yet, no input is held, and a running wiper takes no second press (%s)" % [heard])
	var n := 30
	while heard.is_empty() and n < 300:
		await frames(1)
		n += 1
		if n == 120:  # part way: the bar between the ends, the dust gone only behind it
			var x: float = (w.panel as Node3D).to_local((w.bar as Node3D).global_position).x
			var p: Dictionary = clock._panels.filter(func(q: Dictionary) -> bool: return q.row == it.get_parent())[0]
			check(x > float(w.ends[0]) + 2.0 and x < float(w.ends[1]) - 2.0 and absf(p.wipe.x - x) < 0.5 and p.wipe.y == 1.0 and p.shown > 0.9,
				"part way the bar is %.1f m along and the row's coat ends at it (wipe %s)" % [x, p.wipe])
	check(heard == ["clean_panel"] and n <= 250, "the bar is across and `clean_panel` told once, after %.1f s (%s)" % [n / 60.0, heard])
	await frames(10)
	var end: Vector3 = (w.panel as Node3D).to_local((w.bar as Node3D).global_position)
	check(absf(end.x - float(w.ends[1])) < 0.01 and w.at == 1, "the bar is parked at the far end (%.2f of %.2f)" % [end.x, w.ends[1]])
	var turned := 0.0
	for i in tilts.size():
		turned = maxf(turned, absf((game.world.machines.panels[i].node as Node3D).rotation.x - tilts[i]))
	check(turned < deg_to_rad(0.5), "no panel was tilted (%.2f deg)" % rad_to_deg(turned))
	check(root.get_camera_3d() == cam and player.body.global_position.distance_to(at) < 0.05, "the camera is the same one and the hero stayed at the post")
	check((sim.now() - t0) * 60.0 < 10.0, "the game clock did not jump (%.1f game minutes in %.1f s)" % [(sim.now() - t0) * 60.0, n / 60.0])
	check(absf(sim.panel_dust - 0.33 * (1.0 - float(sim.d.uses.clean_panel.clean))) < 0.002, "the rules' dust fell by a sixth (%.4f)" % sim.panel_dust)
	check((shown.call(it) as Array).max() < 0.01 and not clock.dusty(it.middle()), "the wiped row is clean on screen (%s)" % [(shown.call(it) as Array).max()])
	check((shown.call(other) as Array).min() > 0.9 and clock.dusty(other.middle()), "the next row is still dusty (%s)" % [(shown.call(other) as Array).min()])
	heard.clear()
	check(not it.can_use(player.body) and box.target != it, "a clean row offers no second run (target %s)" % [box.target])
	box.interact()
	await frames(30)
	check(heard.is_empty() and w.t < 0.0, "and E there does nothing (%s)" % [heard])
	sim.panel_dust += 0.2  # dust again: the next run sends the bar back
	await frames(15)
	box.use(it)
	await frames(260)
	check(heard == ["clean_panel"] and w.at == 0, "dusty again, the next press sends the bar back to the post (%s, at %d)" % [heard, w.at])
