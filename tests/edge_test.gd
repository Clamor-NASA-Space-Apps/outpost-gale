extends "res://addons/forge/test.gd"
## The end of the real ground (data/world.json `bound`, CONTRACTS.md):
##   godot --headless --path . --fixed-fps 60 -s tests/edge_test.gd     (a few minutes)
## 1. One surface: everywhere a body can be, near the line, the drawn ground, the ground's collision and height_at()
##    agree.
## 2. The hero hurries at the line, head-on and slanted, at spots all round it: slows at its own braking, stops on
##    the line, stands on the ground, never past it.
## 3. The rover drives at it, forward and backing: brakes to a stop with its hatch inside, and the driver gets out
##    onto the ground.
## 4. The safety net: the hero, the rover, PIP and a bag put under the ground, or past the line, come back on top.
## Nothing in 2 and 3 may need the net.

const GHOST := 1 << 19  # layer 20, which nothing in the game uses: the drawn ground, touching nothing
const SPOTS := [-0.8, -0.4, 0.0, 0.4, 0.8]  # along each side, as a share of the half width
const AGREE := 0.06  # m: a heightmap cell's two triangles against the drawn ones (tests/run.gd)

var game: Node3D
var world: Node3D
var player: Node3D
var half: float


func _init() -> void:
	watchdog = 900.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	world = game.get_node("World")
	player = game.get_node("Player")
	half = world.data.bound.half
	await _surface()
	var rescued: int = game.rescued
	for side in 4:
		for s: float in SPOTS:
			await _walk(side, s * half, 45.0 if absf(s) == 0.4 else 0.0)
	for side in 4:
		await _walk(side, half - 3.0, 45.0)  # into a corner
	for side in 4:
		for s: float in [-0.5, 0.5]:
			await _drive(side, s * half, s > 0.0)
	check(game.rescued == rescued, "nothing walked or drove needed the safety net (%d rescues)" % (game.rescued - rescued))
	await _net()
	return true


## The outward direction and the direction along the line of side 0 to 3 (east, south, west, north).
func _side(side: int) -> Array[Vector3]:
	var out: Vector3 = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][side]
	return [out, Vector3(-out.z, 0.0, out.x)]


## Yaw in degrees clockwise from north (CONTRACTS.md) of a flat direction.
func _yaw(d: Vector3) -> float:
	return rad_to_deg(atan2(d.x, -d.z))


func _surface() -> void:
	# the backdrop is not drawn over the patch (terrain.gdshader `backdrop`), so the patch is the drawn ground there
	var patch: Vector4 = world.terrain.material.get_shader_parameter("macro_rect")
	var r: Rect2 = world.bound()
	check(Rect2(patch.x, patch.y, patch.z, patch.w).encloses(r), "the bound %s lies inside the patch %s" % [r, patch])
	for mi: MeshInstance3D in world.terrain.find_children("*", "MeshInstance3D", true, false):
		if not str(mi.name).begins_with("patch_"):
			check(float(mi.get_instance_shader_parameter("backdrop")) == 1.0, "%s leaves the patch to the patch" % mi.name)
			continue
		var shape := ConcavePolygonShape3D.new()
		var faces := mi.mesh.get_faces()
		for k in faces.size():
			faces[k] = mi.global_transform * faces[k]
		shape.set_faces(faces)
		var body := StaticBody3D.new()
		body.collision_layer = GHOST
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		root.add_child(body)
	await frames(2)
	var space := game.get_world_3d().direct_space_state
	var worst := {"drawn": 0.0, "collision": 0.0}
	var where := {"drawn": Vector2.ZERO, "collision": Vector2.ZERO}
	var missing := 0
	# the band a body can stand in near the line, every metre round all four sides
	for side in 4:
		var d := _side(side)
		for a in range(-int(half), int(half) + 1):
			for inward: float in [0.0, 1.0, 2.5, 5.0, 10.0]:
				var p: Vector3 = d[0] * (half - inward) + d[1] * float(a)
				var h: float = world.height_at(p.x, p.z)
				for what: String in worst:
					var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 60.0, p.z), Vector3(p.x, h - 60.0, p.z), GHOST if what == "drawn" else world.GROUND)
					var hit := space.intersect_ray(q)
					if hit.is_empty():
						missing += 1
						continue
					var off := absf(hit.position.y - h)
					if off > worst[what]:
						worst[what] = off
						where[what] = Vector2(p.x, p.z)
	check(missing == 0, "drawn ground and collision under every point of the band (%d missing)" % missing)
	for what: String in worst:
		check(worst[what] < AGREE, "%s ground and height_at() agree near the line (worst %.3f m at %s)" % [what, worst[what], where[what]])
	print("surface near the line: drawn %.3f m, collision %.3f m worst off height_at()" % [worst.drawn, worst.collision])


