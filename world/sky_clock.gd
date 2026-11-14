extends Node
## The world's own clock (skills/day-cycle, design/research/day-cycle.md): one local solar hour at Gale that the whole
## look follows. The sun runs Gale's real path; the sky, ambient, fog and the light blend the approved designs
## (DESIGN.md day, DESIGN.sunset.md, DESIGN.night.md, DESIGN.storm.md) by the sun's elevation; lamps fade on at dusk;
## the stars, Phobos and Deimos turn with the same clock; dust settles in a storm and stays.
## It drives the look only: nothing here counts sols, and nothing a player can win or lose reads it (hard rule 1 until
## 14 Nov). The rules take it over with `driven` and set_hour() (CONTRACTS.md, The sky clock).
## Knobs: data/tuning.json `sky`. Cost: the light moves in short bursts and the probes redraw in steps, never per frame.

## The design that now leads the blend changed (sandbox SKIES names: "design", "design.sunset", "design.night",
## "design.storm"). The sandbox passes it to the audio; the rules may listen on 14 Nov.
signal phase_changed(state: String)

const HouseStyle := preload("res://addons/forge/house_style.gd")
const KEYS := ["design", "design.sunset", "design.night", "design.storm"]
const PHASES := ["dawn", "noon", "dusk", "night", "storm"]

var hours := 0.0  # local solar hours since midnight of the first sol; hour() is this within the sol
var driven := false  # the rules own the hour (set_hour() every frame); the clock stops advancing it
var paused := false  # a menu or a cover is up: time waits for the player (skills/day-cycle section 1)
var pinned := false  # tools and captures: an hour that stays put, for repeatable pictures
var storm_on := false
var storm := 0.0  # the storm key's share, 0 to 1, building and clearing on the clock
var coat := 0.0  # the weathering coat now (DESIGN.md weathering.amount when clear)
var state := ""  # the design leading the blend
var weights: Array[float] = [1.0, 0.0, 0.0, 0.0]
var sun := Vector3.UP  # toward the sun, x east, y up, z south
# what the checks count (tests/day_test.gd): light writes, bursts begun, probe redraws, look updates, and the clock's
# own time per frame (microseconds)
var light_writes := 0
var bursts := 0
var probe_redraws := 0
var looks := 0
var cost_us := 0
var cost_max_us := 0

var _game: Node3D
var _world: Node3D
var _design: Dictionary
var _cfg: Dictionary
var _C: Dictionary  # DESIGN.night.md lighting.celestial: the sky the sun is placed in
var _look: Array[Dictionary] = []  # per key, HouseStyle.look()
var _el: Array[float] = []  # per key, the sun's elevation it was approved at (day, sunset, night)
var _weather: Array[Dictionary] = []  # per key, data/world.json weather row
var _dust_design: Array[Dictionary] = []  # per key, its lighting: the dust's colours follow the key's horizon
var _rate := 0.0  # hours a real second at day speed
var _phase_h := {}  # PHASES -> hour of the sol
var _phase := 0
var _skip_to := -1.0
var _skip_rate := 0.0
var _since_look := 0.0
var _v: Dictionary  # the look of the last update, without the light
var _light_to: Dictionary  # where the true sun would put the light now: {dir, color, energy}
var _light_from: Dictionary  # a burst's two ends, with `shadowed` (HouseStyle._shadowed(), solved once a burst)
var _burst_to: Dictionary
var _light_now: Dictionary
var _burst_t := 1.0
var _lit_at := -1.0  # the hour the light was last turned to (continuous light)
var _burst_sun := Vector3.ZERO
var _probe_w: Array[float] = []
var _lamps: Dictionary = {}  # OmniLight3D -> {on, level, full, at (its own switch offset, degrees)}
var _glow := {"on": false, "level": -1.0}  # the work lights' glowing faces (the `light` role), on the lamps' schedule
var _panels: Array[Dictionary] = []  # {node, copies: [[MultiMeshInstance3D, index]], keep (0 shed .. 1), shown}
var _coat_shown := -1.0
var _base_coat: float
var _storm_coat: float
var _base_side: float
var _storm_side: float
var _last_hours := 0.0  # where the last look update was: the storm and the coat move by the hours since
var _probe_list: Array[Node] = []
var _stars: Node  # the rig's HouseStyle.SkyClock: the night sky's seconds


