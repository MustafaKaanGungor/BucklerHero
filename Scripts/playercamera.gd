extends Camera3D

const METHOD_CONSUME_LANDING_IMPACT: StringName = &"consume_landing_impact"
const METHOD_CONSUME_JUMP_FEEDBACK: StringName = &"consume_jump_feedback"
const METHOD_CONSUME_CROUCH_ENTER_FEEDBACK: StringName = &"consume_crouch_enter_feedback"
const METHOD_CONSUME_CROUCH_EXIT_FEEDBACK: StringName = &"consume_crouch_exit_feedback"
const METHOD_CONSUME_CLIMB_FEEDBACK: StringName = &"consume_climb_feedback"
const METHOD_CONSUME_STAIR_STEP_FEEDBACK: StringName = &"consume_stair_step_feedback"
const METHOD_CONSUME_WALL_JUMP_FEEDBACK: StringName = &"consume_wall_jump_feedback"
const METHOD_GET_HORIZONTAL_SPEED: StringName = &"get_horizontal_speed"
const METHOD_GET_MOVE_INPUT: StringName = &"get_move_input"
const METHOD_GET_TARGET_SPEED: StringName = &"get_target_speed"
const METHOD_GET_STAIR_BLEND: StringName = &"get_stair_blend"
const METHOD_GET_SLIDE_BLEND: StringName = &"get_slide_blend"
const METHOD_GET_SLIDE_SPEED: StringName = &"get_slide_speed"
const METHOD_GET_CLIMB_BLEND: StringName = &"get_climb_blend"
const METHOD_GET_CLIMB_PROGRESS: StringName = &"get_climb_progress"
const METHOD_GET_EDGE_HOLD_BLEND: StringName = &"get_edge_hold_blend"
const METHOD_GET_EDGE_PULL_OVER_BLEND: StringName = &"get_edge_pull_over_blend"
const METHOD_GET_EDGE_PULL_OVER_TIMER: StringName = &"get_edge_pull_over_timer"
const METHOD_GET_EDGE_PULL_OVER_DURATION: StringName = &"get_edge_pull_over_duration"
const METHOD_GET_EDGE_PULL_OVER_STRENGTH: StringName = &"get_edge_pull_over_strength"
const METHOD_GET_WALL_RUN_BLEND: StringName = &"get_wall_run_blend"
const METHOD_GET_WALL_RUN_SIDE: StringName = &"get_wall_run_side"
const METHOD_GET_SPRINT_RAMP_BLEND: StringName = &"get_sprint_ramp_blend"
const METHOD_GET_LOOK_MOTION: StringName = &"get_look_motion"
const METHOD_IS_CROUCHING: StringName = &"is_crouching"
const METHOD_IS_SPRINTING: StringName = &"is_sprinting"

@export var player_path: NodePath = NodePath("../..")

var player: CharacterBody3D
var head: Node3D
var _bob_phase: float = 0.0
var _base_local_position: Vector3 = Vector3.ZERO
var _look_motion: Vector2 = Vector2.ZERO
var _turn_strafe_input: float = 0.0
var _camera_feel_position: Vector3 = Vector3.ZERO
var _camera_feel_rotation: Vector3 = Vector3.ZERO
var _target_roll: float = 0.0
var _vertical_offset: float = 0.0
var _vertical_velocity: float = 0.0
var _landing_offset: float = 0.0
var _landing_velocity: float = 0.0
var _landing_side_offset: float = 0.0
var _landing_side_velocity: float = 0.0
var _landing_roll: float = 0.0
var _landing_roll_velocity: float = 0.0
var _landing_pitch: float = 0.0
var _landing_pitch_velocity: float = 0.0
var _second_leg_timer: float = 0.0
var _second_leg_strength: float = 0.0
var _second_leg_side: float = 1.0
var _previous_horizontal_speed: float = 0.0
var _walk_stop_dip: float = 0.0
var _slide_shake_phase: float = 0.0
var _crouch_position_offset: Vector3 = Vector3.ZERO
var _crouch_position_velocity: Vector3 = Vector3.ZERO
var _crouch_rotation_offset: Vector3 = Vector3.ZERO
var _crouch_rotation_velocity: Vector3 = Vector3.ZERO
var _shake_amount: float = 0.0
var _shake_time: float = 0.0
var _shake_position: Vector3 = Vector3.ZERO
var _shake_rotation: Vector3 = Vector3.ZERO
var _shake_noise: FastNoiseLite = FastNoiseLite.new()


