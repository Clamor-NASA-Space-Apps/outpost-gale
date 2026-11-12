extends Node3D
## The drawn hero: a rigged model through the house style, its clips (data/clips.json) in an AnimationTree. Gaits
## blend by the speed the body really has, footsteps fire on each clip's measured touchdown, the hop plays its
## three clips timed to the body's arc, and a carried bag rides on the chest (skills/character-life sections 1 to
## 3, skills/suited-locomotion section 4, skills/contextual-traversal rule 9).

const GAITS := ["walk", "lope"]  # the move blend, slowest first
const CARRY := "carry_walk"

var anim: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var skeleton: Skeleton3D
var bounds: AABB  # the drawn body in the idle pose, in this node's space (feet at y = 0, centred on the axis)
var clip_speed := {}  # gait clip -> the ground speed its stride was made for, m/s, measured from the feet
var touchdown := {}  # gait clip -> [left, right] phase (0..1) where each boot lands, from clips.json
var foot_bones: Array[int] = []
var chest := -1  # the bone a carried bag rides on
var bag_at: Transform3D  # the bag's centre in the chest bone's space, in the carry pose
var hip_sit: Vector3  # the drawn hips in drive_sit, in the hero's space: what goes on a seat
var state := &"idle"
var phase := ""  # "", "crouch", "air", "land", "act", "sit"
var timer := 0.0  # seconds left in a timed phase (landing, interacting)
var last_phase := -1.0  # where the gait cycle was last frame, 0..1, negative outside a gait
var clips: Dictionary
var feel: Dictionary


## `info` is data/clips.json, `hop` tuning.json `hop`, `sink` how far the drawn boots sit in the dust and
## `contact` how close to its lowest a foot counts as down (m).
func setup(model: Node3D, design: Dictionary, info: Dictionary, hop: Dictionary, sink: float, contact: float) -> void:
	clips = info.clips
	feel = hop
	Forge.HouseStyle.apply(model, design)
	add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for c: String in clips:
		# loops are not in the file: the import leaves every clip playing once
		anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR if clips[c].loop else Animation.LOOP_NONE
	var feet: Array = [info.feet.left, info.feet.right]
	for f: String in feet:
		foot_bones.append(skeleton.find_bone(f))
	for g: String in GAITS + [CARRY]:
		clip_speed[g] = _ground_speed(model, g, feet, contact)
		touchdown[g] = [clips[g].foot_l.touchdown[0], clips[g].foot_r.touchdown[0]]
	anim.play(&"idle")
	anim.seek(0.0, true)
	var points := _skinned_points(model)
	var raw := AABB(points[0], Vector3.ZERO)
	for p in points:
		raw = raw.expand(p)
	# glTF models face +Z, the game's front is -Z at yaw 0; centring the drawn body on the axis keeps a turn
	# from swinging it out of the collider. The drawn body sinks into the dust; the collider stays on top.
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var c := (flip * raw).get_center()
	model.transform = Transform3D(flip.basis, Vector3(-c.x, -sink, -c.z))
	bounds = Transform3D(flip.basis, Vector3(-c.x, 0, -c.z)) * raw
	var to_hero := global_transform.affine_inverse() * skeleton.global_transform
	chest = skeleton.find_bone(clips.carry_idle.bag_bone)
	anim.play(&"carry_idle")
	anim.seek(0.0, true)
	var bag: Array = clips.carry_idle.bag_center_godot  # in the model's own space, facing +Z
	var model_to_skel := skeleton.global_transform.affine_inverse() * model.global_transform
	bag_at = skeleton.get_bone_global_pose(chest).affine_inverse() * Transform3D(model_to_skel.basis, model_to_skel * Vector3(bag[0], bag[1], bag[2]))
	anim.play(&"drive_sit")
	anim.seek(0.0, true)
	hip_sit = to_hero * skeleton.get_bone_global_pose(skeleton.find_bone(&"pelvis")).origin  # as drawn, sink included
	anim.stop()
	_build_tree(model)


## Called every physics frame by the body. `speed` is the real horizontal speed, `idle` the speed under which it
## stands. Returns the feet (0 left, 1 right) that touched down this frame.
func update(speed: float, idle: float, on_floor: bool, carrying: bool, delta: float) -> Array[int]:
	var gait := CARRY if carrying else ""
	tree.set(&"parameters/move/gait/blend_position", speed)
	tree.set(&"parameters/carry_move/pace/scale", speed / clip_speed[CARRY])
	# below the slowest clip or above the fastest the stride stays and the cadence changes, so no foot slides
	var slow: float = clip_speed[GAITS[0]]
	var fast: float = clip_speed[GAITS[-1]]
	tree.set(&"parameters/move/pace/scale", speed / clampf(speed, slow, fast) if speed > 0.0 else 1.0)
	timer -= delta
	match phase:
		"air":
			if on_floor:
				phase = "land"
				timer = clips.hop_land.length
		"land", "act":
			if timer <= 0.0 or speed > idle:
				phase = ""  # walking off cuts the landing or the reach short: an in-place clip would skate
		"":
			if not on_floor:
				phase = "air"  # stepped off something: no anticipation, just the fall
	var next: StringName
	match phase:
		"crouch": next = &"hop_start"
		"air": next = &"hop_air"
		"land": next = &"hop_land"
		"act": next = &"interact"
		"sit": next = &"drive_sit"
		_:
			if speed > idle:
				next = &"carry_move" if carrying else &"move"
			else:
				next = &"carry_idle" if carrying else &"idle"
	if next != state:
		state = next
		playback.travel(state)
	# a gait cycle's phase, where touchdowns are measured; every gait clip starts on the left boot's touchdown
	var out: Array[int] = []
	var cycle := -1.0
	if state in [&"move", &"carry_move"] and playback.get_current_node() == state and playback.get_current_length() > 0.0:
		cycle = fposmod(playback.get_current_play_position() / playback.get_current_length(), 1.0)
	if cycle >= 0.0 and last_phase >= 0.0:
		var td: Array = touchdown[gait if gait != "" else GAITS[0]]
		for i in 2:
			var t: float = td[i]
			var crossed := (last_phase < t and t <= cycle) if cycle >= last_phase else (t > last_phase or t <= cycle)
			if crossed:
				out.append(i)
	last_phase = cycle
	return out


