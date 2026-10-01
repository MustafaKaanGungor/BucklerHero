extends CharacterBody3D

## Training dummy that stands in for an enemy.
## It doesn't move or fight back; it only reacts: melee hits damage it and knock it back,
## a shield charge can pick it up and carry it, and being crushed against a wall kills it outright.
## When it dies it breaks into physics pieces that fly off along the killing blow.
## After dying it comes back at its starting spot, so it can be used again for testing.
## Real enemies should implement the same methods: on_melee_hit, can_be_shield_carried,
## start_shield_carry, end_shield_carry and on_shield_crush.

signal damaged(health: float, max_health: float)
signal died
signal respawned

## Other systems find enemies through this group.
const GROUP_ENEMIES: StringName = &"enemies"

@export var visual_path: NodePath = NodePath("Visual")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")

@export_group("Health")
## Damage needed to kill the dummy. Sword and shield bash do 1, the halberd does 2.
@export var max_health: float = 3.0
## Seconds before a dead dummy comes back. 0 or less removes it for good.
@export var respawn_time: float = 4.0

@export_group("Shield Carry")
## Heavy enemies can't be picked up by a shield charge. Running into one stops the charge dead instead.
@export var blocks_shield_charge: bool = false
## Speed a heavy enemy is shoved back at when a shield charge slams into it.
@export var charge_impact_knockback_speed: float = 3.0

@export_group("Knockback")
## Speed the dummy is pushed at by a melee hit, along the hit direction.
@export var hit_knockback_speed: float = 5.0
## How quickly the dummy stops sliding on the ground.
@export var ground_friction: float = 9.0
## How quickly the dummy loses sideways speed in the air.
@export var air_friction: float = 0.6

@export_group("Feedback")
## Color the dummy flashes when hit.
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Seconds the hit flash takes to fade.
@export var hit_flash_time: float = 0.18

@export_group("Fragments")
## Pieces the dummy breaks into when it dies. 0 disables the breaking effect.
@export var fragment_count: int = 14
## Smallest and largest edge length of a piece, in meters.
@export var fragment_size_range: Vector2 = Vector2(0.14, 0.3)
## Pieces spawn inside the body: within this distance of its center line, along this height.
@export var fragment_spawn_radius: float = 0.28
@export var fragment_spawn_height: float = 1.6
@export var fragment_mass: float = 0.3
## Push along the direction of the killing blow.
@export var fragment_forward_impulse: float = 1.1
## Push away from the body's center line.
@export var fragment_outward_impulse: float = 0.7
## Upward push so pieces pop up before falling.
@export var fragment_up_impulse: float = 0.6
## Random spin strength.
@export var fragment_spin_impulse: float = 0.04
## Seconds pieces stay before shrinking away.
@export var fragment_lifetime: float = 3.0
@export var fragment_shrink_time: float = 0.4
## Layer 2 keeps pieces from blocking the player or stopping attacks.
@export_flags_3d_physics var fragment_collision_layer: int = 2
## Pieces land on the world (layer 1) and bump into each other (layer 2).
@export_flags_3d_physics var fragment_collision_mask: int = 3

var _visual: Node3D
var _collision_shape: CollisionShape3D
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _health: float = 1.0
var _is_dead: bool = false
var _is_carried: bool = false
var _carrier: PhysicsBody3D
var _respawn_timer: float = 0.0
var _flash_amount: float = 0.0
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _last_hit_direction: Vector3 = Vector3.ZERO
var _hit_stop_timer: float = 0.0
var _is_crush_pending: bool = false


func _ready() -> void:
	add_to_group(GROUP_ENEMIES)
	_visual = get_node_or_null(visual_path) as Node3D
	_collision_shape = get_node_or_null(collision_shape_path) as CollisionShape3D
	_spawn_transform = global_transform
	_health = maxf(max_health, 0.001)
	_cache_materials()


func _physics_process(delta: float) -> void:
	if _is_dead:
		_update_respawn(delta)
		return
	# Hit-stop: frozen in place for a moment; knockback from the hit starts once it ends.
	if _hit_stop_timer > 0.0:
		_hit_stop_timer = maxf(_hit_stop_timer - delta, 0.0)
		if _hit_stop_timer <= 0.0 and _is_crush_pending:
			_finish_crush()
		return
	# While carried, the shield charge moves the dummy; it doesn't simulate itself.
	if _is_carried:
		return

	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y = maxf(
			velocity.y - (WorldBasicRules.get_gravity() * delta),
			-WorldBasicRules.get_terminal_fall_speed()
		)

	_update_horizontal_velocity(delta)
	move_and_slide()


