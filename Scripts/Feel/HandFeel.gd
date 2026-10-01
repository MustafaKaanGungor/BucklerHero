extends Node

@export_group("Placement")
@export var base_position: Vector3 = Vector3(0.0, -0.72, -0.58)
@export var base_rotation_degrees: Vector3 = Vector3(-4.0, 0.0, 0.0)
@export var motion_presence_multiplier: float = 0.74
@export var follow_lerp_speed: float = 16.0
@export var rotation_lerp_speed: float = 14.0

@export_group("Hand Spread")
@export var left_hand_position: Vector3 = Vector3(-0.18, -0.255, 0.035)
@export var right_hand_position: Vector3 = Vector3(0.18, -0.255, 0.035)
@export var left_hand_rotation_degrees: Vector3 = Vector3(2.5, -7.0, -4.5)
@export var right_hand_rotation_degrees: Vector3 = Vector3(2.5, 7.0, 4.5)
@export var hand_lerp_speed: float = 18.0

@export_group("Body Tuck")
## Tucks the whole viewmodel down and inward while walking or sprinting.
@export var ground_move_tuck_position: Vector3 = Vector3(0.0, -0.145, 0.105)
## Rotates the hands toward the player body while walking or sprinting.
@export var ground_move_tuck_rotation_degrees: Vector3 = Vector3(2.4, 0.0, 0.0)
## Extra tuck added as sprint speed ramps up.
@export var sprint_tuck_position: Vector3 = Vector3(0.0, -0.080, 0.045)
## Extra sprint rotation toward the player body.
@export var sprint_tuck_rotation_degrees: Vector3 = Vector3(1.8, 0.0, 0.0)

@export_group("Movement Sway")
@export var move_sway_position: Vector3 = Vector3(0.050, 0.022, 0.035)
@export var move_sway_rotation_degrees: Vector3 = Vector3(1.6, 2.6, 3.8)
@export var look_sway_position: Vector3 = Vector3(0.0011, 0.0008, 0.0)
@export var look_sway_rotation_degrees: Vector3 = Vector3(0.024, 0.030, 0.020)
@export var max_look_sway: Vector2 = Vector2(36.0, 28.0)

@export_group("Bob")
@export var walk_bob_position: Vector3 = Vector3(0.022, 0.030, 0.012)
@export var sprint_bob_position: Vector3 = Vector3(0.030, 0.038, 0.016)
@export var crouch_bob_position: Vector3 = Vector3(0.016, 0.024, 0.009)
@export var bob_frequency: float = 1.95
@export var sprint_frequency_multiplier: float = 1.18

@export_group("State Offsets")
@export var sprint_position_offset: Vector3 = Vector3(0.0, -0.035, 0.010)
@export var sprint_rotation_degrees: Vector3 = Vector3(-2.8, 0.0, 1.6)
@export var crouch_position_offset: Vector3 = Vector3(0.0, -0.105, 0.070)
@export var crouch_rotation_degrees: Vector3 = Vector3(3.2, 0.0, 0.0)
@export var fall_position_offset: Vector3 = Vector3(0.0, 0.045, 0.020)
@export var fall_rotation_degrees: Vector3 = Vector3(4.2, 0.0, 0.0)

@export_group("Crouch Transition")
## Viewmodel kick while entering crouch.
@export var crouch_enter_kick_position: Vector3 = Vector3(0.0, -0.085, 0.085)
## Viewmodel rotation kick while entering crouch.
@export var crouch_enter_kick_rotation_degrees: Vector3 = Vector3(6.0, 0.0, 0.75)
## Viewmodel kick while standing up from crouch.
@export var crouch_exit_kick_position: Vector3 = Vector3(0.0, 0.052, -0.045)
## Viewmodel rotation kick while standing up from crouch.
@export var crouch_exit_kick_rotation_degrees: Vector3 = Vector3(-3.5, 0.0, -0.35)

@export_group("Slide Feel")
@export var slide_position_offset: Vector3 = Vector3(0.0, -0.12, 0.05)
@export var slide_rotation_degrees: Vector3 = Vector3(5.0, 0.0, -2.0)
@export var slide_left_hand_position_offset: Vector3 = Vector3(-0.06, -0.04, -0.2)
@export var slide_right_hand_position_offset: Vector3 = Vector3(0.08, 0.025, 0.13)
@export var slide_left_hand_rotation_degrees: Vector3 = Vector3(9.0, -13.0, -13.0)
@export var slide_right_hand_rotation_degrees: Vector3 = Vector3(-2.0, 8.0, 10.0)
@export var slide_bob_multiplier: float = 0.25