## Where each foot is drawn now, in world space.
func feet() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b in foot_bones:
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(b).origin)
	return out


## Where a carried bag's centre goes this frame, in world space (it rides on the chest bone).
func bag_transform() -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(chest) * bag_at


func crouch() -> void:
	phase = "crouch"


func take_off() -> void:
	phase = "air"


func act() -> void:
	if phase == "":
		phase = "act"
		timer = clips.interact.length


func sit(on: bool) -> void:
	phase = "sit" if on else ""


func reset() -> void:
	phase = ""
	state = &"idle"
	last_phase = -1.0
	playback.start(&"idle")


## The ground speed a gait clip was made for: how fast a planted foot moves back under the body, over the
## stance of each foot. Assumes the clip runs in place facing +Z.
func _ground_speed(model: Node3D, clip: StringName, feet: Array, contact: float) -> float:
	var a := anim.get_animation(clip)
	var n := 60
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
	# a foot is planted while it is within the contact height of its lowest and moving back (a suited boot rolls
	# little, so the ankle stands for the sole; a low swing moves forward); its typical speed over those frames
	var speeds: Array[float] = []
	for f: String in feet:
		var p: Array = track[f]
		var low: float = p.map(func(v: Vector3) -> float: return v.y).min()
		for i in n:
			var j := (i + 1) % n
			if p[i].y < low + contact and p[j].y < low + contact and p[j].z < p[i].z:
				speeds.append((p[i].z - p[j].z) / dt)
	speeds.sort()
	return speeds[speeds.size() / 2]  # the median: a boot still settling as it lands would drag a mean down


## The drawn body as the GPU skins it in the current pose, in the model's own space. A skinned mesh's get_aabb()
## is its bind pose (arms out) in file units, which says nothing about the body the player sees.
func _skinned_points(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
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
				out.append(p)
	return out


func _build_tree(model: Node3D) -> void:
	var sm := AnimationNodeStateMachine.new()
	for c: StringName in [&"idle", &"carry_idle", &"hop_air", &"hop_land", &"interact", &"drive_sit"]:
		sm.add_node(c, _clip(c))
	# hop_start ends at take-off: start it late, so its last part fills the body's short crouch
	var start := _clip(&"hop_start")
	start.use_custom_timeline = true
	start.stretch_time_scale = false
	start.start_offset = maxf(clips.hop_start.takeoff_at - feel.anticipation, 0.0)
	start.timeline_length = minf(feel.anticipation, clips.hop_start.takeoff_at)
	sm.add_node(&"hop_start", start)
	var gait := AnimationNodeBlendSpace1D.new()
	gait.min_space = clip_speed[GAITS[0]]
	gait.max_space = clip_speed[GAITS[-1]]
	gait.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE  # feet stay in step through the blend
	for g: String in GAITS:
		gait.add_blend_point(_clip(g), clip_speed[g], -1, g)
	sm.add_node(&"move", _paced(gait))
	sm.add_node(&"carry_move", _paced(_clip(CARRY)))
	var first := AnimationNodeStateMachineTransition.new()
	first.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO  # or the tree sits in Start
	sm.add_transition(&"Start", &"idle", first)
	var states := [&"idle", &"move", &"carry_idle", &"carry_move", &"hop_start", &"hop_air", &"hop_land", &"interact", &"drive_sit"]
	for a: StringName in states:
		for b: StringName in states:
			if a != b:
				var t := AnimationNodeStateMachineTransition.new()
				# into and through a hop the clips are short and timed to the arc: a long blend would eat them
				t.xfade_time = feel.xfade_hop if String(b).begins_with("hop") or String(a).begins_with("hop") else feel.xfade
				sm.add_transition(a, b, t)
	tree = AnimationTree.new()
	tree.tree_root = sm
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	playback = tree.get(&"parameters/playback")


func _clip(clip: StringName) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = clip
	return a


## A clip or blend followed by a time scale named `pace`, so the cadence can change while the stride stays.
func _paced(node: AnimationRootNode) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node(&"gait", node)
	bt.add_node(&"pace", AnimationNodeTimeScale.new())
	bt.connect_node(&"pace", 0, &"gait")
	bt.connect_node(&"output", 0, &"pace")
	return bt
