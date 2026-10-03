extends Node3D

## First-person melee weapon holder.
## Lives under Head/Camera3D and owns one child node per melee weapon.
## Exactly one weapon is in hand at all times: the player starts with starting_weapon,
## and pressing the key of the weapon that is already out does nothing (it is not re-equipped).
## If a pistol node exists at pistol_path it is holstered while a melee weapon is out;
## the pistol is currently not part of the player scene.
## Each weapon's idle pose is its own transform in the scene, so poses are tuned in the editor.
## Equipping plays a short rise from a lowered pose into that idle pose.
## Attacking: a click starts the equipped weapon's attack (one MeleeAttackData per weapon).
## Combos: every weapon has a long recover after its strike and can't attack again until it is over.
## Attacking with a different weapon than the last one resets the recover of all the others,
## so alternating weapons is fast and repeating one weapon is slow.
## The attack plays windup -> strike -> recover on the viewmodel, and while the strike is active
## it hits objects inside its hit area: anything that implements on_melee_hit(hit_info),
## plus RigidBody3D objects, which get pushed.
## Shield only: a quick click is the bash, holding attack braces the shield and starts a charge.
## Weapons added later (war hammer, sickle and dagger, morningstar, war axe, hatchets, hook, talons)
## are child nodes with a script extending Scripts/Weapons/Behaviours/weapon_behaviour.gd. They are
## registered on their own and get hooks for holds, strikes and hits (see that script). How a press
## is read (attack on press, click or hold, hold only, hold only at S) is their press mode; the shield
## uses the same click-or-hold path.
## The charge movement itself lives in player.gd; this script asks for it, holds the braced pose
## and knocks away whatever the shield runs into.
## Enemies (anything with start_shield_carry) are not knocked away: the charge picks them up,
## carries them in front of the shield, and crushes them if it then runs into a wall.

signal weapon_changed(weapon_id: StringName)
## The loadout (weapon_order) was set by set_loadout().
signal loadout_changed(weapon_ids: Array[StringName])
signal attack_started(weapon_id: StringName)
signal attack_hit(weapon_id: StringName, hit_info: Dictionary)
signal attack_finished(weapon_id: StringName)
## An attack with a different weapon cleared the recover of every other weapon.
signal recover_reset(attacking_weapon_id: StringName)
signal shield_charge_started
signal shield_charge_released
signal shield_carry_changed(carried_count: int)
signal shield_carry_crushed(crushed_count: int)
signal shield_charge_blocked
## A shield charge slammed into a heavy enemy and staggered it.
signal shield_charge_stunned(enemy: Node3D)
## An S-rank empowered move began: the sword's wave, the halberd's long dash or the crushing charge.
signal empowered_attack_started(weapon_id: StringName)
## The crossbow fired, spending the combo meter at this rank (0 D … 4 S); explosive at S.
signal crossbow_fired(rank: int, is_explosive: bool)
## The crossbow was triggered with an empty combo meter and didn't fire.
signal crossbow_dry_fired
## A weapon became usable or unusable (a hatchet thrown or picked up).
signal weapon_availability_changed(weapon_id: StringName, available: bool)
## An explosive bolt blew up.
signal crossbow_explosion(center: Vector3, radius: float, hit_count: int)
## The charge slammed into a wall or a heavy enemy and knocked the player back.
signal shield_charge_impact

## Other systems find the melee holder through this group.
const GROUP_PLAYER_MELEE: StringName = &"player_melee"

const WEAPON_NONE: StringName = &"none"
const WEAPON_BROADSWORD: StringName = &"broadsword"
const WEAPON_HALBERD: StringName = &"halberd"
const WEAPON_SHIELD: StringName = &"shield"
## Ranged weapon that spends the combo meter (see the Crossbow exports).
const WEAPON_CROSSBOW: StringName = &"crossbow"
## Behaviour weapons (ids come from their nodes; listed here for other scripts to match).
const WEAPON_WAR_HAMMER: StringName = &"war_hammer"
const WEAPON_SICKLE_DAGGER: StringName = &"sickle_dagger"
const WEAPON_MORNINGSTAR: StringName = &"morningstar"
const WEAPON_WAR_AXE: StringName = &"war_axe"
const WEAPON_HATCHET: StringName = &"hatchet"
const WEAPON_RETURNING_HATCHET: StringName = &"returning_hatchet"
const WEAPON_HOOK: StringName = &"hook"
const WEAPON_TALONS: StringName = &"talons"
## Press modes, matching weapon_behaviour.gd's PressMode.
const PRESS_ON_PRESS: int = 0
const PRESS_CLICK_OR_HOLD: int = 1
const PRESS_HOLD_ONLY: int = 2
const PRESS_HOLD_WHEN_EMPOWERED: int = 3
const METHOD_GET_PRESS_MODE: StringName = &"get_press_mode"
const METHOD_IS_DEAD: StringName = &"is_dead"

const METHOD_SET_HOLSTERED: StringName = &"set_holstered"
const METHOD_ON_MELEE_HIT: StringName = &"on_melee_hit"
const METHOD_APPLY_HIT_STOP: StringName = &"apply_hit_stop"
const METHOD_PAUSE_DASH: StringName = &"pause_dash"
const METHOD_ADD_SCREEN_SHAKE: StringName = &"add_screen_shake"
const METHOD_START_DASH: StringName = &"start_dash"
const METHOD_ADD_RECOIL_IMPULSE: StringName = &"add_recoil_impulse"
const METHOD_IS_CLIMBING: StringName = &"is_climbing"
const METHOD_IS_EDGE_HOLDING: StringName = &"is_edge_holding"
const METHOD_IS_EDGE_PULLING_OVER: StringName = &"is_edge_pulling_over"
const METHOD_START_SHIELD_CHARGE: StringName = &"start_shield_charge"
const METHOD_RELEASE_SHIELD_CHARGE: StringName = &"release_shield_charge"
const METHOD_IS_SHIELD_CHARGING: StringName = &"is_shield_charging"
const METHOD_GET_HORIZONTAL_SPEED: StringName = &"get_horizontal_speed"
const METHOD_STOP_SHIELD_CHARGE: StringName = &"stop_shield_charge"
const METHOD_GET_SHIELD_CHARGE_HEADING: StringName = &"get_shield_charge_heading"
const METHOD_GET_SHIELD_CHARGE_SPEED: StringName = &"get_shield_charge_speed"
const METHOD_CAN_BE_SHIELD_CARRIED: StringName = &"can_be_shield_carried"
const METHOD_IS_SHIELD_CHARGE_BLOCKER: StringName = &"is_shield_charge_blocker"
const METHOD_ON_SHIELD_CHARGE_IMPACT: StringName = &"on_shield_charge_impact"
const METHOD_START_SHIELD_CARRY: StringName = &"start_shield_carry"
const METHOD_END_SHIELD_CARRY: StringName = &"end_shield_carry"
const METHOD_ON_SHIELD_CRUSH: StringName = &"on_shield_crush"
const SwordWave = preload("res://Scripts/Weapons/sword_wave.gd")
const CrossbowBolt = preload("res://Scripts/Weapons/crossbow_bolt.gd")
## The weapon selector (weapon_wheel.gd) joins this group; attacks wait while it is open.
const GROUP_WEAPON_WHEEL: StringName = &"weapon_wheel"

@export_group("Nodes")
@export var player_path: NodePath = NodePath("../../..")
@export var broadsword_path: NodePath = NodePath("Broadsword")
@export var halberd_path: NodePath = NodePath("Halberd")
@export var shield_path: NodePath = NodePath("Shield")
@export var crossbow_path: NodePath = NodePath("Crossbow")
## Ranged weapon that is put away while a melee weapon is out.
@export var pistol_path: NodePath = NodePath("../Pistol")

@export_group("Equip")
## Weapon in hand when the player spawns: "broadsword", "halberd" or "shield".
@export var starting_weapon: StringName = WEAPON_BROADSWORD
## Order the next / previous weapon keys (Q, mouse wheel) step through. Wraps around.
@export var weapon_order: Array[StringName] = [WEAPON_BROADSWORD, WEAPON_HALBERD, WEAPON_SHIELD]
## Seconds the weapon takes to rise into its idle pose.
@export var equip_time: float = 0.18
## Offset from the idle pose where the rise starts. Negative Y is below the screen.
@export var equip_start_position: Vector3 = Vector3(0.04, -0.42, 0.10)
## Extra rotation at the start of the rise. -X tips the weapon forward, +Z rolls it left.
@export var equip_start_rotation_degrees: Vector3 = Vector3(-38.0, 0.0, 16.0)

@export_group("Attacks")
## Wide right-to-left sweep.
@export var broadsword_attack: MeleeAttackData
## Long, narrow thrust with a short forward dash.
@export var halberd_attack: MeleeAttackData
## Short bash with a very small hit area.
@export var shield_attack: MeleeAttackData
## Crossbow shot. Only its timing, poses, camera kick and loudness are used; the bolt does the hitting.
@export var crossbow_attack: MeleeAttackData
## A click this many seconds before the weapon is ready still attacks as soon as it can.
@export var attack_input_buffer: float = 0.15
## Physics layers attacks can hit. Matches the player's movement collision layer.
@export_flags_3d_physics var hit_collision_mask: int = 1
## Most hittable objects a single hit ray can pass through.
@export var max_pierce_per_ray: int = 4

@export_group("Shield Charge")
## Holding attack this long with the shield out starts a charge; letting go sooner is a bash.
@export var shield_hold_time: float = 0.2
## Hits dealt by the braced shield while charging. Only its hit area and effect are used.
@export var shield_charge_attack: MeleeAttackData
## Seconds before the charge can hit the same object again.
@export var shield_charge_rehit_interval: float = 0.35
## The charge only hits things while the player is at least this fast.
@export var shield_charge_min_hit_speed: float = 5.0
## Offset from the idle pose while the shield is braced in front.
@export var shield_brace_position: Vector3 = Vector3(-0.25, 0.05, -0.08)
## Rotation added to the idle pose while braced, turning the shield to face straight ahead.
@export var shield_brace_rotation_degrees: Vector3 = Vector3(12.0, 34.0, -6.0)
## How quickly the shield moves into and out of the braced pose.
@export var shield_brace_lerp_speed: float = 12.0
## Up-and-down shake of the braced shield at full charge speed.
@export var shield_brace_shake_amount: float = 0.008
## Shakes per second of the braced shield.
@export var shield_brace_shake_frequency: float = 5.0