## The dummy only slides to a stop. Enemies that move on their own override this.
func _update_horizontal_velocity(delta: float) -> void:
	var friction: float = ground_friction if is_on_floor() else air_friction
	var friction_blend: float = 1.0 - exp(-maxf(friction, 0.0) * delta)
	velocity.x = lerpf(velocity.x, 0.0, friction_blend)
	velocity.z = lerpf(velocity.z, 0.0, friction_blend)


func _process(delta: float) -> void:
	if _flash_amount <= 0.0:
		return

	_flash_amount = maxf(_flash_amount - (delta / maxf(hit_flash_time, 0.001)), 0.0)
	_apply_flash()


func get_health() -> float:
	return _health


func is_dead() -> bool:
	return _is_dead


func is_shield_carried() -> bool:
	return _is_carried


## Called by melee weapons. hit_info has position, normal, direction, damage, weapon and attacker.
func on_melee_hit(hit_info: Dictionary) -> void:
	if _is_dead:
		return

	var direction: Vector3 = Vector3(hit_info.get("direction", Vector3.ZERO))
	_last_hit_direction = direction
	if not _is_carried:
		velocity += direction * maxf(hit_knockback_speed, 0.0)
	_take_damage(float(hit_info.get("damage", 1.0)))


## Freezes the dummy for a moment when a melee hit lands. The longer freeze wins if hits overlap.
func apply_hit_stop(duration: float) -> void:
	if _is_dead or _is_carried:
		return
	_hit_stop_timer = maxf(_hit_stop_timer, maxf(duration, 0.0))


func is_in_hit_stop() -> bool:
	return _hit_stop_timer > 0.0


## A shield charge asks this before picking the dummy up.
func can_be_shield_carried() -> bool:
	return not _is_dead and not _is_carried and not blocks_shield_charge and not _is_crush_pending


## A shield charge that runs into this enemy is stopped instead of picking it up.
func is_shield_charge_blocker() -> bool:
	return blocks_shield_charge and not _is_dead


## A shield charge slammed into this enemy without picking it up. hit_info has direction and attacker.
func on_shield_charge_impact(hit_info: Dictionary) -> void:
	if _is_dead or _is_carried:
		return

	var direction: Vector3 = Vector3(hit_info.get("direction", Vector3.ZERO))
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		velocity += direction.normalized() * maxf(charge_impact_knockback_speed, 0.0)
	_flash_amount = 1.0
	_apply_flash()


## The shield charge picked the dummy up. From now on the carrier sets its position every physics tick.
func start_shield_carry(carrier: PhysicsBody3D) -> void:
	if not can_be_shield_carried():
		return

	_is_carried = true
	_carrier = carrier
	velocity = Vector3.ZERO
	if _carrier != null:
		add_collision_exception_with(_carrier)
		_carrier.add_collision_exception_with(self)


## The shield charge let go without hitting a wall. The dummy is thrown with release_velocity.
func end_shield_carry(release_velocity: Vector3) -> void:
	if not _is_carried:
		return

	_clear_carry()
	velocity = release_velocity


## The shield charge crushed the dummy against a wall. Kills it regardless of health.
## hit_info may carry "hit_stop_time": the dummy then freezes pinned to the wall for that long
## and breaks when the freeze ends.
func on_shield_crush(hit_info: Dictionary) -> void:
	if _is_dead or _is_crush_pending:
		return

	# Crushed against a wall: the pieces bounce back off it, toward the attacker.
	_last_hit_direction = -Vector3(hit_info.get("direction", Vector3.ZERO))
	_clear_carry()
	velocity = Vector3.ZERO
	var freeze_time: float = maxf(float(hit_info.get("hit_stop_time", 0.0)), 0.0)
	if freeze_time > 0.0:
		_is_crush_pending = true
		_hit_stop_timer = maxf(_hit_stop_timer, freeze_time)
		_flash_amount = 1.0
		_apply_flash()
		return
	_finish_crush()


func _finish_crush() -> void:
	_is_crush_pending = false
	_health = 0.0
	damaged.emit(_health, maxf(max_health, 0.001))
	_die()


func _take_damage(amount: float) -> void:
	_health = maxf(_health - maxf(amount, 0.0), 0.0)
	_flash_amount = 1.0
	_apply_flash()
	damaged.emit(_health, maxf(max_health, 0.001))
	if _health <= 0.0:
		_die()