func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	head = get_parent() as Node3D
	_base_local_position = position
	current = true
	fov = CameraFeel.base_fov
	# One noise unit per shake step; the default frequency is far too slow for a jitter.
	_shake_noise.frequency = 1.0
	_shake_noise.seed = randi()
	HealthManager.damaged.connect(_on_player_damaged)
	HealthManager.blocked.connect(_on_player_blocked)


## A smaller jolt when the braced shield stops a hit.
func _on_player_blocked(amount: float) -> void:
	var kick_strength: float = HealthManager.get_camera_kick_strength(amount) * HealthManager.block_camera_kick_multiplier
	add_recoil_impulse(Vector3.ZERO, _degrees_to_radians(HealthManager.damage_camera_kick_degrees) * kick_strength)
	add_screen_shake(HealthManager.damage_screen_shake * kick_strength)


## Flinch when the player gets hit. Reuses the recoil spring, so the view settles back by itself.
func _on_player_damaged(amount: float) -> void:
	var kick_strength: float = HealthManager.get_camera_kick_strength(amount)
	add_recoil_impulse(Vector3.ZERO, _degrees_to_radians(HealthManager.damage_camera_kick_degrees) * kick_strength)
	add_screen_shake(HealthManager.damage_screen_shake * kick_strength)


func _process(delta: float) -> void:
	if player == null:
		return

	# Last frame's shake is taken off first, so the smoothed feel offsets never pick it up.
	position -= _shake_position
	rotation -= _shake_rotation

	_look_motion = _get_look_motion()
	_update_turn_strafe_input(delta)
	_consume_movement_feedback()
	_update_vertical_feedback(delta)
	_update_landing_feedback(delta)
	_update_crouch_feedback(delta)
	_update_directional_camera_feel(delta)
	_update_bob(delta)
	_update_roll(delta)
	_update_fov(delta)
	_update_screen_shake(delta)


## Shakes the camera. amount runs 0-1 and adds to any shake already running; it wears off by itself.
func add_screen_shake(amount: float) -> void:
	_shake_amount = clampf(_shake_amount + maxf(amount, 0.0), 0.0, 1.0)


## Noise-driven jitter on top of every other camera offset, applied last and removed next frame.
func _update_screen_shake(delta: float) -> void:
	_shake_position = Vector3.ZERO
	_shake_rotation = Vector3.ZERO
	if _shake_amount <= 0.0:
		return

	_shake_time += delta * maxf(CameraFeel.shake_frequency, 0.0)
	# Noise mostly stays within about -0.5..0.5, so it is doubled to reach the configured maximums.
	var strength: float = pow(_shake_amount, maxf(CameraFeel.shake_strength_curve, 0.001)) * 2.0
	_shake_position = Vector3(
		_shake_noise.get_noise_2d(_shake_time, 0.0) * CameraFeel.shake_max_position.x,
		_shake_noise.get_noise_2d(_shake_time, 40.0) * CameraFeel.shake_max_position.y,
		_shake_noise.get_noise_2d(_shake_time, 80.0) * CameraFeel.shake_max_position.z
	) * strength
	_shake_rotation = Vector3(
		_shake_noise.get_noise_2d(_shake_time, 120.0) * deg_to_rad(CameraFeel.shake_max_rotation_degrees.x),
		_shake_noise.get_noise_2d(_shake_time, 160.0) * deg_to_rad(CameraFeel.shake_max_rotation_degrees.y),
		_shake_noise.get_noise_2d(_shake_time, 200.0) * deg_to_rad(CameraFeel.shake_max_rotation_degrees.z)
	) * strength
	position += _shake_position
	rotation += _shake_rotation
	_shake_amount = maxf(_shake_amount - (maxf(CameraFeel.shake_decay_per_second, 0.0) * delta), 0.0)


