extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## Hook: mobility and control. No S-rank version.
## Click (yank): the hook flies straight ahead up to yank_reach. A light enemy it catches is pulled to
## about yank_stop_distance in front of the player and staggered; a heavy one (brute, mortar) stays
## put and pulls the player to it instead (a dash that stops heavy_stop_distance short), and is
## staggered. Either way it takes yank_damage. A miss just flies out and back.
## Hold (grapple): a camera ray up to MovementGrapple.grapple_range. On the level the hook latches
## and the player state takes over (player.start_grapple: zip while attack is held, swing while jump
## is held too, let go to keep the momentum). An anchor just below a ledge top is moved onto the
## top, so zipping to a platform edge pops the player onto it. On an enemy it does the yank instead.
## The rope (hook_rope.gd) is drawn from the hook in hand to the hook head.

const HookRope = preload("res://Scripts/Weapons/hook_rope.gd")

@export_group("Yank")
## How far the yank reaches (m).
@export var yank_reach: float = 9.0
## Light enemies end up this far in front of the player (m), over yank_time seconds.
@export var yank_stop_distance: float = 1.5
@export var yank_time: float = 0.25
## Upward speed added to the pull so the enemy leaves the ground instead of dragging (m/s).
@export var yank_lift: float = 3.0
## Stagger and damage of a yanked enemy.
@export var yank_stagger_time: float = 0.6
@export var yank_damage: float = 1.0
## Heavy enemies: the player is pulled to this far short of them, over heavy_pull_time seconds.
@export var heavy_stop_distance: float = 1.8
@export var heavy_pull_time: float = 0.25
## Screen shake of a catch.
@export_range(0.0, 1.0) var yank_screen_shake: float = 0.25

@export_group("Rope")
## Rope start, as an offset from the hook node (the tip in hand).
@export var rope_origin_offset: Vector3 = Vector3(0.0, 0.22, 0.0)
## Seconds the rope shows after a yank or a miss.
@export var rope_flash_time: float = 0.25

var _rope: Node3D
var _rope_timer: float = 0.0
var _rope_target: Node3D
var _rope_point: Vector3 = Vector3.ZERO
var _is_grappling: bool = false
var _yanks: int = 0
var _heavy_pulls: int = 0


func setup(owner_weapons: Node) -> void:
	super.setup(owner_weapons)
	_rope = MeshInstance3D.new()
	_rope.set_script(HookRope)
	add_child(_rope)


## Counters for tests.
func get_stats() -> Dictionary:
	return {"yanks": _yanks, "heavy_pulls": _heavy_pulls}


func on_strike_started(_attack: MeleeAttackData, _empowered: bool) -> void:
	_yank(yank_reach)


## Hold: latch the grapple, or yank if the ray finds an enemy.
func on_hold_started() -> bool:
	var hit: Dictionary = _cast_from_camera(MovementGrapple.grapple_range)
	if hit.is_empty():
		_show_miss(MovementGrapple.grapple_range)
		return false
	var collider: Node3D = hit.get("collider") as Node3D
	if collider != null and collider.has_method(&"on_melee_hit"):
		weapons.call(&"register_custom_attack", weapon_id)
		weapons.call(&"set_recover", weapon_id, attack_data.get_duration() if attack_data != null else 0.8)
		_catch(collider, Vector3(hit.get("position", collider.global_position)))
		return false
	var anchor: Vector3 = Vector3(hit.get("position", Vector3.ZERO))
	var normal: Vector3 = Vector3(hit.get("normal", Vector3.UP))
	var ledge: Dictionary = _find_ledge_top(anchor, normal)
	if not ledge.is_empty():
		anchor = Vector3(ledge["position"])
		normal = Vector3.UP
	var player: Node3D = weapons.call(&"get_player") as Node3D
	if player == null or not player.has_method(&"start_grapple") or not bool(player.call(&"start_grapple", anchor, normal)):
		return false
	weapons.call(&"register_custom_attack", weapon_id)
	_is_grappling = true
	_rope_target = null
	_rope_point = anchor
	_play(&"grapple_latch")
	return true


func on_hold_updated(_delta: float, _held_time: float) -> bool:
	var player: Node3D = weapons.call(&"get_player") as Node3D
	if player == null or not bool(player.call(&"is_grappling")):
		# The player side ended it (arrived, rope broke, stamina, a climb took over).
		_is_grappling = false
		return false
	return true


func on_hold_released(_held_time: float) -> void:
	_release()


func on_hold_cancelled() -> void:
	_release()


func on_unequipped() -> void:
	_release()
	_rope_timer = 0.0
	if _rope != null:
		_rope.call(&"hide_rope")


func is_hook_grappling() -> bool:
	return _is_grappling


func _release() -> void:
	if not _is_grappling:
		return
	_is_grappling = false
	var player: Node3D = weapons.call(&"get_player") as Node3D
	if player != null and player.has_method(&"release_grapple"):
		player.call(&"release_grapple")


func _yank(reach: float) -> void:
	var hit: Dictionary = _cast_from_camera(reach)
	var collider: Node3D = null if hit.is_empty() else hit.get("collider") as Node3D
	if collider == null or not collider.has_method(&"on_melee_hit"):
		_show_miss(reach if hit.is_empty() else Vector3(hit.get("position", Vector3.ZERO)).distance_to((weapons.call(&"get_camera") as Node3D).global_position))
		return
	_catch(collider, Vector3(hit.get("position", collider.global_position)))


