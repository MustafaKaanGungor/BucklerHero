extends Node3D

## The thrown shield (right click). Created by melee_weapons.gd (throw_shield()), which owns the
## rules; this node only flies and reports back. No gravity, no arc. States:
## - FLYING: straight along its direction, or straight at a ricochet target's chest. Each tick it casts
##   a small bundle of rays over its motion (centre + hit_radius around it). The first living enemy it
##   meets takes a hit (weapons.on_thrown_shield_hit), then the shield ricochets to
##   weapons.find_shield_ricochet_target() while it has ricochets left, otherwise it returns. A wall or
##   prop, max_distance flown without a hit, or a ricochet target dying first also sends it back.
## - RETURNING: flies to the player's camera through everything; within catch_distance it is caught
##   (weapons.on_thrown_shield_caught). A return that takes too long snaps back.
## Every enemy hit freezes the shield in place for hit_freeze_time (the enemy freezes as long, through
## the hit's hit-stop) before it ricochets on or returns. The shield glows (additive overlay + light)
## and leaves a fading ribbon trail along its path.

enum State { FLYING, RETURNING }

const METHOD_ON_MELEE_HIT: StringName = &"on_melee_hit"
const METHOD_IS_DEAD: StringName = &"is_dead"

var speed: float = 40.0
var return_speed: float = 45.0
var max_distance: float = 30.0
var hit_radius: float = 0.3
var catch_distance: float = 1.0
var spin_speed: float = 22.0
var max_return_time: float = 3.0
var collision_mask: int = 1
var ricochets_left: int = 0
var hit_freeze_time: float = 0.09
var glow_color: Color = Color(0.45, 0.75, 1.0, 0.55)
var trail_color: Color = Color(0.45, 0.75, 1.0, 0.5)
var trail_width: float = 0.45
var trail_time: float = 0.22
## The trail is invisible closer than trail_near_fade_start to the camera and fully there
## trail_near_fade_length further out.
var trail_near_fade_start: float = 2.0
var trail_near_fade_length: float = 3.0

var state: int = State.FLYING
var _weapons: Node
var _direction: Vector3 = Vector3.FORWARD
var _target: Node3D
var _excluded: Array[RID] = []
var _hit_enemies: Array = []
var _flown: float = 0.0
var _return_timer: float = 0.0
var _visual: Node3D
var _ricochets: int = 0
var _freeze_timer: float = 0.0
var _glow_material: StandardMaterial3D
var _glow_time: float = 0.0
var _light: OmniLight3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_material: StandardMaterial3D
## Trail points: [position, age].
var _trail_points: Array = []


## visual: the model to show (a copy of the shield in hand). Call after adding to the tree.
func launch(weapons: Node, from: Vector3, direction: Vector3, visual: Node3D, excluded: Array[RID]) -> void:
	_weapons = weapons
	_excluded = excluded.duplicate()
	_direction = direction.normalized()
	_visual = visual
	add_child(_visual)
	global_position = from
	reset_physics_interpolation()
	_build_glow()
	_build_trail()


func is_returning() -> bool:
	return state == State.RETURNING


## Enemies hit so far on this throw.
func get_hit_count() -> int:
	return _hit_enemies.size()


func get_ricochet_count() -> int:
	return _ricochets


## Sends it straight back (a wall, nothing left to hit, or the run restarted).
func start_return() -> void:
	state = State.RETURNING
	_target = null
	_return_timer = 0.0


func _physics_process(delta: float) -> void:
	if _weapons == null or not is_instance_valid(_weapons):
		queue_free()
		return
	if _visual != null:
		_visual.rotate_y(spin_speed * delta * (0.35 if _freeze_timer > 0.0 else 1.0))
	if _freeze_timer > 0.0:
		# Hit-stop: hold still on the enemy that was just hit.
		_freeze_timer = maxf(_freeze_timer - delta, 0.0)
		return
	if state == State.RETURNING:
		_return(delta)
	else:
		_fly(delta)


func _fly(delta: float) -> void:
	if _target != null:
		if not _is_alive(_target):
			# The ricochet target died before the shield got there: try another one, else come back.
			_pick_next_target()
			if state == State.RETURNING:
				return
		if _target != null:
			_direction = (_target.global_position + Vector3.UP * 1.0 - global_position).normalized()
	var step: float = speed * delta
	var from: Vector3 = global_position
	var hit: Dictionary = _cast_bundle(from, _direction * step)
	if hit.is_empty():
		global_position = from + _direction * step
		_flown += step
		if _flown >= max_distance and _target == null:
			start_return()
		return

	var collider: Node3D = hit.get("collider") as Node3D
	var point: Vector3 = Vector3(hit.get("position", from))
	global_position = point - _direction * 0.2
	if collider != null and collider.has_method(METHOD_ON_MELEE_HIT) and _is_alive(collider):
		_hit_enemies.append(collider)
		_weapons.call(&"on_thrown_shield_hit", collider, point, _direction)
		_freeze_timer = maxf(hit_freeze_time, 0.0)
		_pick_next_target()
		return
	# A wall or a prop: bounce back to the player.
	_weapons.call(&"on_thrown_shield_bounced", collider, point, _direction)
	start_return()


func _pick_next_target() -> void:
	_target = null
	if ricochets_left <= 0:
		start_return()
		return
	var next: Node3D = _weapons.call(&"find_shield_ricochet_target", global_position, _hit_enemies) as Node3D
	if next == null:
		start_return()
		return
	ricochets_left -= 1
	_ricochets += 1
	_target = next
	_flown = 0.0
	_weapons.call(&"on_thrown_shield_ricochet", global_position, next)