@export_group("Wall Run Feel")
## Root hand offset while the player is attached to a wall.
@export var wall_run_position_offset: Vector3 = Vector3(0.0, -0.055, 0.06)
## Side root offset that moves hands away from the wall.
@export var wall_run_away_side_offset: float = 0.045
## Root hand rotation while the player is attached to a wall.
@export var wall_run_rotation_degrees: Vector3 = Vector3(3.5, 0.0, 0.0)
## Root roll amount that leans the hands with the wall-run side.
@export var wall_run_side_roll_degrees: float = 5.5
## Bob amount used while wall running in the air.
@export var wall_run_bob_position: Vector3 = Vector3(0.028, 0.034, 0.02)
## Hand bob frequency multiplier while wall running.
@export var wall_run_frequency_multiplier: float = 1.22
## Position offset for the hand nearest to the wall.
@export var wall_run_wall_hand_position_offset: Vector3 = Vector3(0.085, 0.035, 0.16)
## Position offset for the hand away from the wall.
@export var wall_run_free_hand_position_offset: Vector3 = Vector3(0.045, -0.035, -0.08)
## Rotation offset for the hand nearest to the wall.
@export var wall_run_wall_hand_rotation_degrees: Vector3 = Vector3(-7.0, 12.0, 18.0)
## Rotation offset for the hand away from the wall.
@export var wall_run_free_hand_rotation_degrees: Vector3 = Vector3(5.0, -8.0, -11.0)
## Extra alternating hand motion while wall running.
@export var wall_run_hand_alternate_multiplier: float = 1.25

@export_group("Stair Feel")
@export var stair_position_offset: Vector3 = Vector3(0.0, -0.026, 0.028)
@export var stair_rotation_degrees: Vector3 = Vector3(1.8, 0.0, 0.0)
@export var stair_step_kick_position: Vector3 = Vector3(0.0, -0.026, -0.010)
@export var stair_step_kick_rotation_degrees: Vector3 = Vector3(-2.2, 0.0, 0.0)

@export_group("Jump And Landing")
@export var jump_kick_position: Vector3 = Vector3(0.0, 0.075, 0.04)
@export var jump_kick_rotation_degrees: Vector3 = Vector3(7.0, 0.0, 0.0)
@export var landing_kick_position: Vector3 = Vector3(0.0, -0.15, -0.06)
@export var landing_kick_rotation_degrees: Vector3 = Vector3(-10.0, 0.0, 0.0)
@export var impulse_spring_stiffness: float = 100.0
@export var impulse_spring_damping: float = 16.0

@export_group("Surface Protection")
@export var enable_surface_pushback: bool = true
@export var surface_use_player_collision_mask: bool = true
@export var surface_collision_mask: int = 1
@export var surface_probe_distance: float = 1.05
@export var surface_ground_probe_distance: float = 0.95
@export var surface_probe_clearance: float = 0.18
@export var surface_side_probe_offset: float = 0.24
@export var surface_vertical_probe_offset: float = -0.18
@export var surface_ground_probe_down_bias: float = 0.55
@export var surface_pushback_curve: float = 1.25
@export var surface_pushback_lerp_speed: float = 22.0
@export var surface_return_lerp_speed: float = 10.0
@export var surface_pushback_position: Vector3 = Vector3(0.0, -0.030, 0.30)
@export var surface_pushback_rotation_degrees: Vector3 = Vector3(-6.5, 0.0, 0.0)
@export var surface_left_hand_position_offset: Vector3 = Vector3(0.020, -0.015, 0.050)
@export var surface_right_hand_position_offset: Vector3 = Vector3(-0.020, -0.015, 0.050)
@export var surface_left_hand_rotation_degrees: Vector3 = Vector3(-4.0, 5.0, -4.0)
@export var surface_right_hand_rotation_degrees: Vector3 = Vector3(-4.0, -5.0, 4.0)

@export_group("Visuals")
@export var hand_scale: Vector3 = Vector3(0.170, 0.132, 0.265)
@export var render_over_world: bool = true
@export var viewmodel_render_priority: int = 100
@export var disable_viewmodel_shadows: bool = true
@export var disable_viewmodel_receive_shadows: bool = true
@export var ignore_viewmodel_occlusion_culling: bool = true
@export var viewmodel_extra_cull_margin: float = 1.0
