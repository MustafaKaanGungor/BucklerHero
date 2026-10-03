extends Node3D

## The crossbow's bolt. Flies fast under light gravity and raycasts the segment it travels each
## physics tick (like the other projectiles). The first hittable thing it meets takes `damage`;
## the level stops it, and it stays stuck in the wall for a moment.
## An explosive bolt (fired at S rank) blows up wherever it lands instead: every enemy within
## explosion_radius with nothing solid in between takes explosion damage, falling off toward the
## edge, and is thrown outward; loose props are pushed.
## Hits are reported to melee_weapons.on_crossbow_bolt_hit() so sounds, hit-stop and shake match the
## other weapons. Created by melee_weapons.gd.
## Also used for the sickle and dagger's thrown daggers: report_method then points at deliver_hit-style
## reporting (weapon_id is passed along), stick_in_world off, and a shorter, darker look.

const METHOD_ON_MELEE_HIT: StringName = &"on_melee_hit"
const METHOD_ON_BOLT_HIT: StringName = &"on_crossbow_bolt_hit"
const METHOD_ON_BOLT_EXPLOSION: StringName = &"on_crossbow_bolt_explosion"
const GROUP_ENEMIES: StringName = &"enemies"
const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")

@export_group("Flight")
## Metres per second.
@export var speed: float = 80.0
## Downward pull, m/s². Low, so the bolt flies nearly straight.
@export var gravity: float = 2.0
## Seconds before a bolt that hit nothing removes itself.
@export var lifetime: float = 3.0
## Seconds a bolt stays stuck in a wall.
@export var stuck_time: float = 3.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Look")
@export var bolt_color: Color = Color(0.85, 0.75, 0.55)
@export var explosive_color: Color = Color(1.0, 0.45, 0.1)
@export var explosion_color: Color = Color(1.0, 0.5, 0.15, 0.6)

var damage: float = 2.0
var physics_impulse: float = 10.0
var is_explosive: bool = false
var explosion_radius: float = 6.0
var explosion_damage: float = 10.0
## Share of explosion_damage at the very edge of the blast.
var explosion_edge_damage_ratio: float = 0.4
var explosion_impulse: float = 30.0
## Method on the weapons node that hits are reported to: (target, hit_info, impulse).
var report_method: StringName = METHOD_ON_BOLT_HIT
## False: hitting the level just removes the projectile instead of leaving it stuck there.
var stick_in_world: bool = true
## Length of the visible shaft in metres.
var shaft_length: float = 0.7
## Weapon id put into hit_info["weapon"] (used with report_method on_weapon_projectile_hit).
var weapon_id: StringName = &"crossbow"

var velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _excluded: Array[RID] = []
var _weapons: Node
var _done: bool = false

static var _boom_sound: AudioStreamWAV


