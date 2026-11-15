extends "res://addons/forge/test.gd"
## The camera past a pole, and out from a wall (15 Nov playtest: "if I move the hero so another object comes between
## him and the camera, the hero goes faster, teleports, the camera becomes a shaky slideshow"):
##   godot --headless --fixed-fps 60 --path . -s tests/cam_pole_test.gd
## The hero walks sideways across the view so a lamp's mast crosses the arm's last stretch, between the lens and the
## hero: the lens keeps its distance (no jump in a frame, no pull in and out) and the hero keeps its pace. Then the
## hero walks away from a wall the lens was squeezed against: the lens comes out at tuning.json camera.out_rate at
## most, never in a jump.

const PROPS := 2 | 4 | 16 | 64  # CONTRACTS.md: statics, thin, vehicles, carriables
const BACK := 3.4  # m the pole stands behind the hero's line, toward the lens: in the arm's last 1.2 m
const SIDE := 3.0  # m either side of the pole the walk starts and ends

var game: Node3D
var player: Node3D
var cam: Node3D
var space: PhysicsDirectSpaceState3D


func _init() -> void:
	watchdog = 240.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	while game.busy():
		await process_frame
	player = game.player
	cam = player.cam
	space = game.world.get_world_3d().direct_space_state
	game.clock.pinned = true
	game.pip.process_mode = Node.PROCESS_MODE_DISABLED  # it wanders: a robot rolling through the walk is not the camera's doing
	await pole()
	await wall()
	return true


## The bodies of `item`, to leave out of a clearance check.
func _own(item: Node3D) -> Array[RID]:
	var out: Array[RID] = []
	for b: CollisionObject3D in item.find_children("*", "CollisionObject3D", true, false):
		out.append(b.get_rid())
	return out


## Whether a level box `size` centred `at` (its long sides along `basis`) is free of every prop but `but`.
func _free(at: Vector3, basis: Basis, size: Vector3, but: Array[RID]) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = size
	q.shape = box
	q.transform = Transform3D(basis, at)
	q.collision_mask = PROPS
	q.exclude = but + [player.body.get_rid()]
	return space.intersect_shape(q, 1).is_empty()


func pole() -> void:
	# a lamp with room round it: the walk's corridor and the arm's sweep behind it hold nothing else
	var found := false
	var from := Vector3.ZERO
	var view := 0.0
	for id: String in game.world.items:
		if found or not str(game.world.items[id].get_meta("prefab", "")) == "lamp":
			continue
		var p: Vector3 = game.world.items[id].global_position
		for turn in 8:
			view = TAU * turn / 8.0
			var b := Basis(Vector3.UP, view)  # the view's frame: -Z ahead, +Z back toward the lens, +X to its right
			var mid: Vector3 = p + b * Vector3(0.0, 2.0, 1.4 - BACK)
			if _free(mid, b, Vector3(2.0 * SIDE + 1.5, 3.0, 6.5), _own(game.world.items[id])):
				from = p + b * Vector3(-SIDE, 0.0, -BACK)
				found = true
				break
	if not check(found, "a lamp with open ground to walk past"):
		return
	game.place(Vector3(from.x, 0.05, from.z), -rad_to_deg(view))
	await frames(90)
	var dist0: float = cam.dist
	var lo := INF
	var hi := -INF
	var jump := 0.0
	var pace_lo := INF
	var pace_hi := 0.0
	var last: Vector3 = player.body.global_position
	var before: float = cam.dist
	action(&"move_right", true)
	for i in int(2.0 * SIDE / float(player.walk) * 60.0):
		await physics_frame
		cam.idle = 0.0  # the player holds the view: left alone it would drift round behind the walk and off the lamp
		var at: Vector3 = player.body.global_position
		jump = maxf(jump, absf(cam.dist - before))
		before = cam.dist
		lo = minf(lo, cam.dist)
		hi = maxf(hi, cam.dist)
		if i > 90:  # turned to the side and up to pace
			pace_lo = minf(pace_lo, at.distance_to(last) * 60.0)
			pace_hi = maxf(pace_hi, at.distance_to(last) * 60.0)
		last = at
	action(&"move_right", false)
	print("  past the lamp: the lens %.2f to %.2f m from the pivot (%.2f before), %.3f m the largest change in a frame; the hero at %.2f to %.2f m/s" % [lo, hi, dist0, jump, pace_lo, pace_hi])
	check(absf(wrapf(cam.yaw - view, -PI, PI)) < deg_to_rad(10.0), "the view stayed across the walk (%.0f deg off)" % rad_to_deg(wrapf(cam.yaw - view, -PI, PI)))
	check(jump < 0.03, "a lamp's mast between the lens and the hero: the lens never jumps (%.3f m in a frame)" % jump)
	check(hi - lo < 0.25, "and is not pulled in and let out (%.2f to %.2f m)" % [lo, hi])
	check(pace_hi - pace_lo < 0.1 * float(player.walk), "the hero keeps its pace (%.2f to %.2f m/s)" % [pace_lo, pace_hi])


func wall() -> void:
	# HAB 1's outside wall, from a side with open ground: the hero a metre off it, its back to it, the lens squeezed
	var hab: Vector3 = game.world.items.hab1.global_position
	var found := false
	var at := Vector3.ZERO
	var out := Vector3.ZERO
	for turn in 16:
		out = Basis(Vector3.UP, TAU * turn / 16.0) * Vector3.FORWARD
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(hab + out * 12.0 + Vector3.UP * 1.6, hab + Vector3.UP * 1.6, 2))
		if hit.is_empty():
			continue
		at = hit.position + out * 1.0
		var b := Basis.looking_at(out)
		if _free(hit.position + out * 4.3 + Vector3.UP * 0.6, b, Vector3(3.0, 3.6, 7.0), []):
			found = true
			break
	if not check(found, "a side of HAB 1 with open ground"):
		return
	game.place(Vector3(at.x, 0.05, at.z), rad_to_deg(atan2(out.x, -out.z)))
	await frames(90)
	var squeezed: float = cam.dist
	var rate: float = float(player.tuning.camera.out_rate)
	var fastest := 0.0
	var before: float = cam.dist
	action(&"move_forward", true)
	for i in 240:
		await physics_frame
		fastest = maxf(fastest, (cam.dist - before) * 60.0)
		before = cam.dist
	action(&"move_forward", false)
	print("  away from the wall: the lens from %.2f m out to %.2f m, at %.2f m/s at most" % [squeezed, cam.dist, fastest])
	check(squeezed < float(player.tuning.camera.distance) - 1.0, "against a wall the lens is pulled in (%.2f m)" % squeezed)
	check(cam.dist > squeezed + 1.5, "walking away lets it out again (%.2f m)" % cam.dist)
	check(fastest <= rate + 0.05, "slowly: %.2f m/s at most (out_rate %.1f)" % [fastest, rate])
