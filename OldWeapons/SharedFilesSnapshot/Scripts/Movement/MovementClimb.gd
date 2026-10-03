extends Node

@export_group("Activation")
## Enables upward wall climb assistance while airborne.
@export var enable_climb: bool = true
## Requires Space to stay held while checking for a wall climb.
@export var require_jump_pressed: bool = true
## Allows wall run to convert into an upward climb on front wall contact.
@export var allow_from_wall_run: bool = true
## Requires Space for wall-run to climb conversion; off means looking/holding forward can convert.
@export var wall_run_transition_requires_jump: bool = false
## Earliest time after leaving the floor that wall climb can start.
@export var min_time_after_leaving_floor: float = 0.04
## Latest time after leaving the floor that wall climb can start.
@export var max_time_after_leaving_floor: float = 2.20
## Delay after releasing a wall climb before another climb can start.
@export var cooldown_time: float = 0.24
## Minimum horizontal speed needed before a wall climb can start.
@export var min_horizontal_speed: float = 1.15
## Lowest vertical velocity allowed when catching the wall.
@export var min_vertical_velocity: float = -12.0
## Highest vertical velocity allowed when catching the wall.
@export var max_vertical_velocity: float = 8.6
## Required ray alignment into the wall.
@export var min_wall_approach_alignment: float = 0.28
## Required movement alignment with player forward before climb checks start.
@export var min_forward_input_alignment: float = 0.54
## Required wall alignment with player forward so side walls do not become climbs.
@export var min_front_wall_alignment: float = 0.72
## Small input steering added to the forward climb probe.
@export var climb_input_direction_blend: float = 0.16

@export_group("Detection")
## Forward distance used to find the wall face.
@export var wall_check_distance: float = 0.72
## Lower wall probe height from the player origin.
@export var wall_check_height: float = 1.02
## Upper wall probe height used to keep climbing on uneven walls.
@export var wall_upper_check_height: float = 1.48
## Distance used while already climbing to keep wall contact alive.
@export var wall_release_distance: float = 0.95
## Highest wall normal Y value accepted as a climbable wall.
@export var wall_max_normal_y: float = 0.34
## Lowest wall normal Y value accepted as a climbable wall.
@export var wall_min_normal_y: float = -0.25

@export_group("Climb Edge Classification")
## Requires ledge tops to be at or above the climb-start head height to count as climb edges.
@export var climb_edge_requires_start_head_height: bool = true
## Small tolerance around the head-height threshold so exact head-level edges are accepted.
@export var climb_edge_head_height_tolerance: float = 0.035

@export_group("Motion")
## Maximum time the player can keep climbing upward before dropping.
@export var wall_climb_duration: float = 3.50
## Upward speed at the start of the climb.
@export var wall_climb_start_up_speed: float = 4.95
## Upward speed near the end; negative values make the player begin to drop.
@export var wall_climb_end_up_speed: float = -1.10
## Extra upward start speed gained from fast entries.
@export var wall_climb_entry_up_bonus: float = 0.65
## Maximum upward speed allowed during wall climb.
@export var wall_climb_max_up_speed: float = 4.75
## Exponential high-to-low strength for the upward climb speed.
@export var wall_climb_ease_out_strength: float = 3.25
## Small speed pressing into the wall so the body stays attached.
@export var wall_stick_speed: float = 1.18
## Side control speed while climbing the wall.
@export var wall_side_control_speed: float = 1.25
## How quickly horizontal climb velocity follows the wall target.
@export var wall_horizontal_lerp_speed: float = 14.0
## Away-from-wall speed used when the climb times out.
@export var wall_climb_release_forward_speed: float = 0.70
## Downward velocity applied when the climb times out.
@export var wall_climb_release_drop_velocity: float = -2.20
## Forward speed kept when wall contact is lost near a possible edge.
@export var wall_climb_edge_forward_speed: float = 1.65
## Vertical velocity kept when releasing near a possible edge.
@export var wall_climb_edge_release_up_velocity: float = -0.20

