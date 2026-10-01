extends StaticBody3D

## Target that reacts to projectile hits.
## It wobbles when hit, breaks into physics fragments when its health runs out,
## and pops back in after a delay. Collision is built from the model's mesh at startup,
## so swapping the model in the scene just works.

signal hit(hit_info: Dictionary)
signal destroyed
signal respawned

@export var model_path: NodePath = NodePath("Model")

@export_group("Health")
## Damage needed to break the target. The pistol does 1 damage per shot.
@export var max_health: float = 1.0
## Seconds before a broken target comes back. 0 or less keeps it broken.
@export var respawn_time: float = 3.0
## Seconds the respawn pop-in animation takes.
@export var respawn_pop_time: float = 0.3

@export_group("Hit Wobble")
## Tilt added by a hit on the target's edge. Hits closer to the center tilt it less.
@export var wobble_degrees_per_hit: float = 16.0
@export var wobble_spring_stiffness: float = 180.0
## Lower values let the target swing back and forth longer.
@export var wobble_spring_damping: float = 7.0

@export_group("Fragments")
## Models used for the pieces, picked in turn.
@export var fragment_scenes: Array[PackedScene] = [
	preload("res://Assets/Models/Weapons/Models/GLB format/target-fragment-large.glb"),
	preload("res://Assets/Models/Weapons/Models/GLB format/target-fragment-small.glb"),
]
@export var fragment_count: int = 8
## Scale applied to fragment models. Match the target model's scale.
@export var fragment_scale: float = 3.0
## Pieces spawn within this distance of the target center.
@export var fragment_spawn_radius: float = 0.35
@export var fragment_mass: float = 0.15
## Push along the bullet direction.
@export var fragment_forward_impulse: float = 0.35
## Push away from the target center.
@export var fragment_outward_impulse: float = 0.3
## Upward push so pieces pop up before falling.
@export var fragment_up_impulse: float = 0.25
## Random spin strength.
@export var fragment_spin_impulse: float = 0.01
## Seconds pieces stay before shrinking away.
@export var fragment_lifetime: float = 4.0
@export var fragment_shrink_time: float = 0.4
## Layer 2 keeps pieces from blocking the player or stopping bullets.
@export_flags_3d_physics var fragment_collision_layer: int = 2
## Pieces land on the world (layer 1) and bump into each other (layer 2).
@export_flags_3d_physics var fragment_collision_mask: int = 3

var _model: Node3D
var _model_base_transform: Transform3D = Transform3D.IDENTITY
var _model_radius: float = 0.5
var _collision_shapes: Array[CollisionShape3D] = []
var _health: float = 1.0
var _is_destroyed: bool = false
var _respawn_timer: float = 0.0
var _pop_progress: float = 1.0
var _wobble: Vector2 = Vector2.ZERO
var _wobble_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	_model = get_node_or_null(model_path) as Node3D
	if _model != null:
		_model_base_transform = _model.transform
		_build_collision()
	_health = maxf(max_health, 0.001)


## Called by projectiles. hit_info has position, normal, direction, damage and projectile.
func on_projectile_hit(hit_info: Dictionary) -> void:
	_take_hit(hit_info)


## Called by melee weapons. hit_info has position, normal, direction, damage, weapon and attacker.
func on_melee_hit(hit_info: Dictionary) -> void:
	_take_hit(hit_info)


func _take_hit(hit_info: Dictionary) -> void:
	if _is_destroyed:
		return

	hit.emit(hit_info)
	_add_wobble(hit_info)
	_health -= float(hit_info.get("damage", 1.0))
	if _health <= 0.0:
		_destroy(hit_info)


func is_destroyed() -> bool:
	return _is_destroyed


func _process(delta: float) -> void:
	if _model == null:
		return

	if _is_destroyed:
		if respawn_time > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return

	_wobble_velocity += -_wobble * wobble_spring_stiffness * delta
	_wobble_velocity *= exp(-wobble_spring_damping * delta)
	_wobble += _wobble_velocity * delta
	_pop_progress = minf(_pop_progress + (delta / maxf(respawn_pop_time, 0.001)), 1.0)

	var wobble_basis: Basis = Basis.from_euler(Vector3(_wobble.x, _wobble.y, 0.0))
	var pop_scale: float = maxf(_ease_out_back(_pop_progress), 0.001)
	_model.transform = Transform3D(
		(wobble_basis * _model_base_transform.basis).scaled(Vector3.ONE * pop_scale),
		_model_base_transform.origin
	)


func _add_wobble(hit_info: Dictionary) -> void:
	var local_point: Vector3 = to_local(Vector3(hit_info.get("position", global_position))) - _model_base_transform.origin
	var world_direction: Vector3 = Vector3(hit_info.get("direction", -global_basis.z))
	var local_direction: Vector3 = (global_basis.inverse() * world_direction).normalized()
	var edge_amount: Vector2 = Vector2(local_point.y, -local_point.x) / maxf(_model_radius, 0.01)
	edge_amount = edge_amount.limit_length(1.0)

	# The side that was hit gets pushed along the bullet direction.
	_wobble += edge_amount * local_direction.z * deg_to_rad(wobble_degrees_per_hit)


