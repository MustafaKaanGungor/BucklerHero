extends Node3D

const METHOD_GET_HORIZONTAL_SPEED: StringName = &"get_horizontal_speed"
const METHOD_GET_MOVE_INPUT: StringName = &"get_move_input"
const METHOD_GET_RECENT_JUMP_FEEDBACK: StringName = &"get_recent_jump_feedback"
const METHOD_GET_RECENT_LANDING_IMPACT: StringName = &"get_recent_landing_impact"
const METHOD_GET_RECENT_CROUCH_FEEDBACK: StringName = &"get_recent_crouch_feedback"
const METHOD_GET_RECENT_CLIMB_FEEDBACK: StringName = &"get_recent_climb_feedback"
const METHOD_GET_RECENT_STAIR_STEP: StringName = &"get_recent_stair_step"
const METHOD_GET_TARGET_SPEED: StringName = &"get_target_speed"
const METHOD_GET_VERTICAL_VELOCITY: StringName = &"get_vertical_velocity"
const METHOD_GET_STAIR_BLEND: StringName = &"get_stair_blend"
const METHOD_GET_SLIDE_BLEND: StringName = &"get_slide_blend"
const METHOD_GET_CLIMB_BLEND: StringName = &"get_climb_blend"
const METHOD_GET_CLIMB_PROGRESS: StringName = &"get_climb_progress"
const METHOD_GET_EDGE_HOLD_BLEND: StringName = &"get_edge_hold_blend"
const METHOD_GET_EDGE_HOLD_SIDE_INPUT: StringName = &"get_edge_hold_side_input"
const METHOD_GET_EDGE_PULL_OVER_BLEND: StringName = &"get_edge_pull_over_blend"
const METHOD_GET_EDGE_PULL_OVER_PROGRESS: StringName = &"get_edge_pull_over_progress"
const METHOD_GET_EDGE_PULL_OVER_STRENGTH: StringName = &"get_edge_pull_over_strength"
const METHOD_GET_WALL_RUN_BLEND: StringName = &"get_wall_run_blend"
const METHOD_GET_WALL_RUN_SIDE: StringName = &"get_wall_run_side"
const METHOD_GET_SPRINT_RAMP_BLEND: StringName = &"get_sprint_ramp_blend"
const METHOD_GET_LOOK_MOTION: StringName = &"get_look_motion"
const METHOD_IS_CROUCHING: StringName = &"is_crouching"
const METHOD_IS_SPRINTING: StringName = &"is_sprinting"
const METHOD_IS_SLIDING: StringName = &"is_sliding"

@export var player_path: NodePath = NodePath("../../..")
@export var head_path: NodePath = NodePath("../..")
@export var left_hand_path: NodePath = NodePath("HandLeft")
@export var right_hand_path: NodePath = NodePath("HandRight")

var player: CharacterBody3D
var head: Node3D
var camera: Camera3D
var left_hand: Node3D
var right_hand: Node3D
var _bob_phase: float = 0.0
var _base_rotation: Vector3 = Vector3.ZERO
var _left_base_rotation: Vector3 = Vector3.ZERO
var _right_base_rotation: Vector3 = Vector3.ZERO
var _surface_pushback: float = 0.0
var _surface_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _surface_query_exclude: Array[RID] = []
var _impulse_position: Vector3 = Vector3.ZERO
var _impulse_position_velocity: Vector3 = Vector3.ZERO
var _impulse_rotation: Vector3 = Vector3.ZERO
var _impulse_rotation_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	head = get_node_or_null(head_path) as Node3D
	camera = get_parent() as Camera3D
	left_hand = get_node_or_null(left_hand_path) as Node3D
	right_hand = get_node_or_null(right_hand_path) as Node3D
	_update_surface_query_exclude()

	_base_rotation = _degrees_to_radians(HandFeel.base_rotation_degrees)
	_left_base_rotation = _degrees_to_radians(HandFeel.left_hand_rotation_degrees)
	_right_base_rotation = _degrees_to_radians(HandFeel.right_hand_rotation_degrees)

	position = HandFeel.base_position
	rotation = _base_rotation
	_apply_hand_visual_defaults()
	_apply_viewmodel_render_settings()


func _process(delta: float) -> void:
	if player == null:
		return

	_update_hands_root(delta)
	_update_individual_hands(delta)