@export_group("Entry Speed Climb Range")
## Enables movement speed at climb entry to increase climb range and power.
@export var enable_entry_speed_climb_range_scaling: bool = true
## Entry speed where extra climb range starts.
@export var climb_entry_speed_min_speed: float = 3.6
## Entry speed that reaches full climb range bonus.
@export var climb_entry_speed_full_speed: float = 18.0
## Curve for how entry speed turns into climb range.
@export var climb_entry_speed_range_curve: float = 0.90
## Extra climb duration at full entry-speed range.
@export var climb_entry_speed_duration_bonus: float = 0.82
## Extra starting upward climb speed at full entry-speed range.
@export var climb_entry_speed_up_bonus: float = 1.35
## Extra maximum upward speed allowed at full entry-speed range.
@export var climb_entry_speed_max_up_bonus: float = 1.45
## Extra forward release speed when a fast climb times out.
@export var climb_entry_speed_release_forward_bonus: float = 0.55
## Extra edge-release forward speed when a fast climb reaches the top.
@export var climb_entry_speed_edge_release_forward_bonus: float = 0.85

@export_group("Wall Run Transition Motion")
## Extra wall-climb duration after converting out of a wall run.
@export var wall_run_transition_duration_bonus: float = 0.30
## Extra upward speed on the first climb frames after wall running.
@export var wall_run_transition_up_speed_bonus: float = 0.42
## Portion of wall-run sideways velocity kept when hands catch the front wall.
@export var wall_run_transition_wall_speed_keep: float = 0.24
## Speed pressing into the wall during the first conversion frame.
@export var wall_run_transition_into_wall_speed: float = 1.35
## Maximum horizontal speed kept during wall-run to climb conversion.
@export var wall_run_transition_max_horizontal_speed: float = 3.35

@export_group("Edge Pull Over")
## Automatically pulls over valid climb edges instead of waiting in manual edge hold.
@export var auto_pull_over_climb_edges: bool = true
## Enables a smooth ledge pull-over instead of instant edge placement.
@export var enable_edge_pull_over: bool = true
## Base time used to pull the body over a found edge.
@export var edge_pull_over_duration: float = 0.54
## Shortest allowed edge pull-over time.
@export var edge_pull_over_min_duration: float = 0.38
## Longest allowed edge pull-over time.
@export var edge_pull_over_max_duration: float = 0.78
## Extra time added for taller edge catches.
@export var edge_pull_over_lift_duration_bonus: float = 0.12
## Time removed when entering the edge with speed.
@export var edge_pull_over_speed_duration_reduction: float = 0.08
## Height used as full strength for edge pull-over timing.
@export var edge_pull_over_reference_height: float = 1.10
## First part of the pull where the player hangs on the lip.
@export var edge_pull_over_hold_ratio: float = 0.20
## Tiny lift while hanging on the edge before the pull starts.
@export var edge_pull_over_hold_lift: float = 0.040
## Extra clearance above the ledge during the pull-over arc.
@export var edge_pull_over_vertical_clearance: float = 0.105
## Forward speed kept after standing on top of the edge.
@export var edge_pull_over_finish_forward_speed: float = 1.20
## Extra finish speed from the climb entry speed.
@export var edge_pull_over_finish_entry_speed_multiplier: float = 0.05
## Small downward velocity used after finishing so the body settles onto the floor.
@export var edge_pull_over_finish_down_velocity: float = -0.35

