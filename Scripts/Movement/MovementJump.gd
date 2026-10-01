extends Node

@export_group("Jump Motion")
## Upward velocity applied when a normal jump starts.
@export var jump_velocity: float = 8.35
## Overall gravity weight applied while airborne.
@export var player_weight: float = 1.12
## Gravity multiplier while the player is rising.
@export var jump_rise_gravity_multiplier: float = 0.96
## Gravity multiplier near the top of the jump arc.
@export var jump_apex_gravity_multiplier: float = 0.82
## Vertical speed range treated as the jump apex.
@export var jump_apex_velocity_threshold: float = 0.85
## Gravity multiplier while the player is falling.
@export var jump_fall_gravity_multiplier: float = 1.58
## Short time after leaving ground where jump is still allowed.
@export var coyote_time: float = 0.08
## Short time before landing where a jump press is remembered.
@export var jump_buffer_time: float = 0.10

@export_group("Momentum Links")
## Allows sprint, jump, crouch, and slide to share movement power.
@export var enable_momentum_links: bool = true
## Keeps some walk speed when jumping from normal movement.
@export var jump_walk_momentum_keep_multiplier: float = 0.20
## Keeps less horizontal speed on small crouch jumps.
@export var jump_crouch_momentum_keep_multiplier: float = 0.72
## Preserves slide speed when jumping out of a slide.
@export var jump_slide_momentum_keep_multiplier: float = 1.5
## Adds more jump feedback when horizontal speed is high.
@export var jump_feedback_speed_bonus: float = 0.28

@export_group("Takeoff Control")
## Enables a small horizontal correction toward input when jumping.
@export var enable_jump_takeoff_control: bool = true
## Jump takeoff target speed relative to the current movement target.
@export var jump_takeoff_target_speed_multiplier: float = 1.08
## Immediate portion of target speed guaranteed on takeoff.
@export var jump_takeoff_minimum_speed_multiplier: float = 0.64
## Acceleration used for the takeoff correction.
@export var jump_takeoff_acceleration: float = 22.0
## Extra takeoff acceleration when changing direction.
@export var jump_takeoff_direction_change_multiplier: float = 1.32
## Minimum move input needed for takeoff control.
@export var jump_takeoff_min_input_strength: float = 0.12
## Maximum speed a normal jump takeoff correction can add.
@export var jump_takeoff_max_added_speed: float = 2.15
## Maximum speed a slide jump takeoff correction can add.
@export var slide_jump_takeoff_max_added_speed: float = 1.15

@export_group("Sprint Jump Height")
## Curves sprint jump vertical gain so it stays realistic.
@export var sprint_jump_height_curve: float = 0.82

@export_group("Crouch Jump")
## Enables small jumps while crouched.
@export var enable_crouch_jump: bool = true
## Multiplies jump velocity for crouch jumps.
@export var crouch_jump_velocity_multiplier: float = 0.55
## Multiplies visual feedback for crouch jumps.
@export var crouch_jump_feedback_multiplier: float = 0.65

@export_group("Variable Jump")
## Lets holding jump make the jump higher.
@export var enable_variable_jump_height: bool = true
## Time that jump hold can reduce gravity.
@export var jump_hold_time: float = 0.13
## Gravity multiplier while jump is held.
@export var jump_hold_gravity_multiplier: float = 0.52
## Velocity multiplier when jump is released early.
@export var jump_release_cut_multiplier: float = 0.56
## Minimum upward velocity kept after early jump release.
@export var jump_release_min_velocity: float = 2.0
## Lets crouch jumps use variable jump height.
@export var crouch_jump_uses_variable_height: bool = true


func get_jump_start_velocity(jump_started_from_crouch: bool) -> float:
	var start_velocity: float = jump_velocity
	if jump_started_from_crouch and enable_crouch_jump:
		start_velocity *= maxf(crouch_jump_velocity_multiplier, 0.0)
	return start_velocity


func get_sprint_jump_velocity(base_jump_velocity: float, sprint_jump_power: float, sprint_height_multiplier: float) -> float:
	var shaped_power: float = pow(clampf(sprint_jump_power, 0.0, 1.0), maxf(sprint_jump_height_curve, 0.001))
	var height_multiplier: float = lerpf(1.0, maxf(sprint_height_multiplier, 1.0), shaped_power)
	return base_jump_velocity * height_multiplier


func can_start_variable_jump(jump_started_from_crouch: bool) -> bool:
	if not enable_variable_jump_height:
		return false
	if jump_started_from_crouch and not crouch_jump_uses_variable_height:
		return false
	return jump_hold_time > 0.0


func get_jump_arc_gravity_multiplier(vertical_velocity: float) -> float:
	var apex_threshold: float = maxf(jump_apex_velocity_threshold, 0.0)
	if apex_threshold > 0.0 and absf(vertical_velocity) <= apex_threshold:
		return maxf(jump_apex_gravity_multiplier, 0.0)
	if vertical_velocity > 0.0:
		return maxf(jump_rise_gravity_multiplier, 0.0)
	return maxf(jump_fall_gravity_multiplier, 0.0)