func _consume_movement_feedback() -> void:
	var landing_impact: float = _player_float(METHOD_CONSUME_LANDING_IMPACT, 0.0)
	if landing_impact > 0.0:
		_start_landing_feedback(landing_impact)

	var jump_feedback: float = _player_float(METHOD_CONSUME_JUMP_FEEDBACK, 0.0)
	if jump_feedback > 0.0:
		_vertical_velocity += JumpFeel.jump_lift_velocity * jump_feedback
		_camera_feel_position += JumpFeel.get_camera_position_impulse(jump_feedback)
		_camera_feel_rotation += JumpFeel.get_camera_rotation_impulse(jump_feedback)

	var crouch_enter_feedback: float = _player_float(METHOD_CONSUME_CROUCH_ENTER_FEEDBACK, 0.0)
	if crouch_enter_feedback > 0.0:
		_apply_crouch_camera_impulse(
			CrouchFeel.get_enter_camera_position_impulse(crouch_enter_feedback),
			CrouchFeel.get_enter_camera_rotation_impulse(crouch_enter_feedback)
		)

	var crouch_exit_feedback: float = _player_float(METHOD_CONSUME_CROUCH_EXIT_FEEDBACK, 0.0)
	if crouch_exit_feedback > 0.0:
		_apply_crouch_camera_impulse(
			CrouchFeel.get_exit_camera_position_impulse(crouch_exit_feedback),
			CrouchFeel.get_exit_camera_rotation_impulse(crouch_exit_feedback)
		)

	var climb_feedback: float = _player_float(METHOD_CONSUME_CLIMB_FEEDBACK, 0.0)
	if climb_feedback > 0.0:
		_camera_feel_position += ClimbFeel.get_start_camera_position_impulse(climb_feedback)
		_camera_feel_rotation += ClimbFeel.get_start_camera_rotation_impulse(climb_feedback)
		_vertical_velocity += ClimbFeel.get_start_lift_velocity(climb_feedback)

	var stair_step_feedback: float = _player_float(METHOD_CONSUME_STAIR_STEP_FEEDBACK, 0.0)
	if stair_step_feedback > 0.0:
		_vertical_offset -= StairFeel.stair_camera_step_amount * stair_step_feedback
		_vertical_velocity += StairFeel.stair_camera_rebound_velocity * stair_step_feedback

	var wall_jump_feedback: float = _player_float(METHOD_CONSUME_WALL_JUMP_FEEDBACK, 0.0)
	if wall_jump_feedback != 0.0:
		var wall_jump_side: int = 1
		if wall_jump_feedback < 0.0:
			wall_jump_side = -1
		var wall_jump_impulse: Vector3 = WallRunFeel.get_wall_jump_camera_impulse(wall_jump_side, absf(wall_jump_feedback))
		_camera_feel_position.x += wall_jump_impulse.x
		_camera_feel_position.z += wall_jump_impulse.z
		_vertical_velocity += wall_jump_impulse.y


func _update_vertical_feedback(delta: float) -> void:
	_vertical_velocity += -_vertical_offset * CameraFeel.vertical_feedback_stiffness * delta
	_vertical_velocity *= exp(-CameraFeel.vertical_feedback_damping * delta)
	_vertical_offset += _vertical_velocity * delta

	if absf(_vertical_offset) < 0.0001 and absf(_vertical_velocity) < 0.0001:
		_vertical_offset = 0.0
		_vertical_velocity = 0.0


## Weapon recoil kick. Reuses the crouch camera spring, so the view springs back afterwards.
func add_recoil_impulse(position_impulse: Vector3, rotation_impulse: Vector3) -> void:
	_apply_crouch_camera_impulse(position_impulse, rotation_impulse)


func _apply_crouch_camera_impulse(position_impulse: Vector3, rotation_impulse: Vector3) -> void:
	_crouch_position_offset += position_impulse
	_crouch_rotation_offset += rotation_impulse


func _update_crouch_feedback(delta: float) -> void:
	_crouch_position_velocity += -_crouch_position_offset * CrouchFeel.crouch_camera_spring_stiffness * delta
	_crouch_rotation_velocity += -_crouch_rotation_offset * CrouchFeel.crouch_camera_spring_stiffness * delta

	var damping: float = exp(-CrouchFeel.crouch_camera_spring_damping * delta)
	_crouch_position_velocity *= damping
	_crouch_rotation_velocity *= damping
	_crouch_position_offset += _crouch_position_velocity * delta
	_crouch_rotation_offset += _crouch_rotation_velocity * delta

	if _crouch_feedback_is_resting():
		_crouch_position_offset = Vector3.ZERO
		_crouch_position_velocity = Vector3.ZERO
		_crouch_rotation_offset = Vector3.ZERO
		_crouch_rotation_velocity = Vector3.ZERO


func _crouch_feedback_is_resting() -> bool:
	if _crouch_position_offset.length_squared() >= 0.000001:
		return false
	if _crouch_position_velocity.length_squared() >= 0.000001:
		return false
	if _crouch_rotation_offset.length_squared() >= 0.000001:
		return false
	return _crouch_rotation_velocity.length_squared() < 0.000001