@export_group("Edge Hold")
## Enables manual ledge hanging and shimmying instead of automatic pull-over.
@export var enable_edge_hold: bool = false
## Minimum hang time before held forward input can pull over the edge.
@export var edge_hold_min_hold_time: float = 0.18
## Lets holding forward climb over after the short hold instead of requiring a new jump press.
@export var edge_hold_auto_pull_with_forward: bool = true
## Requires W to be released and pressed again after grabbing the edge.
@export var edge_hold_requires_fresh_forward_press: bool = true
## Forward input needed to climb over while edge holding.
@export var edge_hold_pull_forward_threshold: float = 0.62
## Back input needed to drop from an edge hold.
@export var edge_hold_drop_backward_threshold: float = 0.68
## Side input ignored while shimmying along an edge.
@export var edge_hold_side_input_deadzone: float = 0.12
## Side movement speed along the held edge.
@export var edge_hold_side_speed: float = 1.55
## Largest side check in one physics frame while shimmying.
@export var edge_hold_max_side_step: float = 0.12
## How quickly the body follows the held edge position.
@export var edge_hold_position_lerp_speed: float = 18.0
## Delay before dropping if the edge briefly disappears during side movement.
@export var edge_hold_lost_grace_time: float = 0.16
## Cooldown after edge hold ends so the player does not instantly re-grab the same lip.
@export var edge_hold_cooldown_time: float = 0.32
## Height used by the top-down ray that finds the top surface of the ledge.
@export var edge_hold_top_probe_height: float = 1.58
## Forward offset used by the top-down ray that finds the ledge surface.
@export var edge_hold_top_forward_distance: float = 0.72
## Downward distance used by the top-down ledge ray.
@export var edge_hold_top_down_distance: float = 1.72
## Distance below the found top where the forward wall ray checks the lip.
@export var edge_hold_wall_probe_below_top: float = 0.16
## Forward distance used by the wall ray below the lip.
@export var edge_hold_wall_probe_distance: float = 0.92
## Extra height above the top used to reject blocked ledges.
@export var edge_hold_upper_clearance: float = 0.24
## Extra distance away from the wall while hanging on the edge.
@export var edge_hold_wall_clearance: float = 0.055
## Target body origin distance below the top while holding the edge.
@export var edge_hold_body_below_top: float = 1.42
## Maximum vertical correction applied when snapping into edge hold.
@export var edge_hold_max_vertical_adjust: float = 1.05
## Camera/hand climb progress used while hanging from the edge.
@export var edge_hold_climb_progress: float = 0.84
## Initial climb blend when edge hold starts.
@export var edge_hold_enter_blend: float = 0.72
## Blend speed used by camera and hands for edge hold.
@export var edge_hold_blend_lerp_speed: float = 16.0
## Away-from-wall speed when dropping from the edge hold.
@export var edge_hold_release_away_speed: float = 0.72
## Down velocity when dropping from the edge hold.
@export var edge_hold_release_down_velocity: float = -2.35

@export_group("Wall Climb Jump")
## Allows pressing Space again during a climb to jump away from the wall.
@export var enable_wall_climb_jump: bool = true
## Time after catch before a climb jump is accepted.
@export var wall_climb_jump_lockout_time: float = 0.18
## Upward velocity for jumping away from a wall climb.
@export var wall_climb_jump_up_velocity: float = 5.65
## Horizontal speed pushed away from the climbed wall.
@export var wall_climb_jump_away_speed: float = 5.40
## Extra input-directed speed added to wall climb jumps.
@export var wall_climb_jump_input_speed: float = 2.85
## Extra wall jump speed gained from fast climb entries.
@export var wall_climb_jump_entry_speed_multiplier: float = 0.18
## Maximum horizontal speed after a wall climb jump.
@export var wall_climb_jump_max_horizontal_speed: float = 8.90

@export_group("Blend")
## Blend speed used by camera and hands for climb state.
@export var climb_blend_lerp_speed: float = 13.5
## Initial blend amount when climb starts.
@export var climb_enter_blend: float = 0.58



@export_group("Talons")
## Upward climb speed multiplier while the talons are in hand.
@export var talon_climb_speed_multiplier: float = 1.3
## With the talons in hand any wall in front can be grabbed mid-air, jump held or not.
@export var talon_grab_any_wall: bool = true
## ... unless falling faster than this (m/s).
@export var talon_max_fall_speed: float = 14.0

