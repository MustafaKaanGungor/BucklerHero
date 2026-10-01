extends Node

@export_group("Activation")
@export var enable_slide_movement: bool = true
@export var enable_slide: bool = true
@export var enable_manual_slide: bool = true
@export var enable_auto_slide_under_obstacles: bool = true
@export var slide_from_auto_crouch: bool = true
@export var slide_min_start_speed: float = 5.2
@export var slide_start_speed_multiplier: float = 1.05
@export var slide_min_time: float = 0.22
@export var slide_exit_speed: float = 1.45

@export_group("Ground Motion")
@export var slide_deceleration: float = 3.85
@export var slide_steer_strength: float = 2.2
@export var slide_max_speed: float = 11.5
@export var slide_stop_to_crouch_speed: float = 1.0
## Steering multiplier while slide speed is high.
@export var slide_high_speed_steer_multiplier: float = 0.58
## Extra steering when input is already aligned with the slide.
@export var slide_aligned_steer_bonus: float = 0.55
## Brake added when the player steers against the slide.
@export var slide_counter_steer_deceleration: float = 2.4
## Brake added when sliding uphill on angled ground.
@export var slope_slide_uphill_deceleration: float = 7.5

@export_group("Combo Speed")
## Lets slide movement use the slide-jump combo speed bonus.
@export var enable_combo_slide_speed: bool = true
## Portion of combo speed added to slide start speed.
@export var combo_slide_start_speed_multiplier: float = 0.85
## Portion of combo speed added to slide max speed.
@export var combo_slide_max_speed_multiplier: float = 1.0
## Portion of combo speed added to slide jump forward target.
@export var combo_slide_jump_forward_multiplier: float = 0.75
## Portion of combo speed added to slide jump max speed.
@export var combo_slide_jump_max_speed_multiplier: float = 1.25

@export_group("Slope Slide")
## Enables downhill surfaces to build slide speed.
@export var enable_slope_slide_boost: bool = true
## Surface steepness needed before downhill boost starts.
@export var slope_slide_min_steepness: float = 0.001
## Acceleration added while sliding down an angled surface.
@export var slope_slide_downhill_acceleration: float = 100.0
## Extra speed allowed above normal slide max on downhill slopes.
@export var slope_slide_max_extra_speed: float = 36.5
## Minimum downhill alignment needed to receive slope boost.
@export var slope_slide_min_downhill_alignment: float = 0.02
## Smoothly pulls slide direction toward the downhill path.
@export var slope_slide_direction_lerp_speed: float = 3.8

@export_group("Ease Out")
## Keeps slide speed early, then brakes harder near the end.
@export var enable_ease_out_deceleration: bool = true
## Time before strong slide braking begins.
@export var slide_coast_time: float = 0.16
## Time used to ramp from soft braking to hard braking.
@export var slide_ease_out_time: float = 0.72
## Fraction of base deceleration used while slide is fresh.
@export var slide_early_deceleration_multiplier: float = 0.18
## Fraction of base deceleration used near the end of the slide.
@export var slide_late_deceleration_multiplier: float = 2.75
## Higher values keep speed longer and make late braking sharper.
@export var slide_ease_out_power: float = 2.25
## How much lost speed contributes to late braking.
@export var slide_speed_loss_deceleration_influence: float = 0.75
## Extra braking once speed is close to the slide exit range.
@export var slide_finish_deceleration_multiplier: float = 1.45
## Speed window above exit speed where finish braking starts.
@export var slide_finish_speed_window: float = 0.8

@export_group("Slide Jump")
## Allows sliding jumps to carry extra forward speed.
@export var enable_slide_jump_boost: bool = true
## Forward speed added after slide speed inheritance.
@export var slide_jump_forward_boost: float = 5.8
## Multiplies current slide speed before adding the forward boost.
@export var slide_jump_speed_multiplier: float = 1.12
## Maximum horizontal speed after a slide jump boost.
@export var slide_jump_max_horizontal_speed: float = 17.2
## Multiplies slide jump camera and hand feedback strength.
@export var slide_jump_feedback_multiplier: float = 1.0

