extends Node3D
## The drawn hero: a rigged model through the house style, its gait clips blended by the speed the body really
## has, and a hop posed from code over the idle clip for a model that ships no jump clip
## (skills/character-life sections 1 to 3, skills/contextual-traversal rule 9).

var feel: Dictionary  # tuning.json `hop`: the feel numbers of the code-posed hop, judged on film
var anim: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
var fold: Fold
var bounds: AABB  # the drawn body in the idle pose, in this node's space (feet at y = 0, centred on the axis)
var clip_speed := {}  # "walk" and "run": the ground speed each stride was made for, m/s
var clips := {}  # "idle", "walk", "run": names in the player's library
var foot_bones: Array[int] = []
var phase := ""  # "", "crouch", "air"
var fold_target := 0.0


## `rig` names the clips and bones of this model: {idle, walk, run, feet: [l, r], hips, legs: [[thigh, shin, foot], ...]}.
func setup(model: Node3D, design: Dictionary, rig: Dictionary, hop: Dictionary) -> void:
	feel = hop
	Forge.HouseStyle.apply(model, design)
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for k: String in ["idle", "walk", "run"]:
		clips[k] = _find_clip(rig[k])
		anim.get_animation(clips[k]).loop_mode = Animation.LOOP_LINEAR  # the import leaves gait clips playing once
	for f: String in rig.feet:
		foot_bones.append(skeleton.find_bone(f))
	for k: String in ["walk", "run"]:
		clip_speed[k] = _ground_speed(model, clips[k], rig.feet)
	anim.play(clips.idle)
	anim.seek(0.0, true)
	var raw := _skinned_bounds(model)
	# glTF models face +Z, the game's front is -Z at yaw 0; centring the drawn body on the axis keeps a turn
	# from swinging it out of the collider
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var c := (flip * raw).get_center()
	model.transform = Transform3D(flip.basis, Vector3(-c.x, 0, -c.z))
	bounds = model.transform * raw
	anim.stop()
	_build_tree(model)
	fold = Fold.new()
	skeleton.add_child(fold)
	fold.setup(skeleton, model, rig)


## Called every physics frame by the body. `speed` is the real horizontal speed, `idle` the speed under which it stands.
func update(speed: float, idle: float, on_floor: bool, rising: bool, impact: float, delta: float) -> void:
	tree.set(&"parameters/move/gait/blend_position", speed)
	# below the slowest clip or above the fastest the stride stays and the cadence changes, so no foot slides
	var slow: float = clip_speed.walk
	var fast: float = clip_speed.run
	tree.set(&"parameters/move/pace/scale", speed / clampf(speed, slow, fast) if speed > 0.0 else 1.0)
	if phase == "air" and on_floor:
		phase = ""
		fold.amount = maxf(fold.amount, impact * feel.squash)  # the landing squash, then it eases out
		fold_target = 0.0
	elif phase == "air":
		fold_target = 0.0 if rising else feel.tuck
	elif phase == "" and not on_floor and not rising:
		phase = "air"  # stepped off something: no anticipation, just the fall
	fold.grounded = on_floor
	fold.amount = lerpf(fold.amount, fold_target, 1.0 - exp(-feel.fold_rate * delta))
	var playback: AnimationNodeStateMachinePlayback = tree.get(&"parameters/playback")
	playback.travel(&"hop" if phase != "" else (&"move" if speed > idle else &"idle"))


## Where each foot is drawn now, in world space (the pose the tree last gave, before Fold).
func feet() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b in foot_bones:
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(b).origin)
	return out


func crouch() -> void:
	phase = "crouch"
	fold_target = feel.crouch


func take_off() -> void:
	phase = "air"
	fold_target = 0.0


func reset() -> void:
	phase = ""
	fold_target = 0.0
	fold.amount = 0.0
	var playback: AnimationNodeStateMachinePlayback = tree.get(&"parameters/playback")
	playback.start(&"idle")


func _find_clip(name: String) -> StringName:
	for c: StringName in anim.get_animation_list():
		if c == name or c.ends_with("|" + name):  # kit clips arrive as Armature|Name
			return c
	push_error("hero model has no clip %s" % name)
	return &""


## The ground speed a gait clip was made for: how fast a planted foot moves back under the body, read at
## mid-stance (the foot's lowest frame) of each foot and averaged. Assumes the clip runs in place facing +Z.
func _ground_speed(model: Node3D, clip: StringName, feet: Array) -> float:
	var a := anim.get_animation(clip)
	var n := 40
	var dt := a.length / n
	var to_model := model.global_transform.affine_inverse() * skeleton.global_transform
	anim.play(clip)
	var track := {}
	for f: String in feet:
		track[f] = []
	for i in n:
		anim.seek(i * dt, true)
		for f: String in feet:
			track[f].append(to_model * skeleton.get_bone_global_pose(skeleton.find_bone(f)).origin)
	var total := 0.0
	var k := n / 20  # a tenth of the stride around mid-stance
	for f: String in feet:
		var p: Array = track[f]
		var low := 0
		for i in n:
			if p[i].y < p[low].y:
				low = i
		total += (p[(low - k + n) % n].z - p[(low + k) % n].z) / (2 * k * dt)
	return total / feet.size()


