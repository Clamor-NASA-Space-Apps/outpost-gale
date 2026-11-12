extends Node3D
## The world: terrain, every item in data/world.json on the ground, the rock scatter, the dust, the machines
## that work on their own, one gusting wind every wind listener reads, and one reflection probe. A prefab whose model is not in models/ yet stands in as a labelled box of its real size,
## so the sandbox runs before the models land. Collision always comes from what is drawn (skills/world-collision).

const Terrain := preload("res://world/terrain.gd")
const Rocks := preload("res://world/rocks.gd")
const Dust := preload("res://world/dust.gd")
const Machines := preload("res://world/machines.gd")
# CONTRACTS.md collision layers, as bits
const GROUND := 1
const STATICS := 2
const THIN := 4
const HERO := 8
const VEHICLES := 16
const CARRIABLES := 64
# metres: still items in one cell share their meshes; the patch centre is a cell's middle. 128 holds the whole base,
# the wing field and Mont Mercou in one cell, a draw call per material (64 split them three ways: 10 more calls)
const CELL := 128.0

## A sound the world makes on its own (a servo starting): the sandbox passes it to audio.play().
signal sound(what: String, pos: Vector3)

var data: Dictionary
var hero: Node3D  # set by the sandbox: machines hold still while the hero stands at them
var machines: Node
var terrain: Node3D
var rocks: Node3D
var dust: Node3D
var items: Dictionary = {}  # id -> Node3D
var hero_width: float  # from the reality sheet: a solid narrower than this is `thin`
var hero_step: float  # and one no higher than this is a `floor` the hero steps onto
var hero_height: float  # for the sweeps in tests/world_test.gd
var weather: Dictionary
var sheet_values: Dictionary = {}  # reality.json row id -> value
var _moving: RegEx
var _blink: RegEx
var _built := false
var _time := 0.0
var _gust := FastNoiseLite.new()
var _pane_mark := Material.new()  # only tells HouseStyle.merge() to number the panes
var _resting: Dictionary = {}  # carriable -> resting on the ground (parent is the world), to redraw contacts on a change
var _drawn: Dictionary = {}  # carriable -> Rect2 (x, z) of the feet drawn into the contact map
var _probe: ReflectionProbe
var _rooms: Array[ReflectionProbe] = []  # one probe per room (data/world.json probe.rooms), made with _probe
const ROOMS := 1 << 3  # render layer 4: indoor swept surfaces, which only the room probes reflect onto
var _cells: Array[Node3D] = []
var _touch: Dictionary = {}  # mover -> PackedVector4Array of its contact discs (touch())
var _touch_dirty := false
var _wheel := SphereShape3D.new()
var _cables: MeshInstance3D
var _static_parts: Array = []  # the moving parts of still items, drawn together (_instance())
var _mirrors: Array[Dictionary] = []  # {mmi, srcs, at}: identical moving meshes drawn as one MultiMesh (_instance())