@export_group("Slide Jump Speed Scaling")
## Enables faster slides to add more forward speed when jumping out of a slide.
@export var enable_slide_speed_jump_scaling: bool = true
## Slide speed where extra slide-jump forward scaling starts.
@export var slide_jump_speed_scaling_min_speed: float = 5.2
## Slide speed where extra slide-jump forward scaling reaches full strength.
@export var slide_jump_speed_scaling_full_speed: float = 22.0
## Curve for how slide speed becomes extra slide-jump force.
@export var slide_jump_speed_scaling_curve: float = 0.86
## Extra slide-speed inheritance multiplier at full slide-jump speed scaling.
@export var slide_jump_speed_extra_multiplier: float = 0.30
## Extra forward speed added at full slide-jump speed scaling.
@export var slide_jump_speed_forward_bonus: float = 4.8
## Extra horizontal speed cap added at full slide-jump speed scaling.
@export var slide_jump_speed_max_bonus: float = 6.4

@export_group("Momentum Links")
## Lets slide starts inherit speed from a recent jump.
@export var slide_inherit_jump_momentum: bool = true
## Time after jumping where slide can inherit jump momentum.
@export var slide_jump_momentum_window: float = 0.48
## Amount of recent jump speed reused when starting a slide.
@export var slide_jump_momentum_multiplier: float = 0.9
## How much slide direction follows the recent jump direction.
@export var slide_jump_direction_influence: float = 0.55
## Minimum recent jump speed needed to help start a slide.
@export var slide_min_jump_momentum_speed: float = 3.6

@export_group("Landing Drop Boost")
## Enables higher drops to start longer and faster landing slides.
@export var enable_landing_drop_slide_boost: bool = true
## Drop height needed before landing slide boost starts.
@export var landing_drop_min_boost_height: float = 1.8
## Drop height that reaches the maximum landing slide multiplier.
@export var landing_drop_height_for_max_multiplier: float = 100.0
## Maximum multiplier applied to slide speed/range after a big drop.
@export var landing_drop_max_slide_multiplier: float = 5.0
## Curve for how quickly drop height turns into slide boost.
@export var landing_drop_boost_curve: float = 0.82
## Time after touching ground where a slide can still use landing drop boost.
@export var landing_drop_slide_boost_window: float = 0.42

@export_group("Feel")
@export var slide_blend_lerp_speed: float = 14.0
@export var slide_enter_blend: float = 0.72

var _active_slide_direction: Vector3 = Vector3.ZERO
var _active_wish_direction: Vector3 = Vector3.ZERO
var _active_floor_normal: Vector3 = Vector3.UP
var _active_combo_speed_bonus: float = 0.0
var _active_landing_drop_slide_multiplier: float = 1.0


func set_slide_motion_context(
	slide_direction: Vector3,
	floor_normal: Vector3,
	combo_speed_bonus: float,
	wish_direction: Vector3 = Vector3.ZERO
) -> void:
	_active_slide_direction = slide_direction
	_active_wish_direction = wish_direction
	_active_floor_normal = _get_safe_floor_normal(floor_normal)
	_active_combo_speed_bonus = maxf(combo_speed_bonus, 0.0)


func set_combo_speed_bonus(combo_speed_bonus: float) -> void:
	_active_combo_speed_bonus = maxf(combo_speed_bonus, 0.0)


func set_landing_drop_slide_multiplier(drop_multiplier: float) -> void:
	_active_landing_drop_slide_multiplier = clampf(
		drop_multiplier,
		1.0,
		maxf(landing_drop_max_slide_multiplier, 1.0)
	)


func clear_landing_drop_slide_multiplier() -> void:
	_active_landing_drop_slide_multiplier = 1.0


