extends Node

@export_group("Activation")
## Enables wall running while airborne.
@export var enable_wall_run: bool = true
## Side ray distance used to find runnable walls.
@export var wall_check_distance: float = 0.82
## Lower ray height used to check the wall beside the body.
@export var wall_check_height: float = 0.95
## Upper ray height used to keep wall checks stable.
@export var wall_check_upper_height: float = 1.45
## Required side-ray alignment so front walls do not become wall runs.
@export var min_side_wall_alignment: float = 0.62
## Minimum horizontal speed needed to start a wall run.
@export var min_start_horizontal_speed: float = 4.2
## Minimum horizontal speed needed to keep wall running.
@export var min_keep_horizontal_speed: float = 2.6
## Highest upward velocity allowed when attaching to a wall.
@export var max_start_upward_velocity: float = 10.5
## Lowest falling velocity allowed when attaching to a wall.
@export var min_start_vertical_velocity: float = -24.0
## Maximum wall run duration before the player must leave the wall.
@export var max_wall_run_time: float = 2.05
## Extra wall run time available from fast sprint, combo, and entry-speed range scaling.
@export var max_bonus_wall_run_time: float = 1.65
## Highest wall normal Y value accepted as a wall.
@export var wall_max_normal_y: float = 0.35
## Lowest wall normal Y value accepted as a wall.
@export var wall_min_normal_y: float = -0.25
## Required alignment with wall direction before attaching.
@export var min_forward_alignment: float = 0.14
## Time after wall jumping where the same wall cannot be grabbed again.
@export var same_wall_reattach_lockout: float = 0.24
## Normal dot threshold used to identify the same wall after jumping.
@export var same_wall_dot_threshold: float = 0.72

@export_group("Wall Run To Climb")
## Enables converting a wall run into a forward wall climb when looking into the wall.
@export var enable_wall_run_to_climb: bool = true
## Minimum wall-run time before a forward wall climb can take over.
@export var wall_run_to_climb_min_time: float = 0.10
## Minimum horizontal speed needed for wall-run to climb conversion.
@export var wall_run_to_climb_min_speed: float = 2.8
## Forward W input needed before wall-run can convert into climb; 0 allows look-only conversion.
@export var wall_run_to_climb_forward_input_threshold: float = 0.0
## Required look alignment into the climb wall.
@export var wall_run_to_climb_look_alignment: float = 0.68
## Extra front probe distance while wall running so the transition catches reliably.
@export var wall_run_to_climb_extra_probe_distance: float = 0.22

@export_group("Run Motion")
## Target speed along the wall.
@export var wall_run_speed: float = 7.8
## Highest target speed allowed after sprint, entry, and combo bonuses.
@export var wall_run_max_speed: float = 12.0
## How much normal sprint speed can pull the wall run above its base speed.
@export var wall_run_input_speed_influence: float = 0.34
## Portion of combo speed added to wall run speed.
@export var wall_run_combo_speed_multiplier: float = 0.3
## Acceleration used to blend into wall run speed.
@export var wall_run_acceleration: float = 12.0
## How quickly speed above the wall-run cap is bled off.
@export var wall_run_excess_speed_decay: float = 5.4
## How much movement input can steer along the wall plane.
@export var wall_run_input_direction_blend: float = 0.34
## Small inward push that keeps contact with the wall.
@export var wall_stick_speed: float = 0.86
## Gravity multiplier while attached to a wall.
@export var wall_run_gravity_multiplier: float = 0.34
## Downward velocity clamp while wall running.
@export var wall_run_min_vertical_velocity: float = -4.25
## Upward velocity kept when starting a wall run.
@export var wall_run_max_upward_velocity: float = 1.75
## How fast extra upward velocity is softened on the wall.
@export var wall_run_upward_damping: float = 9.2

