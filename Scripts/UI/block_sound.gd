extends AudioStreamPlayer

## Plays a metallic shield clang whenever the shield stops a hit (HealthManager.blocked).
## Bigger blocked hits are louder and a little lower. The sound is synthesized once in code
## (the project has no audio files): a few inharmonic partials like struck metal, plus a sharp
## noise tick for the impact.

@export_group("Block Sound")
## Volume of the weakest blocked hit, in decibels.
@export var min_volume_db: float = -10.0
## Volume of a blocked hit of damage_for_full_volume or more.
@export var max_volume_db: float = -2.0
## Blocked damage that plays at max_volume_db.
@export var damage_for_full_volume: float = 25.0
## Pitch of the weakest blocked hit; the biggest play at base_pitch minus pitch_drop.
@export var base_pitch: float = 1.05
## How much lower the biggest blocked hits sound.
@export_range(0.0, 0.5) var pitch_drop: float = 0.15
## Random pitch change per block, so repeated blocks don't sound identical.
@export_range(0.0, 0.5) var pitch_variation: float = 0.06

## Partial frequency (Hz), loudness and decay rate (per second) of the ring.
const PARTIALS: Array[Vector3] = [
	Vector3(523.0, 0.55, 7.0),
	Vector3(1307.0, 0.4, 10.0),
	Vector3(2149.0, 0.3, 14.0),
	Vector3(3473.0, 0.22, 20.0),
	Vector3(4912.0, 0.12, 28.0),
]


func _ready() -> void:
	stream = _build_clang_sound()
	HealthManager.blocked.connect(_on_player_blocked)


func _on_player_blocked(amount: float) -> void:
	var ratio: float = clampf(amount / maxf(damage_for_full_volume, 0.001), 0.0, 1.0)
	volume_db = lerpf(min_volume_db, max_volume_db, ratio)
	pitch_scale = maxf(base_pitch - pitch_drop * ratio + randf_range(-pitch_variation, pitch_variation), 0.1)
	play()


func _build_clang_sound() -> AudioStreamWAV:
	var mix_rate: int = 44100
	var length: float = 0.7
	var sample_count: int = int(length * float(mix_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var noise_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	noise_rng.seed = 4242
	for sample in range(sample_count):
		var time: float = float(sample) / float(mix_rate)
		var value: float = 0.0
		for partial in PARTIALS:
			# A slight downward pitch wobble at the start makes it sound struck rather than rung.
			var frequency: float = partial.x * (1.0 + 0.012 * exp(-time * 30.0))
			value += sin(TAU * frequency * time) * partial.y * exp(-time * partial.z)
		var tick: float = noise_rng.randf_range(-1.0, 1.0) * exp(-time * 120.0) * 0.5
		value = (value + tick) * minf(time / 0.0015, 1.0)
		value *= clampf((length - time) / 0.06, 0.0, 1.0)
		data.encode_s16(sample * 2, int(clampf(value * 0.8, -1.0, 1.0) * 32767.0))

	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = mix_rate
	sound.stereo = false
	sound.data = data
	return sound
