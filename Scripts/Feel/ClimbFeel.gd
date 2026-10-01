extends Node

@export_group("Feedback")
## Minimum feedback strength when hands catch a wall.
@export var climb_feedback_min_strength: float = 0.88
## Extra feedback strength from wall entry speed.
@export var climb_feedback_speed_multiplier: float = 0.20
## Time recent climb feedback stays readable by hands.
@export var recent_feedback_time: float = 0.34

@export_group("Wall Run To Climb Feedback")
## Extra catch feedback when wall run converts into wall climb.
@export var wall_run_to_climb_feedback_multiplier: float = 1.22
## How much active wall-run camera blend strengthens the climb catch.
@export var wall_run_to_climb_blend_bonus: float = 0.18

@export_group("Climb Edge Feedback")
## Minimum feedback when climb edge help pulls the player onto a top.
@export var climb_edge_feedback_min_strength: float = 1.00
## Extra feedback from how much height the edge help solved.
@export var climb_edge_lift_feedback_multiplier: float = 0.18
## Extra feedback from entry speed into the climb edge help.
@export var climb_edge_speed_feedback_multiplier: float = 0.06

@export_group("Climb Edge Over Camera")
## Time used by the smooth pull-over camera animation.
@export var climb_edge_over_duration: float = 0.48
## Extra animation time added for stronger edge-over assists.
@export var climb_edge_over_duration_bonus: float = 0.14
## Minimum camera lerp speed while the edge-over animation is active.
@export var climb_edge_over_camera_lerp_speed: float = 18.0
## Early soft dip as the body loads onto the ledge.
@export var climb_edge_over_preload_position: Vector3 = Vector3(0.0, -0.070, -0.046)
## Main upward and forward pull over the ledge.
@export var climb_edge_over_pull_position: Vector3 = Vector3(0.0, 0.105, 0.135)
## Small settling motion after the body clears the ledge.
@export var climb_edge_over_settle_position: Vector3 = Vector3(0.0, -0.024, 0.038)
## Early camera rotation while loading weight onto the arms.
@export var climb_edge_over_preload_rotation_degrees: Vector3 = Vector3(3.4, 0.0, 0.35)
## Camera rotation while being pulled forward over the ledge.
@export var climb_edge_over_pull_rotation_degrees: Vector3 = Vector3(-4.4, 0.0, -0.45)
## Small settling rotation after clearing the ledge.
@export var climb_edge_over_settle_rotation_degrees: Vector3 = Vector3(1.05, 0.0, 0.16)
## FOV pulse used during the smooth edge-over pull.
@export var climb_edge_over_fov_bonus: float = 1.95
## Limits very strong edge assists so the camera never snaps too hard.
@export var climb_edge_over_max_strength: float = 1.25
## Extra time the camera keeps the settled-on-top pose after the body clears the edge.
@export var climb_edge_over_finish_feedback_duration: float = 0.24

@export_group("Climb Edge Over Hands")
## Extra root hand offset while the player pulls over a ledge.
@export var climb_edge_over_hand_root_position: Vector3 = Vector3(0.0, -0.045, 0.055)
## Extra root hand rotation while the player pulls over a ledge.
@export var climb_edge_over_hand_root_rotation_degrees: Vector3 = Vector3(-3.0, 0.0, 0.0)
## Left hand placement while gripping over the ledge.
@export var climb_edge_over_left_hand_position_offset: Vector3 = Vector3(-0.075, 0.020, 0.080)
## Right hand placement while gripping over the ledge.
@export var climb_edge_over_right_hand_position_offset: Vector3 = Vector3(0.075, 0.010, 0.070)
## Left hand rotation while gripping over the ledge.
@export var climb_edge_over_left_hand_rotation_degrees: Vector3 = Vector3(-8.0, -4.0, -6.0)
## Right hand rotation while gripping over the ledge.
@export var climb_edge_over_right_hand_rotation_degrees: Vector3 = Vector3(-7.0, 4.0, 6.0)

@export_group("Climb Edge Hold Camera")
## Camera offset while the player hangs below a held ledge.
@export var edge_hold_camera_position: Vector3 = Vector3(0.0, -0.058, 0.060)
## Camera rotation while body weight is hanging from the arms.
@export var edge_hold_camera_rotation_degrees: Vector3 = Vector3(2.8, 0.0, 0.45)
## Small FOV push while hanging on an edge.
@export var edge_hold_fov_bonus: float = 0.85
## Minimum camera lerp speed while hanging from an edge.
@export var edge_hold_camera_lerp_speed: float = 18.0