func _die() -> void:
	_clear_carry()
	_is_dead = true
	_respawn_timer = respawn_time
	velocity = Vector3.ZERO
	if _collision_shape != null:
		_collision_shape.set_deferred(&"disabled", true)
	if _visual != null:
		_visual.hide()
	_spawn_fragments()
	died.emit()
	if respawn_time <= 0.0:
		queue_free()


func _update_respawn(delta: float) -> void:
	if respawn_time <= 0.0:
		return

	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		return

	_is_dead = false
	_health = maxf(max_health, 0.001)
	_flash_amount = 0.0
	_apply_flash()
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	reset_physics_interpolation()
	if _collision_shape != null:
		_collision_shape.set_deferred(&"disabled", false)
	if _visual != null:
		_visual.show()
	respawned.emit()


func _spawn_fragments() -> void:
	if fragment_count <= 0:
		return

	var fragment_parent: Node = get_tree().current_scene
	if fragment_parent == null:
		fragment_parent = get_parent()

	var blow_direction: Vector3 = _last_hit_direction
	if blow_direction.length_squared() > 0.0001:
		blow_direction = blow_direction.normalized()
	for index in range(fragment_count):
		var body: RigidBody3D = _create_fragment_body(index)
		fragment_parent.add_child(body)

		var angle: float = randf() * TAU
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (randf() * fragment_spawn_radius)
		var height: float = randf_range(0.1, maxf(fragment_spawn_height, 0.1))
		var random_rotation: Vector3 = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		body.global_transform = Transform3D(
			Basis.from_euler(random_rotation),
			global_position + offset + (Vector3.UP * height)
		)
		body.reset_physics_interpolation()

		var outward: Vector3 = offset.normalized() if offset.length_squared() > 0.0001 else Vector3.UP
		var impulse: Vector3 = (
			(blow_direction * fragment_forward_impulse)
			+ (outward * fragment_outward_impulse)
			+ (Vector3.UP * fragment_up_impulse)
		) * randf_range(0.7, 1.3)
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(
			Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * fragment_spin_impulse
		)


## A box piece in one of the dummy's own colors that shrinks away after fragment_lifetime.
func _create_fragment_body(index: int) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.name = "DummyFragment"
	body.mass = maxf(fragment_mass, 0.001)
	body.collision_layer = fragment_collision_layer
	body.collision_mask = fragment_collision_mask

	var min_size: float = maxf(minf(fragment_size_range.x, fragment_size_range.y), 0.02)
	var max_size: float = maxf(maxf(fragment_size_range.x, fragment_size_range.y), min_size)
	var piece_size: Vector3 = Vector3(
		randf_range(min_size, max_size),
		randf_range(min_size, max_size),
		randf_range(min_size, max_size)
	)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	# Mostly the body color, with the occasional piece in one of the other colors.
	if not _base_colors.is_empty():
		var color_index: int = 0
		if index % 5 == 4:
			color_index = (index / 5 + 1) % _base_colors.size()
		material.albedo_color = _base_colors[color_index]
	material.roughness = 0.8

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = piece_size
	box_mesh.material = material
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = box_mesh
	body.add_child(mesh_instance)

	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = piece_size
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.shape = box_shape
	body.add_child(collision_shape)

	var tween: Tween = body.create_tween()
	tween.tween_interval(maxf(fragment_lifetime, 0.0))
	tween.tween_property(mesh_instance, ^"scale", Vector3.ZERO, maxf(fragment_shrink_time, 0.01))
	tween.tween_callback(body.queue_free)
	return body


func _clear_carry() -> void:
	if _carrier != null and is_instance_valid(_carrier):
		remove_collision_exception_with(_carrier)
		_carrier.remove_collision_exception_with(self)
	_carrier = null
	_is_carried = false


## Gives each mesh its own material copy so the hit flash doesn't tint every dummy.
func _cache_materials() -> void:
	if _visual == null:
		return

	var mesh_instances: Array[Node] = _visual.find_children("*", "MeshInstance3D", true, false)
	if _visual is MeshInstance3D:
		mesh_instances.append(_visual)
	for node in mesh_instances:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var source_material: StandardMaterial3D = mesh_instance.get_active_material(0) as StandardMaterial3D
		if source_material == null:
			continue
		var material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
		mesh_instance.set_surface_override_material(0, material)
		_materials.append(material)
		_base_colors.append(material.albedo_color)


func _apply_flash() -> void:
	for index in range(_materials.size()):
		_materials[index].albedo_color = _base_colors[index].lerp(hit_flash_color, clampf(_flash_amount, 0.0, 1.0))
