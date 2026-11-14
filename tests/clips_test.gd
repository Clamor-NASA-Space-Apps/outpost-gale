extends "res://addons/forge/test.gd"
## The hero's use clips (Lane A): godot --headless --path . -s tests/clips_test.gd
## Every clip in data/clips.json is on the hero. Each use clip (one with `planted` boots) is drawn at 12 phases on
## the shipped model, skinned on the CPU: no vertex under the floor, no glove inside the helmet or the chest unit,
## the planted boots still, the lean under the sheet's hero.lean.max, a kneel's knee on the floor and the working
## glove where clips.json says. Then sit() through the real player on a flat floor.

const MODEL := "res://models/character_suited.glb"
const PHASES := 12
const FLOOR_SLACK := 0.02  # m under the idle pose's lowest point that still counts as on the floor (the boots' dust sink is 0.01)
const SLIDE := 0.02  # m a planted boot may move (the plan's check)
const HAND := 0.05  # m between the drawn glove and clips.json's point at the work time
const BOOT := 0.06  # share of its standing distance to the ankle a boot vertex may lose: a walk loses under 2%, the boot
# crushed by a folded ankle in a kneel (13 Nov review) lost 12%

var clips: Dictionary
var lean_max: float
var anim: AnimationPlayer
var skel: Skeleton3D
var to_model: Transform3D
var meshes: Array[Dictionary] = []  # per skinned mesh: verts, bones, weights, per, binds (bone ids), top (bone name)


func _init() -> void:
	watchdog = 240.0


func play() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/clips.json"))
	clips = data.clips
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json"))
	for r: Dictionary in sheet.rows:
		if r.id == "hero.lean.max":
			lean_max = r.value
	var model: Node3D = load(MODEL).instantiate()
	root.add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	to_model = model.global_transform.affine_inverse() * skel.global_transform
	for c: String in clips:
		var ok := anim.has_animation(c)
		check(ok, "%s is in clips.json but not on the hero" % c)
		if ok:
			check(anim.get_animation(c).length > 0.3, "%s lasts %.2f s, under 0.3" % [c, anim.get_animation(c).length])
			check(absf(anim.get_animation(c).length - clips[c].length) < 0.05, "%s: clips.json says %.2f s, the model %.2f" % [c, clips[c].length, anim.get_animation(c).length])
	_read_meshes()
	await poses()
	model.queue_free()
	await frames(2)
	await player_methods()
	return true


func _read_meshes() -> void:
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", true, false):
		var binds: Array[int] = []
		var bind_pose: Array[Transform3D] = []
		for i in mi.skin.get_bind_count():
			var b := mi.skin.get_bind_bone(i)
			binds.append(b if b >= 0 else skel.find_bone(mi.skin.get_bind_name(i)))
			bind_pose.append(mi.skin.get_bind_pose(i))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			var top := PackedStringArray()
			for i in verts.size():
				var best := 0
				for j in per:
					if weights[i * per + j] > weights[i * per + best]:
						best = j
				top.append(skel.get_bone_name(binds[bones[i * per + best]]))
			meshes.append({"verts": verts, "bones": bones, "weights": weights, "per": per, "binds": binds, "bind_pose": bind_pose, "top": top})


## Every vertex where the GPU draws it in the current pose, in the model's space (y up, feet at 0, front +Z).
func _skinned() -> PackedVector3Array:
	var out := PackedVector3Array()
	for m: Dictionary in meshes:
		var mats: Array[Transform3D] = []
		for i in m.binds.size():
			mats.append(to_model * skel.get_bone_global_pose(m.binds[i]) * m.bind_pose[i])
		var verts: PackedVector3Array = m.verts
		var bones: PackedInt32Array = m.bones
		var weights: PackedFloat32Array = m.weights
		var per: int = m.per
		for i in verts.size():
			var p := Vector3.ZERO
			for j in per:
				var w := weights[i * per + j]
				if w > 0.0:
					p += w * (mats[bones[i * per + j]] * verts[i])
			out.append(p)
	return out