func build(design: Dictionary) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/reality.json"))
	for r: Dictionary in sheet.rows:
		sheet_values[r.id] = r.value
		if r.id == "hero.width":
			hero_width = r.value
		elif r.id == "hero.step":
			hero_step = r.value
		elif r.id == "hero.height":
			hero_height = r.value
	_moving = RegEx.create_from_string(data.moving)
	_blink = RegEx.create_from_string(data.blink.nodes)
	_pane_mark.set_meta("lit", true)
	_gust.frequency = float(data.wind.gust_hz)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(design)
	for it: Dictionary in data.items:
		items[it.id] = _item(it, design)
	_plant(design, sheet)
	_merge_cells()
	var bags: Array = []
	for n: Node3D in items.values():
		if n.is_in_group("carriable"):
			bags.append_array(n.find_children("merged", "MeshInstance3D", true, false))
	_instance(bags + _static_parts, self)
	_lay_cables(design)
	rocks = Rocks.new()
	rocks.name = "Rocks"
	add_child(rocks)
	rocks.build(self)
	dust = Dust.new()
	dust.name = "Dust"
	add_child(dust)
	dust.build(self)
	machines = Machines.new()
	machines.name = "Machines"
	add_child(machines)
	machines.build(self)
	_contacts()
	# the probe's light on rough ground came out as a bright square around the base (measured): the ground,
	# the rocks and the dust sit on render layer 2, which the probe draws but does not shade. Dust under the
	# probe came out twice as bright as the shaded ground it rose from (measured in a shadow)
	for g: GeometryInstance3D in terrain.find_children("*", "GeometryInstance3D", true, false) + rocks.find_children("*", "GeometryInstance3D", true, false) + dust.find_children("*", "GeometryInstance3D", true, false):
		g.layers = 2
	dust.layers = 2  # and every wheel stream made later
	# the patch is within 2 m of flat over 400 m, so its shadow on itself is a few pixels at most, and each
	# chunk in the shadow range was drawn again per split (the base view was over its 150 draw calls)
	for g: GeometryInstance3D in terrain.find_children("patch_*", "GeometryInstance3D", false, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	restyle(design)
	_built = true


func _process(delta: float) -> void:
	_time += delta
	for m: Dictionary in _mirrors:
		var to_mmi: Transform3D = (m.mmi as Node3D).global_transform.affine_inverse()
		for i in m.srcs.size():
			var t: Transform3D = to_mmi * (m.srcs[i] as Node3D).global_transform
			if t != m.at[i]:
				m.at[i] = t
				(m.mmi as MultiMeshInstance3D).multimesh.set_instance_transform(i, t)
	for n: Node3D in _resting:
		_resting[n] = n.get_parent() == self
		if _resting[n] != _drawn.has(n):
			_contacts(n)  # a bag picked up leaves the dust bare; put down, rest() draws it again
	if _touch_dirty:
		_touch_dirty = false
		var all := PackedVector4Array()
		for d: PackedVector4Array in _touch.values():
			all.append_array(d)
		terrain.movers(all)


## Where something that moves meets the ground, redrawn every time it moves: `discs` are Vector4(x, z, radius,
## strength 0 to 1), darkened like a resting item's feet (data/world.json `grounding`). The contact map is drawn once
## at load, too slow to redraw per frame, so movers go to the ground shader as a short list (terrain.MOVERS).
func touch(who: Object, discs: PackedVector4Array) -> void:
	_touch[who] = discs
	_touch_dirty = true


## A continuous stream of grit and haze from a rolling wheel (world/dust.gd stream()): `id` names the stream, `vel` is
## the tread's world velocity at the ground, `strength` 0 stops it.
func stream(id: String, pos: Vector3, vel: Vector3, strength: float) -> void:
	dust.stream(id, pos, vel, strength)


## The height a wheel of radius `r` centred over (x, z) rests at: the ground, or the top of a rock under it. A rock
## meets the round wheel before the hub is over it, so the wheel rolls up its side rather than stepping onto it.
## Above `reach` over the ground the answer stops at ground + reach + r (a rock that tall is a wall to a wheel).
## Call it from physics (it asks the physics space). The rover subtracts its own sink (data/world.json `sink`).
func wheel_rest(x: float, z: float, r: float, reach: float) -> float:
	var ground := height_at(x, z)
	var best := maxf(ground, rocks.on_pebbles(x, z, r))
	_wheel.radius = r
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _wheel
	q.collision_mask = Rocks.ROCK
	var top := ground + reach + r  # the hub of a wheel standing on a rock `reach` tall
	q.transform = Transform3D(Basis(), Vector3(x, top, z))
	var space := get_world_3d().direct_space_state
	# Jolt answers "never stopped" when the cast starts inside a solid (skills/world-collision): ask first
	if not space.intersect_shape(q, 1).is_empty():
		return ground + reach + r
	q.motion = Vector3(0, ground - top, 0)
	var stop := space.cast_motion(q)
	if stop[0] < 1.0:
		best = maxf(best, top + q.motion.y * stop[0] - r)
	return best


## The wind's slow swell, 0 to 1: one value for every listener (dust streaks, the wind sound, the telltale),
## so eye and ear believe one wind (skills/living-atmosphere section 2). data/world.json `wind`.
func gust() -> float:
	return clampf(0.5 + 0.5 * _gust.get_noise_1d(_time) * 1.6, 0.0, 1.0)


## The wind speed of this moment, m/s: the sky state's speed taken up or down by the gust.
func wind_now() -> float:
	return float(weather.get("wind", 0.0)) * (1.0 + float(data.wind.share) * (2.0 * gust() - 1.0))


## A sky state or a quality switch: every material, lamp, the probe and the dust follow the design in force.
func restyle(design: Dictionary) -> void:
	terrain.restyle(design)
	for n: Node3D in items.values():
		Forge.HouseStyle.apply(n, design, n.get_meta("still"))
		for part: Node3D in n.get_meta("parts"):
			Forge.HouseStyle.apply(part, design, false)  # it moves, so its detail must travel with it
	for cell: Node3D in _cells:
		Forge.HouseStyle.apply(cell, design, true)
	if _cables:
		Forge.HouseStyle.apply(_cables, design, true)
	for m: Dictionary in _mirrors:
		var mesh: Mesh = (m.mmi as MultiMeshInstance3D).multimesh.mesh
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, (m.srcs[0] as MeshInstance3D).get_active_material(i))
	rocks.restyle(design)
	weather = data.weather.get(design.get("name", ""), data.weather["Outpost Gale"])
	dust.restyle(design, weather)
	machines.restyle(design, weather)
	_lamps(design)
	# One probe for the life of the world: freeing one leaked its two atlas textures in Compatibility (measured,
	# "Texture ... leaked" at exit). The ambient set below does not redraw it (Compatibility ignores it for that):
	# the sandbox's warm-up after every sky or quality switch does (HouseStyle.warm(), _redraw_probes()).
	if _probe == null:
		_probe = ReflectionProbe.new()
		_probe.name = "Probe"
		var p: Array = data.probe.pos
		var s: Array = data.probe.size
		_probe.size = Vector3(s[0], s[1], s[2])
		_probe.position = Vector3(p[0], height_at(p[0], p[1]) + 2.0, p[1])
		_probe.reflection_mask = 1  # machines only: ground and rocks on layer 2 keep the sky's light
		# a probe also replaces the ambient light inside its box with what it captured, and faces turned from
		# the sun went pure black there; the rig's own shade colour keeps them as DESIGN.md says
		_probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
		add_child(_probe)
		# A room's own probe (data/world.json probe.rooms): with only the base's, glass and metal inside HAB 1 showed
		# the rover and the sky (12 Nov playtest). Compatibility averages every probe whose box holds a pixel, so the
		# swept meshes (the rooms' fit-out and floors, world.gd _merge) go on a layer only the room probes reflect onto
		for id: String in data.probe.get("rooms", {}):
			if not items.has(id):
				continue
			var r: Dictionary = data.probe.rooms[id]
			var room := ReflectionProbe.new()
			room.name = "Probe_" + id
			room.size = Vector3(r.size[0], r.size[1], r.size[2])
			room.position = Vector3(r.at[0], r.at[1], r.at[2])
			room.box_projection = true  # a closed room: reflections land on its walls, not at infinity
			room.interior = true
			room.reflection_mask = ROOMS
			room.ambient_mode = ReflectionProbe.AMBIENT_COLOR
			items[id].add_child(room)
			_rooms.append(room)
		for cell: Node3D in _cells:
			for mi: MeshInstance3D in cell.find_children("merged_swept", "MeshInstance3D", false, false):
				mi.layers = ROOMS
	for p: ReflectionProbe in [_probe] + _rooms:
		p.ambient_color = Color.html(design.lighting.get("ambientColor", design.lighting.sky))
		p.ambient_color_energy = float(design.lighting.get("ambient", 1)) / PI  # the rig's units (house_style UNIT)


