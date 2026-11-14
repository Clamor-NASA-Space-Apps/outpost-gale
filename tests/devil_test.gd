extends "res://addons/forge/test.gd"
## Dust devils are scenery: they never enter the base (Ravindu, 14 Nov). Three copies left to the weather alone emitted
## at the origin, inside HAB 1, before the devil hours, because only the first was gated by the hour and moved.

const KEEP_OUT_M := 80.0  # nearest a devil may come to any base building


func _init() -> void:
	watchdog = 300.0


func play() -> bool:
	var game: Node = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var dust: Node = game.world.dust
	var clock: Node = game.clock
	clock.pinned = true
	clock.set_hour(10.8)
	clock.refresh()
	await frames(30)
	check(not dust.devils.any(func(d: GPUParticles3D) -> bool: return d.emitting), "before the devil hours no devil emits")
	clock.set_hour(12.0)
	clock.refresh()
	var nearest := INF
	for i in 600:
		await frames(1)
		for d: GPUParticles3D in dust.devils:
			if not d.emitting:
				continue
			for item: Node3D in game.world.items.values():
				if item.global_position.length() < 60.0:  # the base's own buildings, not the far lander or reactor
					nearest = minf(nearest, Vector2(d.global_position.x - item.global_position.x, d.global_position.z - item.global_position.z).length())
	check(dust.devils.all(func(d: GPUParticles3D) -> bool: return d.emitting), "in the devil hours they all emit")
	check(nearest >= KEEP_OUT_M, "no devil comes within %d m of the base (nearest %.0f m)" % [KEEP_OUT_M, nearest])
	return true
