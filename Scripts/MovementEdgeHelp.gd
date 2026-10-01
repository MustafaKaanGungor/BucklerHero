extends Node

@export_group("Activation")
## Enables regular airborne edge correction.
@export var enable_edge_help: bool = true
## Latest time after leaving floor where normal edge help can trigger.
@export var max_time_after_leaving_floor: float = 0.72
## Delay after normal edge help before another edge assist can trigger.
@export var cooldown_time: float = 0.22
## Minimum horizontal speed needed for normal edge help.
@export var min_horizontal_speed: float = 1.4
## Lowest vertical speed accepted by normal edge help.
@export var min_vertical_velocity: float = -7.5
## Highest vertical speed accepted by normal edge help.
@export var max_vertical_velocity: float = 4.5

@export_group("Detection")
## Highest edge lift normal edge help can solve.
@export var max_lift_height: float = 0.42
## Lowest edge lift normal edge help reacts to.
@export var min_lift_height: float = 0.02
## Minimum feel height used when edge help settles onto a lower surface.
@export var min_feedback_lift_height: float = 0.02
## Lowest probe height checked by normal edge help.
@export var min_probe_lift_height: float = 0.02
## Number of lift heights checked by normal edge help.
@export var lift_probe_count: int = 3
## Forward distance used to search over a normal edge.
@export var forward_distance: float = 0.26
## Extra forward pull after a normal edge help succeeds.
@export var pull_forward_distance: float = 0.012
## Downward distance used to find the landing floor.
@export var snap_down_distance: float = 0.55
## Safe margin used by edge test moves.
@export var safe_margin: float = 0.001
## Minimum floor normal Y accepted for normal edge landings.
@export var floor_min_normal_y: float = 0.55

@export_group("Assist")
## Forward speed kept after normal edge help succeeds.
@export var forward_velocity_keep_multiplier: float = 0.0
## Allows normal edge help to add forward speed after placing the body.
@export var allow_forward_velocity_boost: bool = false
## Maximum forward speed normal edge help can add when boost is enabled.
@export var max_forward_velocity_boost: float = 0.0
## Maximum forward speed allowed after normal edge help; negative disables this cap.
@export var max_forward_velocity_after_help: float = -1.0
## Multiplier for vertical speed kept after normal edge help.
@export var vertical_velocity_keep_multiplier: float = 0.0
## Upward velocity kept after normal edge help succeeds.
@export var vertical_velocity_after_help: float = 0.0
## Highest upward velocity allowed after normal edge help.
@export var max_vertical_velocity_after_help: float = 0.0
## Camera lift feedback multiplier for normal edge help.
@export var view_lift_feedback_multiplier: float = 0.62
## Maximum visual lift used by normal edge help.
@export var max_visual_lift_height: float = 0.22

@export_group("Climb Edge Assist")
## Enables a stronger edge helper while the player is climbing a wall.
@export var enable_climb_edge_help: bool = true
## Earliest climb time before climb edge help can pull the player over.
@export var climb_edge_min_climb_time: float = 0.00
## Highest edge lift climb help can solve.
@export var climb_edge_max_lift_height: float = 1.10
## Lowest edge lift needed before climb help reacts.
@export var climb_edge_min_lift_height: float = -0.28
## Minimum feel height used when climb edge help settles onto a lower surface.
@export var climb_edge_min_feedback_lift_height: float = 0.18
## Lowest probe height checked while climbing.
@export var climb_edge_min_probe_lift_height: float = 0.02
## Number of lift heights checked while climbing.
@export var climb_edge_lift_probe_count: int = 6
## Forward distance used to search over the wall top while climbing.
@export var climb_edge_forward_distance: float = 0.72
## Extra forward pull after climb edge help succeeds.
@export var climb_edge_pull_forward_distance: float = 0.12
## Downward distance used to find the landing floor after climbing.
@export var climb_edge_snap_down_distance: float = 1.30
## Minimum floor normal Y accepted for climb edge landings.
@export var climb_edge_floor_min_normal_y: float = 0.55
## Forward speed kept after climb edge help succeeds.
@export var climb_edge_forward_velocity_keep_multiplier: float = 0.1
## Allows climb edge help to add forward speed after placing the body.
@export var climb_edge_allow_forward_velocity_boost: bool = false
## Maximum forward speed climb edge help can add when boost is enabled.
@export var climb_edge_max_forward_velocity_boost: float = 0.1
## Maximum forward speed allowed after climb edge help.
@export var climb_edge_max_forward_velocity_after_help: float = 0.45
## Multiplier for vertical climb speed kept after climb edge help.
@export var climb_edge_vertical_velocity_keep_multiplier: float = 0.08
## Upward velocity kept after climb edge help succeeds.
@export var climb_edge_vertical_velocity_after_help: float = 0.0
## Highest upward velocity allowed after climb edge help.
@export var climb_edge_max_vertical_velocity_after_help: float = 0.12
## Extra camera lift feedback when climb edge help succeeds.
@export var climb_edge_view_lift_feedback_multiplier: float = 0.72
## Maximum visual lift used by climb edge help.
@export var climb_edge_max_visual_lift_height: float = 0.32
## Strength multiplier for the step/edge feedback from climb help.
@export var climb_edge_step_feedback_multiplier: float = 0.58
## Makes climb edge feedback last longer than normal edge help.
@export var climb_edge_feedback_time_multiplier: float = 1.95
## Cooldown after climb edge help succeeds.
@export var climb_edge_cooldown_time: float = 0.28

@export_group("Smooth Pull Over")
## Uses a smooth hold-and-pull-over state for climb edge help instead of instant placement.
@export var climb_edge_use_smooth_pull_over: bool = true
## Keeps normal airborne edge help instant instead of using the smooth pull-over state.
@export var normal_edge_help_stays_instant: bool = true


func get_edge_exit_vertical_velocity(current_vertical_velocity: float) -> float:
	return _get_soft_exit_vertical_velocity(
		current_vertical_velocity,
		vertical_velocity_keep_multiplier,
		vertical_velocity_after_help,
		max_vertical_velocity_after_help
	)


func get_climb_edge_exit_vertical_velocity(current_vertical_velocity: float) -> float:
	return _get_soft_exit_vertical_velocity(
		current_vertical_velocity,
		climb_edge_vertical_velocity_keep_multiplier,
		climb_edge_vertical_velocity_after_help,
		climb_edge_max_vertical_velocity_after_help
	)


func _get_soft_exit_vertical_velocity(
	current_vertical_velocity: float,
	keep_multiplier: float,
	min_exit_velocity: float,
	max_exit_velocity: float
) -> float:
	var min_velocity: float = minf(min_exit_velocity, max_exit_velocity)
	var max_velocity: float = maxf(min_exit_velocity, max_exit_velocity)
	var kept_velocity: float = current_vertical_velocity * clampf(keep_multiplier, 0.0, 1.0)
	return clampf(kept_velocity, min_velocity, max_velocity)
