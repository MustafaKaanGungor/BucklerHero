extends Node

## Sounds for the melee weapons. Child of MeleeWeapons (melee_weapons.tscn) and driven purely by
## its signals, so the weapon code has no audio in it.
## Swings (attack_started): a whoosh per weapon. Hits (attack_hit): a slash for the sword, a heavy
## stab for the halberd, a blunt thump for the shield (bash and charge knock-aways). Shield charge:
## a whoosh when it starts, a thump when an enemy is picked up, a crunch when enemies are crushed,
## and a heavy slam for wall / heavy-enemy impacts and for a full shield stopping the charge.
## All sounds are synthesized once in _ready (sound_synth.gd).

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")
## Must match the ids in melee_weapons.gd.
const WEAPON_BROADSWORD: StringName = &"broadsword"
const WEAPON_HALBERD: StringName = &"halberd"
const WEAPON_SHIELD: StringName = &"shield"

@export_group("Volume")
## Volume of the swing whooshes, in decibels.
@export var swing_volume_db: float = -9.0
## Volume of weapon hits.
@export var hit_volume_db: float = -5.0
## Volume of the shield-charge crunch and impact slam.
@export var impact_volume_db: float = -2.0
## Random pitch change per sound, so repeats don't sound identical.
@export_range(0.0, 0.5) var pitch_variation: float = 0.06

var _weapons: Node
var _players: Dictionary = {}
var _last_carry_count: int = 0


func _ready() -> void:
	_weapons = get_parent()
	_add_sound(&"swing_broadsword", SoundSynth.whoosh(0.26, 700.0, 2600.0, 1100.0, 0.45, 2.2, 11), swing_volume_db)
	_add_sound(&"swing_halberd", SoundSynth.whoosh(0.3, 380.0, 1500.0, 600.0, 0.35, 2.6, 12), swing_volume_db + 1.0)
	_add_sound(&"swing_shield", SoundSynth.whoosh(0.2, 260.0, 900.0, 400.0, 0.4, 1.8, 13), swing_volume_db)
	_add_sound(&"charge_start", SoundSynth.whoosh(0.45, 200.0, 700.0, 300.0, 0.3, 1.6, 14), swing_volume_db + 2.0)

	# Sword: a bright slash on top of a light thwack.
	var slash: PackedFloat32Array = SoundSynth.thud(0.16, 260.0, 120.0, 30.0, 1.4, 38.0, 0.85, 21)
	slash = SoundSynth.mix(slash, SoundSynth.whoosh(0.09, 2400.0, 4200.0, 2800.0, 0.15, 3.0, 22), 0.8)
	_add_sound(&"hit_broadsword", slash, hit_volume_db)
	_add_sound(&"hit_halberd", SoundSynth.thud(0.22, 200.0, 75.0, 18.0, 1.0, 30.0, 0.5, 23), hit_volume_db + 1.0)
	_add_sound(&"hit_shield", SoundSynth.thud(0.25, 150.0, 55.0, 14.0, 0.9, 26.0, 0.35, 24), hit_volume_db + 1.0)

	_add_sound(&"carry", SoundSynth.thud(0.18, 120.0, 60.0, 20.0, 0.5, 30.0, 0.3, 31), hit_volume_db - 5.0)
	# Crush: a deep slam with two quick cracks right after it.
	var crunch: PackedFloat32Array = SoundSynth.thud(0.45, 110.0, 40.0, 8.0, 1.2, 9.0, 0.6, 32)
	crunch = SoundSynth.mix(crunch, SoundSynth.thud(0.2, 300.0, 120.0, 30.0, 1.5, 40.0, 0.9, 33), 0.7, 0.03)
	crunch = SoundSynth.mix(crunch, SoundSynth.thud(0.2, 260.0, 100.0, 30.0, 1.5, 40.0, 0.8, 34), 0.6, 0.07)
	_add_sound(&"crush", crunch, impact_volume_db)
	_add_sound(&"impact", SoundSynth.thud(0.4, 95.0, 38.0, 9.0, 1.0, 18.0, 0.4, 35), impact_volume_db)

	_weapons.connect(&"attack_started", _on_attack_started)
	_weapons.connect(&"attack_hit", _on_attack_hit)
	_weapons.connect(&"shield_charge_started", _on_shield_charge_started)
	_weapons.connect(&"shield_carry_changed", _on_shield_carry_changed)
	_weapons.connect(&"shield_carry_crushed", _on_shield_carry_crushed)
	_weapons.connect(&"shield_charge_impact", _on_shield_charge_impact)
	_weapons.connect(&"shield_charge_blocked", _on_shield_charge_impact)


## Plays one of the sounds by name (see _ready), with an optional extra pitch factor.
func play_sound(sound_name: StringName, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(sound_name) as AudioStreamPlayer
	if player == null:
		return
	player.pitch_scale = maxf(pitch * (1.0 + randf_range(-pitch_variation, pitch_variation)), 0.1)
	player.play()


func _on_attack_started(weapon_id: StringName) -> void:
	play_sound(StringName("swing_%s" % weapon_id))


func _on_attack_hit(weapon_id: StringName, _hit_info: Dictionary) -> void:
	play_sound(StringName("hit_%s" % weapon_id))


func _on_shield_charge_started() -> void:
	_last_carry_count = 0
	play_sound(&"charge_start")


func _on_shield_carry_changed(carried_count: int) -> void:
	if carried_count > _last_carry_count:
		play_sound(&"carry", 1.0 + 0.08 * float(carried_count - 1))
	_last_carry_count = carried_count


func _on_shield_carry_crushed(_crushed_count: int) -> void:
	play_sound(&"crush")


func _on_shield_charge_impact() -> void:
	play_sound(&"impact")


func _add_sound(sound_name: StringName, samples: PackedFloat32Array, volume_db: float) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = String(sound_name)
	# Every sound is normalized; loudness is set only by volume_db.
	player.stream = SoundSynth.make_wav(SoundSynth.normalize(samples))
	player.volume_db = volume_db
	# Sword sweeps can hit several enemies in quick succession.
	player.max_polyphony = 4
	add_child(player)
	_players[sound_name] = player
