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


## Damage being done: grinding, crackling noise.
static func crunch() -> AudioStreamWAV:
	var low := _LowPass.new(900.0)
	return _make(0.55, func(t: float, rng: RandomNumberGenerator) -> float:
		var crackle: float = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.08 else 0.0
		return (low.run(rng.randf_range(-1.0, 1.0)) * 1.4 + crackle * 0.5) * exp(-t / 0.18) * 0.8)


## A gentle bump, heard through the hull: a hollow metal knock.
static func knock() -> AudioStreamWAV:
	var low := _LowPass.new(600.0)
	var rings: Array[_Ring] = [_Ring.new(95.0, 0.1, 1.0), _Ring.new(180.0, 0.06, 0.5), _Ring.new(263.0, 0.05, 0.35), _Ring.new(410.0, 0.03, 0.2)]
	return _peaked(0.45, 0.6, func(t: float, rng: RandomNumberGenerator) -> float:
		var strike: float = low.run(rng.randf_range(-1.0, 1.0)) * exp(-t / 0.004) if t < 0.03 else 0.0
		var total: float = sin(TAU * 70.0 * t) * exp(-t / 0.03) * 0.3
		for ring: _Ring in rings:
			total += ring.run(strike)
		return total)


## The frame straining after a hard hit: a low groan with creaks in it, as the metal slips and sticks.
static func groan() -> AudioStreamWAV:
	var low := _LowPass.new(300.0)
	var creaks: Array[_Ring] = [_Ring.new(420.0, 0.025, 1.0), _Ring.new(610.0, 0.02, 0.7), _Ring.new(890.0, 0.015, 0.4)]
	var state := {"slip": 0.0, "phase": 0.0}
	return _peaked(1.6, 0.45, func(t: float, rng: RandomNumberGenerator) -> float:
		var swell: float = minf(t / 0.25, 1.0) * clampf((1.6 - t) / 1.1, 0.0, 1.0)
		# The groan: a rough tone sliding down as the frame gives.
		state["phase"] += lerpf(58.0, 44.0, t / 1.6) / RATE
		var rough: float = fmod(state["phase"], 1.0) * 2.0 - 1.0 + fmod(state["phase"] * 1.007, 1.0) - 0.5
		var tone: float = low.run(rough) * 1.5
		# The creaks: the metal catching and slipping, at a rate that wanders.
		state["slip"] += (14.0 + 10.0 * sin(TAU * t * 0.9) + rng.randf_range(-6.0, 6.0)) / RATE
		var pulse: float = 0.0
		if state["slip"] >= 1.0:
			state["slip"] -= 1.0
			pulse = rng.randf_range(0.5, 1.0)
		var creak: float = 0.0
		for ring: _Ring in creaks:
			creak += ring.run(pulse)
		return (tone * 0.6 + creak * 0.5) * swell)


## A part breaking off: a sharp metal crack, ringing like a struck plate, with a thump under it.
static func crack() -> AudioStreamWAV:
	var tear := _LowPass.new(2500.0)
	var rings: Array[_Ring] = [_Ring.new(310.0, 0.18, 1.0), _Ring.new(742.0, 0.12, 0.7), _Ring.new(1210.0, 0.09, 0.5), _Ring.new(1873.0, 0.06, 0.35), _Ring.new(2650.0, 0.04, 0.25)]
	return _peaked(0.6, 0.9, func(t: float, rng: RandomNumberGenerator) -> float:
		var burst: float = rng.randf_range(-1.0, 1.0) * exp(-t / 0.002) if t < 0.02 else 0.0
		var total: float = burst * 0.8 + sin(TAU * 60.0 * t) * exp(-t / 0.06) * 0.6
		for ring: _Ring in rings:
			total += ring.run(burst)
		var tearing: float = tear.run(rng.randf_range(-1.0, 1.0)) if rng.randf() < 0.3 else 0.0
		return total + tearing * exp(-t / 0.05) * 0.7)


## Debris rattling against the hull after something breaks: small pieces tinking, fewer and softer.
static func debris() -> AudioStreamWAV:
	var plan := RandomNumberGenerator.new()
	plan.seed = 5
	var hits: Array[Dictionary] = []
	for i in range(13):
		var at: float = 0.9 * pow(plan.randf(), 1.8)
		hits.append({"at": at, "loud": (1.0 - at) * plan.randf_range(0.4, 1.0), "pitch": plan.randf_range(900.0, 2600.0), "ring": plan.randf_range(0.02, 0.05)})
	return _peaked(1.0, 0.5, func(t: float, rng: RandomNumberGenerator) -> float:
		var total: float = 0.0
		for hit: Dictionary in hits:
			var u: float = t - hit["at"]
			if u >= 0.0 and u < 0.15:
				total += sin(TAU * hit["pitch"] * u) * exp(-u / hit["ring"]) * hit["loud"]
				if u < 0.002:
					total += rng.randf_range(-1.0, 1.0) * hit["loud"] * 0.5
		return total)