func get_next_slide_speed(
	slide_speed: float,
	slide_start_speed: float,
	slide_timer: float,
	delta: float
) -> float:
	var deceleration: float = get_slide_deceleration(slide_speed, slide_start_speed, slide_timer)
	deceleration += get_counter_steer_deceleration(_active_slide_direction)
	deceleration += get_uphill_slide_deceleration(_active_slide_direction, _active_floor_normal)
	var next_speed: float = maxf(slide_speed - (deceleration * delta), 0.0)
	var slope_acceleration: float = get_slope_slide_acceleration(_active_slide_direction, _active_floor_normal)
	var slope_speed_limit: float = get_slope_slide_speed_limit(_active_slide_direction, _active_floor_normal)
	return minf(next_speed + (slope_acceleration * delta), slope_speed_limit)


func get_combo_slide_start_speed(start_speed: float) -> float:
	return maxf(start_speed, 0.0) + _get_combo_slide_bonus(combo_slide_start_speed_multiplier)


func get_landing_drop_slide_start_speed(start_speed: float, drop_height: float) -> float:
	return maxf(start_speed, 0.0) * get_landing_drop_slide_multiplier(drop_height)


func get_landing_drop_slide_multiplier(drop_height: float) -> float:
	if not enable_landing_drop_slide_boost:
		return 1.0

	var min_height: float = maxf(landing_drop_min_boost_height, 0.0)
	var max_height: float = maxf(landing_drop_height_for_max_multiplier, min_height + 0.001)
	var clean_drop_height: float = maxf(drop_height, 0.0)
	if clean_drop_height < min_height:
		return 1.0

	var height_ratio: float = clampf((clean_drop_height - min_height) / maxf(max_height - min_height, 0.001), 0.0, 1.0)
	var shaped_ratio: float = pow(height_ratio, maxf(landing_drop_boost_curve, 0.001))
	return lerpf(1.0, maxf(landing_drop_max_slide_multiplier, 1.0), shaped_ratio)


func get_slide_max_speed() -> float:
	var base_speed_limit: float = maxf(slide_max_speed, 0.0) + _get_combo_slide_bonus(combo_slide_max_speed_multiplier)
	return base_speed_limit * maxf(_active_landing_drop_slide_multiplier, 1.0)


func has_landing_drop_slide_boost(drop_height: float) -> bool:
	return get_landing_drop_slide_multiplier(drop_height) > 1.001


func get_steered_slide_direction(
	slide_direction: Vector3,
	wish_direction: Vector3,
	floor_normal: Vector3,
	slide_speed: float,
	delta: float
) -> Vector3:
	var current_direction: Vector3 = slide_direction
	if current_direction == Vector3.ZERO:
		current_direction = wish_direction
	if current_direction == Vector3.ZERO:
		return Vector3.ZERO

	current_direction.y = 0.0
	current_direction = current_direction.normalized()

	if wish_direction != Vector3.ZERO and slide_steer_strength > 0.0:
		var speed_ratio: float = clampf(slide_speed / maxf(get_slide_max_speed(), 0.001), 0.0, 1.0)
		var input_direction: Vector3 = wish_direction
		input_direction.y = 0.0
		input_direction = input_direction.normalized()

		var input_alignment: float = current_direction.dot(input_direction)
		var high_speed_multiplier: float = lerpf(1.0, maxf(slide_high_speed_steer_multiplier, 0.0), speed_ratio)
		var aligned_bonus: float = maxf(input_alignment, 0.0) * maxf(slide_aligned_steer_bonus, 0.0)
		var steer_speed: float = maxf(slide_steer_strength, 0.0) * (high_speed_multiplier + aligned_bonus)
		var steer_blend: float = 1.0 - exp(-steer_speed * delta)
		current_direction = current_direction.lerp(input_direction, steer_blend).normalized()

	return get_slope_adjusted_slide_direction(current_direction, floor_normal, delta)


func get_slope_adjusted_slide_direction(slide_direction: Vector3, floor_normal: Vector3, delta: float) -> Vector3:
	if not enable_slope_slide_boost:
		return slide_direction

	var downhill_direction: Vector3 = get_downhill_direction(floor_normal)
	if downhill_direction == Vector3.ZERO:
		return slide_direction

	var downhill_strength: float = get_downhill_slide_strength(slide_direction, floor_normal)
	if downhill_strength <= 0.0:
		return slide_direction

	var direction_blend_speed: float = maxf(slope_slide_direction_lerp_speed, 0.0) * downhill_strength
	var direction_blend: float = 1.0 - exp(-direction_blend_speed * delta)
	return slide_direction.lerp(downhill_direction, direction_blend).normalized()


