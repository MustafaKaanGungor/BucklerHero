extends Node

@export_group("Feedback")
## Scales camera and hand kick when jumping.
@export var jump_feedback_multiplier: float = 1.08

@export_group("Camera Feel")
## Upward camera kick applied when jumping.
@export var jump_lift_velocity: float = 0.58
## Small camera position impulse when jumping.
@export var jump_camera_position_impulse: Vector3 = Vector3(0.0, 0.018, 0.018)
## Small camera rotation impulse when jumping.
@export var jump_camera_rotation_degrees: Vector3 = Vector3(-1.6, 0.0, 0.0)


func get_camera_position_impulse(strength: float) -> Vector3:
	return jump_camera_position_impulse * maxf(strength, 0.0)


func get_camera_rotation_impulse(strength: float) -> Vector3:
	var impulse_strength: float = maxf(strength, 0.0)
	return Vector3(
		deg_to_rad(jump_camera_rotation_degrees.x),
		deg_to_rad(jump_camera_rotation_degrees.y),
		deg_to_rad(jump_camera_rotation_degrees.z)
	) * impulse_strength