func _start_landing_feedback(landing_impact: float) -> void:
	var impact: float = minf(maxf(landing_impact, 0.0), maxf(LandingFeel.max_landing_impact, 0.0))
	var landing_side: float = _get_landing_side()
	_apply_landing_impulse(
		impact,
		landing_side,
		LandingFeel.first_leg_dip_amount,
		LandingFeel.first_leg_rebound_velocity,
		LandingFeel.first_leg_side_offset,
		LandingFeel.first_leg_roll_degrees,
		LandingFeel.first_leg_pitch_degrees
	)

	_second_leg_timer = maxf(LandingFeel.second_leg_delay, 0.0)
	_second_leg_strength = impact * clampf(LandingFeel.second_leg_strength, 0.0, 1.0)
	_second_leg_side = -landing_side
	if _second_leg_timer <= 0.0:
		_apply_second_leg_landing()


func _update_landing_feedback(delta: float) -> void:
	if _second_leg_timer > 0.0:
		_second_leg_timer = maxf(_second_leg_timer - delta, 0.0)
		if _second_leg_timer <= 0.0:
			_apply_second_leg_landing()

	_landing_velocity += -_landing_offset * LandingFeel.vertical_stiffness * delta
	_landing_velocity *= exp(-LandingFeel.vertical_damping * delta)
	_landing_offset += _landing_velocity * delta

	_landing_side_velocity += -_landing_side_offset * LandingFeel.side_stiffness * delta
	_landing_side_velocity *= exp(-LandingFeel.side_damping * delta)
	_landing_side_offset += _landing_side_velocity * delta

	_landing_roll_velocity += -_landing_roll * LandingFeel.roll_stiffness * delta
	_landing_roll_velocity *= exp(-LandingFeel.roll_damping * delta)
	_landing_roll += _landing_roll_velocity * delta

	_landing_pitch_velocity += -_landing_pitch * LandingFeel.pitch_stiffness * delta
	_landing_pitch_velocity *= exp(-LandingFeel.pitch_damping * delta)
	_landing_pitch += _landing_pitch_velocity * delta

	if _landing_feedback_is_resting():
		_landing_offset = 0.0
		_landing_velocity = 0.0
		_landing_side_offset = 0.0
		_landing_side_velocity = 0.0
		_landing_roll = 0.0
		_landing_roll_velocity = 0.0
		_landing_pitch = 0.0
		_landing_pitch_velocity = 0.0


func _apply_second_leg_landing() -> void:
	if _second_leg_strength <= 0.0:
		return

	_apply_landing_impulse(
		_second_leg_strength,
		_second_leg_side,
		LandingFeel.second_leg_dip_amount,
		LandingFeel.second_leg_rebound_velocity,
		LandingFeel.second_leg_side_offset,
		LandingFeel.second_leg_roll_degrees,
		LandingFeel.second_leg_pitch_degrees
	)
	_second_leg_strength = 0.0


func _apply_landing_impulse(
	impact: float,
	side: float,
	dip_amount: float,
	rebound_velocity: float,
	side_offset: float,
	roll_degrees: float,
	pitch_degrees: float
) -> void:
	_landing_offset -= dip_amount * impact
	_landing_velocity += rebound_velocity * impact
	_landing_side_offset += side_offset * impact * side
	_landing_roll += deg_to_rad(roll_degrees) * impact * side
	if LandingFeel.enable_pitch_jolt:
		_landing_pitch += deg_to_rad(pitch_degrees) * impact


func _get_landing_side() -> float:
	if sin(_bob_phase) < 0.0:
		return -1.0
	return 1.0


func _landing_feedback_is_resting() -> bool:
	if _second_leg_timer > 0.0 or _second_leg_strength > 0.0:
		return false
	if absf(_landing_offset) >= 0.0001 or absf(_landing_velocity) >= 0.0001:
		return false
	if absf(_landing_side_offset) >= 0.0001 or absf(_landing_side_velocity) >= 0.0001:
		return false
	if absf(_landing_roll) >= 0.0001 or absf(_landing_roll_velocity) >= 0.0001:
		return false

	return absf(_landing_pitch) < 0.0001 and absf(_landing_pitch_velocity) < 0.0001