@export_group("Shield Carry")
## Most enemies the charge can carry. Running into one more stops the charge without hurting anyone.
@export var shield_carry_max: int = 3
## How far in front of the player carried enemies are held.
@export var shield_carry_distance: float = 1.05
## Sideways gap between carried enemies.
@export var shield_carry_spacing: float = 0.75
## Speed, on top of the charge speed, at which a picked-up enemy is pulled into its place on the shield.
@export var shield_carry_snap_speed: float = 10.0
## Charging slower than this into a wall doesn't crush carried enemies.
@export var shield_crush_min_speed: float = 6.0
## A wall this close in front of the player crushes the carried enemies against it.
@export var shield_crush_wall_distance: float = 1.7
## Heights above the player's feet of the two rays that look for the wall. Both must hit,
## so steps and low ledges don't count as walls.
@export var shield_crush_ray_heights: Vector2 = Vector2(0.9, 1.5)
## Surfaces leaning further than this from vertical don't count as walls (0 = only upright, 1 = anything).
@export_range(0.0, 1.0) var shield_crush_max_wall_normal_y: float = 0.5
## Forward speed carried enemies are thrown at when the charge ends without hitting a wall.
@export var shield_release_forward_speed: float = 10.0
## Sideways speed that spreads released enemies apart.
@export var shield_release_spread_speed: float = 4.5
## Upward speed given to released enemies.
@export var shield_release_up_speed: float = 2.0
## Loudness added to the stealth meter when enemies are crushed against a wall.
@export var shield_crush_loudness: float = 45.0
## Camera kick when the charge slams into a wall with enemies on the shield.
@export var shield_crush_camera_kick_degrees: Vector3 = Vector3(3.0, 0.0, 0.0)
## Screen shake when enemies are crushed against a wall, from 0 (none) to 1 (strongest).
@export_range(0.0, 1.0) var shield_crush_screen_shake: float = 0.85
## Seconds everything freezes when enemies are crushed (hit-stop): crushed enemies stay pinned,
## the braced shield holds still, then they break and the player bounces off. 0 disables it.
@export var shield_crush_hit_stop_time: float = 0.2

@export_group("Shield Impact")
## A charge with nothing on the shield slams into a wall this close in front of the player.
@export var shield_wall_impact_distance: float = 0.95
## Charging slower than this into a wall just pushes against it, with no impact.
@export var shield_wall_impact_min_speed: float = 6.0
## Meters the player is thrown back after slamming into a wall or a heavy enemy.
@export var shield_impact_kickback_distance: float = 1.4
## Seconds the kickback takes. It starts fast and eases out.
@export var shield_impact_kickback_duration: float = 0.3
## Camera kick on impact. It springs back on its own.
@export var shield_impact_camera_kick_degrees: Vector3 = Vector3(4.5, 0.0, 1.5)
## Screen shake when the charge slams into a wall or a heavy enemy, from 0 (none) to 1 (strongest).
## A crush uses shield_crush_screen_shake instead.
@export_range(0.0, 1.0) var shield_impact_screen_shake: float = 0.6
## Loudness added to the stealth meter by an impact.
@export var shield_impact_loudness: float = 30.0

@export_group("Empowered (S Rank)")
## At this combo rank (ComboMeter: 0 D ... 4 S) or above, attacks are empowered. The normal shield
## bash is never empowered.
@export var enable_empowerment: bool = true
@export var empowered_rank: int = 4
## Broadsword: each swing also launches a slash wave that flies ahead and cuts through enemies.
## Damage of each wave hit.
@export var sword_wave_damage: float = 3.0
## Wave speed (m/s), range (m) and width (m).
@export var sword_wave_speed: float = 28.0
@export var sword_wave_range: float = 22.0
@export var sword_wave_width: float = 3.2
## The wave follows the camera's pitch, limited to this range (degrees, negative is down), so it
## doesn't plough into the floor at your feet.
@export var sword_wave_pitch_limits: Vector2 = Vector2(-12.0, 30.0)
## Halberd: the lunge covers this many times its normal distance ...
@export var halberd_empowered_dash_multiplier: float = 4.0
## ... over this many times its normal duration ...
@export var halberd_empowered_dash_duration_multiplier: float = 2.0
## ... and everything it hits on the way takes this many times the damage. The player passes
## through the enemies it hits instead of stopping against them.
@export var halberd_empowered_damage_multiplier: float = 2.0
## Shield charge: nothing is picked up; every enemy it touches (heavy ones too) is crushed on the
## spot and the charge keeps going. Screen shake per crushed enemy.
@export_range(0.0, 1.0) var empowered_charge_crush_screen_shake: float = 0.35
## Glow over the weapon in hand while empowered.
@export var empowered_glow_color: Color = Color(1.0, 0.35, 0.2, 0.35)
## Glow pulses per second.
@export var empowered_glow_pulse_speed: float = 3.0

@export_group("Crossbow")
## The crossbow only fires with something on the combo meter. Each shot spends all of it, and the
## bolt's damage depends on the rank it was fired at: D, C, B, A, S.
@export var crossbow_rank_damage: Array[float] = [2.0, 3.0, 5.0, 8.0, 12.0]
## Bolt speed (m/s) and push on what it hits.
@export var crossbow_bolt_speed: float = 80.0
@export var crossbow_bolt_impulse: float = 12.0
## Freeze on an enemy hit by a bolt (the crossbow itself doesn't freeze).
@export var crossbow_hit_stop_time: float = 0.08
## Screen shake on a bolt hit at rank D, and how much more per rank above it.
@export_range(0.0, 1.0) var crossbow_hit_screen_shake: float = 0.2
@export_range(0.0, 1.0) var crossbow_hit_screen_shake_per_rank: float = 0.08
## At S rank (empowered_rank) the bolt explodes where it lands: radius (m), damage at the centre,
## share of it at the edge, and the shove on props.
@export var crossbow_explosion_radius: float = 6.0
@export var crossbow_explosion_damage: float = 10.0
@export_range(0.0, 1.0) var crossbow_explosion_edge_damage_ratio: float = 0.4
@export var crossbow_explosion_impulse: float = 30.0
## Screen shake and loudness of the explosion.
@export_range(0.0, 1.0) var crossbow_explosion_screen_shake: float = 0.8
@export var crossbow_explosion_loudness: float = 60.0
## Seconds between dry-fire clicks when the meter is empty.
@export var crossbow_dry_fire_cooldown: float = 0.3

@export_group("Visuals")
## Keeps the viewmodels from casting odd shadows onto the world.
@export var cast_shadows: bool = false

var player: CharacterBody3D
var _camera: Node3D
var _weapons: Dictionary = {}
var _idle_transforms: Dictionary = {}
var _attacks: Dictionary = {}
var _pistol: Node
var _equipped_weapon: StringName = WEAPON_NONE
var _equip_timer: float = 0.0
var _is_equipping: bool = false
var _is_attacking: bool = false
var _attack_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _attack_strike_started: bool = false
var _attack_strike_finished: bool = false
var _attack_has_hit: bool = false
var _attack_hit_stop_used: bool = false
var _attack_shake_used: bool = false
var _hit_stop_timer: float = 0.0
var _attack_hit_ids: Dictionary = {}
var _attack_next_ray_angle: float = 0.0
var _pose_position: Vector3 = Vector3.ZERO
var _pose_rotation: Vector3 = Vector3.ZERO
var _recover_timers: Dictionary = {}
var _last_attack_weapon: StringName = WEAPON_NONE
var _mouse_was_captured: bool = false
var _behaviours: Dictionary = {}
var _press_pending: bool = false
var _press_weapon: StringName = WEAPON_NONE
var _press_timer: float = 0.0
var _is_hold_active: bool = false
var _hold_weapon: StringName = WEAPON_NONE
var _hold_active_time: float = 0.0
var _previous_weapon: StringName = WEAPON_NONE
var _is_shield_charge_held: bool = false
var _shield_charge_hit_timer: float = 0.0
var _shield_brace_blend: float = 0.0
var _shield_brace_time: float = 0.0
var _carried_enemies: Array[Node3D] = []
var _is_casting_charge_hits: bool = false
var _charge_was_blocked: bool = false
var _charge_blocker: Node3D
var _pending_impact_heading: Vector3 = Vector3.ZERO
var _pending_impact_timer: float = 0.0
var _attack_empowered: bool = false
var _crossbow_rank: int = -1
var _dry_fire_timer: float = 0.0
var _charge_empowered: bool = false
var _empowered_dash_timer: float = 0.0
var _dash_passed_enemies: Array[Node3D] = []
var _dash_pass_timer: float = 0.0
var _glow_material: StandardMaterial3D
var _glow_time: float = 0.0
var _is_glowing: bool = false


func _ready() -> void:
	add_to_group(GROUP_PLAYER_MELEE)
	player = get_node_or_null(player_path) as CharacterBody3D
	_camera = get_parent() as Node3D
	_pistol = get_node_or_null(pistol_path)
	_register_weapon(WEAPON_BROADSWORD, broadsword_path, broadsword_attack)
	_register_weapon(WEAPON_HALBERD, halberd_path, halberd_attack)
	_register_weapon(WEAPON_SHIELD, shield_path, shield_attack)
	_register_weapon(WEAPON_CROSSBOW, crossbow_path, crossbow_attack)
	_register_behaviour_weapons()
	if not cast_shadows:
		_disable_shadows(self)
	equip(starting_weapon)


func _physics_process(delta: float) -> void:
	# Number keys pick a loadout slot: 1 = first weapon in weapon_order, 2 = second, … up to 9.
	var slot: int = InputManager.get_weapon_slot_just_pressed()
	if slot >= 0:
		equip_slot(slot)
	var cycle: int = InputManager.consume_weapon_cycle()
	if cycle != 0:
		cycle_weapon(cycle)

	_update_recover_timers(delta)
	_dry_fire_timer = maxf(_dry_fire_timer - delta, 0.0)
	_update_pending_impact(delta)
	_update_attack_input(delta)
	_update_attack(delta)
	_update_shield_charge(delta)
	_update_dash_pass_through(delta)
	_update_hold(delta)
	for behaviour in _behaviours.values():
		behaviour.call(&"behaviour_physics_process", delta)


func _process(delta: float) -> void:
	# During a crush freeze the braced shield holds still instead of relaxing.
	if _pending_impact_timer <= 0.0:
		_update_shield_brace_blend(delta)
	if _is_equipping:
		_equip_timer += delta
		if get_equip_progress() >= 1.0:
			_is_equipping = false

	_apply_weapon_pose()
	_update_empowered_glow(delta)


