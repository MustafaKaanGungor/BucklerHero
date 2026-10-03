extends Node3D

## First-person pistol viewmodel.
## Lives under Head/Camera3D and layers its own motion on top of the camera:
## camera turn sway, strafe/forward sway, walk and sprint bob, idle breathing,
## jump/landing kicks, and state poses for sprinting, sliding and climbing.
## Values are tuned for the model being scaled down and held close to the camera,
## which keeps it from clipping into walls.
## Shooting: aims through the screen center, spawns a projectile at the muzzle that flies
## toward the aimed point, and plays recoil, muzzle flash and a loudness spike.
## Ammo: a magazine that refills from unlimited reserve ammo. R reloads early; pulling
## the trigger on an empty magazine reloads automatically.

signal fired(spawn_position: Vector3, direction: Vector3)
signal ammo_changed(current_ammo: int, magazine_size: int, is_reloading: bool)

## HUD elements find the player's weapon through this group.
const GROUP_PLAYER_WEAPONS: StringName = &"player_weapons"

const METHOD_GET_HORIZONTAL_SPEED: StringName = &"get_horizontal_speed"
const METHOD_GET_MOVE_INPUT: StringName = &"get_move_input"
const METHOD_GET_VERTICAL_VELOCITY: StringName = &"get_vertical_velocity"
const METHOD_GET_RECENT_JUMP_FEEDBACK: StringName = &"get_recent_jump_feedback"
const METHOD_GET_RECENT_LANDING_IMPACT: StringName = &"get_recent_landing_impact"
const METHOD_GET_SPRINT_RAMP_BLEND: StringName = &"get_sprint_ramp_blend"
const METHOD_GET_SLIDE_BLEND: StringName = &"get_slide_blend"
const METHOD_GET_CLIMB_BLEND: StringName = &"get_climb_blend"
const METHOD_GET_EDGE_PULL_OVER_BLEND: StringName = &"get_edge_pull_over_blend"
const METHOD_GET_YAW: StringName = &"get_yaw"
const METHOD_GET_PITCH: StringName = &"get_pitch"
const METHOD_IS_CLIMBING: StringName = &"is_climbing"
const METHOD_IS_EDGE_HOLDING: StringName = &"is_edge_holding"
const METHOD_IS_EDGE_PULLING_OVER: StringName = &"is_edge_pulling_over"
const METHOD_ADD_RECOIL_IMPULSE: StringName = &"add_recoil_impulse"

@export var player_path: NodePath = NodePath("../../..")
@export var head_path: NodePath = NodePath("../..")
@export var muzzle_path: NodePath = NodePath("Muzzle")
@export var muzzle_flash_path: NodePath = NodePath("Muzzle/MuzzleFlash")

@export_group("Shooting")
## Scene spawned for each shot.
@export var projectile_scene: PackedScene = preload("res://Scenes/Weapons/projectile.tscn")
## Minimum seconds between shots. The pistol is semi-automatic: one click, one shot.
@export var fire_interval: float = 0.14
## A click this many seconds before the pistol is ready still fires as soon as it can.
@export var fire_input_buffer: float = 0.12
## Bullet speed in meters per second.
@export var projectile_speed: float = 180.0
## Damage passed to hit objects.
@export var projectile_damage: float = 1.0
## Push applied to RigidBody3D objects that get hit.
@export var projectile_physics_impulse: float = 4.0
## How far the aim ray from the screen center looks for a target.
@export var max_aim_distance: float = 1000.0
## If the aimed point is closer than this, the bullet starts at the camera instead of the muzzle,
## so point-blank shots still land exactly under the crosshair.
@export var min_muzzle_aim_distance: float = 1.2
## Physics layers used for aiming. Matches the player's movement collision layer.
@export_flags_3d_physics var aim_collision_mask: int = 1
## Loudness added to the stealth meter per shot.
@export var shot_loudness: float = 60.0