func get_downhill_direction(floor_normal: Vector3) -> Vector3:
	var safe_floor_normal: Vector3 = _get_safe_floor_normal(floor_normal)
	var downhill_direction: Vector3 = Vector3.DOWN.slide(safe_floor_normal)
	downhill_direction.y = 0.0
	if downhill_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return downhill_direction.normalized()


func get_slope_slide_acceleration(slide_direction: Vector3, floor_normal: Vector3) -> float:
	if not enable_slope_slide_boost:
		return 0.0

	var downhill_strength: float = get_downhill_slide_strength(slide_direction, floor_normal)
	return maxf(slope_slide_downhill_acceleration, 0.0) * downhill_strength


func get_uphill_slide_deceleration(slide_direction: Vector3, floor_normal: Vector3) -> float:
	var downhill_direction: Vector3 = get_downhill_direction(floor_normal)
	if downhill_direction == Vector3.ZERO or slide_direction == Vector3.ZERO:
		return 0.0

	var slope_strength: float = _get_slope_steepness_ratio(floor_normal)
	var uphill_alignment: float = maxf(-slide_direction.normalized().dot(downhill_direction), 0.0)
	return maxf(slope_slide_uphill_deceleration, 0.0) * slope_strength * uphill_alignment


func get_counter_steer_deceleration(slide_direction: Vector3) -> float:
	if _active_wish_direction == Vector3.ZERO or slide_direction == Vector3.ZERO:
		return 0.0

	var direction_alignment: float = slide_direction.normalized().dot(_active_wish_direction.normalized())
	var counter_strength: float = clampf(-direction_alignment, 0.0, 1.0)
	return maxf(slide_counter_steer_deceleration, 0.0) * counter_strength


func get_slope_slide_speed_limit(slide_direction: Vector3, floor_normal: Vector3) -> float:
	var base_speed_limit: float = get_slide_max_speed()
	if not enable_slope_slide_boost:
		return base_speed_limit

	var downhill_strength: float = get_downhill_slide_strength(slide_direction, floor_normal)
	var extra_speed: float = maxf(slope_slide_max_extra_speed, 0.0) * downhill_strength
	return base_speed_limit + extra_speed


func get_downhill_slide_strength(slide_direction: Vector3, floor_normal: Vector3) -> float:
	var downhill_direction: Vector3 = get_downhill_direction(floor_normal)
	if downhill_direction == Vector3.ZERO or slide_direction == Vector3.ZERO:
		return 0.0

	var slope_strength: float = _get_slope_steepness_ratio(floor_normal)
	if slope_strength <= 0.0:
		return 0.0

	var downhill_alignment: float = slide_direction.normalized().dot(downhill_direction)
	var minimum_alignment: float = clampf(slope_slide_min_downhill_alignment, 0.0, 0.99)
	var alignment_strength: float = clampf(
		(downhill_alignment - minimum_alignment) / maxf(1.0 - minimum_alignment, 0.001),
		0.0,
		1.0
	)
	return slope_strength * alignment_strength


func get_active_slide_ground_strength(slide_speed: float) -> float:
	var speed_ratio: float = clampf(slide_speed / maxf(get_slide_max_speed(), 0.001), 0.0, 1.0)
	var slope_strength: float = _get_slope_steepness_ratio(_active_floor_normal)
	var downhill_strength: float = get_downhill_slide_strength(_active_slide_direction, _active_floor_normal)
	var ground_strength: float = pow(speed_ratio, 0.75)
	ground_strength *= 0.75 + (slope_strength * 0.35) + (downhill_strength * 0.45)
	return clampf(ground_strength, 0.0, 1.35)


