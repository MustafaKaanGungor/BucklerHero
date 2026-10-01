extends Node

@export_group("Speed")
## Normal ground speed before sprint, crouch, or slide modifiers.
@export var walk_speed: float = 4.7
## Curve for analog movement input before it becomes target speed.
@export var input_response_curve: float = 0.72
## Input below this value is treated as no movement.
@export var minimum_input_strength: float = 0.04
## Minimum speed used by camera and hands while the body is slowing down.
@export var minimum_feedback_target_speed: float = 2.0

@export_group("Ground Movement")
## How quickly walking reaches target speed on ground.
@export var ground_acceleration: float = 36.0
## Extra acceleration when changing walking direction.
@export var direction_change_acceleration_multiplier: float = 1.38
## Ground friction while still holding movement input.
@export var ground_friction: float = 11.25
## Extra friction while releasing movement input.
@export var stop_friction_multiplier: float = 1.55
## Horizontal speed below this value snaps to zero.
@export var low_speed_snap_threshold: float = 0.055

@export_group("Ground Physics")
## Enables slope-aware input and speed shaping on walkable ground.
@export var enable_slope_grounding: bool = true
## Maximum floor angle the player can walk up.
@export var max_walkable_slope_angle_degrees: float = 50.0
## How quickly the cached floor normal follows the real floor.
@export var ground_normal_lerp_speed: float = 24.0
## Snap distance used by CharacterBody3D to stay grounded on slopes and stairs.
@export var floor_snap_length: float = 0.28
## Stops the body from sliding while standing still on slopes.
@export var floor_stop_on_slope: bool = true
## Keeps movement speed constant across slopes when enabled.
@export var floor_constant_speed: bool = false
## Prevents floor motion from treating walls as walkable ground.
@export var floor_block_on_wall: bool = true
## Collision recovery margin used by CharacterBody3D.
@export var body_safe_margin: float = 0.001
## Slightly slows uphill walking by slope steepness.
@export var slope_uphill_speed_penalty: float = 0.12
## Slightly rewards downhill walking by slope steepness.
@export var slope_downhill_speed_bonus: float = 0.08

@export_group("Air Movement")
## How quickly the player can redirect walking speed in air.
@export var air_acceleration: float = 8.4
## Extra air control speed added to the air target speed.
@export var air_control: float = 0.68
## Maximum air target speed relative to walk speed.
@export var air_wish_speed_cap_multiplier: float = 1.34
## Extra air acceleration when changing direction.
@export var air_direction_change_acceleration_multiplier: float = 1.55
## Extra air acceleration for sideways correction.
@export var air_strafe_acceleration_multiplier: float = 1.22
## Light braking when air input pushes against current momentum.
@export var air_counter_move_brake: float = 1.15

@export_group("Momentum Cleanup")
## Enables soft caps and direction cleanup adapted from PlayerMovementData.
@export var enable_momentum_cleanup: bool = true
## Speed bled per second when ground momentum is above the target speed.
@export var ground_overspeed_decay: float = 5.0
## Speed bled per second when air momentum is above the air cap.
@export var air_overspeed_decay: float = 2.2
## Damps sideways drift against the held movement direction on ground.
@export var ground_sideways_damping: float = 1.15
## Damps sideways drift against the held movement direction in air.
@export var air_sideways_damping: float = 0.42
## Brakes momentum moving backward against held input on ground.
@export var ground_backward_brake: float = 4.5
## Brakes momentum moving backward against held input in air.
@export var air_backward_brake: float = 1.35
## Very small no-input air drag to keep airborne motion readable.
@export var air_idle_damping: float = 0.08
## Soft air speed cap used when no movement input is held.
@export var air_idle_soft_cap_multiplier: float = 2.2

@export_group("Air Control Phase")
## Air control multiplier while the jump is fresh and moving upward fast.
@export var air_takeoff_control_multiplier: float = 1.22
## Air control multiplier while rising after the first takeoff push.
@export var air_rising_control_multiplier: float = 1.0
## Air control multiplier near the top of the jump arc.
@export var air_apex_control_multiplier: float = 0.2
## Air control multiplier once the player starts falling.
@export var air_falling_control_multiplier: float = 0.45
## Air control multiplier during a faster fall.
@export var air_fast_fall_control_multiplier: float = 1.18
## Upward velocity treated as fresh takeoff control.
@export var air_takeoff_velocity: float = 5.6
## Upward velocity where the harder rising control starts.
@export var air_rising_hard_velocity: float = 2.2
## Downward velocity where falling control starts becoming easier.
@export var air_fall_control_velocity: float = -1.4
## Downward velocity where the strongest falling control is reached.
@export var air_fast_fall_control_velocity: float = -7.0
## How much the air phase also changes the air wish speed bonus.
@export var air_phase_speed_influence: float = 0.55