@export_group("Recoil")
## Gun kick per shot. +Z pushes the gun back toward the camera.
@export var recoil_kick_position: Vector3 = Vector3(0.0, 0.005, 0.024)
## Gun kick rotation per shot. +X tips the barrel up.
@export var recoil_kick_rotation_degrees: Vector3 = Vector3(9.0, 0.0, 0.0)
## Random extra yaw and roll per shot, in degrees (X = yaw range, Y = roll range).
@export var recoil_random_degrees: Vector2 = Vector2(1.5, 4.0)
@export var recoil_spring_stiffness: float = 260.0
@export var recoil_spring_damping: float = 20.0
## Small camera kick per shot. It springs back, so aim returns to where it was.
@export var camera_kick_rotation_degrees: Vector3 = Vector3(0.6, 0.0, 0.0)
@export var camera_kick_position: Vector3 = Vector3(0.0, 0.0, 0.006)

@export_group("Ammo")
## Rounds in a full magazine. Reserve ammo is unlimited, so reloading always refills it.
@export var magazine_size: int = 12
## Seconds a reload takes. The gun can't fire until it finishes.
@export var reload_time: float = 1.2
## Starts reloading right after the last round is fired instead of waiting for the next trigger pull.
@export var reload_immediately_when_empty: bool = false
## Loudness added to the stealth meter when the new magazine clicks in.
@export var reload_loudness: float = 8.0

@export_group("Reload Animation")
## Gun offset at the lowest point of the reload.
@export var reload_position_offset: Vector3 = Vector3(0.015, -0.065, 0.03)
## Gun rotation at the lowest point of the reload. +X tips the barrel up, +Z rolls it left.
@export var reload_rotation_degrees: Vector3 = Vector3(-22.0, -12.0, 38.0)
## Share of the reload spent moving the gun into the reload pose.
@export_range(0.05, 0.5) var reload_lower_portion: float = 0.22
## Point in the reload (0-1) where the gun starts coming back up.
@export_range(0.5, 0.95) var reload_raise_start: float = 0.74
## Point in the reload (0-1) where the new magazine slaps in.
@export_range(0.0, 1.0) var reload_slap_point: float = 0.6
## Kick applied when the magazine slaps in. +Y bumps the gun up.
@export var reload_slap_kick_position: Vector3 = Vector3(0.0, 0.014, -0.004)
@export var reload_slap_kick_rotation_degrees: Vector3 = Vector3(-7.0, 0.0, -4.0)

@export_group("Muzzle Flash")
## Seconds the flash stays visible.
@export var muzzle_flash_duration: float = 0.045

@export_group("Placement")
## Resting position relative to the camera. Negative Z is in front of the camera.
@export var base_position: Vector3 = Vector3(0.1, -0.105, -0.22)
## Resting rotation. Positive Y turns the barrel toward the screen center.
@export var base_rotation_degrees: Vector3 = Vector3(0.0, 4.0, 0.0)
## Keeps the viewmodel from casting odd shadows onto the world.
@export var cast_shadows: bool = false

@export_group("Camera Turn Sway")
## Enables the gun lagging behind camera rotation.
@export var enable_turn_sway: bool = true
## Position drift per degree/second of camera turn. X follows yaw, Y follows pitch.
@export var turn_sway_position: Vector2 = Vector2(0.00008, 0.00006)
## Rotation lag per degree/second of camera turn: X = nose lag from pitch, Y = yaw lag, Z = roll from yaw.
@export var turn_sway_rotation: Vector3 = Vector3(0.018, 0.024, 0.02)
## Turn speed (degrees/second) is clamped to this, so fast flicks don't throw the gun off-screen.
@export var max_turn_speed_degrees: float = 320.0
## Smooths the measured turn speed so uneven mouse input doesn't jitter the gun.
@export var turn_speed_smoothing: float = 22.0
## How strongly turn sway pulls back to rest. Higher is snappier.
@export var turn_spring_stiffness: float = 110.0
## How quickly turn sway bounce settles. Lower gives more overshoot when you stop turning.
@export var turn_spring_damping: float = 11.0

@export_group("Move Sway")
## Sideways shift while strafing.
@export var strafe_position: float = 0.012
## Roll while strafing.
@export var strafe_roll_degrees: float = 3.0
## Pulls the gun back while moving forward and pushes it out while moving backward.
@export var forward_position: float = 0.008

