extends "res://addons/forge/test.gd"
## Hands and body (design/plans/core-loop-contracts.md, W): a use row with `hold_s` needs E held that long and fires
## `used` once; letting go or walking off cancels; a row without it still fires on the press. Hurrying on foot costs
## stamina, the lock lets go at 0 and stays off until it is back. A dust devil is felt only near it:
## godot --headless --path . --fixed-fps 60 -s tests/hold_test.gd

var game: Node3D
var box: Node3D
var player: Node3D
var heard: Array = []


func _init() -> void:
	watchdog = 300.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	box = game.interactions
	player = game.player
	box.used.connect(func(what: String, _pos: Vector3) -> void: heard.append(what))
	check(player.allowed.is_empty(), "the bare sandbox blocks no action (%s)" % [player.allowed])
	await holds()
	await stamina()
	await devils()
	await instant()
	return true


## The first spot of `kind` on `item`, the hero at its stand looking at it (as tests/uses_test.gd one()).
func at_spot(item: String, kind: String) -> Node3D:
	var spot: Node3D = null
	for it: Node3D in get_nodes_in_group("interactable"):
		if it.kind == "spot" and it.row.kind == kind and it.get_parent().name == item:
			spot = it
	if not check(spot != null, "%s has a %s spot (world.json uses)" % [item, kind]):
		return null
	var at: Vector3 = spot.stand().origin
	var hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 1.5, at + Vector3.DOWN * 1.5, 1 | 2, [player.body.get_rid()]))
	at.y = (hit.position.y if hit else at.y) + 0.05
	var to: Vector3 = spot.middle() - at
	player.place(at, rad_to_deg(atan2(to.x, -to.z)))
	player.cam.snap(player.yaw)
	await frames(40)
	var down: Vector3 = spot.middle() - player.cam.lens.global_position
	player.cam.pitch = -atan2(-down.y, Vector2(down.x, down.z).length())
	await frames(1)
	box.target = null
	await frames(5)
	check(box.target == spot, "%s on %s: the target from its stand (got %s, room '%s')" % [kind, item, box.target, player.room])
	return spot


func holds() -> void:
	var spot := await at_spot("hab1", "drink")
	if spot == null or box.target != spot:
		return
	var n := int(float(spot.row.hold_s) * 60.0)
	check(box.hold == -1.0 and box.hold_shown() == 0.0, "a hold row shows its ring empty before the press (hold %s, shown %s)" % [box.hold, box.hold_shown()])
	# let go half way: nothing
	action(&"interact")  # the key, as the root hears it: sandbox.gd calls interactions.interact() on the press
	await frames(n / 2)
	check(heard.is_empty() and absf(box.hold - 0.5) < 0.1 and box.hold_shown() == box.hold, "E down half the time: half a ring, nothing used (hold %.2f, %s)" % [box.hold, heard])
	action(&"interact", false)
	await frames(2)
	check(box.hold == -1.0 and box.hold_shown() == 0.0, "let go: the hold is gone (hold %s)" % box.hold)
	await frames(n)
	check(heard.is_empty(), "and nothing was used (%s)" % [heard])
	# held to the end: once, and no second one while E stays down
	action(&"interact")
	await frames(n - 3)
	check(heard.is_empty() and box.hold > 0.9, "just short of the time: still nothing (hold %.2f, %s)" % [box.hold, heard])
	await frames(8)
	check(heard == ["drink"] and box.hold == -1.0, "held %.1f s: `used` names the drink once (%s)" % [spot.row.hold_s, heard])
	await frames(n + 10)
	check(heard == ["drink"], "E still down: no second drink (%s)" % [heard])
	action(&"interact", false)
	await frames(2)
	# walking off cancels
	heard.clear()
	action(&"interact")
	await frames(n / 3)
	check(box.hold > 0.0, "a new press starts a new hold (hold %.2f)" % box.hold)
	game.place(Vector3(-22, 0, 18), 90)  # the open ground east of the base
	await frames(3)
	check(box.hold == -1.0, "out of reach: the hold is gone (hold %s)" % box.hold)
	await frames(n)
	check(heard.is_empty(), "and nothing was used (%s)" % [heard])
	action(&"interact", false)
	await frames(2)