func _update_bob(delta: float) -> void:
	var horizontal_speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0)
	var raw_target_speed: float = _player_float(METHOD_GET_TARGET_SPEED, MovementWalk.walk_speed)
	var target_speed: float = MovementWalk.get_feedback_target_speed(raw_target_speed)
	var speed_ratio: float = 0.0
	speed_ratio = clampf(horizontal_speed / target_speed, 0.0, 1.0)
	var move_input: Vector2 = _player_vector2(METHOD_GET_MOVE_INPUT, Vector2.ZERO)
	var has_move_input: bool = MovementWalk.get_input_strength(move_input) > 0.0
	var stair_blend: float = _player_float(METHOD_GET_STAIR_BLEND, 0.0)
	var slide_blend: float = _player_float(METHOD_GET_SLIDE_BLEND, 0.0)
	var sprint_blend: float = _get_sprint_blend()
	var is_crouching: bool = _player_bool(METHOD_IS_CROUCHING, false)
	var is_sprinting: bool = _player_bool(METHOD_IS_SPRINTING, false)
	var step_strength: float = WalkFeel.get_step_strength(speed_ratio, is_crouching, is_sprinting, slide_blend)
	_walk_stop_dip = WalkFeel.get_stop_dip(
		_walk_stop_dip,
		_previous_horizontal_speed,
		horizontal_speed,
		has_move_input,
		delta
	)
	_previous_horizontal_speed = horizontal_speed

	var bob_amount: float = WalkFeel.walk_bob_amount
	var bob_side_multiplier: float = 1.0
	var bob_forward_multiplier: float = 1.0
	var frequency_multiplier: float = 1.0
	if is_crouching:
		bob_amount = CrouchFeel.crouch_bob_amount
		bob_side_multiplier = CrouchFeel.crouch_bob_side_multiplier
		bob_forward_multiplier = CrouchFeel.crouch_bob_forward_multiplier
		frequency_multiplier = CrouchFeel.crouch_bob_frequency_multiplier
	elif is_sprinting:
		bob_amount = lerpf(WalkFeel.walk_bob_amount, SprintFeel.sprint_bob_amount, sprint_blend)
		frequency_multiplier = lerpf(1.0, SprintFeel.sprint_bob_frequency_multiplier, sprint_blend)
	bob_amount = lerpf(bob_amount, bob_amount * StairFeel.stair_bob_amount_multiplier, stair_blend)

	var bob_position: Vector3 = Vector3.ZERO
	if player.is_on_floor() and horizontal_speed > 0.2:
		_bob_phase += horizontal_speed * WalkFeel.head_bob_frequency * frequency_multiplier * delta
		bob_position.x = cos(_bob_phase * 0.5) * WalkFeel.bob_side_amount * bob_side_multiplier * speed_ratio
		bob_position.y = absf(sin(_bob_phase)) * bob_amount * speed_ratio
		bob_position.y -= WalkFeel.get_step_impact(_bob_phase, step_strength)
		if is_crouching:
			bob_position.y -= CrouchFeel.get_crouch_step_dip(_bob_phase, speed_ratio)
		bob_position.z = cos(_bob_phase) * WalkFeel.bob_forward_amount * bob_forward_multiplier * speed_ratio
		bob_position.z += WalkFeel.get_step_forward_impact(_bob_phase, step_strength)
		if is_crouching:
			bob_position.z += CrouchFeel.get_crouch_step_forward(_bob_phase, speed_ratio)
		bob_position.z += StairFeel.stair_camera_forward_amount * stair_blend
	else:
		_bob_phase = 0.0

	var feedback_blend: float = _get_feedback_blend(delta)
	position = position.lerp(
		_base_local_position
			+ bob_position
			+ Vector3(_landing_side_offset, _vertical_offset + _landing_offset - _walk_stop_dip, 0.0)
			+ _camera_feel_position
			+ _crouch_position_offset,
		feedback_blend
	)