func get_input_strength(move_input: Vector2) -> float:
	var input_strength: float = clampf(move_input.length(), 0.0, 1.0)
	if input_strength < minimum_input_strength:
		return 0.0
	return pow(input_strength, maxf(input_response_curve, 0.001))


func get_scaled_target_speed(base_speed: float, move_input: Vector2) -> float:
	return maxf(base_speed, 0.0) * get_input_strength(move_input)


func get_feedback_target_speed(target_speed: float) -> float:
	return maxf(target_speed, maxf(minimum_feedback_target_speed, 0.001))


func get_max_walkable_floor_angle() -> float:
	return deg_to_rad(clampf(max_walkable_slope_angle_degrees, 0.0, 89.0))


func get_ground_normal_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(ground_normal_lerp_speed, 0.001) * delta)


func get_safe_floor_normal(floor_normal: Vector3) -> Vector3:
	if floor_normal.length_squared() <= 0.001:
		return Vector3.UP
	return floor_normal.normalized()


func is_walkable_floor_normal(floor_normal: Vector3) -> bool:
	var safe_normal: Vector3 = get_safe_floor_normal(floor_normal)
	var min_walkable_y: float = cos(get_max_walkable_floor_angle())
	return safe_normal.y >= min_walkable_y


func get_ground_wish_direction(wish_direction: Vector3, floor_normal: Vector3) -> Vector3:
	if wish_direction == Vector3.ZERO:
		return Vector3.ZERO

	var clean_direction: Vector3 = Vector3(wish_direction.x, 0.0, wish_direction.z)
	if clean_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	clean_direction = clean_direction.normalized()

	if not enable_slope_grounding:
		return clean_direction
	if not is_walkable_floor_normal(floor_normal):
		return Vector3.ZERO

	var projected_direction: Vector3 = clean_direction.slide(get_safe_floor_normal(floor_normal))
	projected_direction.y = 0.0
	if projected_direction.length_squared() <= 0.001:
		return clean_direction
	return projected_direction.normalized()


func get_slope_adjusted_target_speed(target_speed: float, wish_direction: Vector3, floor_normal: Vector3) -> float:
	if not enable_slope_grounding or wish_direction == Vector3.ZERO:
		return maxf(target_speed, 0.0)
	if not is_walkable_floor_normal(floor_normal):
		return 0.0

	var downhill_direction: Vector3 = get_downhill_direction(floor_normal)
	if downhill_direction == Vector3.ZERO:
		return maxf(target_speed, 0.0)

	var slope_strength: float = get_slope_steepness(floor_normal)
	var downhill_alignment: float = wish_direction.normalized().dot(downhill_direction)
	var speed_multiplier: float = 1.0
	if downhill_alignment > 0.0:
		speed_multiplier += slope_strength * downhill_alignment * maxf(slope_downhill_speed_bonus, 0.0)
	elif downhill_alignment < 0.0:
		speed_multiplier -= slope_strength * absf(downhill_alignment) * maxf(slope_uphill_speed_penalty, 0.0)

	return maxf(target_speed * maxf(speed_multiplier, 0.1), 0.0)


func get_downhill_direction(floor_normal: Vector3) -> Vector3:
	var downhill_direction: Vector3 = Vector3.DOWN.slide(get_safe_floor_normal(floor_normal))
	downhill_direction.y = 0.0
	if downhill_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return downhill_direction.normalized()


func get_slope_steepness(floor_normal: Vector3) -> float:
	var safe_normal: Vector3 = get_safe_floor_normal(floor_normal)
	var min_walkable_y: float = cos(get_max_walkable_floor_angle())
	return clampf((1.0 - safe_normal.y) / maxf(1.0 - min_walkable_y, 0.001), 0.0, 1.0)


func apply_ground_movement(
	horizontal_velocity: Vector3,
	wish_direction: Vector3,
	target_speed: float,
	delta: float,
	floor_normal: Vector3 = Vector3.UP
) -> Vector3:
	var ground_wish_direction: Vector3 = get_ground_wish_direction(wish_direction, floor_normal)
	var ground_target_speed: float = get_slope_adjusted_target_speed(target_speed, ground_wish_direction, floor_normal)
	var has_input: bool = ground_wish_direction != Vector3.ZERO and ground_target_speed > 0.0
	horizontal_velocity = apply_friction(horizontal_velocity, delta, not has_input)

	if has_input:
		var acceleration: float = _get_ground_acceleration(horizontal_velocity, ground_wish_direction)
		horizontal_velocity = accelerate(horizontal_velocity, ground_wish_direction, ground_target_speed, acceleration, delta)
		horizontal_velocity = _apply_directional_momentum_cleanup(
			horizontal_velocity,
			ground_wish_direction,
			ground_sideways_damping,
			ground_backward_brake,
			delta
		)
		horizontal_velocity = soft_cap_horizontal_speed(horizontal_velocity, ground_target_speed, ground_overspeed_decay, delta)

	return _snap_low_speed(horizontal_velocity)


