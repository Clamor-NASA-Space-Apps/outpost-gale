extends "res://addons/forge/test.gd"
## Lettuce is eaten from the tray, not conjured (14 Nov playtest: an endless lettuce): every harvest takes a head off
## its tray and shows one in the glove, the tray runs out and then refuses, and the cut heads grow back over the sols.
##   godot --headless --path . --fixed-fps 60 -s tests/harvest_test.gd


func _init() -> void:
	watchdog = 300.0


func play() -> bool:
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await frames(1)
	var box: Node3D = game.interactions
	var world: Node3D = game.world
	_in_trays(world)
	var spots: Array = box.by_thing.values().filter(func(it: Node) -> bool: return it.kind == "spot" and it.row.kind == "harvest")
	if not check(spots.size() > 0, "the greenhouse has a harvest spot"):
		return true
	var it: Node3D = spots[0]
	var id: String = it.get_parent().name
	var ready: int = world._lettuce[id].filter(func(h: Dictionary) -> bool:
		var p: Vector3 = (h.slot as Node3D).global_position
		return int(h.stage) >= world.EAT_STAGE and absf(p.y - it.middle().y) < 0.3 and Vector2(p.x - it.middle().x, p.z - it.middle().z).length() <= 1.3).size()
	check(ready > 0, "the tray starts with heads to eat (%d)" % ready)
	var eaten := 0
	var head: Node3D = it.props["head"]
	while it.can_use(game.player.body) and eaten < 10:
		var before := _stages(world, id)
		box.use(it)
		await frames(2)
		check(_stages(world, id) < before, "a harvest takes a head off the tray (stages %d, then %d)" % [before, _stages(world, id)])
		eaten += 1
	check(not head.visible, "no head is left floating where the glove was (no clip)")
	check(eaten == ready, "the tray gave %d heads, it had %d" % [eaten, ready])
	check(not it.can_use(game.player.body), "an empty tray refuses the next harvest")
	world.regrow(int(game.sim.sim.sol) + 40, 33.0)
	check(it.can_use(game.player.body), "40 sols on, the cut heads have grown back")
	_in_trays(world)
	return true


## Every head inside its tray (14 Nov playtest: heads past the rack): its drawn box within the tray's inner half
## width across and half the slot spacing along the rack (forge/building_greenhouse.py: trays 0.5 m inside, slots
## 0.6 m apart), and under the LED bars of the tier above (0.55 m up, the bars 8 cm under the next tray).
func _in_trays(world: Node3D) -> void:
	const ACROSS := 0.25
	const ALONG := 0.3
	const UP := 0.4
	for id: String in world._lettuce:
		for h: Dictionary in world._lettuce[id]:
			var slot: Node3D = h.slot
			var b := AABB()
			var first := true
			for mi: MeshInstance3D in (h.node as Node3D).find_children("*", "MeshInstance3D", true, false):
				var local := slot.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
				b = local if first else b.merge(local)
				first = false
			var across := maxf(absf(b.position.x), absf(b.end.x))
			var along := maxf(absf(b.position.z), absf(b.end.z))
			check(across <= ACROSS and along <= ALONG and b.end.y <= UP, "%s %s: the head (stage %d) stays in its tray (%.2f across, %.2f along, %.2f up)" % [id, slot.name, h.stage, across, along, b.end.y])


## The sum of the item's heads' stages: falls by a cut, rises as they grow.
func _stages(world: Node3D, id: String) -> int:
	var n := 0
	for h: Dictionary in world._lettuce[id]:
		n += int(h.stage)
	return n