@export_group("Climb Edge Hold Hands")
## Root hand offset while both hands are gripping the ledge.
@export var edge_hold_hand_root_position: Vector3 = Vector3(0.0, -0.015, 0.125)
## Root hand rotation while hanging under the ledge.
@export var edge_hold_hand_root_rotation_degrees: Vector3 = Vector3(-6.5, 0.0, 0.0)
## Left hand position while gripping the top edge.
@export var edge_hold_left_hand_position_offset: Vector3 = Vector3(-0.115, 0.095, 0.170)
## Right hand position while gripping the top edge.
@export var edge_hold_right_hand_position_offset: Vector3 = Vector3(0.115, 0.085, 0.160)
## Left hand rotation while gripping the top edge.
@export var edge_hold_left_hand_rotation_degrees: Vector3 = Vector3(-12.0, -7.0, -10.0)
## Right hand rotation while gripping the top edge.
@export var edge_hold_right_hand_rotation_degrees: Vector3 = Vector3(-11.5, 7.0, 10.0)
## Side hand reach while shimmying along a held ledge.
@export var edge_hold_shimmy_side_offset: float = 0.020
## Extra vertical hand load while shimmying along a held ledge.
@export var edge_hold_shimmy_vertical_offset: float = 0.014

@export_group("Camera")
## Camera lift while the player climbs upward.
@export var climb_camera_up_offset: float = 0.060
## Camera push toward the wall while climbing.
@export var climb_camera_forward_offset: float = 0.040
## Early camera dip when hands first catch the wall.
@export var climb_camera_early_dip: float = 0.046
## Late camera settle as the climb loses power.
@export var climb_camera_late_drop: float = 0.026
## Camera pitch while pulling upward on the wall.
@export var climb_camera_pitch_degrees: float = -2.4
## Camera roll sway from alternating hands.
@export var climb_camera_roll_degrees: float = 1.35
## Camera yaw sway from alternating hands.
@export var climb_camera_yaw_degrees: float = 1.05
## Extra FOV while the climb is active.
@export var climb_fov_bonus: float = 6.35
## Minimum camera lerp speed while climbing.
@export var climb_camera_lerp_speed: float = 17.0
## How strongly climb overrides normal turn camera effects.
@export var climb_turn_effect_override: float = 0.46

@export_group("Camera Start Kick")
## Camera impulse when hands catch the wall.
@export var climb_start_camera_position: Vector3 = Vector3(0.0, -0.062, 0.052)
## Camera rotation impulse when hands catch the wall.
@export var climb_start_camera_rotation_degrees: Vector3 = Vector3(3.6, 0.0, 0.8)
## Camera lift velocity added when climb starts.
@export var climb_start_lift_velocity: float = 0.34

@export_group("Hands")
## Root hand offset while palms are on the wall.
@export var climb_hand_root_position: Vector3 = Vector3(0.0, 0.032, 0.225)
## Root hand rotation while palms are on the wall.
@export var climb_hand_root_rotation_degrees: Vector3 = Vector3(-8.5, 0.0, 0.0)
## Left hand base placement while climbing upward.
@export var climb_left_hand_position_offset: Vector3 = Vector3(-0.090, 0.116, 0.285)
## Right hand base placement while climbing upward.
@export var climb_right_hand_position_offset: Vector3 = Vector3(0.090, 0.092, 0.255)
## Left hand base rotation while climbing upward.
@export var climb_left_hand_rotation_degrees: Vector3 = Vector3(-17.0, -8.0, -14.0)
## Right hand base rotation while climbing upward.
@export var climb_right_hand_rotation_degrees: Vector3 = Vector3(-14.0, 8.5, 13.0)
## Number of alternating hand pulls across a full climb.
@export var climb_hand_cycles: float = 3.75
## Vertical offset from alternating hand pulls.
@export var climb_hand_alternate_height: float = 0.054
## Forward reach when a hand plants on the wall.
@export var climb_hand_reach_amount: float = 0.050
## Pullback amount when a hand is dragging down the wall.
@export var climb_hand_pullback_amount: float = 0.030
## Extra hand kick from the first wall catch.
@export var climb_hand_catch_kick_position: Vector3 = Vector3(0.0, 0.055, 0.092)
## Extra hand rotation kick from the first wall catch.
@export var climb_hand_catch_kick_rotation_degrees: Vector3 = Vector3(-7.0, 0.0, 0.0)


