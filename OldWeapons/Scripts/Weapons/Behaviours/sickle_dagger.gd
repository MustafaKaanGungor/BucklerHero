extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## Sickle and dagger: fast duelist. Clicks alternate between the sickle (right hand, sweeps right to
## left) and the dagger (left hand, sweeps left to right): quick, low-damage cuts. Enemies that are
## staggered (by any weapon) take execute_multiplier times the damage.
## S rank: holding attack throws daggers in a stream, alternating hands (thrown_dagger hits never
## score on the combo meter, so the stream doesn't keep S going by itself). Below S a hold is
## just a click.
## The two hands are the children right_hand_path / left_hand_path; this script animates them itself
## (the attack data's poses stay at zero so the weapon node as a whole doesn't move).

const CrossbowBolt = preload("res://Scripts/Weapons/crossbow_bolt.gd")
const THROWN_DAGGER: StringName = &"thrown_dagger"

@export_group("Hands")
@export var right_hand_path: NodePath = NodePath("Right")
@export var left_hand_path: NodePath = NodePath("Left")
## Attack data for the left hand's cut (the right hand uses attack_data).
@export var left_attack_data: MeleeAttackData
## Right hand pose at the end of the windup and of the strike (offset from its idle place). The left
## hand uses the mirror image.
@export var windup_position: Vector3 = Vector3(0.1, 0.06, 0.1)
@export var windup_rotation_degrees: Vector3 = Vector3(-15.0, -55.0, 25.0)
@export var strike_position: Vector3 = Vector3(-0.32, -0.02, -0.16)
@export var strike_rotation_degrees: Vector3 = Vector3(-35.0, 75.0, -15.0)
## How quickly a hand returns to rest.
@export var return_speed: float = 14.0

@export_group("Execute")
## Damage multiplier against staggered enemies.
@export var execute_multiplier: float = 3.0
## Extra screen shake on an execute hit.
@export_range(0.0, 1.0) var execute_screen_shake: float = 0.2

@export_group("Dagger Stream (S Rank)")
## Seconds between thrown daggers while attack is held at S rank.
@export var throw_interval: float = 0.08
## Damage, speed (m/s) and push of each dagger.
@export var dagger_damage: float = 1.5
@export var dagger_speed: float = 70.0
@export var dagger_impulse: float = 4.0
## Random spread around the crosshair (degrees).
@export var dagger_spread_degrees: float = 1.5
@export var dagger_color: Color = Color(0.55, 0.57, 0.62)
## Loudness per dagger.
@export var dagger_loudness: float = 4.0

var _right: Node3D
var _left: Node3D
var _right_idle: Transform3D
var _left_idle: Transform3D
var _right_pose: Transform3D = Transform3D.IDENTITY
var _left_pose: Transform3D = Transform3D.IDENTITY
var _use_left: bool = true
var _active_left: bool = false
var _throw_timer: float = 0.0
var _throw_left: bool = false
var _flick_right: float = 0.0
var _flick_left: float = 0.0
var _streaming: bool = false
var _throw_count: int = 0


func setup(owner_weapons: Node) -> void:
	super.setup(owner_weapons)
	_right = get_node_or_null(right_hand_path) as Node3D
	_left = get_node_or_null(left_hand_path) as Node3D
	if _right != null:
		_right_idle = _right.transform
	if _left != null:
		_left_idle = _left.transform
	weapons.connect(&"attack_started", _on_attack_started)


func get_throw_count() -> int:
	return _throw_count


func is_streaming() -> bool:
	return _streaming


## Each new cut uses the other hand: swap the attack data before the swing runs.
func _on_attack_started(started_weapon: StringName) -> void:
	if started_weapon != weapon_id or _streaming:
		return
	_use_left = not _use_left
	_active_left = _use_left
	var data: MeleeAttackData = left_attack_data if _use_left and left_attack_data != null else attack_data
	weapons.call(&"set_attack_data", weapon_id, data)


func modify_hit(hit_info: Dictionary, target: Node3D) -> Dictionary:
	if target != null and target.has_method(&"is_staggered") and bool(target.call(&"is_staggered")):
		hit_info["damage"] = float(hit_info.get("damage", 0.0)) * maxf(execute_multiplier, 0.0)
		hit_info["execute"] = true
		weapons.call(&"add_screen_shake", execute_screen_shake)
	return hit_info


func on_hold_started() -> bool:
	if not is_empowered():
		return false
	_streaming = true
	_throw_timer = 0.0
	weapons.call(&"register_custom_attack", weapon_id)
	weapons.call(&"set_recover", weapon_id, 0.25)
	return true


func on_hold_updated(delta: float, _held_time: float) -> bool:
	# The stream stops as soon as the meter drops below S.
	if not is_empowered():
		_streaming = false
		return false
	weapons.call(&"set_recover", weapon_id, 0.25)
	_throw_timer -= delta
	while _throw_timer <= 0.0:
		_throw_timer += maxf(throw_interval, 0.02)
		_throw_dagger()
	return true


func on_hold_released(_held_time: float) -> void:
	_streaming = false


func on_hold_cancelled() -> void:
	_streaming = false


func on_unequipped() -> void:
	_streaming = false