func _update_hands_root(delta: float) -> void:
	var horizontal_speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0)
	var target_speed: float = MovementWalk.get_feedback_target_speed(
		_player_float(METHOD_GET_TARGET_SPEED, MovementWalk.walk_speed)
	)
	var speed_ratio: float = clampf(horizontal_speed / target_speed, 0.0, 1.0)
	var move_input: Vector2 = _player_vector2(METHOD_GET_MOVE_INPUT, Vector2.ZERO)
	var look_motion: Vector2 = _get_look_motion()
	var jump_feedback: float = _player_float(METHOD_GET_RECENT_JUMP_FEEDBACK, 0.0)
	var landing_impact: float = _player_float(METHOD_GET_RECENT_LANDING_IMPACT, 0.0)
	var crouch_feedback: float = _player_float(METHOD_GET_RECENT_CROUCH_FEEDBACK, 0.0)
	var climb_feedback: float = _player_float(METHOD_GET_RECENT_CLIMB_FEEDBACK, 0.0)
	var stair_blend: float = _player_float(METHOD_GET_STAIR_BLEND, 0.0)
	var stair_step: float = _player_float(METHOD_GET_RECENT_STAIR_STEP, 0.0)
	var slide_blend: float = _player_float(METHOD_GET_SLIDE_BLEND, 0.0)
	var climb_blend: float = clampf(_player_float(METHOD_GET_CLIMB_BLEND, 0.0), 0.0, 1.0)
	var climb_progress: float = clampf(_player_float(METHOD_GET_CLIMB_PROGRESS, 0.0), 0.0, 1.0)
	var edge_hold_blend: float = clampf(_player_float(METHOD_GET_EDGE_HOLD_BLEND, 0.0), 0.0, 1.0)
	var edge_pull_blend: float = clampf(_player_float(METHOD_GET_EDGE_PULL_OVER_BLEND, 0.0), 0.0, 1.0)
	var edge_pull_progress: float = clampf(_player_float(METHOD_GET_EDGE_PULL_OVER_PROGRESS, 0.0), 0.0, 1.0)
	var edge_pull_strength: float = maxf(_player_float(METHOD_GET_EDGE_PULL_OVER_STRENGTH, 0.0), 0.0)
	var wall_run_blend: float = clampf(_player_float(METHOD_GET_WALL_RUN_BLEND, 0.0), 0.0, 1.0)
	var wall_run_side: int = int(_player_float(METHOD_GET_WALL_RUN_SIDE, 0.0))
	var sprint_blend: float = _get_sprint_blend()
	var surface_pushback: float = _update_surface_pushback(delta)
	var fall_amount: float = _get_fall_amount()
	_update_impulse_feedback(jump_feedback, landing_impact, crouch_feedback, climb_feedback, delta)

	var non_wall_run_blend: float = 1.0 - wall_run_blend
	var climb_state_blend: float = maxf(climb_blend, edge_pull_blend)
	var non_climb_blend: float = 1.0 - climb_state_blend
	var wall_climb_blend: float = climb_blend * (1.0 - edge_hold_blend)
	var ground_move_tuck: float = _get_ground_move_tuck(horizontal_speed, speed_ratio, wall_run_blend, slide_blend, climb_state_blend)
	var climb_look_keep: float = lerpf(1.0, 0.38, climb_state_blend)
	var target_position: Vector3 = HandFeel.base_position
	target_position += _get_state_position_offset(sprint_blend)
	target_position += _get_ground_move_tuck_position(ground_move_tuck, sprint_blend)
	target_position += HandFeel.slide_position_offset * slide_blend * non_wall_run_blend * non_climb_blend
	target_position += _get_wall_run_root_position_offset(wall_run_side, wall_run_blend)
	target_position += ClimbFeel.get_hand_root_position(wall_climb_blend, climb_progress)
	target_position += ClimbFeel.get_edge_hold_hand_root_position(edge_hold_blend)
	target_position += ClimbFeel.get_climb_edge_over_hand_root_position(edge_pull_blend, edge_pull_progress, edge_pull_strength)
	target_position += HandFeel.stair_position_offset * stair_blend
	target_position += HandFeel.surface_pushback_position * surface_pushback * non_climb_blend
	target_position += HandFeel.stair_step_kick_position * stair_step
	target_position += _get_move_sway_position(move_input, speed_ratio) * non_climb_blend
	target_position += _get_look_sway_position(look_motion) * climb_look_keep
	target_position += _get_bob_position(horizontal_speed, speed_ratio, sprint_blend, wall_run_blend, climb_blend, delta)
	target_position += HandFeel.fall_position_offset * fall_amount * (1.0 - wall_run_blend) * non_climb_blend
	target_position += _impulse_position

	var target_rotation: Vector3 = _base_rotation
	target_rotation += _get_state_rotation_offset(sprint_blend)
	target_rotation += _get_ground_move_tuck_rotation(ground_move_tuck, sprint_blend)
	target_rotation += _degrees_to_radians(HandFeel.slide_rotation_degrees) * slide_blend * non_wall_run_blend * non_climb_blend
	target_rotation += _get_wall_run_root_rotation_offset(wall_run_side, wall_run_blend)
	target_rotation += ClimbFeel.get_hand_root_rotation(wall_climb_blend, climb_progress)
	target_rotation += ClimbFeel.get_edge_hold_hand_root_rotation(edge_hold_blend)
	target_rotation += ClimbFeel.get_climb_edge_over_hand_root_rotation(edge_pull_blend, edge_pull_progress, edge_pull_strength)
	target_rotation += _degrees_to_radians(HandFeel.stair_rotation_degrees) * stair_blend
	target_rotation += _degrees_to_radians(HandFeel.surface_pushback_rotation_degrees) * surface_pushback * non_climb_blend
	target_rotation += _degrees_to_radians(HandFeel.stair_step_kick_rotation_degrees) * stair_step
	target_rotation += _get_move_sway_rotation(move_input, speed_ratio) * non_climb_blend
	target_rotation += _get_look_sway_rotation(look_motion) * climb_look_keep
	target_rotation += _degrees_to_radians(HandFeel.fall_rotation_degrees) * fall_amount * (1.0 - wall_run_blend) * non_climb_blend
	target_rotation += _impulse_rotation

	target_position = _apply_position_presence(HandFeel.base_position, target_position)
	target_rotation = _apply_rotation_presence(_base_rotation, target_rotation)

	var position_blend: float = 1.0 - exp(-HandFeel.follow_lerp_speed * delta)
	var rotation_blend: float = 1.0 - exp(-HandFeel.rotation_lerp_speed * delta)
	position = position.lerp(target_position, position_blend)
	rotation = rotation.lerp(target_rotation, rotation_blend)