@export_group("Vertical Arc")
## Time where wall run pulls the player upward.
@export var wall_run_climb_time: float = 0.34
## Upward velocity used at the start of the wall run climb.
@export var wall_run_climb_velocity: float = 2.65
## Small vertical speed held after the initial climb.
@export var wall_run_float_velocity: float = 0.18
## Time after climb where the player hangs before dropping.
@export var wall_run_float_time: float = 0.18
## Downward velocity reached near the end of the wall run.
@export var wall_run_end_drop_velocity: float = -3.85
## Smooth curve used when changing from float to drop.
@export var wall_run_drop_curve: float = 1.45
## Blend speed used to follow the wall-run vertical arc.
@export var wall_run_vertical_arc_lerp_speed: float = 8.5
## Gravity multiplier during the first upward wall-run pull.
@export var wall_run_climb_gravity_multiplier: float = 0.04
## Gravity multiplier while the wall run is floating.
@export var wall_run_float_gravity_multiplier: float = 0.12

@export_group("Speed Scaling")
## Horizontal speed that gives full entry-speed scaling.
@export var speed_to_full_wall_run_bonus: float = 13.5
## Portion of entry speed added to wall run speed.
@export var wall_run_entry_speed_multiplier: float = 0.1
## Extra speed added at full sprint ramp.
@export var wall_run_sprint_speed_bonus: float = 0.72
## Portion of combo speed added to wall run speed.
@export var wall_run_combo_extra_multiplier: float = 0.18
## Extra wall run time from fast entry speed.
@export var entry_speed_duration_bonus: float = 0.28
## Extra wall run time from full sprint ramp.
@export var sprint_duration_bonus: float = 0.22
## Extra wall run time from combo speed.
@export var combo_duration_bonus: float = 0.25
## Enables stronger wall-run speed and duration from the speed used to enter the state.
@export var enable_entry_speed_range_scaling: bool = true
## Entry speed where the extra range scaling starts.
@export var entry_speed_range_min_speed: float = 4.4
## Entry speed that reaches full extra wall-run range scaling.
@export var entry_speed_range_full_speed: float = 18.0
## Curve for how entry speed turns into range scaling.
@export var entry_speed_range_curve: float = 0.88
## Extra target wall-run speed at full entry-speed range scaling.
@export var entry_speed_range_target_speed_bonus: float = 2.35
## Extra wall-run max speed at full entry-speed range scaling.
@export var entry_speed_range_max_speed_bonus: float = 4.65
## Extra wall-run time at full entry-speed range scaling.
@export var entry_speed_range_duration_bonus: float = 0.85

@export_group("Wall Jump")
## Upward velocity applied by a wall jump.
@export var wall_jump_up_velocity: float = 7.8
## Horizontal speed pushed away from the wall.
@export var wall_jump_away_speed: float = 6.9
## Forward speed carried along the wall jump direction.
@export var wall_jump_forward_speed: float = 8.8
## Portion of combo speed added to wall jump speed.
@export var wall_jump_combo_speed_multiplier: float = 0.62
## Portion of wall-run entry speed added to wall jump carry.
@export var wall_jump_entry_speed_multiplier: float = 0.14
## Maximum horizontal speed after a wall jump.
@export var wall_jump_max_horizontal_speed: float = 17.2
## Blend from wall direction toward current input during wall jump.
@export var wall_jump_input_blend: float = 0.35
## Allows jumping during soft release to launch away from the stored wall.
@export var enable_wall_release_jump: bool = true
## Extra away-from-wall push when jumping during soft release.
@export var wall_release_jump_away_multiplier: float = 1.18
## Along-wall carry kept when jumping during soft release.
@export var wall_release_jump_forward_multiplier: float = 0.82
## Extra away push added by holding the opposite direction during release jump.
@export var wall_release_jump_input_away_bonus: float = 1.8
## Vertical power multiplier for release jumps; lower keeps the jump more directional.
@export var wall_release_jump_up_multiplier: float = 0.96
## Extra horizontal speed cap allowed for release jumps.
@export var wall_release_jump_max_speed_bonus: float = 1.8

