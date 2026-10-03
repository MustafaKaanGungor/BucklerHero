extends Node

## Sounds for the melee weapons. Child of MeleeWeapons (melee_weapons.tscn) and driven purely by
## its signals, so the weapon code has no audio in it.
## Swings (attack_started): a whoosh per weapon. Hits (attack_hit): a slash for the sword, a heavy
## stab for the halberd, a blunt thump for the shield (bash and charge knock-aways). Shield charge:
## a whoosh when it starts, a thump when an enemy is picked up, a crunch when enemies are crushed,
## and a heavy slam for wall / heavy-enemy impacts and for a full shield stopping the charge.
## Empowered (S rank) moves (empowered_attack_started) add their own layer on top: a ringing slash
## for the sword wave, a deep rushing roar for the halberd's long dash, a rumble for the crushing charge.
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

	# Empowered moves.
	var wave: PackedFloat32Array = SoundSynth.whoosh(0.7, 1200.0, 4200.0, 1800.0, 0.2, 3.0, 41)
	wave = SoundSynth.mix(wave, SoundSynth.tone_sweep(0.6, 1320.0, 1760.0, 0.05, 11.0, 42), 0.35)
	wave = SoundSynth.mix(wave, SoundSynth.tone_sweep(0.6, 1980.0, 2640.0, 0.05, 13.0, 43), 0.2)
	_add_sound(&"empowered_broadsword", wave, swing_volume_db + 3.0)
	var lunge: PackedFloat32Array = SoundSynth.whoosh(0.6, 180.0, 900.0, 260.0, 0.25, 2.2, 44)
	lunge = SoundSynth.mix(lunge, SoundSynth.thud(0.3, 110.0, 50.0, 10.0, 0.8, 20.0, 0.4, 45), 0.8)
	_add_sound(&"empowered_halberd", lunge, swing_volume_db + 4.0)
	var rumble: PackedFloat32Array = SoundSynth.growl(0.9, 45.0, 0.9, 46)
	rumble = SoundSynth.mix(rumble, SoundSynth.whoosh(0.8, 150.0, 600.0, 250.0, 0.3, 1.5, 47), 0.8)
	_add_sound(&"empowered_shield", rumble, swing_volume_db + 4.0)

	# Crossbow: a string twang on firing, a wooden thunk on hits, a rising whine for the S-rank
	# explosive shot, and a dry click when the combo meter is empty.
	var twang: PackedFloat32Array = SoundSynth.tone_sweep(0.3, 190.0, 150.0, 0.01, 18.0, 81)
	twang = SoundSynth.mix(twang, SoundSynth.thud(0.12, 400.0, 180.0, 40.0, 1.4, 60.0, 0.85, 82), 0.8)
	twang = SoundSynth.mix(twang, SoundSynth.whoosh(0.18, 1200.0, 3500.0, 1800.0, 0.2, 2.0, 83), 0.5, 0.01)
	_add_sound(&"swing_crossbow", twang, swing_volume_db + 3.0)
	_add_sound(&"hit_crossbow", SoundSynth.thud(0.16, 260.0, 110.0, 26.0, 1.3, 40.0, 0.7, 84), hit_volume_db + 1.0)
	var whine: PackedFloat32Array = SoundSynth.tone_sweep(0.5, 600.0, 1800.0, 0.4, 14.0, 85)
	whine = SoundSynth.mix(whine, SoundSynth.whoosh(0.5, 400.0, 2500.0, 1500.0, 0.8, 1.6, 86), 0.7)
	_add_sound(&"empowered_crossbow", whine, swing_volume_db + 2.0)
	_add_sound(&"dry_crossbow", SoundSynth.thud(0.07, 900.0, 600.0, 70.0, 0.8, 90.0, 0.95, 87), swing_volume_db - 2.0)

	# War hammer: a heavy low swing (the slam's boom is played by the hammer itself), a deep crunch on
	# hits and a growl when an S-rank slam sends its quake.
	_add_sound(&"swing_war_hammer", SoundSynth.whoosh(0.32, 160.0, 700.0, 240.0, 0.5, 2.4, 91), swing_volume_db + 2.0)
	var crunch_hit: PackedFloat32Array = SoundSynth.thud(0.3, 140.0, 50.0, 12.0, 1.2, 22.0, 0.45, 92)
	crunch_hit = SoundSynth.mix(crunch_hit, SoundSynth.thud(0.12, 320.0, 150.0, 40.0, 1.4, 50.0, 0.8, 93), 0.5, 0.01)
	_add_sound(&"hit_war_hammer", crunch_hit, hit_volume_db)
	_add_sound(&"empowered_war_hammer", SoundSynth.growl(0.7, 50.0, 1.0, 94), swing_volume_db + 3.0)

	# Sickle and dagger: short bright flicks and a light, sharp cut; thrown daggers get a thin zip and
	# a small tick on hits.
	_add_sound(&"swing_sickle_dagger", SoundSynth.whoosh(0.14, 1400.0, 3800.0, 2000.0, 0.4, 2.6, 101), swing_volume_db - 1.0)
	var cut: PackedFloat32Array = SoundSynth.thud(0.1, 420.0, 220.0, 45.0, 1.6, 60.0, 0.9, 102)
	cut = SoundSynth.mix(cut, SoundSynth.whoosh(0.07, 3000.0, 5200.0, 3600.0, 0.15, 3.2, 103), 0.7)
	_add_sound(&"hit_sickle_dagger", cut, hit_volume_db - 1.0)
	_add_sound(&"swing_thrown_dagger", SoundSynth.whoosh(0.1, 2200.0, 5000.0, 3000.0, 0.3, 3.0, 104), swing_volume_db - 4.0)
	_add_sound(&"hit_thrown_dagger", SoundSynth.thud(0.08, 700.0, 380.0, 60.0, 1.4, 70.0, 0.95, 105), hit_volume_db - 4.0)

	# Morningstar: a long whirring swing, a heavy spiked smack, and a deep rush at S rank.
	var whirl: PackedFloat32Array = SoundSynth.whoosh(0.45, 220.0, 1100.0, 380.0, 0.55, 2.8, 111)
	whirl = SoundSynth.mix(whirl, SoundSynth.whoosh(0.3, 300.0, 1400.0, 500.0, 0.5, 2.8, 112), 0.6, 0.12)
	_add_sound(&"swing_morningstar", whirl, swing_volume_db + 1.0)
	var smack: PackedFloat32Array = SoundSynth.thud(0.3, 170.0, 60.0, 14.0, 1.5, 24.0, 0.7, 113)
	smack = SoundSynth.mix(smack, SoundSynth.thud(0.1, 900.0, 500.0, 60.0, 1.2, 80.0, 0.95, 114), 0.4)
	_add_sound(&"hit_morningstar", smack, hit_volume_db + 1.0)
	_add_sound(&"empowered_morningstar", SoundSynth.whoosh(0.6, 150.0, 800.0, 260.0, 0.3, 2.0, 115), swing_volume_db + 3.0)
	# War axe: a heavy chop and a meaty cleave; a bright ring at S rank.
	_add_sound(&"swing_war_axe", SoundSynth.whoosh(0.28, 400.0, 1700.0, 600.0, 0.45, 2.6, 121), swing_volume_db + 1.0)
	var cleave: PackedFloat32Array = SoundSynth.thud(0.22, 230.0, 90.0, 20.0, 1.6, 34.0, 0.75, 122)
	cleave = SoundSynth.mix(cleave, SoundSynth.whoosh(0.08, 2000.0, 3600.0, 2400.0, 0.15, 3.0, 123), 0.6)
	_add_sound(&"hit_war_axe", cleave, hit_volume_db + 1.0)
	_add_sound(&"empowered_war_axe", SoundSynth.tone_sweep(0.5, 660.0, 990.0, 0.03, 8.0, 124), swing_volume_db)

	# Hatchets: a spinning throw, a solid chop on hits, a thunk when one lands in the level, a pickup
	# clink, and a rising lock-on tone for the S-rank homing throw.
	for hatchet_id in ["hatchet", "returning_hatchet"]:
		var throw_sound: PackedFloat32Array = SoundSynth.whoosh(0.35, 500.0, 2000.0, 700.0, 0.3, 2.4, 131)
		throw_sound = SoundSynth.mix(throw_sound, SoundSynth.whoosh(0.2, 800.0, 2400.0, 900.0, 0.5, 2.4, 132), 0.5, 0.12)
		_add_sound(StringName("swing_%s" % hatchet_id), throw_sound, swing_volume_db + 1.0)
		var chop: PackedFloat32Array = SoundSynth.thud(0.22, 260.0, 100.0, 22.0, 1.6, 36.0, 0.8, 133)
		chop = SoundSynth.mix(chop, SoundSynth.whoosh(0.07, 2200.0, 3800.0, 2600.0, 0.15, 3.0, 134), 0.5)
		_add_sound(StringName("hit_%s" % hatchet_id), chop, hit_volume_db + 1.0)
		_add_sound(StringName("empowered_%s" % hatchet_id), SoundSynth.tone_sweep(0.35, 700.0, 1400.0, 0.03, 10.0, 135), swing_volume_db)
	_add_sound(&"land_hatchet", SoundSynth.thud(0.16, 300.0, 140.0, 30.0, 1.2, 40.0, 0.7, 136), hit_volume_db - 4.0)
	var clink: PackedFloat32Array = SoundSynth.tone_sweep(0.25, 1200.0, 1500.0, 0.01, 0.0, 137)
	clink = SoundSynth.mix(clink, SoundSynth.thud(0.08, 800.0, 500.0, 60.0, 0.8, 80.0, 0.9, 138), 0.6)
	_add_sound(&"pickup_hatchet", clink, swing_volume_db - 2.0)

	# Hook: a rattling chain throw, a metal bite on a catch, and a clank when the grapple latches.
	var chain: PackedFloat32Array = SoundSynth.whoosh(0.3, 900.0, 3000.0, 1400.0, 0.3, 2.0, 141)
	chain = SoundSynth.mix(chain, SoundSynth.growl(0.3, 160.0, 1.0, 142), 0.25)
	_add_sound(&"swing_hook", chain, swing_volume_db)
	var bite: PackedFloat32Array = SoundSynth.thud(0.16, 600.0, 260.0, 40.0, 1.3, 50.0, 0.9, 143)
	bite = SoundSynth.mix(bite, SoundSynth.tone_sweep(0.2, 1800.0, 1500.0, 0.005, 0.0, 144), 0.3)
	_add_sound(&"hit_hook", bite, hit_volume_db)
	var clank: PackedFloat32Array = SoundSynth.thud(0.2, 900.0, 500.0, 35.0, 1.0, 50.0, 0.95, 145)
	clank = SoundSynth.mix(clank, SoundSynth.tone_sweep(0.3, 2100.0, 1900.0, 0.005, 0.0, 146), 0.35)
	_add_sound(&"grapple_latch", clank, hit_volume_db - 2.0)

	# Talons: a quick triple scratch, a tearing rip on hits.
	var scratch: PackedFloat32Array = SoundSynth.whoosh(0.12, 1800.0, 4200.0, 2400.0, 0.4, 2.6, 151)
	scratch = SoundSynth.mix(scratch, SoundSynth.whoosh(0.1, 2000.0, 4600.0, 2600.0, 0.4, 2.6, 152), 0.6, 0.03)
	_add_sound(&"swing_talons", scratch, swing_volume_db - 1.0)
	var rip: PackedFloat32Array = SoundSynth.thud(0.14, 380.0, 180.0, 40.0, 1.8, 50.0, 0.95, 153)
	rip = SoundSynth.mix(rip, SoundSynth.whoosh(0.1, 2600.0, 5000.0, 3200.0, 0.2, 3.2, 154), 0.7)
	_add_sound(&"hit_talons", rip, hit_volume_db)

	_weapons.connect(&"attack_started", _on_attack_started)
	_weapons.connect(&"attack_hit", _on_attack_hit)
	_weapons.connect(&"shield_charge_started", _on_shield_charge_started)
	_weapons.connect(&"shield_carry_changed", _on_shield_carry_changed)
	_weapons.connect(&"shield_carry_crushed", _on_shield_carry_crushed)
	_weapons.connect(&"shield_charge_impact", _on_shield_charge_impact)
	_weapons.connect(&"shield_charge_blocked", _on_shield_charge_impact)
	_weapons.connect(&"empowered_attack_started", _on_empowered_attack_started)
	_weapons.connect(&"crossbow_dry_fired", play_sound.bind(&"dry_crossbow", 1.0))


## Plays one of the sounds by name (see _ready), with an optional extra pitch factor.
func play_sound(sound_name: StringName, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(sound_name) as AudioStreamPlayer
	if player == null:
		return
	player.pitch_scale = maxf(pitch * (1.0 + randf_range(-pitch_variation, pitch_variation)), 0.1)
	player.play()


func _on_empowered_attack_started(weapon_id: StringName) -> void:
	play_sound(StringName("empowered_%s" % weapon_id))


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
