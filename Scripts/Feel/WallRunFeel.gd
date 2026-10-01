extends Node

@export_group("Camera Wall Run")
## Side camera offset while attached to a wall.
@export var wall_run_side_offset: float = 0.058
## Upward camera offset while attached to a wall.
@export var wall_run_up_offset: float = 0.022
## Forward camera offset while attached to a wall.
@export var wall_run_forward_offset: float = 0.035
## Roll applied toward the wall.
@export var wall_run_roll_degrees: float = -20.0
## Soft yaw that angles the view away from the wall.
@export var wall_run_look_away_yaw_degrees: float = 40.0
## Extra yaw removed from the away turn to keep forward flow.
@export var wall_run_forward_flow_yaw_degrees: float = 1.0
## Small pitch applied while wall running.
@export var wall_run_pitch_degrees: float = -1.5
## Maximum final yaw angle allowed from wall side, A/D, and mouse turn.
@export var wall_run_max_total_yaw_degrees: float = 52.0
## Extra FOV while wall running.
@export var wall_run_fov_bonus: float = 5.8
## Minimum camera lerp speed while wall running.
@export var wall_run_camera_lerp_speed: float = 15.5
## How strongly wall run overrides other camera turn effects.
@export var wall_run_turn_effect_override: float = 0.55
## Curve used to lock into the wall-run look-away angle.
@export var wall_run_turn_override_curve: float = 0.95
## Flips the wall-run yaw direction if a scene uses opposite wall-side signs.
@export var invert_wall_run_yaw: bool = false

@export_group("Wall Run To Climb Transition")
## Portion of wall-run camera feel kept when converting into a wall climb.
@export var wall_run_to_climb_keep_blend: float = 0.58
## Minimum wall-run camera blend kept for the handoff into climb.
@export var wall_run_to_climb_min_release_blend: float = 0.34

@export_group("Wall Strafe Camera Feel")
## How much wall side acts like a held left/right movement input.
@export var wall_run_side_strafe_strength: float = 0.78
## How much real A/D input changes the wall-run camera angle.
@export var wall_run_move_side_influence: float = 0.36
## How much mouse left/right turn changes the wall-run camera angle.
@export var wall_run_mouse_turn_influence: float = 0.44
## Extra side offset from wall-run virtual strafe.
@export var wall_run_strafe_side_offset: float = 0.024
## Small dip from strong wall-run strafe camera pressure.
@export var wall_run_strafe_dip_amount: float = 0.012
## Extra yaw from wall-run virtual strafe.
@export var wall_run_strafe_yaw_degrees: float = 5.0
## Extra pitch from wall-run virtual strafe.
@export var wall_run_strafe_pitch_degrees: float = 1.0
## Extra roll from wall-run virtual strafe.
@export var wall_run_strafe_roll_degrees: float = 6.0

@export_group("Wall Mouse Camera Feel")
## Extra wall-run pitch per pixel of vertical mouse movement.
@export var wall_run_look_pitch_degrees_per_pixel: float = 0.045
## Extra wall-run yaw per pixel of horizontal mouse movement.
@export var wall_run_look_yaw_degrees_per_pixel: float = 0.055
## Maximum extra wall-run pitch from mouse movement.
@export var wall_run_max_look_pitch_degrees: float = 4.0
## Maximum extra wall-run yaw from mouse movement.
@export var wall_run_max_look_yaw_degrees: float = 7.0

@export_group("Wall Jump")
## Scales the normal jump feedback when wall jumping.
@export var wall_jump_feedback_multiplier: float = 1.12
## Extra feedback when jumping away during a soft wall-run release.
@export var wall_release_jump_feedback_multiplier: float = 1.16
## Camera lift impulse added when wall jumping.
@export var wall_jump_camera_lift_velocity: float = 0.42
## Side impulse pushed away from the wall when wall jumping.
@export var wall_jump_camera_side_kick: float = 0.045


func get_camera_position(
	wall_side: int,
	wall_run_blend: float,
	move_input: Vector2 = Vector2.ZERO,
	turn_strafe_input: float = 0.0
) -> Vector3:
	if wall_side == 0 or wall_run_blend <= 0.0:
		return Vector3.ZERO

	var side: float = float(wall_side)
	var blend: float = clampf(wall_run_blend, 0.0, 1.0)
	var wall_strafe: float = get_wall_run_strafe(wall_side, move_input, turn_strafe_input)
	return Vector3(
		-side * wall_run_side_offset + wall_strafe * wall_run_strafe_side_offset,
		wall_run_up_offset - absf(wall_strafe) * wall_run_strafe_dip_amount,
		wall_run_forward_offset
	) * blend