@export_group("Soft Release")
## Enables smooth wall-run release when pressing away from the wall or losing wall contact.
@export var enable_soft_wall_release: bool = true
## Away-from-wall input needed before the player softly leaves the wall.
@export var wall_release_away_input_threshold: float = 0.42
## Time the release state keeps wall-run camera and hand feel fading out.
@export var wall_release_duration: float = 0.34
## Outward speed applied when leaving the wall without jumping.
@export var wall_release_away_speed: float = 3.2
## Portion of current along-wall speed kept during release.
@export var wall_release_forward_carry: float = 0.82
## How much the player's current input can steer the release.
@export var wall_release_input_blend: float = 0.62
## Maximum horizontal speed allowed during the soft release.
@export var wall_release_max_horizontal_speed: float = 11.0
## Acceleration used to blend into the release velocity.
@export var wall_release_acceleration: float = 8.5
## Highest upward velocity kept when softly leaving the wall.
@export var wall_release_max_upward_velocity: float = 0.75
## Gravity multiplier for the first part of the soft release.
@export var wall_release_initial_gravity_multiplier: float = 0.42
## Gravity multiplier after the soft release starts falling away.
@export var wall_release_gravity_multiplier: float = 0.86

@export_group("Feel")
## Blend speed used by the player wall run state.
@export var wall_run_blend_lerp_speed: float = 12.0
## Initial blend amount when wall run starts.
@export var wall_run_enter_blend: float = 0.42
## Blend speed used when a wall run stops normally.
@export var wall_run_exit_blend_lerp_speed: float = 8.0
## Blend speed used while softly releasing from the wall.
@export var wall_run_release_blend_lerp_speed: float = 5.6


@export_group("Talons")
## Wall runs last this many times longer while the talons are in hand.
@export var talon_duration_multiplier: float = 1.5

var _talon_bonus_active: bool = false
var _active_entry_horizontal_speed: float = 0.0
var _active_sprint_blend: float = 0.0
var _active_combo_speed_bonus: float = 0.0


func set_wall_run_speed_context(entry_horizontal_speed: float, sprint_blend: float, combo_speed_bonus: float) -> void:
	_active_entry_horizontal_speed = maxf(entry_horizontal_speed, 0.0)
	_active_sprint_blend = clampf(sprint_blend, 0.0, 1.0)
	_active_combo_speed_bonus = maxf(combo_speed_bonus, 0.0)


func can_attach_to_wall(wall_normal: Vector3, last_wall_jump_normal: Vector3, lockout_timer: float) -> bool:
	if not is_valid_wall_normal(wall_normal):
		return false
	if lockout_timer <= 0.0 or last_wall_jump_normal == Vector3.ZERO:
		return true

	var same_wall_dot: float = wall_normal.normalized().dot(last_wall_jump_normal.normalized())
	return same_wall_dot < clampf(same_wall_dot_threshold, -1.0, 1.0)


func is_side_wall_hit(ray_direction: Vector3, wall_normal: Vector3) -> bool:
	var clean_ray_direction: Vector3 = get_horizontal_direction(ray_direction)
	var clean_wall_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if clean_ray_direction == Vector3.ZERO or clean_wall_normal == Vector3.ZERO:
		return false
	return clean_ray_direction.dot(-clean_wall_normal) >= clampf(min_side_wall_alignment, -1.0, 1.0)


func can_start_wall_run(
	on_floor: bool,
	is_crouching: bool,
	is_sliding: bool,
	wish_direction: Vector3,
	horizontal_speed: float,
	vertical_velocity: float,
	wall_normal: Vector3,
	last_wall_jump_normal: Vector3,
	lockout_timer: float
) -> bool:
	if not enable_wall_run:
		return false
	if on_floor or is_crouching or is_sliding:
		return false
	if wish_direction == Vector3.ZERO:
		return false
	if horizontal_speed < min_start_horizontal_speed:
		return false
	if vertical_velocity > max_start_upward_velocity or vertical_velocity < min_start_vertical_velocity:
		return false
	if not can_attach_to_wall(wall_normal, last_wall_jump_normal, lockout_timer):
		return false

	var run_direction: Vector3 = get_wall_run_direction(wall_normal, wish_direction)
	return wish_direction.normalized().dot(run_direction) >= min_forward_alignment