@export_group("Sway Spring")
## How strongly sway returns to rest. Higher is snappier.
@export var sway_spring_stiffness: float = 140.0
## How quickly sway bounce settles. Lower gives more overshoot.
@export var sway_spring_damping: float = 13.0

@export_group("Bob")
## Walk bob size. X is side to side, Y is up and down.
@export var walk_bob_amount: Vector2 = Vector2(0.005, 0.004)
## Sprint bob size.
@export var sprint_bob_amount: Vector2 = Vector2(0.009, 0.007)
## Roll added in rhythm with the side-to-side bob.
@export var bob_roll_degrees: float = 1.2
## Bob phase gained per meter traveled.
@export var bob_frequency: float = 1.2
## Bob frequency multiplier while sprinting; below 1 keeps sprint bob from getting frantic.
@export var sprint_bob_frequency_multiplier: float = 0.75
## How quickly bob fades in and out when landing or leaving the ground.
@export var bob_ground_blend_speed: float = 10.0

@export_group("Idle Breathing")
@export var breath_amount: float = 0.0015
@export var breath_speed: float = 1.4

@export_group("Air")
## Gun floats up while falling and dips while rising.
@export var air_velocity_position: float = 0.0012
## Limit for the air float offset.
@export var max_air_position: float = 0.014
## Nose tilt per unit of vertical speed.
@export var air_velocity_rotation_degrees: float = 0.25
## Limit for the air nose tilt.
@export var max_air_rotation_degrees: float = 3.5

@export_group("Kicks")
@export var jump_kick_position: Vector3 = Vector3(0.0, -0.012, 0.004)
@export var jump_kick_rotation_degrees: Vector3 = Vector3(-3.0, 0.0, 0.0)
@export var landing_kick_position: Vector3 = Vector3(0.0, -0.022, 0.006)
@export var landing_kick_rotation_degrees: Vector3 = Vector3(-5.0, 0.0, 1.5)

@export_group("State Poses")
## How quickly the gun blends between sprint, slide and climb poses.
@export var pose_lerp_speed: float = 9.0
@export var sprint_position_offset: Vector3 = Vector3(0.01, -0.025, 0.02)
@export var sprint_rotation_degrees: Vector3 = Vector3(-10.0, 8.0, 12.0)
@export var slide_position_offset: Vector3 = Vector3(-0.01, -0.012, 0.0)
@export var slide_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 10.0)
## Lowered pose while climbing or pulling over a ledge, when the hands are busy.
@export var lowered_position_offset: Vector3 = Vector3(0.02, -0.16, 0.06)
@export var lowered_rotation_degrees: Vector3 = Vector3(-40.0, 10.0, 0.0)

var player: CharacterBody3D
var head: Node3D
var _time: float = 0.0
var _bob_phase: float = 0.0
var _ground_blend: float = 1.0
var _sway_position: Vector3 = Vector3.ZERO
var _sway_position_velocity: Vector3 = Vector3.ZERO
var _sway_rotation: Vector3 = Vector3.ZERO
var _sway_rotation_velocity: Vector3 = Vector3.ZERO
var _pose_position: Vector3 = Vector3.ZERO
var _pose_rotation: Vector3 = Vector3.ZERO
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var _has_last_look_angles: bool = false
var _turn_speed: Vector2 = Vector2.ZERO
var _turn_position: Vector3 = Vector3.ZERO
var _turn_position_velocity: Vector3 = Vector3.ZERO
var _turn_rotation: Vector3 = Vector3.ZERO
var _turn_rotation_velocity: Vector3 = Vector3.ZERO
var _muzzle: Node3D
var _muzzle_flash: Node3D
var _muzzle_flash_timer: float = 0.0
var _fire_cooldown_timer: float = 0.0
var _fire_buffer_timer: float = 0.0
var _mouse_was_captured: bool = false
var _recoil_position: Vector3 = Vector3.ZERO
var _recoil_position_velocity: Vector3 = Vector3.ZERO
var _recoil_rotation: Vector3 = Vector3.ZERO
var _recoil_rotation_velocity: Vector3 = Vector3.ZERO
var _ammo: int = 0
var _is_reloading: bool = false
var _reload_timer: float = 0.0
var _reload_slapped: bool = false
var _is_holstered: bool = false