func apply_air_movement(
	horizontal_velocity: Vector3,
	wish_direction: Vector3,
	target_speed: float,
	vertical_velocity: float,
	delta: float
) -> Vector3:
	if wish_direction == Vector3.ZERO:
		return apply_air_idle_momentum(horizontal_velocity, delta)

	var phase_control: float = get_air_phase_control_multiplier(vertical_velocity)
	horizontal_velocity = _apply_air_counter_move_brake(horizontal_velocity, wish_direction, phase_control, delta)
	var air_speed: float = minf(
		maxf(target_speed, walk_speed),
		maxf(walk_speed, 0.0) * maxf(air_wish_speed_cap_multiplier, 1.0)
	)
	var phase_speed_scale: float = lerpf(1.0, phase_control, clampf(air_phase_speed_influence, 0.0, 1.0))
	var air_speed_bonus: float = walk_speed * maxf(air_control, 0.0) * phase_speed_scale
	var air_speed_cap: float = air_speed + air_speed_bonus
	var acceleration: float = _get_air_acceleration(horizontal_velocity, wish_direction) * phase_control
	horizontal_velocity = accelerate(horizontal_velocity, wish_direction, air_speed_cap, acceleration, delta)
	horizontal_velocity = _apply_directional_momentum_cleanup(
		horizontal_velocity,
		wish_direction,
		air_sideways_damping,
		air_backward_brake * phase_control,
		delta
	)
	return soft_cap_horizontal_speed(horizontal_velocity, air_speed_cap, air_overspeed_decay, delta)


func apply_air_idle_momentum(horizontal_velocity: Vector3, delta: float) -> Vector3:
	if not enable_momentum_cleanup:
		return horizontal_velocity

	var idle_blend: float = 1.0 - exp(-maxf(air_idle_damping, 0.0) * delta)
	var cleaned_velocity: Vector3 = horizontal_velocity.lerp(Vector3.ZERO, idle_blend)
	var idle_cap: float = maxf(walk_speed, 0.0) * maxf(air_idle_soft_cap_multiplier, 1.0)
	return soft_cap_horizontal_speed(cleaned_velocity, idle_cap, air_overspeed_decay, delta)


func soft_cap_horizontal_speed(
	horizontal_velocity: Vector3,
	speed_cap: float,
	overspeed_decay: float,
	delta: float
) -> Vector3:
	if not enable_momentum_cleanup:
		return horizontal_velocity

	var clean_speed_cap: float = maxf(speed_cap, 0.0)
	var speed: float = horizontal_velocity.length()
	if speed <= clean_speed_cap or speed <= 0.001:
		return horizontal_velocity

	var new_speed: float = move_toward(speed, clean_speed_cap, maxf(overspeed_decay, 0.0) * delta)
	return horizontal_velocity.normalized() * new_speed


func apply_friction(horizontal_velocity: Vector3, delta: float, is_stopping: bool) -> Vector3:
	var speed: float = horizontal_velocity.length()
	if speed <= low_speed_snap_threshold:
		return Vector3.ZERO

	var friction: float = ground_friction
	if is_stopping:
		friction *= stop_friction_multiplier

	var control: float = maxf(speed, walk_speed)
	var drop: float = control * friction * delta
	var new_speed: float = maxf(speed - drop, 0.0)
	if new_speed <= low_speed_snap_threshold:
		return Vector3.ZERO
	return horizontal_velocity * (new_speed / speed)


func accelerate(
	horizontal_velocity: Vector3,
	wish_direction: Vector3,
	wish_speed: float,
	acceleration: float,
	delta: float
) -> Vector3:
	var current_speed: float = horizontal_velocity.dot(wish_direction)
	var add_speed: float = wish_speed - current_speed
	if add_speed <= 0.0:
		return horizontal_velocity

	var acceleration_speed: float = minf(acceleration * wish_speed * delta, add_speed)
	return horizontal_velocity + (wish_direction * acceleration_speed)