func get_slide_deceleration(slide_speed: float, slide_start_speed: float, slide_timer: float) -> float:
	var base_deceleration: float = maxf(slide_deceleration, 0.0)
	if not enable_ease_out_deceleration:
		return base_deceleration

	var start_speed: float = maxf(slide_start_speed, slide_min_start_speed)
	var speed_range: float = maxf(start_speed - slide_exit_speed, 0.001)
	var speed_loss_ratio: float = clampf((start_speed - slide_speed) / speed_range, 0.0, 1.0)
	var time_ratio: float = clampf((slide_timer - slide_coast_time) / maxf(slide_ease_out_time, 0.001), 0.0, 1.0)
	var time_factor: float = pow(time_ratio, maxf(slide_ease_out_power, 0.001))
	var speed_factor: float = pow(speed_loss_ratio, maxf(slide_ease_out_power, 0.001))
	var brake_factor: float = maxf(time_factor, speed_factor * clampf(slide_speed_loss_deceleration_influence, 0.0, 1.0))
	var multiplier: float = lerpf(
		maxf(slide_early_deceleration_multiplier, 0.0),
		maxf(slide_late_deceleration_multiplier, 0.0),
		clampf(brake_factor, 0.0, 1.0)
	)

	if slide_speed <= slide_exit_speed + maxf(slide_finish_speed_window, 0.0):
		multiplier = maxf(multiplier, slide_finish_deceleration_multiplier)

	return base_deceleration * multiplier


func get_slide_jump_target_forward_speed(current_forward_speed: float, slide_speed: float) -> float:
	var speed_scale: float = get_slide_jump_speed_scaling_ratio(slide_speed)
	var slide_speed_multiplier: float = maxf(slide_jump_speed_multiplier, 0.0)
	slide_speed_multiplier += speed_scale * maxf(slide_jump_speed_extra_multiplier, 0.0)
	var inherited_speed: float = maxf(current_forward_speed, slide_speed * slide_speed_multiplier)
	var combo_forward_bonus: float = _get_combo_slide_bonus(combo_slide_jump_forward_multiplier)
	var slide_speed_forward_bonus: float = speed_scale * maxf(slide_jump_speed_forward_bonus, 0.0)
	return inherited_speed + maxf(slide_jump_forward_boost, 0.0) + slide_speed_forward_bonus + combo_forward_bonus


func get_slide_jump_max_horizontal_speed(slide_speed: float = 0.0) -> float:
	var speed_scale: float = get_slide_jump_speed_scaling_ratio(slide_speed)
	var speed_bonus: float = speed_scale * maxf(slide_jump_speed_max_bonus, 0.0)
	return maxf(slide_jump_max_horizontal_speed, 0.0) + speed_bonus + _get_combo_slide_bonus(combo_slide_jump_max_speed_multiplier)


func get_slide_jump_speed_scaling_ratio(slide_speed: float) -> float:
	if not enable_slide_speed_jump_scaling:
		return 0.0

	var min_speed: float = maxf(slide_jump_speed_scaling_min_speed, 0.0)
	var full_speed: float = maxf(slide_jump_speed_scaling_full_speed, min_speed + 0.001)
	var speed_ratio: float = clampf(
		(maxf(slide_speed, 0.0) - min_speed) / maxf(full_speed - min_speed, 0.001),
		0.0,
		1.0
	)
	return pow(speed_ratio, maxf(slide_jump_speed_scaling_curve, 0.001))


func _get_slope_steepness_ratio(floor_normal: Vector3) -> float:
	var safe_floor_normal: Vector3 = _get_safe_floor_normal(floor_normal)
	var steepness: float = 1.0 - clampf(safe_floor_normal.y, 0.0, 1.0)
	var minimum_steepness: float = clampf(slope_slide_min_steepness, 0.0, 0.99)
	return clampf(
		(steepness - minimum_steepness) / maxf(1.0 - minimum_steepness, 0.001),
		0.0,
		1.0
	)


func _get_safe_floor_normal(floor_normal: Vector3) -> Vector3:
	if floor_normal.length_squared() <= 0.001:
		return Vector3.UP
	return floor_normal.normalized()


func _get_combo_slide_bonus(multiplier: float) -> float:
	if not enable_combo_slide_speed:
		return 0.0
	return _active_combo_speed_bonus * maxf(multiplier, 0.0)