func _update_roll(delta: float) -> void:
	var move_input: Vector2 = _player_vector2(METHOD_GET_MOVE_INPUT, Vector2.ZERO)
	var horizontal_speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0)
	var raw_target_speed: float = _player_float(METHOD_GET_TARGET_SPEED, MovementWalk.walk_speed)
	var target_speed: float = MovementWalk.get_feedback_target_speed(raw_target_speed)
	var speed_ratio: float = clampf(horizontal_speed / target_speed, 0.0, 1.0)
	var yaw_basis: Basis = Basis(Vector3.UP, player.rotation.y)
	var local_velocity: Vector3 = yaw_basis.inverse() * player.velocity
	var velocity_side_ratio: float = 0.0
	if MovementRun.sprint_speed > 0.0:
		velocity_side_ratio = clampf(local_velocity.x / MovementRun.sprint_speed, -1.0, 1.0)

	var sprint_blend: float = _get_sprint_blend()
	var slide_blend: float = _player_float(METHOD_GET_SLIDE_BLEND, 0.0)
	var wall_run_blend: float = _player_float(METHOD_GET_WALL_RUN_BLEND, 0.0)
	var climb_blend: float = _player_float(METHOD_GET_CLIMB_BLEND, 0.0)
	var edge_hold_blend: float = _player_float(METHOD_GET_EDGE_HOLD_BLEND, 0.0)
	var edge_pull_blend: float = _player_float(METHOD_GET_EDGE_PULL_OVER_BLEND, 0.0)
	var climb_state_blend: float = maxf(climb_blend, edge_hold_blend)
	var wall_turn_keep: float = WallRunFeel.get_turn_effect_keep(wall_run_blend)
	wall_turn_keep *= ClimbFeel.get_turn_effect_keep(climb_state_blend)
	wall_turn_keep *= ClimbFeel.get_turn_effect_keep(edge_pull_blend)
	var is_crouching: bool = _player_bool(METHOD_IS_CROUCHING, false)
	var is_sprinting: bool = _player_bool(METHOD_IS_SPRINTING, false)
	var step_strength: float = WalkFeel.get_step_strength(speed_ratio, is_crouching, is_sprinting, slide_blend)
	var roll_multiplier: float = lerpf(1.0, SprintFeel.sprint_roll_multiplier, sprint_blend)
	var camera_strafe_input: float = CameraFeel.get_combined_strafe_input(move_input.x, _turn_strafe_input)
	var input_roll: float = -camera_strafe_input * CameraFeel.roll_amount * roll_multiplier
	var velocity_roll: float = -velocity_side_ratio * CameraFeel.velocity_roll_amount
	var look_roll: float = clampf(
		-_look_motion.x * CameraFeel.look_roll_amount,
		-CameraFeel.max_look_roll,
		CameraFeel.max_look_roll
	)
	look_roll *= lerpf(1.0, SlideFeel.slide_look_roll_multiplier, slide_blend)

	var stair_blend: float = _player_float(METHOD_GET_STAIR_BLEND, 0.0)
	var walk_step_roll: float = WalkFeel.get_step_roll(_bob_phase, step_strength)
	var crouch_step_roll: float = 0.0
	if is_crouching:
		crouch_step_roll = CrouchFeel.get_crouch_step_roll(_bob_phase, speed_ratio)
	var stair_roll: float = sin(_bob_phase) * StairFeel.stair_roll_amount * stair_blend
	_target_roll = input_roll + velocity_roll + look_roll + walk_step_roll + crouch_step_roll + stair_roll
	_target_roll *= wall_turn_keep

	var feedback_blend: float = _get_feedback_blend(delta)
	rotation.x = lerpf(rotation.x, _camera_feel_rotation.x + _landing_pitch + _crouch_rotation_offset.x, feedback_blend)
	rotation.y = lerpf(rotation.y, _camera_feel_rotation.y + _crouch_rotation_offset.y, feedback_blend)
	rotation.z = lerpf(
		rotation.z,
		_target_roll + _camera_feel_rotation.z + _landing_roll + _crouch_rotation_offset.z,
		feedback_blend
	)


func _update_fov(delta: float) -> void:
	var target_fov: float = CameraFeel.base_fov
	var horizontal_speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0)
	var slide_blend: float = _player_float(METHOD_GET_SLIDE_BLEND, 0.0)
	var slide_speed: float = _player_float(METHOD_GET_SLIDE_SPEED, 0.0)
	var wall_run_blend: float = _player_float(METHOD_GET_WALL_RUN_BLEND, 0.0)
	var climb_blend: float = _player_float(METHOD_GET_CLIMB_BLEND, 0.0)
	var climb_progress: float = _player_float(METHOD_GET_CLIMB_PROGRESS, 0.0)
	var edge_hold_blend: float = _player_float(METHOD_GET_EDGE_HOLD_BLEND, 0.0)
	var edge_pull_blend: float = _player_float(METHOD_GET_EDGE_PULL_OVER_BLEND, 0.0)
	var edge_pull_timer: float = _player_float(METHOD_GET_EDGE_PULL_OVER_TIMER, 0.0)
	var edge_pull_duration: float = _player_float(METHOD_GET_EDGE_PULL_OVER_DURATION, 0.0)
	var edge_pull_strength: float = _player_float(METHOD_GET_EDGE_PULL_OVER_STRENGTH, 0.0)
	var wall_climb_blend: float = clampf(climb_blend, 0.0, 1.0) * (1.0 - clampf(edge_hold_blend, 0.0, 1.0))
	var speed_ratio: float = 0.0
	if MovementRun.sprint_speed > 0.0:
		speed_ratio = clampf(horizontal_speed / MovementRun.sprint_speed, 0.0, 1.0)

	target_fov += CameraFeel.get_speed_fov_bonus(speed_ratio)
	target_fov += SprintFeel.sprint_fov_bonus * _get_sprint_blend()
	target_fov += SlideFeel.get_fov_bonus(slide_blend, slide_speed, MovementSlide.get_slide_max_speed())
	target_fov += WallRunFeel.wall_run_fov_bonus * wall_run_blend
	target_fov += ClimbFeel.get_fov_bonus(wall_climb_blend, climb_progress)
	target_fov += ClimbFeel.get_edge_hold_fov_bonus(edge_hold_blend)
	target_fov += ClimbFeel.get_climb_edge_over_fov_bonus(edge_pull_timer, edge_pull_duration, edge_pull_strength) * edge_pull_blend
	target_fov = CameraFeel.get_clamped_fov(target_fov)

	var fov_blend: float = 1.0 - exp(-CameraFeel.fov_lerp_speed * delta)
	fov = lerpf(fov, target_fov, fov_blend)