## Indices (into _skinned()) of the vertices whose strongest bone passes `pick`.
func _where(pick: Callable) -> PackedInt32Array:
	var out := PackedInt32Array()
	var k := 0
	for m: Dictionary in meshes:
		for name: String in m.top:
			if pick.call(name, k):
				out.append(k)
			k += 1
	return out


## {vertex index: bone} for every vertex weighted at least 5% to a bone whose name starts with `prefix`.
func _weighted(prefix: String) -> Dictionary:
	var out := {}
	var k := 0
	for m: Dictionary in meshes:
		var bones: PackedInt32Array = m.bones
		var weights: PackedFloat32Array = m.weights
		for i in m.top.size():
			for j in m.per:
				var name := skel.get_bone_name(m.binds[bones[i * m.per + j]])
				if weights[i * m.per + j] >= 0.05 and name.begins_with(prefix):
					out[k] = name
			k += 1
	return out


func _top(k: int) -> String:
	for m: Dictionary in meshes:
		if k < m.top.size():
			return m.top[k]
		k -= m.top.size()
	return ""


func _bone(name: String) -> Transform3D:
	return to_model * skel.get_bone_global_pose(skel.find_bone(name))


func _pose(clip: String, t: float) -> void:
	anim.play(clip)
	anim.seek(t, true)


func poses() -> void:
	_pose("idle", 0.0)
	var rest := _skinned()
	var floor_y := INF
	for p in rest:
		floor_y = minf(floor_y, p.y)
	var gloves := _where(func(b: String, _k: int) -> bool: return b == "hand_l" or b == "hand_r")
	var helmet := _where(func(b: String, _k: int) -> bool: return b == "Head")
	# the chest unit: the box bolted to the upper torso in front (forge/hero_astronaut.py in_dcm)
	var dcm := _where(func(b: String, k: int) -> bool: return b == "spine_03" and rest[k].z > 0.15 and absf(rest[k].x) < 0.115 and rest[k].y > 1.2 and rest[k].y < 1.54)
	# the boot and the shaft over it: every vertex the foot bone moves at all. A bent ankle pulls the blended ones in
	# toward the joint (linear skinning loses volume), and a fold crushes them right onto it
	var boots := _weighted("foot_")
	var boot_rest := PackedFloat32Array()
	for k: int in boots:
		boot_rest.append(rest[k].distance_to(_bone(boots[k]).origin))
	var knees := _where(func(b: String, k: int) -> bool: return (b.begins_with("calf") or b.begins_with("thigh")) and rest[k].y > 0.35 and rest[k].y < 0.65)
	# the helmet and the chest unit as boxes in their own bone's space: a glove inside the ellipsoid that fills
	# the helmet's box, or inside the chest unit's box less a centimetre, goes through it
	var head := _bone("Head").affine_inverse()
	var hbox := AABB(head * rest[helmet[0]], Vector3.ZERO)
	for i in helmet:
		hbox = hbox.expand(head * rest[i])
	var chest := _bone("spine_03").affine_inverse()
	var cbox := AABB(chest * rest[dcm[0]], Vector3.ZERO)
	for i in dcm:
		cbox = cbox.expand(chest * rest[i])
	cbox = cbox.grow(-0.01)
	check(dcm.size() > 20 and helmet.size() > 100 and gloves.size() > 100, "found the chest unit (%d), helmet (%d) and gloves (%d)" % [dcm.size(), helmet.size(), gloves.size()])
	for c: String in clips:
		if not clips[c].has("planted"):
			continue
		var L: float = clips[c].length
		var feet := {}
		var low := INF
		var low_at := ""
		var lean := -INF
		var in_helmet := 0
		var in_chest := 0.0  # m, the deepest a glove goes into the chest unit
		var chest_at := ""  # which glove and when, for the message
		var slide := 0.0
		var fold := 0.0  # the most a boot vertex closes in on its ankle, as a share of its standing distance
		for i in PHASES + 1:
			_pose(c, L * i / PHASES)
			var pts := _skinned()
			for k in pts.size():
				if pts[k].y < low:
					low = pts[k].y
					low_at = "%s at %.2f s" % [_top(k), L * i / PHASES]
			var h := _bone("Head").affine_inverse()
			var ch := _bone("spine_03").affine_inverse()
			for g in gloves:
				var q := (h * pts[g] - hbox.get_center()) / (hbox.size / 2.0)
				if q.length_squared() < 1.0:
					in_helmet += 1
				var q2 := ch * pts[g]
				if cbox.has_point(q2):
					var a := q2 - cbox.position
					var b := cbox.end - q2
					var deep := minf(minf(minf(a.x, b.x), minf(a.y, b.y)), minf(a.z, b.z))
					if deep > in_chest:
						in_chest = deep
						chest_at = "%s at %.2f s" % [_top(g), L * i / PHASES]
			var ankle := {"foot_l": _bone("foot_l").origin, "foot_r": _bone("foot_r").origin}
			var j := 0
			for k: int in boots:
				if boot_rest[j] > 0.05:  # near the joint itself a share means nothing
					fold = maxf(fold, 1.0 - pts[k].distance_to(ankle[boots[k]]) / boot_rest[j])
				j += 1
			var d := _bone("neck_01").origin - _bone("pelvis").origin
			lean = maxf(lean, rad_to_deg(atan2(d.z, d.y)))
			for f: String in clips[c].planted:
				var at := _bone(f).origin
				if not feet.has(f):
					feet[f] = at
				slide = maxf(slide, at.distance_to(feet[f]))
		check(low >= floor_y - FLOOR_SLACK, "%s: the suit goes %.3f m into the floor (%s)" % [c, floor_y - low, low_at])
		check(in_helmet == 0, "%s: a glove is inside the helmet (%d vertex frames)" % [c, in_helmet])
		check(in_chest == 0.0, "%s: a glove goes %.3f m into the chest unit (%s)" % [c, in_chest + 0.01, chest_at])
		check(lean <= lean_max, "%s: leans %.1f degrees, the sheet allows %.0f" % [c, lean, lean_max])
		check(slide < SLIDE, "%s: a planted boot moves %.3f m" % [c, slide])
		check(fold < BOOT, "%s: a boot folds, a vertex comes %d%% closer to its ankle" % [c, roundi(fold * 100.0)])
		if clips[c].has("hand"):
			_pose(c, L * clips[c].work_at)
			var v: Array = clips[c].hand
			var gap := _bone(clips[c].hand_bone).origin.distance_to(Vector3(v[0], v[1], v[2]))
			check(gap < HAND, "%s: the glove is %.3f m from clips.json's hand at the work time" % [c, gap])
		if c.begins_with("kneel") or c.ends_with("_kneel"):
			_pose(c, L * clips[c].work_at)
			var pts := _skinned()
			var knee := INF
			for k in knees:
				knee = minf(knee, pts[k].y)
			check(knee - floor_y < 0.03, "%s: the knee is %.3f m over the floor at the work time" % [c, knee - floor_y])


