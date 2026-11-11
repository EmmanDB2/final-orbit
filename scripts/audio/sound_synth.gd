# sound_synth.gd: makes the game's sounds from code, so it has them with no sound files: clicks, ticks,
# and clunks for the cockpit's switches, a radio blip, warning tones, an alarm, a chime for getting
# paid, thuds and crunches for hitting things, and seamless loops of shaped noise for the engine, the
# RCS, the wind, re-entry, and the legs' motors. Any of them can be swapped for a recorded file in the
# sound set. From DESIGN.md, "Sound".
class_name SoundSynth

const RATE: int = 22050


static func click() -> AudioStreamWAV:
	return _make(0.03, func(t: float, rng: RandomNumberGenerator) -> float:
		return rng.randf_range(-1.0, 1.0) * exp(-t / 0.003) * 0.5 + sin(TAU * 2400.0 * t) * exp(-t / 0.006) * 0.35)


static func tick() -> AudioStreamWAV:
	return _make(0.015, func(t: float, _rng: RandomNumberGenerator) -> float:
		return sin(TAU * 3200.0 * t) * exp(-t / 0.002) * 0.3)


## A heavy switch, or a latch: a low knock with a click in it.
static func clunk() -> AudioStreamWAV:
	return _make(0.2, func(t: float, rng: RandomNumberGenerator) -> float:
		var knock: float = sin(TAU * 70.0 * t) * exp(-t / 0.05) * 0.7
		var snap: float = rng.randf_range(-1.0, 1.0) * exp(-t / 0.008) * 0.4
		var second: float = rng.randf_range(-1.0, 1.0) * exp(-maxf(t - 0.035, 0.0) / 0.006) * 0.25 if t > 0.035 else 0.0
		return knock + snap + second)


## A safety cover flipping up: a quick swish and a snap.
static func cover() -> AudioStreamWAV:
	return _make(0.09, func(t: float, rng: RandomNumberGenerator) -> float:
		var swish: float = rng.randf_range(-1.0, 1.0) * sin(PI * minf(t / 0.06, 1.0)) * 0.15
		var snap: float = rng.randf_range(-1.0, 1.0) * exp(-maxf(t - 0.06, 0.0) / 0.004) * 0.45 if t > 0.06 else 0.0
		return swish + snap)


## The radio: a burst of static, then a short beep.
static func blip() -> AudioStreamWAV:
	return _make(0.11, func(t: float, rng: RandomNumberGenerator) -> float:
		if t < 0.03:
			return rng.randf_range(-1.0, 1.0) * 0.18
		var u: float = t - 0.03
		return _soft_square(1400.0, u) * _envelope(u, 0.004, 0.07) * 0.22)


## Two falling tones, for a caution.
static func warning() -> AudioStreamWAV:
	return _make(0.3, func(t: float, _rng: RandomNumberGenerator) -> float:
		var tone: float = 880.0 if t < 0.15 else 660.0
		var u: float = fmod(t, 0.15)
		return _soft_square(tone, t) * _envelope(u, 0.005, 0.14) * 0.25)


## A faster, higher alarm, three times, for a crash or a lost ship.
static func alarm() -> AudioStreamWAV:
	return _make(0.6, func(t: float, _rng: RandomNumberGenerator) -> float:
		var u: float = fmod(t, 0.2)
		var tone: float = 1000.0 if u < 0.1 else 750.0
		return _soft_square(tone, t) * _envelope(fmod(u, 0.1), 0.004, 0.095) * 0.28)


## Three rising notes, for getting paid.
static func chime() -> AudioStreamWAV:
	return _make(0.7, func(t: float, _rng: RandomNumberGenerator) -> float:
		var total: float = 0.0
		var notes: Array[float] = [784.0, 988.0, 1175.0]
		for i in range(notes.size()):
			var start: float = i * 0.1
			if t >= start:
				total += sin(TAU * notes[i] * t) * exp(-(t - start) / 0.18) * 0.18
		return total)


## Touching down, felt through the hull.
static func thud() -> AudioStreamWAV:
	var low := _LowPass.new(300.0)
	return _make(0.45, func(t: float, rng: RandomNumberGenerator) -> float:
		return sin(TAU * 55.0 * t) * exp(-t / 0.12) * 0.7 + low.run(rng.randf_range(-1.0, 1.0)) * exp(-t / 0.05) * 0.8)


