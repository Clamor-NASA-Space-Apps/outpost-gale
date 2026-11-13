extends Node
## The base working on its own (skills/living-atmosphere section 2, design/research/alive.md touch-ups 9 and 10):
## solar panels turn to face the sun and lie flat at night and in a storm, the dish nods, the telltale leans
## downwind with the gust, status lights flash. Motion and light only: nothing here changes game state.
## Numbers: data/world.json `machines`, `telltale`, `blink`.

var panels: Array[Dictionary] = []  # {node, at (the angle written last), aim, wait, moving, gcr, lim}
var dishes: Array[Dictionary] = []  # {node, rest, at, aim, next, moving}
var tells: Array[Dictionary] = []  # {node, rest: Basis, tilt}
var lights: Array[MeshInstance3D] = []  # meshes with a `light` surface that flashes
var flash_on := true
var _world: Node3D
var _m: Dictionary  # data/world.json `machines`
var _sun := Vector3.ZERO  # toward the sun; zero when the trackers stow
var _blink_mat: StandardMaterial3D
var _lit: Color
var _glow := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _aimed := false


func build(world: Node3D) -> void:
	_world = world
	_m = world.data.machines
	_rng.seed = 7
	var blink := RegEx.create_from_string(world.data.blink.nodes)
	for n: Node3D in world.items.values():
		for part: Node3D in n.get_meta("parts"):
			if str(part.name).begins_with("panel_"):
				# per prefab: its rows' ground coverage ratio and its turning limit (data/world.json machines.tracker.rows)
				var r: Dictionary = _m.tracker.rows.get(n.get_meta("prefab"), {})
				panels.append({"node": part, "at": part.rotation.x, "aim": part.rotation.x, "wait": 0.0, "moving": false,
					"gcr": float(r.get("gcr", 0.0)), "lim": deg_to_rad(float(r.get("limit_deg", _m.tracker.limit_deg)))})
			elif part.name == &"dish":
				dishes.append({"node": part, "rest": part.rotation.x, "at": part.rotation.x, "aim": part.rotation.x,
					"next": _rng.randf() * float(_m.dish.period_s), "moving": false})
			elif part.name == &"tell":
				tells.append({"node": part, "rest": part.basis, "tilt": 0.0})
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh and blink.search(mi.name):
				lights.append(mi)


## The sun of the design in force, the weather row (`stow`), and the flashing lights' own copy of the light role.
func restyle(design: Dictionary, weather: Dictionary) -> void:
	var L: Dictionary = design.lighting
	var el := deg_to_rad(float(L.get("elevation", 45)))
	var az := deg_to_rad(float(L.get("azimuth", 0)))
	# where the rig puts its sun (house_style.gd apply_lighting: azimuth turns from +Z, as the forge previews do)
	_sun = Vector3.ZERO if weather.get("stow", false) else Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	_blink_mat = null
	for mi in lights:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m and m.resource_name == "light" and m is StandardMaterial3D:
				if _blink_mat == null:
					# one copy for every flashing light, so they flash together like the lights on one tower
					_blink_mat = m.duplicate()
					# its own name: it is no role's shared material (house_style's kit maps "light" back on restyle)
					_blink_mat.resource_name = "light_flash"
					_lit = _blink_mat.albedo_color
					_glow = float(m.get_meta("glow", _blink_mat.emission_energy_multiplier))  # full, not the sky clock's daytime glimmer
				mi.set_surface_override_material(i, _blink_mat)
	_flash(true, true)


## Toward the sun the trackers turn to (x east, y up, z south), zero to lie flat: the sky clock's real sun.
func aim(sun: Vector3) -> void:
	_sun = sun


func _process(delta: float) -> void:
	_time += delta
	_track(delta)
	_nod(delta)
	_lean()
	var b: Dictionary = _world.data.blink
	_flash(fmod(_time * float(b.hz), 1.0) < float(b.duty))