func get_equipped_weapon() -> StringName:
	return _equipped_weapon


func has_weapon_equipped() -> bool:
	return _equipped_weapon != WEAPON_NONE


func is_equipping() -> bool:
	return _is_equipping


func get_equip_progress() -> float:
	if _equipped_weapon == WEAPON_NONE:
		return 0.0
	return clampf(_equip_timer / maxf(equip_time, 0.001), 0.0, 1.0)


func is_attacking() -> bool:
	return _is_attacking


func get_attack_progress() -> float:
	var attack_data: MeleeAttackData = _get_equipped_attack()
	if not _is_attacking or attack_data == null:
		return 0.0
	return clampf(_attack_timer / attack_data.get_duration(), 0.0, 1.0)


func can_attack() -> bool:
	if _is_attacking or _is_equipping or _is_hold_active:
		return false
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour != null and bool(behaviour.call(&"is_busy")):
		return false
	if _get_equipped_attack() == null:
		return false
	if get_recover_remaining(_equipped_weapon) > 0.0:
		return false
	if _player_bool(METHOD_IS_SHIELD_CHARGING, false):
		return false
	return not _is_weapon_blocked()


## Seconds until the given weapon can attack again. It keeps counting down while another weapon is out,
## and drops to zero as soon as a different weapon attacks.
func get_recover_remaining(weapon_id: StringName) -> float:
	return maxf(float(_recover_timers.get(weapon_id, 0.0)), 0.0)


func is_recovering(weapon_id: StringName) -> bool:
	return get_recover_remaining(weapon_id) > 0.0


## Weapon used for the most recent attack. Attacking with any other weapon resets all recovers.
func get_last_attack_weapon() -> StringName:
	return _last_attack_weapon


## True while attack is held and the shield is braced for a charge (not while the charge brakes).
func is_shield_charge_held() -> bool:
	return _is_shield_charge_held


## True when the combo meter is high enough (S) for empowered attacks.
func is_empowered() -> bool:
	return enable_empowerment and ComboMeter.get_rank() >= empowered_rank


## True while the current attack or shield charge is an empowered one.
func is_attack_empowered() -> bool:
	return (_is_attacking and _attack_empowered) or (_is_shield_charge_held and _charge_empowered)


func get_carried_enemy_count() -> int:
	return _carried_enemies.size()


## Brings the given weapon into hand. Returns true if the equipped weapon changed.
## Asking for the weapon that is already out does nothing and does not replay the equip animation.
## Switching weapons cancels an attack in progress.
func equip(weapon_id: StringName) -> bool:
	if weapon_id == _equipped_weapon or not _weapons.has(weapon_id):
		return false
	# Only weapons in the loadout can be taken out.
	if not weapon_order.is_empty() and not weapon_order.has(weapon_id):
		return false
	if not is_weapon_available(weapon_id):
		return false

	_put_away_equipped()
	if _equipped_weapon != WEAPON_NONE:
		_previous_weapon = _equipped_weapon
	_equipped_weapon = weapon_id
	_equip_timer = 0.0
	_is_equipping = true
	_set_pistol_holstered(true)

	var weapon: Node3D = _weapons[weapon_id] as Node3D
	_apply_weapon_pose()
	weapon.reset_physics_interpolation()
	weapon.visible = true
	var behaviour: Node = _get_behaviour(weapon_id)
	if behaviour != null:
		behaviour.call(&"on_equipped")
	weapon_changed.emit(_equipped_weapon)
	return true


## Puts every weapon away: nothing in hand, no attacks (after throwing the only weapon left).
func holster_all() -> void:
	if _equipped_weapon == WEAPON_NONE:
		return
	_put_away_equipped()
	_previous_weapon = _equipped_weapon
	_equipped_weapon = WEAPON_NONE
	_is_equipping = false
	weapon_changed.emit(_equipped_weapon)


## Cancels whatever the weapon in hand is doing and hides every weapon.
func _put_away_equipped() -> void:
	_cancel_attack()
	_cancel_press_and_hold()
	_release_shield_charge()
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour != null:
		behaviour.call(&"on_unequipped")
	_hide_all_weapons()


## The weapon that was in hand before the current one (WEAPON_NONE if none).
func get_previous_weapon() -> StringName:
	return _previous_weapon


## False while a weapon can't be used, for example a thrown hatchet that hasn't been picked up.
func is_weapon_available(weapon_id: StringName) -> bool:
	var behaviour: Node = _get_behaviour(weapon_id)
	return behaviour == null or bool(behaviour.call(&"is_available"))


## Takes out the best other weapon: the previous one if it is usable, else the first usable one in the
## loadout, else nothing. Used after a throw leaves the hand empty.
func switch_away_from(weapon_id: StringName) -> void:
	var candidates: Array[StringName] = [_previous_weapon]
	candidates.append_array(weapon_order)
	for candidate in candidates:
		if candidate == weapon_id or candidate == WEAPON_NONE or not _weapons.has(candidate):
			continue
		if not weapon_order.is_empty() and not weapon_order.has(candidate):
			continue
		if not is_weapon_available(candidate):
			continue
		equip(candidate)
		return
	if _equipped_weapon == weapon_id:
		holster_all()


## Called by a behaviour when one of its weapons becomes usable or unusable.
func notify_availability_changed(weapon_id: StringName) -> void:
	weapon_availability_changed.emit(weapon_id, is_weapon_available(weapon_id))


## Equips the weapon in loadout slot index (0-based) of weapon_order. False if the slot is empty.
func equip_slot(index: int) -> bool:
	if index < 0 or index >= weapon_order.size():
		return false
	return equip(weapon_order[index])


## Every weapon this node has, in registration order (broadsword, halberd, shield), whether or not
## it is in the loadout. The loadout screen offers these.
func get_all_weapons() -> Array[StringName]:
	var all: Array[StringName] = []
	for weapon_id in _weapons.keys():
		all.append(weapon_id)
	return all


## Sets the loadout: the weapons the player can use, in slot order (keys 1, 2, 3, cycling and the
## selector wheel follow it). The first one is taken out right away if the weapon in hand isn't in
## the new loadout. Unknown ids are ignored; an empty list is refused.
func set_loadout(weapon_ids: Array[StringName]) -> void:
	var loadout: Array[StringName] = []
	for weapon_id in weapon_ids:
		if _weapons.has(weapon_id) and not loadout.has(weapon_id):
			loadout.append(weapon_id)
	if loadout.is_empty():
		return
	weapon_order = loadout
	if not weapon_order.has(_equipped_weapon):
		equip(weapon_order[0])
	loadout_changed.emit(weapon_order)


## Equips the weapon steps places after the current one in weapon_order (negative goes back),
## wrapping around. Q and mouse wheel up step +1, mouse wheel down steps -1.
func cycle_weapon(steps: int) -> bool:
	if weapon_order.is_empty():
		return false
	var index: int = weapon_order.find(_equipped_weapon)
	if index < 0:
		index = -1 if steps > 0 else 0
	var step: int = 1 if steps > 0 else -1
	var next_index: int = posmod(index + steps, weapon_order.size())
	# Skip weapons that can't be used right now (a thrown hatchet).
	for _attempt in range(weapon_order.size()):
		if weapon_order[next_index] == _equipped_weapon:
			return false
		if is_weapon_available(weapon_order[next_index]):
			return equip(weapon_order[next_index])
		next_index = posmod(next_index + step, weapon_order.size())
	return false


## Starts the equipped weapon's attack. Returns true if an attack started.
func attack() -> bool:
	# The crossbow needs something on the combo meter. Checked before the reload, so clicking an
	# empty crossbow always gives the dry-fire feedback.
	if _equipped_weapon == WEAPON_CROSSBOW and ComboMeter.get_rank() < 0 and not _is_equipping:
		_attack_buffer_timer = 0.0
		if _dry_fire_timer <= 0.0:
			_dry_fire_timer = maxf(crossbow_dry_fire_cooldown, 0.0)
			crossbow_dry_fired.emit()
		return false
	if not can_attack():
		return false

	var attack_data: MeleeAttackData = _get_equipped_attack()
	_is_attacking = true
	_attack_timer = 0.0
	_attack_buffer_timer = 0.0
	_attack_strike_started = false
	_attack_strike_finished = false
	_attack_has_hit = false
	_attack_hit_stop_used = false
	_attack_shake_used = false
	_hit_stop_timer = 0.0
	_attack_hit_ids.clear()
	_attack_next_ray_angle = attack_data.get_half_arc_degrees()
	# The shield's bash is never empowered; only its charge is.
	_attack_empowered = is_empowered() and _equipped_weapon != WEAPON_SHIELD
	# Behaviour weapons whose click has no S-rank version don't count as empowered.
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour != null and not bool(behaviour.call(&"has_empowered_click")):
		_attack_empowered = false
	if _equipped_weapon == WEAPON_CROSSBOW:
		# The whole meter goes into this shot; the rank it was at sets the damage.
		_crossbow_rank = ComboMeter.spend_all()
	_register_weapon_use(_equipped_weapon)
	# Busy for the whole attack. Switching away doesn't skip it; only another weapon's attack clears it.
	_recover_timers[_equipped_weapon] = attack_data.get_duration()
	LoudnessManger.register_sound(attack_data.swing_loudness)
	attack_started.emit(_equipped_weapon)
	return true


## Attacking with a different weapon than last time clears every other weapon's recover.
func _register_weapon_use(weapon_id: StringName) -> void:
	if weapon_id == _last_attack_weapon:
		return

	_last_attack_weapon = weapon_id
	for other_weapon_id in _recover_timers.keys():
		if other_weapon_id != weapon_id:
			_recover_timers[other_weapon_id] = 0.0
	recover_reset.emit(weapon_id)


func _update_recover_timers(delta: float) -> void:
	for weapon_id in _recover_timers.keys():
		_recover_timers[weapon_id] = maxf(float(_recover_timers[weapon_id]) - delta, 0.0)