func _return(delta: float) -> void:
	_return_timer += delta
	var catch_point: Vector3 = _weapons.call(&"get_shield_catch_point") as Vector3
	var to_player: Vector3 = catch_point - global_position
	var step: float = return_speed * delta
	if to_player.length() <= maxf(catch_distance, step) or _return_timer >= max_return_time:
		_weapons.call(&"on_thrown_shield_caught", self)
		return
	global_position += to_player.normalized() * step


## The nearest hit among a centre ray and four rays hit_radius around it, along motion. Dead
## enemies and enemies already hit this throw are passed through.
func _cast_bundle(from: Vector3, motion: Vector3) -> Dictionary:
	var right: Vector3 = motion.cross(Vector3.UP)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = right.cross(motion).normalized()
	var offsets: Array[Vector3] = [Vector3.ZERO, right * hit_radius, -right * hit_radius, up * hit_radius, -up * hit_radius]
	var best: Dictionary = {}
	var best_distance: float = INF
	for offset in offsets:
		var hit: Dictionary = _cast(from + offset, from + offset + motion)
		if hit.is_empty():
			continue
		# Only the centre ray may stop on level geometry, so the shield doesn't clip corners early.
		var collider: Node = hit.get("collider") as Node
		var is_enemy: bool = collider != null and collider.has_method(METHOD_ON_MELEE_HIT)
		if offset != Vector3.ZERO and not is_enemy:
			continue
		var distance: float = from.distance_to(Vector3(hit.get("position", from)))
		if distance < best_distance:
			best_distance = distance
			best = hit
	return best


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var excluded: Array[RID] = _excluded.duplicate()
	for _attempt in range(6):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, excluded)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return hit
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.has_method(METHOD_ON_MELEE_HIT) and (_hit_enemies.has(collider) or not _is_alive(collider)):
			excluded.append(hit.get("rid"))
			continue
		return hit
	return {}


func _is_alive(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return not (target.has_method(METHOD_IS_DEAD) and bool(target.call(METHOD_IS_DEAD)))


## Freeze time left from the last hit (hit-stop). For tests.
func get_freeze_remaining() -> float:
	return _freeze_timer


func _process(delta: float) -> void:
	_update_glow(delta)
	_update_trail(delta)


func _build_glow() -> void:
	_glow_material = StandardMaterial3D.new()
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_material.albedo_color = glow_color
	_set_overlay(_visual, _glow_material)
	_light = OmniLight3D.new()
	_light.light_color = Color(glow_color, 1.0)
	_light.light_energy = 1.6
	_light.omni_range = 3.0
	add_child(_light)


func _update_glow(delta: float) -> void:
	if _glow_material == null:
		return
	_glow_time += delta
	var pulse: float = 0.75 + 0.25 * sin(_glow_time * TAU * 4.0)
	# Flares up while frozen on a hit.
	if _freeze_timer > 0.0:
		pulse = 1.6
	_glow_material.albedo_color = Color(glow_color, clampf(glow_color.a * pulse, 0.0, 1.0))
	_light.light_energy = 1.6 * pulse


func _set_overlay(node: Node, overlay: Material) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		geometry.material_overlay = overlay
	for child in node.get_children():
		_set_overlay(child, overlay)


## The trail is a child with top_level on, so it is drawn in world space and freed with the shield.
func _build_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_material.vertex_color_use_as_albedo = true
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY


## A ribbon through the recent positions, facing the camera, narrowing and fading toward its tail.
func _update_trail(delta: float) -> void:
	if _trail_mesh == null:
		return
	for point in _trail_points:
		point[1] = float(point[1]) + delta
	while not _trail_points.is_empty() and float(_trail_points[0][1]) > trail_time:
		_trail_points.pop_front()
	if _freeze_timer <= 0.0:
		_trail_points.append([global_position, 0.0])
	_trail_mesh.clear_surfaces()
	if _trail_points.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_material)
	var last: int = _trail_points.size() - 1
	var camera: Camera3D = get_viewport().get_camera_3d()
	var previous_side: Vector3 = Vector3.RIGHT
	for index in range(_trail_points.size()):
		var point_position: Vector3 = _trail_points[index][0]
		var along: Vector3
		if index < last:
			along = Vector3(_trail_points[index + 1][0]) - point_position
		else:
			along = point_position - Vector3(_trail_points[index - 1][0])
		# The ribbon turns to face the camera, so it reads from behind as well as from the side.
		var view: Vector3 = (camera.global_position - point_position) if camera != null else Vector3.UP
		var side: Vector3 = along.cross(view)
		if side.length_squared() > 0.000001:
			side = side.normalized()
			# Keep the same side from point to point so the ribbon never twists into a zigzag.
			if side.dot(previous_side) < 0.0:
				side = -side
		else:
			side = previous_side
		previous_side = side
		var life: float = 1.0 - clampf(float(_trail_points[index][1]) / maxf(trail_time, 0.001), 0.0, 1.0)
		# Right in front of the camera the ribbon would fill the screen: fade it in with distance.
		if camera != null:
			var camera_distance: float = camera.global_position.distance_to(point_position)
			life *= clampf((camera_distance - trail_near_fade_start) / maxf(trail_near_fade_length, 0.001), 0.0, 1.0)
		var half_width: float = trail_width * 0.5 * life
		var color: Color = Color(trail_color, trail_color.a * life)
		_trail_mesh.surface_set_color(color)
		_trail_mesh.surface_add_vertex(point_position + side * half_width)
		_trail_mesh.surface_set_color(color)
		_trail_mesh.surface_add_vertex(point_position - side * half_width)
	_trail_mesh.surface_end()