func get_wall_climb_feedback_strength(entry_horizontal_speed: float) -> float:
	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var strength: float = maxf(climb_feedback_min_strength, 0.0)
	strength += speed_ratio * maxf(climb_feedback_speed_multiplier, 0.0)
	return strength


func get_wall_run_to_climb_feedback_strength(entry_horizontal_speed: float, wall_run_blend: float) -> float:
	var strength: float = get_wall_climb_feedback_strength(entry_horizontal_speed)
	var transition_multiplier: float = maxf(wall_run_to_climb_feedback_multiplier, 0.0)
	transition_multiplier += clampf(wall_run_blend, 0.0, 1.0) * maxf(wall_run_to_climb_blend_bonus, 0.0)
	return strength * transition_multiplier


func get_climb_edge_help_feedback_strength(
	lift_height: float,
	max_lift_height: float,
	entry_horizontal_speed: float
) -> float:
	var lift_ratio: float = clampf(lift_height / maxf(max_lift_height, 0.001), 0.0, 1.0)
	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var strength: float = maxf(climb_edge_feedback_min_strength, 0.0)
	strength += lift_ratio * maxf(climb_edge_lift_feedback_multiplier, 0.0)
	strength += speed_ratio * maxf(climb_edge_speed_feedback_multiplier, 0.0)
	return strength


func get_climb_edge_over_duration(strength: float) -> float:
	var strength_ratio: float = clampf(maxf(strength, 0.0) / maxf(climb_edge_over_max_strength, 0.001), 0.0, 1.0)
	return maxf(climb_edge_over_duration + (strength_ratio * maxf(climb_edge_over_duration_bonus, 0.0)), 0.001)


func get_climb_edge_over_total_duration(action_duration: float) -> float:
	return maxf(action_duration, 0.001) + maxf(climb_edge_over_finish_feedback_duration, 0.0)


func is_climb_edge_over_feedback_finished(timer: float, action_duration: float) -> bool:
	return timer >= get_climb_edge_over_total_duration(action_duration)


func get_climb_edge_over_camera_position(timer: float, duration: float, strength: float) -> Vector3:
	var progress: float = _get_timed_progress(timer, duration)
	var strength_scale: float = _get_edge_over_strength_scale(strength)
	var feedback_keep: float = _get_edge_over_feedback_keep(timer, duration)
	var preload_weight: float = _smooth_bell(progress, 0.00, 0.38)
	var pull_weight: float = _smooth_bell(progress, 0.16, 0.88)
	var settle_weight: float = _smooth_tail(progress, 0.62, 1.00)
	return (
		(climb_edge_over_preload_position * preload_weight)
		+ (climb_edge_over_pull_position * pull_weight)
		+ (climb_edge_over_settle_position * settle_weight)
	) * strength_scale * feedback_keep


func get_climb_edge_over_camera_rotation(timer: float, duration: float, strength: float) -> Vector3:
	var progress: float = _get_timed_progress(timer, duration)
	var strength_scale: float = _get_edge_over_strength_scale(strength)
	var feedback_keep: float = _get_edge_over_feedback_keep(timer, duration)
	var preload_weight: float = _smooth_bell(progress, 0.00, 0.38)
	var pull_weight: float = _smooth_bell(progress, 0.16, 0.88)
	var settle_weight: float = _smooth_tail(progress, 0.62, 1.00)
	return (
		(_degrees_to_radians(climb_edge_over_preload_rotation_degrees) * preload_weight)
		+ (_degrees_to_radians(climb_edge_over_pull_rotation_degrees) * pull_weight)
		+ (_degrees_to_radians(climb_edge_over_settle_rotation_degrees) * settle_weight)
	) * strength_scale * feedback_keep


func get_climb_edge_over_fov_bonus(timer: float, duration: float, strength: float) -> float:
	var progress: float = _get_timed_progress(timer, duration)
	var pull: float = _smooth_bell(progress, 0.12, 0.92)
	var settle: float = _smooth_tail(progress, 0.72, 1.00) * 0.28
	return maxf(climb_edge_over_fov_bonus, 0.0) * (pull + settle) * _get_edge_over_strength_scale(strength) * _get_edge_over_feedback_keep(timer, duration)


