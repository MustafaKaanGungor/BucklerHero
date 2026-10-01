extends Node

@export_group("Speed")
## Ground speed used while crouching.
@export var crouch_speed: float = 2.4

@export_group("Body")
## Standing collision body height.
@export var standing_height: float = 1.8
## Crouched collision body height.
@export var crouching_height: float = 1.05
## Capsule radius shared by standing and crouched body shapes.
@export var capsule_radius: float = 0.35
## Speed used to blend body height into crouch or stand.
@export var crouch_lerp_speed: float = 16.0
## Speed used when dropping into crouch.
@export var crouch_enter_lerp_speed: float = 22.0
## Speed used when rising back to standing.
@export var crouch_exit_lerp_speed: float = 13.0

@export_group("Auto Crouch")
## Enables crouching automatically under low ceilings.
@export var enable_auto_crouch: bool = true
## Forces crouch while the standing body is blocked.
@export var force_crouch_when_head_blocked: bool = true
## Distance ahead used to test upcoming crouch clearance.
@export var auto_crouch_probe_distance: float = 0.25
## Minimum speed needed before probing ahead for auto crouch.
@export var auto_crouch_probe_min_speed: float = 0.1
## Extra height used when testing if standing is clear.
@export var stand_clearance_margin: float = 0.04
## Extra height used when testing if crouching is clear.
@export var crouch_clearance_margin: float = 0.02
## Vertical margin used by body clearance shape casts.
@export var clearance_test_margin: float = 0.02
## Maximum hits accepted from clearance shape tests.
@export var clearance_max_results: int = 8


func get_target_height(is_crouching: bool) -> float:
	if is_crouching:
		return crouching_height
	return standing_height


func get_height_blend(delta: float, is_crouching: bool = false) -> float:
	var lerp_speed: float = crouch_lerp_speed
	if is_crouching:
		lerp_speed = maxf(crouch_lerp_speed, crouch_enter_lerp_speed)
	else:
		lerp_speed = maxf(crouch_exit_lerp_speed, 0.001)
	return 1.0 - exp(-maxf(lerp_speed, 0.001) * delta)