func can_continue_wall_run(
	wish_direction: Vector3,
	horizontal_speed: float,
	wall_run_timer: float,
	wall_normal: Vector3
) -> bool:
	if not enable_wall_run:
		return false
	if wall_run_timer > get_wall_run_time_limit():
		return false
	if not is_valid_wall_normal(wall_normal):
		return false
	if wish_direction == Vector3.ZERO:
		return false
	return horizontal_speed >= min_keep_horizontal_speed


func should_soft_release_wall_run(desired_direction: Vector3, wall_normal: Vector3) -> bool:
	if not enable_soft_wall_release:
		return false

	var clean_wall_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	var clean_desired_direction: Vector3 = get_horizontal_direction(desired_direction)
	if clean_wall_normal == Vector3.ZERO or clean_desired_direction == Vector3.ZERO:
		return false

	var away_input: float = clean_desired_direction.dot(clean_wall_normal)
	return away_input >= clampf(wall_release_away_input_threshold, 0.0, 1.0)


func can_transition_to_front_climb(
	wall_run_timer: float,
	horizontal_speed: float,
	player_forward_direction: Vector3,
	move_input: Vector2,
	front_wall_normal: Vector3
) -> bool:
	if not enable_wall_run_to_climb:
		return false
	if wall_run_timer < maxf(wall_run_to_climb_min_time, 0.0):
		return false
	if horizontal_speed < maxf(wall_run_to_climb_min_speed, 0.0):
		return false
	if move_input.y > -maxf(wall_run_to_climb_forward_input_threshold, 0.0):
		return false
	if not is_valid_wall_normal(front_wall_normal):
		return false

	var clean_forward: Vector3 = get_horizontal_direction(player_forward_direction)
	var climb_direction: Vector3 = -get_horizontal_wall_normal(front_wall_normal)
	if clean_forward == Vector3.ZERO or climb_direction == Vector3.ZERO:
		return false

	return clean_forward.dot(climb_direction) >= clampf(wall_run_to_climb_look_alignment, -1.0, 1.0)


func is_valid_wall_normal(wall_normal: Vector3) -> bool:
	if wall_normal.length_squared() <= 0.001:
		return false
	return wall_normal.y >= wall_min_normal_y and wall_normal.y <= wall_max_normal_y


func get_wall_run_direction(wall_normal: Vector3, desired_direction: Vector3) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if horizontal_normal == Vector3.ZERO:
		return Vector3.ZERO

	var direction_a: Vector3 = horizontal_normal.cross(Vector3.UP).normalized()
	var direction_b: Vector3 = -direction_a
	if desired_direction == Vector3.ZERO:
		return direction_a
	if desired_direction.normalized().dot(direction_b) > desired_direction.normalized().dot(direction_a):
		return direction_b
	return direction_a


func get_wall_side(wall_normal: Vector3, player_yaw: float) -> int:
	var right_direction: Vector3 = Basis(Vector3.UP, player_yaw).x.normalized()
	var side_dot: float = get_horizontal_wall_normal(wall_normal).dot(right_direction)
	if side_dot > 0.0:
		return -1
	return 1


func get_wall_run_target_speed(input_target_speed: float, combo_speed_bonus: float) -> float:
	var combo_speed: float = maxf(maxf(combo_speed_bonus, 0.0), _active_combo_speed_bonus)
	var entry_range_ratio: float = _get_entry_speed_range_ratio()
	var base_speed: float = maxf(wall_run_speed, 0.0)
	var input_bonus: float = maxf(maxf(input_target_speed, 0.0) - base_speed, 0.0)
	input_bonus *= clampf(wall_run_input_speed_influence, 0.0, 1.0)
	var entry_bonus: float = _active_entry_horizontal_speed * maxf(wall_run_entry_speed_multiplier, 0.0)
	entry_bonus += entry_range_ratio * maxf(entry_speed_range_target_speed_bonus, 0.0)
	var sprint_bonus: float = _active_sprint_blend * maxf(wall_run_sprint_speed_bonus, 0.0)
	var combo_bonus: float = combo_speed * maxf(wall_run_combo_speed_multiplier + wall_run_combo_extra_multiplier, 0.0)
	var speed_limit: float = get_wall_run_speed_limit()
	return minf(base_speed + input_bonus + entry_bonus + sprint_bonus + combo_bonus, speed_limit)


