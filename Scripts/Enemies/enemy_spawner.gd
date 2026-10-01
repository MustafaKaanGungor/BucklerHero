extends Node3D

## Spawns enemies at its Marker3D children on a timer.
## Every spawn_interval seconds it spawns a wave of enemies_per_wave enemies, each at a different
## free spawn point, until max_alive enemies from this spawner are alive.
## Spawned enemies don't come back on their own when they die; the next wave replaces them.

signal enemy_spawned(enemy: Node3D)
signal wave_spawned(spawned_count: int, alive_count: int)

@export_group("Spawning")
## Scene spawned for each enemy when enemy_scenes is empty.
@export var enemy_scene: PackedScene = preload("res://Scenes/Enemies/dummy_enemy.tscn")
## Mix of enemy types. Each spawned enemy is picked at random from this list.
@export var enemy_scenes: Array[PackedScene] = []
## Relative chance of each entry in enemy_scenes being picked. Missing entries count as 1.
@export var enemy_weights: Array[float] = []
## Seconds between waves.
@export var spawn_interval: float = 20.0
## Spawns the first wave right away instead of waiting one interval.
@export var spawn_on_start: bool = true
## Enemies spawned per wave, if there are enough free spawn points and room under max_alive.
@export var enemies_per_wave: int = 3
## Most enemies from this spawner alive at once. A wave only fills up to this number.
@export var max_alive: int = 9
## A spawn point is skipped while a living enemy stands this close to it.
@export var spawn_point_clear_radius: float = 1.2
## Turns spawned enemies to face the spawner's own position (the middle of the arena).
@export var face_center: bool = true

@export_group("Spawn Effect")
## Seconds a spawned enemy takes to grow to full size. 0 disables the effect.
@export var pop_in_time: float = 0.25
## Node inside the enemy that is scaled for the effect. The body itself is never scaled.
@export var enemy_visual_path: NodePath = NodePath("Visual")

var _spawn_points: Array[Node3D] = []
var _alive_enemies: Array[Node3D] = []
var _spawn_timer: float = 0.0


func _ready() -> void:
	refresh_spawn_points()

	_spawn_timer = maxf(spawn_interval, 0.0)
	if spawn_on_start:
		spawn_wave.call_deferred()


## Re-reads the Marker3D children. Call it after adding spawn points from code.
func refresh_spawn_points() -> void:
	_spawn_points.clear()
	for child in get_children():
		var spawn_point: Marker3D = child as Marker3D
		if spawn_point != null:
			_spawn_points.append(spawn_point)


func _physics_process(delta: float) -> void:
	if spawn_interval <= 0.0:
		return

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return

	_spawn_timer += spawn_interval
	spawn_wave()


func get_alive_count() -> int:
	_remove_dead_enemies()
	return _alive_enemies.size()


func get_time_until_next_wave() -> float:
	return maxf(_spawn_timer, 0.0)


## Spawns one wave now. Returns how many enemies were spawned.
func spawn_wave() -> int:
	_remove_dead_enemies()
	if (enemy_scene == null and enemy_scenes.is_empty()) or _spawn_points.is_empty():
		return 0

	var room: int = maxi(max_alive, 0) - _alive_enemies.size()
	var wanted: int = mini(maxi(enemies_per_wave, 0), room)
	var free_points: Array[Node3D] = _get_free_spawn_points()
	free_points.shuffle()
	var spawned_count: int = 0
	for spawn_point in free_points:
		if spawned_count >= wanted:
			break
		if _spawn_enemy(spawn_point, _pick_enemy_scene()) != null:
			spawned_count += 1

	wave_spawned.emit(spawned_count, _alive_enemies.size())
	return spawned_count