var _talon_bonus_active: bool = false
func can_try_climb(
	on_floor: bool,
	is_sliding: bool,
	is_crouching: bool,
	is_wall_running: bool,
	wish_direction: Vector3,
	horizontal_speed: float,
	vertical_velocity: float,
	time_since_floor: float,
	jump_pressed: bool,
	cooldown_timer: float
) -> bool:
	if not enable_climb:
		return false
	if on_floor or is_sliding or is_crouching:
		return false
	if is_wall_running and not allow_from_wall_run:
		return false

	var needs_jump: bool = require_jump_pressed
	if is_wall_running:
		needs_jump = wall_run_transition_requires_jump
	# Talons grab any wall mid-air: no jump needed, no timing or falling-speed window.
	if _talon_bonus_active and talon_grab_any_wall:
		if is_wall_running and needs_jump and not jump_pressed:
			return false
		return cooldown_timer <= 0.0 and wish_direction != Vector3.ZERO and vertical_velocity >= -absf(talon_max_fall_speed)
	if needs_jump and not jump_pressed:
		return false
	if cooldown_timer > 0.0:
		return false
	if wish_direction == Vector3.ZERO:
		return false
	if horizontal_speed < min_horizontal_speed:
		return false
	if time_since_floor < min_time_after_leaving_floor:
		return false
	if not is_wall_running and time_since_floor > max_time_after_leaving_floor:
		return false
	return vertical_velocity >= min_vertical_velocity and vertical_velocity <= max_vertical_velocity


func is_valid_wall_normal(wall_normal: Vector3) -> bool:
	if wall_normal.length_squared() <= 0.001:
		return false
	return wall_normal.y >= wall_min_normal_y and wall_normal.y <= wall_max_normal_y


func is_climb_edge_top_high_enough(edge_top_y: float, climb_start_head_y: float) -> bool:
	if not climb_edge_requires_start_head_height:
		return true
	return edge_top_y >= climb_start_head_y - maxf(climb_edge_head_height_tolerance, 0.0)


func is_aligned_with_wall(probe_direction: Vector3, wall_normal: Vector3) -> bool:
	var climb_direction: Vector3 = get_climb_direction_from_wall(wall_normal)
	if climb_direction == Vector3.ZERO or probe_direction == Vector3.ZERO:
		return false
	return probe_direction.normalized().dot(climb_direction) >= clampf(min_wall_approach_alignment, -1.0, 1.0)


func is_valid_front_climb_hit(probe_direction: Vector3, player_forward_direction: Vector3, wall_normal: Vector3) -> bool:
	if not is_valid_wall_normal(wall_normal):
		return false
	if not is_aligned_with_wall(probe_direction, wall_normal):
		return false
	return is_wall_in_front_for_climb(player_forward_direction, wall_normal)


func is_wall_in_front_for_climb(player_forward_direction: Vector3, wall_normal: Vector3) -> bool:
	var clean_forward: Vector3 = get_horizontal_direction(player_forward_direction)
	var climb_direction: Vector3 = get_climb_direction_from_wall(wall_normal)
	if clean_forward == Vector3.ZERO or climb_direction == Vector3.ZERO:
		return false
	return clean_forward.dot(climb_direction) >= clampf(min_front_wall_alignment, -1.0, 1.0)


func get_front_climb_probe_direction(player_forward_direction: Vector3, wish_direction: Vector3) -> Vector3:
	var clean_forward: Vector3 = get_horizontal_direction(player_forward_direction)
	if clean_forward == Vector3.ZERO:
		return Vector3.ZERO
	if wish_direction == Vector3.ZERO:
		return clean_forward

	var clean_wish: Vector3 = get_horizontal_direction(wish_direction)
	if clean_wish == Vector3.ZERO:
		return clean_forward
	if clean_wish.dot(clean_forward) < clampf(min_forward_input_alignment, -1.0, 1.0):
		return Vector3.ZERO

	var input_blend: float = clampf(climb_input_direction_blend, 0.0, 1.0)
	return clean_forward.lerp(clean_wish, input_blend).normalized()


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


