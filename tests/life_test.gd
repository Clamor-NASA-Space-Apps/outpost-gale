extends "res://addons/forge/test.gd"
## More life (CONTRACTS.md "More life"): godot --headless --path . --fixed-fps 60 -s tests/life_test.gd
## The rover's drawn body squats setting off, leans out of a turn, dips braking and settles, while the camera's target
## stays on the wheels; the radio and the quiet motif keep their gaps and never sound over a cue; the dusk glance turns
## the view only in the sunset sky, only while the look is left alone, and never its pitch.

var game: Node3D
var audio: Node


func _init() -> void:
	watchdog = 300.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	audio = game.audio
	await _rover()
	await _radio()
	await _motif()
	await _dusk()
	return true


func _rover() -> void:
	var player: Node3D = game.player
	var rover: Node3D = game.world.items.rover
	# west, away from the base, on open ground
	rover.yaw = PI / 2.0
	rover._apply(rover._pose(rover.global_position, rover.yaw))
	player.enter(rover)
	await frames(90)
	var r: Vector3 = rover._off
	check(r.length() < 0.002, "parked, the body has settled on its springs (%s)" % r)
	var up := 0.0
	action(&"move_forward")
	for i in 60:
		await frames(1)
		up = maxf(up, rover._off.y)
	check(up > deg_to_rad(0.3), "setting off, the nose lifts (%.2f deg)" % rad_to_deg(up))
	await frames(90)
	check(absf(rover.v) > 2.0, "it drives (%.2f m/s, blocked: '%s')" % [rover.v, rover.blocked])
	action(&"move_right")
	var roll := 0.0
	var steady := true
	for i in 150:
		await frames(1)
		roll = maxf(roll, rover._off.z)
		# the physics body (the camera's target) stays on the wheels' plane: no spring in it
		var rigid := Basis.from_euler(Vector3(rover._plane.y, rover.yaw, rover._plane.z))
		steady = steady and rover.global_basis.is_equal_approx(rigid)
	# a right turn: the turn's centre is to the right, so the top leans left (positive roll lifts the right side)
	var want: float = deg_to_rad(rover.spring.roll_deg_g) * absf(rover.v) * rover.turn / rover.g
	check(roll > want * 0.6, "in a right turn the body leans out, to the left (%.2f deg, about %.2f wanted)" % [rad_to_deg(roll), rad_to_deg(want)])
	check(steady, "the camera's target never leans: only the drawing does")
	check(player.cam.target == rover, "the camera follows the rover's body")
	var seat: Transform3D = rover.global_transform * rover.lean * Transform3D(Basis(), rover.seat_at)
	check(rover.seat().is_equal_approx(seat), "the driver's seat rides with the cab")
	action(&"move_right", false)
	action(&"move_forward", false)
	var dip := 0.0
	for i in 120:
		await frames(1)
		dip = minf(dip, rover._off.y)
	check(dip < -deg_to_rad(0.3), "braking, the nose dips (%.2f deg)" % rad_to_deg(dip))
	var k: Dictionary = rover.get_script().get_script_constant_map()
	var lim := Vector3(rover.travel, atan2(rover.travel, k.AXLE), atan2(rover.travel, k.TRACK))
	await frames(180)
	r = rover._off
	check(absf(rover.v) < 0.01 and r.length() < 0.002, "stopped, it settles within 3 s (%s)" % r)
	check(absf(r.x) <= lim.x and absf(r.y) <= lim.y and absf(r.z) <= lim.z, "inside the suspension's travel")
	player.exit()
	await frames(5)


func _radio() -> void:
	var r: Dictionary = audio.t.radio
	var spawn: Dictionary = game.world.landmark("spawn")
	game.player.place(spawn.pos, spawn.yaw)
	await frames(30)
	check(float(r.base_s[0]) >= float(r.gap_s), "the base calls no more often than the radio's gap")
	_quiet_now()
	audio.play("radio_pip", Vector3.ZERO)  # what PIP's sound signal sends
	await frames(2)
	check(audio.radio_who == "pip" and audio._time - audio.radio_last < 0.1, "PIP's chirp plays on the radio when the air is clear")
	var heard: Array = audio.get_children().filter(func(n: Node) -> bool:
		return n is AudioStreamPlayer and n.playing and n.stream.resource_path.get_file() == "radio_pip.ogg")
	check(heard.size() == 1 and heard[0].bus == "Suit", "on the suit radio, clear")
	var last: float = audio.radio_last
	audio._busy_until = -1e9
	audio.radio("base")
	await frames(30)
	check(audio.radio_last == last, "a second call within the gap waits")
	audio._radio_by = audio._time + 0.2  # as if it had waited its `wait_s`
	await frames(20)
	check(audio._radio_want == "" and audio.radio_last == last, "and is dropped when its wait runs out")
	# never over a cue: a music cue, then an event sound
	_quiet_now()
	check(audio.music("discovery"), "a cue plays")
	audio.radio("base")
	await frames(30)
	check(audio.radio_last < audio._time - 0.4, "no radio over a music cue")
	_quiet_now()
	audio.play("door_open", spawn.pos)
	audio.radio("base")
	await frames(2)
	check(audio.radio_last < audio._time - 0.01, "no radio over an event sound")
	await frames(int(60 * (audio._busy_until - audio._time + 0.3)))  # "door_open" is a hiss and the door (audio.gd SOUNDS)
	check(audio.radio_who == "base" and audio._time - audio.radio_last < 0.4, "it plays once the sound has ended")