## The hero hurries at the line from 6 m in, turned `slant` degrees off straight out, for 7 s.
func _walk(side: int, along: float, slant: float) -> void:
	var d := _side(side)
	var start: Vector3 = d[0] * (half - 6.0) + d[1] * along
	var out: Vector3 = d[0].rotated(Vector3.UP, deg_to_rad(slant))
	player.place(Vector3(start.x, world.height_at(start.x, start.z) + 0.05, start.z), _yaw(out))
	await frames(5)
	var tag := "walk %s %.0f, %.0f deg" % ["ESWN"[side], along, slant]
	action(&"move_forward", true)
	action(&"hurry", true)
	var jolt := 0.0
	var jolt_at := 0.0  # metres from the line
	var past := 0.0
	var was := 0.0
	for i in 60 * 7:
		await frames(1)
		var p: Vector3 = player.body.global_position
		past = maxf(past, world.past(p))
		if was - player.moved > jolt:
			jolt = was - player.moved  # m/s lost in one frame
			jolt_at = half - p.dot(d[0])
		was = player.moved
	action(&"move_forward", false)
	action(&"hurry", false)
	await frames(30)
	var p: Vector3 = player.body.global_position
	var s: Dictionary = player.state().player
	var gap: float = half - p.dot(d[0])
	check(past < 0.005, "%s: never past the line (%.3f m)" % [tag, past])
	check(gap < 0.3 or not s.inside.is_empty(), "%s: stops on the line (%.2f m short)" % [tag, gap])
	# a turn into the slide takes speed off faster than the brakes (the walk's own rule); head-on it is the brakes,
	# give or take 5 cm/s in a frame (a wall would take all 1.6 m/s at once; the last step goes at once, _held())
	check(slant > 0.0 or jolt < player.brake / 60.0 * 1.25 + 0.05, "%s: slows at its braking (%.3f m/s lost in a frame %.2f m from the line, brakes %.3f)" % [tag, jolt, jolt_at, player.brake / 60.0])
	check(s.onFloor and absf(p.y - world.height_at(p.x, p.z)) < 0.1, "%s: stands on the ground (%.2f m off)" % [tag, p.y - world.height_at(p.x, p.z)])


## The rover drives at the line from 12 m short of where its hatch room starts, forward or backing, for 9 s; then
## the driver gets out.
func _drive(side: int, along: float, backing: bool) -> void:
	var rover: Node3D = world.items["rover"]
	var d := _side(side)
	var reach := float(world.data.bound.reach)
	var start: Vector3 = d[0] * (half - reach - 12.0) + d[1] * along
	var face: Vector3 = -d[0] if backing else d[0]
	rover.yaw = -deg_to_rad(_yaw(face))
	rover.v = 0.0
	rover._apply(rover._pose(Vector3(start.x, 0.0, start.z), rover.yaw))
	player.enter(rover)
	await frames(5)
	var tag := "drive %s %.0f%s" % ["ESWN"[side], along, " backing" if backing else ""]
	var key: StringName = &"move_back" if backing else &"move_forward"
	action(key, true)
	var jolt := 0.0
	var past := 0.0
	var off := 0.0
	var was := 0.0
	var why := ""
	for i in 60 * 9:
		await frames(1)
		why = rover.blocked
		past = maxf(past, world.past(rover.global_position, reach))
		jolt = maxf(jolt, (absf(was) - absf(rover.v)) * 60.0)
		was = rover.v
		var g: float = world.height_at(rover.global_position.x, rover.global_position.z)
		off = maxf(off, absf(rover.global_position.y - g))
	action(key, false)
	await frames(2)
	var gap: float = (half - reach) - rover.global_position.dot(d[0])
	check(past < 0.01, "%s: its hatch room never past the line (%.3f m)" % [tag, past])
	check(gap < 0.5 and why == "edge", "%s: brakes to a stop at the line (%.2f m short, %s)" % [tag, gap, why])
	check(jolt < rover.brake * 1.1 + 0.05, "%s: slows at its braking (%.2f m/s2, brakes %.2f)" % [tag, jolt, rover.brake])
	check(off < 0.3, "%s: rides the drawn ground (%.2f m off at most)" % [tag, off])
	player.exit()
	await frames(60)
	var p: Vector3 = player.body.global_position
	var s: Dictionary = player.state().player
	check(world.past(p) == 0.0 and s.onFloor and absf(p.y - world.height_at(p.x, p.z)) < 0.1,
		"%s: the driver gets out onto the ground (%s, on floor %s)" % [tag, p, s.onFloor])


func _net() -> void:
	var at := Vector3(120.0, 0.0, 40.0)
	var h: float = world.height_at(at.x, at.z)
	player.place(Vector3(at.x, h + 0.05, at.z), 0.0)
	await frames(10)
	player.body.global_position = Vector3(at.x, h - 1.0, at.z)  # pushed through the ground
	await frames(3)
	check(player.body.global_position.y > h - 0.05, "net: a hero 1 m under the ground is back on top (%.2f)" % (player.body.global_position.y - h))
	player.body.global_position = Vector3(half + 30.0, h + 0.5, at.z)  # out over the backdrop, falling
	await frames(3)
	var p: Vector3 = player.body.global_position
	check(world.past(p) == 0.0 and p.y > world.height_at(p.x, p.z) - 0.05, "net: a hero past the line is back inside on top (%s)" % p)
	check(game.cover.visible, "net: a far move happens behind the fade")
	await frames(60)
	for id: String in ["rover", "pip", "bag1"]:
		var n: Node3D = world.items[id]
		var q: Vector3 = n.global_position
		var g: float = world.height_at(q.x, q.z)
		n.global_position = Vector3(q.x, g - 1.0, q.z)
		await frames(3)
		check(n.global_position.y > world.height_at(n.global_position.x, n.global_position.z) - 0.35, "net: %s under the ground is back on top" % id)
