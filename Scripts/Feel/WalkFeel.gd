extends Node

@export_group("Camera Bob")
## Vertical bob amount while walking.
@export var walk_bob_amount: float = 0.135
## Base frequency of movement camera bob.
@export var head_bob_frequency: float = 2.20
## Side-to-side camera bob amount.
@export var bob_side_amount: float = 0.038
## Forward-back camera bob amount.
@export var bob_forward_amount: float = 0.024

@export_group("Step Impact")
## Enables sharper footfall dips during walking.
@export var enable_step_impact: bool = true
## Downward camera dip added on each footstep.
@export var step_impact_amount: float = 0.030
## Forward nudge added at each footstep.
@export var step_forward_amount: float = 0.012
## Roll sway added from alternating steps.
@export var step_roll_amount: float = 0.008
## Higher values make footstep impact shorter and sharper.
@export var step_impact_sharpness: float = 5.0
## Extra step strength while sprinting uses walk footfall feel.
@export var sprint_step_strength_multiplier: float = 1.15

@export_group("Stop Feedback")
## Enables a small camera dip when walking input is released.
@export var enable_stop_feedback: bool = true
## Speed needed before stop feedback can trigger.
@export var stop_feedback_min_speed: float = 1.2
## Minimum speed drop needed to add stop feedback.
@export var stop_feedback_min_drop: float = 0.08
## Downward camera dip added from sudden walking slowdown.
@export var stop_dip_amount: float = 0.012
## Maximum stop dip camera offset.
@export var max_stop_dip: float = 0.030
## Speed used to recover stop feedback back to neutral.
@export var stop_dip_return_lerp_speed: float = 15.0


func get_step_strength(speed_ratio: float, is_crouching: bool, is_sprinting: bool, slide_blend: float) -> float:
	if is_crouching or slide_blend > 0.15:
		return 0.0

	var strength: float = clampf(speed_ratio, 0.0, 1.0)
	if is_sprinting:
		strength *= maxf(sprint_step_strength_multiplier, 0.0)
	return clampf(strength, 0.0, 1.25)


func get_step_impact(phase: float, strength: float) -> float:
	if not enable_step_impact:
		return 0.0

	var footfall: float = maxf(cos(phase * 2.0), 0.0)
	footfall = pow(footfall, maxf(step_impact_sharpness, 0.001))
	return footfall * step_impact_amount * strength


func get_step_forward_impact(phase: float, strength: float) -> float:
	if not enable_step_impact:
		return 0.0

	var footfall: float = maxf(cos(phase * 2.0), 0.0)
	footfall = pow(footfall, maxf(step_impact_sharpness, 0.001))
	return footfall * step_forward_amount * strength


func get_step_roll(phase: float, strength: float) -> float:
	if not enable_step_impact:
		return 0.0
	return sin(phase) * step_roll_amount * strength


func get_stop_dip(current_dip: float, previous_speed: float, horizontal_speed: float, has_move_input: bool, delta: float) -> float:
	var target_dip: float = current_dip
	if enable_stop_feedback and not has_move_input and previous_speed >= stop_feedback_min_speed:
		var speed_drop: float = maxf(previous_speed - horizontal_speed, 0.0)
		if speed_drop >= stop_feedback_min_drop:
			target_dip = minf(current_dip + (speed_drop * stop_dip_amount), max_stop_dip)

	var return_blend: float = 1.0 - exp(-maxf(stop_dip_return_lerp_speed, 0.001) * delta)
	return lerpf(target_dip, 0.0, return_blend)
