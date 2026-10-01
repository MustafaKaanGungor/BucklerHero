extends Node

## Style / combo meter (autoload ComboMeter). Points fill ranks D, C, B, A, S; the HUD
## (Scripts/UI/combo_meter_hud.gd) shows the rank and the progress inside it.
## Rules:
## - A melee hit on an enemy scores. If the attack uses a different weapon than the attack before it
##   (a combo), its first hit gives switch_hit_points and every further hit of that swing
##   extra_hit_points. Repeating the same weapon gives same_weapon_hit_points per hit, but only while
##   the meter is below rank C: spamming one weapon can't take you past D.
## - A shield charge counts as a shield attack for the "different weapon" rule.
## - While a shield charge carries at least one enemy, the meter is frozen (no drain).
## - A crush (enemies slammed into a wall) gives crush_points_per_enemy for each enemy crushed.
##   A charge that ends any other way (released, thrown off, a full shield) gives nothing.
## - Stunning a heavy enemy with a charge gives stun_points.
## - The meter drains after drain_delay seconds without scoring, faster at higher ranks.
## - Taking damage knocks the meter down damage_rank_drop ranks (blocked hits don't). Dying empties it.
## Finds the weapons (group player_melee) and the player (group player) on its own; they spawn later.

signal points_changed(points: float, rank: int)
signal rank_changed(rank: int, previous_rank: int)

const GROUP_PLAYER_MELEE: StringName = &"player_melee"
const GROUP_PLAYER: StringName = &"player"
const GROUP_ENEMIES: StringName = &"enemies"
const METHOD_IS_SHIELD_CHARGING: StringName = &"is_shield_charging"
## Must match WEAPON_SHIELD in melee_weapons.gd.
const WEAPON_SHIELD: StringName = &"shield"
## No rank: the meter is empty.
const RANK_NONE: int = -1
const RANK_LETTERS: Array[String] = ["D", "C", "B", "A", "S"]

@export_group("Ranks")
## Points needed for each rank, D to S. D is reached with the first point.
@export var rank_thresholds: Array[float] = [0.0, 100.0, 200.0, 300.0, 400.0]
## The meter can't go above this (the top of S).
@export var max_points: float = 500.0
## Word shown under each rank letter, D to S.
@export var rank_words: Array[String] = ["DECENT", "CRUEL", "BRUTAL", "ATROCIOUS", "SUPREME"]

@export_group("Weapon Hits")
## First enemy hit of an attack with a different weapon than the previous attack.
@export var switch_hit_points: float = 70.0
## Each further enemy hit of that same attack (a sword sweep through a group).
@export var extra_hit_points: float = 30.0
## Each enemy hit of an attack that repeats the previous attack's weapon.
@export var same_weapon_hit_points: float = 20.0
## Same-weapon hits only add points up to this (just below rank C), so one weapon tops out at D.
@export var same_weapon_cap: float = 99.0

@export_group("Shield Charge")
## Points for each enemy crushed against a wall.
@export var crush_points_per_enemy: float = 60.0
## Points for staggering a heavy enemy (brute, mortar) with a charge.
@export var stun_points: float = 40.0

@export_group("Drain")
## Seconds after the last points before the meter starts draining.
@export var drain_delay: float = 1.5
## Points lost per second at each rank, D to S.
@export var drain_per_second: Array[float] = [8.0, 12.0, 16.0, 22.0, 30.0]

@export_group("Damage")
## Ranks lost when the player takes damage. The meter drops to the bottom of the rank below.
@export var damage_rank_drop: int = 1

var _points: float = 0.0
var _rank: int = RANK_NONE
var _drain_timer: float = 0.0
var _weapons: Node
var _player: Node
var _last_weapon: StringName = &""
var _current_attack_weapon: StringName = &""
var _current_attack_is_switch: bool = false
var _current_attack_hits: int = 0
var _carried_count: int = 0


func _ready() -> void:
	HealthManager.damaged.connect(_on_player_damaged)
	HealthManager.died.connect(reset)


func _process(delta: float) -> void:
	_connect_weapons()
	if _points <= 0.0:
		return
	if is_frozen():
		return
	if _drain_timer > 0.0:
		_drain_timer = maxf(_drain_timer - delta, 0.0)
		return
	_set_points(_points - _get_drain_rate() * delta)


func get_points() -> float:
	return _points


## RANK_NONE (-1) when empty, else 0 (D) to 4 (S).
func get_rank() -> int:
	return _rank


func get_rank_letter(rank: int = -2) -> String:
	var index: int = _rank if rank == -2 else rank
	if index < 0 or index >= RANK_LETTERS.size():
		return ""
	return RANK_LETTERS[index]


