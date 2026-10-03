extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## Hatchet and returning hatchet (same script, returns_on_kill picks which). A click throws it in an
## arc (thrown_hatchet.gd) for throw_damage. From the moment it leaves the hand until it is back,
## the weapon is unavailable: keys, cycling and the selector skip it, and the player is switched to
## the weapon used before it (or to nothing if the hatchet was the only one).
## - It drops where it hits; walking over it picks it up and puts it straight in hand.
## - returns_on_kill: a throw that kills its target flies back. It goes into the hand if the player
##   is still holding the weapon they were switched to after the throw; otherwise it just becomes
##   available again.
## - S rank: the throw picks the enemy nearest the crosshair (homing_cone_degrees, homing_range,
##   line of sight) and flies straight into it.
## A run restart or a new level puts a thrown hatchet back (reset_behaviour).

const ThrownHatchet = preload("res://Scripts/Weapons/thrown_hatchet.gd")

@export_group("Throw")
## Damage of a hit.
@export var throw_damage: float = 4.0
## Throw speed (m/s) and gravity on it (m/s²). The throw is aimed so the arc comes down on what the
## crosshair points at (within aim_max_distance; otherwise at a point aim_fallback_distance ahead).
@export var throw_speed: float = 22.0
@export var throw_gravity: float = 9.0
@export var aim_max_distance: float = 40.0
@export var aim_fallback_distance: float = 25.0
## Extra upward angle on top of the aimed arc (degrees).
@export var throw_up_degrees: float = 0.0
## Freeze, screen shake and push of a hit.
@export var hit_stop_time: float = 0.1
@export_range(0.0, 1.0) var hit_screen_shake: float = 0.3
@export var hit_impulse: float = 8.0
## Distance at which walking over a dropped hatchet picks it up (m).
@export var pickup_radius: float = 1.4
## Colour of the small light on a dropped hatchet.
@export var light_color: Color = Color(1.0, 0.8, 0.45)

@export_group("Return")
## Kills send it flying back to the player.
@export var returns_on_kill: bool = false
## Speed it flies back with (m/s).
@export var return_speed: float = 30.0

@export_group("Homing (S Rank)")
## Enemies within this angle of the crosshair and this range can be locked on to.
@export var homing_cone_degrees: float = 8.0
@export var homing_range: float = 40.0

var _projectile: Node3D
var _weapon_after_throw: StringName = &""
var _last_hit_killed: bool = false
var _throws: int = 0
var _returns: int = 0
var _pickups: int = 0


func is_available() -> bool:
	return _projectile == null or not is_instance_valid(_projectile)


func is_out() -> bool:
	return not is_available()


func get_projectile() -> Node3D:
	return _projectile


## Counters for tests: throws, returns after a kill, pickups.
func get_stats() -> Dictionary:
	return {"throws": _throws, "returns": _returns, "pickups": _pickups}


func get_player() -> Node3D:
	return weapons.call(&"get_player") as Node3D


func get_camera() -> Node3D:
	return weapons.call(&"get_camera") as Node3D


func on_strike_started(_attack: MeleeAttackData, empowered: bool) -> void:
	if not is_available():
		return
	var camera: Node3D = get_camera()
	if camera == null:
		return
	var camera_transform: Transform3D = camera.global_transform.orthonormalized()
	var forward: Vector3 = -camera_transform.basis.z
	var start: Vector3 = camera_transform.origin + forward * 0.6 + camera_transform.basis.x * 0.15 - camera_transform.basis.y * 0.15
	var direction: Vector3 = _get_throw_direction(camera_transform, start)
	var target: Node3D = null
	if empowered:
		target = weapons.call(&"find_aimed_enemy", homing_cone_degrees, homing_range) as Node3D
	var projectile: Node3D = Node3D.new()
	projectile.set_script(ThrownHatchet)
	projectile.set(&"speed", throw_speed)
	projectile.set(&"gravity", throw_gravity)
	projectile.set(&"return_speed", return_speed)
	projectile.set(&"pickup_radius", pickup_radius)
	projectile.set(&"collision_mask", int(weapons.call(&"get_hit_collision_mask")))
	projectile.set(&"light_color", light_color)
	weapons.call(&"spawn_in_world", projectile)
	projectile.call(&"launch", self, start, direction, _make_visual(), target, weapons.call(&"get_excluded_rids"))
	_projectile = projectile
	_throws += 1
	weapons.call(&"notify_availability_changed", weapon_id)
	# Switch after this physics step: the attack that threw it is still being updated.
	_switch_away.call_deferred()