func _get_feedback_blend(delta: float) -> float:
	return CameraFeel.get_feedback_blend(delta)


func _update_turn_strafe_input(delta: float) -> void:
	var target_turn_strafe: float = CameraFeel.get_turn_strafe_target(_look_motion)
	var turn_blend: float = CameraFeel.get_turn_strafe_blend(delta, _turn_strafe_input, target_turn_strafe)
	_turn_strafe_input = lerpf(_turn_strafe_input, target_turn_strafe, turn_blend)
	if absf(_turn_strafe_input) < 0.001:
		_turn_strafe_input = 0.0


func _update_directional_camera_feel(delta: float) -> void:
	var move_input: Vector2 = _player_vector2(METHOD_GET_MOVE_INPUT, Vector2.ZERO)
	var slide_blend: float = _player_float(METHOD_GET_SLIDE_BLEND, 0.0)
	var slide_speed: float = _player_float(METHOD_GET_SLIDE_SPEED, 0.0)
	var slide_ground_strength: float = MovementSlide.get_active_slide_ground_strength(slide_speed)
	var wall_run_blend: float = _player_float(METHOD_GET_WALL_RUN_BLEND, 0.0)
	var wall_run_side: int = int(_player_float(METHOD_GET_WALL_RUN_SIDE, 0.0))
	var climb_blend: float = _player_float(METHOD_GET_CLIMB_BLEND, 0.0)
	var climb_progress: float = _player_float(METHOD_GET_CLIMB_PROGRESS, 0.0)
	var edge_hold_blend: float = _player_float(METHOD_GET_EDGE_HOLD_BLEND, 0.0)
	var edge_pull_blend: float = _player_float(METHOD_GET_EDGE_PULL_OVER_BLEND, 0.0)
	var edge_pull_timer: float = _player_float(METHOD_GET_EDGE_PULL_OVER_TIMER, 0.0)
	var edge_pull_duration: float = _player_float(METHOD_GET_EDGE_PULL_OVER_DURATION, 0.0)
	var edge_pull_strength: float = _player_float(METHOD_GET_EDGE_PULL_OVER_STRENGTH, 0.0)
	var clean_edge_hold_blend: float = clampf(edge_hold_blend, 0.0, 1.0)
	var climb_state_blend: float = maxf(climb_blend, clean_edge_hold_blend)
	var wall_climb_blend: float = clampf(climb_blend, 0.0, 1.0) * (1.0 - clean_edge_hold_blend)
	var state_turn_keep: float = WallRunFeel.get_turn_effect_keep(wall_run_blend)
	state_turn_keep *= ClimbFeel.get_turn_effect_keep(climb_state_blend)
	state_turn_keep *= ClimbFeel.get_turn_effect_keep(edge_pull_blend)
	_update_slide_shake_phase(slide_blend, slide_speed, slide_ground_strength, delta)

	var target_position: Vector3 = CameraFeel.get_turn_position(_look_motion)
	target_position += CameraFeel.get_turn_strafe_position(_turn_strafe_input)
	target_position += _get_slide_camera_position(move_input, slide_blend, slide_speed, slide_ground_strength)
	target_position *= state_turn_keep
	target_position += WallRunFeel.get_camera_position(wall_run_side, wall_run_blend, move_input, _turn_strafe_input)
	target_position += ClimbFeel.get_camera_position(wall_climb_blend, climb_progress)
	target_position += ClimbFeel.get_edge_hold_camera_position(clean_edge_hold_blend)
	target_position += ClimbFeel.get_climb_edge_over_camera_position(edge_pull_timer, edge_pull_duration, edge_pull_strength) * edge_pull_blend

	var target_rotation: Vector3 = CameraFeel.get_turn_rotation(_look_motion)
	target_rotation += CameraFeel.get_turn_strafe_rotation(_turn_strafe_input)
	target_rotation += _get_slide_camera_rotation(move_input, slide_blend, slide_speed, slide_ground_strength)
	target_rotation *= state_turn_keep
	target_rotation += WallRunFeel.get_camera_rotation(
		wall_run_side,
		wall_run_blend,
		move_input,
		_turn_strafe_input,
		_look_motion
	)
	target_rotation += ClimbFeel.get_camera_rotation(wall_climb_blend, climb_progress)
	target_rotation += ClimbFeel.get_edge_hold_camera_rotation(clean_edge_hold_blend)
	target_rotation += ClimbFeel.get_climb_edge_over_camera_rotation(edge_pull_timer, edge_pull_duration, edge_pull_strength) * edge_pull_blend

	var minimum_lerp_speed: float = 0.0
	if slide_blend > 0.01:
		minimum_lerp_speed = SlideFeel.slide_camera_lerp_speed
	if wall_run_blend > 0.01:
		minimum_lerp_speed = maxf(minimum_lerp_speed, WallRunFeel.wall_run_camera_lerp_speed)
	if climb_blend > 0.01:
		minimum_lerp_speed = maxf(minimum_lerp_speed, ClimbFeel.climb_camera_lerp_speed)
	if clean_edge_hold_blend > 0.01:
		minimum_lerp_speed = maxf(minimum_lerp_speed, ClimbFeel.edge_hold_camera_lerp_speed)
	if edge_pull_blend > 0.01:
		minimum_lerp_speed = maxf(minimum_lerp_speed, ClimbFeel.climb_edge_over_camera_lerp_speed)

	var feel_blend: float = CameraFeel.get_turn_blend(delta, minimum_lerp_speed)
	_camera_feel_position = _camera_feel_position.lerp(target_position, feel_blend)
	_camera_feel_rotation = _camera_feel_rotation.lerp(target_rotation, feel_blend)