## `design` is the one the materials and the rig were built from; `keys` the four DESIGN token files by KEYS name.
func setup(game: Node3D, world: Node3D, design: Dictionary, keys: Dictionary, cfg: Dictionary) -> void:
	_game = game
	_world = world
	_look.clear()
	_weather.clear()
	_dust_design.clear()
	_design = design
	_cfg = cfg
	_C = keys["design.night"].lighting.celestial
	for k: String in KEYS:
		var d: Dictionary = keys[k]
		_look.append(HouseStyle.look(d.lighting))
		_weather.append(world.data.weather[d.name])
		_dust_design.append(d.lighting)
	# each key holds where it was approved: day and sunset at their designs' sun, night at its celestial hour
	_el = [float(keys.design.lighting.elevation), float(keys["design.sunset"].lighting.elevation),
		_elevation(HouseStyle.sun_at(_C, float(_C.hour)))]
	_base_coat = float(keys.design.weathering.amount)
	_storm_coat = float(keys["design.storm"].weathering.amount)
	_base_side = float(keys.design.weathering.side)
	_storm_side = float(keys["design.storm"].weathering.side)
	coat = _base_coat
	# a sol of day_minutes real minutes, with the night night_speed times faster: the day's rate from the whole sol
	var n := 480
	var slow := 0.0
	for i in n:
		slow += 1.0 / _speed(_elevation(HouseStyle.sun_at(_C, 24.0 * (i + 0.5) / n)))
	_rate = 24.0 * (slow / n) / (float(cfg.day_minutes) * 60.0)
	_phase_h = {"dawn": _cross(_el[1], true), "noon": 12.0, "dusk": _cross(_el[1], false), "night": float(_C.hour), "storm": 12.0}
	hours = float(cfg.start_hour)
	_last_hours = hours
	for c: Node in game.get_children():
		if c is HouseStyle.SkyClock:
			c.driven = true
			_stars = c
	_find_panels()
	refresh()


## Everything again, now, with no fade or burst: after a quality switch (the world rebuilt its lamps and materials),
## a jump, or at load.
func refresh() -> void:
	_lamps.clear()
	_probe_list = _world.find_children("*", "ReflectionProbe", true, false)
	_coat_shown = -1.0
	for p in _panels:
		p.shown = -1.0
	state = ""
	_update_look(true)
	_burst_t = 1.0
	_burst_to = _solved(_light_to)
	_light_from = _burst_to
	_set_light(_burst_to)
	_redraw_probes()


func hour() -> float:
	return fposmod(hours, 24.0)


## The rules' hook (14 Nov): put the clock at `h` (0 to 24 local solar time; larger values run on into later sols).
## With `driven` set the clock never moves it itself.
func set_hour(h: float) -> void:
	hours = h
	_skip_to = -1.0


## Straight to the next `phase` (PHASES) with no time-lapse: tests, captures and the old sky switch.
func jump(phase: String) -> void:
	storm_on = phase == "storm"
	storm = 1.0 if storm_on else 0.0
	_phase = PHASES.find(phase)
	hours = _next(_phase_h[phase])
	_last_hours = hours  # a jump settles no dust
	_skip_to = -1.0
	refresh()


## The debug key: a few seconds of time-lapse to the next phase (dawn, noon, dusk, night), then a storm at noon, then
## the storm off and on to dawn, so the coat it left can be seen.
func skip() -> void:
	_phase = (_phase + 1) % PHASES.size()
	storm_on = PHASES[_phase] == "storm"
	_skip_to = _next(_phase_h[PHASES[_phase]])
	_skip_rate = (_skip_to - hours) / float(_cfg.skip_s)