func height_at(x: float, z: float) -> float:
	return terrain.height_at(x, z)


## Where anything that moves may go, x and z (data/world.json `bound`), `margin` metres further in: inside it the
## drawn ground, its collision and height_at() are one surface (the patch); past it there is only the backdrop.
func bound(margin := 0.0) -> Rect2:
	var h := float(data.bound.half) - margin
	return Rect2(-h, -h, 2.0 * h, 2.0 * h)


## How far `p` is past bound(margin), metres (0 inside).
func past(p: Vector3, margin := 0.0) -> float:
	var r := bound(margin)
	var q := Vector2(p.x, p.z)
	return q.distance_to(q.clamp(r.position, r.end))


## {pos: Vector3 on the ground, yaw: degrees}
func landmark(name: String) -> Dictionary:
	var l: Array = data.landmarks.get(name, data.landmarks.spawn)
	return {"pos": Vector3(l[0], height_at(l[0], l[1]), l[1]), "yaw": float(l[2])}


## A footprint ("foot_l", "foot_r") or a wheel print ("wheel", `width` in metres) pressed into the dust: terrain.gd
## draws it, `strength` 0 to 1 its depth.
func mark(pos: Vector3, yaw_deg: float, kind: String, width := 0.3, strength := 1.0) -> void:
	terrain.mark(pos, yaw_deg, kind, width, strength)