func get_airborne_gravity_multiplier(variable_jump_multiplier: float, vertical_velocity: float) -> float:
	var gravity_multiplier: float = maxf(variable_jump_multiplier, 0.0)
	gravity_multiplier *= maxf(player_weight, 0.0)
	gravity_multiplier *= get_jump_arc_gravity_multiplier(vertical_velocity)
	return maxf(gravity_multiplier, 0.0)


func get_released_jump_velocity(vertical_velocity: float) -> float:
	var cut_multiplier: float = clampf(jump_release_cut_multiplier, 0.0, 1.0)
	var cut_velocity: float = maxf(
		vertical_velocity * cut_multiplier,
		maxf(jump_release_min_velocity, 0.0)
	)
	return minf(vertical_velocity, cut_velocity)


func get_momentum_keep_multiplier(jump_started_from_crouch: bool, jump_started_from_slide: bool) -> float:
	if jump_started_from_slide:
		return jump_slide_momentum_keep_multiplier
	if jump_started_from_crouch:
		return jump_crouch_momentum_keep_multiplier
	return jump_walk_momentum_keep_multiplier


func get_takeoff_control_velocity(
	horizontal_velocity: Vector3,
	wish_direction: Vector3,
	target_speed: float,
	move_input_strength: float,
	jump_started_from_crouch: bool,
	jump_started_from_slide: bool,
	delta: float
) -> Vector3:
	if not enable_jump_takeoff_control:
		return horizontal_velocity
	if wish_direction == Vector3.ZERO:
		return horizontal_velocity

	var input_strength: float = clampf(move_input_strength, 0.0, 1.0)
	if input_strength < clampf(jump_takeoff_min_input_strength, 0.0, 1.0):
		return horizontal_velocity

	var keep_multiplier: float = get_momentum_keep_multiplier(jump_started_from_crouch, jump_started_from_slide)
	var desired_speed: float = maxf(target_speed, 0.0)
	desired_speed *= maxf(jump_takeoff_target_speed_multiplier, 0.0)
	desired_speed *= maxf(keep_multiplier, 0.0)
	desired_speed *= input_strength
	if desired_speed <= 0.0:
		return horizontal_velocity

	var acceleration: float = _get_takeoff_acceleration(horizontal_velocity, wish_direction)
	var controlled_velocity: Vector3 = _apply_minimum_takeoff_speed(horizontal_velocity, wish_direction, desired_speed)
	controlled_velocity = MovementWalk.accelerate(
		controlled_velocity,
		wish_direction,
		desired_speed,
		acceleration,
		delta
	)
	var max_added_speed: float = jump_takeoff_max_added_speed
	if jump_started_from_slide:
		max_added_speed = slide_jump_takeoff_max_added_speed
	return _limit_added_horizontal_speed(horizontal_velocity, controlled_velocity, max_added_speed)


func get_feedback_speed_bonus(horizontal_speed: float, max_horizontal_speed: float) -> float:
	if max_horizontal_speed <= 0.0:
		return 0.0

	var speed_ratio: float = clampf(horizontal_speed / max_horizontal_speed, 0.0, 1.0)
	return speed_ratio * maxf(jump_feedback_speed_bonus, 0.0)


func _get_takeoff_acceleration(horizontal_velocity: Vector3, wish_direction: Vector3) -> float:
	var acceleration: float = jump_takeoff_acceleration
	if horizontal_velocity.length_squared() <= 0.001:
		return acceleration

	var direction_dot: float = horizontal_velocity.normalized().dot(wish_direction)
	if direction_dot < 0.45:
		acceleration *= maxf(jump_takeoff_direction_change_multiplier, 0.0)
	return acceleration


func _apply_minimum_takeoff_speed(horizontal_velocity: Vector3, wish_direction: Vector3, desired_speed: float) -> Vector3:
	var minimum_speed: float = desired_speed * clampf(jump_takeoff_minimum_speed_multiplier, 0.0, 1.0)
	if minimum_speed <= 0.0:
		return horizontal_velocity

	var current_speed_in_direction: float = horizontal_velocity.dot(wish_direction)
	var speed_to_add: float = minimum_speed - current_speed_in_direction
	if speed_to_add <= 0.0:
		return horizontal_velocity
	return horizontal_velocity + (wish_direction * speed_to_add)


func _limit_added_horizontal_speed(
	previous_velocity: Vector3,
	next_velocity: Vector3,
	max_added_speed: float
) -> Vector3:
	var previous_speed: float = previous_velocity.length()
	var next_speed: float = next_velocity.length()
	var speed_limit: float = previous_speed + maxf(max_added_speed, 0.0)
	if next_speed <= speed_limit:
		return next_velocity
	if next_speed <= 0.001:
		return Vector3.ZERO
	return next_velocity.normalized() * speed_limit