## The part of the sol the look is in (day, dawn, dusk, night, storm), for the frame-rate label and the report.
func phase() -> String:
	var h := hour()
	if storm > 0.5:
		return "storm"
	if weights[2] > 0.5:
		return "night"
	if weights[0] > 0.99:
		return "day"
	return "dawn" if h < 12.0 else "dusk"


func report() -> Dictionary:
	var lit := 0
	for s: Dictionary in _lamps.values():
		lit += int(s.on)
	return {"state": state, "phase": phase(), "hour": snappedf(hour(), 0.01), "sun_el": snappedf(_elevation(sun), 0.1),
		"sun_az": snappedf(fposmod(rad_to_deg(atan2(sun.x, -sun.z)), 360.0), 0.1),
		"keys": {"day": snappedf(weights[0], 0.01), "sunset": snappedf(weights[1], 0.01), "night": snappedf(weights[2], 0.01),
			"storm": snappedf(weights[3], 0.01)},
		"light_el": snappedf(_elevation(_light_now.get("dir", Vector3.UP)), 0.1), "lamps_on": lit, "coat": snappedf(coat, 0.001),
		"bursts": bursts, "probe_redraws": probe_redraws}


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var was := hours
	if _skip_to >= 0.0:
		hours = minf(hours + _skip_rate * delta, _skip_to)
		if hours >= _skip_to:
			_skip_to = -1.0
	elif not (driven or paused or pinned):
		hours += _rate * _speed(_elevation(sun)) * delta
	if _stars:
		# the planet's own seconds since the night design's hour: stars, Phobos and Deimos keep pace with the sun
		_stars.t = (hours - float(_C.hour)) * float(_cfg.sol_s) / 24.0
	_since_look += delta
	var dh := hours - was
	if _since_look >= 1.0 / float(_cfg.look_hz) or dh > 0.05:
		_update_look(false)
		_since_look = 0.0
	elif dh != 0.0:
		# the disc keeps pace with the light and the stars every frame (a global: the cubemap is left alone); at
		# look_hz alone it stepped like a slideshow in a fast-forward (Ravindu, 14 Nov)
		var s := HouseStyle.sun_at(_C, hour())
		RenderingServer.global_shader_parameter_set(&"forge_sky_sun_dir", s)
		RenderingServer.global_shader_parameter_set(&"forge_sky_twilight_dir", Vector3(s.x, 0.0, s.z).normalized())
	if float(_cfg.sun_step_deg) <= 0.0:
		if hours != _lit_at:  # a still clock leaves the light, and the sky's reflections, alone
			_lit_at = hours
			var l := _burst_to.duplicate()
			l.dir = _light_dir(HouseStyle.sun_at(_C, hour()))
			_set_light(l)
	elif _burst_t < 1.0:
		_burst_t = minf(_burst_t + delta / float(_cfg.burst_s), 1.0)
		var e := smoothstep(0.0, 1.0, _burst_t)
		_set_light({"dir": (_light_from.dir as Vector3).slerp(_burst_to.dir, e).normalized(),
			"color": lerp(_light_from.color, _burst_to.color, e), "energy": lerpf(_light_from.energy, _burst_to.energy, e),
			"shadowed": lerpf(_light_from.shadowed, _burst_to.shadowed, e)})
	_fade_lamps(delta)
	cost_us = Time.get_ticks_usec() - t0
	cost_max_us = maxi(cost_max_us, cost_us)


## Hours of the next time the sol reaches `h`, from now (today if it is still ahead).
func _next(h: float) -> float:
	var base := hours - hour()
	return base + h if base + h > hours + 0.01 else base + 24.0 + h


## The day speed's multiple at sun elevation `el`: night_speed below the night key, ramping in above it.
func _speed(el: float) -> float:
	return lerpf(1.0, float(_cfg.night_speed), smoothstep(_el[2] + float(_cfg.night_ramp_deg), _el[2], el))


static func _elevation(d: Vector3) -> float:
	return rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))


