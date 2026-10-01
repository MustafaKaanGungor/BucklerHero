extends AudioStreamPlayer

## Plays a short, punchy thud whenever the player loses health (HealthManager.damaged).
## Hits the shield blocks don't play it. Bigger hits are louder and a little deeper.
## The project has no audio files, so the sound is synthesized once in code.

@export_group("Hit Sound")
## Volume of the weakest hit, in decibels.
@export var min_volume_db: float = -12.0
## Volume of a hit of damage_for_full_volume or more.
@export var max_volume_db: float = -3.0
## Damage that plays at max_volume_db.
@export var damage_for_full_volume: float = 25.0
## Pitch of the weakest hit; the biggest hits play at 1.0 minus pitch_drop.
@export var base_pitch: float = 1.05
## How much lower the biggest hits sound.
@export_range(0.0, 0.5) var pitch_drop: float = 0.2
## Random pitch change per hit, so repeated hits don't sound identical.
@export_range(0.0, 0.5) var pitch_variation: float = 0.05


func _ready() -> void:
	stream = _build_hit_sound()
	HealthManager.damaged.connect(_on_player_damaged)


func _on_player_damaged(amount: float) -> void:
	var ratio: float = clampf(amount / maxf(damage_for_full_volume, 0.001), 0.0, 1.0)
	volume_db = lerpf(min_volume_db, max_volume_db, ratio)
	pitch_scale = maxf(base_pitch - pitch_drop * ratio + randf_range(-pitch_variation, pitch_variation), 0.1)
	play()


## A low body thump (sine sweeping 150 -> 55 Hz) with a short, darkened noise crack on top.
func _build_hit_sound() -> AudioStreamWAV:
	var mix_rate: int = 44100
	var length: float = 0.3
	var sample_count: int = int(length * float(mix_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var noise_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	noise_rng.seed = 1337
	var phase: float = 0.0
	var filtered_noise: float = 0.0
	for sample in range(sample_count):
		var time: float = float(sample) / float(mix_rate)
		var frequency: float = 55.0 + 95.0 * exp(-time * 22.0)
		phase += TAU * frequency / float(mix_rate)
		var attack: float = minf(time / 0.003, 1.0)
		var body: float = sin(phase) * exp(-time * 11.0)
		# One-pole low-pass keeps the crack dull, like a blow rather than a hiss.
		filtered_noise = lerpf(filtered_noise, noise_rng.randf_range(-1.0, 1.0), 0.35)
		var crack: float = filtered_noise * exp(-time * 45.0)
		var value: float = attack * (body * 0.85 + crack * 0.6)
		value *= clampf((length - time) / 0.04, 0.0, 1.0)
		data.encode_s16(sample * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = mix_rate
	sound.stereo = false
	sound.data = data
	return sound
