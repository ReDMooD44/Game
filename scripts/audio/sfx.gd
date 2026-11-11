class_name Sfx
extends RefCounted
## Every sound in the game is synthesised here at load time. No audio files
## ship with the project, so nothing has to be downloaded or licensed.
## Loops are generated with a whole number of cycles per buffer, which is what
## makes them seamless without a crossfade.

const RATE := 22050

# --- helpers ------------------------------------------------------------

static func _wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if looping:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

## Deterministic value noise: a plain randf() per sample buzzes at full
## bandwidth, which on a phone speaker is just hiss.
static func _noise(n: int, smooth: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		raw[i] = rng.randf_range(-1.0, 1.0)
	if smooth <= 1:
		return raw
	var out := PackedFloat32Array()
	out.resize(n)
	var acc := 0.0
	for i in n:
		acc = 0.0
		for k in smooth:
			acc += raw[(i + k) % n]
		out[i] = acc / smooth
	return out

static func _fade_edges(s: PackedFloat32Array, ms: int) -> PackedFloat32Array:
	var n := int(RATE * ms / 1000.0)
	for i in mini(n, s.size()):
		var f := float(i) / float(n)
		s[i] *= f
		s[s.size() - 1 - i] *= f
	return s

# --- loops --------------------------------------------------------------

## Turbine idle: a few harmonics of a low fundamental plus smoothed noise.
## Pitch is scaled at playback, so this only has to sound right at one speed.
static func engine_loop() -> AudioStreamWAV:
	var cycles := 24
	var n := RATE / 2                     # 0.5 s
	var s := PackedFloat32Array()
	s.resize(n)
	var hiss := _noise(n, 6, 1337)
	for i in n:
		var t := float(i) / float(n)
		var ph := TAU * cycles * t
		var v := sin(ph) * 0.45
		v += sin(ph * 2.0) * 0.22
		v += sin(ph * 3.0) * 0.12
		v += sin(ph * 5.0) * 0.06
		v += hiss[i] * 0.22
		s[i] = v * 0.55
	return _wav(s, true)

## Afterburner: broadband roar with a slow swell, layered over the engine.
static func burner_loop() -> AudioStreamWAV:
	var n := RATE / 2
	var s := PackedFloat32Array()
	s.resize(n)
	var rough := _noise(n, 3, 24601)
	var body := _noise(n, 12, 99)
	for i in n:
		var t := float(i) / float(n)
		var swell := 0.8 + 0.2 * sin(TAU * 2.0 * t)
		s[i] = (rough[i] * 0.55 + body[i] * 0.45) * swell * 0.7
	return _wav(s, true)

## Airflow: heavily smoothed noise, volume driven by speed at playback.
static func wind_loop() -> AudioStreamWAV:
	var n := RATE
	var s := _noise(n, 24, 7)
	for i in n:
		s[i] *= 0.9
	return _wav(s, true)

# --- one-shots ----------------------------------------------------------

## Checkpoint chime. `up` is the green "you gained" variant, down is the red one.
static func ding(up: bool) -> AudioStreamWAV:
	var n := int(RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	var f0 := 880.0 if up else 660.0
	var f1 := 1320.0 if up else 440.0
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-t * 11.0)
		var f: float = f0 if t < 0.06 else f1
		s[i] = (sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.2) * env * 0.8
	return _wav(_fade_edges(s, 4), false)

## Wall scrape: a short, bright noise burst with a fast decay.
static func scrape() -> AudioStreamWAV:
	var n := int(RATE * 0.35)
	var grit := _noise(n, 2, 4242)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-t * 9.0) * minf(1.0, t * 90.0)
		s[i] = grit[i] * env * 0.85
	return _wav(_fade_edges(s, 3), false)

## Countdown beep; the final one is higher and longer.
static func beep(final_beep: bool) -> AudioStreamWAV:
	var n := int(RATE * (0.45 if final_beep else 0.16))
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 1100.0 if final_beep else 700.0
	for i in n:
		var t := float(i) / float(RATE)
		var env := minf(1.0, t * 60.0) * exp(-t * (4.0 if final_beep else 9.0))
		s[i] = sin(TAU * f * t) * env * 0.7
	return _wav(_fade_edges(s, 4), false)

## Lap/medal flourish: a short rising triad.
static func fanfare() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in n:
		var t := float(i) / float(RATE)
		var step := clampi(int(t / 0.18), 0, notes.size() - 1)
		var local := t - step * 0.18
		var env := minf(1.0, local * 70.0) * exp(-local * 5.0)
		var f: float = notes[step]
		s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.18) * env * 0.6
	return _wav(_fade_edges(s, 5), false)

## Crash: a low thud with a bright crack on top and a long noisy tail.
static func boom() -> AudioStreamWAV:
	var n := int(RATE * 1.1)
	var rubble := _noise(n, 5, 909)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var crack := exp(-t * 26.0) * sin(TAU * 140.0 * t + sin(t * 60.0) * 3.0)
		var body := exp(-t * 3.4) * sin(TAU * 48.0 * t * (1.0 - t * 0.35))
		var tail := exp(-t * 2.6) * rubble[i]
		s[i] = clampf(crack * 0.5 + body * 0.6 + tail * 0.45, -1.0, 1.0) * 0.9
	return _wav(_fade_edges(s, 5), false)

## Eight-bar loop: a driving bass pulse under a simple minor arpeggio, with a
## noise tick for rhythm. Synthesised like everything else, so no music files.
static func music_loop() -> AudioStreamWAV:
	var bpm := 132.0
	var beat := 60.0 / bpm
	var bars := 4
	var length := beat * 4.0 * bars
	var n := int(RATE * length)
	var s := PackedFloat32Array()
	s.resize(n)
	var tick := _noise(n, 3, 5150)
	# A minor -> F -> C -> G, one chord per bar.
	var roots := [110.0, 87.31, 130.81, 98.0]
	var arp := [1.0, 1.2, 1.5, 2.0]
	for i in n:
		var t := float(i) / float(RATE)
		var bar := int(t / (beat * 4.0)) % bars
		var root: float = roots[bar]
		var beat_t := fmod(t, beat)
		var env := exp(-beat_t * 5.5)

		# bass: a plucked eighth on every beat
		var bass := sin(TAU * root * 0.5 * t) * env * 0.5
		bass += sin(TAU * root * t) * env * 0.18

		# arpeggio: a sixteenth-note figure climbing the chord
		var step := int(t / (beat * 0.5)) % arp.size()
		var a_t := fmod(t, beat * 0.5)
		var a_env := exp(-a_t * 11.0) * 0.22
		var note: float = root * 2.0 * arp[step]
		var lead := (sin(TAU * note * t) * 0.7 + sin(TAU * note * 2.0 * t) * 0.3) * a_env

		# hat on the offbeat
		var hat := 0.0
		if fmod(t + beat * 0.5, beat) < 0.04:
			hat = tick[i] * exp(-fmod(t + beat * 0.5, beat) * 70.0) * 0.18

		s[i] = clampf(bass + lead + hat, -1.0, 1.0) * 0.55
	# Whole bars at a fixed tempo, so the ends meet exactly.
	return _wav(s, true)

## UI tap.
static func click() -> AudioStreamWAV:
	var n := int(RATE * 0.07)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		s[i] = sin(TAU * 1600.0 * t) * exp(-t * 55.0) * 0.5
	return _wav(_fade_edges(s, 2), false)