func _update_impulse_feedback(
	jump_feedback: float,
	landing_impact: float,
	crouch_feedback: float,
	climb_feedback: float,
	delta: float
) -> void:
	var target_position: Vector3 = (
		(HandFeel.jump_kick_position * jump_feedback)
		+ (HandFeel.landing_kick_position * landing_impact)
		+ _get_crouch_kick_position(crouch_feedback)
		+ ClimbFeel.get_hand_catch_position(climb_feedback)
	)
	var target_rotation: Vector3 = (
		(_degrees_to_radians(HandFeel.jump_kick_rotation_degrees) * jump_feedback)
		+ (_degrees_to_radians(HandFeel.landing_kick_rotation_degrees) * landing_impact)
		+ _get_crouch_kick_rotation(crouch_feedback)
		+ ClimbFeel.get_hand_catch_rotation(climb_feedback)
	)

	_impulse_position_velocity += (target_position - _impulse_position) * HandFeel.impulse_spring_stiffness * delta
	_impulse_rotation_velocity += (target_rotation - _impulse_rotation) * HandFeel.impulse_spring_stiffness * delta

	var damping: float = exp(-HandFeel.impulse_spring_damping * delta)
	_impulse_position_velocity *= damping
	_impulse_rotation_velocity *= damping
	_impulse_position += _impulse_position_velocity * delta
	_impulse_rotation += _impulse_rotation_velocity * delta


func _get_crouch_kick_position(crouch_feedback: float) -> Vector3:
	if crouch_feedback > 0.0:
		return HandFeel.crouch_enter_kick_position * crouch_feedback
	if crouch_feedback < 0.0:
		return HandFeel.crouch_exit_kick_position * absf(crouch_feedback)
	return Vector3.ZERO


func _get_crouch_kick_rotation(crouch_feedback: float) -> Vector3:
	if crouch_feedback > 0.0:
		return _degrees_to_radians(HandFeel.crouch_enter_kick_rotation_degrees) * crouch_feedback
	if crouch_feedback < 0.0:
		return _degrees_to_radians(HandFeel.crouch_exit_kick_rotation_degrees) * absf(crouch_feedback)
	return Vector3.ZERO


