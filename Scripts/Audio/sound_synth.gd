extends RefCounted

## Tiny sound synthesizer. The project has no audio files, so gameplay sounds are generated in code
## once (when their player node starts) and kept as AudioStreamWAV.
## Every builder returns mono float samples in -1..1; make_wav() packs them into a 16-bit stream.
## Used by player_audio.gd and melee_audio.gd; preload it as a const.

const MIX_RATE: int = 44100


static func make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Air rushing past: noise through a resonant band-pass whose centre sweeps start -> peak -> end Hz.
## Loudness swells in and fades out, peaking at peak_at (0..1 of the length).
static func whoosh(length: float, start_hz: float, peak_hz: float, end_hz: float, peak_at: float, resonance: float, seed_value: int) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(length * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var low: float = 0.0
	var band: float = 0.0
	var damping: float = clampf(1.0 / maxf(resonance, 0.1), 0.05, 2.0)
	var peak: float = clampf(peak_at, 0.05, 0.95)
	for index in range(count):
		var progress: float = float(index) / float(maxi(count - 1, 1))
		var cutoff: float = 0.0
		var envelope: float = 0.0
		if progress < peak:
			var rise: float = progress / peak
			cutoff = lerpf(start_hz, peak_hz, rise)
			envelope = rise * rise
		else:
			var fall: float = (progress - peak) / (1.0 - peak)
			cutoff = lerpf(peak_hz, end_hz, fall)
			envelope = pow(1.0 - fall, 1.6)
		var f: float = 2.0 * sin(PI * minf(cutoff, float(MIX_RATE) * 0.2) / float(MIX_RATE))
		var noise: float = rng.randf_range(-1.0, 1.0)
		low += f * band
		var high: float = noise - low - damping * band
		band += f * high
		samples[index] = band * envelope * 1.6
	return samples


## A body blow: a sine that drops from start_hz to end_hz and dies away, with a muffled noise
## crack on top. crack_brightness 0..1 sets how bright (sharp) the crack is.
static func thud(length: float, start_hz: float, end_hz: float, body_decay: float, crack_amount: float, crack_decay: float, crack_brightness: float, seed_value: int) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(length * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var filtered: float = 0.0
	var smoothing: float = clampf(lerpf(0.08, 0.9, crack_brightness), 0.01, 1.0)
	for index in range(count):
		var time: float = float(index) / float(MIX_RATE)
		var frequency: float = end_hz + (start_hz - end_hz) * exp(-time * 25.0)
		phase += TAU * frequency / float(MIX_RATE)
		var body: float = sin(phase) * exp(-time * body_decay)
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), smoothing)
		var crack: float = filtered * exp(-time * crack_decay) * crack_amount
		var attack: float = minf(time / 0.002, 1.0)
		samples[index] = (body + crack) * attack * _tail(time, length, 0.03)
	return samples


## A rough, throaty growl: a buzzy tone (harmonics of base_hz) that rises slightly in pitch, with a
## fast flutter for roughness (0..1) and a breathy noise layer. Swells in and falls away.
static func growl(length: float, base_hz: float, roughness: float, seed_value: int) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(length * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var breath: float = 0.0
	for index in range(count):
		var time: float = float(index) / float(MIX_RATE)
		var progress: float = time / maxf(length, 0.001)
		var frequency: float = base_hz * (1.0 + 0.18 * sin(PI * progress))
		phase += TAU * frequency / float(MIX_RATE)
		var tone: float = 0.0
		for harmonic in range(1, 9):
			tone += sin(phase * float(harmonic)) / float(harmonic)
		var flutter: float = 1.0 - roughness * 0.5 * (1.0 + sin(TAU * 27.0 * time + rng.randf() * 0.6))
		breath = lerpf(breath, rng.randf_range(-1.0, 1.0), 0.25)
		var envelope: float = sin(PI * clampf(progress, 0.0, 1.0)) * minf(progress * 6.0, 1.0)
		samples[index] = (tone * 0.5 * flutter + breath * 0.35) * envelope
	return samples


## A tone gliding from start_hz to end_hz (exponential glide), with a little vibrato and a second
## harmonic. The volume follows rise (0..1 of the length spent fading in) and then fades out at the end.
static func tone_sweep(length: float, start_hz: float, end_hz: float, rise: float, vibrato_hz: float, seed_value: int) -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = int(length * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	for index in range(count):
		var time: float = float(index) / float(MIX_RATE)
		var progress: float = time / maxf(length, 0.001)
		var frequency: float = start_hz * pow(end_hz / maxf(start_hz, 1.0), progress)
		frequency *= 1.0 + 0.02 * sin(TAU * vibrato_hz * time)
		phase += TAU * frequency / float(MIX_RATE)
		var envelope: float = minf(progress / maxf(rise, 0.001), 1.0) * _tail(time, length, minf(0.05, length * 0.3))
		samples[index] = (sin(phase) + 0.3 * sin(phase * 2.0) + rng.randf_range(-0.04, 0.04)) * envelope
	return samples


## Plays a stream once at a world position on its own AudioStreamPlayer3D, which frees itself when
## done. For sounds that must outlive their source (an enemy that is freed as it dies, a projectile).
static func play_at(context: Node, stream: AudioStream, world_position: Vector3, volume_db: float, pitch: float, unit_size: float = 8.0) -> void:
	if context == null or not context.is_inside_tree() or stream == null:
		return
	var parent: Node = context.get_tree().current_scene
	if parent == null:
		parent = context.get_tree().root
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch, 0.1)
	player.unit_size = unit_size
	parent.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()


## Adds b into a (scaled), extending a if b is longer. Returns the result; packed arrays are
## copied when passed, so always use the return value (a = mix(a, b)).
static func mix(a: PackedFloat32Array, b: PackedFloat32Array, b_gain: float = 1.0, b_delay: float = 0.0) -> PackedFloat32Array:
	var offset: int = int(b_delay * float(MIX_RATE))
	if a.size() < b.size() + offset:
		a.resize(b.size() + offset)
	for index in range(b.size()):
		a[index + offset] += b[index] * b_gain
	return a


## Scales all samples so the loudest one sits at peak. Use the return value.
static func normalize(samples: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var loudest: float = 0.0
	for value in samples:
		loudest = maxf(loudest, absf(value))
	if loudest <= 0.0001:
		return samples
	var gain: float = peak / loudest
	for index in range(samples.size()):
		samples[index] *= gain
	return samples


static func _tail(time: float, length: float, fade: float) -> float:
	return clampf((length - time) / maxf(fade, 0.001), 0.0, 1.0)