## The hour the sun crosses elevation `el`, rising (morning) or setting.
func _cross(el: float, rising: bool) -> float:
	var lo := 0.0 if rising else 12.0
	var hi := 12.0 if rising else 24.0
	for i in 30:
		var mid := (lo + hi) / 2.0
		if (_elevation(HouseStyle.sun_at(_C, mid)) < el) == rising:
			lo = mid
		else:
			hi = mid
	return (lo + hi) / 2.0


## The keys' shares at sun elevation `el`, the storm laid over the lit keys (a storm's night is still night).
func _weights(el: float) -> Array[float]:
	var w: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if el >= _el[0]:
		w[0] = 1.0
	elif el >= _el[1]:
		w[0] = smoothstep(_el[1], _el[0], el)
		w[1] = 1.0 - w[0]
	elif el >= _el[2]:
		w[1] = smoothstep(_el[2], _el[1], el)
		w[2] = 1.0 - w[1]
	else:
		w[2] = 1.0
	w[3] = (w[0] + w[1]) * storm
	w[0] *= 1.0 - storm
	w[1] *= 1.0 - storm
	return w


func _update_look(now: bool) -> void:
	looks += 1
	var h := hour()
	sun = HouseStyle.sun_at(_C, h)
	var el := _elevation(sun)
	# the storm and the coat build and clear over game hours, not real seconds (skills/day-cycle section 3)
	var dh := maxf(hours - _last_hours, 0.0)
	_last_hours = hours
	storm = move_toward(storm, 1.0 if storm_on else 0.0, dh / float(_cfg.storm_build_h))
	_settle(dh)
	weights = _weights(el)
	var v := HouseStyle.blend(_look, weights)
	v.sun_dir = sun
	v.twilight_dir = Vector3(sun.x, 0.0, sun.z).normalized()
	v.merge(HouseStyle.sky_fades(el, _C), true)
	for k: String in ["star_fade", "moon_fade", "milky_gain"]:
		v[k] *= 1.0 - storm  # a dust storm hides the stars
	# the night is lit by a fill from the night design's own direction, not by a sun under the ground: one light,
	# handed over at `light_swap_deg` where both sides are dark (the sun's last light, the night's first)
	var swap := float(_cfg.light_swap_deg)
	var band := float(_cfg.light_band_deg)
	var to := {"dir": _light_dir(sun), "color": v.light_color, "energy": v.light_energy * smoothstep(swap, swap + band, el)}
	if el <= swap:
		var night: Dictionary = _look[2]
		to = {"dir": _light_dir(sun), "color": night.light_color,
			"energy": night.light_energy * weights[2] * smoothstep(swap, swap - band, el)}
	# Never quite off. The Compatibility renderer specialises every material on whether the sun lights it and on
	# whether the fog scatters it (USE_SUN_SCATTER below 0.001, rasterizer_scene_gles3.cpp 4.7.2): crossing either at
	# the first dusk compiled every material again, seconds of hitches on a cold shader cache (measured 13 Nov)
	to.energy = maxf(to.energy, float(_cfg.light_floor))
	v.fog_sun = maxf(v.fog_sun * smoothstep(swap, swap + band, el), float(_cfg.scatter_floor))  # round the sun, not the night fill
	for k: String in ["light_color", "light_energy", "light_dir"]:
		v.erase(k)
	HouseStyle.set_look(_game, _design, v)
	_v = v
	_light_to = to
	# `sun_step_deg` 0: the light turns with the sun every frame (_process), its colour and energy taken here. Above 0
	# it moves only when the sun has moved a step, in a short eased burst (skills/day-cycle section 4). The 13 Nov
	# playtest read 1 degree steps as shadows that "wait, then teleport fast-forward"
	var step := float(_cfg.sun_step_low_deg if el < float(_cfg.low_deg) else _cfg.sun_step_deg)
	if step <= 0.0:
		_burst_to = _solved(to)
	elif not now and rad_to_deg(sun.angle_to(_burst_sun)) >= step:
		_burst_sun = sun
		_light_from = _light_now.duplicate()
		_burst_to = _solved(to)
		_burst_t = 0.0
		bursts += 1
	elif now:
		_burst_sun = sun
	for p: ReflectionProbe in _probes(false):
		p.ambient_color = Color(v.ambient_color.x, v.ambient_color.y, v.ambient_color.z).linear_to_srgb()
		p.ambient_color_energy = v.ambient
	if _probe_w.size() and not now:
		var moved := 0.0
		for i in 4:
			moved += absf(weights[i] - _probe_w[i])
		if moved >= float(_cfg.probe_step):
			_redraw_probes()
	_lamp_targets(el, now)
	_lead(now)
	_wind(h, el, now)
	_show_coat()


