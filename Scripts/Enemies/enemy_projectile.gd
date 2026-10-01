extends Node3D

## Projectile thrown by ranged enemies.
## It flies under its own gravity and raycasts the segment it travels each physics tick.
## It passes through enemies, hurts the player on a direct hit, and stops at the level.
## With explosion_radius above 0 it explodes wherever it lands instead, hurting the player
## if they are inside the radius with nothing solid in between; damage falls off toward the edge.
## An exploding projectile can show a ring on the ground where it is going to land.

## Enemies are skipped by the projectile's rays. The player is found through its group.
const GROUP_ENEMIES: StringName = &"enemies"
const GROUP_PLAYER: StringName = &"player"
const METHOD_TAKE_DAMAGE: StringName = &"take_damage"
const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")

@export_group("Flight")
## Downward acceleration while flying. The thrower usually overrides this.
@export var gravity: float = 6.0
## Seconds before the projectile removes itself if it hits nothing.
@export var lifetime: float = 6.0
## Physics layers the projectile collides with: the level and the player.
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Damage")
## Damage on a direct hit, or at the center of an explosion.
@export var damage: float = 8.0
## Explosion radius in meters. 0 means no explosion: only direct hits hurt.
@export var explosion_radius: float = 0.0
## Share of the damage dealt at the very edge of the explosion.
@export_range(0.0, 1.0) var explosion_edge_damage_ratio: float = 0.4
## Height above the player's feet used as their center for explosion distance and cover checks.
@export var player_center_height: float = 0.9

@export_group("Sound")
## Volume of the explosion boom, in decibels.
@export var explosion_volume_db: float = 4.0
## Volume of a non-exploding projectile hitting the level. A hit on the player is covered by the
## player's own hit / block sounds instead.
@export var impact_volume_db: float = -6.0

@export_group("Visuals")
@export var visual_path: NodePath = NodePath("Visual")
## Color of the explosion flash and the landing ring.
@export var explosion_color: Color = Color(1.0, 0.45, 0.1, 0.55)
## Seconds the explosion flash takes to grow and fade.
@export var explosion_visual_time: float = 0.35
## Shows a ring on the ground where an exploding projectile will land.
@export var show_landing_marker: bool = true

var velocity: Vector3 = Vector3.ZERO
var _thrower: Node3D
var _age: float = 0.0
var _landing_marker: MeshInstance3D
var _has_finished: bool = false

## Synthesized once, shared by all projectiles.
static var _explosion_sound: AudioStreamWAV
static var _impact_sound: AudioStreamWAV


## Places the projectile and starts it moving. Call after it is added to the scene tree.
func launch(from: Vector3, initial_velocity: Vector3, thrower: Node3D = null) -> void:
	_thrower = thrower
	global_position = from
	velocity = initial_velocity
	reset_physics_interpolation()


## Puts a ring on the ground at the spot the projectile is aimed at.
func set_landing_marker(landing_position: Vector3) -> void:
	if not show_landing_marker or explosion_radius <= 0.0:
		return

	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = explosion_radius
	ring_mesh.bottom_radius = explosion_radius
	ring_mesh.height = 0.03
	ring_mesh.material = _make_glow_material(Color(explosion_color, explosion_color.a * 0.5))

	_landing_marker = MeshInstance3D.new()
	_landing_marker.mesh = ring_mesh
	_landing_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_get_effect_parent().add_child(_landing_marker)
	_landing_marker.global_position = landing_position + (Vector3.UP * 0.03)


func _physics_process(delta: float) -> void:
	if _has_finished:
		return

	_age += delta
	velocity.y -= gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + (velocity * delta)
	var hit: Dictionary = _cast(from, to)
	if not hit.is_empty():
		_on_impact(hit)
		return

	global_position = to
	if _age >= lifetime:
		_finish()


## Raycasts the flight segment, passing through enemies.
func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var excluded_rids: Array[RID] = []
	# The thrower may have died while the projectile is still flying.
	if _thrower != null and is_instance_valid(_thrower):
		var thrower_body: CollisionObject3D = _thrower as CollisionObject3D
		if thrower_body != null:
			excluded_rids.append(thrower_body.get_rid())
	else:
		_thrower = null

	for _attempt in range(8):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, excluded_rids)
		query.collide_with_areas = false
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return {}
		var collider: Node = hit.get("collider") as Node
		if collider == null or not collider.is_in_group(GROUP_ENEMIES):
			return hit
		excluded_rids.append(hit.get("rid"))
	return {}


