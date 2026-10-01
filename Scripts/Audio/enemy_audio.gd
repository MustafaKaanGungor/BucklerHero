extends Node3D

## Positional sounds for one enemy: the attack telegraph (windup), the attack itself (strike) and
## the death shatter, plus a push-off when the enemy jumps. Child node "Audio" in every enemy scene;
## driven only by the enemy's signals (melee_enemy.gd: attack_started, attack_struck,
## attack_cancelled, jumped; dummy_enemy.gd: died).
## profile picks the voice. Sounds are synthesized once per profile and shared by all enemies.
## The death sound plays on a detached one-shot player, because arena enemies free themselves
## the moment they die.

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")

enum Profile {
	DUMMY,
	GRUNT,
	RUNNER,
	BRUTE,
	THROWER,
	GUNNER,
	MORTAR,
}

@export_group("Voice")
## Which set of sounds this enemy uses.
@export var profile: Profile = Profile.GRUNT
## Volume of the windup telegraph, in decibels.
@export var windup_volume_db: float = -4.0
## Volume of the attack itself.
@export var strike_volume_db: float = -2.0
## Volume of the death shatter.
@export var death_volume_db: float = 0.0
## Volume of the jump push-off.
@export var jump_volume_db: float = -6.0
## Distance in metres at which the sounds play at their set volume; they get quieter further away.
@export var unit_size: float = 8.0
## Random pitch change per sound.
@export_range(0.0, 0.5) var pitch_variation: float = 0.07

## Profile -> {windup, strike, death} streams (null where a profile has no such sound).
static var _banks: Dictionary = {}

var _windup_player: AudioStreamPlayer3D
var _strike_player: AudioStreamPlayer3D
var _jump_player: AudioStreamPlayer3D
var _bank: Dictionary = {}


func _ready() -> void:
	_bank = _get_bank(profile)
	_windup_player = _add_player("Windup", _bank.get(&"windup") as AudioStream, windup_volume_db)
	_strike_player = _add_player("Strike", _bank.get(&"strike") as AudioStream, strike_volume_db)
	_jump_player = _add_player("Jump", _get_jump_sound(), jump_volume_db + float(_bank.get(&"death_volume", 0.0)))

	var enemy: Node = get_parent()
	if enemy.has_signal(&"attack_started"):
		enemy.connect(&"attack_started", _on_attack_started)
	if enemy.has_signal(&"attack_struck"):
		enemy.connect(&"attack_struck", _on_attack_struck)
	if enemy.has_signal(&"attack_cancelled"):
		enemy.connect(&"attack_cancelled", _on_attack_cancelled)
	if enemy.has_signal(&"jumped"):
		enemy.connect(&"jumped", _on_jumped)
	if enemy.has_signal(&"died"):
		enemy.connect(&"died", _on_died)


func _on_attack_started() -> void:
	_play(_windup_player)


func _on_attack_struck() -> void:
	# The gunner's charge hum stops the moment it fires.
	if profile == Profile.GUNNER:
		_windup_player.stop()
	_play(_strike_player)


func _on_attack_cancelled() -> void:
	_windup_player.stop()


## Bigger enemies thump deeper (same pitch factor as their death sound); higher jumps a bit louder.
func _on_jumped(obstacle_height: float) -> void:
	_jump_player.pitch_scale = float(_bank.get(&"death_pitch", 1.0)) * (1.0 + randf_range(-pitch_variation, pitch_variation))
	_jump_player.volume_db = jump_volume_db + float(_bank.get(&"death_volume", 0.0)) + clampf(obstacle_height - 1.0, -0.5, 1.5) * 2.0
	_jump_player.play()


func _on_died() -> void:
	_windup_player.stop()
	var pitch: float = float(_bank.get(&"death_pitch", 1.0)) * (1.0 + randf_range(-pitch_variation, pitch_variation))
	SoundSynth.play_at(self, _bank.get(&"death") as AudioStream, global_position + Vector3.UP, death_volume_db + float(_bank.get(&"death_volume", 0.0)), pitch, unit_size)


