extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## Talons: parkour predator.
## Click: fast claw rakes; every third rake in a row (within rake_chain_time of the last one) is a
## heavier rend (rend_attack_data: more damage, a longer freeze, a bigger swing).
## Passive while in hand (player.gd pushes it to the autoloads every tick): wall runs last longer
## (MovementWallRun.talon_duration_multiplier), climbs are faster (MovementClimb.talon_climb_speed_
## multiplier) and any wall can be grabbed mid-air (MovementClimb.talon_grab_any_wall).
## Hold: pounce onto the enemy nearest the crosshair (pounce_cone_degrees, pounce_range): the player
## leaps along an arc to it (player.start_pounce, following it if it moves) and lands a hit on
## contact. Nothing aimed at: no pounce.
## S rank: after a pounce lands it chains to the nearest other enemy within chain_range, up to
## chain_count more times.

@export_group("Rakes")
## Attack data for the rend (every third rake).
@export var rend_attack_data: MeleeAttackData
## Rakes further apart than this start the count again (s).
@export var rake_chain_time: float = 1.5

@export_group("Pounce")
## Enemies within this angle of the crosshair and this range can be pounced on.
@export var pounce_cone_degrees: float = 12.0
@export var pounce_range: float = 12.0
## The leap ends this far short of the enemy (m).
@export var pounce_stop_distance: float = 1.0
## Leap time: base plus this much per metre (s), and how high the arc goes (m).
@export var pounce_base_time: float = 0.25
@export var pounce_time_per_meter: float = 0.03
@export var pounce_arc_height: float = 1.2
## Contact distance (horizontal, m), damage, freeze and screen shake of the landing hit.
@export var pounce_hit_distance: float = 1.6
@export var pounce_damage: float = 3.0
@export var pounce_hit_stop: float = 0.12
@export_range(0.0, 1.0) var pounce_screen_shake: float = 0.35

@export_group("Chain (S Rank)")
## Extra pounces after the first at S rank, and how far the next enemy may be (m).
@export var chain_count: int = 2
@export var chain_range: float = 10.0

var _rake_count: int = 0
var _last_rake_time: float = -100.0
var _is_rend: bool = false
var _pounce_target: Node3D
var _chains_left: int = 0
var _pounce_hit: Array = []
var _pounce_hits_total: int = 0


func setup(owner_weapons: Node) -> void:
	super.setup(owner_weapons)
	weapons.connect(&"attack_started", _on_attack_started)


func is_busy() -> bool:
	return is_pouncing()


func is_pouncing() -> bool:
	var player: Node3D = weapons.call(&"get_player") as Node3D
	return _pounce_target != null and player != null and bool(player.call(&"is_pouncing"))


## For tests: the last attack was a rend; total pounce hits so far.
func is_rend() -> bool:
	return _is_rend


func get_pounce_hits() -> int:
	return _pounce_hits_total


## Count rakes; the third in a row uses the rend data.
func _on_attack_started(started_weapon: StringName) -> void:
	if started_weapon != weapon_id or _pounce_target != null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_rake_time > rake_chain_time:
		_rake_count = 0
	_last_rake_time = now
	_rake_count += 1
	_is_rend = _rake_count % 3 == 0
	var data: MeleeAttackData = rend_attack_data if _is_rend and rend_attack_data != null else attack_data
	weapons.call(&"set_attack_data", weapon_id, data)
	# The rend's data is used for this attack's timing too: the recover was set from the old data.
	if data != null:
		weapons.call(&"set_recover", weapon_id, data.get_duration())


func on_hold_started() -> bool:
	var target: Node3D = weapons.call(&"find_aimed_enemy", pounce_cone_degrees, pounce_range) as Node3D
	if target == null:
		return false
	_chains_left = maxi(chain_count, 0) if is_empowered() else 0
	_pounce_hit.clear()
	if _start_pounce(target):
		weapons.call(&"register_custom_attack", weapon_id)
	# The pounce runs on its own; letting go of attack doesn't stop it.
	return false


func on_unequipped() -> void:
	_end_pounce()


func reset_behaviour() -> void:
	_end_pounce()


func _start_pounce(target: Node3D) -> bool:
	var player: Node3D = weapons.call(&"get_player") as Node3D
	if player == null or not player.has_method(&"start_pounce"):
		return false
	var end_point: Vector3 = _get_landing_point(player, target)
	var distance: float = player.global_position.distance_to(end_point)
	var duration: float = pounce_base_time + distance * pounce_time_per_meter
	if not bool(player.call(&"start_pounce", end_point, duration, pounce_arc_height)):
		return false
	_pounce_target = target
	return true


func _get_landing_point(player: Node3D, target: Node3D) -> Vector3:
	var flat: Vector3 = target.global_position - player.global_position
	flat.y = 0.0
	var direction: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else -player.global_basis.z
	return target.global_position - direction * pounce_stop_distance


func behaviour_physics_process(_delta: float) -> void:
	if _pounce_target == null:
		return
	var player: Node3D = weapons.call(&"get_player") as Node3D
	if player == null:
		_end_pounce()
		return
	if not is_instance_valid(_pounce_target) or (_pounce_target.has_method(&"is_dead") and bool(_pounce_target.call(&"is_dead"))):
		_end_pounce()
		return
	player.call(&"set_pounce_end", _get_landing_point(player, _pounce_target))
	var offset: Vector3 = _pounce_target.global_position - player.global_position
	var close: bool = Vector2(offset.x, offset.z).length() <= pounce_hit_distance and absf(offset.y) < 2.5
	if close:
		_land_pounce(player)
	elif not bool(player.call(&"is_pouncing")):
		# The leap ended without reaching it (blocked).
		_end_pounce()


func _land_pounce(player: Node3D) -> void:
	var target: Node3D = _pounce_target
	_pounce_hit.append(target)
	_pounce_hits_total += 1
	var direction: Vector3 = (target.global_position - player.global_position)
	direction.y = 0.0
	weapons.call(&"deliver_hit", weapon_id, target, {
		"position": target.global_position + Vector3.UP,
		"direction": (direction.normalized() + Vector3.UP * 0.2).normalized(),
		"damage": pounce_damage,
	}, pounce_hit_stop, pounce_screen_shake)
	player.call(&"stop_pounce")
	_pounce_target = null
	if _chains_left <= 0:
		return
	var next: Node3D = _find_chain_target(player)
	if next == null:
		return
	_chains_left -= 1
	_start_pounce(next)


func _find_chain_target(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_distance: float = chain_range
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Node3D = node as Node3D
		if enemy == null or _pounce_hit.has(enemy):
			continue
		if enemy.has_method(&"is_dead") and bool(enemy.call(&"is_dead")):
			continue
		var distance: float = enemy.global_position.distance_to(player.global_position)
		if distance > best_distance:
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, enemy.global_position + Vector3.UP, int(weapons.call(&"get_hit_collision_mask")), weapons.call(&"get_excluded_rids"))
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty() and hit.get("collider") != enemy and not (hit.get("collider") as Node).is_in_group(&"enemies"):
			continue
		best = enemy
		best_distance = distance
	return best


func _end_pounce() -> void:
	_pounce_target = null
	_chains_left = 0
	var player: Node3D = weapons.call(&"get_player") as Node3D if weapons != null else null
	if player != null and player.has_method(&"stop_pounce") and bool(player.call(&"is_pouncing")):
		player.call(&"stop_pounce")
