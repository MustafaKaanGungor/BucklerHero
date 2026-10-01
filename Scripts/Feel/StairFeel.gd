extends Node

@export_group("Stair Movement")
## Enables automatic stair stepping while grounded.
@export var enable_stair_stepping: bool = true
## Highest stair the player can climb.
@export var stair_max_height: float = 1.00
## Smallest step height that counts as a stair.
@export var stair_min_height: float = 0.005
## Forward probe distance used when testing stairs.
@export var stair_forward_distance: float = 0.08
## Downward snap distance after the raised stair probe.
@export var stair_snap_down_distance: float = 0.58
## Minimum speed required before stair stepping tries to run.
@export var stair_min_speed: float = 0.5
## Speed multiplier while walking on stairs.
@export var stair_walk_speed_multiplier: float = 0.88
## Speed multiplier while sprinting on stairs.
@export var stair_sprint_speed_multiplier: float = 0.78
## Delay before another stair feedback impulse can fire.
@export var stair_step_cooldown: float = 0.075
## Safe margin used by stair test moves.
@export var stair_safe_margin: float = 0.001
## Wall normal threshold used by stair blocking tests.
@export var stair_wall_max_normal_y: float = 0.0
## Direct blocker normal threshold for stair detection.
@export var stair_direct_blocker_max_normal_y: float = 0.9
## Minimum floor normal accepted after a stair step.
@export var stair_floor_min_normal_y: float = 0.05
## Minimum alignment required for a collision to block stairs.
@export var stair_min_blocking_dot: float = 0.35
## Horizontal speed kept after a stair step.
@export var stair_velocity_keep_multiplier: float = 0.92
## Speed used to recover visual stair view offset.
@export var stair_view_lerp_speed: float = 6.8
## Biggest camera height correction created by one stair step.
@export var stair_max_view_step_offset: float = 0.72
## How much of a new step correction is hidden immediately.
@export var stair_view_snap_hide_multiplier: float = 1.0
## Maximum instant camera drop used to hide a body step-up.
@export var stair_view_max_instant_drop: float = 0.72

@export_group("Stair State Feel")
## Time the player remains in stair-feel state after stepping.
@export var stair_state_hold_time: float = 0.34
## Speed used to blend in and out of stair-feel state.
@export var stair_state_lerp_speed: float = 5.5
## Initial stair blend applied when a step is detected.
@export var stair_enter_blend: float = 0.22
## Speed used to limit movement speed while on stairs.
@export var stair_speed_lerp_speed: float = 5.0
## Time stair step feedback remains visible to camera and hands.
@export var stair_step_feedback_time: float = 0.36
## Curve that softens camera and hand feedback from stair height.
@export var stair_step_feedback_curve: float = 2.1

@export_group("Stair Camera Feel")
## Camera dip applied by each stair step.
@export var stair_camera_step_amount: float = 0.004
## Forward camera nudge while moving on stairs.
@export var stair_camera_forward_amount: float = 0.002
## Camera rebound applied after a stair step.
@export var stair_camera_rebound_velocity: float = 0.045
## Camera roll added while moving on stairs.
@export var stair_roll_amount: float = 0.0015
## Bob reduction applied while moving on stairs.
@export var stair_bob_amount_multiplier: float = 0.82


func get_speed_multiplier(is_sprinting: bool, stair_blend: float) -> float:
	if stair_blend <= 0.0:
		return 1.0

	var stair_multiplier: float = stair_walk_speed_multiplier
	if is_sprinting:
		stair_multiplier = stair_sprint_speed_multiplier
	return lerpf(1.0, stair_multiplier, clampf(stair_blend, 0.0, 1.0))


func get_speed_limit_blend(stair_blend: float, delta: float) -> float:
	return 1.0 - exp(-maxf(stair_speed_lerp_speed, 0.001) * clampf(stair_blend, 0.0, 1.0) * delta)


func get_step_strength(step_height: float) -> float:
	var step_ratio: float = clampf(step_height / maxf(stair_max_height, 0.001), 0.0, 1.0)
	return pow(step_ratio, maxf(stair_step_feedback_curve, 0.001))


func get_state_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(stair_state_lerp_speed, 0.001) * delta)


func get_view_recovery_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(stair_view_lerp_speed, 0.001) * delta)


func get_visual_step_height(step_height: float, max_visual_height: float) -> float:
	return minf(maxf(step_height, 0.0), maxf(max_visual_height, 0.0))


func get_instant_step_hide_delta(step_view_delta: float) -> float:
	if step_view_delta >= 0.0:
		return 0.0

	var instant_multiplier: float = clampf(stair_view_snap_hide_multiplier, 0.0, 1.0)
	var max_instant_drop: float = maxf(stair_view_max_instant_drop, 0.0)
	if instant_multiplier <= 0.0 or max_instant_drop <= 0.0:
		return 0.0

	return maxf(step_view_delta, -max_instant_drop) * instant_multiplier


func get_feedback_decay_strength(timer: float, duration: float) -> float:
	var time_ratio: float = clampf(timer / maxf(duration, 0.001), 0.0, 1.0)
	return time_ratio * time_ratio * (3.0 - (2.0 * time_ratio))