func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	head = get_node_or_null(head_path) as Node3D
	_muzzle = get_node_or_null(muzzle_path) as Node3D
	_muzzle_flash = get_node_or_null(muzzle_flash_path) as Node3D
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
	position = base_position
	rotation = _degrees_to_radians(base_rotation_degrees)
	if not cast_shadows:
		_disable_shadows(self)
	add_to_group(GROUP_PLAYER_WEAPONS)
	_ammo = maxi(magazine_size, 1)
	_emit_ammo_changed()


func get_ammo() -> int:
	return _ammo


func get_magazine_size() -> int:
	return maxi(magazine_size, 1)


func is_reloading() -> bool:
	return _is_reloading


func get_reload_progress() -> float:
	if not _is_reloading or reload_time <= 0.0:
		return 0.0
	return clampf(_reload_timer / reload_time, 0.0, 1.0)


func is_holstered() -> bool:
	return _is_holstered


## Puts the pistol away (hidden, can't fire or reload) or brings it back.
## A reload in progress pauses while holstered and continues afterwards.
func set_holstered(holstered: bool) -> void:
	_is_holstered = holstered
	visible = not holstered
	_fire_buffer_timer = 0.0
	if holstered and _muzzle_flash != null:
		_muzzle_flash.visible = false


func _physics_process(delta: float) -> void:
	_fire_cooldown_timer = maxf(_fire_cooldown_timer - delta, 0.0)
	_fire_buffer_timer = maxf(_fire_buffer_timer - delta, 0.0)
	if _is_holstered:
		_mouse_was_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		return

	_update_reload(delta)

	if InputManager.is_reload_just_pressed():
		start_reload()

	# head.gd captures the mouse on click; that same click shouldn't also fire.
	var mouse_captured: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if InputManager.is_shoot_just_pressed() and _mouse_was_captured and mouse_captured:
		_fire_buffer_timer = maxf(fire_input_buffer, 0.0)
	_mouse_was_captured = mouse_captured

	if _is_weapon_blocked():
		_fire_buffer_timer = 0.0
		return

	if _fire_buffer_timer <= 0.0 or _fire_cooldown_timer > 0.0:
		return
	if _is_reloading:
		# Keep the click buffered; it fires if the reload finishes within the buffer window.
		return

	_fire_buffer_timer = 0.0
	if _ammo <= 0:
		start_reload()
		return

	_fire_cooldown_timer = maxf(fire_interval, 0.0)
	_ammo -= 1
	_fire()
	_emit_ammo_changed()
	if _ammo <= 0 and reload_immediately_when_empty:
		start_reload()


## Starts a reload if the magazine isn't full. Returns true if a reload started.
func start_reload() -> bool:
	if _is_reloading or _ammo >= get_magazine_size():
		return false

	_is_reloading = true
	_reload_timer = 0.0
	_reload_slapped = false
	_emit_ammo_changed()
	return true


func _update_reload(delta: float) -> void:
	if not _is_reloading:
		return

	_reload_timer += delta
	var progress: float = get_reload_progress()
	if not _reload_slapped and progress >= reload_slap_point:
		_reload_slapped = true
		_recoil_position += reload_slap_kick_position
		_recoil_rotation += _degrees_to_radians(reload_slap_kick_rotation_degrees)
		LoudnessManger.register_sound(reload_loudness)

	if _reload_timer >= maxf(reload_time, 0.0):
		_is_reloading = false
		_reload_timer = 0.0
		_ammo = get_magazine_size()
		_emit_ammo_changed()


func _get_reload_pose_weight() -> float:
	if not _is_reloading:
		return 0.0

	var progress: float = get_reload_progress()
	var lower: float = smoothstep(0.0, maxf(reload_lower_portion, 0.001), progress)
	var raise: float = 1.0 - smoothstep(clampf(reload_raise_start, 0.0, 0.999), 1.0, progress)
	return lower * raise


func _emit_ammo_changed() -> void:
	ammo_changed.emit(_ammo, get_magazine_size(), _is_reloading)


func _is_weapon_blocked() -> bool:
	return (
		_player_bool(METHOD_IS_CLIMBING, false)
		or _player_bool(METHOD_IS_EDGE_HOLDING, false)
		or _player_bool(METHOD_IS_EDGE_PULLING_OVER, false)
	)