func get_climb_direction_from_wall(wall_normal: Vector3) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if horizontal_normal == Vector3.ZERO:
		return Vector3.ZERO
	return -horizontal_normal


func get_wall_climb_duration(entry_horizontal_speed: float, from_wall_run: bool = false) -> float:
	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var duration_bonus: float = speed_ratio * 0.18
	duration_bonus += _get_entry_speed_climb_range_ratio(entry_horizontal_speed) * maxf(climb_entry_speed_duration_bonus, 0.0)
	if from_wall_run:
		duration_bonus += maxf(wall_run_transition_duration_bonus, 0.0)
	return maxf(wall_climb_duration + duration_bonus, 0.001)


func get_climb_progress(climb_timer: float, duration: float) -> float:
	var time_ratio: float = clampf(climb_timer / maxf(duration, 0.001), 0.0, 1.0)
	var strength: float = maxf(wall_climb_ease_out_strength, 0.001)
	var raw_progress: float = 1.0 - pow(2.0, -strength * time_ratio)
	var raw_end: float = 1.0 - pow(2.0, -strength)
	return clampf(raw_progress / maxf(raw_end, 0.001), 0.0, 1.0)


func get_wall_climb_vertical_velocity(
	climb_timer: float,
	duration: float,
	entry_horizontal_speed: float,
	from_wall_run: bool = false
) -> float:
	var progress: float = get_climb_progress(climb_timer, duration)
	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var entry_range_ratio: float = _get_entry_speed_climb_range_ratio(entry_horizontal_speed)
	var start_speed: float = wall_climb_start_up_speed + (speed_ratio * maxf(wall_climb_entry_up_bonus, 0.0))
	start_speed += entry_range_ratio * maxf(climb_entry_speed_up_bonus, 0.0)
	if from_wall_run:
		start_speed += maxf(wall_run_transition_up_speed_bonus, 0.0)
	var max_up_speed: float = maxf(wall_climb_max_up_speed, 0.001)
	max_up_speed += entry_range_ratio * maxf(climb_entry_speed_max_up_bonus, 0.0)
	start_speed = minf(start_speed, max_up_speed)
	var vertical: float = lerpf(start_speed, wall_climb_end_up_speed, progress)
	# Talons climb faster (only the upward part is scaled).
	if _talon_bonus_active and vertical > 0.0:
		vertical *= maxf(talon_climb_speed_multiplier, 0.0)
	return vertical


## Talons in hand (pushed by the player every tick): faster climbs, and any wall can be grabbed.
func set_talon_bonus(active: bool) -> void:
	_talon_bonus_active = active


func get_wall_climb_velocity(
	current_horizontal_velocity: Vector3,
	wall_normal: Vector3,
	probe_direction: Vector3,
	climb_timer: float,
	duration: float,
	entry_horizontal_speed: float,
	delta: float,
	from_wall_run: bool = false
) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if horizontal_normal == Vector3.ZERO:
		return Vector3.ZERO

	var into_wall_direction: Vector3 = -horizontal_normal
	var side_direction: Vector3 = horizontal_normal.cross(Vector3.UP)
	if side_direction.length_squared() <= 0.001:
		side_direction = Vector3.ZERO
	else:
		side_direction = side_direction.normalized()

	var side_input: float = 0.0
	if probe_direction != Vector3.ZERO and side_direction != Vector3.ZERO:
		side_input = clampf(probe_direction.normalized().dot(side_direction), -1.0, 1.0)

	var target_horizontal: Vector3 = into_wall_direction * maxf(wall_stick_speed, 0.0)
	target_horizontal += side_direction * side_input * maxf(wall_side_control_speed, 0.0)
	var response: float = 1.0 - exp(-maxf(wall_horizontal_lerp_speed, 0.001) * delta)
	var horizontal_velocity: Vector3 = current_horizontal_velocity.lerp(target_horizontal, response)
	var vertical_velocity: float = get_wall_climb_vertical_velocity(climb_timer, duration, entry_horizontal_speed, from_wall_run)
	return Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)