func get_turn_effect_keep(climb_blend: float) -> float:
	return 1.0 - (clampf(climb_blend, 0.0, 1.0) * clampf(climb_turn_effect_override, 0.0, 1.0))


func get_edge_hold_camera_position(edge_hold_blend: float) -> Vector3:
	var blend: float = _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))
	return edge_hold_camera_position * blend


func get_edge_hold_camera_rotation(edge_hold_blend: float) -> Vector3:
	var blend: float = _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))
	return _degrees_to_radians(edge_hold_camera_rotation_degrees) * blend


func get_edge_hold_fov_bonus(edge_hold_blend: float) -> float:
	return maxf(edge_hold_fov_bonus, 0.0) * clampf(edge_hold_blend, 0.0, 1.0)


func get_camera_position(climb_blend: float, climb_progress: float) -> Vector3:
	var blend: float = clampf(climb_blend, 0.0, 1.0)
	var progress: float = clampf(climb_progress, 0.0, 1.0)
	var pull_curve: float = _ease_out(progress)
	var catch_dip: float = sin(progress * PI) * climb_camera_early_dip
	var late_drop: float = progress * maxf(climb_camera_late_drop, 0.0)
	return Vector3(
		0.0,
		(climb_camera_up_offset * pull_curve) - catch_dip - late_drop,
		climb_camera_forward_offset * (0.35 + (pull_curve * 0.65))
	) * blend


func get_camera_rotation(climb_blend: float, climb_progress: float) -> Vector3:
	var blend: float = clampf(climb_blend, 0.0, 1.0)
	var progress: float = clampf(climb_progress, 0.0, 1.0)
	var pull_curve: float = _ease_out(progress)
	var hand_sway: float = sin(_get_hand_phase(progress))
	return Vector3(
		deg_to_rad(climb_camera_pitch_degrees) * pull_curve,
		deg_to_rad(climb_camera_yaw_degrees) * hand_sway,
		deg_to_rad(climb_camera_roll_degrees) * hand_sway
	) * blend


func get_fov_bonus(climb_blend: float, climb_progress: float) -> float:
	var progress: float = clampf(climb_progress, 0.0, 1.0)
	var pulse: float = sin(progress * PI) * 0.48
	return maxf(climb_fov_bonus, 0.0) * clampf(climb_blend, 0.0, 1.0) * (0.74 + pulse)


func get_start_camera_position_impulse(strength: float) -> Vector3:
	return climb_start_camera_position * maxf(strength, 0.0)


func get_start_camera_rotation_impulse(strength: float) -> Vector3:
	return _degrees_to_radians(climb_start_camera_rotation_degrees) * maxf(strength, 0.0)


func get_start_lift_velocity(strength: float) -> float:
	return maxf(climb_start_lift_velocity, 0.0) * maxf(strength, 0.0)


func get_hand_root_position(climb_blend: float, climb_progress: float) -> Vector3:
	var progress: float = _ease_out(clampf(climb_progress, 0.0, 1.0))
	return climb_hand_root_position * clampf(climb_blend, 0.0, 1.0) * progress


func get_hand_root_rotation(climb_blend: float, climb_progress: float) -> Vector3:
	var progress: float = _ease_out(clampf(climb_progress, 0.0, 1.0))
	return _degrees_to_radians(climb_hand_root_rotation_degrees) * clampf(climb_blend, 0.0, 1.0) * progress


func get_climb_edge_over_hand_root_position(edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	var blend: float = clampf(edge_blend, 0.0, 1.0)
	var pull: float = _smooth_tail(edge_progress, 0.12, 0.70)
	var settle: float = _smooth_tail(edge_progress, 0.62, 1.00)
	return climb_edge_over_hand_root_position * blend * _get_edge_over_strength_scale(strength) * maxf(pull, settle)


func get_climb_edge_over_hand_root_rotation(edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	var blend: float = clampf(edge_blend, 0.0, 1.0)
	var pull: float = _smooth_tail(edge_progress, 0.10, 0.74)
	var settle: float = _smooth_tail(edge_progress, 0.62, 1.00)
	return _degrees_to_radians(climb_edge_over_hand_root_rotation_degrees) * blend * _get_edge_over_strength_scale(strength) * maxf(pull, settle)


func get_edge_hold_hand_root_position(edge_hold_blend: float) -> Vector3:
	var blend: float = _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))
	return edge_hold_hand_root_position * blend