## The key with the largest share leads: the weather row (dust, the trackers' stow) and the audio follow it.
func _lead(now: bool) -> void:
	var best := 0
	for i in 4:
		if weights[i] > weights[best] + 0.001:
			best = i
	if KEYS[best] != state or now:
		var changed: bool = KEYS[best] != state
		state = KEYS[best]
		_world.weather = _weather[best].duplicate()
		# at the particle share the player chose now (a quality switch replaces `_quality`)
		_world.dust.restyle({"materials": _design.materials, "lighting": _dust_design[best], "_quality": _design.get("_quality", {})}, _world.weather, now)
		if changed:
			phase_changed.emit(state)


## The wind of the hour: Gale's downslope winds after dark are its strongest (Martinez 2017; Ullan 2017: about 21 m/s
## at night against 14 by day), so the night key's wind is `night_wind` times the row's. A whirlwind shows only in
## `devil_hours` (Newman 2019: Gale's vortices peak 11:00 to 13:00), on the day key's row.
func _wind(h: float, el: float, now: bool) -> void:
	var wind := 0.0
	for i in 4:
		wind += weights[i] * float(_weather[i].wind) * (float(_cfg.night_wind) if i == 2 else 1.0)
	_world.weather.wind = wind
	var hours_on: Array = _cfg.devil_hours
	var devil: bool = _world.weather.get("devil", false) and h >= float(hours_on[0]) and h < float(hours_on[1])
	if _world.dust.devil.emitting != devil or now:
		_world.dust.switch(_world.dust.devil, devil, now)  # spins up in play, whole at once behind a cover
	# the trackers turn to the real sun, and lie flat once it is down or the row says stow (a storm)
	_world.machines.aim(Vector3.ZERO if el <= 0.0 or _world.weather.get("stow", false) else sun)


## Dust settles on everything while a storm blows and stays after it; the wind takes it back only slowly (an e-fold of
## `coat_clear_sols`). Panels hold their own share: a storm coats them all, a tilt sheds one (NASA crew-base studies
## shed panel dust by tilting, NTRS 20170000235).
func _settle(dh: float) -> void:
	if storm > 0.5:
		coat = move_toward(coat, _storm_coat, (_storm_coat - _base_coat) / float(_cfg.coat_rise_h) * dh)
		# each panel gathers it again at the same rate, a shed one too: setting them all to 1 here undid a tilt's shed
		# within a tenth of a second, and a panel tilted in a storm flickered dusty and bare (13 Nov playtest)
		for p in _panels:
			p.keep = move_toward(p.keep, 1.0, dh / float(_cfg.coat_rise_h))
	else:
		coat = _base_coat + (coat - _base_coat) * exp(-dh / (24.0 * float(_cfg.coat_clear_sols)))


func _show_coat() -> void:
	var extra := clampf((coat - _base_coat) / (_storm_coat - _base_coat), 0.0, 1.0)
	if absf(coat - _coat_shown) >= 0.002:
		_coat_shown = coat
		HouseStyle.set_coat(_design, coat, lerpf(_base_side, _storm_side, extra))
	for p in _panels:
		var share: float = p.keep * extra
		if absf(share - p.shown) >= 0.005:
			p.shown = share
			for c: Array in p.copies:
				(c[0] as MultiMeshInstance3D).multimesh.set_instance_custom_data(c[1], Color(share, 0, 0, 0))