## Dust thrown by a boot or a wheel at contact: `vel` the foot's (or wheel rim's) world velocity, `strength`
## 0 to 1, `kind` "foot" or "wheel" (world/dust.gd).
func puff(pos: Vector3, vel: Vector3, strength: float, kind := "foot") -> void:
	dust.puff(pos, vel, strength, kind)


## Sets an item down in the dust (at load, and wherever the sandbox puts one down). Its feet are the drawn points
## within `sink.support` of its underside (data/world.json `sink`); an item crews do not level first turns to the
## ground's plane under them, then every foot goes into the ground right under it by the prefab's sink row
## (reality.json ground.sink.*), so no foot, skid or bevelled edge hangs over a dip. Its collision moves with it.
## Vehicles only touch: their drivers set them on their wheels.
func rest(root: Node3D) -> void:
	var prefab: String = root.get_meta("prefab")
	var s: Dictionary = data.sink
	var kind: String = data.kinds.get(prefab, "static")
	var depth := 0.0 if kind == "vehicle" else float(sheet_values[s.get(prefab, s.default)])
	var points := PackedVector3Array()
	var low := INF
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var to := mi.global_transform
			for v in mi.mesh.get_faces():
				var p := to * v
				points.append(p)
				low = minf(low, p.y)
	# a model bedded in the ground (an outcrop's skirt) marks its ground line with a `ground_level` node: it rests
	# there, and what is drawn below it stays in the dust
	var mark := root.find_child("ground_level", true, false) as Node3D
	if mark:
		low = mark.global_position.y
	# each foot dropped onto the underside's plane: a bevelled edge 4 cm up counts where it would meet the
	# ground, or it pushed the flat bottom 4 cm deeper than the sink row
	var feet := PackedVector3Array()
	for p in points:
		if p.y < low + float(s.support):
			feet.append(Vector3(p.x, low, p.z))
	if feet.is_empty():
		return
	if kind != "vehicle" and prefab not in s.level:
		feet = _tilt(root, feet)
	var lift := INF  # how far up the root may go before a foot leaves the ground
	var flat := PackedVector2Array()
	for p in feet:
		lift = minf(lift, height_at(p.x, p.z) - p.y)
		flat.append(Vector2(p.x, p.z))
	root.global_position.y += lift - depth
	if kind == "vehicle":
		return
	root.set_meta("feet", flat)  # where the ground darkens round it (_contacts)
	if kind == "carriable":
		_resting[root] = root.get_parent() == self
	if _built:
		# set down after the world was built (a bag put down): grit and haze at the contact, the shadow redrawn
		var g: Dictionary = data.grounding
		var at := root.global_position
		puff(Vector3(at.x, height_at(at.x, at.z), at.z), Vector3.DOWN * float(g.set_down_speed), float(g.set_down_strength))
		_contacts(root)


## Every resting item's feet and the solid rocks' into the ground's contact map (terrain.gd). With `moved` (a carriable
## picked up or put down) only the ground where its feet were and are now is drawn again.
func _contacts(moved: Node3D = null) -> void:
	var feet := PackedVector2Array()
	var now: Dictionary = {}  # carriable -> the box (x, z) round its feet
	for n: Node3D in items.values():
		if n.has_meta("feet") and n.get_parent() == self:
			var f: PackedVector2Array = n.get_meta("feet")
			feet.append_array(f)
			if _resting.has(n):
				var b := Rect2(f[0], Vector2.ZERO)
				for p in f:
					b = b.expand(p)
				now[n] = b
	if rocks:
		feet.append_array(rocks.feet)
	var spots: Array = [_drawn.get(moved), now.get(moved)].filter(func(r: Variant) -> bool: return r != null)
	var area := Rect2()
	if moved and spots.size():
		area = spots[0].merge(spots[-1]).grow(0.01)
	_drawn = now
	terrain.contacts(feet, data.grounding, float(data.play_half), area)