func get_wall_run_speed_limit() -> float:
	var entry_range_ratio: float = _get_entry_speed_range_ratio()
	var base_speed_limit: float = maxf(wall_run_max_speed, maxf(wall_run_speed, 0.0))
	base_speed_limit += entry_range_ratio * maxf(entry_speed_range_max_speed_bonus, 0.0)
	return base_speed_limit


## Talons in hand (pushed by the player every tick): wall runs last talon_duration_multiplier longer.
func set_talon_bonus(active: bool) -> void:
	_talon_bonus_active = active


func get_wall_run_time_limit() -> float:
	var entry_ratio: float = _get_entry_speed_ratio()
	var combo_ratio: float = clampf(_active_combo_speed_bonus / maxf(MovementRun.combo_max_speed_bonus, 0.001), 0.0, 1.0)
	var bonus_time: float = 0.0
	bonus_time += entry_ratio * maxf(entry_speed_duration_bonus, 0.0)
	bonus_time += _active_sprint_blend * maxf(sprint_duration_bonus, 0.0)
	bonus_time += combo_ratio * maxf(combo_duration_bonus, 0.0)
	bonus_time += _get_entry_speed_range_ratio() * maxf(entry_speed_range_duration_bonus, 0.0)
	bonus_time = minf(bonus_time, maxf(max_bonus_wall_run_time, 0.0))
	var limit: float = maxf(max_wall_run_time, 0.0) + bonus_time
	if _talon_bonus_active:
		limit *= maxf(talon_duration_multiplier, 0.0)
	return limit


func get_wall_run_horizontal_velocity(
	current_horizontal_velocity: Vector3,
	wall_direction: Vector3,
	wall_normal: Vector3,
	desired_direction: Vector3,
	target_speed: float,
	delta: float
) -> Vector3:
	if wall_direction == Vector3.ZERO:
		return current_horizontal_velocity

	var clean_wall_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if clean_wall_normal == Vector3.ZERO:
		return current_horizontal_velocity

	var controlled_direction: Vector3 = _get_controlled_wall_run_direction(
		wall_direction,
		clean_wall_normal,
		desired_direction
	)
	if controlled_direction == Vector3.ZERO:
		return current_horizontal_velocity

	var speed_limit: float = get_wall_run_speed_limit()
	var desired_speed: float = clampf(target_speed, 0.0, speed_limit)
	var planar_velocity: Vector3 = current_horizontal_velocity.slide(clean_wall_normal)
	planar_velocity.y = 0.0

	var planar_speed: float = planar_velocity.length()
	if planar_speed > speed_limit:
		var decay_blend: float = 1.0 - exp(-maxf(wall_run_excess_speed_decay, 0.001) * delta)
		planar_velocity = planar_velocity.normalized() * lerpf(planar_speed, speed_limit, decay_blend)

	var target_velocity: Vector3 = controlled_direction * desired_speed
	var blend: float = 1.0 - exp(-maxf(wall_run_acceleration, 0.001) * delta)
	var next_velocity: Vector3 = planar_velocity.lerp(target_velocity, blend)
	next_velocity += -clean_wall_normal * maxf(wall_stick_speed, 0.0)
	next_velocity.y = 0.0
	return next_velocity


