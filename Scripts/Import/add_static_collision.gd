@tool
extends EditorScenePostImport

## Import script for level geometry (walls, stairs, floors...).
## Adds a StaticBody3D with a trimesh collision shape under every MeshInstance3D.
## The body stays on collision layer 1, which the player's movement raycasts use.
## Assign it in the Import dock (Import Script) and press Reimport.


func _post_import(scene: Node) -> Object:
	_add_collision_recursive(scene, scene)
	return scene


func _add_collision_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		_add_collision_recursive(child, scene_root)

	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return
	if _has_static_body_child(mesh_instance):
		return

	var shape: ConcavePolygonShape3D = mesh_instance.mesh.create_trimesh_shape()
	if shape == null:
		return

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "StaticBody3D"
	mesh_instance.add_child(body)
	body.owner = scene_root

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	body.add_child(collision_shape)
	collision_shape.owner = scene_root


func _has_static_body_child(node: Node) -> bool:
	for child in node.get_children():
		if child is StaticBody3D:
			return true
	return false