func _update_slide_shake_phase(
	slide_blend: float,
	slide_speed: float,
	slide_ground_strength: float,
	delta: float
) -> void:
	if slide_blend <= 0.001 or slide_speed <= 0.001:
		_slide_shake_phase = 0.0
		return

	var phase_speed: float = SlideFeel.get_shake_phase_speed(
		slide_speed,
		MovementSlide.get_slide_max_speed(),
		slide_ground_strength
	)
	_slide_shake_phase = fmod(_slide_shake_phase + (phase_speed * delta), TAU)


func _get_slide_camera_position(
	move_input: Vector2,
	slide_blend: float,
	slide_speed: float,
	slide_ground_strength: float
) -> Vector3:
	if slide_blend <= 0.0:
		return Vector3.ZERO

	return SlideFeel.get_camera_position(
		move_input,
		slide_blend,
		slide_speed,
		MovementSlide.get_slide_max_speed(),
		_slide_shake_phase,
		slide_ground_strength
	)


func _get_slide_camera_rotation(
	move_input: Vector2,
	slide_blend: float,
	slide_speed: float,
	slide_ground_strength: float
) -> Vector3:
	if slide_blend <= 0.0:
		return Vector3.ZERO

	return SlideFeel.get_camera_rotation(
		move_input,
		slide_blend,
		slide_speed,
		MovementSlide.get_slide_max_speed(),
		_slide_shake_phase,
		slide_ground_strength
	)


func _get_look_motion() -> Vector2:
	if head == null or not head.has_method(METHOD_GET_LOOK_MOTION):
		return Vector2.ZERO
	return Vector2(head.call(METHOD_GET_LOOK_MOTION))


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees_value.x),
		deg_to_rad(degrees_value.y),
		deg_to_rad(degrees_value.z)
	)


func _get_sprint_blend() -> float:
	if not _player_bool(METHOD_IS_SPRINTING, false):
		return 0.0
	return clampf(_player_float(METHOD_GET_SPRINT_RAMP_BLEND, 1.0), 0.0, 1.0)


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