func _update_individual_hands(delta: float) -> void:
	if left_hand == null or right_hand == null:
		return

	var horizontal_speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0)
	var target_speed: float = MovementWalk.get_feedback_target_speed(
		_player_float(METHOD_GET_TARGET_SPEED, MovementWalk.walk_speed)
	)
	var speed_ratio: float = clampf(horizontal_speed / target_speed, 0.0, 1.0)
	var slide_blend: float = _player_float(METHOD_GET_SLIDE_BLEND, 0.0)
	var climb_blend: float = clampf(_player_float(METHOD_GET_CLIMB_BLEND, 0.0), 0.0, 1.0)
	var climb_progress: float = clampf(_player_float(METHOD_GET_CLIMB_PROGRESS, 0.0), 0.0, 1.0)
	var edge_hold_blend: float = clampf(_player_float(METHOD_GET_EDGE_HOLD_BLEND, 0.0), 0.0, 1.0)
	var edge_hold_side_input: float = clampf(_player_float(METHOD_GET_EDGE_HOLD_SIDE_INPUT, 0.0), -1.0, 1.0)
	var edge_pull_blend: float = clampf(_player_float(METHOD_GET_EDGE_PULL_OVER_BLEND, 0.0), 0.0, 1.0)
	var edge_pull_progress: float = clampf(_player_float(METHOD_GET_EDGE_PULL_OVER_PROGRESS, 0.0), 0.0, 1.0)
	var edge_pull_strength: float = maxf(_player_float(METHOD_GET_EDGE_PULL_OVER_STRENGTH, 0.0), 0.0)
	var wall_run_blend: float = clampf(_player_float(METHOD_GET_WALL_RUN_BLEND, 0.0), 0.0, 1.0)
	var wall_run_side: int = int(_player_float(METHOD_GET_WALL_RUN_SIDE, 0.0))
	var non_wall_run_blend: float = 1.0 - wall_run_blend
	var climb_state_blend: float = maxf(climb_blend, edge_pull_blend)
	var non_climb_blend: float = 1.0 - climb_state_blend
	var wall_climb_blend: float = climb_blend * (1.0 - edge_hold_blend)
	var surface_pushback: float = _surface_pushback
	var hand_blend: float = 1.0 - exp(-HandFeel.hand_lerp_speed * delta)
	var wall_run_alternate_multiplier: float = lerpf(
		1.0,
		maxf(HandFeel.wall_run_hand_alternate_multiplier, 0.0),
		wall_run_blend
	)
	var alternating_offset: float = sin(_bob_phase) * 0.025 * speed_ratio * wall_run_alternate_multiplier
	var hand_roll: float = sin(_bob_phase + PI * 0.5) * 0.04 * speed_ratio
	alternating_offset *= non_climb_blend
	hand_roll *= non_climb_blend
	var left_slide_rotation: Vector3 = _degrees_to_radians(HandFeel.slide_left_hand_rotation_degrees)
	var right_slide_rotation: Vector3 = _degrees_to_radians(HandFeel.slide_right_hand_rotation_degrees)
	var left_surface_rotation: Vector3 = _degrees_to_radians(HandFeel.surface_left_hand_rotation_degrees)
	var right_surface_rotation: Vector3 = _degrees_to_radians(HandFeel.surface_right_hand_rotation_degrees)

	var left_target_position: Vector3 = HandFeel.left_hand_position
	left_target_position += Vector3(0.0, alternating_offset, 0.0)
	left_target_position += HandFeel.slide_left_hand_position_offset * slide_blend * non_wall_run_blend * non_climb_blend
	left_target_position += _get_wall_run_hand_position_offset(-1, wall_run_side, wall_run_blend)
	left_target_position += ClimbFeel.get_left_hand_position(wall_climb_blend, climb_progress)
	left_target_position += ClimbFeel.get_edge_hold_left_hand_position(edge_hold_blend, edge_hold_side_input)
	left_target_position += ClimbFeel.get_climb_edge_over_left_hand_position(edge_pull_blend, edge_pull_progress, edge_pull_strength)
	left_target_position += HandFeel.surface_left_hand_position_offset * surface_pushback * non_climb_blend

	var right_target_position: Vector3 = HandFeel.right_hand_position
	right_target_position += Vector3(0.0, -alternating_offset, 0.0)
	right_target_position += HandFeel.slide_right_hand_position_offset * slide_blend * non_wall_run_blend * non_climb_blend
	right_target_position += _get_wall_run_hand_position_offset(1, wall_run_side, wall_run_blend)
	right_target_position += ClimbFeel.get_right_hand_position(wall_climb_blend, climb_progress)
	right_target_position += ClimbFeel.get_edge_hold_right_hand_position(edge_hold_blend, edge_hold_side_input)
	right_target_position += ClimbFeel.get_climb_edge_over_right_hand_position(edge_pull_blend, edge_pull_progress, edge_pull_strength)
	right_target_position += HandFeel.surface_right_hand_position_offset * surface_pushback * non_climb_blend

	var left_target_rotation: Vector3 = _left_base_rotation
	left_target_rotation += Vector3(0.0, 0.0, -hand_roll)
	left_target_rotation += left_slide_rotation * slide_blend * non_wall_run_blend * non_climb_blend
	left_target_rotation += _get_wall_run_hand_rotation_offset(-1, wall_run_side, wall_run_blend)
	left_target_rotation += ClimbFeel.get_left_hand_rotation(wall_climb_blend, climb_progress)
	left_target_rotation += ClimbFeel.get_edge_hold_left_hand_rotation(edge_hold_blend, edge_hold_side_input)
	left_target_rotation += ClimbFeel.get_climb_edge_over_left_hand_rotation(edge_pull_blend, edge_pull_progress, edge_pull_strength)
	left_target_rotation += left_surface_rotation * surface_pushback * non_climb_blend

	var right_target_rotation: Vector3 = _right_base_rotation
	right_target_rotation += Vector3(0.0, 0.0, hand_roll)
	right_target_rotation += right_slide_rotation * slide_blend * non_wall_run_blend * non_climb_blend
	right_target_rotation += _get_wall_run_hand_rotation_offset(1, wall_run_side, wall_run_blend)
	right_target_rotation += ClimbFeel.get_right_hand_rotation(wall_climb_blend, climb_progress)
	right_target_rotation += ClimbFeel.get_edge_hold_right_hand_rotation(edge_hold_blend, edge_hold_side_input)
	right_target_rotation += ClimbFeel.get_climb_edge_over_right_hand_rotation(edge_pull_blend, edge_pull_progress, edge_pull_strength)
	right_target_rotation += right_surface_rotation * surface_pushback * non_climb_blend

	left_hand.position = left_hand.position.lerp(
		_apply_position_presence(HandFeel.left_hand_position, left_target_position),
		hand_blend
	)
	right_hand.position = right_hand.position.lerp(
		_apply_position_presence(HandFeel.right_hand_position, right_target_position),
		hand_blend
	)

	left_hand.rotation = left_hand.rotation.lerp(
		_apply_rotation_presence(_left_base_rotation, left_target_rotation),
		hand_blend
	)
	right_hand.rotation = right_hand.rotation.lerp(
		_apply_rotation_presence(_right_base_rotation, right_target_rotation),
		hand_blend
	)


