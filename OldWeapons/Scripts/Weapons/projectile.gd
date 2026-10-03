extends Node3D

## A fast bullet that exists in the world.
## Every physics tick it raycasts the segment it is about to travel, so it can't skip
## through thin walls even at very high speed.
## Future abilities can find live bullets with get_tree().get_nodes_in_group(&"projectiles")
## and use time_scale, stop(), resume() or redirect() to slow, freeze or deflect them.

signal hit_something(hit: Dictionary)

const GROUP_PROJECTILES: StringName = &"projectiles"
const METHOD_ON_PROJECTILE_HIT: StringName = &"on_projectile_hit"
const METHOD_PLACE_DECAL: StringName = &"place"
const GROUP_NO_IMPACT_DECALS: StringName = &"no_impact_decals"

@export_group("Motion")
## Meters per second. Usually overridden by the weapon that fires it.
@export var speed: float = 180.0
## Downward acceleration. 0 keeps bullets perfectly straight.
@export var gravity: float = 0.0
## Seconds before the bullet removes itself if it hits nothing. Counts scaled time.
@export var lifetime: float = 3.0
## Physics layers the bullet collides with.
@export_flags_3d_physics var collision_mask: int = 1
## Lets Area3D nodes (for example future shields) stop bullets.
@export var collide_with_areas: bool = false

@export_group("Hit")
## Damage passed to objects that implement on_projectile_hit(hit).
@export var damage: float = 1.0
## Impulse applied to RigidBody3D objects that get hit.
@export var physics_impulse: float = 4.0
## Bullet hole spawned on the hit surface. Leave empty for no holes.
@export var impact_decal_scene: PackedScene = preload("res://Scenes/Weapons/impact_decal.tscn")

@export_group("Tracer")
## Longest visible streak behind the bullet. It grows from zero so it never streaks back through the camera.
@export var tracer_length: float = 1.4
@export var tracer_path: NodePath = NodePath("Tracer")

## Multiplies how fast this bullet moves and ages. 0 freezes it in place.
var time_scale: float = 1.0
var velocity: Vector3 = Vector3.ZERO
var excluded_rids: Array[RID] = []
var _age: float = 0.0
var _traveled: float = 0.0
var _tracer: Node3D


func _ready() -> void:
	add_to_group(GROUP_PROJECTILES)
	_tracer = get_node_or_null(tracer_path) as Node3D
	_update_tracer()


## Places the bullet and starts it moving. Call after the bullet is added to the scene tree.
func launch(from: Vector3, direction: Vector3, exclude: Array[RID] = []) -> void:
	excluded_rids = exclude
	global_position = from
	velocity = direction.normalized() * speed
	_traveled = 0.0
	_orient_to_velocity()
	_update_tracer()
	reset_physics_interpolation()


## Freezes the bullet in the air.
func stop() -> void:
	time_scale = 0.0


func resume() -> void:
	time_scale = 1.0


## Sends the bullet in a new direction. Keeps the current speed unless a new one is given.
func redirect(new_direction: Vector3, new_speed: float = -1.0) -> void:
	var final_speed: float = velocity.length() if new_speed < 0.0 else new_speed
	velocity = new_direction.normalized() * final_speed
	_orient_to_velocity()


func _physics_process(delta: float) -> void:
	var step_delta: float = delta * maxf(time_scale, 0.0)
	if step_delta <= 0.0:
		return

	_age += step_delta
	velocity.y -= gravity * step_delta

	var from: Vector3 = global_position
	var to: Vector3 = from + (velocity * step_delta)
	var hit: Dictionary = _raycast(from, to)
	if not hit.is_empty():
		global_position = hit.position
		_handle_hit(hit)
		return

	_traveled += from.distance_to(to)
	global_position = to
	_orient_to_velocity()
	_update_tracer()

	if _age >= lifetime:
		queue_free()


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, excluded_rids)
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _handle_hit(ray_hit: Dictionary) -> void:
	var direction: Vector3 = velocity.normalized()
	var collider: Object = ray_hit.collider
	var hit: Dictionary = {
		"position": ray_hit.position,
		"normal": ray_hit.normal,
		"direction": direction,
		"collider": collider,
		"damage": damage,
		"projectile": self,
	}

	# Hole first, so an object that breaks from this hit can clean it up along with its other holes.
	_spawn_impact_decal(collider, ray_hit.position, ray_hit.normal)

	if collider != null and collider.has_method(METHOD_ON_PROJECTILE_HIT):
		collider.call(METHOD_ON_PROJECTILE_HIT, hit)

	var rigid_body: RigidBody3D = collider as RigidBody3D
	if rigid_body != null and physics_impulse > 0.0:
		rigid_body.sleeping = false
		rigid_body.apply_impulse(direction * physics_impulse, ray_hit.position - rigid_body.global_position)

	hit_something.emit(hit)
	queue_free()


func _spawn_impact_decal(collider: Object, hit_position: Vector3, hit_normal: Vector3) -> void:
	if impact_decal_scene == null:
		return

	var collider_node: Node3D = collider as Node3D
	if collider_node != null and collider_node.is_in_group(GROUP_NO_IMPACT_DECALS):
		return

	# Parent to the hit object so the hole follows moving bodies and disappears with the object.
	var decal_parent: Node = collider_node
	if decal_parent == null or not decal_parent.is_inside_tree() or collider is Area3D:
		decal_parent = get_tree().current_scene
	if decal_parent == null:
		return

	var decal: Node3D = impact_decal_scene.instantiate() as Node3D
	if decal == null:
		return
	decal_parent.add_child(decal)
	decal.call(METHOD_PLACE_DECAL, hit_position, hit_normal)


func _orient_to_velocity() -> void:
	if velocity.length_squared() <= 0.000001:
		return

	var direction: Vector3 = velocity.normalized()
	var up: Vector3 = Vector3.UP
	if absf(direction.dot(up)) > 0.99:
		up = Vector3.FORWARD
	global_basis = Basis.looking_at(direction, up)


func _update_tracer() -> void:
	if _tracer == null:
		return

	# Tracer mesh is 1 unit long; stretch it behind the bullet (+Z is behind when facing -Z).
	var length: float = clampf(_traveled, 0.001, maxf(tracer_length, 0.001))
	_tracer.scale = Vector3(1.0, 1.0, length)
	_tracer.position = Vector3(0.0, 0.0, length * 0.5)