## Turns `root` about its origin so its feet (world space) lie along the ground's plane under them (a least-squares
## fit), and returns them turned: on a slope a rigid lander buried its uphill pads and lifted its downhill ones.
## A pole or a single foot has no plane and stays upright.
func _tilt(root: Node3D, feet: PackedVector3Array) -> PackedVector3Array:
	var mid := Vector3.ZERO
	var ground: Array[Vector3] = []
	for p in feet:
		var g := Vector3(p.x, height_at(p.x, p.z), p.z)
		ground.append(g)
		mid += g
	mid /= ground.size()
	var xx := 0.0
	var xz := 0.0
	var zz := 0.0
	var xg := 0.0
	var zg := 0.0
	for g in ground:
		var d := g - mid
		xx += d.x * d.x
		xz += d.x * d.z
		zz += d.z * d.z
		xg += d.x * d.y
		zg += d.z * d.y
	var det := xx * zz - xz * xz
	if det < 1e-6:
		return feet
	# ground height = mid.y + a * dx + b * dz
	var a := (xg * zz - zg * xz) / det
	var b := (zg * xx - xg * xz) / det
	var turn := Basis(Quaternion(Vector3.UP, Vector3(-a, 1.0, -b).normalized()))
	var o := root.global_position
	root.global_basis = turn * root.global_basis
	for i in feet.size():
		feet[i] = o + turn * (feet[i] - o)
	return feet