func _get_bob_position(
	horizontal_speed: float,
	speed_ratio: float,
	sprint_blend: float,
	wall_run_blend: float,
	climb_blend: float,
	delta: float
) -> Vector3:
	if climb_blend > 0.01:
		_bob_phase = 0.0
		return Vector3.ZERO

	if wall_run_blend > 0.01 and horizontal_speed > 0.2:
		_bob_phase += horizontal_speed * HandFeel.bob_frequency * maxf(HandFeel.wall_run_frequency_multiplier, 0.0) * delta
		var wall_bob_position: Vector3 = HandFeel.wall_run_bob_position * wall_run_blend
		return Vector3(
			cos(_bob_phase * 0.5) * wall_bob_position.x * speed_ratio,
			absf(sin(_bob_phase)) * wall_bob_position.y * speed_ratio,
			cos(_bob_phase) * wall_bob_position.z * speed_ratio
		)

	if not player.is_on_floor() or horizontal_speed <= 0.2:
		_bob_phase = 0.0
		return Vector3.ZERO

	var bob_position: Vector3 = HandFeel.walk_bob_position
	var frequency_multiplier: float = 1.0
	if _player_bool(METHOD_IS_CROUCHING, false):
		bob_position = HandFeel.crouch_bob_position
	elif _player_bool(METHOD_IS_SPRINTING, false):
		bob_position = HandFeel.walk_bob_position.lerp(HandFeel.sprint_bob_position, sprint_blend)
		frequency_multiplier = lerpf(1.0, HandFeel.sprint_frequency_multiplier, sprint_blend)
	if _player_bool(METHOD_IS_SLIDING, false):
		bob_position *= HandFeel.slide_bob_multiplier

	_bob_phase += horizontal_speed * HandFeel.bob_frequency * frequency_multiplier * delta
	return Vector3(
		cos(_bob_phase * 0.5) * bob_position.x * speed_ratio,
		absf(sin(_bob_phase)) * bob_position.y * speed_ratio,
		cos(_bob_phase) * bob_position.z * speed_ratio
	)


func _get_wall_run_root_position_offset(wall_side: int, wall_run_blend: float) -> Vector3:
	if wall_side == 0 or wall_run_blend <= 0.0:
		return Vector3.ZERO

	var side: float = float(wall_side)
	var side_offset: Vector3 = Vector3(-side * HandFeel.wall_run_away_side_offset, 0.0, 0.0)
	return (HandFeel.wall_run_position_offset + side_offset) * wall_run_blend