func get_wall_run_vertical_velocity(current_vertical_velocity: float, wall_run_timer: float, delta: float) -> float:
	var vertical_velocity: float = current_vertical_velocity
	if vertical_velocity > wall_run_max_upward_velocity:
		var damping_blend: float = 1.0 - exp(-maxf(wall_run_upward_damping, 0.001) * delta)
		vertical_velocity = lerpf(vertical_velocity, wall_run_max_upward_velocity, damping_blend)

	var arc_target_velocity: float = _get_wall_run_arc_target_velocity(wall_run_timer)
	var arc_blend: float = 1.0 - exp(-maxf(wall_run_vertical_arc_lerp_speed, 0.001) * delta)
	vertical_velocity = lerpf(vertical_velocity, arc_target_velocity, arc_blend)

	var gravity_multiplier: float = _get_wall_run_arc_gravity_multiplier(wall_run_timer)
	vertical_velocity -= WorldBasicRules.get_gravity() * gravity_multiplier * delta
	return maxf(vertical_velocity, wall_run_min_vertical_velocity)


func get_wall_run_release_horizontal_velocity(
	current_horizontal_velocity: Vector3,
	wall_direction: Vector3,
	wall_normal: Vector3,
	desired_direction: Vector3,
	delta: float
) -> Vector3:
	var clean_wall_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if clean_wall_normal == Vector3.ZERO:
		return current_horizontal_velocity

	var clean_wall_direction: Vector3 = get_horizontal_direction(wall_direction)
	if clean_wall_direction == Vector3.ZERO:
		clean_wall_direction = current_horizontal_velocity.slide(clean_wall_normal)
		clean_wall_direction.y = 0.0
		if clean_wall_direction.length_squared() <= 0.001:
			clean_wall_direction = clean_wall_normal.cross(Vector3.UP).normalized()
		else:
			clean_wall_direction = clean_wall_direction.normalized()

	var along_wall_speed: float = maxf(current_horizontal_velocity.dot(clean_wall_direction), 0.0)
	var target_velocity: Vector3 = clean_wall_direction * along_wall_speed * clampf(wall_release_forward_carry, 0.0, 1.0)
	target_velocity += clean_wall_normal * maxf(wall_release_away_speed, 0.0)

	var clean_desired_direction: Vector3 = get_horizontal_direction(desired_direction)
	if clean_desired_direction != Vector3.ZERO:
		var input_speed: float = maxf(current_horizontal_velocity.length(), maxf(wall_release_away_speed, 0.0))
		var input_velocity: Vector3 = clean_desired_direction * input_speed
		input_velocity += clean_wall_normal * maxf(wall_release_away_speed, 0.0) * 0.35
		target_velocity = target_velocity.lerp(input_velocity, clampf(wall_release_input_blend, 0.0, 1.0))

	var max_release_speed: float = maxf(wall_release_max_horizontal_speed, 0.0)
	if max_release_speed > 0.0 and target_velocity.length() > max_release_speed:
		target_velocity = target_velocity.normalized() * max_release_speed

	var release_blend: float = 1.0 - exp(-maxf(wall_release_acceleration, 0.001) * delta)
	var release_velocity: Vector3 = current_horizontal_velocity.lerp(target_velocity, release_blend)
	release_velocity.y = 0.0
	return release_velocity


func get_wall_run_release_vertical_velocity(current_vertical_velocity: float, release_timer: float, delta: float) -> float:
	var vertical_velocity: float = minf(current_vertical_velocity, maxf(wall_release_max_upward_velocity, 0.0))
	var release_ratio: float = clampf(release_timer / maxf(wall_release_duration, 0.001), 0.0, 1.0)
	var gravity_multiplier: float = lerpf(
		maxf(wall_release_initial_gravity_multiplier, 0.0),
		maxf(wall_release_gravity_multiplier, 0.0),
		release_ratio
	)
	vertical_velocity -= WorldBasicRules.get_gravity() * gravity_multiplier * delta
	return maxf(vertical_velocity, -WorldBasicRules.get_terminal_fall_speed())


