extends Decal

## Bullet hole left where a projectile hits a surface.
## place() orients it to the surface normal. It is parented to the object that was hit,
## so it follows moving bodies and is removed together with that object.
## Only max_decals stay alive at once; when a new one appears past the limit the oldest is removed.
## Objects in the "no_impact_decals" group never receive holes (for example glass or water later).

const GROUP_NO_IMPACT_DECALS: StringName = &"no_impact_decals"

## Every live impact decal, oldest first. Shared by all instances.
static var _active_decals: Array[Decal] = []

@export_group("Size")
## Width and length of the hole in meters.
@export var decal_size: float = 0.11
## Random size variation as a fraction, e.g. 0.25 gives 75%-125% of decal_size.
@export_range(0.0, 0.9) var size_variation: float = 0.25
## How deep the projection reaches. Keep it thinner than the thinnest wall, or holes show on the back side.
@export var projection_depth: float = 0.06
## Pushes the decal slightly out of the surface so the projection box covers it cleanly.
@export var surface_offset: float = 0.012

@export_group("Lifetime")
## Most bullet holes alive at once, across the whole level.
@export var max_decals: int = 64
## Seconds a hole stays fully visible. 0 keeps holes until the limit removes them.
@export var lifetime: float = 20.0
## Seconds spent fading out after lifetime ends.
@export var fade_time: float = 1.5

var _age: float = 0.0


## Positions and orients the hole. Call after the decal is added to the scene tree.
func place(hit_position: Vector3, hit_normal: Vector3) -> void:
	var up: Vector3 = hit_normal.normalized()
	if up.length_squared() <= 0.0001:
		up = Vector3.UP

	# Decals project along their local -Y, so local +Y points out of the surface.
	var reference: Vector3 = Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var x_axis: Vector3 = reference.cross(up).normalized()
	var z_axis: Vector3 = x_axis.cross(up).normalized()
	var surface_basis: Basis = Basis(x_axis, up, z_axis).rotated(up, randf() * TAU)
	global_transform = Transform3D(surface_basis, hit_position + (up * surface_offset))

	var hole_size: float = decal_size * randf_range(1.0 - size_variation, 1.0 + size_variation)
	size = Vector3(hole_size, projection_depth, hole_size)
	reset_physics_interpolation()
	_register()


func _process(delta: float) -> void:
	if lifetime <= 0.0:
		return

	_age += delta
	if _age <= lifetime:
		return

	var fade: float = 1.0 - ((_age - lifetime) / maxf(fade_time, 0.001))
	if fade <= 0.0:
		queue_free()
		return
	modulate.a = fade


func _exit_tree() -> void:
	_active_decals.erase(self)


func _register() -> void:
	_active_decals.append(self)
	var limit: int = maxi(max_decals, 1)
	while _active_decals.size() > limit:
		var oldest: Decal = _active_decals.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