func _get_wall_run_root_rotation_offset(wall_side: int, wall_run_blend: float) -> Vector3:
	if wall_side == 0 or wall_run_blend <= 0.0:
		return Vector3.ZERO

	var side: float = float(wall_side)
	var root_rotation: Vector3 = _degrees_to_radians(HandFeel.wall_run_rotation_degrees)
	root_rotation.z += -side * deg_to_rad(HandFeel.wall_run_side_roll_degrees)
	return root_rotation * wall_run_blend


func _get_wall_run_hand_position_offset(hand_side: int, wall_side: int, wall_run_blend: float) -> Vector3:
	if wall_side == 0 or wall_run_blend <= 0.0:
		return Vector3.ZERO

	var hand_side_float: float = float(hand_side)
	var is_wall_hand: bool = hand_side == wall_side
	if is_wall_hand:
		var wall_offset: Vector3 = HandFeel.wall_run_wall_hand_position_offset
		wall_offset.x *= hand_side_float
		return wall_offset * wall_run_blend

	var free_offset: Vector3 = HandFeel.wall_run_free_hand_position_offset
	free_offset.x *= -float(wall_side)
	return free_offset * wall_run_blend


func _get_wall_run_hand_rotation_offset(hand_side: int, wall_side: int, wall_run_blend: float) -> Vector3:
	if wall_side == 0 or wall_run_blend <= 0.0:
		return Vector3.ZERO

	var hand_side_float: float = float(hand_side)
	var rotation_degrees: Vector3 = HandFeel.wall_run_free_hand_rotation_degrees
	if hand_side == wall_side:
		rotation_degrees = HandFeel.wall_run_wall_hand_rotation_degrees

	return Vector3(
		deg_to_rad(rotation_degrees.x),
		deg_to_rad(rotation_degrees.y * hand_side_float),
		deg_to_rad(rotation_degrees.z * hand_side_float)
	) * wall_run_blend


func _get_state_position_offset(sprint_blend: float) -> Vector3:
	var offset: Vector3 = Vector3.ZERO
	if _player_bool(METHOD_IS_CROUCHING, false):
		offset += HandFeel.crouch_position_offset
	if _player_bool(METHOD_IS_SPRINTING, false):
		offset += HandFeel.sprint_position_offset * sprint_blend
	return offset


func _get_state_rotation_offset(sprint_blend: float) -> Vector3:
	var offset: Vector3 = Vector3.ZERO
	if _player_bool(METHOD_IS_CROUCHING, false):
		offset += _degrees_to_radians(HandFeel.crouch_rotation_degrees)
	if _player_bool(METHOD_IS_SPRINTING, false):
		offset += _degrees_to_radians(HandFeel.sprint_rotation_degrees) * sprint_blend
	return offset


func _get_ground_move_tuck(
	horizontal_speed: float,
	speed_ratio: float,
	wall_run_blend: float,
	slide_blend: float,
	climb_state_blend: float
) -> float:
	if player == null or not player.is_on_floor():
		return 0.0
	if horizontal_speed <= 0.18:
		return 0.0

	var tuck: float = clampf(speed_ratio, 0.0, 1.0)
	tuck *= 1.0 - clampf(maxf(wall_run_blend, maxf(slide_blend, climb_state_blend)), 0.0, 1.0)
	return tuck


func _get_ground_move_tuck_position(ground_move_tuck: float, sprint_blend: float) -> Vector3:
	var tuck: float = clampf(ground_move_tuck, 0.0, 1.0)
	var sprint_tuck: float = tuck * clampf(sprint_blend, 0.0, 1.0)
	return (HandFeel.ground_move_tuck_position * tuck) + (HandFeel.sprint_tuck_position * sprint_tuck)


func _get_ground_move_tuck_rotation(ground_move_tuck: float, sprint_blend: float) -> Vector3:
	var tuck: float = clampf(ground_move_tuck, 0.0, 1.0)
	var sprint_tuck: float = tuck * clampf(sprint_blend, 0.0, 1.0)
	return (
		(_degrees_to_radians(HandFeel.ground_move_tuck_rotation_degrees) * tuck)
		+ (_degrees_to_radians(HandFeel.sprint_tuck_rotation_degrees) * sprint_tuck)
	)


func _get_move_sway_position(move_input: Vector2, speed_ratio: float) -> Vector3:
	return Vector3(
		-move_input.x * HandFeel.move_sway_position.x,
		absf(move_input.y) * -HandFeel.move_sway_position.y,
		-absf(move_input.y) * HandFeel.move_sway_position.z
	) * speed_ratio


func _get_move_sway_rotation(move_input: Vector2, speed_ratio: float) -> Vector3:
	var sway_rotation: Vector3 = _degrees_to_radians(HandFeel.move_sway_rotation_degrees)
	return Vector3(
		-move_input.y * sway_rotation.x,
		-move_input.x * sway_rotation.y,
		-move_input.x * sway_rotation.z
	) * speed_ratio


