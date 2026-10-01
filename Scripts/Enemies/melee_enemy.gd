extends "res://Scripts/Enemies/dummy_enemy.gd"

## Enemy that walks at the player and hits them.
## Builds on the training dummy, so damage, knockback, shield carry, crush and breaking all work the same.
## Behavior: stand idle until it notices the player, walk straight at them, and when close enough
## lean back (windup), lunge (strike) and rest (recover) before moving again.
## Getting hit or thrown staggers it for a moment and cancels an attack that hasn't landed yet.
## Pathfinding comes from the level: if a node in group level_navigation exists (the generated level),
## the enemy asks it which way to walk, so it follows corridors around corners. Without one it walks
## in a straight line and slides along whatever is in the way.
## This is also the base for every other enemy type: ranged ones set preferred_min_distance to
## hold their ground at range, attack_requires_line_of_sight, and override _strike() and the
## windup hooks (_on_windup_started, _on_windup_cancelled).

signal attack_started
## The windup finished and the attack happens now (swing, throw or shot), whether or not it lands.
signal attack_struck
## A windup ended without attacking (stagger, carry, death, losing the player).
signal attack_cancelled
signal attack_landed(damage: float)
## The enemy jumped at an obstacle this tall (metres above its feet).
signal jumped(obstacle_height: float)

enum State {
	IDLE,
	CHASE,
	WINDUP,
	RECOVER,
	STAGGER,
}

## The player joins this group in player.gd.
const GROUP_PLAYER: StringName = &"player"
const METHOD_TAKE_DAMAGE: StringName = &"take_damage"
## The generated level joins this group and answers get_navigation_direction(from, to).
const GROUP_LEVEL_NAVIGATION: StringName = &"level_navigation"
const METHOD_GET_NAVIGATION_DIRECTION: StringName = &"get_navigation_direction"

@export_group("Awareness")
## The enemy notices the player inside this distance, if nothing solid is in between.
@export var notice_range: float = 22.0
## Once chasing, the enemy gives up when the player is further away than this.
@export var lose_range: float = 40.0
## Height above the feet the line-of-sight ray starts and ends at.
@export var sight_height: float = 1.3
## Physics layers that block sight. Matches the level geometry layer.
@export_flags_3d_physics var sight_collision_mask: int = 1

@export_group("Movement")
## Walking speed while chasing. The player walks at 4.7 and sprints at 12.8.
@export var move_speed: float = 4.0
## Speed gained per second while walking up to move_speed, and lost per second when stopping.
@export var acceleration: float = 22.0
## Degrees per second the enemy can turn to face the player.
@export var turn_speed_degrees: float = 420.0
## Enemies closer together than this push each other apart, so they spread around the player.
@export var separation_distance: float = 1.1
## Speed of that push at full overlap.
@export var separation_speed: float = 2.4

@export_group("Positioning")
## Ranged enemies back away when the player is closer than this. 0 means always close in (melee).
@export var preferred_min_distance: float = 0.0
## Ranged enemies stop walking in once the player is within this share of attack_range.
@export_range(0.1, 1.0) var ranged_approach_ratio: float = 0.85
## Walking speed multiplier while backing away.
@export_range(0.0, 1.0) var retreat_speed_multiplier: float = 0.7
## A ranged enemy that is too close doesn't attack while it backs away, unless it has been
## backing away this many seconds (cornered) — then it attacks anyway.
@export var max_retreat_time_before_attacking: float = 1.5

@export_group("Attack")
## The enemy stops and starts an attack when the player is this close.
@export var attack_range: float = 1.7
## Only start an attack when nothing solid is between the enemy and the player (for ranged enemies).
@export var attack_requires_line_of_sight: bool = false
## The strike still lands if the player is within this distance when the windup ends.
@export var attack_hit_range: float = 2.2
## The strike misses if the player is further than this to the side of where the enemy faces.
@export_range(0.0, 180.0) var attack_hit_angle_degrees: float = 70.0
## The strike misses if the player's feet are this much higher or lower than the enemy's.
@export var attack_max_height_difference: float = 1.4
## Damage dealt to the player.
@export var attack_damage: float = 10.0
## Seconds the enemy leans back before striking. This is the player's time to react.
@export var attack_windup_time: float = 0.5
## Seconds the enemy rests after a strike before it moves again.
@export var attack_recover_time: float = 0.75
## Turning speed multiplier during the windup, so sidestepping a strike is possible.
@export_range(0.0, 1.0) var attack_windup_turn_multiplier: float = 0.25