## Each panel turns about its tube (its X axis) toward the sun, inside the tracker's limits, in steps. It holds
## still while the hero is near, and for a while after anything else moved it (the tilt interaction). Rows backtrack:
## when the sun is so low that a row's shadow would reach the next row, they turn back toward flat until it just
## does not (Anderson and Mikofski 2020, NREL/TP-5K00-76626, eq. 14; pvlib tracking.singleaxis), so no row ever
## shades another (design/research/pages/tracker/).
func _track(delta: float) -> void:
	var t: Dictionary = _m.tracker
	var step := deg_to_rad(float(t.step_deg))
	for p in panels:
		var node: Node3D = p.node
		if absf(node.rotation.x - p.at) > 1e-4 and _aimed or _hero_near(node):
			p.wait = float(t.pause_s)
			p.at = node.rotation.x
			p.moving = false
			continue
		if p.wait > 0.0:
			p.wait -= delta
			continue
		var want := 0.0
		if _sun != Vector3.ZERO:
			# the panel's face is its +Y; turned by x about X it points along (0, cos x, sin x)
			var d: Vector3 = node.get_parent().global_basis.inverse() * _sun
			want = atan2(d.z, d.y)  # true tracking: the sun across the tube
			var gcr: float = p.gcr
			var c: float = absf(cos(want)) / gcr if gcr > 0.0 else 1.0  # row pitch over the shadow's reach
			if c < 1.0:
				want -= signf(want) * acos(c)
			want = clampf(want, -p.lim, p.lim)
		# a tracker re-aims in steps, not continuously: when the sun is a step off its aim
		if absf(want - p.aim) >= step:
			p.aim = want
		if not _aimed:
			p.at = p.aim  # the base ran before anyone arrived: the panels start facing the sun
		_slew(p, node, float(t.slew_deg_s), delta)
	_aimed = true


## The dish nods either side of its rest every period, as a dish re-points.
func _nod(delta: float) -> void:
	var d: Dictionary = _m.dish
	for p in dishes:
		if _hero_near(p.node):
			continue  # it holds still while someone stands at it
		p.next -= delta
		if p.next <= 0.0:
			p.next = float(d.period_s)
			var nod := deg_to_rad(float(d.nod_deg))
			p.aim = p.rest + (nod if p.aim <= p.rest else -nod)
		_slew(p, p.node, float(d.slew_deg_s), delta)


func _slew(p: Dictionary, node: Node3D, deg_s: float, delta: float) -> void:
	var was: bool = p.moving
	p.moving = absf(p.aim - p.at) > 1e-4
	if p.moving and not was and _world.hero and _world.hero.global_position.distance_to(node.global_position) < float(_m.hear_m):
		_world.sound.emit(str(_m.servo), node.global_position)
	p.at = move_toward(p.at, p.aim, deg_to_rad(deg_s) * delta)
	node.rotation.x = p.at


## The telltale leans downwind by the Phoenix curve at the wind of the moment, and trembles a little.
func _lean() -> void:
	var tt: Dictionary = _world.data.telltale
	var v: float = _world.wind_now()
	var curve: Array = tt.tilt
	var tilt := 0.0
	for i in range(1, curve.size()):
		if v <= curve[i][0] or i == curve.size() - 1:
			tilt = remap(v, curve[i - 1][0], curve[i][0], curve[i - 1][1], curve[i][1])
			break
	tilt *= 1.0 + float(tt.flutter) * sin(_time * TAU * float(tt.flutter_hz)) * sin(_time * 2.3 + 1.0)
	var dir: Vector3 = _world.dust.wind.normalized()
	for t in tells:
		var node: Node3D = t.node
		var w: Vector3 = node.get_parent().global_basis.inverse() * dir
		w.y = 0.0
		t.tilt = tilt
		if w.length() < 0.01:
			continue
		# turning the hanging tube about down x wind swings its lower end downwind
		node.basis = Basis(Vector3.DOWN.cross(w.normalized()).normalized(), tilt) * t.rest


func _flash(on: bool, force := false) -> void:
	if _blink_mat == null or on == flash_on and not force:
		return
	flash_on = on
	var k := 1.0 if on else float(_world.data.blink.off)
	_blink_mat.albedo_color = _lit * Color(k, k, k)
	_blink_mat.emission_energy_multiplier = _glow * k


func _hero_near(node: Node3D) -> bool:
	var h: Node3D = _world.hero
	return h != null and h.global_position.distance_to(node.global_position) < float(_m.near_m)


func state() -> Dictionary:
	return {"panels": panels.map(func(p: Dictionary) -> float: return snappedf(rad_to_deg(p.at), 0.1)),
		"dish": dishes.map(func(p: Dictionary) -> float: return snappedf(rad_to_deg(p.at), 0.1)),
		"tell": tells.map(func(t: Dictionary) -> float: return snappedf(rad_to_deg(t.tilt), 0.01)),
		"flash": flash_on}
