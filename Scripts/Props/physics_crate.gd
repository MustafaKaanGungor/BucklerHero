extends RigidBody3D

## Crate that bullets and bumps knock around.
## At startup its box collision is resized to fit the model, and any static collision
## baked into the model by the import script is removed so it can't fight the rigid body.

@export var model_path: NodePath = NodePath("Model")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")
## Resize the collision box to the model's bounds when the game starts.
@export var fit_collision_to_model: bool = true


func _ready() -> void:
	var model: Node3D = get_node_or_null(model_path) as Node3D
	if model == null:
		return

	_remove_baked_static_bodies(model)
	if fit_collision_to_model:
		_fit_collision_box(model)


func _remove_baked_static_bodies(model: Node) -> void:
	var static_bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	for static_body in static_bodies:
		static_body.get_parent().remove_child(static_body)
		static_body.free()


func _fit_collision_box(model: Node3D) -> void:
	var collision_shape: CollisionShape3D = get_node_or_null(collision_shape_path) as CollisionShape3D
	if collision_shape == null:
		return

	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_instances: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		mesh_instances.append(model)
	for node in mesh_instances:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var to_body: Transform3D = global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = to_body * mesh_instance.mesh.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true

	if not has_bounds:
		return

	var box: BoxShape3D = BoxShape3D.new()
	box.size = bounds.size
	collision_shape.shape = box
	collision_shape.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
