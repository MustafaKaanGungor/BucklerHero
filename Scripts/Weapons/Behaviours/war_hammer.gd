extends "res://Scripts/Weapons/Behaviours/weapon_behaviour.gd"

## War hammer: hold-only heavy breaker. A click does nothing. Holding attack raises the hammer and
## charges it while the player walks slowly (no sprint or slide); the full charge can be held for as
## long as you like. Releasing after min_charge_time slams the ground in front: every enemy in the
## shockwave (with nothing solid in between) takes damage, light enemies are launched into the air,
## and a full charge also staggers heavy enemies (brute, mortar). Damage, radius, launch, hit-stop
## and shake all grow with the charge. Releasing in the air turns it into a plunge: the player drives
## straight down and slams on landing, harder and wider the further they fell.
## S rank: each slam also sends a quake line rolling forward along the ground (hammer_quake.gd).

const HammerQuake = preload("res://Scripts/Weapons/hammer_quake.gd")
const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")
const GROUP_ENEMIES: StringName = &"enemies"

@export_group("Charge")
## Seconds of holding before a release slams. Letting go sooner cancels (no attack, no recover).
@export var min_charge_time: float = 0.35
## Seconds of holding for a full charge.
@export var full_charge_time: float = 1.2
## Move speed multiplier while charging (and no sprinting or sliding).
@export_range(0.05, 1.0) var charge_move_speed_multiplier: float = 0.55
## Viewmodel offset with the hammer raised at full charge.
@export var raised_position: Vector3 = Vector3(-0.02, 0.16, 0.06)
## Rotation (degrees) with the hammer raised. +X tips it back over the shoulder.
@export var raised_rotation_degrees: Vector3 = Vector3(30.0, 0.0, -12.0)
## Tremble of the raised hammer at full charge, in metres.
@export var full_charge_tremble: float = 0.006

@export_group("Slam")
## The shockwave is centred this far in front of the player, on the ground.
@export var slam_forward_distance: float = 1.6
## Shockwave radius at the minimum and at full charge (m).
@export var radius_range: Vector2 = Vector2(1.5, 4.0)
## Damage at the minimum and at full charge.
@export var damage_range: Vector2 = Vector2(3.0, 6.0)
## Share of the damage at the very edge of the shockwave.
@export_range(0.0, 1.0) var edge_damage_ratio: float = 0.7
## Upward speed light enemies are launched with, minimum and full charge (m/s).
@export var launch_range: Vector2 = Vector2(4.0, 8.0)
## Outward push on hit enemies (multiplies their hit knockback).
@export var knockback_multiplier: float = 1.3
## Freeze on hit enemies, minimum and full charge (s).
@export var hit_stop_range: Vector2 = Vector2(0.08, 0.25)
## Screen shake of the slam, minimum and full charge (0..1).
@export var shake_range: Vector2 = Vector2(0.35, 0.9)
## Camera kick of the slam (degrees), scaled by charge (half at the minimum).
@export var slam_camera_kick_degrees: Vector3 = Vector3(-3.5, 0.0, 0.0)
## Loudness of the slam, minimum and full charge.
@export var loudness_range: Vector2 = Vector2(30.0, 55.0)
## Enemies more than this far above or below the slam point are missed (m).
@export var max_height_difference: float = 2.2
## Push on loose props in the shockwave.
@export var prop_impulse: float = 18.0
## Combo points for staggering a heavy enemy with a full charge (like a shield-charge stun).
@export var heavy_stun_points: float = 40.0
## Colour of the shockwave ring.
@export var ring_color: Color = Color(1.0, 0.8, 0.45, 0.7)

@export_group("Plunge")
## Downward speed the plunge starts with (m/s).
@export var plunge_speed: float = 22.0
## The plunge gives up after this long without landing (s).
@export var plunge_timeout: float = 3.0
## Extra damage and radius per metre fallen, and their caps.
@export var plunge_damage_per_meter: float = 0.5
@export var plunge_max_damage_bonus: float = 3.0
@export var plunge_radius_per_meter: float = 0.35
@export var plunge_max_radius_bonus: float = 2.0

@export_group("Quake (S Rank)")
## Number of bursts in the quake line, the gap between them (m) and the time between them (s).
@export var quake_pulses: int = 8
@export var quake_spacing: float = 1.4
@export var quake_interval: float = 0.06
## Radius and damage of each burst, and the launch it gives light enemies.
@export var quake_radius: float = 1.5
@export var quake_damage: float = 2.0
@export var quake_launch: float = 5.0