func _get_look_sway_position(look_motion: Vector2) -> Vector3:
	return Vector3(
		-look_motion.x * HandFeel.look_sway_position.x,
		look_motion.y * HandFeel.look_sway_position.y,
		0.0
	)


func _get_look_sway_rotation(look_motion: Vector2) -> Vector3:
	var look_rotation: Vector3 = _degrees_to_radians(HandFeel.look_sway_rotation_degrees)
	return Vector3(
		look_motion.y * look_rotation.x,
		look_motion.x * look_rotation.y,
		look_motion.x * look_rotation.z
	)


func _get_look_motion() -> Vector2:
	if head == null or not head.has_method(METHOD_GET_LOOK_MOTION):
		return Vector2.ZERO

	var look_motion: Vector2 = Vector2(head.call(METHOD_GET_LOOK_MOTION))
	look_motion.x = clampf(look_motion.x, -HandFeel.max_look_sway.x, HandFeel.max_look_sway.x)
	look_motion.y = clampf(look_motion.y, -HandFeel.max_look_sway.y, HandFeel.max_look_sway.y)
	return look_motion


func _get_fall_amount() -> float:
	if player.is_on_floor():
		return 0.0

	var vertical_velocity: float = _player_float(METHOD_GET_VERTICAL_VELOCITY, 0.0)
	return clampf(-vertical_velocity / WorldBasicRules.get_terminal_fall_speed(), 0.0, 1.0)


func _get_sprint_blend() -> float:
	if not _player_bool(METHOD_IS_SPRINTING, false):
		return 0.0
	return clampf(_player_float(METHOD_GET_SPRINT_RAMP_BLEND, 1.0), 0.0, 1.0)


func _update_surface_pushback(delta: float) -> float:
	var target_pushback: float = _get_surface_pushback_target()
	var pushback_lerp_speed: float = HandFeel.surface_pushback_lerp_speed
	if target_pushback < _surface_pushback:
		pushback_lerp_speed = HandFeel.surface_return_lerp_speed

	var pushback_blend: float = 1.0 - exp(-maxf(pushback_lerp_speed, 0.001) * delta)
	_surface_pushback = lerpf(_surface_pushback, target_pushback, pushback_blend)
	return _surface_pushback


func _get_surface_pushback_target() -> float:
	if not HandFeel.enable_surface_pushback:
		return 0.0
	if camera == null or player == null:
		return 0.0

	var strongest_pushback: float = 0.0
	var side_offset: float = maxf(HandFeel.surface_side_probe_offset, 0.0)
	var vertical_offset: float = HandFeel.surface_vertical_probe_offset
	var forward_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
	var ground_direction: Vector3 = Vector3(0.0, -maxf(HandFeel.surface_ground_probe_down_bias, 0.0), -1.0).normalized()

	strongest_pushback = maxf(
		strongest_pushback,
		_probe_surface_pushback(Vector3(0.0, vertical_offset, 0.0), forward_direction, HandFeel.surface_probe_distance)
	)
	strongest_pushback = maxf(
		strongest_pushback,
		_probe_surface_pushback(Vector3(-side_offset, vertical_offset, 0.0), forward_direction, HandFeel.surface_probe_distance)
	)
	strongest_pushback = maxf(
		strongest_pushback,
		_probe_surface_pushback(Vector3(side_offset, vertical_offset, 0.0), forward_direction, HandFeel.surface_probe_distance)
	)
	strongest_pushback = maxf(
		strongest_pushback,
		_probe_surface_pushback(Vector3(0.0, vertical_offset, 0.0), ground_direction, HandFeel.surface_ground_probe_distance)
	)
	return strongest_pushback


func _probe_surface_pushback(local_origin: Vector3, local_direction: Vector3, probe_distance: float) -> float:
	var distance: float = maxf(probe_distance, 0.001)
	var ray_origin: Vector3 = _get_camera_local_point(local_origin)
	var ray_direction: Vector3 = _get_camera_local_direction(local_direction)

	_surface_query.from = ray_origin
	_surface_query.to = ray_origin + (ray_direction * distance)
	_surface_query.collision_mask = _get_surface_collision_mask()
	_surface_query.exclude = _surface_query_exclude
	_surface_query.collide_with_areas = false
	_surface_query.collide_with_bodies = true

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space_state.intersect_ray(_surface_query)
	if hit.is_empty():
		return 0.0

	var hit_position: Vector3 = Vector3(hit.get("position", ray_origin))
	var hit_distance: float = ray_origin.distance_to(hit_position)
	var clearance: float = maxf(HandFeel.surface_probe_clearance, 0.0)
	var raw_pushback: float = clampf((distance - hit_distance + clearance) / distance, 0.0, 1.0)
	return pow(raw_pushback, maxf(HandFeel.surface_pushback_curve, 0.001))


