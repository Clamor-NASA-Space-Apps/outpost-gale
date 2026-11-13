extends RefCounted
## The HUD's own cues, made in code once at load (no files to license; they play in a web build's Sample mode).
## The mood is calm and warm: soft sine tones with a few quiet overtones, slow attacks, long gentle tails and a faint
## echo for air; nothing square, nothing arcade. audio/audio.gd ui(name) plays them on the UI bus at its UI_SOUNDS level.
## Each recipe is a list of notes [start s, Hz, length s, loudness] or a whoosh.

const RATE := 22050
const ECHO_S := 0.09  # a faint copy this much later, so a tone sounds like a room, not a beep
const ECHO := 0.22
const RECIPES := {
	"objective_new": [[0.0, 523.25, 0.32, 0.5], [0.13, 783.99, 0.5, 0.5]],  # C5 then G5: a gentle rising chime
	"objective_done": [[0.0, 587.33, 0.3, 0.4], [0.12, 392.0, 0.9, 0.35], [0.12, 493.88, 0.9, 0.3], [0.12, 587.33, 0.9, 0.3]],  # D5 resolving on G major
	"task_tick": [[0.0, 1046.5, 0.12, 0.3]],
	"pip_open": [[0.0, -500.0, 0.14, 0.25]],  # a negative Hz glides up an octave: a soft open
	"mail": [[0.0, 987.77, 0.09, 0.3], [0.13, 1318.5, 0.11, 0.3]],  # B5, E6: a radio double tone
	"alert": [[0.0, 220.0, 0.45, 0.55], [0.0, 440.0, 0.45, 0.2]],  # a low, clear pulse
	"danger": [[0.0, 164.81, 0.25, 0.6], [0.0, 329.63, 0.25, 0.22], [0.3, 164.81, 0.35, 0.6], [0.3, 329.63, 0.35, 0.22]],
	"choice_open": [[0.0, 698.46, 0.4, 0.28], [0.0, 1046.5, 0.4, 0.12]],
	"choice_made": [[0.0, 659.25, 0.12, 0.35], [0.08, 987.77, 0.3, 0.35]],
	"ledger_open": [[0.0, 329.63, 0.5, 0.3], [0.05, 493.88, 0.45, 0.18]],
	"map_open": "up",
	"map_close": "down",
	"tick": [[0.0, 1567.98, 0.035, 0.12]],
	"select": [[0.0, 880.0, 0.14, 0.25], [0.0, 1318.5, 0.14, 0.1]],
}


static func build() -> Dictionary:
	var out := {}
	for n: String in RECIPES:
		out[n] = make(n)
	return out


static func make(n: String) -> AudioStreamWAV:
	var r: Variant = RECIPES[n]
	var s := PackedFloat32Array()
	if r is String:
		s = _whoosh(r == "up")
	else:
		var end := 0.0
		for note: Array in r:
			end = maxf(end, note[0] + note[2])
		s.resize(int((end + ECHO_S + 0.05) * RATE))
		for note: Array in r:
			_note(s, note[0], note[1], note[2], note[3])
	return _wav(_echo(s))


## A sine with a soft 12 ms attack, a quiet second and third partial, and an exponential tail.
static func _note(s: PackedFloat32Array, t0: float, hz: float, length: float, amp: float) -> void:
	var start := int(t0 * RATE)
	var n := int(length * RATE)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := absf(hz) * (1.0 + t / length if hz < 0.0 else 1.0)  # a glide up when hz is negative
		phase += TAU * f / RATE
		var env := minf(t / 0.012, 1.0) * exp(-4.0 * t / length)
		var v := sin(phase) + 0.18 * sin(phase * 2.0) + 0.06 * sin(phase * 3.0)
		if start + i < s.size():
			s[start + i] += v * env * amp * 0.6


## Air through a soft low-pass whose opening sweeps up (open) or down (close): a whoosh, 0.35 s.
static func _whoosh(up: bool) -> PackedFloat32Array:
	var n := int(0.35 * RATE)
	var s := PackedFloat32Array()
	s.resize(n + int((ECHO_S + 0.05) * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if up else 12  # the same whoosh every run
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var cut := lerpf(0.02, 0.18, t if up else 1.0 - t)
		y += cut * (rng.randf_range(-1.0, 1.0) - y)
		s[i] = y * sin(PI * t) * 1.6
	return s


static func _echo(s: PackedFloat32Array) -> PackedFloat32Array:
	var d := int(ECHO_S * RATE)
	for i in range(s.size() - 1, d - 1, -1):
		s[i] += s[i - d] * ECHO
	return s


static func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
