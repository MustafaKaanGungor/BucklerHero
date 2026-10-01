extends Node

@export_group("Activation")
## Enables the shield charge started by holding attack with the shield out.
@export var enable_shield_charge: bool = true

@export_group("Speed")
## Top speed of the charge.
@export var charge_speed: float = 11.5
## Speed the charge starts at if the player is moving slower than this.
@export var charge_start_speed: float = 4.0
## Speed gained per second while the charge builds up.
@export var charge_acceleration: float = 11.0
## After running into something, the charge speed drops to the real forward speed plus this much.
@export var blocked_speed_slack: float = 1.0

@export_group("Steering")
## Degrees per second the charge can turn toward where the player looks while it is still slow.
@export var turn_rate_degrees: float = 150.0
## Degrees per second the charge can turn at top speed. Lower feels heavier, like a car at speed.
@export var full_speed_turn_rate_degrees: float = 75.0

@export_group("Brake")
## Speed lost per second after the attack button is released.
@export var brake_deceleration: float = 13.0
## The charge ends and normal movement returns once braking reaches this speed.
@export var brake_end_speed: float = 5.0

@export_group("Block")
## The braced shield blocks damage while the charge is held (not while it brakes).
@export var enable_brace_block: bool = true
## Attacks from further than this to the side of the charge heading get past the shield.
## 90 covers the whole front half, 180 blocks from every direction.
@export_range(0.0, 180.0) var brace_block_angle_degrees: float = 100.0
## The shield also blocks damage just by being the weapon in hand, without charging.
@export var enable_equipped_block: bool = true
## Attacks from further than this to the side of where the player faces get past a shield that is only held.
@export_range(0.0, 180.0) var equipped_block_angle_degrees: float = 80.0

@export_group("Feel")
## Blend speed of the charge state used by camera and hands.
@export var charge_blend_lerp_speed: float = 9.0


func get_next_charge_speed(charge_speed_now: float, is_braking: bool, delta: float) -> float:
	if is_braking:
		return maxf(charge_speed_now - (maxf(brake_deceleration, 0.0) * delta), 0.0)
	return move_toward(charge_speed_now, maxf(charge_speed, 0.0), maxf(charge_acceleration, 0.0) * delta)


func get_start_speed(forward_speed: float) -> float:
	return clampf(maxf(forward_speed, charge_start_speed), 0.0, maxf(charge_speed, 0.0))


func get_speed_ratio(charge_speed_now: float) -> float:
	return clampf(charge_speed_now / maxf(charge_speed, 0.001), 0.0, 1.0)


func is_brake_finished(charge_speed_now: float) -> bool:
	return charge_speed_now <= maxf(brake_end_speed, 0.0)


## Turns the charge heading toward the look direction, limited like a steering wheel.
func get_steered_heading(heading: Vector3, look_direction: Vector3, charge_speed_now: float, delta: float) -> Vector3:
	var clean_heading: Vector3 = _get_horizontal_direction(heading)
	var clean_look: Vector3 = _get_horizontal_direction(look_direction)
	if clean_heading == Vector3.ZERO:
		return clean_look
	if clean_look == Vector3.ZERO:
		return clean_heading

	var turn_rate: float = lerpf(
		maxf(turn_rate_degrees, 0.0),
		maxf(full_speed_turn_rate_degrees, 0.0),
		get_speed_ratio(charge_speed_now)
	)
	var max_turn: float = deg_to_rad(turn_rate) * delta
	var angle_to_look: float = clean_heading.signed_angle_to(clean_look, Vector3.UP)
	return clean_heading.rotated(Vector3.UP, clampf(angle_to_look, -max_turn, max_turn)).normalized()


## True if an attack coming from direction_to_attacker hits the braced shield instead of the player.
## An attack with no known direction is treated as coming from the front.
func is_blocked_by_brace(heading: Vector3, direction_to_attacker: Vector3) -> bool:
	if not enable_brace_block:
		return false
	return _is_inside_block_angle(heading, direction_to_attacker, brace_block_angle_degrees)


## True if an attack coming from direction_to_attacker hits a shield that is simply held in hand.
func is_blocked_by_equipped_shield(facing: Vector3, direction_to_attacker: Vector3) -> bool:
	if not enable_equipped_block:
		return false
	return _is_inside_block_angle(facing, direction_to_attacker, equipped_block_angle_degrees)


func _is_inside_block_angle(facing: Vector3, direction_to_attacker: Vector3, block_angle_degrees: float) -> bool:
	var clean_facing: Vector3 = _get_horizontal_direction(facing)
	var clean_direction: Vector3 = _get_horizontal_direction(direction_to_attacker)
	if clean_facing == Vector3.ZERO or clean_direction == Vector3.ZERO:
		return true
	return rad_to_deg(clean_facing.angle_to(clean_direction)) <= block_angle_degrees


func get_charge_blend(current_blend: float, is_charging: bool, delta: float) -> float:
	var target_blend: float = 0.0
	if is_charging:
		target_blend = 1.0

	var blend_amount: float = 1.0 - exp(-maxf(charge_blend_lerp_speed, 0.001) * delta)
	return lerpf(current_blend, target_blend, blend_amount)


func _get_horizontal_direction(direction: Vector3) -> Vector3:
	var horizontal_direction: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if horizontal_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return horizontal_direction.normalized()