## The drawn body as the GPU skins it in the current pose, in the model's own space. A skinned mesh's get_aabb()
## is its bind pose (arms out) in file units, which says nothing about the body the player sees.
func _skinned_bounds(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var to_model := model.global_transform.affine_inverse() * skeleton.global_transform
	for mi: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		var binds: Array[Transform3D] = []
		for i in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(i)
			if bone < 0:
				bone = skeleton.find_bone(mi.skin.get_bind_name(i))
			binds.append(to_model * skeleton.get_bone_global_pose(bone) * mi.skin.get_bind_pose(i))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / verts.size()
			for i in verts.size():
				var p := Vector3.ZERO
				for j in per:
					var w := weights[i * per + j]
					if w > 0.0:
						p += w * (binds[bones[i * per + j]] * verts[i])
				if first:
					out = AABB(p, Vector3.ZERO)
					first = false
				else:
					out = out.expand(p)
	return out


func _build_tree(model: Node3D) -> void:
	var sm := AnimationNodeStateMachine.new()
	sm.add_node(&"idle", _clip_node(clips.idle))
	sm.add_node(&"hop", _clip_node(clips.idle))  # no jump clip: the hop is the idle pose folded by Fold
	var gait := AnimationNodeBlendSpace1D.new()
	gait.min_space = clip_speed.walk
	gait.max_space = clip_speed.run
	gait.sync = true  # feet stay in step through the blend
	gait.add_blend_point(_clip_node(clips.walk), clip_speed.walk, -1, &"walk")
	gait.add_blend_point(_clip_node(clips.run), clip_speed.run, -1, &"run")
	var move := AnimationNodeBlendTree.new()
	move.add_node(&"gait", gait)
	move.add_node(&"pace", AnimationNodeTimeScale.new())
	move.connect_node(&"pace", 0, &"gait")
	move.connect_node(&"output", 0, &"pace")
	sm.add_node(&"move", move)
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO  # or the tree sits in Start
	sm.add_transition(&"Start", &"idle", start)
	for a: StringName in [&"idle", &"move", &"hop"]:
		for b: StringName in [&"idle", &"move", &"hop"]:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = feel.xfade
				sm.add_transition(a, b, t)
	tree = AnimationTree.new()
	tree.tree_root = sm
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true


func _clip_node(clip: StringName) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = clip
	return a


## Bends both legs by `amount` metres: on the floor the hips come down and the feet stay planted (a crouch), in
## the air the hips stay and the feet come up (a tuck). Runs after the AnimationTree, over whatever it posed.
class Fold extends SkeletonModifier3D:
	var amount := 0.0
	var grounded := true
	var legs: Array = []  # [thigh, shin, foot] bone indices per leg
	var hips := -1
	var leg_length := 1.0  # m, thigh plus shin
	var right := Vector3.RIGHT  # the body's side axis, in skeleton space
	var up := Vector3.UP  # one metre up, in skeleton space

	func setup(s: Skeleton3D, model: Node3D, rig: Dictionary) -> void:
		var to_skel := s.global_transform.affine_inverse() * model.global_transform
		var to_model := to_skel.affine_inverse()
		hips = s.find_bone(rig.hips)
		for names: Array in rig.legs:
			legs.append(names.map(func(n: String) -> int: return s.find_bone(n)))
		var leg: Array = legs[0]
		var at := func(b: int) -> Vector3: return to_model * s.get_bone_global_pose(b).origin
		leg_length = at.call(leg[0]).distance_to(at.call(leg[1])) + at.call(leg[1]).distance_to(at.call(leg[2]))
		# the model's own axes (before the flip to -Z): +X is the side the knees bend about, +Z the front
		right = (to_skel.basis * Vector3.RIGHT).normalized()
		up = to_skel.basis * Vector3.UP

	func _process_modification_with_delta(_delta: float) -> void:
		if amount <= 0.0:
			return
		var s := get_skeleton()
		var a := acos(clampf(1.0 - amount / leg_length, -1.0, 1.0))
		if grounded:
			var h := s.get_bone_global_pose(hips)
			s.set_bone_global_pose(hips, Transform3D(h.basis, h.origin - up * amount))
		for leg: Array in legs:
			# knee forward, shin back, foot level again: the thigh and shin each lean `a` from upright
			for i in 3:
				var b: int = leg[i]
				var g := s.get_bone_global_pose(b)
				s.set_bone_global_pose(b, Transform3D(Basis(right, [-a, 2.0 * a, -a][i]) * g.basis, g.origin))
