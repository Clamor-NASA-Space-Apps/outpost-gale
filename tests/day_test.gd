extends "res://addons/forge/test.gd"
## The world's own clock (world/sky_clock.gd, skills/day-cycle checks): godot --headless --path . -s tests/day_test.gd --fixed-fps 60
## The sun rises in the east and sets in the west at Gale's hours, the four designs blend through a sol with no jump
## and nothing darker than the night key, lamps switch once each way at dusk and dawn, the light turns with the sun
## every frame with no jump (and not at all while the clock stands), the probes redraw in steps, and
## the probes redraw in steps (never every frame), the night sky turns with the clock, a storm's dust stays after it
## and a wiped row of panels sheds its own, the clock waits while a menu is open, and the clock's own work per frame is small.
## In a time-lapse (the sleep's set_hour() every frame, the debug skip) the sun, the light and the sky's colour move on
## every frame with no step much larger than the rest, the probes still in steps; after it the look is back at look_hz.

const HouseStyle := preload("res://addons/forge/house_style.gd")

var game: Node3D
var clock: Node
# hours between the clock and phase `p`'s own hour
var off_phase := func(p: String) -> float: return absf(fposmod(clock.hour() - float(clock._phase_h[p]) + 12.0, 24.0) - 12.0)


func _init() -> void:
	watchdog = 300.0


func settle() -> void:
	for i in 900:
		if not game.busy():
			return
		await process_frame
	check(false, "the cover came down")


func el(h: float) -> float:
	return rad_to_deg(asin(HouseStyle.sun_at(clock._C, h).y))


## How bright a look leaves a lit top: ambient plus the light on a level face (linear luminance).
func lift(v: Dictionary, light: Dictionary) -> float:
	var lum := func(x: Vector3) -> float: return Color(x.x, x.y, x.z).get_luminance()
	return v.ambient * lum.call(v.ambient_color) + light.energy * lum.call(light.color) * maxf((light.dir as Vector3).y, 0.0)


## The clock driven to `h` and the look taken there, as the rules would drive it.
func at(h: float) -> void:
	clock.set_hour(h)
	clock._update_look(false)


