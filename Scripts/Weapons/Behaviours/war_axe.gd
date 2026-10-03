extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## War axe: cleaver. A heavy diagonal cleave that does more damage the more an enemy is already
## hurt: damage × (1 + missing_health_share × wounded_bonus).
## S rank: the cleave does empowered_damage_multiplier more, and every kill with the axe heals the
## player heal_per_kill.

@export_group("Cleave")
## Extra damage at 100 % missing health (1 = double damage on an enemy with almost no health left).
@export var wounded_bonus: float = 1.0

@export_group("S Rank")
## Damage multiplier at S rank.
@export var empowered_damage_multiplier: float = 1.5
## Health given back for each kill with the axe at S rank.
@export var heal_per_kill: float = 10.0

var _kill_heals: int = 0


## How many S-rank kills have healed so far (for tests).
func get_kill_heal_count() -> int:
	return _kill_heals


func modify_hit(hit_info: Dictionary, target: Node3D) -> Dictionary:
	var damage: float = float(hit_info.get("damage", 0.0))
	if target != null and target.has_method(&"get_health"):
		var max_health: float = maxf(float(target.get(&"max_health")), 0.001)
		var missing: float = clampf(1.0 - float(target.call(&"get_health")) / max_health, 0.0, 1.0)
		damage *= 1.0 + missing * maxf(wounded_bonus, 0.0)
	if bool(weapons.call(&"is_attack_empowered")):
		damage *= maxf(empowered_damage_multiplier, 0.0)
		hit_info["empowered"] = true
	hit_info["damage"] = damage
	return hit_info


func on_hit_landed(_target: Node3D, hit_info: Dictionary, killed: bool) -> void:
	if killed and bool(hit_info.get("empowered", false)) and heal_per_kill > 0.0:
		_kill_heals += 1
		HealthManager.heal(heal_per_kill)