func _destroy(hit_info: Dictionary) -> void:
	_is_destroyed = true
	_respawn_timer = respawn_time
	_model.visible = false
	_set_collision_enabled(false)
	_remove_impact_decals()
	_spawn_fragments(hit_info)
	destroyed.emit()


func _respawn() -> void:
	_is_destroyed = false
	_health = maxf(max_health, 0.001)
	_wobble = Vector2.ZERO
	_wobble_velocity = Vector2.ZERO
	_pop_progress = 0.0
	_model.transform = Transform3D(_model_base_transform.basis.scaled(Vector3.ONE * 0.001), _model_base_transform.origin)
	_model.visible = true
	_set_collision_enabled(true)
	respawned.emit()


func _set_collision_enabled(enabled: bool) -> void:
	for collision_shape in _collision_shapes:
		collision_shape.set_deferred(&"disabled", not enabled)


func _remove_impact_decals() -> void:
	# Bullet holes are parented to the body that was hit; they shouldn't float in the air.
	for child in get_children():
		if child is Decal:
			child.queue_free()


func _build_collision() -> void:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for mesh_instance in _find_mesh_instances(_model):
		var faces: PackedVector3Array = mesh_instance.mesh.get_faces()
		var to_body: Transform3D = global_transform.affine_inverse() * mesh_instance.global_transform
		for i in range(faces.size()):
			faces[i] = to_body * faces[i]

		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		collision_shape.shape = shape
		add_child(collision_shape)
		_collision_shapes.append(collision_shape)

		var mesh_bounds: AABB = to_body * mesh_instance.mesh.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true

	if has_bounds:
		_model_radius = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 0.5


func _spawn_fragments(hit_info: Dictionary) -> void:
	if fragment_scenes.is_empty() or fragment_count <= 0:
		return

	var fragment_parent: Node = get_tree().current_scene
	if fragment_parent == null:
		fragment_parent = get_parent()

	var center: Vector3 = _model.global_position
	var bullet_direction: Vector3 = Vector3(hit_info.get("direction", -global_basis.z)).normalized()
	for i in range(fragment_count):
		var fragment_scene: PackedScene = fragment_scenes[i % fragment_scenes.size()]
		if fragment_scene == null:
			continue

		var body: RigidBody3D = _create_fragment_body(fragment_scene)
		fragment_parent.add_child(body)

		var spread: Vector3 = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.3, 0.3))
		var offset: Vector3 = global_basis * (spread.limit_length(1.0) * fragment_spawn_radius)
		var random_rotation: Vector3 = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		body.global_transform = Transform3D(Basis.from_euler(random_rotation), center + offset)
		body.reset_physics_interpolation()

		var outward: Vector3 = offset.normalized() if offset.length_squared() > 0.0001 else Vector3.UP
		var impulse: Vector3 = (
			(bullet_direction * fragment_forward_impulse)
			+ (outward * fragment_outward_impulse)
			+ (Vector3.UP * fragment_up_impulse)
		) * randf_range(0.7, 1.3)
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fragment_spin_impulse)


func _create_fragment_body(fragment_scene: PackedScene) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = "TargetFragment"
	body.mass = maxf(fragment_mass, 0.001)
	body.collision_layer = fragment_collision_layer
	body.collision_mask = fragment_collision_mask

	var model: Node3D = fragment_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * fragment_scale
	body.add_child(model)

	# Box collision sized from the (scaled) fragment mesh.
	var bounds: AABB = _get_local_mesh_bounds(model, Transform3D(Basis.from_scale(model.scale), Vector3.ZERO))
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.02), maxf(bounds.size.y, 0.02), maxf(bounds.size.z, 0.02))
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.shape = box
	collision_shape.position = bounds.get_center()
	body.add_child(collision_shape)

	var tween: Tween = body.create_tween()
	tween.tween_interval(maxf(fragment_lifetime, 0.0))
	tween.tween_property(model, ^"scale", Vector3.ZERO, maxf(fragment_shrink_time, 0.01))
	tween.tween_callback(body.queue_free)
	return body


func _get_local_mesh_bounds(node: Node, node_transform: Transform3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		bounds = node_transform * mesh_instance.mesh.get_aabb()
		has_bounds = true

	for child in node.get_children():
		var child_node: Node3D = child as Node3D
		if child_node == null:
			continue
		var child_bounds: AABB = _get_local_mesh_bounds(child_node, node_transform * child_node.transform)
		if child_bounds.size == Vector3.ZERO:
			continue
		bounds = child_bounds if not has_bounds else bounds.merge(child_bounds)
		has_bounds = true
	return bounds


func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		found.append(mesh_instance)
	for child in node.get_children():
		found.append_array(_find_mesh_instances(child))
	return found


func _ease_out_back(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	var overshoot: float = 1.70158
	var shifted: float = t - 1.0
	return 1.0 + ((overshoot + 1.0) * shifted * shifted * shifted) + (overshoot * shifted * shifted)
