extends Node

@export_group("Eye Height")
## Camera eye height while standing.
@export var standing_eye_height: float = 1.62
## Camera eye height while crouching.
@export var crouching_eye_height: float = 0.95
## Speed used to blend camera height after body height changes.
@export var eye_height_lerp_speed: float = 18.0
## Extra speed used when the camera drops into crouch.
@export var eye_drop_lerp_speed: float = 24.0
## Speed used when the camera rises back to standing.
@export var eye_raise_lerp_speed: float = 14.0

@export_group("Crouch Walk Feel")
## Vertical bob amount while crouch-walking.
@export var crouch_bob_amount: float = 0.066
## Frequency multiplier used for slower stealth-like crouch steps.
@export var crouch_bob_frequency_multiplier: float = 0.78
## Side bob multiplier while crouch-walking.
@export var crouch_bob_side_multiplier: float = 0.58
## Forward bob multiplier while crouch-walking.
@export var crouch_bob_forward_multiplier: float = 0.62
## Downward foot dip added during crouch steps.
@export var crouch_step_dip_amount: float = 0.014
## Forward nudge added during crouch steps.
@export var crouch_step_forward_amount: float = 0.006
## Roll sway added during crouch steps.
@export var crouch_step_roll_amount: float = 0.005
## Higher values make crouch foot dips sharper.
@export var crouch_step_sharpness: float = 3.7

@export_group("Transition Feedback")
## Base strength used when entering crouch.
@export var crouch_enter_feedback_strength: float = 1.0
## Base strength used when leaving crouch.
@export var crouch_exit_feedback_strength: float = 0.82
## Extra feedback added from horizontal speed.
@export var crouch_speed_feedback_influence: float = 0.22
## Air crouch feedback multiplier.
@export var crouch_air_feedback_multiplier: float = 0.55
## Time recent crouch feedback stays readable by viewmodel scripts.
@export var recent_feedback_time: float = 0.22

@export_group("Camera Transition")
## Camera impulse when the body drops into crouch.
@export var crouch_enter_camera_position: Vector3 = Vector3(0.0, -0.095, 0.035)
## Camera rotation impulse when the body drops into crouch.
@export var crouch_enter_camera_rotation_degrees: Vector3 = Vector3(2.2, 0.0, 0.45)
## Camera impulse when the body rises from crouch.
@export var crouch_exit_camera_position: Vector3 = Vector3(0.0, 0.054, -0.018)
## Camera rotation impulse when the body rises from crouch.
@export var crouch_exit_camera_rotation_degrees: Vector3 = Vector3(-1.45, 0.0, -0.25)
## Spring strength used to recover crouch camera impulses.
@export var crouch_camera_spring_stiffness: float = 118.0
## Damping used to settle crouch camera impulses.
@export var crouch_camera_spring_damping: float = 17.0


func get_eye_height(body_height: float) -> float:
	var crouch_blend: float = inverse_lerp(MovementCrouch.standing_height, MovementCrouch.crouching_height, body_height)
	crouch_blend = clampf(crouch_blend, 0.0, 1.0)
	return lerpf(standing_eye_height, crouching_eye_height, crouch_blend)


func get_eye_height_blend(current_eye_height: float, target_eye_height: float, delta: float) -> float:
	var lerp_speed: float = eye_height_lerp_speed
	if target_eye_height < current_eye_height:
		lerp_speed = maxf(eye_height_lerp_speed, eye_drop_lerp_speed)
	elif target_eye_height > current_eye_height:
		lerp_speed = maxf(eye_raise_lerp_speed, 0.001)
	return 1.0 - exp(-maxf(lerp_speed, 0.001) * delta)


func get_crouch_step_dip(phase: float, strength: float) -> float:
	var footfall: float = maxf(cos(phase * 2.0), 0.0)
	footfall = pow(footfall, maxf(crouch_step_sharpness, 0.001))
	return footfall * crouch_step_dip_amount * clampf(strength, 0.0, 1.0)


func get_crouch_step_forward(phase: float, strength: float) -> float:
	var footfall: float = maxf(cos(phase * 2.0), 0.0)
	footfall = pow(footfall, maxf(crouch_step_sharpness, 0.001))
	return footfall * crouch_step_forward_amount * clampf(strength, 0.0, 1.0)


func get_crouch_step_roll(phase: float, strength: float) -> float:
	return sin(phase) * crouch_step_roll_amount * clampf(strength, 0.0, 1.0)


func get_enter_feedback_strength(horizontal_speed: float, reference_speed: float, is_on_ground: bool) -> float:
	return _get_transition_strength(crouch_enter_feedback_strength, horizontal_speed, reference_speed, is_on_ground)


func get_exit_feedback_strength(horizontal_speed: float, reference_speed: float, is_on_ground: bool) -> float:
	return _get_transition_strength(crouch_exit_feedback_strength, horizontal_speed, reference_speed, is_on_ground)


func get_enter_camera_position_impulse(strength: float) -> Vector3:
	return crouch_enter_camera_position * maxf(strength, 0.0)


func get_enter_camera_rotation_impulse(strength: float) -> Vector3:
	return _degrees_to_radians(crouch_enter_camera_rotation_degrees) * maxf(strength, 0.0)


func get_exit_camera_position_impulse(strength: float) -> Vector3:
	return crouch_exit_camera_position * maxf(strength, 0.0)


func get_exit_camera_rotation_impulse(strength: float) -> Vector3:
	return _degrees_to_radians(crouch_exit_camera_rotation_degrees) * maxf(strength, 0.0)


func _get_transition_strength(base_strength: float, horizontal_speed: float, reference_speed: float, is_on_ground: bool) -> float:
	var speed_ratio: float = clampf(horizontal_speed / maxf(reference_speed, 0.001), 0.0, 1.0)
	var strength: float = maxf(base_strength, 0.0) * (1.0 + (speed_ratio * maxf(crouch_speed_feedback_influence, 0.0)))
	if not is_on_ground:
		strength *= clampf(crouch_air_feedback_multiplier, 0.0, 1.0)
	return strength


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees_value.x),
		deg_to_rad(degrees_value.y),
		deg_to_rad(degrees_value.z)
	)