func get_edge_hold_hand_root_rotation(edge_hold_blend: float) -> Vector3:
	var blend: float = _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))
	return _degrees_to_radians(edge_hold_hand_root_rotation_degrees) * blend


func get_left_hand_position(climb_blend: float, climb_progress: float) -> Vector3:
	var hand_pull: float = _get_hand_pull(climb_blend, climb_progress)
	var step_amount: float = _get_hand_step(climb_progress, 0.0)
	return _get_hand_position(climb_left_hand_position_offset, step_amount) * hand_pull


func get_right_hand_position(climb_blend: float, climb_progress: float) -> Vector3:
	var hand_pull: float = _get_hand_pull(climb_blend, climb_progress)
	var step_amount: float = _get_hand_step(climb_progress, PI)
	return _get_hand_position(climb_right_hand_position_offset, step_amount) * hand_pull


func get_left_hand_rotation(climb_blend: float, climb_progress: float) -> Vector3:
	var hand_pull: float = _get_hand_pull(climb_blend, climb_progress)
	var step_amount: float = _get_hand_step(climb_progress, 0.0)
	var rotation_degrees: Vector3 = climb_left_hand_rotation_degrees
	rotation_degrees.x += -absf(step_amount) * 3.0
	rotation_degrees.z += -step_amount * 4.0
	return _degrees_to_radians(rotation_degrees) * hand_pull


func get_right_hand_rotation(climb_blend: float, climb_progress: float) -> Vector3:
	var hand_pull: float = _get_hand_pull(climb_blend, climb_progress)
	var step_amount: float = _get_hand_step(climb_progress, PI)
	var rotation_degrees: Vector3 = climb_right_hand_rotation_degrees
	rotation_degrees.x += -absf(step_amount) * 3.0
	rotation_degrees.z += step_amount * 4.0
	return _degrees_to_radians(rotation_degrees) * hand_pull


func get_climb_edge_over_left_hand_position(edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	return _get_edge_over_hand_offset(climb_edge_over_left_hand_position_offset, edge_blend, edge_progress, strength)


func get_climb_edge_over_right_hand_position(edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	return _get_edge_over_hand_offset(climb_edge_over_right_hand_position_offset, edge_blend, edge_progress, strength)


func get_climb_edge_over_left_hand_rotation(edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	return _degrees_to_radians(climb_edge_over_left_hand_rotation_degrees) * _get_edge_over_hand_weight(edge_blend, edge_progress, strength)


func get_climb_edge_over_right_hand_rotation(edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	return _degrees_to_radians(climb_edge_over_right_hand_rotation_degrees) * _get_edge_over_hand_weight(edge_blend, edge_progress, strength)


func get_edge_hold_left_hand_position(edge_hold_blend: float, side_input: float) -> Vector3:
	var hand_position: Vector3 = edge_hold_left_hand_position_offset
	var clean_side_input: float = clampf(side_input, -1.0, 1.0)
	hand_position.x += clean_side_input * maxf(edge_hold_shimmy_side_offset, 0.0)
	hand_position.y += maxf(-clean_side_input, 0.0) * maxf(edge_hold_shimmy_vertical_offset, 0.0)
	return hand_position * _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))


func get_edge_hold_right_hand_position(edge_hold_blend: float, side_input: float) -> Vector3:
	var hand_position: Vector3 = edge_hold_right_hand_position_offset
	var clean_side_input: float = clampf(side_input, -1.0, 1.0)
	hand_position.x += clean_side_input * maxf(edge_hold_shimmy_side_offset, 0.0)
	hand_position.y += maxf(clean_side_input, 0.0) * maxf(edge_hold_shimmy_vertical_offset, 0.0)
	return hand_position * _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))


func get_edge_hold_left_hand_rotation(edge_hold_blend: float, side_input: float) -> Vector3:
	var rotation_degrees: Vector3 = edge_hold_left_hand_rotation_degrees
	rotation_degrees.z += clampf(side_input, -1.0, 1.0) * -4.0
	return _degrees_to_radians(rotation_degrees) * _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))


