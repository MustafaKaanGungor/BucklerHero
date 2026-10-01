extends Node

@export_group("Mouse Look")
## Mouse sensitivity for yaw and pitch input.
@export var mouse_sensitivity: float = 0.00248
## Maximum vertical look angle in degrees.
@export var max_pitch_degrees: float = 89.0
## How quickly mouse motion feedback fades after turning.
@export var look_motion_decay_speed: float = 16.0

@export_group("Smoothed Look Input")
## Enables CameraController-style smoothing before yaw and pitch are applied.
@export var enable_smoothed_look_input: bool = true
## Higher values make smoothed mouse look catch raw input faster.
@export var look_input_smoothing_speed: float = 52.0
## Raw mouse input kept in the applied look so turning stays responsive.
@export var look_input_immediate_response: float = 0.74
## Higher values make camera/hand turn feedback follow mouse movement faster.
@export var look_feedback_smoothing_speed: float = 26.0
## Largest mouse delta accepted in one frame to avoid harsh turn spikes.
@export var max_look_input_pixels: float = 120.0
## Mouse movement below this pixel amount is treated as no movement.
@export var look_input_deadzone_pixels: float = 0.001

@export_group("Mouse Turn Camera Feel")
## Side camera offset per pixel of horizontal mouse movement.
@export var turn_camera_side_amount: float = 0.00046
## Vertical camera offset per pixel of vertical mouse movement.
@export var turn_camera_vertical_amount: float = 0.00030
## Maximum side offset from mouse turn feel.
@export var max_turn_camera_side_offset: float = 0.060
## Maximum vertical offset from mouse turn feel.
@export var max_turn_camera_vertical_offset: float = 0.044
## Camera pitch added per pixel of vertical mouse movement.
@export var turn_camera_pitch_degrees_per_pixel: float = 0.105
## Camera yaw added per pixel of horizontal mouse movement.
@export var turn_camera_yaw_degrees_per_pixel: float = 0.105
## Maximum extra camera pitch from mouse turn feel.
@export var max_turn_camera_pitch_degrees: float = 8.4
## Maximum extra camera yaw from mouse turn feel.
@export var max_turn_camera_yaw_degrees: float = 6.4
## Speed used to blend mouse turn camera offsets.
@export var turn_camera_lerp_speed: float = 22.0

@export_group("Mouse Turn Strafe Feel")
## Enables mouse turning to add A/D-style camera lean.
@export var enable_turn_strafe_feel: bool = true
## Horizontal mouse pixels that become full virtual strafe feel.
@export var turn_strafe_full_motion_pixels: float = 24.0
## Curve used to shape virtual strafe strength.
@export var turn_strafe_curve: float = 0.85
## How quickly virtual strafe feel enters while turning.
@export var turn_strafe_enter_lerp_speed: float = 24.0
## How quickly virtual strafe feel relaxes after turning.
@export var turn_strafe_return_lerp_speed: float = 18.0
## How much mouse turn contributes to normal A/D roll.
@export var turn_strafe_move_input_mix: float = 0.85
## Side camera shift from virtual mouse strafe.
@export var turn_strafe_side_offset: float = 0.026
## Small downward camera dip while turn strafe is active.
@export var turn_strafe_dip_amount: float = 0.008
## Extra roll added by virtual mouse strafe.
@export var turn_strafe_extra_roll_amount: float = 0.020
## Extra yaw lag added by virtual mouse strafe.
@export var turn_strafe_yaw_degrees: float = 0.45
## Extra pitch weight added by virtual mouse strafe.
@export var turn_strafe_pitch_degrees: float = 0.12

@export_group("FOV")
## Default camera field of view.
@export var base_fov: float = 82.0
## Maximum camera field of view after movement and state bonuses.
@export var max_fov: float = 98.0
## Extra FOV added from movement speed.
@export var speed_fov_bonus: float = 3.5
## Curve for how quickly movement speed opens the FOV.
@export var speed_fov_curve: float = 0.9
## Speed used to blend FOV changes.
@export var fov_lerp_speed: float = 12.0

@export_group("Vertical Feedback")
## Spring strength for vertical camera feedback.
@export var vertical_feedback_stiffness: float = 105.0
## Damping for vertical camera feedback.
@export var vertical_feedback_damping: float = 18.0
## Blend speed for camera feedback position and rotation.
@export var camera_feedback_lerp: float = 15.0

@export_group("Step And Edge Eye Smoothing")
## Softens instant eye-height correction when stairs or edge pulls move the player body.
@export var enable_soft_step_eye_correction: bool = true
## Maximum eye-height correction applied in one frame to hide sharp stair or edge body motion.
@export var max_soft_step_hide_delta: float = 0.72

@export_group("Screen Shake")
## Largest sideways/vertical camera offset at full shake, in meters.
@export var shake_max_position: Vector3 = Vector3(0.07, 0.07, 0.03)
## Largest camera rotation at full shake, in degrees (pitch, yaw, roll).
@export var shake_max_rotation_degrees: Vector3 = Vector3(2.4, 2.0, 3.6)
## How fast the shake jitters. Higher is more violent.
@export var shake_frequency: float = 24.0
## Shake strength lost per second. Shake runs from 1 (full) down to 0.
@export var shake_decay_per_second: float = 1.5
## Strength is squared before use, so small shakes stay subtle and big ones hit hard.
@export var shake_strength_curve: float = 1.5