## The box everything drawn under `root` fills, in world space.
static func drawn(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _item(it: Dictionary, design: Dictionary) -> Node3D:
	var kind: String = data.kinds.get(it.prefab, "static")
	var model := _model(it.prefab, design)
	var root: Node3D = model
	if kind != "static":
		# a mover is one body around its model: the lane that moves it finds the body at the item's node
		var body := AnimatableBody3D.new()
		# with sync_to_physics the body is pulled back to where physics first saw it, the origin: every mover
		# sat at (0, 0, 0). The rover and the bags are moved by setting their transform.
		body.sync_to_physics = false
		body.collision_layer = VEHICLES if kind == "vehicle" else CARRIABLES
		body.collision_mask = GROUND | STATICS | THIN | HERO if kind == "vehicle" else 0
		body.add_to_group(kind)
		body.add_child(model)
		root = body
	root.name = it.id
	add_child(root)
	root.position = Vector3(it.pos[0], 0, it.pos[1])
	root.rotation.y = -deg_to_rad(float(it.get("yaw", 0)))
	var parts := _parts(model)
	var moving: Array = []
	for p: Node3D in parts:
		moving.append_array(([p] if p is MeshInstance3D else []) + p.find_children("*", "MeshInstance3D", true, false))
	if kind == "static":
		_static_parts.append_array(moving)  # every array's panels together, after all items (build())
	else:
		_instance(moving, model)  # a mover's own wheels ride with it
	if kind == "static":
		_solidify(model, parts)
	else:
		# the import's own bodies (-convcol) sat on layer 1 inside the mover and stayed behind when it moved:
		# the one hull below replaces them
		for b: CollisionObject3D in model.find_children("*", "CollisionObject3D", true, false):
			b.free()
		_hull(root, model)
	root.set_meta("parts", parts)
	var still := _still(root)
	if still.size() > 1:
		_merge(still, model)
		for mi: MeshInstance3D in still:
			mi.mesh = null
	root.set_meta("prefab", it.prefab)
	rest(root)
	var box := drawn(root)
	# a vehicle's wheels cast too: without them its shadow was a body floating on nothing (13 Nov playtest)
	if box.size.y < float(data.shadow_min):
		# each shadow split draws a caster again, and a knee-high bag's shadow is a few pixels
		for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("still", kind == "static")
	root.set_meta("lamp", _lamp_at(root) if it.prefab in data.lamps else null)
	return root


func _model(id: String, design: Dictionary) -> Node3D:
	var file: String = data.prefabs.get(id, "")
	if ResourceLoader.exists(file):
		var m: Node3D = load(file).instantiate()
		Forge.HouseStyle.apply(m, design, true)
		return m
	var size: Array = data.standin.get(id, [1, 1, 1])
	var s := Vector3(size[0], size[1], size[2])
	var root := Node3D.new()
	var box := BoxMesh.new()
	box.size = s
	box.material = Forge.HouseStyle.role(design, "trim")  # a named role, so restyle() finds it again
	var mi := MeshInstance3D.new()
	mi.name = "standin"
	mi.mesh = box
	mi.position.y = s.y / 2.0
	root.add_child(mi)
	var label := Label3D.new()
	label.text = id + " (stand-in)"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = s.y + 0.4
	label.font_size = 48
	root.add_child(label)
	return root


## The parts that move (data/world.json `moving`: door, dish, panel_N, wheel_N): the topmost node so named, below the model.
func _parts(model: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var todo: Array[Node] = model.get_children()
	while todo.size():
		var n: Node = todo.pop_back()
		if n is Node3D and _moving.search(n.name):
			out.append(n)
		else:
			todo.append_array(n.get_children())
	return out


func _in_part(n: Node, parts: Array[Node3D]) -> bool:
	return parts.any(func(p: Node3D) -> bool: return p == n or p.is_ancestor_of(n))


## Identical meshes that move (a rover's wheels, an array's panels, the cargo bags) drawn as one MultiMesh under
## `holder`: a draw call per material for all of them, not one each (the base view was 233 calls against its 150).
## Each keeps its node, its collision and its motion; its own mesh is hidden, and _process() copies where it is to
## its instance.
func _instance(meshes: Array, holder: Node3D) -> void:
	var same: Dictionary = {}  # geometry and materials -> the meshes that have them
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null or mi.skin != null:
			continue
		var key := []
		for i in mi.mesh.get_surface_count():
			key.append_array([mi.get_active_material(i), mi.mesh.surface_get_arrays(i)])
		same.get_or_add(hash(key), []).append(mi)
	for srcs: Array in same.values():
		if srcs.size() < 2:
			continue
		var first: MeshInstance3D = srcs[0]
		var mesh := first.mesh.duplicate() as Mesh  # its own copy: the restyle sets the drawn materials on it
		for i in mesh.get_surface_count():
			mesh.surface_set_material(i, first.get_active_material(i))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = srcs.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "all_" + first.name  # not "wheel_*": the rover and PIP find their wheels by name
		mmi.multimesh = mm
		mmi.cast_shadow = first.cast_shadow
		mmi.layers = first.layers
		holder.add_child(mmi)
		var at: Array[Transform3D] = []
		for i in srcs.size():
			at.append(mmi.global_transform.affine_inverse() * (srcs[i] as Node3D).global_transform)
			mm.set_instance_transform(i, at[i])
			(srcs[i] as MeshInstance3D).visible = false
		_mirrors.append({"mmi": mmi, "srcs": srcs, "at": at})


## Collision for a static item, from its own triangles. A model that arrives with bodies (-col names) chose
## which parts block, so its other still parts (handles, labels) stay walk-past detail; a model with none gets
## a triangle body on every still mesh. A moving part with no body gets a convex hull on an AnimatableBody3D,
## so it can open, tilt or turn and still block.
func _solidify(model: Node3D, parts: Array[Node3D]) -> void:
	var authored := model.find_children("*", "CollisionObject3D", true, false).size() > 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.skin or mi.get_children().any(func(c: Node) -> bool: return c is CollisionObject3D):
			continue
		var moving := _in_part(mi, parts)
		if authored and not moving:
			continue
		if moving:
			var body := AnimatableBody3D.new()
			body.sync_to_physics = false  # it rides a moving parent (world-collision rule: or its shape stays behind)
			var col := CollisionShape3D.new()
			col.shape = mi.mesh.create_convex_shape(true, false)
			body.add_child(col)
			mi.add_child(body)
		else:
			mi.create_trimesh_collision()
	for body: CollisionObject3D in model.find_children("*", "CollisionObject3D", true, false):
		_layer(body)
	if authored and model.find_children("*", "CollisionObject3D", true, false).all(func(b: CollisionObject3D) -> bool: return b.collision_layer == THIN):
		_feet(model)


## A pole on feet (a lamp's tripod): its authored body is the pole, and the hero stood inside the drawn feet
## from 6 of 8 headings (tests/sweep_test.gd). One convex hull of what is drawn below the hero's head covers
## them; it slopes in toward the pole, so the hero slides round it, and it stays thin (layer 3) for the camera.
func _feet(model: Node3D) -> void:
	var to_model := model.global_transform.affine_inverse()
	var base := drawn(model).position.y
	var points := PackedVector3Array()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			for v in mi.mesh.get_faces():
				var at := mi.global_transform * v
				if at.y - base < hero_height:
					points.append(to_model * at)
	if points.size() < 4:
		return
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var col := CollisionShape3D.new()
	col.shape = shape
	var body := StaticBody3D.new()
	body.name = "feet"
	body.collision_layer = THIN
	body.collision_mask = 0
	body.add_to_group("thin")
	body.add_child(col)
	model.add_child(body)


## Statics on layer 2, anything narrower than the hero on layer 3 (the camera ignores it), groups for the rules.
func _layer(body: CollisionObject3D) -> void:
	var box := AABB()
	var first := true
	for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
		var b := cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		box = b if first else box.merge(b)
		first = false
	var thin := maxf(box.size.x, box.size.z) < hero_width
	body.collision_layer = THIN if thin else STATICS
	body.collision_mask = 0
	body.add_to_group("thin" if thin else "wall")
	if box.size.y <= hero_step:
		body.add_to_group("floor")


## One convex hull around a mover's drawn points. The rover is entered by a door script, not walked into.
func _hull(body: Node3D, model: Node3D) -> void:
	var points := PackedVector3Array()
	var to_body := body.global_transform.affine_inverse()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			var at := to_body * mi.global_transform
			for v in mi.mesh.get_faces():
				points.append(at * v)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points  # the engine reduces it to the hull
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)


## Meshes into one mesh with one surface per material, placed in `parent`: a draw call per material, not per part.
func _merge(meshes: Array, parent: Node3D) -> MeshInstance3D:
	var tools: Dictionary = {}  # Material -> SurfaceTool
	var to_parent := parent.global_transform.affine_inverse()
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if not tools.has(m):
				tools[m] = SurfaceTool.new()
			# panes of a role some sky state lights (`lit_roles`) are numbered now, whatever the sky at load
			Forge.HouseStyle.merge(tools[m], mi.mesh, s, to_parent * mi.global_transform, _pane_mark if m and m.resource_name in data.lit_roles else m)
	# surfaces kept swept (DESIGN.md weathering.clean: floors, HAB 1's fit-out) are indoors or underfoot, so they go
	# in a second mesh that casts no shadow: each shadowed surface is drawn again per shadow split (skills/frame-budget)
	var out: MeshInstance3D
	for swept in [false, true]:
		var mesh := ArrayMesh.new()
		for m: Material in tools:
			if (m != null and m.get_meta("clean", false)) == swept:
				tools[m].commit(mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "merged_swept" if swept else "merged"
		mi.mesh = mesh
		if swept:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = float(data.swept_range_m)  # rooms and floors are hidden from afar anyway
		parent.add_child(mi)
		out = mi if out == null else out
	return out


## An item's meshes that never move: not a moving part, not skinned.
func _still(n: Node3D) -> Array:
	var parts: Array[Node3D] = n.get_meta("parts")
	return n.find_children("*", "MeshInstance3D", true, false).filter(func(mi: MeshInstance3D) -> bool:
		# a flashing light keeps its own mesh, so its material can change without the rest of the cell
		return mi.mesh != null and mi.skin == null and not _in_part(mi, parts) and not _blink.search(mi.name))


## The still meshes of every static item in one ground cell, merged per material (world-collision rule 9):
## the base went from 400 draw calls to a handful per material. Each item keeps its own meshes hidden,
## for its collision, its tags, its lamp and the checks.
func _merge_cells() -> void:
	var cells: Dictionary = {}  # Vector2i -> meshes
	for n: Node3D in items.values():
		if n.get_meta("still"):
			cells.get_or_add(Vector2i(floori(n.position.x / CELL + 0.5), floori(n.position.z / CELL + 0.5)), []).append_array(_still(n))
	for key: Vector2i in cells:
		var holder := Node3D.new()
		holder.name = "cell_%d_%d" % [key.x, key.y]
		add_child(holder)
		_merge(cells[key], holder)
		for mi: MeshInstance3D in cells[key]:
			mi.visible = false
		_cells.append(holder)


## Where a lamp's light sits: the middle of its `light` role parts, else the top of the model.
func _lamp_at(root: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m and m.resource_name == "light":
				var b := mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
	if first:
		var all := drawn(root)
		return root.to_local(Vector3(all.get_center().x, all.end.y - 0.15, all.get_center().z))
	return root.to_local(box.get_center())


## Lamps light only when the design has `lighting.lamp` (the night). The old ones go first, every time.
func _lamps(design: Dictionary) -> void:
	for old: Node in get_tree().get_nodes_in_group("world_lamp"):
		old.free()
	for n: Node3D in items.values():
		var at: Variant = n.get_meta("lamp") if n.has_meta("lamp") else null  # set_meta(null) stores nothing
		var lamp := Forge.HouseStyle.make_lamp(design) if at != null else null
		if lamp:
			lamp.position = at
			lamp.add_to_group("world_lamp")
			n.add_child(lamp)


## Power cables on the ground (data/world.json `cables`): a box-section strip draped on height_at() every `step` m,
## all lines one mesh in the role's material. No body: the hero steps over a cable a few centimetres high.
func _lay_cables(design: Dictionary) -> void:
	var c: Dictionary = data.get("cables", {})
	if c.get("lines", []).is_empty():
		return
	var w := float(c.width) / 2.0
	var h := float(c.height)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for line: Array in c.lines:
		var pts: Array[Vector3] = []
		for i in line.size() - 1:
			var a := Vector2(line[i][0], line[i][1])
			var b := Vector2(line[i + 1][0], line[i + 1][1])
			var n := maxi(1, ceili(a.distance_to(b) / float(c.step)))
			for k in n + int(i == line.size() - 2):
				var p := a.lerp(b, float(k) / n)
				pts.append(Vector3(p.x, height_at(p.x, p.y) - h * 0.3, p.y))  # bedded a little into the dust
		for i in pts.size() - 1:
			var side := (pts[i + 1] - pts[i]).cross(Vector3.UP).normalized() * w
			var up := Vector3.UP * h
			# left wall, top, right wall: three quads per step
			for q: Array in [[-side, -side + up], [-side + up, side + up], [side + up, side]]:
				var a0: Vector3 = pts[i] + q[0]
				var a1: Vector3 = pts[i] + q[1]
				var b0: Vector3 = pts[i + 1] + q[0]
				var b1: Vector3 = pts[i + 1] + q[1]
				for v: Vector3 in [a0, b0, b1, a0, b1, a1]:
					st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, Forge.HouseStyle.role(design, c.role, true))
	_cables = MeshInstance3D.new()
	_cables.name = "Cables"
	_cables.mesh = mesh
	_cables.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # a few pixels wide: not worth a shadow pass
	add_child(_cables)


## Lettuce in the greenhouse's grow-bed slots (data/world.json `plants`), sized so a full head is the sheet's
## lettuce.width, and any other prefab named there in its item's slot. They join the item, so the merge draws them with it.
func _plant(design: Dictionary, sheet: Dictionary) -> void:
	var width := 0.3
	for r: Dictionary in sheet.rows:
		if r.id == "lettuce.width":
			width = r.value
	for id: String in data.get("plants", {}):
		if id.begins_with("_") or not items.has(id):
			continue
		var stages: Array = data.plants[id]
		var slots: Array[Node] = (items[id] as Node3D).find_children("slot_*", "Node3D", true, false)
		slots.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)
		var scale_by := 0.0
		for i in mini(slots.size(), stages.size()):
			# a prefab id is a model built at its real size (HAB 1's Veggie unit); a number is a lettuce stage
			var plant := _model(stages[i] if stages[i] is String else "lettuce_%d" % int(stages[i]), design)
			slots[i].add_child(plant)
			if stages[i] is String:
				# styled again from the slot's parent, so a slot in a room kept swept (HAB 1's `interior`) keeps it swept
				Forge.HouseStyle.apply(slots[i].get_parent(), design, true)
				continue
			if scale_by == 0.0:
				# measured in place, so a scale the slot carries from its model counts too
				var full := drawn(_model_in(slots[i], "lettuce_4", design)).size
				scale_by = width / maxf(full.x, full.z)
			plant.scale = Vector3.ONE * scale_by


## A throwaway copy of a prefab under `parent`, measured and freed by the caller's next line.
func _model_in(parent: Node3D, id: String, design: Dictionary) -> Node3D:
	var m := _model(id, design)
	parent.add_child(m)
	m.queue_free()
	return m
