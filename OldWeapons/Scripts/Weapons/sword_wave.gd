extends Node3D

## The empowered broadsword's slash wave (S rank). A glowing crescent ribbon that flies straight ahead,
## cutting through every enemy in its path, and dies against the level.
## Created by melee_weapons.gd; hits are raycast each physics tick across the wave's width and height
## (like the melee attacks), and reported back through melee_weapons.on_sword_wave_hit() so hit
## sounds and the combo meter treat them like sword hits.

const METHOD_ON_SWORD_WAVE_HIT: StringName = &"on_sword_wave_hit"
const METHOD_ON_MELEE_HIT: StringName = &"on_melee_hit"

@export_group("Flight")
## Metres per second.
@export var speed: float = 28.0
## The wave fades out and disappears after travelling this far.
@export var max_distance: float = 22.0
## Width of the wave (side to side) and of its hit area.
@export var width: float = 3.2
## Height of the hit area, centred on the wave.
@export var hit_height: float = 1.0
## Physics layers the wave hits: enemies and the level.
@export_flags_3d_physics var collision_mask: int = 1
## Rays across the width and up the height.
@export var ray_columns: int = 5
@export var ray_rows: int = 3

@export_group("Look")
## Glow colour.
@export var color: Color = Color(0.55, 0.9, 1.0, 0.45)
## How far the crescent bows forward in the middle.
@export var bow_depth: float = 0.7
## Share of max_distance over which it fades out at the end.
@export_range(0.0, 1.0) var fade_share: float = 0.3

var damage: float = 1.0
var _direction: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _weapons: Node
var _excluded: Array[RID] = []
var _hit_ids: Dictionary = {}
var _material: StandardMaterial3D
var _is_dying: bool = false


## Places the wave and starts it flying. Call after adding it to the scene tree.
func launch(from: Vector3, direction: Vector3, weapons: Node, excluded: Array[RID]) -> void:
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_weapons = weapons
	_excluded = excluded.duplicate()
	var up: Vector3 = Vector3.UP if absf(_direction.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(_direction, up), from)
	reset_physics_interpolation()
	_build_visual()


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	var step: float = maxf(speed, 0.0) * delta
	var from: Vector3 = global_position
	if _cast_hits(from, _direction * step):
		_die()
		return
	global_position = from + _direction * step
	_travelled += step
	var fade_start: float = max_distance * (1.0 - clampf(fade_share, 0.0, 1.0))
	if _travelled > fade_start and _material != null:
		var fade: float = 1.0 - clampf((_travelled - fade_start) / maxf(max_distance - fade_start, 0.001), 0.0, 1.0)
		_material.albedo_color.a = color.a * fade
	if _travelled >= max_distance:
		queue_free()


## Casts the grid of rays along this tick's movement. Returns true if the centre ray hit the level.
func _cast_hits(from: Vector3, motion: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var right: Vector3 = global_transform.basis.x
	var up: Vector3 = global_transform.basis.y
	var columns: int = maxi(ray_columns, 1)
	var rows: int = maxi(ray_rows, 1)
	var blocked: bool = false
	for column in range(columns):
		for row in range(rows):
			var lateral: float = _spread(column, columns, width)
			var vertical: float = _spread(row, rows, hit_height)
			# The crescent bows forward in the middle, so the centre rays start a little ahead.
			var bow: float = bow_depth * (1.0 - pow(absf(lateral) / maxf(width * 0.5, 0.001), 2.0))
			var start: Vector3 = from + right * lateral + up * vertical + _direction * bow
			var is_centre: bool = column == columns / 2 and row == rows / 2
			if _cast_ray(space, start, start + motion) and is_centre:
				blocked = true
	return blocked


## One ray that passes through hittable things and stops at the level. Returns true at the level.
func _cast_ray(space: PhysicsDirectSpaceState3D, ray_from: Vector3, ray_to: Vector3) -> bool:
	var excluded: Array[RID] = _excluded.duplicate()
	for _pierce in range(8):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to, collision_mask, excluded)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return false
		var target: Node3D = hit.get("collider") as Node3D
		if target == null or not (target.has_method(METHOD_ON_MELEE_HIT) or target is RigidBody3D):
			return true
		excluded.append(hit.get("rid"))
		var target_id: int = target.get_instance_id()
		if _hit_ids.has(target_id):
			continue
		_hit_ids[target_id] = true
		if _weapons != null and is_instance_valid(_weapons) and _weapons.has_method(METHOD_ON_SWORD_WAVE_HIT):
			_weapons.call(METHOD_ON_SWORD_WAVE_HIT, target, {
				"position": Vector3(hit.get("position", target.global_position)),
				"normal": Vector3(hit.get("normal", Vector3.UP)),
				"direction": _direction,
				"collider": target,
				"damage": damage,
			})
	return false


func _spread(index: int, count: int, size: float) -> float:
	if count <= 1:
		return 0.0
	return lerpf(-size * 0.5, size * 0.5, float(index) / float(count - 1))


## Against the level: a quick flare, then gone.
func _die() -> void:
	_is_dying = true
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"scale", Vector3(1.4, 2.5, 0.2), 0.12)
	tween.parallel().tween_property(_material, ^"albedo_color:a", 0.0, 0.12)
	tween.tween_callback(queue_free)


## A crescent of thin glowing slabs, flat and bowed forward.
func _build_visual() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(color, color.a)
	var segments: int = 9
	var half_width: float = width * 0.5
	for segment in range(segments):
		var t0: float = lerpf(-half_width, half_width, float(segment) / float(segments))
		var t1: float = lerpf(-half_width, half_width, float(segment + 1) / float(segments))
		var a: Vector3 = Vector3(t0, 0.0, -bow_depth * (1.0 - pow(t0 / half_width, 2.0)))
		var b: Vector3 = Vector3(t1, 0.0, -bow_depth * (1.0 - pow(t1 / half_width, 2.0)))
		var middle: float = (t0 + t1) * 0.5 / half_width
		# A glowing ribbon: tallest in the middle, tapering to points at the tips, so it reads
		# clearly from behind instead of as a thin line at eye level.
		var ribbon_height: float = lerpf(0.06, 0.55, 1.0 - middle * middle)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(a.distance_to(b) + 0.02, ribbon_height, 0.1)
		mesh.material = _material
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.position = (a + b) * 0.5
		instance.rotation.y = -atan2(b.z - a.z, b.x - a.x)
		add_child(instance)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)