func play() -> bool:
	# the waits count frames as game seconds: without a fixed step a headless run races, 1800 frames passed 0.3 game
	# hours where 30 s holds 0.7, and ten checks failed for it (13 Nov gate)
	# the engine eats its own flags (OS.get_cmdline_args() never lists --fixed-fps), so read the step it runs at
	await process_frame
	if not check(is_equal_approx(root.get_process_delta_time(), 1.0 / 60.0), "run with --fixed-fps 60 (the waits count frames as game time)"):
		return true
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	clock = game.clock
	await settle()
	var cfg: Dictionary = clock._cfg

	# 1. the sun: Gale (4.6 S) has near-equal day and night all year, noon is the highest, east at dawn, west at dusk
	var rise: float = clock._cross(0.0, true)
	var set_h: float = clock._cross(0.0, false)
	check(rise > 5.3 and rise < 6.5, "sunrise at %.2f h (about 06:00 at Gale)" % rise)
	check(set_h > 17.5 and set_h < 18.7, "sunset at %.2f h (about 18:00)" % set_h)
	check(absf((rise + set_h) / 2.0 - 12.0) < 0.05, "noon halfway between sunrise and sunset (%.2f)" % ((rise + set_h) / 2.0))
	check(set_h - rise > 11.6 and set_h - rise < 12.4, "daylight %.2f h (11.7 to 12.3 at 4.6 S, research row 3)" % (set_h - rise))
	check(HouseStyle.sun_at(clock._C, rise).x > 0.9 and HouseStyle.sun_at(clock._C, set_h).x < -0.9, "rises in the east, sets in the west")
	check(el(12.0) > el(11.5) and el(12.0) > el(12.5), "highest at noon (%.1f deg)" % el(12.0))
	check(el(0.0) < -60.0, "midnight is deep night (%.1f deg)" % el(0.0))
	# the keys sit where their designs were approved
	clock.pinned = true
	game._sky(1)
	await settle()
	check(clock.weights[1] > 0.99 and clock.state == "design.sunset", "the sunset key alone at the dusk phase (%s)" % [clock.weights])
	check(clock.hour() > 17.0 and clock.hour() < 18.2, "the dusk phase before sunset (%.2f)" % clock.hour())
	game._sky(2)
	await settle()
	check(clock.weights[2] > 0.99 and absf(clock.hour() - 19.5) < 0.01, "the night key alone at DESIGN.night.md's hour 19.5")
	game._sky(0)
	await settle()
	check(clock.weights[0] > 0.99 and absf(clock.hour() - 12.0) < 0.01, "the day key alone at noon")

	# 2. a whole sol in 0.02 h steps: no jump in any look value, nothing darker than the night key, never black
	clock.driven = true
	var night_lift := lift(clock._look[2], {"energy": clock._look[2].light_energy, "color": clock._look[2].light_color, "dir": clock._look[2].light_dir})
	var worst_jump := 0.0
	var worst_at := 0.0
	var darkest := INF
	var dark_at := 0.0
	var prev := -1.0
	var swaps := 0
	var side := false  # midnight is on the night side
	for i in 1201:
		var h := 24.0 * i / 1200.0
		at(h)
		var b := lift(clock._v, clock._light_to)
		if prev >= 0.0 and absf(b - prev) > worst_jump:
			worst_jump = absf(b - prev)
			worst_at = h
		prev = b
		if b < darkest:
			darkest = b
			dark_at = h
		var day_side: bool = (clock._light_to.dir as Vector3).angle_to(clock._look[2].light_dir) > 0.01
		swaps += int(day_side != side)
		side = day_side
	check(worst_jump < 0.01, "no jump through the sol: the largest step in brightness is %.4f at %.2f h" % [worst_jump, worst_at])
	check(darkest >= night_lift * 0.95, "never darker than the night key: %.4f at %.2f h against %.4f" % [darkest, dark_at, night_lift])
	check(darkest > 0.02, "the night is never black (ambient floor %.4f)" % darkest)
	check(swaps == 2, "the light hands over to the night fill once at dusk and back once at dawn (%d)" % swaps)

	# 3. lamps: once on through dusk, once off through dawn, never flickering; on at night, off by day
	var lamps: Array = clock._lamps.keys()
	check(lamps.size() > 0, "the base has lamps (%d)" % lamps.size())
	at(12.0)
	clock.refresh()
	check(clock.report().lamps_on == 0, "no lamp on at noon (%d)" % clock.report().lamps_on)
	var flips := {}
	for l: Object in lamps:
		flips[l] = 0
	var was := {}
	for pass_ in [[16.5, 19.5], [4.5, 7.5]]:
		for l: Object in lamps:
			was[l] = clock._lamps[l].on
		var h: float = pass_[0]
		while h < pass_[1]:
			at(h)
			for l: Object in lamps:
				if clock._lamps[l].on != was[l]:
					flips[l] += 1
					was[l] = clock._lamps[l].on
			h += 0.01
		if pass_[0] > 12.0:
			check(clock.report().lamps_on == lamps.size(), "every lamp on after dusk (%d of %d)" % [clock.report().lamps_on, lamps.size()])
	check(flips.values().all(func(n: int) -> bool: return n == 2), "each lamp switched exactly once each way (%s)" % [flips.values()])
	check(clock.report().lamps_on == 0, "every lamp off after dawn")
	# what the lights really do once the fades and the lamp pool (a preset's `lamps` limit) have run
	var dark := func() -> bool: return lamps.all(func(l: OmniLight3D) -> bool: return l.light_energy <= float(cfg.light_floor) * 1.01)  # a glimmer, light_floor
	for i in roundi(float(cfg.lamps_fade_s) * 60.0) + 30:
		await process_frame
	check(dark.call(), "by day every lamp is dark (%s)" % [lamps.map(func(l: OmniLight3D) -> float: return l.light_energy)])
	# and the faces that glow with them (lamp heads, the pad's corner lights): a glimmer by day; status lights blink on
	var face: StandardMaterial3D = HouseStyle.role(game.design, "light") as StandardMaterial3D
	var flash: StandardMaterial3D = game.world.machines._blink_mat
	if check(face != null and face.has_meta("glow"), "the light role glows on the clock's schedule"):
		check(face.emission_energy_multiplier <= float(face.get_meta("glow")) * float(cfg.light_floor) * 1.01,
			"by day the work lights' faces are a glimmer (%.4f of %.2f)" % [face.emission_energy_multiplier, face.get_meta("glow")])
	if flash:
		check(game.world.machines._glow > 1.0, "the blinking status lights keep their full glow by day (%.2f)" % game.world.machines._glow)
	at(21.0)
	await process_frame
	var mid: float = (lamps[0] as OmniLight3D).light_energy
	for i in roundi(float(cfg.lamps_fade_s) * 60.0) + 30:
		await process_frame
	var full: float = (lamps[0] as OmniLight3D).get_meta("full")
	check(mid < full * 0.5, "a lamp fades on, not at once (%.2f of %.2f a frame in)" % [mid, full])
	check(lamps.any(func(l: OmniLight3D) -> bool: return l.visible and l.light_energy > full * 0.99), "and shines at night")
	if face and face.has_meta("glow"):
		check(absf(face.emission_energy_multiplier - float(face.get_meta("glow"))) < 1e-3, "the work lights' faces glow fully at night")

	# 4. real time at the shortest sol: the light turns as smoothly as the sun, the probes redraw in steps, a cheap clock
	clock.driven = false
	clock.pinned = false
	cfg.day_minutes = 12
	var day_rate: float = clock._rate
	clock.setup(game, game.world, game.design, _keys(), cfg)
	check(clock._rate > day_rate * 1.6, "a 12 minute sol runs faster than 20 (%.4f h/s)" % clock._rate)
	at(15.0)  # long afternoon shadows: the small step
	clock.refresh()
	await process_frame
	var b0: int = clock.bursts
	var w0: int = clock.light_writes
	var p0: int = clock.probe_redraws
	var stars0: float = clock._stars.t
	var h0: float = clock.hours
	var sun0: Vector3 = clock.sun
	var costs: Array[int] = []
	var refs: Array[int] = []
	var sun_light: DirectionalLight3D = game.find_children("*", "DirectionalLight3D", false, false)[0]
	var turns: Array[float] = []
	var was_dir := sun_light.basis.z
	for i in 1800:  # 30 s at 60 fps
		await process_frame
		costs.append(clock.cost_us)
		var r0 := Time.get_ticks_usec()
		HouseStyle.sun_at(clock._C, 12.0)  # a yardstick timed beside it, so a busy machine slows both alike
		refs.append(Time.get_ticks_usec() - r0)
		turns.append(rad_to_deg(was_dir.angle_to(sun_light.basis.z)))
		was_dir = sun_light.basis.z
	var moved: float = clock.hours - h0
	var bursts: int = clock.bursts - b0
	var writes: int = clock.light_writes - w0
	check(moved > 0.6 and moved < 0.8, "30 s of a 12 minute sol is about 0.7 h (%.3f)" % moved)
	var arc := rad_to_deg(sun0.angle_to(clock.sun))
	turns.sort()
	# the 13 Nov playtest: stepped shadows "wait, then teleport fast-forward". Continuous: every frame the same small turn
	check(float(cfg.sun_step_deg) == 0.0 and bursts == 0 and writes >= 1795, "the light turned on %d of 1800 frames, no bursts" % writes)
	check(turns[90] > 0.0 and turns[-1] < turns[900] * 2.0 + 1e-4, "no frame turns it more than twice the median (%.4f, median %.4f deg, %.1f deg in all)" % [turns[-1], turns[900], arc])
	clock.pinned = true
	var w1: int = clock.light_writes
	for i in 30:
		await process_frame
	check(clock.light_writes == w1, "a still clock leaves the light, and the sky's reflections, alone")
	clock.pinned = false
	check(clock.probe_redraws - p0 <= 1, "no probe redraw in a quiet afternoon half hour (%d)" % (clock.probe_redraws - p0))
	var stars_s: float = clock._stars.t - stars0
	check(absf(stars_s - moved * float(cfg.sol_s) / 24.0) < 5.0, "the night sky turned %.0f Mars s with the clock" % stars_s)
	costs.sort()
	# the look update runs look_hz times a second, the frames between only move the clock and a burst: the typical
	# update is the median of the dearest look_hz/60 of frames. Their tail is the scheduler on a loaded machine (a
	# 0.3 ms piece of work preempted for 10 ms), so it is printed, not checked
	var ticks := costs.slice(1800 - roundi(1800 * float(cfg.look_hz) / 60.0))
	refs.sort()
	# in yardsticks (one sun_at(), about 17 us on this laptop when it is quiet): a frame about 5, a look update about 10
	var ref := maxf(float(refs[900]), 1.0)
	check(costs[900] < 12.0 * ref, "the clock's own work, median %d us a frame (%.1f yardsticks)" % [costs[900], costs[900] / ref])
	# its lower tenth: a 0.3 ms piece of work is preempted far more often than a 17 us one on a loaded machine
	var tick := float(ticks[ticks.size() / 10])
	check(tick < 40.0 * ref, "a look update takes %d us (lower tenth, %.1f yardsticks)" % [tick, tick / ref])
	print("clock cost per frame: median %d us, look update median %d us, 99th %d us, max %d us; %d bursts, %d light writes in 1800 frames" % [
		costs[900], ticks[ticks.size() / 2], costs[1782], costs[-1], bursts, writes])
	# probes across a whole sol: a handful of redraws, at the key changes
	clock.driven = true
	var pr: int = clock.probe_redraws
	for i in 481:
		at(24.0 + 24.0 * i / 480.0)
	check(clock.probe_redraws - pr >= 4 and clock.probe_redraws - pr <= 16, "%d probe redraws in a sol (4 to 16)" % (clock.probe_redraws - pr))

	# 5. a storm's dust stays after it, a clean sheds one row's, the wind takes the rest slowly
	var body: ShaderMaterial = HouseStyle.role(game.design, "body", true)
	var base_coat: float = clock._base_coat
	check(clock._panels.size() > 0, "the trackers' panels wear their own coat (%d)" % clock._panels.size())
	game._sky(3)
	await settle()
	for i in 200:  # two game hours of storm
		at(12.0 + i * 0.01)
	check(clock.coat > base_coat + 0.2, "the storm coated everything (%.3f from %.3f)" % [clock.coat, base_coat])
	check(absf(float(body.get_shader_parameter("coat_amount")) - clock.coat * float(game.design.materials.body.get("weathering", 1))) < 0.01,
		"a role's coat follows the world's (%.3f)" % body.get_shader_parameter("coat_amount"))
	game._sky(0)  # the storm gone
	await settle()
	check(clock.storm == 0.0 and clock.coat > base_coat + 0.2, "the coat stays when the storm ends (%.3f)" % clock.coat)
	var p: Dictionary = clock._panels[0]
	var other: Dictionary = clock._panels[-1]
	# what went to the MultiMesh (headless, the dummy renderer keeps no instance data to read back)
	var share := func(q: Dictionary) -> float: return q.shown
	check(share.call(p) > 0.9 and share.call(other) > 0.9, "every panel dusty after the storm (%.2f)" % share.call(p))
	clock.used("clean_panel", (p.node as Node3D).global_position)
	check(share.call(p) < 0.01, "a wiped row shed its dust (%.3f)" % share.call(p))
	check(other.row != p.row and share.call(other) > 0.9, "another row kept its own (%.2f)" % share.call(other))
	var c0: float = clock.coat
	for i in 241:
		at(clock.hours + 0.1)
	check(clock.coat < c0 and clock.coat > base_coat + (c0 - base_coat) * 0.85, "a sol of wind clears a little of it (%.3f to %.3f)" % [c0, clock.coat])
	# every part of a panel (frame, backsheet, cells) wears the coat: each mesh under it has a drawn copy that takes it
	var bare := 0
	for q: Dictionary in clock._panels:
		var meshes := ([q.node] if q.node is MeshInstance3D else []) + (q.node as Node3D).find_children("*", "MeshInstance3D", true, false)
		meshes = meshes.filter(func(m: MeshInstance3D) -> bool: return m.mesh != null)
		bare += meshes.size() - (q.copies as Array).size()
	check(bare == 0, "every part of every panel is drawn coated (%d parts left bare)" % bare)
	# a clean in a storm: the dust comes back only at the storm's rate
	game._sky(3)
	await settle()
	for i in 200:
		at(clock.hours + 0.01)
	var tp: Dictionary = clock._panels[1]
	check(tp.shown > 0.8, "a panel dusty in the storm (%.2f)" % tp.shown)
	clock.used("clean_panel", (tp.node as Node3D).global_position)
	check(tp.shown < 0.02, "wiped clean in the storm (%.3f)" % tp.shown)
	for i in 30:
		at(clock.hours + 0.002)
	var back: float = tp.shown
	check(back > 0.0 and back < 0.06 / float(cfg.coat_rise_h) * 1.5 + 0.01, "then it gathers dust again at the storm's rate, not at once (%.3f after 0.06 h)" % back)
	game._sky(0)
	await settle()

	# 6. the clock waits while the settings screen is open
	clock.driven = false
	var h1: float = clock.hours
	game.settings.open()
	for i in 30:
		await process_frame
	check(clock.hours == h1, "the clock stood still under the settings screen")
	game.settings.close()
	for i in 30:
		await process_frame
	check(clock.hours > h1, "and runs again once it closes")

	# 7. a time-lapse driven as the sleep drives it (cine.gd: set_hour() before the clock's own frame), through an
	# afternoon, where the light is the sun: the 15 Nov playtest saw the sun "like a slide show", because a driven
	# clock never saw its hour move and took the sky's sun only at look_hz
	clock.jump("noon")
	clock.driven = true
	var lapse_from: float = clock.hours
	var lapse_looks: int = clock.looks
	var lapse_redraws: int = clock.probe_redraws
	var sun_steps: Array[float] = []
	var light_steps: Array[float] = []
	var sun_was: Vector3 = clock.sun
	was_dir = sun_light.basis.z
	for i in 241:  # 4 s at the night lapse's 1.1 h a second
		await process_frame
		if i > 0:  # what the clock made of the hour set a frame ago
			sun_steps.append(rad_to_deg(sun_was.angle_to(clock.sun)) if clock.sun != sun_was else 0.0)
			light_steps.append(rad_to_deg(was_dir.angle_to(sun_light.basis.z)) if sun_light.basis.z != was_dir else 0.0)
		sun_was = clock.sun
		was_dir = sun_light.basis.z
		clock.set_hour(lapse_from + (i + 1) * 1.1 / 60.0)
	sun_steps.sort()
	light_steps.sort()
	check(sun_steps[0] > 0.0 and light_steps[0] > 0.0, "in a lapse the sky's sun and the light move on every frame (smallest steps %.3f, %.3f deg)" % [sun_steps[0], light_steps[0]])
	check(sun_steps[-1] < sun_steps[120] * 2.0 and light_steps[-1] < light_steps[120] * 2.0,
		"and no frame steps more than twice the median (sun %.3f of %.3f deg, light %.3f of %.3f)" % [sun_steps[-1], sun_steps[120], light_steps[-1], light_steps[120]])
	check(clock.looks - lapse_looks >= 239, "the sky's colour is taken on every frame of a lapse (%d looks in 240 frames)" % (clock.looks - lapse_looks))
	check(clock.probe_redraws - lapse_redraws <= 4, "the probes keep their own rate in a lapse (%d redraws in 240 frames)" % (clock.probe_redraws - lapse_redraws))
	clock.driven = false
	await process_frame
	lapse_looks = clock.looks
	for i in 120:
		await process_frame
	check(clock.looks - lapse_looks <= 2 * int(cfg.look_hz) + 2, "after it the look is back at look_hz (%d looks in 2 s)" % (clock.looks - lapse_looks))

	# 8. the debug key: a short time-lapse to each next phase, then a storm, then dawn with the storm's dust left on
	clock.coat = base_coat
	clock.jump("noon")
	var wait := roundi(float(cfg.skip_s) * 60.0) + 20
	for want: String in ["dusk", "night", "storm", "dawn"]:
		game._unhandled_input(_key(&"debug_sky"))
		sun_steps.clear()
		for i in wait:
			sun_was = clock.sun
			var seen: float = clock._seen
			await process_frame
			if clock._seen != seen:  # the frames on which the clock saw its hour move
				sun_steps.append(rad_to_deg(sun_was.angle_to(clock.sun)) if clock.sun != sun_was else 0.0)
		sun_steps.sort()
		check(sun_steps.size() > 100 and sun_steps[0] > 0.0 and sun_steps[-1] < sun_steps[sun_steps.size() / 2] * 2.0,
			"the skip to %s moved the sun on every frame, evenly (%d frames, %.3f to %.3f deg, median %.3f)" % [want, sun_steps.size(),
			sun_steps[0] if sun_steps.size() else 0.0, sun_steps[-1] if sun_steps.size() else 0.0, sun_steps[sun_steps.size() / 2] if sun_steps.size() else 0.0])
		check(off_phase.call(want) < 0.15, "the sky key time-lapsed to %s (%.2f h, off by %.2f)" % [want, clock.hour(), off_phase.call(want)])
		if want == "storm":
			check(clock.storm > 0.99 and clock.coat > base_coat + 0.2, "a storm at noon, its dust settled through the skip (%.3f)" % clock.coat)
	check(clock.storm == 0.0 and clock.coat > base_coat + 0.2, "dawn after the storm, still dusty (%.3f)" % clock.coat)
	return true


func _key(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _keys() -> Dictionary:
	var k := {}
	for name: String in game.SKIES:
		k[name] = HouseStyle.load_design("res://%s.json" % name)
	return k