func get_camera_rotation(
	wall_side: int,
	wall_run_blend: float,
	move_input: Vector2 = Vector2.ZERO,
	turn_strafe_input: float = 0.0,
	look_motion: Vector2 = Vector2.ZERO
) -> Vector3:
	if wall_side == 0 or wall_run_blend <= 0.0:
		return Vector3.ZERO

	var side: float = float(wall_side)
	var blend: float = clampf(wall_run_blend, 0.0, 1.0)
	var wall_strafe: float = get_wall_run_strafe(wall_side, move_input, turn_strafe_input)
	var rotation: Vector3 = Vector3(
		deg_to_rad(wall_run_pitch_degrees),
		get_look_away_yaw(wall_side),
		-side * deg_to_rad(wall_run_roll_degrees)
	)
	rotation += _get_wall_strafe_rotation(wall_strafe)
	rotation += _get_wall_mouse_rotation(look_motion)
	rotation.y = clampf(
		rotation.y,
		-deg_to_rad(maxf(wall_run_max_total_yaw_degrees, 0.0)),
		deg_to_rad(maxf(wall_run_max_total_yaw_degrees, 0.0))
	)
	return rotation * blend


func get_look_away_yaw(wall_side: int) -> float:
	var side: float = float(wall_side)
	if invert_wall_run_yaw:
		side = -side

	var away_yaw: float = maxf(wall_run_look_away_yaw_degrees - wall_run_forward_flow_yaw_degrees, 0.0)
	return side * deg_to_rad(away_yaw)


func get_wall_run_to_climb_release_blend(current_blend: float) -> float:
	var kept_blend: float = clampf(current_blend, 0.0, 1.0) * clampf(wall_run_to_climb_keep_blend, 0.0, 1.0)
	return maxf(kept_blend, clampf(wall_run_to_climb_min_release_blend, 0.0, 1.0))


func get_wall_run_strafe(wall_side: int, move_input: Vector2, turn_strafe_input: float) -> float:
	if wall_side == 0:
		return 0.0

	var wall_side_strafe: float = float(wall_side) * clampf(wall_run_side_strafe_strength, 0.0, 1.0)
	var move_strafe: float = move_input.x * maxf(wall_run_move_side_influence, 0.0)
	var mouse_strafe: float = turn_strafe_input * maxf(wall_run_mouse_turn_influence, 0.0)
	return clampf(wall_side_strafe + move_strafe + mouse_strafe, -1.0, 1.0)


func get_turn_effect_keep(wall_run_blend: float) -> float:
	var blend: float = pow(clampf(wall_run_blend, 0.0, 1.0), maxf(wall_run_turn_override_curve, 0.001))
	var override_amount: float = clampf(wall_run_turn_effect_override, 0.0, 1.0) * blend
	return 1.0 - override_amount


func get_wall_jump_camera_impulse(wall_side: int, strength: float) -> Vector3:
	var side: float = float(wall_side)
	var impulse_strength: float = maxf(strength, 0.0)
	return Vector3(
		-side * wall_jump_camera_side_kick,
		wall_jump_camera_lift_velocity,
		0.0
	) * impulse_strength


func _get_wall_strafe_rotation(wall_strafe: float) -> Vector3:
	return Vector3(
		absf(wall_strafe) * deg_to_rad(wall_run_strafe_pitch_degrees),
		-wall_strafe * deg_to_rad(wall_run_strafe_yaw_degrees),
		-wall_strafe * deg_to_rad(wall_run_strafe_roll_degrees)
	)


func _get_wall_mouse_rotation(look_motion: Vector2) -> Vector3:
	var pitch: float = clampf(
		-look_motion.y * deg_to_rad(wall_run_look_pitch_degrees_per_pixel),
		-deg_to_rad(maxf(wall_run_max_look_pitch_degrees, 0.0)),
		deg_to_rad(maxf(wall_run_max_look_pitch_degrees, 0.0))
	)
	var yaw: float = clampf(
		-look_motion.x * deg_to_rad(wall_run_look_yaw_degrees_per_pixel),
		-deg_to_rad(maxf(wall_run_max_look_yaw_degrees, 0.0)),
		deg_to_rad(maxf(wall_run_max_look_yaw_degrees, 0.0))
	)
	return Vector3(pitch, yaw, 0.0)