func _throw_dagger() -> void:
	var camera: Node3D = weapons.call(&"get_camera") as Node3D
	if camera == null:
		return
	var camera_transform: Transform3D = camera.global_transform.orthonormalized()
	var forward: Vector3 = -camera_transform.basis.z
	var excluded: Array[RID] = weapons.call(&"get_excluded_rids")
	var mask: int = int(weapons.call(&"get_hit_collision_mask"))
	var aim_point: Vector3 = camera_transform.origin + forward * 100.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera_transform.origin, aim_point, mask, excluded)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim_point = Vector3(hit.get("position", aim_point))
	_throw_left = not _throw_left
	var side: float = -1.0 if _throw_left else 1.0
	var start: Vector3 = camera_transform.origin + forward * 0.5 + camera_transform.basis.x * (0.18 * side) - camera_transform.basis.y * 0.12
	if aim_point.distance_to(camera_transform.origin) < 1.2:
		start = camera_transform.origin
	var direction: Vector3 = (aim_point - start).normalized()
	var spread: float = deg_to_rad(maxf(dagger_spread_degrees, 0.0))
	direction = direction.rotated(camera_transform.basis.y, randf_range(-spread, spread))
	direction = direction.rotated(camera_transform.basis.x, randf_range(-spread, spread)).normalized()

	var dagger: Node3D = Node3D.new()
	dagger.set_script(CrossbowBolt)
	dagger.set(&"speed", dagger_speed)
	dagger.set(&"gravity", 0.0)
	dagger.set(&"lifetime", 1.5)
	dagger.set(&"collision_mask", mask)
	dagger.set(&"damage", dagger_damage)
	dagger.set(&"physics_impulse", dagger_impulse)
	dagger.set(&"report_method", &"on_weapon_projectile_hit")
	dagger.set(&"weapon_id", THROWN_DAGGER)
	dagger.set(&"stick_in_world", false)
	dagger.set(&"shaft_length", 0.32)
	dagger.set(&"bolt_color", dagger_color)
	weapons.call(&"spawn_in_world", dagger)
	dagger.call(&"launch", start, direction, weapons, excluded)
	LoudnessManger.register_sound(dagger_loudness)
	_throw_count += 1
	if _throw_left:
		_flick_left = 1.0
	else:
		_flick_right = 1.0
	# The throw sound comes straight from the weapon audio: an attack_started here would count as a
	# different weapon for the combo rule.
	var audio: Node = weapons.get_node_or_null(^"Audio")
	if audio != null and audio.has_method(&"play_sound"):
		audio.call(&"play_sound", &"swing_thrown_dagger")


func _process(delta: float) -> void:
	if _right == null or _left == null:
		return
	var right_target: Transform3D = Transform3D.IDENTITY
	var left_target: Transform3D = Transform3D.IDENTITY
	if is_equipped() and bool(weapons.call(&"is_attacking")) and not _streaming:
		var cut: Transform3D = _get_cut_pose(float(weapons.call(&"get_attack_progress")))
		if _active_left:
			left_target = _mirror(cut)
		else:
			right_target = cut
	var blend: float = 1.0 - exp(-maxf(return_speed, 0.001) * delta)
	if is_equipped() and bool(weapons.call(&"is_attacking")):
		blend = 1.0
	_right_pose = _right_pose.interpolate_with(right_target, blend)
	_left_pose = _left_pose.interpolate_with(left_target, blend)
	_flick_right = maxf(_flick_right - delta * 12.0, 0.0)
	_flick_left = maxf(_flick_left - delta * 12.0, 0.0)
	_right.transform = Transform3D(_right_pose.basis * _flick_basis(_flick_right), _right_idle.origin + _right_pose.origin + _flick_offset(_flick_right)) * Transform3D(_right_idle.basis, Vector3.ZERO)
	_left.transform = Transform3D(_left_pose.basis * _flick_basis(_flick_left), _left_idle.origin + _left_pose.origin + _flick_offset(_flick_left)) * Transform3D(_left_idle.basis, Vector3.ZERO)


## Right-hand pose at progress through windup -> strike -> recover.
func _get_cut_pose(progress: float) -> Transform3D:
	var data: MeleeAttackData = left_attack_data if _active_left and left_attack_data != null else attack_data
	if data == null:
		return Transform3D.IDENTITY
	var windup_end: float = data.get_windup_end()
	var strike_end: float = data.get_strike_end()
	var windup_rot: Vector3 = _deg(windup_rotation_degrees)
	var strike_rot: Vector3 = _deg(strike_rotation_degrees)
	var position_value: Vector3
	var rotation_value: Vector3
	if progress < windup_end:
		var t: float = smoothstep(0.0, 1.0, progress / maxf(windup_end, 0.001))
		position_value = windup_position * t
		rotation_value = windup_rot * t
	elif progress < strike_end:
		var t2: float = 1.0 - pow(1.0 - data.get_strike_progress(progress), 3.0)
		position_value = windup_position.lerp(strike_position, t2)
		rotation_value = windup_rot.lerp(strike_rot, t2)
	else:
		var t3: float = smoothstep(0.0, 1.0, (progress - strike_end) / maxf(1.0 - strike_end, 0.001))
		position_value = strike_position * (1.0 - t3)
		rotation_value = strike_rot * (1.0 - t3)
	return Transform3D(Basis.from_euler(rotation_value), position_value)


## Mirror image across the camera's X axis (for the left hand).
func _mirror(pose: Transform3D) -> Transform3D:
	var euler: Vector3 = pose.basis.get_euler()
	return Transform3D(Basis.from_euler(Vector3(euler.x, -euler.y, -euler.z)), Vector3(-pose.origin.x, pose.origin.y, pose.origin.z))


func _flick_basis(amount: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(-45.0) * amount, 0.0, 0.0))


func _flick_offset(amount: float) -> Vector3:
	return Vector3(0.0, 0.03, -0.14) * amount


func _deg(value: Vector3) -> Vector3:
	return Vector3(deg_to_rad(value.x), deg_to_rad(value.y), deg_to_rad(value.z))