@export_group("Sound")
@export var slam_volume_db: float = 2.0
@export var charge_volume_db: float = -10.0

var _is_charging: bool = false
var _charge_time: float = 0.0
var _full_notified: bool = false
var _raise: float = 0.0
var _tremble_time: float = 0.0
var _is_plunging: bool = false
var _plunge_start_y: float = 0.0
var _plunge_timer: float = 0.0
var _pending_charge: float = 0.0
var _pending_fall: float = 0.0
var _charge_player: AudioStreamPlayer
var _ready_player: AudioStreamPlayer

static var _slam_sound: AudioStreamWAV


func setup(owner_weapons: Node) -> void:
	super.setup(owner_weapons)
	var rumble: PackedFloat32Array = SoundSynth.growl(1.2, 55.0, 0.6, 901)
	rumble = SoundSynth.mix(rumble, SoundSynth.whoosh(1.2, 120.0, 500.0, 300.0, 0.9, 1.4, 902), 0.6)
	_charge_player = _make_player(rumble, charge_volume_db)
	var ping: PackedFloat32Array = SoundSynth.tone_sweep(0.35, 880.0, 1320.0, 0.02, 9.0, 903)
	ping = SoundSynth.mix(ping, SoundSynth.thud(0.15, 500.0, 300.0, 30.0, 0.6, 50.0, 0.8, 904), 0.6)
	_ready_player = _make_player(ping, charge_volume_db + 2.0)


func is_busy() -> bool:
	return _is_plunging


func get_move_speed_multiplier() -> float:
	return charge_move_speed_multiplier if _is_charging else 1.0


## 0 at the minimum charge, 1 at full charge (also while still below the minimum).
func get_charge_ratio() -> float:
	return clampf((_charge_time - min_charge_time) / maxf(full_charge_time - min_charge_time, 0.001), 0.0, 1.0)


func is_charging() -> bool:
	return _is_charging


func is_fully_charged() -> bool:
	return _is_charging and _charge_time >= full_charge_time


func is_plunging() -> bool:
	return _is_plunging


func on_hold_started() -> bool:
	_is_charging = true
	_charge_time = 0.0
	_full_notified = false
	_charge_player.pitch_scale = 1.0
	_charge_player.play()
	return true


func on_hold_updated(delta: float, _held_time: float) -> bool:
	_charge_time += delta
	_charge_player.pitch_scale = 0.8 + 0.5 * get_charge_ratio()
	if not _full_notified and _charge_time >= full_charge_time:
		_full_notified = true
		_ready_player.play()
		if weapons != null:
			weapons.call(&"add_screen_shake", 0.12)
	# The full charge is kept for as long as attack is held.
	return true


func on_hold_released(_held_time: float) -> void:
	var charged: float = _charge_time
	var ratio: float = get_charge_ratio()
	_stop_charging()
	if charged < min_charge_time:
		return
	var player: CharacterBody3D = weapons.call(&"get_player") as CharacterBody3D
	if player == null:
		return
	_pending_charge = ratio
	_pending_fall = 0.0
	if player.is_on_floor():
		weapons.call(&"start_attack")
		return
	# In the air: plunge first, slam on landing.
	_is_plunging = true
	_plunge_timer = 0.0
	# The fall counts from the top of the jump, not from where the button was let go.
	_plunge_start_y = player.global_position.y
	if player.has_method(&"get_airborne_highest_y"):
		_plunge_start_y = maxf(_plunge_start_y, float(player.call(&"get_airborne_highest_y")))
	if player.has_method(&"set_vertical_velocity"):
		player.call(&"set_vertical_velocity", -absf(plunge_speed))


func on_hold_cancelled() -> void:
	_stop_charging()


func on_unequipped() -> void:
	_stop_charging()
	_is_plunging = false


func reset_behaviour() -> void:
	_stop_charging()
	_is_plunging = false


func behaviour_physics_process(delta: float) -> void:
	if not _is_plunging:
		return
	var player: CharacterBody3D = weapons.call(&"get_player") as CharacterBody3D
	_plunge_timer += delta
	if player == null or _plunge_timer > plunge_timeout:
		_is_plunging = false
		return
	# Keep driving down; gravity alone would ease in.
	player.velocity.y = minf(player.velocity.y, -absf(plunge_speed))
	if player.is_on_floor():
		_is_plunging = false
		_pending_fall = maxf(_plunge_start_y - player.global_position.y, 0.0)
		weapons.call(&"start_attack")