## The player's seat on a flat floor: sit() goes down and up (the use clips themselves are gone, 14 Nov).
func player_methods() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	world.add_child(ground)
	var player: Node3D = load("res://player/player.gd").new()
	player.name = "Player"
	world.add_child(player)
	await frames(3)
	player.place(Vector3.ZERO, 0.0)
	await frames(30)
	var model: Node3D = player.model
	# sit and stand: down onto a seat behind, idle there, up again on a move key, where it sat
	var at: Vector3 = player.body.global_position
	player.sit(true)
	await frames(ceili(float(clips.sit_down.length) * Engine.physics_ticks_per_second) + 20)
	await process_frame
	check(player.seated and model.state == &"sit_idle", "sit(true) ends in sit_idle (%s)" % model.state)
	action(&"move_forward", true)
	await frames(5)
	action(&"move_forward", false)
	check(not player.seated and model.state == &"sit_to_stand", "a move key stands the hero up (%s)" % model.state)
	await frames(ceili(float(clips.sit_to_stand.length) * Engine.physics_ticks_per_second) + 20)
	await process_frame
	check(model.state == &"idle" and player.cut.is_empty(), "sit(false) ends standing in idle (%s)" % model.state)
	check(player.body.global_position.distance_to(at) < 0.05, "sitting and standing leave the body where it was")
	world.queue_free()