func _on_impact(hit: Dictionary) -> void:
	var impact_position: Vector3 = Vector3(hit.get("position", global_position))
	global_position = impact_position
	if explosion_radius > 0.0:
		_explode(impact_position)
		return

	var collider: Node = hit.get("collider") as Node
	if collider == null or not collider.is_in_group(GROUP_PLAYER):
		SoundSynth.play_at(self, _get_impact_sound(), impact_position, impact_volume_db, randf_range(0.9, 1.1))
	if collider != null and collider.is_in_group(GROUP_PLAYER) and collider.has_method(METHOD_TAKE_DAMAGE):
		var travel_direction: Vector3 = velocity.normalized() if velocity.length_squared() > 0.0001 else Vector3.FORWARD
		collider.call(METHOD_TAKE_DAMAGE, damage, {
			"position": impact_position,
			"direction": travel_direction,
			"damage": damage,
			"source": _thrower,
		})
	_finish()


func _explode(center: Vector3) -> void:
	_spawn_explosion_visual(center)
	SoundSynth.play_at(self, _get_explosion_sound(), center, explosion_volume_db, randf_range(0.92, 1.05), 12.0)
	var player: Node3D = get_tree().get_first_node_in_group(GROUP_PLAYER) as Node3D
	if player != null and player.has_method(METHOD_TAKE_DAMAGE):
		var player_center: Vector3 = player.global_position + (Vector3.UP * player_center_height)
		var distance: float = center.distance_to(player_center)
		if distance <= explosion_radius and _is_player_exposed(center, player_center, player):
			var falloff: float = clampf(distance / maxf(explosion_radius, 0.001), 0.0, 1.0)
			var explosion_damage: float = lerpf(damage, damage * explosion_edge_damage_ratio, falloff)
			var push_direction: Vector3 = player_center - center
			push_direction = push_direction.normalized() if push_direction.length_squared() > 0.0001 else Vector3.UP
			player.call(METHOD_TAKE_DAMAGE, explosion_damage, {
				"position": center,
				"direction": push_direction,
				"damage": explosion_damage,
				"source": _thrower,
			})
	_finish()


## Walls between the explosion and the player shelter them.
func _is_player_exposed(center: Vector3, player_center: Vector3, player: Node3D) -> bool:
	var from: Vector3 = center + (Vector3.UP * 0.25)
	var excluded_rids: Array[RID] = []
	for _attempt in range(8):
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, player_center, collision_mask, excluded_rids)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider: Node = hit.get("collider") as Node
		if collider == player:
			return true
		if collider == null or not collider.is_in_group(GROUP_ENEMIES):
			return false
		excluded_rids.append(hit.get("rid"))
	return true


func _spawn_explosion_visual(center: Vector3) -> void:
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	var material: StandardMaterial3D = _make_glow_material(explosion_color)
	sphere_mesh.material = material

	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.mesh = sphere_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_get_effect_parent().add_child(flash)
	flash.global_position = center
	flash.scale = Vector3.ONE * 0.1

	var flash_time: float = maxf(explosion_visual_time, 0.01)
	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, ^"scale", Vector3.ONE * explosion_radius, flash_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, ^"albedo_color:a", 0.0, flash_time)
	tween.chain().tween_callback(flash.queue_free)


func _finish() -> void:
	_has_finished = true
	if _landing_marker != null and is_instance_valid(_landing_marker):
		_landing_marker.queue_free()
	queue_free()


func _make_glow_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.disable_receive_shadows = true
	return material


func _get_effect_parent() -> Node:
	var effect_parent: Node = get_tree().current_scene
	return effect_parent if effect_parent != null else get_parent()


## A deep boom with a long rumble and a crackle on top.
static func _get_explosion_sound() -> AudioStreamWAV:
	if _explosion_sound == null:
		var boom: PackedFloat32Array = SoundSynth.thud(1.0, 80.0, 28.0, 4.5, 1.4, 5.0, 0.45, 201)
		boom = SoundSynth.mix(boom, SoundSynth.thud(0.25, 400.0, 150.0, 25.0, 1.6, 22.0, 0.9, 202), 0.6)
		_explosion_sound = SoundSynth.make_wav(SoundSynth.normalize(boom))
	return _explosion_sound


## A dull splat.
static func _get_impact_sound() -> AudioStreamWAV:
	if _impact_sound == null:
		_impact_sound = SoundSynth.make_wav(SoundSynth.normalize(SoundSynth.thud(0.18, 180.0, 90.0, 28.0, 1.2, 35.0, 0.55, 211)))
	return _impact_sound
