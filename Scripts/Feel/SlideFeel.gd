extends Node

@export_group("Camera Pose")
## Camera position while sliding.
@export var slide_camera_position_offset: Vector3 = Vector3(0.0, -0.09, 0.07)
## Extra forward camera push added by slide speed.
@export var slide_speed_forward_offset: float = 0.035
## Extra downward camera dip added by slide speed.
@export var slide_speed_dip_amount: float = 0.035
## Camera rotation while sliding.
@export var slide_camera_rotation_degrees: Vector3 = Vector3(4.8, 0.0, -2.2)
## Side camera movement from A/D input while sliding.
@export var slide_strafe_position_amount: float = 0.07
## Roll from A/D input while sliding.
@export var slide_strafe_roll_degrees: float = 7.0
## Extra pitch from high slide speed.
@export var slide_speed_pitch_degrees: float = 1.2
## Multiplies mouse look roll while sliding.
@export var slide_look_roll_multiplier: float = 1.5
## Minimum camera lerp speed while sliding.
@export var slide_camera_lerp_speed: float = 16.0

@export_group("FOV")
## Base FOV increase while sliding.
@export var slide_fov_bonus: float = 2.2
## Extra FOV increase from slide speed.
@export var slide_speed_fov_bonus: float = 1.4

@export_group("Ground Shake")
## Enables small camera shake from sliding along the ground.
@export var enable_slide_ground_shake: bool = true
## Base ground shake frequency in cycles per second.
@export var slide_shake_frequency: float = 18.0
## Extra shake frequency from slide speed.
@export var slide_shake_speed_frequency_bonus: float = 9.0
## Extra shake frequency from slope or rough ground response.
@export var slide_shake_ground_frequency_bonus: float = 5.0
## Minimum speed ratio needed before ground shake starts.
@export var slide_shake_min_speed_ratio: float = 0.22
## Overall shake strength.
@export var slide_shake_strength: float = 0.62
## Extra shake strength from slope or rough ground response.
@export var slide_shake_ground_strength_multiplier: float = 0.5
## Shape curve for shake strength.
@export var slide_shake_curve: float = 1.25
## Camera position shake at full slide ground strength.
@export var slide_shake_position_amount: Vector3 = Vector3(0.012, 0.008, 0.004)
## Camera rotation shake at full slide ground strength.
@export var slide_shake_rotation_degrees: Vector3 = Vector3(0.25, 0.16, 0.42)


func get_camera_position(
	move_input: Vector2,
	slide_blend: float,
	slide_speed: float,
	max_slide_speed: float,
	shake_phase: float,
	ground_strength: float
) -> Vector3:
	if slide_blend <= 0.0:
		return Vector3.ZERO

	var blend: float = clampf(slide_blend, 0.0, 1.0)
	var speed_ratio: float = get_slide_speed_ratio(slide_speed, max_slide_speed)
	var camera_position: Vector3 = slide_camera_position_offset * blend
	camera_position.x += move_input.x * slide_strafe_position_amount * blend
	camera_position.y -= speed_ratio * slide_speed_dip_amount * blend
	camera_position.z += speed_ratio * slide_speed_forward_offset * blend
	camera_position += get_ground_shake_position(shake_phase, blend, speed_ratio, ground_strength)
	return camera_position


func get_camera_rotation(
	move_input: Vector2,
	slide_blend: float,
	slide_speed: float,
	max_slide_speed: float,
	shake_phase: float,
	ground_strength: float
) -> Vector3:
	if slide_blend <= 0.0:
		return Vector3.ZERO

	var blend: float = clampf(slide_blend, 0.0, 1.0)
	var speed_ratio: float = get_slide_speed_ratio(slide_speed, max_slide_speed)
	var camera_rotation: Vector3 = _degrees_to_radians(slide_camera_rotation_degrees)
	camera_rotation.x += speed_ratio * deg_to_rad(slide_speed_pitch_degrees)
	camera_rotation.z += -move_input.x * deg_to_rad(slide_strafe_roll_degrees)
	camera_rotation *= blend
	camera_rotation += get_ground_shake_rotation(shake_phase, blend, speed_ratio, ground_strength)
	return camera_rotation


func get_fov_bonus(slide_blend: float, slide_speed: float, max_slide_speed: float) -> float:
	var blend: float = clampf(slide_blend, 0.0, 1.0)
	var speed_ratio: float = get_slide_speed_ratio(slide_speed, max_slide_speed)
	return (slide_fov_bonus + (speed_ratio * slide_speed_fov_bonus)) * blend


func get_shake_phase_speed(slide_speed: float, max_slide_speed: float, ground_strength: float) -> float:
	var speed_ratio: float = get_slide_speed_ratio(slide_speed, max_slide_speed)
	var frequency: float = maxf(slide_shake_frequency, 0.0)
	frequency += speed_ratio * maxf(slide_shake_speed_frequency_bonus, 0.0)
	frequency += maxf(ground_strength, 0.0) * maxf(slide_shake_ground_frequency_bonus, 0.0)
	return frequency * TAU


func get_ground_shake_position(
	shake_phase: float,
	slide_blend: float,
	speed_ratio: float,
	ground_strength: float
) -> Vector3:
	var shake_strength: float = get_ground_shake_strength(slide_blend, speed_ratio, ground_strength)
	return Vector3(
		sin(shake_phase * 1.37) * slide_shake_position_amount.x,
		sin(shake_phase * 2.11 + 1.1) * slide_shake_position_amount.y,
		sin(shake_phase * 1.63 + 0.35) * slide_shake_position_amount.z
	) * shake_strength


func get_ground_shake_rotation(
	shake_phase: float,
	slide_blend: float,
	speed_ratio: float,
	ground_strength: float
) -> Vector3:
	var shake_strength: float = get_ground_shake_strength(slide_blend, speed_ratio, ground_strength)
	var shake_rotation: Vector3 = _degrees_to_radians(slide_shake_rotation_degrees)
	return Vector3(
		sin(shake_phase * 2.03 + 0.4) * shake_rotation.x,
		sin(shake_phase * 1.29 + 2.2) * shake_rotation.y,
		sin(shake_phase * 1.71 + 1.7) * shake_rotation.z
	) * shake_strength


func get_ground_shake_strength(slide_blend: float, speed_ratio: float, ground_strength: float) -> float:
	if not enable_slide_ground_shake:
		return 0.0

	var blend: float = clampf(slide_blend, 0.0, 1.0)
	var minimum_speed: float = clampf(slide_shake_min_speed_ratio, 0.0, 0.99)
	var speed_strength: float = clampf((speed_ratio - minimum_speed) / maxf(1.0 - minimum_speed, 0.001), 0.0, 1.0)
	var environment_strength: float = 1.0 + (maxf(ground_strength, 0.0) * maxf(slide_shake_ground_strength_multiplier, 0.0))
	var raw_strength: float = blend * speed_strength * maxf(slide_shake_strength, 0.0) * environment_strength
	return pow(clampf(raw_strength, 0.0, 1.0), maxf(slide_shake_curve, 0.001))


func get_slide_speed_ratio(slide_speed: float, max_slide_speed: float) -> float:
	return clampf(maxf(slide_speed, 0.0) / maxf(max_slide_speed, 0.001), 0.0, 1.0)


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees_value.x),
		deg_to_rad(degrees_value.y),
		deg_to_rad(degrees_value.z)
	)
