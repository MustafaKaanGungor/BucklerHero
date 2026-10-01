extends "res://Scripts/Enemies/melee_enemy.gd"

## Ranged enemy whose shot hits instantly.
## During the windup it shows an aiming laser that follows the player. aim_lock_time before
## firing the laser locks in place and turns bright: that is the moment to step out of the line
## or behind cover. The shot is a raycast along the locked line; enemies in the way are ignored,
## the level blocks it.

@export_group("Hitscan")
## Longest distance the shot reaches.
@export var shot_range: float = 32.0
## Seconds before firing when the aim stops following the player.
@export var aim_lock_time: float = 0.3
## The laser aims this far above the player's feet.
@export var aim_height: float = 1.2
## Height above the enemy's feet the shot leaves from.
@export var shot_height: float = 1.45
## How far in front of the body the shot leaves from.
@export var shot_forward_offset: float = 0.45
## Physics layers the shot collides with: the level and the player.
@export_flags_3d_physics var shot_collision_mask: int = 1

@export_group("Aim Laser")
## Laser color while it is still following the player.
@export var laser_tracking_color: Color = Color(1.0, 0.15, 0.1, 0.35)
## Laser color once the aim is locked.
@export var laser_locked_color: Color = Color(1.0, 0.85, 0.4, 0.9)
## Thickness of the laser in meters.
@export var laser_width: float = 0.025
## Seconds the shot's flash stays on screen after firing.
@export var shot_flash_time: float = 0.08
## Thickness of the shot's flash in meters.
@export var shot_flash_width: float = 0.07

var _aim_point: Vector3 = Vector3.ZERO
var _laser: MeshInstance3D
var _laser_material: StandardMaterial3D
var _laser_end: Vector3 = Vector3.ZERO
var _flash_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_create_laser()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_flash_timer = maxf(_flash_timer - delta, 0.0)
	if _state == State.WINDUP and _state_timer > aim_lock_time and _has_living_target():
		_aim_point = _get_target_aim_point()


func _process(delta: float) -> void:
	super._process(delta)
	_update_laser()


func _on_windup_started() -> void:
	_aim_point = _get_target_aim_point()


func _on_windup_cancelled() -> void:
	_flash_timer = 0.0


## Fires along the locked aim line.
func _strike() -> void:
	var origin: Vector3 = _get_shot_origin()
	var direction: Vector3 = _aim_point - origin
	if direction.length_squared() <= 0.0001:
		return

	direction = direction.normalized()
	var hit: Dictionary = _cast_shot(origin, origin + (direction * maxf(shot_range, 0.0)))
	_laser_end = Vector3(hit.get("position", origin + (direction * shot_range)))
	_flash_timer = maxf(shot_flash_time, 0.0)

	var collider: Node = hit.get("collider") as Node
	if collider == null or not collider.is_in_group(GROUP_PLAYER) or not collider.has_method(METHOD_TAKE_DAMAGE):
		return
	var hit_info: Dictionary = {
		"position": _laser_end,
		"direction": direction,
		"damage": attack_damage,
		"attacker": self,
	}
	if bool(collider.call(METHOD_TAKE_DAMAGE, attack_damage, hit_info)):
		attack_landed.emit(attack_damage)


## Raycast that passes through enemies (this one included) and stops at the player or the level.
func _cast_shot(from: Vector3, to: Vector3) -> Dictionary:
	var excluded_rids: Array[RID] = [get_rid()]
	for _attempt in range(8):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, shot_collision_mask, excluded_rids)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider: Node = hit.get("collider") as Node
		if collider == null or not collider.is_in_group(GROUP_ENEMIES):
			return hit
		excluded_rids.append(hit.get("rid"))
	return {}


func _get_shot_origin() -> Vector3:
	return _get_attack_origin(shot_height, shot_forward_offset)


func _get_target_aim_point() -> Vector3:
	if _target == null:
		return _aim_point
	return _target.global_position + (Vector3.UP * aim_height)


func _create_laser() -> void:
	var laser_mesh: BoxMesh = BoxMesh.new()
	laser_mesh.size = Vector3(1.0, 1.0, 1.0)
	_laser_material = StandardMaterial3D.new()
	_laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_material.disable_receive_shadows = true
	laser_mesh.material = _laser_material

	_laser = MeshInstance3D.new()
	_laser.mesh = laser_mesh
	_laser.top_level = true
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_laser.visible = false
	add_child(_laser)


## The laser runs from the gun to whatever the current aim line hits first.
func _update_laser() -> void:
	if _laser == null:
		return

	var is_aiming: bool = _state == State.WINDUP and not _is_dead and not _is_carried
	var is_flashing: bool = _flash_timer > 0.0
	if not is_aiming and not is_flashing:
		_laser.visible = false
		return

	var origin: Vector3 = _get_shot_origin()
	var laser_end: Vector3 = _laser_end
	var width: float = shot_flash_width
	var color: Color = laser_locked_color
	if is_aiming:
		var direction: Vector3 = _aim_point - origin
		if direction.length_squared() <= 0.0001:
			_laser.visible = false
			return
		var hit: Dictionary = _cast_shot(origin, origin + (direction.normalized() * maxf(shot_range, 0.0)))
		laser_end = Vector3(hit.get("position", origin + (direction.normalized() * shot_range)))
		width = laser_width
		var is_locked: bool = _state_timer <= aim_lock_time
		var windup_progress: float = 1.0 - clampf(_state_timer / maxf(attack_windup_time, 0.001), 0.0, 1.0)
		color = laser_locked_color if is_locked else Color(laser_tracking_color, laser_tracking_color.a * (0.4 + windup_progress * 0.6))

	var length: float = origin.distance_to(laser_end)
	if length <= 0.01:
		_laser.visible = false
		return

	_laser_material.albedo_color = color
	var up: Vector3 = Vector3.UP if absf((laser_end - origin).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	_laser.global_transform = Transform3D(Basis.looking_at(laser_end - origin, up), (origin + laser_end) * 0.5)
	_laser.scale = Vector3(width, width, length)
	_laser.visible = true