## A tilt by hand (sandbox/interactions.gd "panel") sheds that panel's dust over `shed_s`.
func used(what: String, pos: Vector3) -> void:
	if not (what == "panel" or what == "clean_panel") or _panels.is_empty():  # tilted or brushed, the dust comes off
		return
	var near: Dictionary = _panels[0]
	for p in _panels:
		if (p.node as Node3D).global_position.distance_to(pos) < (near.node as Node3D).global_position.distance_to(pos):
			near = p
	create_tween().tween_method(func(k: float) -> void:
		near.keep = k
		_show_coat(), near.keep, 0.0, float(_cfg.shed_s))


## Every solar panel the trackers turn, with its drawn copies in the world's MultiMeshes, whose material takes the
## coat per copy (HouseStyle role `each`).
func _find_panels() -> void:
	_panels.clear()
	for m: Dictionary in _world.machines.panels:
		var node: Node3D = m.node
		var copies: Array = []
		for mi: MeshInstance3D in ([node] if node is MeshInstance3D else []) + node.find_children("*", "MeshInstance3D", true, false):
			var c: Array = _world.instanced(mi)
			if c.size():
				copies.append(c)
		if copies.size():
			_panels.append({"node": node, "copies": copies, "keep": 0.0, "shown": -1.0})
	_coat_panels()


## The panels' MultiMesh copies wear their role with a per-copy coat (after any restyle, which puts the clean role back).
func _coat_panels() -> void:
	var done := {}
	for p in _panels:
		for c: Array in p.copies:
			var mmi: MultiMeshInstance3D = c[0]
			if done.has(mmi):
				continue
			done[mmi] = true
			var mesh := mmi.multimesh.mesh
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m and _design.materials.has(m.resource_name):
					mesh.surface_set_material(i, HouseStyle.role(_design, m.resource_name, false, false, true))


## After the world restyled (a quality switch): its lamps and materials are new.
func restyled() -> void:
	_coat_panels()
	refresh()


func _set_light(l: Dictionary) -> void:
	if l.is_empty():
		return
	_light_now = l
	light_writes += 1
	HouseStyle.set_look(_game, _design, {"light_dir": l.dir, "light_color": l.color, "light_energy": l.energy,
		"light_shadowed": l.shadowed, "disc": _v.disc, "split_el": _v.split_el})  # the keys' own suns size the split


## Where the one light shines from for a sun direction `s`: the sun itself, never from under the ground (a light below
## the horizon lit the undersides), and the night design's fill once the sun is below `light_swap_deg`.
func _light_dir(s: Vector3) -> Vector3:
	var el := _elevation(s)
	if el <= float(_cfg.light_swap_deg):
		return _look[2].light_dir
	if el >= 1.0:
		return s
	var flat := Vector3(s.x, 0.0, s.z).normalized()
	return flat * cos(deg_to_rad(1.0)) + Vector3.UP * sin(deg_to_rad(1.0))


## A light end with its Compatibility energy solved (HouseStyle._shadowed()) under the ambient in force.
func _solved(l: Dictionary) -> Dictionary:
	var out := l.duplicate()
	out.shadowed = HouseStyle._shadowed(_design, _game, l.energy, l.color, (l.dir as Vector3).y)
	return out


## The outdoor probes (a room probe that is `interior` never sees the sky) are redrawn whenever the blend has moved
## `probe_step` since the last time, a few times a sol: a dirty probe is drawn once a camera sees it.
func _probes(outdoor: bool) -> Array:
	return _probe_list.filter(func(p: ReflectionProbe) -> bool: return not outdoor or not p.interior)


func _redraw_probes() -> void:
	_probe_w = weights.duplicate()
	probe_redraws += 1
	for p: ReflectionProbe in _probes(true):
		p.update_mode = p.update_mode  # re-setting it is what dirties an UPDATE_ONCE probe (HouseStyle._redraw_probes())