## The ship lost: the heaviest hit there is, a deep boom with the hull crushing and ringing in it.
static func impact() -> AudioStreamWAV:
	var body := _LowPass.new(250.0)
	var crush := _LowPass.new(1200.0)
	var settle := _LowPass.new(120.0)
	var rings: Array[_Ring] = [_Ring.new(180.0, 0.4, 1.0), _Ring.new(433.0, 0.3, 0.6), _Ring.new(720.0, 0.2, 0.4)]
	var state := {"phase": 0.0}
	return _peaked(1.8, 1.0, func(t: float, rng: RandomNumberGenerator) -> float:
		state["phase"] += lerpf(48.0, 28.0, minf(t / 0.8, 1.0)) / RATE
		var boom: float = sin(TAU * state["phase"]) * exp(-t / 0.45) * 1.2
		var noise: float = rng.randf_range(-1.0, 1.0)
		var burst: float = noise * exp(-t / 0.003) if t < 0.02 else 0.0
		var crackle: float = noise if rng.randf() < 0.06 else 0.0
		var total: float = boom + body.run(noise) * exp(-t / 0.25) * 3.0
		total += (crush.run(noise) * 1.5 + crackle * 0.4) * exp(-t / 0.3)
		total += settle.run(noise) * exp(-t / 0.9) * 2.0
		for ring: _Ring in rings:
			total += ring.run(burst) * 0.5
		return total)


## The radio after the ship's lost: static, fading out.
static func radio_static() -> AudioStreamWAV:
	var high := _LowPass.new(3200.0)
	var low := _LowPass.new(350.0)
	return _peaked(2.6, 0.35, func(t: float, rng: RandomNumberGenerator) -> float:
		var noise: float = rng.randf_range(-1.0, 1.0)
		var band: float = high.run(noise) - low.run(noise)
		var pop: float = rng.randf_range(-1.0, 1.0) if rng.randf() < 0.004 else 0.0
		return (band + pop * 0.6) * clampf((2.6 - t) / 1.4, 0.0, 1.0))


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


## Air rushing past: a soft, dark whoosh that swells and eases in gusts. Three filters in a row leave
## nothing bright in it, so it never sounds like static, and each gust opens them a little.
static func wind() -> AudioStreamWAV:
	var stages: Array[_LowPass] = [_LowPass.new(400.0), _LowPass.new(400.0), _LowPass.new(400.0)]
	return _loop(8.0, func(t: float, rng: RandomNumberGenerator) -> float:
		# Slow swells that repeat with the loop, so it stays seamless, from 0 to 1.
		var gust: float = 0.5 + 0.5 * (0.6 * sin(TAU * t / 8.0) + 0.4 * sin(TAU * t / 2.0 + 1.3) * sin(TAU * t / 4.0))
		var value: float = rng.randf_range(-1.0, 1.0)
		for stage: _LowPass in stages:
			stage.set_cutoff(lerpf(220.0, 520.0, gust))
			value = stage.run(value)
		return value * 2.2 * lerpf(0.55, 1.0, gust))


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
	return _wav(_samples(seconds, sample), false)


# A one-shot scaled so its loudest moment is this loud, so a sound can be shaped first and leveled after.
static func _peaked(seconds: float, peak: float, sample: Callable) -> AudioStreamWAV:
	var samples: PackedFloat32Array = _samples(seconds, sample)
	var loudest: float = 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	if loudest > 0.0:
		for i in range(samples.size()):
			samples[i] *= peak / loudest
	return _wav(samples, false)


static func _samples(seconds: float, sample: Callable) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var count: int = ceili(seconds * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		samples[i] = sample.call(float(i) / RATE, rng)
	return samples


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
		set_cutoff(cutoff)

	func set_cutoff(cutoff: float) -> void:
		_share = 1.0 - exp(-TAU * cutoff / RATE)

	func run(input: float) -> float:
		_value += _share * (input - _value)
		return _value


# A resonance, like a struck piece of metal ringing at one pitch: a kick sets it ringing, and it dies
# away over about this many seconds. Each is weighted so high and low rings start equally loud.
class _Ring:
	var _a1: float = 0.0
	var _a2: float = 0.0
	var _scale: float = 0.0
	var _y1: float = 0.0
	var _y2: float = 0.0

	func _init(frequency: float, ring_seconds: float, weight: float) -> void:
		var r: float = exp(-1.0 / (ring_seconds * RATE))
		var w: float = TAU * frequency / RATE
		_a1 = 2.0 * r * cos(w)
		_a2 = r * r
		_scale = sin(w) * weight

	func run(input: float) -> float:
		var y: float = _a1 * _y1 - _a2 * _y2 + input * _scale
		_y2 = _y1
		_y1 = y
		return y