func get_air_phase_control_multiplier(vertical_velocity: float) -> float:
	var takeoff_velocity: float = maxf(air_takeoff_velocity, 0.001)
	var hard_velocity: float = clampf(air_rising_hard_velocity, 0.0, takeoff_velocity)
	var takeoff_multiplier: float = maxf(air_takeoff_control_multiplier, 0.0)
	var rising_multiplier: float = maxf(air_rising_control_multiplier, 0.0)
	var apex_multiplier: float = maxf(air_apex_control_multiplier, 0.0)
	var falling_multiplier: float = maxf(air_falling_control_multiplier, 0.0)
	var fast_fall_multiplier: float = maxf(air_fast_fall_control_multiplier, 0.0)

	if vertical_velocity >= hard_velocity:
		var takeoff_ratio: float = clampf(
			(vertical_velocity - hard_velocity) / maxf(takeoff_velocity - hard_velocity, 0.001),
			0.0,
			1.0
		)
		return lerpf(rising_multiplier, takeoff_multiplier, takeoff_ratio)

	if vertical_velocity >= 0.0:
		var apex_ratio: float = clampf(1.0 - (vertical_velocity / maxf(hard_velocity, 0.001)), 0.0, 1.0)
		return lerpf(rising_multiplier, apex_multiplier, apex_ratio)

	var fall_control_start: float = minf(air_fall_control_velocity, -0.001)
	if vertical_velocity > fall_control_start:
		var light_fall_ratio: float = clampf(absf(vertical_velocity) / absf(fall_control_start), 0.0, 1.0)
		return lerpf(apex_multiplier, falling_multiplier, light_fall_ratio)

	var fast_fall_velocity: float = minf(air_fast_fall_control_velocity, fall_control_start - 0.001)
	var fast_fall_ratio: float = clampf(
		(fall_control_start - vertical_velocity) / maxf(fall_control_start - fast_fall_velocity, 0.001),
		0.0,
		1.0
	)
	return lerpf(falling_multiplier, fast_fall_multiplier, fast_fall_ratio)


func _get_ground_acceleration(horizontal_velocity: Vector3, wish_direction: Vector3) -> float:
	if horizontal_velocity.length_squared() <= 0.001:
		return ground_acceleration

	var direction_dot: float = horizontal_velocity.normalized().dot(wish_direction)
	if direction_dot < 0.5:
		return ground_acceleration * maxf(direction_change_acceleration_multiplier, 0.0)
	return ground_acceleration


func _get_air_acceleration(horizontal_velocity: Vector3, wish_direction: Vector3) -> float:
	var acceleration: float = air_acceleration
	if horizontal_velocity.length_squared() <= 0.001:
		return acceleration

	var direction_dot: float = horizontal_velocity.normalized().dot(wish_direction)
	if direction_dot < 0.35:
		acceleration *= maxf(air_direction_change_acceleration_multiplier, 0.0)
	elif absf(direction_dot) < 0.72:
		acceleration *= maxf(air_strafe_acceleration_multiplier, 0.0)
	return acceleration


func _apply_air_counter_move_brake(
	horizontal_velocity: Vector3,
	wish_direction: Vector3,
	control_multiplier: float,
	delta: float
) -> Vector3:
	if horizontal_velocity.length_squared() <= 0.001:
		return horizontal_velocity

	var direction_dot: float = horizontal_velocity.normalized().dot(wish_direction)
	if direction_dot >= -0.1:
		return horizontal_velocity

	var brake_strength: float = -direction_dot * maxf(air_counter_move_brake, 0.0) * maxf(control_multiplier, 0.0) * delta
	var speed: float = horizontal_velocity.length()
	var new_speed: float = maxf(speed - (walk_speed * brake_strength), 0.0)
	if new_speed <= low_speed_snap_threshold:
		return Vector3.ZERO
	return horizontal_velocity.normalized() * new_speed


func _apply_directional_momentum_cleanup(
	horizontal_velocity: Vector3,
	wish_direction: Vector3,
	sideways_damping: float,
	backward_brake: float,
	delta: float
) -> Vector3:
	if not enable_momentum_cleanup:
		return horizontal_velocity
	if wish_direction == Vector3.ZERO or horizontal_velocity.length_squared() <= 0.001:
		return horizontal_velocity

	var clean_direction: Vector3 = wish_direction.normalized()
	var forward_speed: float = horizontal_velocity.dot(clean_direction)
	var sideways_velocity: Vector3 = horizontal_velocity - (clean_direction * forward_speed)
	var side_blend: float = 1.0 - exp(-maxf(sideways_damping, 0.0) * delta)
	sideways_velocity = sideways_velocity.lerp(Vector3.ZERO, side_blend)

	if forward_speed < 0.0:
		var brake_drop: float = absf(forward_speed) * maxf(backward_brake, 0.0) * delta
		forward_speed = move_toward(forward_speed, 0.0, brake_drop)

	return (clean_direction * forward_speed) + sideways_velocity


func _snap_low_speed(horizontal_velocity: Vector3) -> Vector3:
	if horizontal_velocity.length() <= low_speed_snap_threshold:
		return Vector3.ZERO
	return horizontal_velocity
