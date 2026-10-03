extends Node3D

## The war hammer's S-rank quake: a line of ground bursts rolling forward from the slam. Every
## quake_interval seconds the next burst goes off quake_spacing metres further on, following the
## floor height; a wall in the way ends the line. Each burst hits enemies in quake_radius through
## the hammer's burst() (damage, launch), each enemy at most once per quake, and throws up a rock
## spike with a small ring. Settings come from the hammer (war_hammer.gd). Created by the hammer.

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")

var _hammer: Node
var _position: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
var _pulses_left: int = 0
var _timer: float = 0.0
var _hit: Array = []

static var _rumble_sound: AudioStreamWAV


func start(hammer: Node, origin: Vector3, direction: Vector3) -> void:
	_hammer = hammer
	_position = origin
	_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_pulses_left = maxi(int(hammer.get(&"quake_pulses")), 0)
	_timer = 0.0


func _physics_process(delta: float) -> void:
	if _hammer == null or not is_instance_valid(_hammer) or _pulses_left <= 0:
		queue_free()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = maxf(float(_hammer.get(&"quake_interval")), 0.01)
	_pulses_left -= 1
	if not _advance():
		queue_free()
		return
	var radius: float = float(_hammer.get(&"quake_radius"))
	_hammer.call(&"burst", _position, radius, float(_hammer.get(&"quake_damage")), float(_hammer.get(&"quake_launch")), 0.05, false, _hit)
	_hammer.call(&"spawn_ring", _position, radius, Color(1.0, 0.5, 0.2, 0.6))
	_spawn_spike()
	SoundSynth.play_at(self, _get_rumble_sound(), _position, -2.0, randf_range(0.85, 1.1), 10.0)


## Moves one step forward onto the floor there. False if a wall blocks the way or there is no floor.
func _advance() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var weapons: Node = _hammer.get(&"weapons") as Node
	var mask: int = int(weapons.call(&"get_hit_collision_mask"))
	var excluded: Array[RID] = weapons.call(&"get_excluded_rids")
	var step: float = float(_hammer.get(&"quake_spacing"))
	var next: Vector3 = _position + _direction * step
	var wall_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_position + Vector3.UP * 0.6, next + Vector3.UP * 0.6, mask, excluded)
	var wall: Dictionary = space.intersect_ray(wall_query)
	if not wall.is_empty() and not (wall.get("collider") as Node).is_in_group(&"enemies"):
		return false
	var floor_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(next + Vector3.UP * 1.5, next + Vector3.DOWN * 2.5, mask, excluded)
	var floor_hit: Dictionary = space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		return false
	if (floor_hit.get("collider") as Node).is_in_group(&"enemies"):
		next.y = _position.y
	else:
		next = Vector3(floor_hit.get("position", next))
	_position = next
	return true


func _spawn_spike() -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.27, 0.22)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.15)
	material.emission_energy_multiplier = 0.6
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3(0.6, 1.1, 0.6)
	mesh.material = material
	var spike: MeshInstance3D = MeshInstance3D.new()
	spike.mesh = mesh
	var weapons: Node = _hammer.get(&"weapons") as Node
	weapons.call(&"spawn_in_world", spike)
	spike.global_position = _position + Vector3.DOWN * 0.6
	spike.rotation = Vector3(randf_range(-0.25, 0.25), randf() * TAU, randf_range(-0.25, 0.25))
	var tween: Tween = spike.create_tween()
	tween.tween_property(spike, ^"global_position:y", _position.y + 0.45, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.35)
	tween.tween_property(spike, ^"global_position:y", _position.y - 0.7, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(spike.queue_free)


static func _get_rumble_sound() -> AudioStreamWAV:
	if _rumble_sound == null:
		var rumble: PackedFloat32Array = SoundSynth.thud(0.4, 120.0, 45.0, 9.0, 1.4, 14.0, 0.6, 921)
		rumble = SoundSynth.mix(rumble, SoundSynth.thud(0.15, 420.0, 200.0, 30.0, 1.6, 40.0, 0.9, 922), 0.5)
		_rumble_sound = SoundSynth.make_wav(SoundSynth.normalize(rumble))
	return _rumble_sound
