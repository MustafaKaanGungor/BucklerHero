extends Node3D

const METHOD_GET_CURRENT_BODY_HEIGHT: StringName = &"get_current_body_height"
const METHOD_GET_STEP_VIEW_OFFSET: StringName = &"get_step_view_offset"

@export var player_path: NodePath = NodePath("..")
@export var capture_mouse_on_ready: bool = true
@export var release_mouse_action: StringName = &"ui_cancel"

var player: CharacterBody3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _target_eye_height: float = 1.62
var _look_motion: Vector2 = Vector2.ZERO
var _last_step_view_offset: float = 0.0
var _pending_look_motion: Vector2 = Vector2.ZERO
var _smoothed_look_motion: Vector2 = Vector2.ZERO


func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	if player == null:
		player = get_parent() as CharacterBody3D

	sync_with_player_rotation()
	_target_eye_height = position.y

	if capture_mouse_on_ready:
		capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(release_mouse_action):
		release_mouse()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			capture_mouse()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_queue_mouse_look(mouse_motion.relative)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_apply_queued_mouse_look(delta)
	_update_eye_height(delta)
	_decay_look_motion(delta)


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func get_target_eye_height() -> float:
	return _target_eye_height


func get_look_motion() -> Vector2:
	return _look_motion


func sync_with_player_rotation() -> void:
	if player != null:
		_yaw = player.rotation.y
	else:
		_yaw = rotation.y

	_pitch = rotation.x
	_pending_look_motion = Vector2.ZERO
	_smoothed_look_motion = Vector2.ZERO
	_look_motion = Vector2.ZERO


func _queue_mouse_look(relative_motion: Vector2) -> void:
	_pending_look_motion += relative_motion


func _apply_queued_mouse_look(delta: float) -> void:
	if _pending_look_motion.length_squared() <= 0.0:
		var rest_blend: float = CameraFeel.get_look_feedback_blend(delta)
		_smoothed_look_motion = _smoothed_look_motion.lerp(Vector2.ZERO, rest_blend)
		return

	var raw_motion: Vector2 = CameraFeel.clamp_look_input(_pending_look_motion)
	_pending_look_motion = Vector2.ZERO
	var applied_motion: Vector2 = CameraFeel.clean_look_input(raw_motion)
	var feedback_motion: Vector2 = applied_motion
	if CameraFeel.enable_smoothed_look_input:
		var look_blend: float = CameraFeel.get_look_input_blend(delta)
		_smoothed_look_motion = _smoothed_look_motion.lerp(raw_motion, look_blend)
		applied_motion = CameraFeel.get_responsive_look_input(raw_motion, _smoothed_look_motion)
		var feedback_blend: float = CameraFeel.get_look_feedback_blend(delta)
		feedback_motion = _look_motion.lerp(_smoothed_look_motion, feedback_blend)
	else:
		_smoothed_look_motion = raw_motion

	if applied_motion == Vector2.ZERO:
		return

	_apply_mouse_look(applied_motion, feedback_motion)


func _apply_mouse_look(relative_motion: Vector2, feedback_motion: Vector2) -> void:
	_look_motion = feedback_motion
	_yaw -= relative_motion.x * CameraFeel.mouse_sensitivity
	_pitch -= relative_motion.y * CameraFeel.mouse_sensitivity
	_pitch = clampf(
		_pitch,
		-deg_to_rad(CameraFeel.max_pitch_degrees),
		deg_to_rad(CameraFeel.max_pitch_degrees)
	)

	if player != null:
		player.rotation.y = _yaw
	else:
		rotation.y = _yaw

	rotation.x = _pitch


func _update_eye_height(delta: float) -> void:
	if player == null or not player.has_method(METHOD_GET_CURRENT_BODY_HEIGHT):
		return

	var body_height: float = float(player.call(METHOD_GET_CURRENT_BODY_HEIGHT))
	_target_eye_height = CrouchFeel.get_eye_height(body_height)
	var step_view_offset: float = 0.0
	if player.has_method(METHOD_GET_STEP_VIEW_OFFSET):
		step_view_offset = float(player.call(METHOD_GET_STEP_VIEW_OFFSET))

	_target_eye_height += step_view_offset
	if step_view_offset < _last_step_view_offset:
		var step_view_delta: float = step_view_offset - _last_step_view_offset
		var raw_hide_delta: float = StairFeel.get_instant_step_hide_delta(step_view_delta)
		position.y += CameraFeel.get_soft_step_hide_delta(raw_hide_delta)
	_last_step_view_offset = step_view_offset

	var height_blend: float = CrouchFeel.get_eye_height_blend(position.y, _target_eye_height, delta)
	position.y = lerpf(position.y, _target_eye_height, height_blend)


func _decay_look_motion(delta: float) -> void:
	var decay_blend: float = 1.0 - exp(-CameraFeel.look_motion_decay_speed * delta)
	_look_motion = _look_motion.lerp(Vector2.ZERO, decay_blend)