func get_wall_jump_velocity(
	current_velocity: Vector3,
	wall_normal: Vector3,
	wall_direction: Vector3,
	wish_direction: Vector3,
	combo_speed_bonus: float
) -> Vector3:
	var away_direction: Vector3 = get_horizontal_wall_normal(wall_normal)
	var forward_direction: Vector3 = wall_direction
	if wish_direction != Vector3.ZERO:
		var input_direction: Vector3 = wish_direction.slide(away_direction)
		input_direction.y = 0.0
		if input_direction.length_squared() > 0.001:
			var input_blend: float = clampf(wall_jump_input_blend, 0.0, 1.0)
			forward_direction = wall_direction.lerp(input_direction.normalized(), input_blend).normalized()

	var combo_speed: float = maxf(combo_speed_bonus, 0.0) * maxf(wall_jump_combo_speed_multiplier, 0.0)
	var entry_jump_speed: float = _active_entry_horizontal_speed * maxf(wall_jump_entry_speed_multiplier, 0.0)
	var horizontal_velocity: Vector3 = away_direction * maxf(wall_jump_away_speed, 0.0)
	horizontal_velocity += forward_direction * (maxf(wall_jump_forward_speed, 0.0) + combo_speed + entry_jump_speed)

	var current_horizontal_velocity: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var forward_speed: float = current_horizontal_velocity.dot(forward_direction)
	if forward_speed > horizontal_velocity.dot(forward_direction):
		horizontal_velocity += forward_direction * (forward_speed - horizontal_velocity.dot(forward_direction))

	var max_horizontal_speed: float = maxf(wall_jump_max_horizontal_speed, 0.0) + combo_speed + entry_jump_speed
	if horizontal_velocity.length() > max_horizontal_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_speed

	return Vector3(horizontal_velocity.x, maxf(wall_jump_up_velocity, 0.0), horizontal_velocity.z)


func get_wall_release_jump_velocity(
	current_velocity: Vector3,
	wall_normal: Vector3,
	wall_direction: Vector3,
	wish_direction: Vector3,
	combo_speed_bonus: float
) -> Vector3:
	var base_velocity: Vector3 = get_wall_jump_velocity(
		current_velocity,
		wall_normal,
		wall_direction,
		wish_direction,
		combo_speed_bonus
	)
	var away_direction: Vector3 = get_horizontal_wall_normal(wall_normal)
	if away_direction == Vector3.ZERO:
		return base_velocity

	var wall_carry_direction: Vector3 = get_horizontal_direction(wall_direction)
	var base_horizontal_velocity: Vector3 = Vector3(base_velocity.x, 0.0, base_velocity.z)
	var away_speed: float = maxf(base_horizontal_velocity.dot(away_direction), 0.0)
	away_speed *= maxf(wall_release_jump_away_multiplier, 0.0)

	var forward_speed: float = 0.0
	if wall_carry_direction != Vector3.ZERO:
		forward_speed = maxf(base_horizontal_velocity.dot(wall_carry_direction), 0.0)
		forward_speed *= maxf(wall_release_jump_forward_multiplier, 0.0)

	var input_direction: Vector3 = get_horizontal_direction(wish_direction)
	if input_direction != Vector3.ZERO:
		var away_input: float = maxf(input_direction.dot(away_direction), 0.0)
		away_speed += away_input * maxf(wall_release_jump_input_away_bonus, 0.0)

	var horizontal_velocity: Vector3 = away_direction * away_speed
	if wall_carry_direction != Vector3.ZERO:
		horizontal_velocity += wall_carry_direction * forward_speed

	var max_horizontal_speed: float = maxf(wall_jump_max_horizontal_speed, 0.0)
	max_horizontal_speed += maxf(wall_release_jump_max_speed_bonus, 0.0)
	if max_horizontal_speed > 0.0 and horizontal_velocity.length() > max_horizontal_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_speed

	var vertical_velocity: float = maxf(base_velocity.y * maxf(wall_release_jump_up_multiplier, 0.0), 0.0)
	return Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)