func _update_attack_input(delta: float) -> void:
	_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)

	# head.gd captures the mouse on click; that same click shouldn't also attack.
	var mouse_captured: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if InputManager.is_attack_just_pressed() and _mouse_was_captured and mouse_captured:
		var press_mode: int = _get_press_mode(_equipped_weapon)
		if press_mode == PRESS_HOLD_WHEN_EMPOWERED and not is_empowered():
			press_mode = PRESS_ON_PRESS
		if press_mode == PRESS_ON_PRESS:
			_attack_buffer_timer = maxf(attack_input_buffer, 0.0)
		else:
			# Wait to see whether this is a click or a hold (shield bash / charge, hammer charge, ...).
			_press_pending = true
			_press_weapon = _equipped_weapon
			_press_timer = 0.0
	# Weapons that repeat while held (sickle and dagger) keep queueing their click attack.
	if mouse_captured and _mouse_was_captured and InputManager.is_attack_pressed() and not _press_pending and not _is_hold_active:
		var repeat_behaviour: Node = _get_behaviour(_equipped_weapon)
		if repeat_behaviour != null and bool(repeat_behaviour.call(&"repeats_while_held")):
			_attack_buffer_timer = maxf(_attack_buffer_timer, maxf(attack_input_buffer, 0.0))
	_mouse_was_captured = mouse_captured

	_update_press(delta)
	# The weapon selector only holds back new attacks; one already swinging finishes. The dead don't attack.
	if _is_weapon_blocked() or _is_weapon_wheel_open() or HealthManager.is_dead():
		_attack_buffer_timer = 0.0
		_cancel_press_and_hold()
		return
	if _attack_buffer_timer > 0.0:
		attack()


## A press that may become a hold: released early it is a click (except hold-only weapons), held past
## the weapon's hold time it starts the hold move as soon as the weapon is free.
func _update_press(delta: float) -> void:
	if not _press_pending:
		return
	if _equipped_weapon != _press_weapon:
		_press_pending = false
		return
	var press_mode: int = _get_press_mode(_equipped_weapon)
	if not InputManager.is_attack_pressed():
		_press_pending = false
		# Let go before the hold time: a normal click attack. Hold-only weapons do nothing.
		if press_mode != PRESS_HOLD_ONLY:
			_attack_buffer_timer = maxf(attack_input_buffer, 0.0)
		return

	_press_timer += delta
	if _press_timer < _get_hold_time(_equipped_weapon):
		return
	# Still held, but busy (equipping or mid-attack): keep waiting and start as soon as the weapon is free.
	if not can_attack():
		return

	_press_pending = false
	_start_hold()


func _start_hold() -> void:
	if _equipped_weapon == WEAPON_SHIELD:
		_start_shield_charge()
		return
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour == null or not bool(behaviour.call(&"on_hold_started")):
		return
	_is_hold_active = true
	_hold_weapon = _equipped_weapon
	_hold_active_time = 0.0


## Runs the behaviour's hold move until attack is released, the behaviour ends it, or something
## interrupts it (switching, the selector, climbing, death).
func _update_hold(delta: float) -> void:
	if not _is_hold_active:
		return
	var behaviour: Node = _get_behaviour(_hold_weapon)
	if behaviour == null or _equipped_weapon != _hold_weapon:
		_cancel_press_and_hold()
		return
	if not InputManager.is_attack_pressed():
		_is_hold_active = false
		behaviour.call(&"on_hold_released", _hold_active_time)
		return
	_hold_active_time += delta
	if not bool(behaviour.call(&"on_hold_updated", delta, _hold_active_time)):
		_is_hold_active = false


func _cancel_press_and_hold() -> void:
	_press_pending = false
	if not _is_hold_active:
		return
	_is_hold_active = false
	var behaviour: Node = _get_behaviour(_hold_weapon)
	if behaviour != null:
		behaviour.call(&"on_hold_cancelled")


## True while a behaviour weapon's hold move runs (hammer charging, dagger stream, grapple, ...).
func is_hold_active() -> bool:
	return _is_hold_active


func _get_press_mode(weapon_id: StringName) -> int:
	if weapon_id == WEAPON_SHIELD:
		return PRESS_CLICK_OR_HOLD
	var behaviour: Node = _get_behaviour(weapon_id)
	if behaviour != null:
		return int(behaviour.call(METHOD_GET_PRESS_MODE))
	return PRESS_ON_PRESS


func _get_hold_time(weapon_id: StringName) -> float:
	if weapon_id == WEAPON_SHIELD:
		return maxf(shield_hold_time, 0.0)
	var behaviour: Node = _get_behaviour(weapon_id)
	if behaviour != null:
		return float(behaviour.call(&"get_hold_time"))
	return 0.0


func _start_shield_charge() -> void:
	if player == null or not player.has_method(METHOD_START_SHIELD_CHARGE):
		return
	if not bool(player.call(METHOD_START_SHIELD_CHARGE)):
		return

	_is_shield_charge_held = true
	_shield_charge_hit_timer = 0.0
	_charge_empowered = is_empowered()
	if _charge_empowered:
		empowered_attack_started.emit(WEAPON_SHIELD)
	# A charge counts as attacking with the shield for combos, but has no recover of its own.
	_register_weapon_use(WEAPON_SHIELD)
	shield_charge_started.emit()


func _release_shield_charge() -> void:
	if not _is_shield_charge_held:
		return

	_is_shield_charge_held = false
	_charge_empowered = false
	if player != null and player.has_method(METHOD_RELEASE_SHIELD_CHARGE):
		player.call(METHOD_RELEASE_SHIELD_CHARGE)
	shield_charge_released.emit()


func _update_shield_charge(delta: float) -> void:
	var player_is_charging: bool = _player_bool(METHOD_IS_SHIELD_CHARGING, false)
	if _is_shield_charge_held:
		if not player_is_charging:
			# The player side ended it: out of stamina, a low ceiling, or a climb or wall run took over.
			_is_shield_charge_held = false
			_charge_empowered = false
			shield_charge_released.emit()
		elif not InputManager.is_attack_pressed() or _equipped_weapon != WEAPON_SHIELD:
			_release_shield_charge()

	if not player_is_charging:
		# The charge ended without hitting a wall: let the carried enemies go in front of the player.
		_release_carried_enemies()
		return

	_cast_shield_charge_hits(delta)
	if _charge_was_blocked:
		_charge_was_blocked = false
		var blocker: Node3D = _charge_blocker
		_charge_blocker = null
		var heading: Vector3 = _get_charge_heading()
		_stop_player_charge()
		_release_carried_enemies()
		# A heavy enemy staggers and knocks the player back. A full shield just stops.
		if blocker != null and is_instance_valid(blocker):
			if blocker.has_method(METHOD_ON_SHIELD_CHARGE_IMPACT):
				blocker.call(METHOD_ON_SHIELD_CHARGE_IMPACT, {
					"position": blocker.global_position,
					"direction": heading,
					"collider": blocker,
					"weapon": WEAPON_SHIELD,
					"attacker": player,
				})
				shield_charge_stunned.emit(blocker)
			_play_shield_impact(heading)
		shield_charge_blocked.emit()
		return

	_update_carried_enemies(delta)
	if not _try_crush_carried_enemies():
		_try_wall_impact()


func _cast_shield_charge_hits(delta: float) -> void:
	if shield_charge_attack == null or _camera == null:
		return

	_shield_charge_hit_timer -= delta
	if _shield_charge_hit_timer <= 0.0:
		_shield_charge_hit_timer = maxf(shield_charge_rehit_interval, 0.05)
		_attack_hit_ids.clear()
		_attack_has_hit = false
	if _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0) < shield_charge_min_hit_speed:
		return

	# The braced shield covers the body and faces where the player faces, not where the camera pitches.
	var charge_transform: Transform3D = Transform3D(
		Basis(Vector3.UP, player.rotation.y),
		_camera.global_position
	)
	_is_casting_charge_hits = true
	_cast_box_rays(shield_charge_attack, charge_transform)
	_is_casting_charge_hits = false


## Picks the enemy up, or flags the charge as blocked if the shield is already full.
func _try_carry_enemy(target: Node3D) -> void:
	if _carried_enemies.has(target):
		return
	# Heavy enemies stop the charge dead, like a full shield does.
	if target.has_method(METHOD_IS_SHIELD_CHARGE_BLOCKER) and bool(target.call(METHOD_IS_SHIELD_CHARGE_BLOCKER)):
		_charge_was_blocked = true
		_charge_blocker = target
		return
	if target.has_method(METHOD_CAN_BE_SHIELD_CARRIED) and not bool(target.call(METHOD_CAN_BE_SHIELD_CARRIED)):
		return
	if _carried_enemies.size() >= maxi(shield_carry_max, 0):
		_charge_was_blocked = true
		return

	target.call(METHOD_START_SHIELD_CARRY, player)
	_carried_enemies.append(target)
	shield_carry_changed.emit(_carried_enemies.size())


## Holds carried enemies side by side in front of the player, centered on the charge heading.
func _update_carried_enemies(delta: float) -> void:
	_remove_lost_carried_enemies()
	if _carried_enemies.is_empty() or player == null:
		return

	var heading: Vector3 = _get_charge_heading()
	var right: Vector3 = heading.cross(Vector3.UP).normalized()
	# Faster than the charge itself, so carried enemies never fall back into the player.
	var carry_step: float = (_player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0) + maxf(shield_carry_snap_speed, 0.0)) * delta
	var carried_count: int = _carried_enemies.size()
	for index in range(carried_count):
		var enemy: Node3D = _carried_enemies[index]
		var side_offset: float = (float(index) - (float(carried_count - 1) * 0.5)) * shield_carry_spacing
		var slot_position: Vector3 = player.global_position
		slot_position += heading * shield_carry_distance
		slot_position += right * side_offset
		enemy.global_position = enemy.global_position.move_toward(slot_position, carry_step)


## Two rays at body height look for a wall right in front. If both find one while the charge
## is fast enough, everything on the shield is crushed and the charge stops dead.
## Returns true if a crush happened.
func _try_crush_carried_enemies() -> bool:
	if _carried_enemies.is_empty() or player == null:
		return false
	if _player_float(METHOD_GET_SHIELD_CHARGE_SPEED, 0.0) < shield_crush_min_speed:
		return false

	var heading: Vector3 = _get_charge_heading()
	if not _is_wall_ahead(heading, shield_crush_ray_heights.x, shield_crush_wall_distance):
		return false
	if not _is_wall_ahead(heading, shield_crush_ray_heights.y, shield_crush_wall_distance):
		return false

	var crushed_enemies: Array[Node3D] = _carried_enemies.duplicate()
	_carried_enemies.clear()
	for enemy in crushed_enemies:
		if not is_instance_valid(enemy) or not enemy.has_method(METHOD_ON_SHIELD_CRUSH):
			continue
		enemy.call(METHOD_ON_SHIELD_CRUSH, {
			"position": enemy.global_position,
			"normal": -heading,
			"direction": heading,
			"collider": enemy,
			"weapon": WEAPON_SHIELD,
			"attacker": player,
			"hit_stop_time": shield_crush_hit_stop_time,
		})

	_stop_player_charge()
	LoudnessManger.register_sound(shield_crush_loudness)
	if _camera != null and _camera.has_method(METHOD_ADD_RECOIL_IMPULSE):
		_camera.call(METHOD_ADD_RECOIL_IMPULSE, Vector3.ZERO, _degrees_to_radians(shield_crush_camera_kick_degrees))
	if _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
		_camera.call(METHOD_ADD_SCREEN_SHAKE, shield_crush_screen_shake)
	# Hit-stop: the enemies stay pinned and the shield holds its pose, then they break and the player bounces off.
	if shield_crush_hit_stop_time > 0.0:
		_pending_impact_heading = heading
		_pending_impact_timer = shield_crush_hit_stop_time
	else:
		_play_shield_impact(heading, false)
	shield_carry_changed.emit(0)
	shield_carry_crushed.emit(crushed_enemies.size())
	return true


