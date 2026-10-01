extends Node

const ACTION_FORWARD: StringName = &"move_forward"
const ACTION_BACKWARD: StringName = &"move_backward"
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"move_jump"
const ACTION_SPRINT: StringName = &"move_sprint"
const ACTION_CROUCH: StringName = &"move_crouch"
const ACTION_SHOOT: StringName = &"shoot"
const ACTION_RELOAD: StringName = &"reload"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_WEAPON_SWORD: StringName = &"weapon_sword"
const ACTION_WEAPON_HALBERD: StringName = &"weapon_halberd"
const ACTION_WEAPON_SHIELD: StringName = &"weapon_shield"

@export_group("Sprint Input")
## Enables normal hold-to-sprint using the move_sprint action.
@export var enable_hold_sprint: bool = true

@export_group("Forward Double Tap Sprint")
## Enables optional Minecraft-style sprint by double tapping forward.
@export var enable_forward_double_tap_sprint: bool = true
## Maximum time allowed between the first and second forward tap.
@export var forward_double_tap_window: float = 0.28
## Forward input amount required to keep sprint active.
@export var sprint_forward_hold_threshold: float = 0.55

var _forward_tap_timer: float = 0.0
var _forward_sprint_active: bool = false
var _hold_sprint_blocked_until_release: bool = false
var _forward_sprint_blocked_until_release: bool = false
var _last_sprint_request_used_hold: bool = false
var _last_sprint_request_used_forward_tap: bool = false


func update_movement_state(delta: float) -> void:
	_update_sprint_release_blocks()
	_update_forward_double_tap_sprint(delta)


func get_move_input() -> Vector2:
	var x: float = get_action_strength(ACTION_RIGHT) - get_action_strength(ACTION_LEFT)
	var y: float = get_action_strength(ACTION_BACKWARD) - get_action_strength(ACTION_FORWARD)
	return Vector2(x, y).limit_length(1.0)


func wants_sprint(move_input: Vector2) -> bool:
	_last_sprint_request_used_hold = false
	_last_sprint_request_used_forward_tap = false

	if _hold_sprint_blocked_until_release and Input.is_action_pressed(ACTION_SPRINT):
		return false
	if _forward_sprint_blocked_until_release and Input.is_action_pressed(ACTION_FORWARD):
		return false

	if enable_hold_sprint and Input.is_action_pressed(ACTION_SPRINT):
		_last_sprint_request_used_hold = true
		return true
	if not enable_forward_double_tap_sprint:
		return false

	var wants_forward_sprint: bool = _forward_sprint_active and move_input.y <= -maxf(sprint_forward_hold_threshold, 0.0)
	if wants_forward_sprint:
		_last_sprint_request_used_forward_tap = true
	return wants_forward_sprint


func is_forward_pressed() -> bool:
	return Input.is_action_pressed(ACTION_FORWARD)


func is_forward_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_FORWARD)


func is_crouch_pressed() -> bool:
	return Input.is_action_pressed(ACTION_CROUCH)


func is_shoot_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_SHOOT)


func is_reload_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_RELOAD)


func is_attack_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_ATTACK)


func is_attack_pressed() -> bool:
	return Input.is_action_pressed(ACTION_ATTACK)


func is_weapon_sword_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_WEAPON_SWORD)


func is_weapon_halberd_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_WEAPON_HALBERD)


func is_weapon_shield_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_WEAPON_SHIELD)


func is_jump_pressed() -> bool:
	return Input.is_action_pressed(ACTION_JUMP)


func is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_JUMP)


func get_action_strength(action: StringName) -> float:
	return Input.get_action_strength(action)


func reset_movement_state() -> void:
	_reset_forward_sprint_state()
	_hold_sprint_blocked_until_release = false
	_forward_sprint_blocked_until_release = false
	_last_sprint_request_used_hold = false
	_last_sprint_request_used_forward_tap = false


func cancel_sprint_request_until_release() -> void:
	if _last_sprint_request_used_hold and Input.is_action_pressed(ACTION_SPRINT):
		_hold_sprint_blocked_until_release = true
	if _last_sprint_request_used_forward_tap and Input.is_action_pressed(ACTION_FORWARD):
		_forward_sprint_blocked_until_release = true

	_forward_tap_timer = 0.0
	_forward_sprint_active = false
	_last_sprint_request_used_hold = false
	_last_sprint_request_used_forward_tap = false


func _update_sprint_release_blocks() -> void:
	if _hold_sprint_blocked_until_release and not Input.is_action_pressed(ACTION_SPRINT):
		_hold_sprint_blocked_until_release = false
	if _forward_sprint_blocked_until_release and not Input.is_action_pressed(ACTION_FORWARD):
		_forward_sprint_blocked_until_release = false


func _update_forward_double_tap_sprint(delta: float) -> void:
	var forward_pressed: bool = Input.is_action_pressed(ACTION_FORWARD)

	if not enable_forward_double_tap_sprint:
		_reset_forward_sprint_state()
		return
	if _forward_sprint_blocked_until_release:
		_reset_forward_sprint_state()
		return

	if Input.is_action_just_pressed(ACTION_FORWARD):
		if _forward_tap_timer > 0.0:
			_forward_sprint_active = true
		_forward_tap_timer = maxf(forward_double_tap_window, 0.0)
	elif _forward_tap_timer > 0.0:
		_forward_tap_timer = maxf(_forward_tap_timer - delta, 0.0)

	if not forward_pressed:
		_forward_sprint_active = false


func _reset_forward_sprint_state() -> void:
	_forward_tap_timer = 0.0
	_forward_sprint_active = false