@export_group("Jumping")
## Lets the enemy jump onto boxes, platforms and raised floors it runs into while chasing.
@export var can_jump: bool = true
## Tallest obstacle the enemy will jump onto, in metres. Arena platforms are 2.2 m.
@export var max_jump_height: float = 2.6
## Obstacles lower than this are ignored (small bumps; ramps and stairs are walked).
@export var min_jump_height: float = 0.3
## Extra height above the obstacle the jump aims for, so the feet clear the edge.
@export var jump_clearance: float = 0.5
## How far ahead of the enemy's centre the obstacle is looked for.
@export var jump_probe_distance: float = 0.9
## Seconds before the enemy can jump again after landing.
@export var jump_cooldown: float = 0.7
## Horizontal speed during the jump, as a share of move_speed.
@export var jump_forward_speed_multiplier: float = 0.9

@export_group("Stagger")
## Seconds the enemy is stunned after being hit.
@export var hit_stagger_time: float = 0.4
## Seconds the enemy is stunned after being thrown off a shield.
@export var throw_stagger_time: float = 0.9
## Seconds a heavy enemy is stunned when a shield charge slams into it.
@export var charge_impact_stagger_time: float = 1.2
## How far the body rocks back while staggered, in degrees.
@export var stagger_lean_degrees: float = 12.0

@export_group("Attack Animation")
## How far the body leans back at the end of the windup, in degrees.
@export var windup_lean_degrees: float = 18.0
## How far the body lunges forward on the strike, in degrees.
@export var strike_lean_degrees: float = 26.0
## How quickly the lean follows its target.
@export var lean_lerp_speed: float = 20.0

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _target: Node3D
var _lean: float = 0.0
var _retreat_timer: float = 0.0
var _is_alerted: bool = false
var _navigation: Node
var _jump_cooldown_timer: float = 0.0
var _jump_assist_timer: float = 0.0
var _jump_direction: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _is_dead or _is_carried:
		if _is_dead and _state == State.WINDUP:
			_set_state(State.IDLE)
		_lean = 0.0
		_apply_lean()


func get_state() -> State:
	return _state


func is_attacking() -> bool:
	return _state == State.WINDUP or _state == State.RECOVER


## Makes the enemy hunt the player right away and keep hunting: it never goes back to idle because
## the player is far away or out of sight. Level sections call this on every enemy they spawn.
func alert() -> void:
	_is_alerted = true
	_update_target()
	if _state == State.IDLE:
		_set_state(State.CHASE)


func is_alerted() -> bool:
	return _is_alerted


func on_melee_hit(hit_info: Dictionary) -> void:
	super.on_melee_hit(hit_info)
	if not _is_dead:
		_start_stagger(hit_stagger_time)


func start_shield_carry(carrier: PhysicsBody3D) -> void:
	super.start_shield_carry(carrier)
	if _is_carried:
		_set_state(State.STAGGER, throw_stagger_time)


func end_shield_carry(release_velocity: Vector3) -> void:
	super.end_shield_carry(release_velocity)
	_start_stagger(throw_stagger_time)


func on_shield_charge_impact(hit_info: Dictionary) -> void:
	super.on_shield_charge_impact(hit_info)
	if not _is_dead and not _is_carried:
		_start_stagger(charge_impact_stagger_time)