## An empty charge that runs into a wall fast enough stops dead and throws the player back.
func _try_wall_impact() -> void:
	if not _carried_enemies.is_empty() or player == null:
		return
	if _player_float(METHOD_GET_SHIELD_CHARGE_SPEED, 0.0) < shield_wall_impact_min_speed:
		return

	var heading: Vector3 = _get_charge_heading()
	if not _is_wall_ahead(heading, shield_crush_ray_heights.x, shield_wall_impact_distance):
		return
	if not _is_wall_ahead(heading, shield_crush_ray_heights.y, shield_wall_impact_distance):
		return

	_stop_player_charge()
	_play_shield_impact(heading)


func _update_pending_impact(delta: float) -> void:
	if _pending_impact_timer <= 0.0:
		return

	_pending_impact_timer = maxf(_pending_impact_timer - delta, 0.0)
	if _pending_impact_timer <= 0.0:
		_play_shield_impact(_pending_impact_heading, false)


## The punch of an impact: the player is thrown back against the charge direction, the camera kicks
## and shakes. A crush shakes the screen itself at the moment of impact, so it passes shake = false.
func _play_shield_impact(heading: Vector3, shake: bool = true) -> void:
	if player != null and player.has_method(METHOD_START_DASH) and heading.length_squared() > 0.001:
		player.call(METHOD_START_DASH, -heading, shield_impact_kickback_distance, shield_impact_kickback_duration)
	if _camera != null and _camera.has_method(METHOD_ADD_RECOIL_IMPULSE):
		_camera.call(METHOD_ADD_RECOIL_IMPULSE, Vector3.ZERO, _degrees_to_radians(shield_impact_camera_kick_degrees))
	if shake and _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
		_camera.call(METHOD_ADD_SCREEN_SHAKE, shield_impact_screen_shake)
	LoudnessManger.register_sound(shield_impact_loudness)
	shield_charge_impact.emit()


func _is_wall_ahead(heading: Vector3, height: float, distance: float) -> bool:
	var ray_from: Vector3 = player.global_position + (Vector3.UP * height)
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_from,
		ray_from + (heading * maxf(distance, 0.0)),
		hit_collision_mask,
		_get_excluded_rids()
	)
	var ray_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
	if ray_hit.is_empty():
		return false
	# Other enemies and loose props in the way are not walls.
	if _is_hittable(ray_hit.get("collider") as Node3D):
		return false
	return absf(Vector3(ray_hit.get("normal", Vector3.UP)).y) <= shield_crush_max_wall_normal_y


## Throws the carried enemies forward, fanned out so they land spread in front of the player.
func _release_carried_enemies() -> void:
	if _carried_enemies.is_empty():
		return

	var heading: Vector3 = Vector3.ZERO
	if player != null:
		heading = -Basis(Vector3.UP, player.rotation.y).z
	var right: Vector3 = heading.cross(Vector3.UP).normalized()
	var released_enemies: Array[Node3D] = _carried_enemies.duplicate()
	_carried_enemies.clear()
	var released_count: int = released_enemies.size()
	for index in range(released_count):
		var enemy: Node3D = released_enemies[index]
		if not is_instance_valid(enemy) or not enemy.has_method(METHOD_END_SHIELD_CARRY):
			continue
		var side: float = float(index) - (float(released_count - 1) * 0.5)
		var release_velocity: Vector3 = heading * shield_release_forward_speed
		release_velocity += right * side * shield_release_spread_speed
		release_velocity += Vector3.UP * shield_release_up_speed
		enemy.call(METHOD_END_SHIELD_CARRY, release_velocity)
	shield_carry_changed.emit(0)


## Drops enemies that died or were freed while on the shield.
func _remove_lost_carried_enemies() -> void:
	for index in range(_carried_enemies.size() - 1, -1, -1):
		var enemy: Node3D = _carried_enemies[index]
		var is_lost: bool = not is_instance_valid(enemy)
		if not is_lost and enemy.has_method(&"is_shield_carried"):
			is_lost = not bool(enemy.call(&"is_shield_carried"))
		if is_lost:
			_carried_enemies.remove_at(index)


func _get_charge_heading() -> Vector3:
	var heading: Vector3 = Vector3.ZERO
	if player != null and player.has_method(METHOD_GET_SHIELD_CHARGE_HEADING):
		heading = Vector3(player.call(METHOD_GET_SHIELD_CHARGE_HEADING))
	if heading.length_squared() <= 0.001 and player != null:
		heading = -Basis(Vector3.UP, player.rotation.y).z
	return heading.normalized()


func _stop_player_charge() -> void:
	_is_shield_charge_held = false
	if player != null and player.has_method(METHOD_STOP_SHIELD_CHARGE):
		player.call(METHOD_STOP_SHIELD_CHARGE)


func _update_shield_brace_blend(delta: float) -> void:
	var brace_target: float = 0.0
	if _is_shield_charge_held:
		brace_target = 1.0

	var brace_blend: float = 1.0 - exp(-maxf(shield_brace_lerp_speed, 0.001) * delta)
	_shield_brace_blend = lerpf(_shield_brace_blend, brace_target, brace_blend)
	if _shield_brace_blend < 0.001 and brace_target <= 0.0:
		_shield_brace_blend = 0.0
	_shield_brace_time += delta


func _set_shield_brace_pose() -> void:
	var speed_ratio: float = MovementShieldCharge.get_speed_ratio(_player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0))
	var shake: float = sin(_shield_brace_time * shield_brace_shake_frequency * TAU) * shield_brace_shake_amount * speed_ratio
	_pose_position = (shield_brace_position + Vector3(0.0, shake, 0.0)) * _shield_brace_blend
	_pose_rotation = _degrees_to_radians(shield_brace_rotation_degrees) * _shield_brace_blend


func _update_attack(delta: float) -> void:
	if not _is_attacking:
		return

	var attack_data: MeleeAttackData = _get_equipped_attack()
	if attack_data == null or _is_weapon_blocked():
		_cancel_attack()
		return

	# Hit-stop: the swing holds still, and the sweep with it, so later hits wait their turn.
	if _hit_stop_timer > 0.0:
		_hit_stop_timer = maxf(_hit_stop_timer - delta, 0.0)
		return

	_attack_timer += delta
	var progress: float = get_attack_progress()
	if progress >= attack_data.get_windup_end() and not _attack_strike_started:
		_attack_strike_started = true
		_start_strike(attack_data)

	# The empowered halberd keeps hitting everything in front for as long as its long dash lasts.
	if _empowered_dash_timer > 0.0:
		_empowered_dash_timer = maxf(_empowered_dash_timer - delta, 0.0)
		_update_attack_hits(attack_data, 1.0)

	# The tick that passes strike_end still checks once, so a fast strike can't skip its last hits.
	if _attack_strike_started and not _attack_strike_finished:
		var strike_progress: float = attack_data.get_strike_progress(progress)
		# The crossbow's bolt and thrown weapons do their own hitting.
		if _uses_strike_rays(_equipped_weapon):
			_update_attack_hits(attack_data, strike_progress)
		if strike_progress >= 1.0:
			_attack_strike_finished = true

	if _attack_timer >= attack_data.get_duration():
		_finish_attack()


func _start_strike(attack_data: MeleeAttackData) -> void:
	if _camera != null and _camera.has_method(METHOD_ADD_RECOIL_IMPULSE):
		_camera.call(
			METHOD_ADD_RECOIL_IMPULSE,
			Vector3.ZERO,
			_degrees_to_radians(attack_data.camera_kick_rotation_degrees)
		)

	if _attack_empowered:
		empowered_attack_started.emit(_equipped_weapon)
		if _equipped_weapon == WEAPON_BROADSWORD:
			_launch_sword_wave()

	if _equipped_weapon == WEAPON_CROSSBOW:
		_fire_crossbow_bolt(_crossbow_rank)
		return
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour != null:
		behaviour.call(&"on_strike_started", attack_data, _attack_empowered)

	if attack_data.dash_distance <= 0.0 or player == null or not player.has_method(METHOD_START_DASH):
		return

	var dash_direction: Vector3 = -Basis(Vector3.UP, player.rotation.y).z
	var dash_distance: float = attack_data.dash_distance
	var dash_duration: float = attack_data.dash_duration
	if _attack_empowered and _equipped_weapon == WEAPON_HALBERD:
		dash_distance *= maxf(halberd_empowered_dash_multiplier, 0.0)
		dash_duration *= maxf(halberd_empowered_dash_duration_multiplier, 0.01)
		_empowered_dash_timer = dash_duration
	player.call(METHOD_START_DASH, dash_direction, dash_distance, dash_duration)


func _finish_attack() -> void:
	var finished_weapon: StringName = _equipped_weapon
	_cancel_attack()
	attack_finished.emit(finished_weapon)


func _cancel_attack() -> void:
	if not _is_attacking:
		return

	_is_attacking = false
	_attack_timer = 0.0
	_attack_hit_ids.clear()
	_attack_empowered = false
	_empowered_dash_timer = 0.0
	if _weapons.has(_equipped_weapon):
		var weapon: Node3D = _weapons[_equipped_weapon] as Node3D
		weapon.transform = _idle_transforms[_equipped_weapon]


func _update_attack_hits(attack_data: MeleeAttackData, strike_progress: float) -> void:
	if _camera == null:
		return

	var camera_transform: Transform3D = _camera.global_transform.orthonormalized()
	if attack_data.hit_area == MeleeAttackData.HitArea.ARC:
		_cast_arc_rays(attack_data, camera_transform, strike_progress)
	else:
		_cast_box_rays(attack_data, camera_transform)