@export_group("Roll")
## Roll from left/right movement input.
@export var roll_amount: float = 0.045
## Roll from sideways velocity.
@export var velocity_roll_amount: float = 0.020
## Roll from horizontal mouse movement.
@export var look_roll_amount: float = 0.00013
## Maximum roll allowed from mouse movement.
@export var max_look_roll: float = 0.028

func get_feedback_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(camera_feedback_lerp, 0.001) * delta)


func get_soft_step_hide_delta(raw_delta: float) -> float:
	if not enable_soft_step_eye_correction:
		return raw_delta

	var max_delta: float = maxf(max_soft_step_hide_delta, 0.0)
	return clampf(raw_delta, -max_delta, max_delta)


func get_look_input_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(look_input_smoothing_speed, 0.001) * delta)


func get_look_feedback_blend(delta: float) -> float:
	return 1.0 - exp(-maxf(look_feedback_smoothing_speed, 0.001) * delta)


func get_responsive_look_input(raw_motion: Vector2, smoothed_motion: Vector2) -> Vector2:
	var immediate_response: float = clampf(look_input_immediate_response, 0.0, 1.0)
	var responsive_motion: Vector2 = smoothed_motion.lerp(raw_motion, immediate_response)
	return clean_look_input(responsive_motion)


func clamp_look_input(look_motion: Vector2) -> Vector2:
	var max_pixels: float = maxf(max_look_input_pixels, 0.0)
	if max_pixels <= 0.0 or look_motion.length_squared() <= max_pixels * max_pixels:
		return look_motion
	return look_motion.normalized() * max_pixels


func clean_look_input(look_motion: Vector2) -> Vector2:
	var deadzone: float = maxf(look_input_deadzone_pixels, 0.0)
	if look_motion.length_squared() <= deadzone * deadzone:
		return Vector2.ZERO

	return look_motion


func get_turn_blend(delta: float, minimum_lerp_speed: float = 0.0) -> float:
	var lerp_speed: float = maxf(turn_camera_lerp_speed, minimum_lerp_speed)
	return 1.0 - exp(-maxf(lerp_speed, 0.001) * delta)


func get_speed_fov_bonus(speed_ratio: float) -> float:
	var shaped_ratio: float = pow(clampf(speed_ratio, 0.0, 1.0), maxf(speed_fov_curve, 0.001))
	return shaped_ratio * maxf(speed_fov_bonus, 0.0)


func get_clamped_fov(target_fov: float) -> float:
	var highest_fov: float = maxf(max_fov, base_fov)
	return clampf(target_fov, base_fov, highest_fov)


func get_turn_position(look_motion: Vector2) -> Vector3:
	var side_offset: float = clampf(
		-look_motion.x * turn_camera_side_amount,
		-max_turn_camera_side_offset,
		max_turn_camera_side_offset
	)
	var vertical_offset: float = clampf(
		look_motion.y * turn_camera_vertical_amount,
		-max_turn_camera_vertical_offset,
		max_turn_camera_vertical_offset
	)
	return Vector3(side_offset, vertical_offset, 0.0)


func get_turn_rotation(look_motion: Vector2) -> Vector3:
	var pitch_amount: float = deg_to_rad(turn_camera_pitch_degrees_per_pixel)
	var yaw_amount: float = deg_to_rad(turn_camera_yaw_degrees_per_pixel)
	var max_pitch: float = deg_to_rad(max_turn_camera_pitch_degrees)
	var max_yaw: float = deg_to_rad(max_turn_camera_yaw_degrees)
	var pitch: float = clampf(-look_motion.y * pitch_amount, -max_pitch, max_pitch)
	var yaw: float = clampf(-look_motion.x * yaw_amount, -max_yaw, max_yaw)
	return Vector3(pitch, yaw, 0.0)


func get_turn_strafe_target(look_motion: Vector2) -> float:
	if not enable_turn_strafe_feel:
		return 0.0

	var raw_turn: float = look_motion.x / maxf(turn_strafe_full_motion_pixels, 0.001)
	var strength: float = clampf(absf(raw_turn), 0.0, 1.0)
	strength = pow(strength, maxf(turn_strafe_curve, 0.001))
	if raw_turn < 0.0:
		return -strength
	return strength


func get_turn_strafe_blend(delta: float, current_strafe: float, target_strafe: float) -> float:
	var lerp_speed: float = turn_strafe_return_lerp_speed
	if absf(target_strafe) > absf(current_strafe):
		lerp_speed = turn_strafe_enter_lerp_speed
	return 1.0 - exp(-maxf(lerp_speed, 0.001) * delta)


func get_combined_strafe_input(move_side: float, turn_strafe: float) -> float:
	var turn_side: float = turn_strafe * maxf(turn_strafe_move_input_mix, 0.0)
	return clampf(move_side + turn_side, -1.0, 1.0)


func get_turn_strafe_position(turn_strafe: float) -> Vector3:
	return Vector3(
		turn_strafe * turn_strafe_side_offset,
		-absf(turn_strafe) * turn_strafe_dip_amount,
		0.0
	)


func get_turn_strafe_rotation(turn_strafe: float) -> Vector3:
	var pitch: float = absf(turn_strafe) * deg_to_rad(turn_strafe_pitch_degrees)
	var yaw: float = -turn_strafe * deg_to_rad(turn_strafe_yaw_degrees)
	var roll: float = -turn_strafe * turn_strafe_extra_roll_amount
	return Vector3(pitch, yaw, roll)