func _fire() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or projectile_scene == null:
		return

	var exclude: Array[RID] = []
	if player != null:
		exclude.append(player.get_rid())

	# Aim through the screen center, then send the bullet from the muzzle toward that point.
	var camera_origin: Vector3 = camera.global_position
	var aim_direction: Vector3 = -camera.global_basis.z.normalized()
	var aim_end: Vector3 = camera_origin + (aim_direction * maxf(max_aim_distance, 0.1))
	var aim_hit: Dictionary = _raycast(camera_origin, aim_end, exclude)
	var aim_point: Vector3 = aim_end if aim_hit.is_empty() else Vector3(aim_hit.position)

	var spawn_position: Vector3 = camera_origin
	var direction: Vector3 = aim_direction
	if _muzzle != null:
		var muzzle_position: Vector3 = _muzzle.global_position
		# If the gun is poking into a wall, start at the camera so the bullet can't pass through it.
		var muzzle_blocked: bool = not _raycast(camera_origin, muzzle_position, exclude).is_empty()
		if not muzzle_blocked and camera_origin.distance_to(aim_point) > min_muzzle_aim_distance:
			spawn_position = muzzle_position
			direction = (aim_point - muzzle_position).normalized()

	var projectile: Node3D = projectile_scene.instantiate() as Node3D
	if projectile == null:
		return
	projectile.set(&"speed", projectile_speed)
	projectile.set(&"damage", projectile_damage)
	projectile.set(&"physics_impulse", projectile_physics_impulse)
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_tree().root
	projectile_parent.add_child(projectile)
	projectile.call(&"launch", spawn_position, direction, exclude)

	_apply_recoil(camera)
	_show_muzzle_flash()
	LoudnessManger.register_sound(shot_loudness)
	fired.emit(spawn_position, direction)


func _raycast(from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, aim_collision_mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _apply_recoil(camera: Camera3D) -> void:
	_recoil_position += recoil_kick_position
	_recoil_rotation += _degrees_to_radians(recoil_kick_rotation_degrees)
	_recoil_rotation.y += deg_to_rad(randf_range(-recoil_random_degrees.x, recoil_random_degrees.x))
	_recoil_rotation.z += deg_to_rad(randf_range(-recoil_random_degrees.y, recoil_random_degrees.y))

	if camera.has_method(METHOD_ADD_RECOIL_IMPULSE):
		camera.call(METHOD_ADD_RECOIL_IMPULSE, camera_kick_position, _degrees_to_radians(camera_kick_rotation_degrees))


func _show_muzzle_flash() -> void:
	if _muzzle_flash == null:
		return
	_muzzle_flash_timer = maxf(muzzle_flash_duration, 0.0)
	_muzzle_flash.rotation.z = randf_range(0.0, TAU)
	_muzzle_flash.visible = true


func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash == null or not _muzzle_flash.visible:
		return
	_muzzle_flash_timer -= delta
	if _muzzle_flash_timer <= 0.0:
		_muzzle_flash.visible = false


func _update_recoil(delta: float) -> void:
	_recoil_position_velocity += -_recoil_position * recoil_spring_stiffness * delta
	_recoil_rotation_velocity += -_recoil_rotation * recoil_spring_stiffness * delta
	var damping: float = exp(-recoil_spring_damping * delta)
	_recoil_position_velocity *= damping
	_recoil_rotation_velocity *= damping
	_recoil_position += _recoil_position_velocity * delta
	_recoil_rotation += _recoil_rotation_velocity * delta


func _process(delta: float) -> void:
	if player == null:
		return

	_time += delta
	var horizontal_speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, 0.0)
	var speed_ratio: float = clampf(horizontal_speed / maxf(MovementWalk.walk_speed, 0.001), 0.0, 1.0)
	var on_floor: bool = player.is_on_floor()

	_update_sway_spring(speed_ratio, delta)
	_update_turn_sway(delta)
	_update_recoil(delta)
	_update_muzzle_flash(delta)
	_update_pose(delta)

	var ground_target: float = 1.0 if on_floor else 0.0
	_ground_blend = lerpf(_ground_blend, ground_target, 1.0 - exp(-bob_ground_blend_speed * delta))

	var bob_position: Vector3 = _get_bob_position(horizontal_speed, speed_ratio, delta)
	var bob_roll: float = deg_to_rad(bob_roll_degrees) * sin(_bob_phase) * speed_ratio * _ground_blend
	var breath_position: Vector3 = _get_breath_position(speed_ratio)

	var reload_weight: float = _get_reload_pose_weight()
	position = (
		base_position
		+ _pose_position
		+ _sway_position
		+ _turn_position
		+ _recoil_position
		+ (reload_position_offset * reload_weight)
		+ bob_position
		+ breath_position
	)
	rotation = (
		_degrees_to_radians(base_rotation_degrees)
		+ _pose_rotation
		+ (_degrees_to_radians(reload_rotation_degrees) * reload_weight)
		+ _sway_rotation
		+ _turn_rotation
		+ _recoil_rotation
		+ Vector3(0.0, 0.0, bob_roll)
	)