## Hitting something hard, or losing a part: grinding, crackling noise.
static func crunch() -> AudioStreamWAV:
	var low := _LowPass.new(900.0)
	return _make(0.55, func(t: float, rng: RandomNumberGenerator) -> float:
		var crackle: float = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.08 else 0.0
		return (low.run(rng.randf_range(-1.0, 1.0)) * 1.4 + crackle * 0.5) * exp(-t / 0.18) * 0.8)


## The engine through the hull: a deep, rolling rumble.
static func rumble() -> AudioStreamWAV:
	var low := _LowPass.new(160.0)
	var lower := _LowPass.new(60.0)
	return _loop(2.0, func(t: float, rng: RandomNumberGenerator) -> float:
		var noise: float = rng.randf_range(-1.0, 1.0)
		return low.run(noise) * 2.2 + lower.run(noise) * 3.0 + sin(TAU * 41.0 * t) * 0.12)


## Gas escaping: the RCS thrusters, or a jetpack.
static func hiss() -> AudioStreamWAV:
	var low := _LowPass.new(5000.0)
	return _loop(1.5, func(_t: float, rng: RandomNumberGenerator) -> float:
		return low.run(rng.randf_range(-1.0, 1.0)) * 0.45)


## Air rushing past, gusting.
static func wind() -> AudioStreamWAV:
	var low := _LowPass.new(700.0)
	return _loop(4.0, func(t: float, rng: RandomNumberGenerator) -> float:
		var gust: float = 0.75 + 0.25 * sin(TAU * t / 4.0) * sin(TAU * t / 2.0)
		return low.run(rng.randf_range(-1.0, 1.0)) * 1.6 * gust)


## Re-entry: a heavy, crackling roar.
static func roar() -> AudioStreamWAV:
	var low := _LowPass.new(400.0)
	return _loop(2.0, func(_t: float, rng: RandomNumberGenerator) -> float:
		var crackle: float = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.03 else 0.0
		return low.run(rng.randf_range(-1.0, 1.0)) * 2.0 + crackle * 0.3)


## The legs' motors while they move.
static func servo() -> AudioStreamWAV:
	return _loop(0.5, func(t: float, _rng: RandomNumberGenerator) -> float:
		var wobble: float = 1.0 + 0.03 * sin(TAU * 8.0 * t)
		return _soft_square(180.0 * wobble, t) * 0.1 + sin(TAU * 360.0 * t) * 0.04)


# A one-shot this many seconds long, from a function of time.
static func _make(seconds: float, sample: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count: int = ceili(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		samples[i] = sample.call(float(i) / RATE, rng)
	return _wav(samples, false)


# A seamless loop: made a little long, with the end faded into the start so it doesn't click.
static func _loop(seconds: float, sample: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var count: int = ceili(seconds * RATE)
	var fade: int = RATE / 20
	var samples := PackedFloat32Array()
	samples.resize(count + fade)
	for i in range(count + fade):
		samples[i] = sample.call(float(i % count) / RATE, rng)
	for i in range(fade):
		var share: float = float(i) / fade
		samples[i] = samples[i] * share + samples[count + i] * (1.0 - share)
	samples.resize(count)
	return _wav(samples, true)


# Godot plays the sample at the loop's end too, and on the phone reading past the end of a long sound
# crashes the game, so every sound carries one sample more than it plays: a loop's own first sample,
# so it stays seamless, or silence after a one-shot.
static func _wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var count: int = samples.size()
	samples.append(samples[0] if looping else 0.0)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav


# A square wave with its corners rounded off, so it beeps without buzzing.
static func _soft_square(frequency: float, t: float) -> float:
	var phase: float = TAU * frequency * t
	return sin(phase) + sin(phase * 3.0) / 3.0 + sin(phase * 5.0) / 5.0


static func _envelope(t: float, attack: float, length: float) -> float:
	if t < attack:
		return t / attack
	return clampf((length - t) / maxf(length - attack, 0.001), 0.0, 1.0)


# A one-pole low-pass filter that keeps its state between samples.
class _LowPass:
	var _share: float = 0.0
	var _value: float = 0.0

	func _init(cutoff: float) -> void:
		_share = 1.0 - exp(-TAU * cutoff / RATE)

	func run(input: float) -> float:
		_value += _share * (input - _value)
		return _value