## Spawns exactly these enemies, one per entry, at the matching entry of points (reused in turn when
## there are fewer points than enemies). Ignores max_alive. Used by the level sections for set waves.
func spawn_enemies(scenes: Array[PackedScene], points: Array[Node3D]) -> Array[Node3D]:
	_remove_dead_enemies()
	var spawned: Array[Node3D] = []
	if points.is_empty():
		return spawned

	for index in range(scenes.size()):
		var enemy: Node3D = _spawn_enemy(points[index % points.size()], scenes[index])
		if enemy == null:
			continue
		if index >= points.size():
			# A reused point: nudge the enemy aside so the two don't spawn inside each other.
			var angle: float = randf() * TAU
			enemy.global_position += Vector3(cos(angle), 0.0, sin(angle)) * 1.2
			enemy.reset_physics_interpolation()
		spawned.append(enemy)

	wave_spawned.emit(spawned.size(), _alive_enemies.size())
	return spawned


func get_spawn_points() -> Array[Node3D]:
	return _spawn_points


## Living enemies spawned by this spawner.
func get_alive_enemies() -> Array[Node3D]:
	_remove_dead_enemies()
	return _alive_enemies


func _spawn_enemy(spawn_point: Node3D, scene: PackedScene) -> Node3D:
	if scene == null:
		return null
	var enemy: Node3D = scene.instantiate() as Node3D
	if enemy == null:
		return null

	# Arena enemies stay dead; without this the training dummy would respawn by itself.
	if &"respawn_time" in enemy:
		enemy.set(&"respawn_time", 0.0)

	var enemy_parent: Node = get_parent()
	if enemy_parent == null:
		enemy_parent = self
	enemy_parent.add_child(enemy)

	var yaw: float = spawn_point.global_rotation.y
	if face_center:
		var to_center: Vector3 = global_position - spawn_point.global_position
		to_center.y = 0.0
		if to_center.length_squared() > 0.001:
			yaw = atan2(-to_center.x, -to_center.z)
	enemy.global_transform = Transform3D(Basis(Vector3.UP, yaw), spawn_point.global_position)
	enemy.reset_physics_interpolation()

	_play_pop_in(enemy)
	_alive_enemies.append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## Weighted random pick from enemy_scenes, or enemy_scene when the list is empty.
func _pick_enemy_scene() -> PackedScene:
	if enemy_scenes.is_empty():
		return enemy_scene

	var total_weight: float = 0.0
	for index in range(enemy_scenes.size()):
		total_weight += _get_enemy_weight(index)
	if total_weight <= 0.0:
		return enemy_scenes.pick_random()

	var roll: float = randf() * total_weight
	for index in range(enemy_scenes.size()):
		roll -= _get_enemy_weight(index)
		if roll <= 0.0:
			return enemy_scenes[index]
	return enemy_scenes.back()


func _get_enemy_weight(index: int) -> float:
	if enemy_scenes[index] == null:
		return 0.0
	if index >= enemy_weights.size():
		return 1.0
	return maxf(enemy_weights[index], 0.0)


func _play_pop_in(enemy: Node3D) -> void:
	if pop_in_time <= 0.0:
		return

	var visual: Node3D = enemy.get_node_or_null(enemy_visual_path) as Node3D
	if visual == null:
		return

	visual.scale = Vector3.ONE * 0.001
	var tween: Tween = visual.create_tween()
	tween.tween_property(visual, ^"scale", Vector3.ONE, pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _get_free_spawn_points() -> Array[Node3D]:
	var free_points: Array[Node3D] = []
	var clear_radius_squared: float = spawn_point_clear_radius * spawn_point_clear_radius
	for spawn_point in _spawn_points:
		var is_free: bool = true
		for enemy in _alive_enemies:
			if enemy.global_position.distance_squared_to(spawn_point.global_position) < clear_radius_squared:
				is_free = false
				break
		if is_free:
			free_points.append(spawn_point)
	return free_points


func _remove_dead_enemies() -> void:
	for index in range(_alive_enemies.size() - 1, -1, -1):
		var enemy: Node3D = _alive_enemies[index]
		var is_gone: bool = not is_instance_valid(enemy) or enemy.is_queued_for_deletion()
		if not is_gone and enemy.has_method(&"is_dead"):
			is_gone = bool(enemy.call(&"is_dead"))
		if is_gone:
			_alive_enemies.remove_at(index)