func _update_sway_spring(speed_ratio: float, delta: float) -> void:
	var move_input: Vector2 = _player_vector2(METHOD_GET_MOVE_INPUT, Vector2.ZERO)
	var vertical_velocity: float = _player_float(METHOD_GET_VERTICAL_VELOCITY, 0.0)
	var jump_feedback: float = maxf(_player_float(METHOD_GET_RECENT_JUMP_FEEDBACK, 0.0), 0.0)
	var landing_impact: float = maxf(_player_float(METHOD_GET_RECENT_LANDING_IMPACT, 0.0), 0.0)
	var air_amount: float = 1.0 - _ground_blend

	# Strafe shifts and rolls the gun away from the move direction; forward pulls it in.
	var target_position: Vector3 = Vector3(
		-move_input.x * strafe_position,
		0.0,
		-move_input.y * forward_position
	) * speed_ratio
	var target_rotation: Vector3 = Vector3(0.0, 0.0, -move_input.x * deg_to_rad(strafe_roll_degrees) * speed_ratio)

	target_position.y += clampf(-vertical_velocity * air_velocity_position, -max_air_position, max_air_position) * air_amount
	target_rotation.x += deg_to_rad(
		clampf(vertical_velocity * air_velocity_rotation_degrees, -max_air_rotation_degrees, max_air_rotation_degrees)
	) * air_amount

	target_position += (jump_kick_position * jump_feedback) + (landing_kick_position * landing_impact)
	target_rotation += (_degrees_to_radians(jump_kick_rotation_degrees) * jump_feedback)
	target_rotation += (_degrees_to_radians(landing_kick_rotation_degrees) * landing_impact)

	_sway_position_velocity += (target_position - _sway_position) * sway_spring_stiffness * delta
	_sway_rotation_velocity += (target_rotation - _sway_rotation) * sway_spring_stiffness * delta
	var damping: float = exp(-sway_spring_damping * delta)
	_sway_position_velocity *= damping
	_sway_rotation_velocity *= damping
	_sway_position += _sway_position_velocity * delta
	_sway_rotation += _sway_rotation_velocity * delta