## Called by the base script every physics tick while alive and not carried.
func _update_horizontal_velocity(delta: float) -> void:
	_state_timer = maxf(_state_timer - delta, 0.0)
	_jump_assist_timer = maxf(_jump_assist_timer - delta, 0.0)
	if is_on_floor() and _jump_assist_timer <= 0.0:
		_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)
	_update_target()
	if _state == State.CHASE and _is_too_close():
		_retreat_timer += delta
	else:
		_retreat_timer = 0.0
	_update_state()

	var desired_velocity: Vector3 = Vector3.ZERO
	var lean_target: float = 0.0
	match _state:
		State.CHASE:
			desired_velocity = _get_chase_velocity()
			_turn_toward_target(delta, 1.0)
			_try_jump(desired_velocity)
		State.WINDUP:
			_turn_toward_target(delta, attack_windup_turn_multiplier)
			var windup_progress: float = 1.0 - (_state_timer / maxf(attack_windup_time, 0.001))
			lean_target = deg_to_rad(windup_lean_degrees) * clampf(windup_progress, 0.0, 1.0)
		State.STAGGER:
			lean_target = deg_to_rad(stagger_lean_degrees)
		State.RECOVER:
			# Lunge forward right after the strike, then straighten up again.
			var recover_progress: float = 1.0 - (_state_timer / maxf(attack_recover_time, 0.001))
			lean_target = -deg_to_rad(strike_lean_degrees) * clampf(1.0 - (recover_progress * 2.5), 0.0, 1.0)

	if _state == State.STAGGER:
		# Staggered enemies slide like the dummy, so knockback and throws carry them properly.
		super._update_horizontal_velocity(delta)
		_jump_assist_timer = 0.0
	elif _jump_assist_timer > 0.0 and not is_on_floor():
		# Mid-jump: keep pushing forward so the enemy carries over the edge it jumped at,
		# instead of losing its speed against the side and dropping back down.
		var jump_speed: float = maxf(move_speed, 0.0) * maxf(jump_forward_speed_multiplier, 0.0)
		velocity.x = _jump_direction.x * jump_speed
		velocity.z = _jump_direction.z * jump_speed
	else:
		var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		var blend_speed: float = acceleration if is_on_floor() else air_friction
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, maxf(blend_speed, 0.0) * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z

	var lean_blend: float = 1.0 - exp(-maxf(lean_lerp_speed, 0.001) * delta)
	_lean = lerpf(_lean, lean_target, lean_blend)
	_apply_lean()


## Jumps when the enemy is pushing into something it can get on top of: a box, a platform edge, a
## raised floor. Walls taller than max_jump_height (and other enemies) never trigger it.
func _try_jump(desired_velocity: Vector3) -> void:
	if not can_jump or _jump_cooldown_timer > 0.0 or not is_on_floor() or not is_on_wall():
		return
	var direction: Vector3 = Vector3(desired_velocity.x, 0.0, desired_velocity.z)
	if direction.length_squared() <= 0.01:
		return
	direction = direction.normalized()
	var wall_normal: Vector3 = get_wall_normal()
	wall_normal.y = 0.0
	if wall_normal.length_squared() <= 0.001 or direction.dot(-wall_normal.normalized()) < 0.35:
		return

	var obstacle_height: float = _probe_obstacle_height(direction)
	if obstacle_height < min_jump_height or obstacle_height > max_jump_height:
		return

	var gravity: float = WorldBasicRules.get_gravity()
	var jump_speed: float = sqrt(2.0 * gravity * (obstacle_height + maxf(jump_clearance, 0.0)))
	velocity.y = jump_speed
	_jump_direction = direction
	_jump_assist_timer = (jump_speed / maxf(gravity, 0.001)) + 0.3
	_jump_cooldown_timer = maxf(jump_cooldown, 0.0)
	jumped.emit(obstacle_height)


