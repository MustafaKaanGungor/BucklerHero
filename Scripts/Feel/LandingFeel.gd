extends Node

@export_group("Impact Strength")
## Enables landing impact feedback from player fall speed.
@export var enable_landing_feedback: bool = true
## Fall speed where landing feedback starts.
@export var landing_min_speed: float = 1.25
## Fall speed where landing feedback reaches full strength.
@export var landing_full_speed: float = 12.0
## Curve below 1 makes medium landings feel harder.
@export var landing_impact_curve: float = 0.75
## Global multiplier for landing impact strength.
@export var landing_weight_multiplier: float = 1.25
## Extra landing impact added from fast horizontal movement.
@export var horizontal_speed_impact_bonus: float = 0.12
## Maximum impact sent to camera and hands.
@export var max_landing_impact: float = 1.25
## Time recent landing strength remains readable by hands.
@export var recent_feedback_time: float = 0.16
## Downward speed used to keep the player grounded after landing.
@export var landing_stick_velocity: float = 0.7

@export_group("First Leg")
## Immediate hard camera dip from the first foot touching down.
@export var first_leg_dip_amount: float = 0.58
## Upward rebound after the first foot impact.
@export var first_leg_rebound_velocity: float = 2.35
## Small side shift from landing on one foot first.
@export var first_leg_side_offset: float = 0.018
## Camera roll from the first foot impact.
@export var first_leg_roll_degrees: float = 1.8

@export_group("Second Leg")
## Delay before the second foot settles the landing.
@export var second_leg_delay: float = 0.055
## Strength of the second foot compared with the first.
@export var second_leg_strength: float = 0.48
## Smaller second camera dip after the other foot lands.
@export var second_leg_dip_amount: float = 0.22
## Rebound from the second foot impact.
@export var second_leg_rebound_velocity: float = 1.05
## Side correction from the second foot landing.
@export var second_leg_side_offset: float = 0.012
## Opposite roll from the second foot landing.
@export var second_leg_roll_degrees: float = 1.15

@export_group("Pitch Jolt")
## Enables CamPositioner-style landing pitch kick.
@export var enable_pitch_jolt: bool = true
## Downward camera pitch from the first foot impact.
@export var first_leg_pitch_degrees: float = 2.6
## Small opposite pitch correction from the second foot landing.
@export var second_leg_pitch_degrees: float = -0.8

@export_group("Recovery")
## Spring strength for vertical landing recovery.
@export var vertical_stiffness: float = 150.0
## Damping for vertical landing recovery.
@export var vertical_damping: float = 17.5
## Spring strength for side landing recovery.
@export var side_stiffness: float = 115.0
## Damping for side landing recovery.
@export var side_damping: float = 18.0
## Spring strength for roll landing recovery.
@export var roll_stiffness: float = 120.0
## Spring strength for pitch landing recovery.
@export var pitch_stiffness: float = 125.0
## Damping for roll landing recovery.
@export var roll_damping: float = 18.0
## Damping for pitch landing recovery.
@export var pitch_damping: float = 18.5


func get_impact_strength(fall_speed: float, horizontal_speed: float, max_horizontal_speed: float) -> float:
	if not enable_landing_feedback:
		return 0.0
	if fall_speed < landing_min_speed:
		return 0.0

	var impact_range: float = maxf(landing_full_speed - landing_min_speed, 0.001)
	var raw_impact: float = clampf((fall_speed - landing_min_speed) / impact_range, 0.0, 1.0)
	var shaped_impact: float = pow(raw_impact, maxf(landing_impact_curve, 0.001))
	shaped_impact *= maxf(landing_weight_multiplier, 0.0)
	shaped_impact += _get_horizontal_impact_bonus(horizontal_speed, max_horizontal_speed)
	return clampf(shaped_impact, 0.0, maxf(max_landing_impact, 0.0))


func _get_horizontal_impact_bonus(horizontal_speed: float, max_horizontal_speed: float) -> float:
	if max_horizontal_speed <= 0.0:
		return 0.0

	var speed_ratio: float = clampf(horizontal_speed / max_horizontal_speed, 0.0, 1.0)
	return speed_ratio * maxf(horizontal_speed_impact_bonus, 0.0)