func get_edge_hold_right_hand_rotation(edge_hold_blend: float, side_input: float) -> Vector3:
	var rotation_degrees: Vector3 = edge_hold_right_hand_rotation_degrees
	rotation_degrees.z += clampf(side_input, -1.0, 1.0) * -4.0
	return _degrees_to_radians(rotation_degrees) * _smooth_step(clampf(edge_hold_blend, 0.0, 1.0))


func get_hand_catch_position(strength: float) -> Vector3:
	return climb_hand_catch_kick_position * maxf(strength, 0.0)


func get_hand_catch_rotation(strength: float) -> Vector3:
	return _degrees_to_radians(climb_hand_catch_kick_rotation_degrees) * maxf(strength, 0.0)


func _get_hand_position(base_position: Vector3, step_amount: float) -> Vector3:
	var hand_position: Vector3 = base_position
	hand_position.y += step_amount * climb_hand_alternate_height
	if step_amount > 0.0:
		hand_position.z += step_amount * climb_hand_reach_amount
	else:
		hand_position.z += step_amount * climb_hand_pullback_amount
	return hand_position


func _get_hand_pull(climb_blend: float, climb_progress: float) -> float:
	var progress: float = clampf(climb_progress, 0.0, 1.0)
	var catch_hold: float = clampf(sin(progress * PI) * 0.18 + _ease_out(minf(progress * 1.8, 1.0)), 0.0, 1.0)
	return clampf(climb_blend, 0.0, 1.0) * catch_hold


func _get_hand_step(climb_progress: float, phase_offset: float) -> float:
	var progress: float = clampf(climb_progress, 0.0, 1.0)
	return sin(_get_hand_phase(progress) + phase_offset)


func _get_hand_phase(climb_progress: float) -> float:
	return climb_progress * maxf(climb_hand_cycles, 0.0) * PI * 2.0


func _ease_out(value: float) -> float:
	var clean_value: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clean_value, 2.0)


func _get_edge_over_strength_scale(strength: float) -> float:
	return clampf(maxf(strength, 0.0), 0.0, maxf(climb_edge_over_max_strength, 0.0))


func _get_edge_over_feedback_keep(timer: float, duration: float) -> float:
	if timer <= duration:
		return 1.0

	var finish_progress: float = clampf(
		(timer - duration) / maxf(climb_edge_over_finish_feedback_duration, 0.001),
		0.0,
		1.0
	)
	var smooth_finish: float = finish_progress * finish_progress * (3.0 - (2.0 * finish_progress))
	return 1.0 - smooth_finish


func _get_edge_over_hand_offset(base_offset: Vector3, edge_blend: float, edge_progress: float, strength: float) -> Vector3:
	return base_offset * _get_edge_over_hand_weight(edge_blend, edge_progress, strength)


func _get_edge_over_hand_weight(edge_blend: float, edge_progress: float, strength: float) -> float:
	var blend: float = clampf(edge_blend, 0.0, 1.0)
	var pull: float = _smooth_tail(edge_progress, 0.08, 0.62)
	var settle: float = _smooth_tail(edge_progress, 0.58, 1.00)
	return blend * _get_edge_over_strength_scale(strength) * maxf(pull, settle)


func _get_timed_progress(timer: float, duration: float) -> float:
	return clampf(timer / maxf(duration, 0.001), 0.0, 1.0)


func _smooth_step(value: float) -> float:
	var clean_value: float = clampf(value, 0.0, 1.0)
	return clean_value * clean_value * (3.0 - (2.0 * clean_value))


func _smooth_bell(value: float, start: float, end: float) -> float:
	if value <= start or value >= end:
		return 0.0

	var window_progress: float = clampf((value - start) / maxf(end - start, 0.001), 0.0, 1.0)
	var smooth_progress: float = window_progress * window_progress * (3.0 - (2.0 * window_progress))
	return sin(smooth_progress * PI)


func _smooth_tail(value: float, start: float, end: float) -> float:
	if value <= start:
		return 0.0

	var tail_progress: float = clampf((value - start) / maxf(end - start, 0.001), 0.0, 1.0)
	return tail_progress * tail_progress * (3.0 - (2.0 * tail_progress))


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees_value.x),
		deg_to_rad(degrees_value.y),
		deg_to_rad(degrees_value.z)
	)