func _update_turn_sway(delta: float) -> void:
	var yaw: float = _head_float(METHOD_GET_YAW, 0.0)
	var pitch: float = _head_float(METHOD_GET_PITCH, 0.0)
	if not _has_last_look_angles:
		_last_yaw = yaw
		_last_pitch = pitch
		_has_last_look_angles = true

	# Degrees per second the camera turned this frame. Positive yaw is turning left, positive pitch is looking up.
	var safe_delta: float = maxf(delta, 0.0001)
	var max_speed: float = maxf(max_turn_speed_degrees, 0.0)
	var raw_turn_speed: Vector2 = Vector2(
		clampf(rad_to_deg(angle_difference(_last_yaw, yaw)) / safe_delta, -max_speed, max_speed),
		clampf(rad_to_deg(pitch - _last_pitch) / safe_delta, -max_speed, max_speed)
	)
	_last_yaw = yaw
	_last_pitch = pitch
	if not enable_turn_sway:
		raw_turn_speed = Vector2.ZERO

	_turn_speed = _turn_speed.lerp(raw_turn_speed, 1.0 - exp(-maxf(turn_speed_smoothing, 0.001) * delta))

	# The gun lags behind the turn: it drifts and rotates opposite to where the camera is heading.
	var target_position: Vector3 = Vector3(
		_turn_speed.x * turn_sway_position.x,
		-_turn_speed.y * turn_sway_position.y,
		0.0
	)
	var target_rotation: Vector3 = Vector3(
		deg_to_rad(-_turn_speed.y * turn_sway_rotation.x),
		deg_to_rad(-_turn_speed.x * turn_sway_rotation.y),
		deg_to_rad(-_turn_speed.x * turn_sway_rotation.z)
	)

	_turn_position_velocity += (target_position - _turn_position) * turn_spring_stiffness * delta
	_turn_rotation_velocity += (target_rotation - _turn_rotation) * turn_spring_stiffness * delta
	var damping: float = exp(-turn_spring_damping * delta)
	_turn_position_velocity *= damping
	_turn_rotation_velocity *= damping
	_turn_position += _turn_position_velocity * delta
	_turn_rotation += _turn_rotation_velocity * delta


func _update_pose(delta: float) -> void:
	var sprint_blend: float = clampf(_player_float(METHOD_GET_SPRINT_RAMP_BLEND, 0.0), 0.0, 1.0)
	var slide_blend: float = clampf(_player_float(METHOD_GET_SLIDE_BLEND, 0.0), 0.0, 1.0)
	var lowered_blend: float = clampf(
		maxf(_player_float(METHOD_GET_CLIMB_BLEND, 0.0), _player_float(METHOD_GET_EDGE_PULL_OVER_BLEND, 0.0)),
		0.0,
		1.0
	)
	var active_blend: float = 1.0 - lowered_blend

	var target_position: Vector3 = (
		(sprint_position_offset * sprint_blend * (1.0 - slide_blend))
		+ (slide_position_offset * slide_blend)
	) * active_blend + (lowered_position_offset * lowered_blend)
	var target_rotation: Vector3 = (
		(_degrees_to_radians(sprint_rotation_degrees) * sprint_blend * (1.0 - slide_blend))
		+ (_degrees_to_radians(slide_rotation_degrees) * slide_blend)
	) * active_blend + (_degrees_to_radians(lowered_rotation_degrees) * lowered_blend)

	var pose_blend: float = 1.0 - exp(-pose_lerp_speed * delta)
	_pose_position = _pose_position.lerp(target_position, pose_blend)
	_pose_rotation = _pose_rotation.lerp(target_rotation, pose_blend)


func _get_bob_position(horizontal_speed: float, speed_ratio: float, delta: float) -> Vector3:
	var sprint_blend: float = clampf(_player_float(METHOD_GET_SPRINT_RAMP_BLEND, 0.0), 0.0, 1.0)
	var frequency: float = bob_frequency * lerpf(1.0, sprint_bob_frequency_multiplier, sprint_blend)
	if _ground_blend > 0.01:
		_bob_phase = fmod(_bob_phase + (horizontal_speed * frequency * delta), TAU)

	var amount: Vector2 = walk_bob_amount.lerp(sprint_bob_amount, sprint_blend)
	var strength: float = speed_ratio * _ground_blend
	# Side sway completes one cycle per two steps; the vertical dip lands on every step.
	return Vector3(
		sin(_bob_phase) * amount.x,
		(cos(_bob_phase * 2.0) - 1.0) * 0.5 * amount.y,
		0.0
	) * strength


func _get_breath_position(speed_ratio: float) -> Vector3:
	var idle_amount: float = breath_amount * (1.0 - speed_ratio)
	return Vector3(
		sin(_time * breath_speed * 0.5) * idle_amount * 0.5,
		sin(_time * breath_speed) * idle_amount,
		0.0
	)


func _head_float(method_name: StringName, fallback: float) -> float:
	if head == null or not head.has_method(method_name):
		return fallback
	return float(head.call(method_name))


func _disable_shadows(node: Node) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for child in node.get_children():
		_disable_shadows(child)


func _degrees_to_radians(degrees_value: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees_value.x), deg_to_rad(degrees_value.y), deg_to_rad(degrees_value.z))


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