func get_wall_run_blend(
	current_blend: float,
	is_wall_running: bool,
	delta: float,
	is_wall_releasing: bool = false
) -> float:
	var target_blend: float = 0.0
	if is_wall_running:
		target_blend = 1.0

	var blend_speed: float = wall_run_exit_blend_lerp_speed
	if is_wall_running:
		blend_speed = wall_run_blend_lerp_speed
	elif is_wall_releasing:
		blend_speed = wall_run_release_blend_lerp_speed

	var blend_amount: float = 1.0 - exp(-maxf(blend_speed, 0.001) * delta)
	return lerpf(current_blend, target_blend, blend_amount)


func get_horizontal_wall_normal(wall_normal: Vector3) -> Vector3:
	var horizontal_normal: Vector3 = Vector3(wall_normal.x, 0.0, wall_normal.z)
	if horizontal_normal.length_squared() <= 0.001:
		return Vector3.ZERO
	return horizontal_normal.normalized()


func get_horizontal_direction(direction: Vector3) -> Vector3:
	var horizontal_direction: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if horizontal_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return horizontal_direction.normalized()


func _get_entry_speed_ratio() -> float:
	return clampf(_active_entry_horizontal_speed / maxf(speed_to_full_wall_run_bonus, 0.001), 0.0, 1.0)


func _get_entry_speed_range_ratio() -> float:
	if not enable_entry_speed_range_scaling:
		return 0.0

	var min_speed: float = maxf(entry_speed_range_min_speed, 0.0)
	var full_speed: float = maxf(entry_speed_range_full_speed, min_speed + 0.001)
	var speed_ratio: float = clampf(
		(_active_entry_horizontal_speed - min_speed) / maxf(full_speed - min_speed, 0.001),
		0.0,
		1.0
	)
	return pow(speed_ratio, maxf(entry_speed_range_curve, 0.001))


func _get_wall_run_arc_target_velocity(wall_run_timer: float) -> float:
	var climb_time: float = maxf(wall_run_climb_time, 0.0)
	var float_time: float = maxf(wall_run_float_time, 0.0)
	if climb_time > 0.0 and wall_run_timer < climb_time:
		var climb_ratio: float = clampf(wall_run_timer / climb_time, 0.0, 1.0)
		return lerpf(wall_run_climb_velocity, wall_run_float_velocity, climb_ratio)

	var drop_start_time: float = climb_time + float_time
	if wall_run_timer < drop_start_time:
		return wall_run_float_velocity

	var drop_duration: float = maxf(get_wall_run_time_limit() - drop_start_time, 0.001)
	var drop_ratio: float = clampf((wall_run_timer - drop_start_time) / drop_duration, 0.0, 1.0)
	var shaped_drop_ratio: float = pow(drop_ratio, maxf(wall_run_drop_curve, 0.001))
	return lerpf(wall_run_float_velocity, wall_run_end_drop_velocity, shaped_drop_ratio)


func _get_wall_run_arc_gravity_multiplier(wall_run_timer: float) -> float:
	if wall_run_timer < maxf(wall_run_climb_time, 0.0):
		return maxf(wall_run_climb_gravity_multiplier, 0.0)
	if wall_run_timer < maxf(wall_run_climb_time, 0.0) + maxf(wall_run_float_time, 0.0):
		return maxf(wall_run_float_gravity_multiplier, 0.0)
	return maxf(wall_run_gravity_multiplier, 0.0)


func _get_controlled_wall_run_direction(
	wall_direction: Vector3,
	wall_normal: Vector3,
	desired_direction: Vector3
) -> Vector3:
	var clean_wall_direction: Vector3 = wall_direction
	clean_wall_direction.y = 0.0
	if clean_wall_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	clean_wall_direction = clean_wall_direction.normalized()

	var input_wall_direction: Vector3 = desired_direction.slide(wall_normal)
	input_wall_direction.y = 0.0
	if input_wall_direction.length_squared() <= 0.001:
		return clean_wall_direction

	var input_blend: float = clampf(wall_run_input_direction_blend, 0.0, 1.0)
	return clean_wall_direction.lerp(input_wall_direction.normalized(), input_blend).normalized()