func get_wall_run_transition_velocity(
	current_velocity: Vector3,
	wall_normal: Vector3,
	climb_direction: Vector3
) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	var clean_climb_direction: Vector3 = get_horizontal_direction(climb_direction)
	if horizontal_normal == Vector3.ZERO or clean_climb_direction == Vector3.ZERO:
		return current_velocity

	var current_horizontal: Vector3 = Vector3(current_velocity.x, 0.0, current_velocity.z)
	var wall_slide_velocity: Vector3 = current_horizontal.slide(horizontal_normal)
	wall_slide_velocity.y = 0.0
	wall_slide_velocity *= clampf(wall_run_transition_wall_speed_keep, 0.0, 1.0)

	var transition_horizontal: Vector3 = wall_slide_velocity
	transition_horizontal += clean_climb_direction * maxf(wall_run_transition_into_wall_speed, 0.0)
	var max_speed: float = maxf(wall_run_transition_max_horizontal_speed, 0.001)
	if transition_horizontal.length() > max_speed:
		transition_horizontal = transition_horizontal.normalized() * max_speed

	return Vector3(transition_horizontal.x, current_velocity.y, transition_horizontal.z)


func get_wall_climb_release_velocity(wall_normal: Vector3, entry_horizontal_speed: float) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if horizontal_normal == Vector3.ZERO:
		return Vector3(0.0, wall_climb_release_drop_velocity, 0.0)

	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var forward_speed: float = maxf(wall_climb_release_forward_speed, 0.0) + (speed_ratio * 0.35)
	forward_speed += _get_entry_speed_climb_range_ratio(entry_horizontal_speed) * maxf(climb_entry_speed_release_forward_bonus, 0.0)
	return (horizontal_normal * forward_speed) + (Vector3.UP * wall_climb_release_drop_velocity)


func get_wall_climb_edge_release_velocity(climb_direction: Vector3, entry_horizontal_speed: float) -> Vector3:
	var forward_direction: Vector3 = climb_direction
	if forward_direction.length_squared() <= 0.001:
		forward_direction = Vector3.ZERO
	else:
		forward_direction = forward_direction.normalized()

	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var forward_speed: float = maxf(wall_climb_edge_forward_speed, 0.0) + (speed_ratio * 0.50)
	forward_speed += _get_entry_speed_climb_range_ratio(entry_horizontal_speed) * maxf(climb_entry_speed_edge_release_forward_bonus, 0.0)
	return (forward_direction * forward_speed) + (Vector3.UP * wall_climb_edge_release_up_velocity)


func get_edge_pull_over_duration(lift_height: float, entry_horizontal_speed: float) -> float:
	var lift_ratio: float = clampf(absf(lift_height) / maxf(edge_pull_over_reference_height, 0.001), 0.0, 1.0)
	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var duration: float = edge_pull_over_duration
	duration += lift_ratio * maxf(edge_pull_over_lift_duration_bonus, 0.0)
	duration -= speed_ratio * maxf(edge_pull_over_speed_duration_reduction, 0.0)
	return clampf(duration, maxf(edge_pull_over_min_duration, 0.001), maxf(edge_pull_over_max_duration, 0.001))


func get_edge_pull_over_progress(timer: float, duration: float) -> float:
	return clampf(timer / maxf(duration, 0.001), 0.0, 1.0)