## Lamps switch on below `lamps_on_deg` of sun and off above `lamps_off_deg` (hysteresis), each a little apart from the
## others so the base does not flip like a switchboard; the fade itself is _fade_lamps().
func _lamp_targets(el: float, now: bool) -> void:
	var on_deg := float(_cfg.lamps_on_deg)
	var off_deg := float(_cfg.lamps_off_deg)
	for l: OmniLight3D in get_tree().get_nodes_in_group("world_lamp"):
		if not _lamps.has(l):
			var full: float = l.get_meta("full", l.get_meta("energy"))
			l.set_meta("full", full)
			_lamps[l] = {"on": el < on_deg, "level": -1.0, "full": full,
				"at": float(hash(l.get_parent().name) % 100) / 100.0 * float(_cfg.lamps_stagger_deg)}
		var s: Dictionary = _lamps[l]
		if s.on and el > off_deg - s.at:
			s.on = false
		elif not s.on and el < on_deg - s.at:
			s.on = true
		if now or s.level < 0.0:
			s.level = 1.0 if s.on else 0.0
			_lamp(l, s)
	# the lamp heads, the pad's corner lights and the yard lights glow with their lamps: no floodlight burns in
	# daylight. The blinking status lights wear their own copy (machines.gd `light_flash`) and blink day and night
	if _glow.on and el > off_deg:
		_glow.on = false
	elif not _glow.on and el < on_deg:
		_glow.on = true
	if now or _glow.level < 0.0:
		_glow.level = 1.0 if _glow.on else 0.0
		_glow_faces()


## The `light` role's glow at the work lights' level, down to a glimmer (`light_floor`) by day. One material for every
## such face: the still items are merged into cells, so a face cannot be told by its item. A room's lights and
## screens wear the swept copy (DESIGN.md weathering.clean: `interior`) and stay lit: indoors no sun replaces them
## (14 Nov playtest: the shelter's ceiling light was dark at noon).
func _glow_faces() -> void:
	var k := maxf(float(_glow.level), float(_cfg.light_floor))
	for m: Material in _design.get("_roles", {}).values():
		if m.resource_name != "light" or m.get_meta("clean", false):
			continue
		if m is StandardMaterial3D:
			var std := m as StandardMaterial3D
			if not std.has_meta("glow"):
				std.set_meta("glow", std.emission_energy_multiplier)  # its full glow, from DESIGN.md `emissive`
			std.emission_energy_multiplier = float(std.get_meta("glow")) * k
		elif m is ShaderMaterial:
			var sm := m as ShaderMaterial
			if not sm.has_meta("glow"):
				sm.set_meta("glow", sm.get_shader_parameter("emission"))
			sm.set_shader_parameter("emission", (sm.get_meta("glow") as Color) * k)


func _fade_lamps(delta: float) -> void:
	var want_glow := 1.0 if _glow.on else 0.0
	if _glow.level != want_glow:
		_glow.level = move_toward(_glow.level, want_glow, delta / float(_cfg.lamps_fade_s))
		_glow_faces()
	for l: Variant in _lamps:
		var s: Dictionary = _lamps[l]
		var want := 1.0 if s.on else 0.0
		if s.level != want and is_instance_valid(l):
			s.level = move_toward(s.level, want, delta / float(_cfg.lamps_fade_s))
			_lamp(l, s)


## A lamp at `level`. Its meta energy is what the lamp pool (a preset's `lamps` limit) holds it to among the nearest;
## the pool fades by that same energy a second, so at 0 it stands still and the level is set here too. Off is a glimmer
## and not hidden: what a lamp reaches compiles its own variant of every material (DISABLE_LIGHT_OMNI otherwise), and a
## lamp that appeared at dusk compiled them in play.
func _lamp(l: OmniLight3D, s: Dictionary) -> void:
	l.set_meta("energy", s.full * s.level)
	l.light_energy = maxf(s.full * s.level, float(_cfg.light_floor))
	l.visible = true