func get_rank_word(rank: int = -2) -> String:
	var index: int = _rank if rank == -2 else rank
	if index < 0 or index >= rank_words.size():
		return ""
	return rank_words[index]


## 0..1 progress inside the current rank (S fills toward max_points).
func get_rank_progress() -> float:
	if _rank < 0:
		return 0.0
	var start: float = rank_thresholds[_rank]
	var end: float = max_points if _rank + 1 >= rank_thresholds.size() else rank_thresholds[_rank + 1]
	return clampf((_points - start) / maxf(end - start, 0.001), 0.0, 1.0)


## True while a shield charge carries an enemy: the meter doesn't drain.
func is_frozen() -> bool:
	return _carried_count > 0


func add_points(amount: float) -> void:
	if amount <= 0.0:
		return
	_drain_timer = maxf(drain_delay, 0.0)
	_set_points(_points + amount)


func reset() -> void:
	_drain_timer = 0.0
	_carried_count = 0
	_last_weapon = &""
	_current_attack_weapon = &""
	_set_points(0.0)


func _connect_weapons() -> void:
	if _weapons != null and is_instance_valid(_weapons):
		return
	_weapons = get_tree().get_first_node_in_group(GROUP_PLAYER_MELEE)
	if _weapons == null:
		return
	_weapons.connect(&"attack_started", _on_attack_started)
	_weapons.connect(&"attack_hit", _on_attack_hit)
	_weapons.connect(&"shield_charge_started", _on_shield_charge_started)
	_weapons.connect(&"shield_carry_changed", _on_shield_carry_changed)
	_weapons.connect(&"shield_carry_crushed", _on_shield_carry_crushed)
	_weapons.connect(&"shield_charge_stunned", _on_shield_charge_stunned)


func _on_attack_started(weapon_id: StringName) -> void:
	_begin_attack(weapon_id)


func _on_shield_charge_started() -> void:
	_begin_attack(WEAPON_SHIELD)


func _begin_attack(weapon_id: StringName) -> void:
	_current_attack_is_switch = _last_weapon != &"" and weapon_id != _last_weapon
	_current_attack_weapon = weapon_id
	_current_attack_hits = 0
	_last_weapon = weapon_id


func _on_attack_hit(_weapon_id: StringName, hit_info: Dictionary) -> void:
	# Shield-charge knock-aways score through crush / stun instead.
	if _is_player_charging():
		return
	var target: Node = hit_info.get("collider") as Node
	if target == null or not target.is_in_group(GROUP_ENEMIES):
		return

	_current_attack_hits += 1
	if _current_attack_is_switch:
		add_points(switch_hit_points if _current_attack_hits == 1 else extra_hit_points)
		return
	# Repeating a weapon only fills the meter up to the cap.
	var room: float = maxf(same_weapon_cap - _points, 0.0)
	if room > 0.0:
		add_points(minf(same_weapon_hit_points, room))
	else:
		# Still counts as activity, so the drain doesn't start while you keep hitting.
		_drain_timer = maxf(drain_delay, 0.0)


func _on_shield_carry_changed(carried_count: int) -> void:
	_carried_count = carried_count


func _on_shield_carry_crushed(crushed_count: int) -> void:
	_carried_count = 0
	add_points(crush_points_per_enemy * float(crushed_count))


func _on_shield_charge_stunned(_enemy: Node3D) -> void:
	add_points(stun_points)


func _on_player_damaged(_amount: float) -> void:
	if _rank < 0:
		return
	var new_rank: int = _rank - maxi(damage_rank_drop, 0)
	_drain_timer = 0.0
	if new_rank < 0:
		_set_points(0.0)
	else:
		# Just inside the lower rank, so D stays on screen rather than emptying.
		_set_points(rank_thresholds[new_rank] + 1.0)


func _is_player_charging() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(GROUP_PLAYER)
	if _player == null or not _player.has_method(METHOD_IS_SHIELD_CHARGING):
		return false
	return bool(_player.call(METHOD_IS_SHIELD_CHARGING))


func _get_drain_rate() -> float:
	if _rank < 0 or drain_per_second.is_empty():
		return 0.0
	return maxf(drain_per_second[mini(_rank, drain_per_second.size() - 1)], 0.0)


func _set_points(value: float) -> void:
	_points = clampf(value, 0.0, maxf(max_points, 0.0))
	var new_rank: int = RANK_NONE
	if _points > 0.0:
		for index in range(rank_thresholds.size()):
			if _points >= rank_thresholds[index]:
				new_rank = index
	if new_rank != _rank:
		var previous: int = _rank
		_rank = new_rank
		rank_changed.emit(_rank, previous)
	points_changed.emit(_points, _rank)