## Fan of rays from the camera. With sweep_right_to_left each tick only casts the columns
## the swing has passed since the last tick, so targets are hit in order from right to left.
func _cast_arc_rays(attack_data: MeleeAttackData, camera_transform: Transform3D, strike_progress: float) -> void:
	var half_arc: float = attack_data.get_half_arc_degrees()
	var sweep_angle: float = -half_arc
	if attack_data.sweep_right_to_left:
		sweep_angle = lerpf(half_arc, -half_arc, clampf(strike_progress, 0.0, 1.0))

	var reach: float = maxf(attack_data.reach, 0.01)
	var spacing: float = maxf(attack_data.ray_spacing_degrees, 0.5)
	var row_count: int = maxi(attack_data.ray_rows, 1)
	# Positive angles are to the right of where the camera looks.
	while _attack_next_ray_angle >= sweep_angle - 0.001:
		var angle: float = deg_to_rad(_attack_next_ray_angle)
		var local_target: Vector3 = Vector3(sin(angle), 0.0, -cos(angle)) * reach
		for row in range(row_count):
			local_target.y = _get_grid_offset(row, row_count, attack_data.arc_height * 2.0)
			_cast_hit_ray(attack_data, camera_transform, camera_transform.origin, camera_transform * local_target)
		_attack_next_ray_angle -= spacing


## Grid of parallel rays covering the box, cast every tick of the strike so a dash can carry it into targets.
func _cast_box_rays(attack_data: MeleeAttackData, camera_transform: Transform3D) -> void:
	var reach: float = maxf(attack_data.reach, 0.01)
	var row_count: int = maxi(attack_data.ray_rows, 1)
	for column in range(row_count):
		for row in range(row_count):
			var local_origin: Vector3 = attack_data.box_offset + Vector3(
				_get_grid_offset(column, row_count, attack_data.box_size.x),
				_get_grid_offset(row, row_count, attack_data.box_size.y),
				0.0
			)
			_cast_hit_ray(
				attack_data,
				camera_transform,
				camera_transform * local_origin,
				camera_transform * (local_origin + (Vector3.FORWARD * reach))
			)


## Position of one ray in a row of count rays spread evenly across size, centered on zero.
func _get_grid_offset(index: int, count: int, size: float) -> float:
	if count <= 1:
		return 0.0
	return lerpf(-size * 0.5, size * 0.5, float(index) / float(count - 1))


## Casts one ray. It passes through hittable objects, so one swing can hit several in a line,
## and stops at anything solid that can't be hit, so attacks don't reach through walls.
func _cast_hit_ray(
	attack_data: MeleeAttackData,
	camera_transform: Transform3D,
	ray_from: Vector3,
	ray_to: Vector3
) -> void:
	var excluded_rids: Array[RID] = _get_excluded_rids()
	for _pierce in range(maxi(max_pierce_per_ray, 1)):
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			ray_from,
			ray_to,
			hit_collision_mask,
			excluded_rids
		)
		var ray_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
		if ray_hit.is_empty():
			return

		var target: Node3D = ray_hit.get("collider") as Node3D
		if not _is_hittable(target):
			return

		excluded_rids.append(ray_hit.get("rid"))
		# An empowered charge crushes every enemy it touches on the spot.
		if _is_casting_charge_hits and _charge_empowered and target.has_method(METHOD_ON_SHIELD_CRUSH):
			_crush_on_contact(target)
			continue
		# A charge picks enemies up instead of hitting them.
		if _is_casting_charge_hits and target.has_method(METHOD_START_SHIELD_CARRY):
			_try_carry_enemy(target)
			continue

		var target_id: int = target.get_instance_id()
		if _attack_hit_ids.has(target_id):
			continue

		_attack_hit_ids[target_id] = true
		var hit_info: Dictionary = _build_hit_info(attack_data, camera_transform, target, ray_hit)
		var behaviour: Node = _get_behaviour(_equipped_weapon)
		if behaviour != null and not _is_casting_charge_hits:
			hit_info = behaviour.call(&"modify_hit", hit_info, target)
		_apply_hit(attack_data, target, hit_info)


func _build_hit_info(
	attack_data: MeleeAttackData,
	camera_transform: Transform3D,
	target: Node3D,
	ray_hit: Dictionary
) -> Dictionary:
	var push_direction: Vector3 = camera_transform.basis * attack_data.impulse_direction
	if push_direction.length_squared() <= 0.0001:
		push_direction = -camera_transform.basis.z

	return {
		"position": Vector3(ray_hit.get("position", target.global_position)),
		"normal": Vector3(ray_hit.get("normal", Vector3.UP)),
		"direction": push_direction.normalized(),
		"collider": target,
		"damage": attack_data.damage * _get_damage_multiplier(attack_data),
		"weapon": _equipped_weapon,
		"attacker": player,
	}


func _get_damage_multiplier(attack_data: MeleeAttackData) -> float:
	if _attack_empowered and not _is_casting_charge_hits and attack_data == halberd_attack:
		return maxf(halberd_empowered_damage_multiplier, 0.0)
	return 1.0


func _apply_hit(attack_data: MeleeAttackData, target: Node3D, hit_info: Dictionary) -> void:
	var was_alive: bool = _is_alive(target)
	if target.has_method(METHOD_ON_MELEE_HIT):
		target.call(METHOD_ON_MELEE_HIT, hit_info)
		_notify_hit_landed(_equipped_weapon, target, hit_info, was_alive)
		if _empowered_dash_timer > 0.0 and not _is_casting_charge_hits:
			_pass_through(target)
		if not _is_casting_charge_hits:
			_trigger_hit_stop(attack_data, target)
			_trigger_hit_shake(attack_data)

	var rigid_body: RigidBody3D = target as RigidBody3D
	if rigid_body != null and attack_data.physics_impulse > 0.0:
		var hit_position: Vector3 = Vector3(hit_info.get("position", rigid_body.global_position))
		rigid_body.sleeping = false
		rigid_body.apply_impulse(
			Vector3(hit_info.get("direction", Vector3.ZERO)) * attack_data.physics_impulse,
			hit_position - rigid_body.global_position
		)

	if not _attack_has_hit:
		_attack_has_hit = true
		LoudnessManger.register_sound(attack_data.hit_loudness)
	attack_hit.emit(_equipped_weapon, hit_info)


func _is_hittable(target: Node3D) -> bool:
	if target == null:
		return false
	return target.has_method(METHOD_ON_MELEE_HIT) or target is RigidBody3D


func _get_excluded_rids() -> Array[RID]:
	var excluded_rids: Array[RID] = []
	if player != null:
		excluded_rids.append(player.get_rid())
	for enemy in _carried_enemies:
		# Check before casting: casting a freed object is an error.
		if not is_instance_valid(enemy):
			continue
		var enemy_body: CollisionObject3D = enemy as CollisionObject3D
		if enemy_body != null:
			excluded_rids.append(enemy_body.get_rid())
	return excluded_rids


## Hands are busy while climbing or hanging on a ledge.
func _is_weapon_blocked() -> bool:
	return (
		_player_bool(METHOD_IS_CLIMBING, false)
		or _player_bool(METHOD_IS_EDGE_HOLDING, false)
		or _player_bool(METHOD_IS_EDGE_PULLING_OVER, false)
	)


func _is_weapon_wheel_open() -> bool:
	var wheel: Node = get_tree().get_first_node_in_group(GROUP_WEAPON_WHEEL)
	return wheel != null and wheel.has_method(&"is_open") and bool(wheel.call(&"is_open"))


func _get_equipped_attack() -> MeleeAttackData:
	return _attacks.get(_equipped_weapon) as MeleeAttackData


## The attack timer ticks with physics; this adds the time since the last tick so the swing stays smooth.
## Freezes the enemy that was hit, and the swing too unless it already froze once this attack
## (weapons with hit_stop_every_hit freeze the swing again for every enemy).
## The frozen time is added to the weapon's recover so the combo timing isn't shortened.
func _trigger_hit_stop(attack_data: MeleeAttackData, target: Node3D) -> void:
	var freeze_time: float = maxf(attack_data.hit_stop_time, 0.0)
	if freeze_time <= 0.0:
		return

	if target.has_method(METHOD_APPLY_HIT_STOP):
		target.call(METHOD_APPLY_HIT_STOP, freeze_time)
	if _attack_hit_stop_used and not attack_data.hit_stop_every_hit:
		return

	_attack_hit_stop_used = true
	_hit_stop_timer += freeze_time
	# A lunge freezes with the swing, otherwise the moving view hides the freeze.
	if player != null and player.has_method(METHOD_PAUSE_DASH):
		player.call(METHOD_PAUSE_DASH, freeze_time)
	_recover_timers[_equipped_weapon] = get_recover_remaining(_equipped_weapon) + freeze_time


## Shakes the screen on the attack's first hit (halberd thrust, shield bash), or on every hit
## for weapons with hit_stop_every_hit (sword sweep), matching their freezes.
func _trigger_hit_shake(attack_data: MeleeAttackData) -> void:
	if attack_data.hit_screen_shake <= 0.0:
		return
	if _attack_shake_used and not attack_data.hit_stop_every_hit:
		return

	_attack_shake_used = true
	if _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
		_camera.call(METHOD_ADD_SCREEN_SHAKE, attack_data.hit_screen_shake)


func is_in_hit_stop() -> bool:
	return _hit_stop_timer > 0.0


func _get_visual_attack_progress() -> float:
	var attack_data: MeleeAttackData = _get_equipped_attack()
	if attack_data == null:
		return 0.0
	if _hit_stop_timer > 0.0:
		return clampf(_attack_timer / attack_data.get_duration(), 0.0, 1.0)

	var tick_time: float = 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	var visual_timer: float = _attack_timer + (Engine.get_physics_interpolation_fraction() * tick_time)
	return clampf(visual_timer / attack_data.get_duration(), 0.0, 1.0)


## Where a weapon that is out but still recovering is in its attack animation.
## The recover timer covers the whole attack, so its remaining time maps straight onto attack progress.
## Never earlier than the end of the strike: coming back to a weapon shows its recover, not a second swing.
func _get_visual_recover_progress() -> float:
	var attack_data: MeleeAttackData = _get_equipped_attack()
	if attack_data == null:
		return 1.0

	var tick_time: float = 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
	var remaining: float = get_recover_remaining(_equipped_weapon) - (Engine.get_physics_interpolation_fraction() * tick_time)
	var progress: float = 1.0 - (maxf(remaining, 0.0) / attack_data.get_duration())
	return clampf(progress, attack_data.get_strike_end(), 1.0)