## Aims the arc so it comes down on what the crosshair points at: the straight line to that point,
## tilted up by the angle that makes up for the drop over the flight. With nothing in reach the
## throw is aimed at a point aim_fallback_distance ahead, so it still arcs.
func _get_throw_direction(camera_transform: Transform3D, start: Vector3) -> Vector3:
	var forward: Vector3 = -camera_transform.basis.z
	var aim_point: Vector3 = camera_transform.origin + forward * aim_fallback_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera_transform.origin, camera_transform.origin + forward * aim_max_distance, int(weapons.call(&"get_hit_collision_mask")), weapons.call(&"get_excluded_rids"))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim_point = Vector3(hit.get("position", aim_point))
	var to_aim: Vector3 = aim_point - start
	var distance: float = to_aim.length()
	if distance < 0.5:
		return forward
	var flight_time: float = distance / maxf(throw_speed, 0.1)
	var drop: float = 0.5 * throw_gravity * flight_time * flight_time
	var lift: float = atan2(drop, distance) + deg_to_rad(throw_up_degrees)
	var flat_axis: Vector3 = to_aim.cross(Vector3.UP)
	if flat_axis.length_squared() <= 0.0001:
		return to_aim.normalized()
	return to_aim.normalized().rotated(flat_axis.normalized(), lift).normalized()


func _switch_away() -> void:
	weapons.call(&"switch_away_from", weapon_id)
	_weapon_after_throw = StringName(weapons.call(&"get_equipped_weapon"))


## Called by the thrown hatchet when it hits something hittable. Returns true if it killed it.
func hit_target(projectile: Node3D, target: Node3D, point: Vector3, direction: Vector3) -> bool:
	_last_hit_killed = false
	weapons.call(&"deliver_hit", weapon_id, target, {
		"position": point,
		"direction": (direction + Vector3.UP * 0.15).normalized(),
		"damage": throw_damage,
	}, hit_stop_time, hit_screen_shake, hit_impulse)
	if _last_hit_killed and returns_on_kill and projectile != null and is_instance_valid(projectile):
		projectile.call(&"start_return")
		return true
	return _last_hit_killed


func on_hit_landed(_target: Node3D, _hit_info: Dictionary, killed: bool) -> void:
	_last_hit_killed = killed


## The level stopped it (no enemy): a dull thunk.
func on_world_hit(projectile: Node3D) -> void:
	var audio: Node = weapons.get_node_or_null(^"Audio")
	if audio != null and audio.has_method(&"play_sound") and projectile != null:
		audio.call(&"play_sound", &"land_hatchet")


## The player walked over the dropped hatchet: it goes straight into the hand.
func collect(projectile: Node3D) -> void:
	_clear_projectile(projectile)
	_pickups += 1
	weapons.call(&"notify_availability_changed", weapon_id)
	weapons.call(&"equip", weapon_id)
	var audio: Node = weapons.get_node_or_null(^"Audio")
	if audio != null and audio.has_method(&"play_sound"):
		audio.call(&"play_sound", &"pickup_hatchet")


## Came back after a kill (or was lost and handed back).
func on_returned(projectile: Node3D) -> void:
	var was_returning: bool = projectile != null and is_instance_valid(projectile) and bool(projectile.call(&"is_returning"))
	_clear_projectile(projectile)
	weapons.call(&"notify_availability_changed", weapon_id)
	if not was_returning:
		return
	_returns += 1
	var audio: Node = weapons.get_node_or_null(^"Audio")
	if audio != null and audio.has_method(&"play_sound"):
		audio.call(&"play_sound", &"pickup_hatchet")
	# Back into the hand only if the player didn't switch since the throw.
	var equipped: StringName = StringName(weapons.call(&"get_equipped_weapon"))
	if equipped == _weapon_after_throw and not bool(weapons.call(&"is_attacking")):
		weapons.call(&"equip", weapon_id)


func reset_behaviour() -> void:
	if _projectile != null and is_instance_valid(_projectile):
		_clear_projectile(_projectile)
		weapons.call(&"notify_availability_changed", weapon_id)


func _clear_projectile(projectile: Node3D) -> void:
	if projectile != null and is_instance_valid(projectile):
		projectile.queue_free()
	_projectile = null


## A copy of this weapon's meshes, centred on the hatchet's head end, for the thrown hatchet.
func _make_visual() -> Node3D:
	var visual: Node3D = Node3D.new()
	for child in get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh == null:
			continue
		var copy: MeshInstance3D = MeshInstance3D.new()
		copy.mesh = mesh.mesh
		copy.transform = mesh.transform
		copy.position -= Vector3(0.0, 0.12, 0.0)
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		visual.add_child(copy)
	return visual
