extends MeshInstance3D

## The hook's rope: a thin box stretched between two points in the world, with a small hook head at
## the far end. Created by hook.gd; set_points() every frame while it is shown.

var _head: MeshInstance3D


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.24, 0.24)
	material.roughness = 0.7
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.018, 0.018, 1.0)
	box.material = material
	mesh = box
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.56, 0.6)
	steel.metallic = 0.6
	var head_mesh: BoxMesh = BoxMesh.new()
	head_mesh.size = Vector3(0.09, 0.09, 0.05)
	head_mesh.material = steel
	_head = MeshInstance3D.new()
	_head.mesh = head_mesh
	_head.top_level = true
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_head)
	visible = false


func set_points(from: Vector3, to: Vector3) -> void:
	var span: Vector3 = to - from
	var length: float = span.length()
	if length <= 0.01:
		visible = false
		_head.visible = false
		return
	visible = true
	_head.visible = true
	var up: Vector3 = Vector3.UP if absf(span.normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var basis_value: Basis = Basis.looking_at(span / length, up)
	global_transform = Transform3D(basis_value.scaled_local(Vector3(1.0, 1.0, length)), from + span * 0.5)
	_head.global_transform = Transform3D(basis_value, to)


func hide_rope() -> void:
	visible = false
	if _head != null:
		_head.visible = false