## Places the equipped weapon: its idle pose, plus the attack, recover or brace pose,
## plus the lowered offset while it is still rising into hand.
func _apply_weapon_pose() -> void:
	if not _weapons.has(_equipped_weapon):
		return

	_pose_position = Vector3.ZERO
	_pose_rotation = Vector3.ZERO
	if _is_attacking:
		_set_attack_pose(_get_visual_attack_progress())
	elif is_recovering(_equipped_weapon):
		_set_attack_pose(_get_visual_recover_progress())
	elif _equipped_weapon == WEAPON_SHIELD:
		_set_shield_brace_pose()
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour != null:
		var extra: Array = behaviour.call(&"get_pose_offset")
		if extra.size() >= 2:
			_pose_position += Vector3(extra[0])
			_pose_rotation += Vector3(extra[1])

	var lowered_amount: float = 0.0
	if _is_equipping:
		lowered_amount = 1.0 - _ease_out(get_equip_progress())
	var lowered_rotation: Vector3 = _degrees_to_radians(equip_start_rotation_degrees) * lowered_amount

	var weapon: Node3D = _weapons[_equipped_weapon] as Node3D
	var idle_transform: Transform3D = _idle_transforms[_equipped_weapon]
	weapon.transform = Transform3D(
		Basis.from_euler(lowered_rotation) * Basis.from_euler(_pose_rotation) * idle_transform.basis,
		idle_transform.origin + _pose_position + (equip_start_position * lowered_amount)
	)


func _set_attack_pose(progress: float) -> void:
	var attack_data: MeleeAttackData = _get_equipped_attack()
	if attack_data == null:
		return

	var windup_end: float = attack_data.get_windup_end()
	var strike_end: float = attack_data.get_strike_end()
	var windup_rotation: Vector3 = _degrees_to_radians(attack_data.windup_rotation_degrees)
	var strike_rotation: Vector3 = _degrees_to_radians(attack_data.strike_rotation_degrees)
	if progress < windup_end:
		var windup_blend: float = _smooth_step(progress / maxf(windup_end, 0.001))
		_pose_position = attack_data.windup_position * windup_blend
		_pose_rotation = windup_rotation * windup_blend
	elif progress < strike_end:
		var strike_blend: float = _ease_out(attack_data.get_strike_progress(progress))
		_pose_position = attack_data.windup_position.lerp(attack_data.strike_position, strike_blend)
		_pose_rotation = windup_rotation.lerp(strike_rotation, strike_blend)
	else:
		var recover_blend: float = _smooth_step((progress - strike_end) / maxf(1.0 - strike_end, 0.001))
		_pose_position = attack_data.strike_position * (1.0 - recover_blend)
		_pose_rotation = strike_rotation * (1.0 - recover_blend)


func _register_weapon(weapon_id: StringName, weapon_path: NodePath, attack_data: MeleeAttackData) -> void:
	var weapon: Node3D = get_node_or_null(weapon_path) as Node3D
	if weapon == null:
		push_warning("Melee weapon node not found: %s" % weapon_path)
		return

	_weapons[weapon_id] = weapon
	_idle_transforms[weapon_id] = weapon.transform
	_attacks[weapon_id] = attack_data
	weapon.visible = false


## Registers every child weapon that has a behaviour script (weapon_behaviour.gd), in scene order.
func _register_behaviour_weapons() -> void:
	for child in get_children():
		if not child.has_method(METHOD_GET_PRESS_MODE):
			continue
		var weapon_id: StringName = StringName(child.get(&"weapon_id"))
		if weapon_id == &"" or _weapons.has(weapon_id):
			continue
		_register_weapon(weapon_id, get_path_to(child), child.get(&"attack_data") as MeleeAttackData)
		_behaviours[weapon_id] = child
		child.call(&"setup", self)


func _get_behaviour(weapon_id: StringName) -> Node:
	return _behaviours.get(weapon_id) as Node


func _uses_strike_rays(weapon_id: StringName) -> bool:
	if weapon_id == WEAPON_CROSSBOW:
		return false
	var behaviour: Node = _get_behaviour(weapon_id)
	return behaviour == null or bool(behaviour.call(&"uses_strike_rays"))


func _is_alive(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return not (target.has_method(METHOD_IS_DEAD) and bool(target.call(METHOD_IS_DEAD)))


func _notify_hit_landed(weapon_id: StringName, target: Node3D, hit_info: Dictionary, was_alive: bool) -> void:
	var behaviour: Node = _get_behaviour(weapon_id)
	if behaviour == null:
		return
	var killed: bool = was_alive and not _is_alive(target)
	behaviour.call(&"on_hit_landed", target, hit_info, killed)


func _hide_all_weapons() -> void:
	for weapon_id in _weapons:
		var weapon: Node3D = _weapons[weapon_id] as Node3D
		weapon.visible = false
		weapon.transform = _idle_transforms[weapon_id]


func _set_pistol_holstered(holstered: bool) -> void:
	if _pistol == null or not _pistol.has_method(METHOD_SET_HOLSTERED):
		return
	_pistol.call(METHOD_SET_HOLSTERED, holstered)


func _ease_out(value: float) -> float:
	var clean_value: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clean_value, 3.0)


func _smooth_step(value: float) -> float:
	var clean_value: float = clampf(value, 0.0, 1.0)
	return clean_value * clean_value * (3.0 - (2.0 * clean_value))


func _disable_shadows(node: Node) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for child in node.get_children():
		_disable_shadows(child)


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees_value.x), deg_to_rad(degrees_value.y), deg_to_rad(degrees_value.z))


func _player_float(method_name: StringName, fallback: float) -> float:
	if player == null or not player.has_method(method_name):
		return fallback
	return float(player.call(method_name))


func _player_bool(method_name: StringName, fallback: bool) -> bool:
	if player == null or not player.has_method(method_name):
		return fallback
	return bool(player.call(method_name))


# --- Empowered attacks (S rank) -----------------------------------------------------------------

## Launches the slash wave from in front of the camera, along the camera's facing (pitch limited).
func _launch_sword_wave() -> void:
	if _camera == null or player == null:
		return
	var forward: Vector3 = -_camera.global_transform.basis.z
	var flat: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() <= 0.0001:
		flat = -Basis(Vector3.UP, player.rotation.y).z
	flat = flat.normalized()
	var pitch: float = clampf(asin(clampf(forward.y, -1.0, 1.0)), deg_to_rad(sword_wave_pitch_limits.x), deg_to_rad(sword_wave_pitch_limits.y))
	var direction: Vector3 = (flat * cos(pitch) + Vector3.UP * sin(pitch)).normalized()

	var wave: Node3D = Node3D.new()
	wave.set_script(SwordWave)
	wave.set(&"speed", sword_wave_speed)
	wave.set(&"max_distance", sword_wave_range)
	wave.set(&"width", sword_wave_width)
	wave.set(&"collision_mask", hit_collision_mask)
	wave.set(&"damage", sword_wave_damage)
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(wave)
	var start: Vector3 = _camera.global_position + Vector3.DOWN * 0.45 + flat * 1.2
	wave.call(&"launch", start, direction, self, _get_excluded_rids())


## Called by a sword wave for everything it cuts. Works like a sword hit without the hit-stop (the
## swing is long over), so sounds and the combo meter count it.
func on_sword_wave_hit(target: Node3D, hit_info: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	hit_info["weapon"] = WEAPON_BROADSWORD
	hit_info["attacker"] = player
	if target.has_method(METHOD_ON_MELEE_HIT):
		target.call(METHOD_ON_MELEE_HIT, hit_info)
	var rigid_body: RigidBody3D = target as RigidBody3D
	if rigid_body != null and broadsword_attack != null and broadsword_attack.physics_impulse > 0.0:
		rigid_body.sleeping = false
		rigid_body.apply_central_impulse(Vector3(hit_info.get("direction", Vector3.ZERO)) * broadsword_attack.physics_impulse)
	attack_hit.emit(WEAPON_BROADSWORD, hit_info)


## The empowered halberd dash goes through the enemies it hits instead of stopping against them.
func _pass_through(target: Node3D) -> void:
	var body: PhysicsBody3D = target as PhysicsBody3D
	if body == null or player == null or _dash_passed_enemies.has(target):
		return
	player.add_collision_exception_with(body)
	body.add_collision_exception_with(player)
	_dash_passed_enemies.append(target)


## Ends the pass-through a moment after the dash, once the player is clear of the enemies.
func _update_dash_pass_through(delta: float) -> void:
	if _dash_passed_enemies.is_empty():
		return
	if _empowered_dash_timer > 0.0:
		_dash_pass_timer = 0.3
		return
	_dash_pass_timer -= delta
	if _dash_pass_timer > 0.0:
		return
	for enemy in _dash_passed_enemies:
		# Enemies the lunge killed are already freed; casting a freed object is an error, so check first.
		if not is_instance_valid(enemy) or player == null:
			continue
		var body: PhysicsBody3D = enemy as PhysicsBody3D
		if body != null:
			player.remove_collision_exception_with(body)
			body.remove_collision_exception_with(player)
	_dash_passed_enemies.clear()


## Empowered charge: the enemy breaks immediately (heavy ones too) and the charge carries on.
func _crush_on_contact(target: Node3D) -> void:
	if target.has_method(&"is_dead") and bool(target.call(&"is_dead")):
		return
	var heading: Vector3 = _get_charge_heading()
	# on_shield_crush throws the pieces against "direction" (back off a wall); here they should fly
	# on ahead of the charge, so it gets the reversed heading.
	target.call(METHOD_ON_SHIELD_CRUSH, {
		"position": target.global_position,
		"normal": heading,
		"direction": -heading,
		"collider": target,
		"weapon": WEAPON_SHIELD,
		"attacker": player,
	})
	LoudnessManger.register_sound(shield_crush_loudness * 0.5)
	if _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
		_camera.call(METHOD_ADD_SCREEN_SHAKE, empowered_charge_crush_screen_shake)
	shield_carry_crushed.emit(1)


## A pulsing glow over the weapons while attacks are empowered.
func _update_empowered_glow(delta: float) -> void:
	var should_glow: bool = is_empowered()
	if should_glow != _is_glowing:
		_is_glowing = should_glow
		if _glow_material == null:
			_glow_material = StandardMaterial3D.new()
			_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_glow_material.albedo_color = empowered_glow_color
		for weapon_id in _weapons.keys():
			_set_overlay(_weapons[weapon_id] as Node, _glow_material if _is_glowing else null)
	if _is_glowing:
		_glow_time += delta
		var pulse: float = 0.65 + 0.35 * sin(_glow_time * TAU * empowered_glow_pulse_speed)
		_glow_material.albedo_color = Color(empowered_glow_color, empowered_glow_color.a * pulse)


func _set_overlay(node: Node, overlay: Material) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.material_overlay = overlay
	for child in node.get_children():
		_set_overlay(child, overlay)


# --- Crossbow ------------------------------------------------------------------------------------

## Fires a bolt from just right of the camera toward whatever the crosshair is on. Damage by rank;
## explosive at empowered_rank (S).
func _fire_crossbow_bolt(rank: int) -> void:
	if _camera == null or player == null or rank < 0:
		return
	var camera_transform: Transform3D = _camera.global_transform.orthonormalized()
	var forward: Vector3 = -camera_transform.basis.z
	var excluded: Array[RID] = _get_excluded_rids()

	# Aim at the crosshair: find what the centre of the screen points at, then fly there from the bow.
	var aim_point: Vector3 = camera_transform.origin + forward * 200.0
	var aim_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera_transform.origin, aim_point, hit_collision_mask, excluded)
	var aim_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(aim_query)
	if not aim_hit.is_empty():
		aim_point = Vector3(aim_hit.get("position", aim_point))
	var start: Vector3 = camera_transform.origin + forward * 0.6 + camera_transform.basis.x * 0.12 - camera_transform.basis.y * 0.1
	if aim_point.distance_to(camera_transform.origin) < 1.5:
		start = camera_transform.origin
	var direction: Vector3 = (aim_point - start).normalized()

	var explosive: bool = rank >= empowered_rank
	var bolt: Node3D = Node3D.new()
	bolt.set_script(CrossbowBolt)
	bolt.set(&"speed", crossbow_bolt_speed)
	bolt.set(&"collision_mask", hit_collision_mask)
	bolt.set(&"damage", crossbow_rank_damage[clampi(rank, 0, crossbow_rank_damage.size() - 1)] if not crossbow_rank_damage.is_empty() else 1.0)
	bolt.set(&"physics_impulse", crossbow_bolt_impulse)
	bolt.set(&"is_explosive", explosive)
	bolt.set(&"explosion_radius", crossbow_explosion_radius)
	bolt.set(&"explosion_damage", crossbow_explosion_damage)
	bolt.set(&"explosion_edge_damage_ratio", crossbow_explosion_edge_damage_ratio)
	bolt.set(&"explosion_impulse", crossbow_explosion_impulse)
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(bolt)
	bolt.call(&"launch", start, direction, self, excluded)
	crossbow_fired.emit(rank, explosive)