func get_edge_pull_over_position(start_position: Vector3, target_position: Vector3, timer: float, duration: float) -> Vector3:
	var raw_progress: float = get_edge_pull_over_progress(timer, duration)
	var hold_ratio: float = clampf(edge_pull_over_hold_ratio, 0.0, 0.85)
	if hold_ratio > 0.0 and raw_progress < hold_ratio:
		var hold_progress: float = _smooth_step(raw_progress / maxf(hold_ratio, 0.001))
		return start_position + (Vector3.UP * sin(hold_progress * PI) * maxf(edge_pull_over_hold_lift, 0.0))

	var pull_progress: float = raw_progress
	if hold_ratio < 1.0:
		pull_progress = clampf((raw_progress - hold_ratio) / maxf(1.0 - hold_ratio, 0.001), 0.0, 1.0)

	var horizontal_progress: float = _smooth_step(clampf((pull_progress - 0.12) / 0.88, 0.0, 1.0))
	var up_progress: float = _smooth_step(clampf(pull_progress / 0.56, 0.0, 1.0))
	var settle_progress: float = _smooth_step(clampf((pull_progress - 0.70) / 0.30, 0.0, 1.0))
	var high_y: float = maxf(start_position.y, target_position.y) + maxf(edge_pull_over_vertical_clearance, 0.0)

	var next_position: Vector3 = start_position
	next_position.x = lerpf(start_position.x, target_position.x, horizontal_progress)
	next_position.z = lerpf(start_position.z, target_position.z, horizontal_progress)
	next_position.y = lerpf(start_position.y, high_y, up_progress)
	next_position.y = lerpf(next_position.y, target_position.y, settle_progress)
	return next_position


func get_edge_pull_over_finish_velocity(edge_direction: Vector3, entry_horizontal_speed: float) -> Vector3:
	var finish_direction: Vector3 = get_horizontal_direction(edge_direction)
	var speed_ratio: float = clampf(entry_horizontal_speed / maxf(MovementRun.get_sprint_speed_limit(), 0.001), 0.0, 1.0)
	var finish_speed: float = maxf(edge_pull_over_finish_forward_speed, 0.0)
	finish_speed += entry_horizontal_speed * maxf(edge_pull_over_finish_entry_speed_multiplier, 0.0) * speed_ratio
	return (finish_direction * finish_speed) + (Vector3.UP * edge_pull_over_finish_down_velocity)


func should_edge_hold_pull_over(
	move_input: Vector2,
	jump_requested: bool,
	forward_just_pressed: bool,
	forward_was_released: bool,
	hold_timer: float
) -> bool:
	if hold_timer < maxf(edge_hold_min_hold_time, 0.0):
		return false
	if jump_requested:
		return true
	if not edge_hold_auto_pull_with_forward:
		return false
	if edge_hold_requires_fresh_forward_press:
		return forward_was_released and forward_just_pressed
	return move_input.y <= -maxf(edge_hold_pull_forward_threshold, 0.0)


func should_edge_hold_drop(move_input: Vector2, crouch_pressed: bool) -> bool:
	if crouch_pressed:
		return true
	return move_input.y >= maxf(edge_hold_drop_backward_threshold, 0.0)


func get_edge_hold_side_input(move_input: Vector2) -> float:
	var side_input: float = clampf(move_input.x, -1.0, 1.0)
	if absf(side_input) < maxf(edge_hold_side_input_deadzone, 0.0):
		return 0.0
	return side_input


func get_edge_hold_side_distance(move_input: Vector2, delta: float) -> float:
	var side_input: float = get_edge_hold_side_input(move_input)
	var side_distance: float = side_input * maxf(edge_hold_side_speed, 0.0) * delta
	return clampf(side_distance, -maxf(edge_hold_max_side_step, 0.001), maxf(edge_hold_max_side_step, 0.001))


func get_edge_hold_side_direction(wall_normal: Vector3) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if horizontal_normal == Vector3.ZERO:
		return Vector3.ZERO

	var side_direction: Vector3 = Vector3.UP.cross(horizontal_normal)
	if side_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return side_direction.normalized()