func _motif() -> void:
	var m: Dictionary = audio.t.motif
	audio.t.motif.after_s = 0.0  # this run is younger than a session's settling time
	_quiet_now()
	audio._still_s = float(m.still_s) - 1.0  # most of the still spell already stood
	var start: float = audio._time
	var played := -1.0
	for i in 150:
		await frames(1)
		if audio.cue == m.name and played < 0.0:
			played = audio._time - start
	check(played > 0.5 and played < 2.0, "standing still outside %s s plays the motif (the last second took %.1f s)" % [m.still_s, played])
	var at: float = audio._motif_at
	_quiet_now()
	audio._still_s = float(m.still_s) + 1.0
	await frames(5)
	check(audio._motif_at == at, "never twice within %s s, even after another still spell" % m.gap_s)
	# the dust devil (out in the day sky) in the middle of the view: once a session
	var devil: Node3D = game.world.dust.devil
	game.clock.jump("noon")  # the whirlwind is out around midday (tuning.json sky.devil_hours, world/sky_clock.gd)
	game.clock.pinned = true
	await frames(60)  # the devil walks out to its circle, and the trackers' servos that the noon sun started go quiet
	check(devil.emitting, "the day sky has its dust devil at noon")
	audio._motif_at = -1e9
	audio._devil_seen = false  # a drive past it earlier in this run may have counted
	_quiet_now()
	_face(devil.global_position)
	await frames(3)
	check(audio._devil_seen and audio.cue == m.name, "the first sight of the dust devil plays the motif")
	audio._motif_at = -1e9  # its gap long over
	_quiet_now()
	_face(devil.global_position)
	await frames(3)
	check(audio._motif_at < 0.0, "only the first sight")
	audio._motif_at = audio._time


func _dusk() -> void:
	var cam: Node3D = game.player.cam
	var c: Dictionary = cam.t
	c.glance_after = 1.0  # the waits, shortened for a test that runs at a few frames a second headless
	game._sky(game.SKIES.find("design.sunset"))
	await frames(3)
	var spawn: Dictionary = game.world.landmark("spawn")
	game.player.place(spawn.pos, spawn.yaw)
	await frames(10)
	check(audio._glance.size() >= 1, "the sunset sky gives the camera something to glance at")
	var hab: Vector3 = audio._glance[0]
	var toward := atan2(cam.global_position.x - hab.x, cam.global_position.z - hab.z)
	cam.yaw = toward + deg_to_rad(25.0)
	cam.look(0.0, 0.0)
	var yaw0: float = cam.yaw
	var pitch0: float = cam.pitch
	# the player keeps looking (a held look input resets the idle clock every frame): nothing moves
	for i in int(60 * (float(c.glance_after) + 2.0)):
		cam.look(0.0, 0.0)
		await frames(1)
	check(cam.yaw == yaw0, "never while the player is looking")
	# left alone: it turns toward the habitat, slowly, a few degrees at most, yaw only
	var fastest := 0.0
	var before: float = cam.yaw
	for i in int(60 * (float(c.glance_after) + float(c.glance_max_deg) / float(c.glance_deg_s) + 2.0)):
		await frames(1)
		fastest = maxf(fastest, absf(cam.yaw - before))
		before = cam.yaw
	var turned := rad_to_deg(yaw0 - cam.yaw)
	check(turned > 1.0 and turned <= float(c.glance_max_deg) + 0.01, "left alone it turns toward the base (%.2f deg, at most %s)" % [turned, c.glance_max_deg])
	check(rad_to_deg(fastest) * 60.0 <= float(c.glance_deg_s) + 0.01, "slowly, never a cut (%.2f deg/s)" % (rad_to_deg(fastest) * 60.0))
	check(cam.pitch == pitch0, "and never pitches")
	# a look takes over at once, and the wait starts again
	cam.look(0.0, 0.0)
	var held: float = cam.yaw
	await frames(int(60 * float(c.glance_after) * 0.9))
	check(cam.yaw == held, "after a look it lets go for %s s" % c.glance_after)
	# the day sky: nothing to glance at
	game._sky(game.SKIES.find("design"))
	await frames(3)
	cam.look(0.0, 0.0)
	held = cam.yaw
	await frames(int(60 * (float(c.glance_after) + 3.0)))
	check(audio._glance.is_empty() and cam.yaw == held, "only in the sunset sky")
	# driving: none either
	game._sky(game.SKIES.find("design.sunset"))
	game.player.enter(game.world.items.rover)
	await frames(3)
	check(audio._glance.is_empty(), "never while driving")
	game.player.exit()


## No cue, no event sound, no radio within its gap.
func _quiet_now() -> void:
	audio._cue_end = -1e9
	audio._busy_until = -1e9
	audio.radio_last = -1e9


func _face(at: Vector3) -> void:
	var cam: Node3D = game.player.cam
	cam.yaw = atan2(cam.global_position.x - at.x, cam.global_position.z - at.z)
	cam.look(0.0, 0.0)
