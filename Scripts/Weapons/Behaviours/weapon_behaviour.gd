extends Node3D

## Base for behaviour weapons. No live weapon uses it right now; the old ones (war hammer, sickle and
## dagger, morningstar, war axe, hatchets, hook, talons) are worked examples in OldWeapons/Scripts/
## (see OldWeapons.md). Attach a script that extends this to a weapon node under
## MeleeWeapons (melee_weapons.tscn); the node's transform is still the weapon's idle pose.
## melee_weapons.gd registers every child with this script on its own (weapon_id + attack_data),
## runs the shared parts (equip, click buffer, windup -> strike -> recover, hit rays, hit-stop,
## combo rule, signals) and calls the hooks below for everything special. All hooks are optional.
## `weapons` is the MeleeWeapons node; behaviours use its public services (deliver_hit, start_attack,
## find_aimed_enemy, add_screen_shake, spawn_in_world, ...).

## How a press of attack is read for this weapon.
enum PressMode {
	## Attack on press (sword, halberd, crossbow).
	PRESS,
	## A quick click attacks; holding past hold_time starts the hold move (shield, hook, talons).
	CLICK_OR_HOLD,
	## Only the hold move; a click does nothing (war hammer).
	HOLD_ONLY,
	## A click attacks; holding only does something while empowered at S rank (sickle and dagger).
	HOLD_WHEN_EMPOWERED,
}

@export_group("Weapon")
## Id used everywhere (loadout, keys, combo meter, sounds: swing_<id>, hit_<id>, empowered_<id>).
@export var weapon_id: StringName = &""
## Timing, hit area, damage and poses of the click attack.
@export var attack_data: MeleeAttackData
## How attack presses are read.
@export var press_mode: PressMode = PressMode.PRESS
## Seconds attack must be held before a hold move starts (CLICK_OR_HOLD, HOLD_WHEN_EMPOWERED).
@export var hold_time: float = 0.2
## False: the strike casts no hit rays (thrown weapons do their own hitting).
@export var uses_hit_rays: bool = true
## True: the click attack has an S-rank version, so at S it counts as empowered (glow sound,
## empowered_attack_started). False: clicks are always normal.
@export var empowered_click: bool = false
## Holding attack keeps attacking: a new click attack starts as soon as the weapon can attack again
## (only while no hold move is running or being waited for).
@export var repeat_while_held: bool = false

var weapons: Node


func get_press_mode() -> int:
	return press_mode


func get_hold_time() -> float:
	return 0.0 if press_mode == PressMode.HOLD_ONLY else maxf(hold_time, 0.0)


func uses_strike_rays() -> bool:
	return uses_hit_rays


func has_empowered_click() -> bool:
	return empowered_click


func repeats_while_held() -> bool:
	return repeat_while_held


## Called once by MeleeWeapons after registering the weapon.
func setup(owner_weapons: Node) -> void:
	weapons = owner_weapons


## False hides the weapon from keys, cycling and the selector (a thrown hatchet).
func is_available() -> bool:
	return true


## True while the weapon is doing something that must finish before any attack (a plunge slam).
func is_busy() -> bool:
	return false


## Multiplier on the player's move speed while this weapon is in hand. Below 1 also stops sprinting.
func get_move_speed_multiplier() -> float:
	return 1.0


func on_equipped() -> void:
	pass


## The weapon was put away (switched, holstered). Cancel anything in progress.
func on_unequipped() -> void:
	pass


## The hold move should start. Return false to refuse (nothing happens).
func on_hold_started() -> bool:
	return false


## Every physics tick while the hold move runs. Return false to end it early.
func on_hold_updated(_delta: float, _held_time: float) -> bool:
	return true


## Attack was released while the hold move ran.
func on_hold_released(_held_time: float) -> void:
	pass


## The hold move was interrupted (weapon switched, selector opened, death, climbing).
func on_hold_cancelled() -> void:
	pass


## The click attack reached its strike. empowered = started at S rank.
func on_strike_started(_attack: MeleeAttackData, _empowered: bool) -> void:
	pass


## Lets the weapon change a hit before it lands (damage bonuses, extra keys). Return the hit info.
func modify_hit(hit_info: Dictionary, _target: Node3D) -> Dictionary:
	return hit_info


## A hit landed on target. killed = the target died from it.
func on_hit_landed(_target: Node3D, _hit_info: Dictionary, _killed: bool) -> void:
	pass


## Extra viewmodel offset [position, rotation in radians] added on top of the attack pose.
func get_pose_offset() -> Array:
	return [Vector3.ZERO, Vector3.ZERO]


## Every physics tick while the weapon is registered, in hand or not (thrown hatchets keep flying).
func behaviour_physics_process(_delta: float) -> void:
	pass


## The run restarted or a new level was built: put everything back.
func reset_behaviour() -> void:
	pass


func is_equipped() -> bool:
	return weapons != null and StringName(weapons.call(&"get_equipped_weapon")) == weapon_id


func is_empowered() -> bool:
	return weapons != null and bool(weapons.call(&"is_empowered"))