func get_edge_hold_position(
	current_position: Vector3,
	edge_top_position: Vector3,
	wall_point: Vector3,
	wall_normal: Vector3,
	body_radius: float
) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	var hold_position: Vector3 = current_position
	if horizontal_normal != Vector3.ZERO:
		var wall_clearance: float = maxf(body_radius, 0.0) + maxf(edge_hold_wall_clearance, 0.0)
		hold_position.x = wall_point.x + horizontal_normal.x * wall_clearance
		hold_position.z = wall_point.z + horizontal_normal.z * wall_clearance

	var target_y: float = edge_top_position.y - maxf(edge_hold_body_below_top, 0.0)
	var max_adjust: float = maxf(edge_hold_max_vertical_adjust, 0.0)
	hold_position.y = clampf(target_y, current_position.y - max_adjust, current_position.y + max_adjust)
	return hold_position


func get_edge_hold_position_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(edge_hold_position_lerp_speed, 0.001) * delta)


func get_edge_hold_blend(current_blend: float, is_edge_holding: bool, delta: float) -> float:
	var target_blend: float = 0.0
	if is_edge_holding:
		target_blend = 1.0

	var blend_amount: float = 1.0 - exp(-maxf(edge_hold_blend_lerp_speed, 0.001) * delta)
	return lerpf(current_blend, target_blend, blend_amount)


func get_edge_hold_release_velocity(wall_normal: Vector3) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	var away_velocity: Vector3 = Vector3.ZERO
	if horizontal_normal != Vector3.ZERO:
		away_velocity = horizontal_normal * maxf(edge_hold_release_away_speed, 0.0)
	return away_velocity + (Vector3.UP * edge_hold_release_down_velocity)


func get_wall_climb_jump_velocity(
	current_velocity: Vector3,
	wall_normal: Vector3,
	wish_direction: Vector3,
	entry_horizontal_speed: float
) -> Vector3:
	var horizontal_normal: Vector3 = get_horizontal_wall_normal(wall_normal)
	if horizontal_normal == Vector3.ZERO:
		return current_velocity

	var speed_bonus: float = maxf(entry_horizontal_speed, 0.0) * maxf(wall_climb_jump_entry_speed_multiplier, 0.0)
	var horizontal_velocity: Vector3 = horizontal_normal * (maxf(wall_climb_jump_away_speed, 0.0) + speed_bonus)
	if wish_direction != Vector3.ZERO:
		horizontal_velocity += wish_direction.normalized() * maxf(wall_climb_jump_input_speed, 0.0)

	var horizontal_speed: float = horizontal_velocity.length()
	var max_horizontal_speed: float = maxf(wall_climb_jump_max_horizontal_speed, 0.001)
	if horizontal_speed > max_horizontal_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_speed

	return Vector3(horizontal_velocity.x, maxf(wall_climb_jump_up_velocity, 0.0), horizontal_velocity.z)


func get_climb_blend(current_blend: float, is_climbing: bool, delta: float) -> float:
	var target_blend: float = 0.0
	if is_climbing:
		target_blend = 1.0

	var blend_amount: float = 1.0 - exp(-maxf(climb_blend_lerp_speed, 0.001) * delta)
	return lerpf(current_blend, target_blend, blend_amount)


func _smooth_step(value: float) -> float:
	var clean_value: float = clampf(value, 0.0, 1.0)
	return clean_value * clean_value * (3.0 - (2.0 * clean_value))


func _get_entry_speed_climb_range_ratio(entry_horizontal_speed: float) -> float:
	if not enable_entry_speed_climb_range_scaling:
		return 0.0

	var min_speed: float = maxf(climb_entry_speed_min_speed, 0.0)
	var full_speed: float = maxf(climb_entry_speed_full_speed, min_speed + 0.001)
	var speed_ratio: float = clampf(
		(maxf(entry_horizontal_speed, 0.0) - min_speed) / maxf(full_speed - min_speed, 0.001),
		0.0,
		1.0
	)
	return pow(speed_ratio, maxf(climb_entry_speed_range_curve, 0.001))