## Called by a bolt for what it hits (directly or with its explosion).
func on_crossbow_bolt_hit(target: Node3D, hit_info: Dictionary, impulse: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	hit_info["weapon"] = WEAPON_CROSSBOW
	hit_info["attacker"] = player
	if target.has_method(METHOD_ON_MELEE_HIT):
		target.call(METHOD_ON_MELEE_HIT, hit_info)
		if target.has_method(METHOD_APPLY_HIT_STOP):
			target.call(METHOD_APPLY_HIT_STOP, maxf(crossbow_hit_stop_time, 0.0))
		if _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
			var rank: int = maxi(_crossbow_rank, 0)
			_camera.call(METHOD_ADD_SCREEN_SHAKE, crossbow_hit_screen_shake + crossbow_hit_screen_shake_per_rank * float(rank))
	var rigid_body: RigidBody3D = target as RigidBody3D
	if rigid_body != null and impulse > 0.0:
		rigid_body.sleeping = false
		rigid_body.apply_central_impulse(Vector3(hit_info.get("direction", Vector3.ZERO)) * impulse)
	if crossbow_attack != null:
		LoudnessManger.register_sound(crossbow_attack.hit_loudness)
	attack_hit.emit(WEAPON_CROSSBOW, hit_info)


## Called by an explosive bolt when it blows up.
func on_crossbow_bolt_explosion(center: Vector3, radius: float, hit_count: int) -> void:
	if _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
		_camera.call(METHOD_ADD_SCREEN_SHAKE, crossbow_explosion_screen_shake)
	LoudnessManger.register_sound(crossbow_explosion_loudness)
	crossbow_explosion.emit(center, radius, hit_count)


# --- Services for behaviour weapons (Scripts/Weapons/Behaviours) ---------------------------------

func get_player() -> CharacterBody3D:
	return player


func get_camera() -> Node3D:
	return _camera


func get_hit_collision_mask() -> int:
	return hit_collision_mask


## The player and carried enemies, for rays that shouldn't hit them.
func get_excluded_rids() -> Array[RID]:
	return _get_excluded_rids()


## Starts the equipped weapon's attack, as a click would (windup -> strike -> recover).
func start_attack() -> bool:
	return attack()


## Counts something that isn't a normal attack (dagger stream, hook yank, pounce) as an attack with
## weapon_id: the combo rule and the combo meter see it, and the swing sound plays.
func register_custom_attack(weapon_id: StringName) -> void:
	_register_weapon_use(weapon_id)
	attack_started.emit(weapon_id)


## Sets how long weapon_id can't attack, as if an attack had just started.
func set_recover(weapon_id: StringName, seconds: float) -> void:
	_recover_timers[weapon_id] = maxf(seconds, 0.0)


## Lands a hit that didn't come from the hit rays (shockwaves, thrown weapons, pounces). Works like a
## ray hit: the behaviour's modify_hit / on_hit_landed, enemy hit-stop, shake, crate push, loudness
## and attack_hit (sounds, combo meter). hit_info needs at least direction and damage.
func deliver_hit(weapon_id: StringName, target: Node3D, hit_info: Dictionary, hit_stop_time: float = 0.0, screen_shake: float = 0.0, impulse: float = 0.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	hit_info["weapon"] = weapon_id
	hit_info["attacker"] = player
	hit_info["collider"] = target
	if not hit_info.has("position"):
		hit_info["position"] = target.global_position
	if not hit_info.has("normal"):
		hit_info["normal"] = Vector3.UP
	var behaviour: Node = _get_behaviour(weapon_id)
	if behaviour != null:
		hit_info = behaviour.call(&"modify_hit", hit_info, target)
	var was_alive: bool = _is_alive(target)
	if target.has_method(METHOD_ON_MELEE_HIT):
		if not was_alive:
			return
		target.call(METHOD_ON_MELEE_HIT, hit_info)
		if hit_stop_time > 0.0 and is_instance_valid(target) and target.has_method(METHOD_APPLY_HIT_STOP):
			target.call(METHOD_APPLY_HIT_STOP, hit_stop_time)
		add_screen_shake(screen_shake)
		_notify_hit_landed(weapon_id, target, hit_info, was_alive)
	var rigid_body: RigidBody3D = target as RigidBody3D
	if rigid_body != null and impulse > 0.0:
		rigid_body.sleeping = false
		rigid_body.apply_central_impulse(Vector3(hit_info.get("direction", Vector3.ZERO)) * impulse)
	attack_hit.emit(weapon_id, hit_info)


## Replaces the attack data used by weapon_id from its next attack on (sickle and dagger alternate hands).
func set_attack_data(weapon_id: StringName, data: MeleeAttackData) -> void:
	if _attacks.has(weapon_id) and data != null:
		_attacks[weapon_id] = data


## Hit callback for projectiles thrown by behaviour weapons (crossbow_bolt.gd with report_method set
## to this). hit_info["weapon"] says whose it is.
func on_weapon_projectile_hit(target: Node3D, hit_info: Dictionary, impulse: float) -> void:
	var weapon_id: StringName = StringName(hit_info.get("weapon", WEAPON_NONE))
	deliver_hit(weapon_id, target, hit_info, float(hit_info.get("hit_stop", 0.03)), float(hit_info.get("shake", 0.05)), impulse)


func add_screen_shake(amount: float) -> void:
	if amount > 0.0 and _camera != null and _camera.has_method(METHOD_ADD_SCREEN_SHAKE):
		_camera.call(METHOD_ADD_SCREEN_SHAKE, amount)


func add_camera_kick(rotation_degrees_value: Vector3) -> void:
	if _camera != null and _camera.has_method(METHOD_ADD_RECOIL_IMPULSE):
		_camera.call(METHOD_ADD_RECOIL_IMPULSE, Vector3.ZERO, _degrees_to_radians(rotation_degrees_value))


## Adds a node to the level (projectiles, effects), so it doesn't move with the camera.
func spawn_in_world(node: Node) -> void:
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(node)


## The living enemy closest to the crosshair within max_angle_degrees of it and max_distance metres,
## with a clear line from the camera to its chest. null if none.
func find_aimed_enemy(max_angle_degrees: float, max_distance: float, ignore: Array = []) -> Node3D:
	if _camera == null:
		return null
	var camera_transform: Transform3D = _camera.global_transform.orthonormalized()
	var forward: Vector3 = -camera_transform.basis.z
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best: Node3D = null
	var best_angle: float = deg_to_rad(maxf(max_angle_degrees, 0.0))
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node3D = node as Node3D
		if enemy == null or ignore.has(enemy) or not _is_alive(enemy):
			continue
		var chest: Vector3 = enemy.global_position + Vector3.UP * 1.0
		var to_enemy: Vector3 = chest - camera_transform.origin
		var distance: float = to_enemy.length()
		if distance > max_distance or distance <= 0.01:
			continue
		var angle: float = forward.angle_to(to_enemy / distance)
		if angle > best_angle:
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera_transform.origin, chest, hit_collision_mask, _get_excluded_rids())
		var blocker: Dictionary = space.intersect_ray(query)
		if not blocker.is_empty() and blocker.get("collider") != enemy and not (blocker.get("collider") as Node).is_in_group(&"enemies"):
			continue
		best = enemy
		best_angle = angle
	return best


## Speed multiplier the weapon in hand puts on the player (the war hammer's charge slows you).
func get_move_speed_multiplier() -> float:
	var behaviour: Node = _get_behaviour(_equipped_weapon)
	if behaviour == null:
		return 1.0
	return clampf(float(behaviour.call(&"get_move_speed_multiplier")), 0.0, 1.0)


## Every behaviour puts itself back (thrown weapons return). Called on run restart and level change.
func reset_behaviours() -> void:
	for behaviour in _behaviours.values():
		behaviour.call(&"reset_behaviour")