func on_strike_started(_attack: MeleeAttackData, empowered: bool) -> void:
	_slam(_pending_charge, _pending_fall, empowered)
	_pending_fall = 0.0


func get_pose_offset() -> Array:
	var raise_rad: Vector3 = Vector3(deg_to_rad(raised_rotation_degrees.x), deg_to_rad(raised_rotation_degrees.y), deg_to_rad(raised_rotation_degrees.z))
	var tremble: Vector3 = Vector3.ZERO
	if is_fully_charged():
		tremble = Vector3(sin(_tremble_time * 71.0), sin(_tremble_time * 53.0), 0.0) * full_charge_tremble
	return [raised_position * _raise + tremble, raise_rad * _raise]


func _process(delta: float) -> void:
	_tremble_time += delta
	var target: float = 0.0
	if _is_charging:
		# Rises quickly at first, the rest of the way as the charge fills.
		target = 0.55 + 0.45 * clampf(_charge_time / maxf(full_charge_time, 0.001), 0.0, 1.0)
	elif _is_plunging:
		target = 1.0
	var speed: float = 10.0 if target > _raise else 25.0
	_raise = lerpf(_raise, target, 1.0 - exp(-speed * delta))


func _stop_charging() -> void:
	_is_charging = false
	_charge_time = 0.0
	if _charge_player != null:
		_charge_player.stop()


## The shockwave: damage, launch, heavy stagger at full charge, prop push, ring, sound and shake.
func _slam(charge: float, fall_height: float, empowered: bool) -> void:
	var player: CharacterBody3D = weapons.call(&"get_player") as CharacterBody3D
	if player == null:
		return
	var forward: Vector3 = -Basis(Vector3.UP, player.rotation.y).z
	var center: Vector3 = player.global_position + forward * slam_forward_distance
	center = _find_floor(center, player.global_position.y)
	var radius: float = lerpf(radius_range.x, radius_range.y, charge) + minf(fall_height * plunge_radius_per_meter, plunge_max_radius_bonus)
	var damage: float = lerpf(damage_range.x, damage_range.y, charge) + minf(fall_height * plunge_damage_per_meter, plunge_max_damage_bonus)
	var full: bool = charge >= 0.999
	var hit_stop: float = lerpf(hit_stop_range.x, hit_stop_range.y, charge)
	var launch: float = lerpf(launch_range.x, launch_range.y, charge)

	burst(center, radius, damage, launch, hit_stop, full, [])
	_push_props(center, radius)
	weapons.call(&"add_screen_shake", lerpf(shake_range.x, shake_range.y, charge))
	weapons.call(&"add_camera_kick", slam_camera_kick_degrees * (0.5 + 0.5 * charge))
	LoudnessManger.register_sound(lerpf(loudness_range.x, loudness_range.y, charge))
	spawn_ring(center, radius, ring_color)
	SoundSynth.play_at(self, _get_slam_sound(), center, slam_volume_db + 4.0 * charge, lerpf(1.1, 0.8, charge), 12.0)
	if empowered:
		var quake: Node3D = Node3D.new()
		quake.set_script(HammerQuake)
		weapons.call(&"spawn_in_world", quake)
		quake.call(&"start", self, center, forward)


