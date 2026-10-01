extends StaticBody3D

## A doorway slab between two sections of a generated level.
## Closed it fills the doorway from floor to ceiling and glows red; open it sinks into the floor,
## turns green and stops colliding. level_generator.gd creates one per doorway and calls setup().

signal opened
signal closed

@export_group("Motion")
## Seconds the slab takes to sink into the floor.
@export var open_time: float = 0.6
## Seconds the slab takes to rise and shut the doorway. Fast, so nothing slips through.
@export var close_time: float = 0.25

@export_group("Look")
## Colour while the doorway is shut.
@export var locked_color: Color = Color(0.75, 0.12, 0.1)
## Colour while the doorway is open.
@export var open_color: Color = Color(0.15, 0.7, 0.3)
## Glow strength of the slab.
@export var emission_energy: float = 1.4

var _size: Vector3 = Vector3(4.0, 8.0, 0.5)
var _is_open: bool = true
var _mesh: MeshInstance3D
var _collision_shape: CollisionShape3D
var _material: StandardMaterial3D
var _tween: Tween


## Builds the slab. size is (doorway width, height, thickness) in the door's own space.
func setup(size: Vector3, start_open: bool) -> void:
	_size = size
	collision_layer = 1
	collision_mask = 0

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = box_shape
	add_child(_collision_shape)

	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.emission_energy_multiplier = emission_energy
	_material.roughness = 0.5
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _material
	_mesh = MeshInstance3D.new()
	_mesh.mesh = box_mesh
	add_child(_mesh)

	_set_open_instantly(start_open)


func is_open() -> bool:
	return _is_open


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_collision_shape.set_deferred(&"disabled", true)
	_apply_color()
	_move_slab(_get_open_height(), open_time)
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_collision_shape.set_deferred(&"disabled", false)
	_mesh.show()
	_apply_color()
	_move_slab(_get_closed_height(), close_time)
	closed.emit()


func _set_open_instantly(open_state: bool) -> void:
	_is_open = open_state
	_collision_shape.disabled = open_state
	_mesh.position.y = _get_open_height() if open_state else _get_closed_height()
	_collision_shape.position.y = _get_closed_height()
	_mesh.visible = not open_state
	_apply_color()


## Only the mesh moves; the collision snaps (on when closing, off when opening), so the doorway is
## blocked the moment it starts to close.
func _move_slab(target_height: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_mesh.show()
	_tween = create_tween()
	_tween.tween_property(_mesh, ^"position:y", target_height, maxf(duration, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if _is_open:
		_tween.tween_callback(_mesh.hide)


func _get_closed_height() -> float:
	return _size.y * 0.5


func _get_open_height() -> float:
	return -_size.y * 0.5 - 0.05


func _apply_color() -> void:
	if _material == null:
		return
	var color: Color = open_color if _is_open else locked_color
	_material.albedo_color = color
	_material.emission = color
