extends "res://addons/forge/test.gd"
## Where a view's draw calls go: the frame's total, then the total with each group hidden in turn (each world item,
## cell, MultiMesh, the terrain's chunks and sites, rocks, dust, machines, each use-spot prop, the hero, PIP, the HUD)
## and with the sun's shadow off. Not a pass/fail test. Needs a display (pictures are drawn):
##   xvfb-run -a nice -n 10 godot --display-driver x11 --path . --fixed-fps 60 --resolution 640x360 -s tests/draw_calls.gd -- hour=6.5 [view=base] [min=2] [quality=phone] [deep=world/rover,world/hab1|none]
## Prints one row per group whose hiding saves at least `min` calls, biggest first; `deep` lists only those groups, node by node.




func _init() -> void:
	watchdog = 1700.0  # a software display draws this scene at a few frames a second


func calls() -> int:
	for i in 2:
		await process_frame
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func play() -> bool:
	var view := "base"
	var least := 2
	var deep: PackedStringArray = []  # groups to break down by each drawn node, light or probe under them
	var only := false  # only the deep groups
	var level := ""  # a quality preset to measure under (phone, older, laptop, ...), else the machine's default
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("view="):
			view = a.trim_prefix("view=")
		elif a.begins_with("min="):
			least = int(a.trim_prefix("min="))
		elif a.begins_with("quality="):
			level = a.trim_prefix("quality=")
		elif a.begins_with("deep="):
			deep = a.trim_prefix("deep=").split(",")
			only = true
	var game: Node3D = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	game.clock.pinned = true
	if level:
		game.set_graphics(level, {})
		for i in 5:
			await process_frame
		while game.busy():
			await process_frame
	game.set_view(view)
	for i in 30:
		await process_frame
	var world: Node3D = game.world
	var groups := {}  # name -> nodes hidden together
	for n: Node in world.get_children():
		if n is Node3D and n.name != "Terrain":
			groups["world/" + n.name] = [n]
	for n: Node in world.terrain.get_children():
		if n is Node3D:
			var key := "terrain/" + str(n.name).rstrip("0123456789_")
			groups.get_or_add(key, []).append(n)
	for n: Node in game.interactions.get_children():
		if n is Node3D:
			groups.get_or_add("prop/" + str(n.name).rstrip("0123456789_@"), []).append(n)
	for n: Node in game.get_children():
		if n is Node3D and n != world and n != game.interactions:
			groups["game/" + n.name] = [n]
		elif n is CanvasLayer or n is Control:
			groups["ui/" + n.name] = [n]
	for g: String in groups.keys():
		if g in deep:
			for top: Node in groups[g]:
				for n: Node in top.find_children("*", "", true, false):
					if (n is GeometryInstance3D or n is Light3D or n is ReflectionProbe) and n.is_visible_in_tree():
						var what := n.get_class()
						if n is MeshInstance3D and n.mesh:
							what += " %d surf, shadow %d" % [n.mesh.get_surface_count(), n.cast_shadow]
						groups["  %s/%s (%s)" % [g, top.get_path_to(n), what]] = [n]
		if only and not g in deep:
			groups.erase(g)
	var total := await calls()
	print("VIEW %s total %d (quality %s)" % [view, total, game.quality])
	var rows: Array = []
	for g: String in groups:
		var was: Array = []
		for n: Node in groups[g]:
			was.append(n.visible)
			n.visible = false
		rows.append([total - await calls(), g])
		if rows[-1][0] >= least:
			print("  .. %d  %s" % rows[-1])  # as it goes: a slow software display can time out the run
		for i in groups[g].size():
			groups[g][i].visible = was[i]
	var sun: DirectionalLight3D = null
	for n in game.get_children():
		if n is DirectionalLight3D and n.has_meta("house_rig"):
			sun = n
	if sun and sun.shadow_enabled:
		sun.shadow_enabled = false
		rows.append([total - await calls(), "sun shadow off"])
		sun.shadow_enabled = true
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("SORTED")
	for r: Array in rows:
		if r[0] >= least:
			print("%5d  %s" % r)
	return true