## Pulls a light enemy in, or the player to a heavy one; staggers and damages it.
func _catch(target: Node3D, point: Vector3) -> void:
	var player: Node3D = weapons.call(&"get_player") as Node3D
	if player == null:
		return
	var heavy: bool = target.has_method(&"is_shield_charge_blocker") and bool(target.call(&"is_shield_charge_blocker"))
	var to_target: Vector3 = target.global_position - player.global_position
	var flat: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	var direction: Vector3 = flat.normalized() if flat.length_squared() > 0.0001 else -player.global_basis.z
	weapons.call(&"deliver_hit", weapon_id, target, {
		"position": point,
		"direction": -direction,
		"damage": yank_damage,
		"knockback_multiplier": 0.0,
	}, 0.04, yank_screen_shake)
	if not is_instance_valid(target) or (target.has_method(&"is_dead") and bool(target.call(&"is_dead"))):
		_flash_rope(null, point)
		return
	if heavy:
		_heavy_pulls += 1
		var distance: float = maxf(flat.length() - heavy_stop_distance, 0.0)
		if distance > 0.0 and player.has_method(&"start_dash"):
			player.call(&"start_dash", direction, distance, heavy_pull_time)
		if target.has_method(&"on_hook_pull"):
			target.call(&"on_hook_pull", {"pull_velocity": Vector3.ZERO, "stagger_time": yank_stagger_time})
	else:
		_yanks += 1
		var destination: Vector3 = player.global_position + direction * yank_stop_distance
		if target.has_method(&"on_hook_pull"):
			target.call(&"on_hook_pull", {"pull_to": destination, "pull_time": yank_time, "lift": yank_lift, "stagger_time": yank_stagger_time})
	_flash_rope(target, point)
	_play(&"grapple_latch")


## Ledge assist: an anchor on a wall just below a top edge moves onto the top.
func _find_ledge_top(anchor: Vector3, normal: Vector3) -> Dictionary:
	if MovementGrapple.is_top_surface(normal) or absf(normal.y) > 0.5:
		return {}
	var into_wall: Vector3 = -Vector3(normal.x, 0.0, normal.z).normalized()
	var probe: Vector3 = anchor + into_wall * 0.35
	var from: Vector3 = probe + Vector3.UP * MovementGrapple.ledge_search_height
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, probe, int(weapons.call(&"get_hit_collision_mask")), weapons.call(&"get_excluded_rids"))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or Vector3(hit.get("normal", Vector3.ZERO)).y < MovementGrapple.top_surface_normal_y:
		return {}
	# The ray must have started in open air above the ledge.
	var start_query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	start_query.position = from
	start_query.collision_mask = int(weapons.call(&"get_hit_collision_mask"))
	if not get_world_3d().direct_space_state.intersect_point(start_query, 1).is_empty():
		return {}
	# Just above the edge, so the rope clears the corner and the arrival lands the player on top.
	return {"position": Vector3(hit.get("position", anchor)) + Vector3.UP * 0.4 - into_wall * 0.15}


func _cast_from_camera(reach: float) -> Dictionary:
	var camera: Node3D = weapons.call(&"get_camera") as Node3D
	if camera == null:
		return {}
	var camera_transform: Transform3D = camera.global_transform.orthonormalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera_transform.origin, camera_transform.origin - camera_transform.basis.z * reach, int(weapons.call(&"get_hit_collision_mask")), weapons.call(&"get_excluded_rids"))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	# Dead enemies (still in the tree for a moment) don't count.
	if not hit.is_empty():
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.has_method(&"is_dead") and bool(collider.call(&"is_dead")):
			return {}
	return hit


func _show_miss(distance: float) -> void:
	var camera: Node3D = weapons.call(&"get_camera") as Node3D
	if camera == null:
		return
	_flash_rope(null, camera.global_position - camera.global_transform.basis.z * minf(distance, yank_reach))


func _flash_rope(target: Node3D, point: Vector3) -> void:
	_rope_target = target
	_rope_point = point
	_rope_timer = rope_flash_time


func _process(delta: float) -> void:
	if _rope == null:
		return
	var origin: Vector3 = global_transform * rope_origin_offset
	if _is_grappling:
		_rope.call(&"set_points", origin, _rope_point)
		return
	if _rope_timer <= 0.0:
		_rope.call(&"hide_rope")
		return
	_rope_timer -= delta
	var end: Vector3 = _rope_point
	if _rope_target != null and is_instance_valid(_rope_target):
		end = _rope_target.global_position + Vector3.UP * 1.0
	# The hook flies out over the first half and is reeled back over the second.
	var t: float = 1.0 - clampf(_rope_timer / maxf(rope_flash_time, 0.01), 0.0, 1.0)
	var reach: float = minf(t * 3.0, 1.0) if t < 0.5 else 1.0 - (t - 0.5) * 2.0
	_rope.call(&"set_points", origin, origin.lerp(end, clampf(reach, 0.0, 1.0)))


func _play(sound: StringName) -> void:
	var audio: Node = weapons.get_node_or_null(^"Audio")
	if audio != null and audio.has_method(&"play_sound"):
		audio.call(&"play_sound", sound)