func _play(player: AudioStreamPlayer3D) -> void:
	if player.stream == null:
		return
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func _add_player(player_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.position = Vector3.UP * 1.2
	add_child(player)
	return player


static func _get_bank(for_profile: Profile) -> Dictionary:
	if _banks.has(for_profile):
		return _banks[for_profile]
	var bank: Dictionary = {}
	match for_profile:
		Profile.GRUNT:
			bank[&"windup"] = _wav(SoundSynth.growl(0.4, 95.0, 0.6, 101))
			bank[&"strike"] = _wav(SoundSynth.whoosh(0.22, 400.0, 1600.0, 600.0, 0.4, 2.0, 102))
		Profile.RUNNER:
			bank[&"windup"] = _wav(SoundSynth.growl(0.26, 150.0, 0.8, 111))
			bank[&"strike"] = _wav(SoundSynth.whoosh(0.16, 700.0, 2400.0, 1000.0, 0.4, 2.2, 112))
			bank[&"death_pitch"] = 1.3
			bank[&"death_volume"] = -3.0
		Profile.BRUTE:
			bank[&"windup"] = _wav(SoundSynth.growl(0.8, 58.0, 0.7, 121))
			bank[&"strike"] = _wav(SoundSynth.whoosh(0.35, 200.0, 900.0, 300.0, 0.35, 2.6, 122))
			bank[&"death_pitch"] = 0.7
			bank[&"death_volume"] = 3.0
		Profile.THROWER:
			bank[&"windup"] = _wav(SoundSynth.whoosh(0.3, 300.0, 700.0, 500.0, 0.85, 1.4, 131))
			bank[&"strike"] = _wav(SoundSynth.whoosh(0.2, 900.0, 2600.0, 1400.0, 0.25, 2.4, 132))
		Profile.GUNNER:
			# Rising hum over the aim time (1.1 s), then a zap.
			bank[&"windup"] = _wav(SoundSynth.tone_sweep(1.1, 220.0, 880.0, 0.7, 9.0, 141))
			var zap: PackedFloat32Array = SoundSynth.tone_sweep(0.2, 2200.0, 160.0, 0.02, 0.0, 142)
			zap = SoundSynth.mix(zap, SoundSynth.thud(0.12, 400.0, 200.0, 40.0, 1.2, 50.0, 0.95, 143), 0.6)
			bank[&"strike"] = _wav(zap)
		Profile.MORTAR:
			bank[&"windup"] = _wav(SoundSynth.thud(0.2, 220.0, 160.0, 25.0, 0.8, 60.0, 0.9, 151))
			var launch: PackedFloat32Array = SoundSynth.thud(0.45, 90.0, 40.0, 9.0, 1.3, 14.0, 0.4, 152)
			launch = SoundSynth.mix(launch, SoundSynth.whoosh(0.5, 200.0, 900.0, 500.0, 0.2, 1.4, 153), 0.5, 0.03)
			bank[&"strike"] = _wav(launch)
			bank[&"death_pitch"] = 0.72
			bank[&"death_volume"] = 3.0
	bank[&"death"] = _get_shatter()
	_banks[for_profile] = bank
	return bank


## A heavy push-off: a low thump with a short whoosh of air. Shared by every profile.
static func _get_jump_sound() -> AudioStream:
	if _banks.has(&"jump"):
		return _banks[&"jump"]
	var jump: PackedFloat32Array = SoundSynth.thud(0.16, 130.0, 70.0, 30.0, 0.9, 35.0, 0.45, 181)
	jump = SoundSynth.mix(jump, SoundSynth.whoosh(0.28, 250.0, 800.0, 350.0, 0.3, 1.4, 182), 0.7, 0.02)
	var stream: AudioStream = _wav(jump)
	_banks[&"jump"] = stream
	return stream


## Breaking apart: a low knock and a burst of bright cracks, shared by every profile (pitched per profile).
static func _get_shatter() -> AudioStream:
	if _banks.has(&"shatter"):
		return _banks[&"shatter"]
	var shatter: PackedFloat32Array = SoundSynth.thud(0.5, 140.0, 50.0, 12.0, 1.0, 16.0, 0.5, 161)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 162
	for crack in range(7):
		var crack_samples: PackedFloat32Array = SoundSynth.thud(0.12, rng.randf_range(300.0, 700.0), 200.0, 45.0, 1.6, rng.randf_range(35.0, 70.0), 0.9, 170 + crack)
		shatter = SoundSynth.mix(shatter, crack_samples, rng.randf_range(0.35, 0.8), rng.randf_range(0.0, 0.16))
	var stream: AudioStream = _wav(shatter)
	_banks[&"shatter"] = stream
	return stream


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	return SoundSynth.make_wav(SoundSynth.normalize(samples))