## Hits every living enemy within radius of center that isn't sheltered by level geometry and isn't
## in already_hit. Returns how many were hit. Used by the slam and by each quake burst.
func burst(center: Vector3, radius: float, damage: float, launch: float, hit_stop: float, stagger_heavy: bool, already_hit: Array) -> int:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var mask: int = int(weapons.call(&"get_hit_collision_mask"))
	var excluded: Array[RID] = weapons.call(&"get_excluded_rids")
	var count: int = 0
	for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var enemy: Node3D = node as Node3D
		if enemy == null or already_hit.has(enemy):
			continue
		if enemy.has_method(&"is_dead") and bool(enemy.call(&"is_dead")):
			continue
		var offset: Vector3 = enemy.global_position - center
		if absf(offset.y) > max_height_difference:
			continue
		var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
		var distance: float = flat.length()
		if distance > radius:
			continue
		var chest: Vector3 = enemy.global_position + Vector3.UP * 0.9
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.5, chest, mask, excluded)
		var blocker: Dictionary = space.intersect_ray(query)
		if not blocker.is_empty() and blocker.get("collider") != enemy and not (blocker.get("collider") as Node).is_in_group(GROUP_ENEMIES):
			continue
		already_hit.append(enemy)
		count += 1
		var outward: Vector3 = flat.normalized() if distance > 0.05 else -Basis(Vector3.UP, (weapons.call(&"get_player") as Node3D).rotation.y).z
		var amount: float = damage * lerpf(1.0, edge_damage_ratio, clampf(distance / maxf(radius, 0.01), 0.0, 1.0))
		var heavy: bool = enemy.has_method(&"is_shield_charge_blocker") and bool(enemy.call(&"is_shield_charge_blocker"))
		weapons.call(&"deliver_hit", weapon_id, enemy, {
			"position": chest,
			"direction": (outward + Vector3.UP * 0.4).normalized(),
			"damage": amount,
			"knockback_multiplier": knockback_multiplier,
		}, hit_stop, 0.0)
		if not is_instance_valid(enemy) or (enemy.has_method(&"is_dead") and bool(enemy.call(&"is_dead"))):
			continue
		if heavy:
			if stagger_heavy and enemy.has_method(&"on_shield_charge_impact"):
				enemy.call(&"on_shield_charge_impact", {
					"position": chest,
					"direction": outward,
					"collider": enemy,
					"weapon": weapon_id,
					"attacker": weapons.call(&"get_player"),
				})
				ComboMeter.add_points(heavy_stun_points)
		elif enemy.has_method(&"apply_launch"):
			enemy.call(&"apply_launch", launch)
	return count


func _push_props(center: Vector3, radius: float) -> void:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = int(weapons.call(&"get_hit_collision_mask"))
	for result in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body: RigidBody3D = result.get("collider") as RigidBody3D
		if body != null:
			var push: Vector3 = (body.global_position - center).normalized() + Vector3.UP
			body.sleeping = false
			body.apply_central_impulse(push.normalized() * prop_impulse)


## The ground below point (searched from a bit above the player's feet), or point at fallback_y.
func _find_floor(point: Vector3, fallback_y: float) -> Vector3:
	var mask: int = int(weapons.call(&"get_hit_collision_mask"))
	var from: Vector3 = Vector3(point.x, fallback_y + 1.2, point.z)
	var to: Vector3 = Vector3(point.x, fallback_y - 3.0, point.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask, weapons.call(&"get_excluded_rids"))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(point.x, fallback_y, point.z)
	# Standing on an enemy's head doesn't count as ground.
	var collider: Node = hit.get("collider") as Node
	if collider != null and collider.is_in_group(GROUP_ENEMIES):
		return Vector3(point.x, fallback_y, point.z)
	return Vector3(hit.get("position", Vector3(point.x, fallback_y, point.z)))


## Expanding flat ring with a flash of light, used by the slam and the quake.
func spawn_ring(center: Vector3, radius: float, color: Color) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.material = material
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapons.call(&"spawn_in_world", ring)
	ring.global_position = center + Vector3.UP * 0.08
	ring.scale = Vector3(0.3, 0.4, 0.3)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = radius * 1.2
	ring.add_child(light)
	var tween: Tween = ring.create_tween()
	tween.tween_property(ring, ^"scale", Vector3(radius, 0.4, radius), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(material, ^"albedo_color:a", 0.0, 0.4)
	tween.parallel().tween_property(light, ^"light_energy", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)


func _make_player(samples: PackedFloat32Array, volume_db: float) -> AudioStreamPlayer:
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.stream = SoundSynth.make_wav(SoundSynth.normalize(samples))
	audio.volume_db = volume_db
	add_child(audio)
	return audio


static func _get_slam_sound() -> AudioStreamWAV:
	if _slam_sound == null:
		var slam: PackedFloat32Array = SoundSynth.thud(0.9, 90.0, 30.0, 5.0, 1.5, 7.0, 0.45, 911)
		slam = SoundSynth.mix(slam, SoundSynth.thud(0.25, 380.0, 140.0, 25.0, 1.8, 30.0, 0.9, 912), 0.7)
		slam = SoundSynth.mix(slam, SoundSynth.whoosh(0.6, 200.0, 900.0, 300.0, 0.1, 1.2, 913), 0.45, 0.03)
		_slam_sound = SoundSynth.make_wav(SoundSynth.normalize(slam))
	return _slam_sound