func _get_camera_local_point(local_point: Vector3) -> Vector3:
	return camera.global_transform.origin + (camera.global_transform.basis * local_point)


func _get_camera_local_direction(local_direction: Vector3) -> Vector3:
	return (camera.global_transform.basis * local_direction).normalized()


func _get_surface_collision_mask() -> int:
	if HandFeel.surface_use_player_collision_mask and player != null:
		return player.collision_mask
	return HandFeel.surface_collision_mask


func _update_surface_query_exclude() -> void:
	_surface_query_exclude.clear()
	if player != null:
		_surface_query_exclude.append(player.get_rid())


func _apply_hand_visual_defaults() -> void:
	if left_hand != null:
		left_hand.position = HandFeel.left_hand_position
		left_hand.rotation = _left_base_rotation
		left_hand.scale = HandFeel.hand_scale
		left_hand.visible = true

	if right_hand != null:
		right_hand.position = HandFeel.right_hand_position
		right_hand.rotation = _right_base_rotation
		right_hand.scale = HandFeel.hand_scale
		right_hand.visible = true


func _apply_viewmodel_render_settings() -> void:
	_apply_viewmodel_render_settings_to_node(self)


func _apply_viewmodel_render_settings_to_node(node: Node) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		if HandFeel.disable_viewmodel_shadows:
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if HandFeel.ignore_viewmodel_occlusion_culling:
			geometry.ignore_occlusion_culling = true
		if HandFeel.viewmodel_extra_cull_margin > 0.0:
			geometry.extra_cull_margin = maxf(geometry.extra_cull_margin, HandFeel.viewmodel_extra_cull_margin)
		if HandFeel.render_over_world:
			_apply_viewmodel_materials(geometry)

	var child_count: int = node.get_child_count()
	for child_index in range(child_count):
		var child: Node = node.get_child(child_index)
		_apply_viewmodel_render_settings_to_node(child)


func _apply_viewmodel_materials(geometry: GeometryInstance3D) -> void:
	var mesh_instance: MeshInstance3D = geometry as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return

	var surface_count: int = mesh_instance.mesh.get_surface_count()
	for surface_index in range(surface_count):
		var source_material: Material = mesh_instance.get_surface_override_material(surface_index)
		if source_material == null:
			source_material = mesh_instance.mesh.surface_get_material(surface_index)

		mesh_instance.set_surface_override_material(surface_index, _make_viewmodel_material(source_material))


func _make_viewmodel_material(source_material: Material) -> Material:
	var viewmodel_material: Material = StandardMaterial3D.new()
	if source_material != null:
		var duplicated_material: Material = source_material.duplicate() as Material
		if duplicated_material != null:
			viewmodel_material = duplicated_material

	viewmodel_material.resource_local_to_scene = true
	viewmodel_material.render_priority = clampi(
		HandFeel.viewmodel_render_priority,
		Material.RENDER_PRIORITY_MIN,
		Material.RENDER_PRIORITY_MAX
	)

	var base_material: BaseMaterial3D = viewmodel_material as BaseMaterial3D
	if base_material != null:
		base_material.no_depth_test = HandFeel.render_over_world
		base_material.disable_receive_shadows = HandFeel.disable_viewmodel_receive_shadows

	return viewmodel_material


func _apply_position_presence(base_position: Vector3, target_position: Vector3) -> Vector3:
	return base_position + ((target_position - base_position) * _get_motion_presence())


func _apply_rotation_presence(base_rotation: Vector3, target_rotation: Vector3) -> Vector3:
	return base_rotation + ((target_rotation - base_rotation) * _get_motion_presence())


func _get_motion_presence() -> float:
	return clampf(HandFeel.motion_presence_multiplier, 0.0, 1.0)


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees_value.x),
		deg_to_rad(degrees_value.y),
		deg_to_rad(degrees_value.z)
	)


func _player_float(method_name: StringName, fallback: float) -> float:
	if player == null or not player.has_method(method_name):
		return fallback
	return float(player.call(method_name))


func _player_bool(method_name: StringName, fallback: bool) -> bool:
	if player == null or not player.has_method(method_name):
		return fallback
	return bool(player.call(method_name))


func _player_vector2(method_name: StringName, fallback: Vector2) -> Vector2:
	if player == null or not player.has_method(method_name):
		return fallback
	return Vector2(player.call(method_name))