## Height of the top of whatever is just ahead, relative to the feet. Returns -1 when the way ahead
## is blocked even at max_jump_height (a real wall) or when the obstacle is another enemy.
func _probe_obstacle_height(direction: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var excluded: Array[RID] = [get_rid()]
	# The player standing on the box must not count as part of it.
	var target_body: CollisionObject3D = _target as CollisionObject3D
	if target_body != null and is_instance_valid(target_body):
		excluded.append(target_body.get_rid())
	var top: float = global_position.y + maxf(max_jump_height, 0.0) + maxf(jump_clearance, 0.0)
	var probe: Vector3 = direction * maxf(jump_probe_distance, 0.1)

	# Something still in the way above the highest jump: too tall.
	var high_from: Vector3 = Vector3(global_position.x, top, global_position.z)
	var high_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(high_from, high_from + probe, collision_mask, excluded)
	if not space.intersect_ray(high_query).is_empty():
		return -1.0

	var down_from: Vector3 = high_from + probe
	var down_to: Vector3 = Vector3(down_from.x, global_position.y - 0.1, down_from.z)
	var down_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(down_from, down_to, collision_mask, excluded)
	var hit: Dictionary = space.intersect_ray(down_query)
	if hit.is_empty():
		return -1.0
	var collider: Node = hit.get("collider") as Node
	if collider != null and collider.is_in_group(GROUP_ENEMIES):
		return -1.0
	return Vector3(hit.get("position", global_position)).y - global_position.y


func _update_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(GROUP_PLAYER) as Node3D


func _update_state() -> void:
	match _state:
		State.IDLE:
			if _can_notice_target() or (_is_alerted and _has_living_target()):
				_set_state(State.CHASE)
		State.CHASE:
			if not _has_living_target() or (not _is_alerted and _get_target_distance() > lose_range):
				_set_state(State.IDLE)
			elif _is_target_in_attack_range(attack_range) and (not attack_requires_line_of_sight or _has_line_of_sight()) and _may_attack_while_close():
				_set_state(State.WINDUP, attack_windup_time)
				_on_windup_started()
				attack_started.emit()
		State.WINDUP:
			if _state_timer <= 0.0:
				attack_struck.emit()
				_strike()
				_set_state(State.RECOVER, attack_recover_time)
		State.RECOVER, State.STAGGER:
			if _state_timer <= 0.0:
				_set_state(State.CHASE if _has_living_target() else State.IDLE)


func _set_state(new_state: State, duration: float = 0.0) -> void:
	if _state == State.WINDUP and new_state != State.RECOVER:
		_on_windup_cancelled()
		attack_cancelled.emit()
	_state = new_state
	_state_timer = maxf(duration, 0.0)


func _start_stagger(duration: float) -> void:
	# A longer stagger already running is kept.
	if _state == State.STAGGER and _state_timer >= duration:
		return
	_set_state(State.STAGGER, duration)


## True for ranged enemies while the player is inside preferred_min_distance.
func _is_too_close() -> bool:
	return preferred_min_distance > 0.0 and _get_target_distance() < preferred_min_distance


## Ranged enemies back off before attacking a player who is too close, unless they are cornered.
func _may_attack_while_close() -> bool:
	return not _is_too_close() or _retreat_timer >= max_retreat_time_before_attacking


## Called when a windup begins. Ranged enemies use it to start aiming.
func _on_windup_started() -> void:
	pass


## Called when a windup ends without striking: stagger, carry, death or losing the player.
func _on_windup_cancelled() -> void:
	pass


## Where ranged attacks leave the enemy: chest height, a little in front of the body.
func _get_attack_origin(height: float, forward_offset: float) -> Vector3:
	var facing: Vector3 = -global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() > 0.001:
		facing = facing.normalized()
	return global_position + (Vector3.UP * height) + (facing * forward_offset)


## The melee strike. The hit lands only if the player is still close, in front, and at a similar height.
## Other enemy types override this with their own attack.
func _strike() -> void:
	if not _has_living_target():
		return
	if not _is_target_in_attack_range(attack_hit_range):
		return

	var to_target: Vector3 = _get_flat_direction_to_target()
	var facing: Vector3 = -global_transform.basis.z
	facing.y = 0.0
	if to_target != Vector3.ZERO and facing.length_squared() > 0.001:
		var angle_to_target: float = rad_to_deg(facing.normalized().angle_to(to_target))
		if angle_to_target > attack_hit_angle_degrees:
			return

	if not _target.has_method(METHOD_TAKE_DAMAGE):
		return
	var hit_info: Dictionary = {
		"position": _target.global_position + (Vector3.UP * sight_height),
		"direction": to_target,
		"damage": attack_damage,
		"attacker": self,
	}
	if bool(_target.call(METHOD_TAKE_DAMAGE, attack_damage, hit_info)):
		attack_landed.emit(attack_damage)


## Melee enemies always walk in. Ranged ones walk in until they are in range and can see the player,
## back away when the player gets closer than preferred_min_distance, and hold still in between.
func _get_chase_velocity() -> Vector3:
	var direction: Vector3 = _get_flat_direction_to_target()
	var chase_velocity: Vector3 = _get_approach_direction() * maxf(move_speed, 0.0)
	if preferred_min_distance > 0.0:
		var distance: float = _get_target_distance()
		var in_range: bool = distance <= attack_range * ranged_approach_ratio
		if distance < preferred_min_distance:
			chase_velocity = -direction * maxf(move_speed, 0.0) * retreat_speed_multiplier
		elif in_range and (not attack_requires_line_of_sight or _has_line_of_sight()):
			chase_velocity = Vector3.ZERO
	return chase_velocity + _get_separation_velocity()


## Which way to walk to reach the player: the level's path around walls when there is a
## level_navigation node, otherwise a straight line.
func _get_approach_direction() -> Vector3:
	var direct: Vector3 = _get_flat_direction_to_target()
	if _target == null or not is_instance_valid(_target):
		return direct
	if _navigation == null or not is_instance_valid(_navigation):
		_navigation = get_tree().get_first_node_in_group(GROUP_LEVEL_NAVIGATION)
	if _navigation == null or not _navigation.has_method(METHOD_GET_NAVIGATION_DIRECTION):
		return direct

	var path_direction: Vector3 = _navigation.call(METHOD_GET_NAVIGATION_DIRECTION, global_position, _target.global_position) as Vector3
	path_direction.y = 0.0
	if path_direction.length_squared() <= 0.001:
		return direct
	return path_direction.normalized()


## Pushes away from other enemies that are too close, so a group doesn't stack into one spot.
func _get_separation_velocity() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	var clean_distance: float = maxf(separation_distance, 0.001)
	for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var other: Node3D = node as Node3D
		if other == null or other == self:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var distance: float = away.length()
		if distance >= clean_distance or distance <= 0.001:
			continue
		push += (away / distance) * (1.0 - (distance / clean_distance))
	return push * maxf(separation_speed, 0.0)


func _turn_toward_target(delta: float, turn_multiplier: float) -> void:
	var to_target: Vector3 = _get_flat_direction_to_target()
	if to_target == Vector3.ZERO:
		return

	var target_yaw: float = atan2(-to_target.x, -to_target.z)
	var max_turn: float = deg_to_rad(turn_speed_degrees) * clampf(turn_multiplier, 0.0, 1.0) * delta
	rotation.y = rotate_toward(rotation.y, target_yaw, max_turn)


func _can_notice_target() -> bool:
	if not _has_living_target() or _get_target_distance() > notice_range:
		return false
	return _has_line_of_sight()


func _has_line_of_sight() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false

	var ray_from: Vector3 = global_position + (Vector3.UP * sight_height)
	var ray_to: Vector3 = _target.global_position + (Vector3.UP * sight_height)
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, sight_collision_mask)
	var excluded_bodies: Array[RID] = [get_rid()]
	ray_query.exclude = excluded_bodies
	var ray_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
	if ray_hit.is_empty():
		return true

	# Seeing the player, or another enemy standing in the way, counts. A wall doesn't.
	var collider: Node = ray_hit.get("collider") as Node
	return collider == _target or (collider != null and collider.is_in_group(GROUP_ENEMIES))


func _has_living_target() -> bool:
	return _target != null and is_instance_valid(_target) and not HealthManager.is_dead()


func _get_target_distance() -> float:
	if _target == null:
		return INF
	return Vector2(_target.global_position.x - global_position.x, _target.global_position.z - global_position.z).length()


func _is_target_in_attack_range(attack_distance: float) -> bool:
	if _target == null:
		return false
	if absf(_target.global_position.y - global_position.y) > attack_max_height_difference:
		return false
	return _get_target_distance() <= attack_distance


func _get_flat_direction_to_target() -> Vector3:
	if _target == null:
		return Vector3.ZERO

	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.001:
		return Vector3.ZERO
	return to_target.normalized()


func _apply_lean() -> void:
	if _visual != null:
		_visual.rotation.x = _lean