## From the open ground the hero hurries east: stamina falls at 1 / drain_s a second, the lock lets go at 0, a press
## under `back` does nothing, and one over it locks again.
func stamina() -> void:
	var st: Dictionary = game.tuning.hero.stamina
	game.place(Vector3(-22, 0, 18), 90)
	player.cam.snap(player.yaw)
	await frames(60)
	check(player.stamina == 1.0 and not player.hurrying_on_foot(), "rested and standing: full stamina (%.2f)" % player.stamina)
	var tap := func() -> void:
		action(&"hurry")
		action(&"hurry", false)
	tap.call()
	action(&"move_forward")
	await frames(130)  # 10 frames to get going, then 2 s
	check(player.hurrying and player.hurrying_on_foot(), "hurrying on foot (speed %.2f)" % player.moved)
	check(absf(1.0 - player.stamina - 2.0 / float(st.drain_s)) < 0.02, "2 s of hurry cost 2 / drain_s (%.3f left)" % player.stamina)
	player.stamina = 0.05  # the last second of a long run
	await frames(int(0.05 * float(st.drain_s) * 60.0) + 5)
	check(player.stamina < 0.01 and not player.hurrying and not player.hurrying_on_foot(), "at 0 the hurry lock lets go (stamina %.3f, hurrying %s)" % [player.stamina, player.hurrying])
	await frames(30)
	tap.call()
	await frames(2)
	check(not player.hurrying and player.stamina > 0.0 and player.stamina < float(st.back), "under `back` a press does not lock it (stamina %.2f)" % player.stamina)
	await frames(int(float(st.back) * float(st.recover_s) * 60.0))  # walking on: back over `back`
	check(player.stamina >= float(st.back), "walking, it comes back at 1 / recover_s (%.2f)" % player.stamina)
	tap.call()
	await frames(10)
	check(player.hurrying and player.hurrying_on_foot(), "over `back` the press locks it again")
	tap.call()
	action(&"move_forward", false)
	await frames(30)


## An emitting devil is near at its own place and not 20 m off; one that is not out touches no one.
func devils() -> void:
	var dust: Node = game.world.dust
	var clock: Node = game.clock
	clock.pinned = true
	clock.set_hour(10.8)
	clock.refresh()
	await frames(30)
	var at: Vector3 = dust.devils[0].global_position
	check(not dust.devil_near(at), "before the devil hours no devil touches anyone")
	clock.set_hour(12.0)
	clock.refresh()
	await frames(30)
	at = dust.devils[0].global_position
	check(dust.devils[0].emitting and dust.devil_near(at) and dust.devil_near(at + Vector3(3, 40, 0)), "in the devil hours: near at a devil's place, whatever the height")
	check(not dust.devil_near(at + Vector3(20, 0, 0)), "and not 20 m from it")
	check(not dust.devil_near(player.body.global_position), "nor at the base")
	clock.pinned = false


## A row with no `hold_s`: the new power panel in HAB 1 is used on the press, and shows no ring.
func instant() -> void:
	for at: Array in [["greenhouse", "refill_air"], ["shelter", "refill_air"]]:
		var air := await at_spot(at[0], at[1])
		check(air != null and box.hold_shown() == 0.0 and box.prompt_label.text.ends_with("Fill suit air"), "%s: Fill suit air, a hold row ('%s')" % [at[0], box.prompt_label.text])
	var spot := await at_spot("hab1", "panel")
	if spot == null or box.target != spot:
		return
	check(box.prompt_label.text.ends_with("Power panel") and box.hold_shown() == -1.0, "the power panel: its prompt, and no ring ('%s', %s)" % [box.prompt_label.text, box.hold_shown()])
	heard.clear()
	action(&"interact")
	await frames(2)
	action(&"interact", false)
	check(heard == ["panel"] and box.hold == -1.0, "E: `used` names the panel at once (%s)" % [heard])