## Places the bolt and starts it flying. Call after adding it to the scene tree.
func launch(from: Vector3, direction: Vector3, weapons: Node, excluded: Array[RID]) -> void:
	_weapons = weapons
	_excluded = excluded.duplicate()
	velocity = direction.normalized() * speed
	global_position = from
	_face_velocity()
	reset_physics_interpolation()
	_build_visual()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	velocity.y -= gravity * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var hit: Dictionary = _cast(from, to)
	if not hit.is_empty():
		_on_impact(hit)
		return
	global_position = to
	_face_velocity()
	if _age >= lifetime:
		queue_free()


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, collision_mask, _excluded)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _on_impact(hit: Dictionary) -> void:
	_done = true
	var impact_position: Vector3 = Vector3(hit.get("position", global_position))
	var target: Node3D = hit.get("collider") as Node3D
	global_position = impact_position
	var direction: Vector3 = velocity.normalized()
	if is_explosive:
		# A direct hit still counts on top of the blast.
		if target != null and target.has_method(METHOD_ON_MELEE_HIT):
			_report_hit(target, impact_position, Vector3(hit.get("normal", Vector3.UP)), direction, damage)
		_explode(impact_position - direction * 0.2)
		queue_free()
		return

	if target != null and (target.has_method(METHOD_ON_MELEE_HIT) or target is RigidBody3D):
		_report_hit(target, impact_position, Vector3(hit.get("normal", Vector3.UP)), direction, damage)
		queue_free()
		return

	if not stick_in_world:
		queue_free()
		return
	# Stuck in the level for a while, then gone.
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(stuck_time, 0.0))
	tween.tween_property(self, ^"scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)


func _report_hit(target: Node3D, hit_position: Vector3, normal: Vector3, direction: Vector3, amount: float) -> void:
	var hit_info: Dictionary = {
		"position": hit_position,
		"normal": normal,
		"direction": direction,
		"collider": target,
		"damage": amount,
		"weapon": weapon_id,
	}
	if _weapons != null and is_instance_valid(_weapons) and _weapons.has_method(report_method):
		_weapons.call(report_method, target, hit_info, physics_impulse)


## Damages and throws every enemy in the radius that isn't sheltered behind level geometry.
func _explode(center: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var radius: float = maxf(explosion_radius, 0.1)
	var hit_count: int = 0
	for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var enemy: Node3D = node as Node3D
		if enemy == null or not enemy.has_method(METHOD_ON_MELEE_HIT):
			continue
		if enemy.has_method(&"is_dead") and bool(enemy.call(&"is_dead")):
			continue
		var enemy_center: Vector3 = enemy.global_position + Vector3.UP * 1.0
		var distance: float = center.distance_to(enemy_center)
		if distance > radius:
			continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center, enemy_center, collision_mask, _excluded)
		var blocker: Dictionary = space.intersect_ray(query)
		if not blocker.is_empty() and blocker.get("collider") != enemy and not (blocker.get("collider") as Node).is_in_group(GROUP_ENEMIES):
			continue
		var falloff: float = clampf(distance / radius, 0.0, 1.0)
		var amount: float = explosion_damage * lerpf(1.0, explosion_edge_damage_ratio, falloff)
		var outward: Vector3 = enemy_center - center
		outward.y = maxf(outward.y, 0.0) + 0.6
		_report_hit(enemy, enemy_center, Vector3.UP, outward.normalized(), amount)
		hit_count += 1

	# Loose props get shoved too.
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis.IDENTITY, center)
	shape_query.collision_mask = collision_mask
	for result in space.intersect_shape(shape_query, 32):
		var body: RigidBody3D = result.get("collider") as RigidBody3D
		if body != null:
			var push: Vector3 = (body.global_position - center).normalized() + Vector3.UP * 0.5
			body.apply_central_impulse(push.normalized() * explosion_impulse)

	if _weapons != null and is_instance_valid(_weapons) and _weapons.has_method(METHOD_ON_BOLT_EXPLOSION):
		_weapons.call(METHOD_ON_BOLT_EXPLOSION, center, radius, hit_count)
	_spawn_explosion_visual(center, radius)
	SoundSynth.play_at(self, _get_boom_sound(), center, 6.0, randf_range(0.9, 1.0), 14.0)


func _spawn_explosion_visual(center: Vector3, radius: float) -> void:
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = explosion_color
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.material = material
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.mesh = mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = center
	flash.scale = Vector3.ONE * 0.3
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = explosion_color
	light.light_energy = 6.0
	light.omni_range = radius * 1.5
	flash.add_child(light)
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, ^"scale", Vector3.ONE * radius, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(material, ^"albedo_color:a", 0.0, 0.45)
	tween.parallel().tween_property(light, ^"light_energy", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)


func _face_velocity() -> void:
	if velocity.length_squared() <= 0.0001:
		return
	var direction: Vector3 = velocity.normalized()
	var up: Vector3 = Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.98 else Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(direction, up), global_position)


func _build_visual() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = explosive_color if is_explosive else bolt_color
	material.emission_enabled = is_explosive
	material.emission = explosive_color
	material.emission_energy_multiplier = 3.0
	var shaft: BoxMesh = BoxMesh.new()
	shaft.size = Vector3(0.03, 0.03, shaft_length)
	shaft.material = material
	var shaft_instance: MeshInstance3D = MeshInstance3D.new()
	shaft_instance.mesh = shaft
	add_child(shaft_instance)
	var tip: BoxMesh = BoxMesh.new()
	tip.size = Vector3(0.07, 0.07, 0.12)
	tip.material = material
	var tip_instance: MeshInstance3D = MeshInstance3D.new()
	tip_instance.mesh = tip
	tip_instance.position = Vector3(0.0, 0.0, -shaft_length * 0.54)
	add_child(tip_instance)
	if is_explosive:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = explosive_color
		light.light_energy = 2.0
		light.omni_range = 3.0
		add_child(light)


static func _get_boom_sound() -> AudioStreamWAV:
	if _boom_sound == null:
		var boom: PackedFloat32Array = SoundSynth.thud(1.3, 75.0, 25.0, 3.5, 1.6, 4.0, 0.5, 701)
		boom = SoundSynth.mix(boom, SoundSynth.thud(0.3, 450.0, 160.0, 22.0, 1.8, 18.0, 0.95, 702), 0.7)
		boom = SoundSynth.mix(boom, SoundSynth.whoosh(0.9, 300.0, 1500.0, 500.0, 0.15, 1.2, 703), 0.5, 0.05)
		_boom_sound = SoundSynth.make_wav(SoundSynth.normalize(boom))
	return _boom_sound
