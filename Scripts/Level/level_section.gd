extends Node3D

## One corridor, arena or exit of a generated level. Created and set up by level_generator.gd.
## WAITING until the player walks one tile past its entrance, then ACTIVE: the entrance door shuts
## and the enemy waves come one after another. The next wave doesn't wait for the current one to be
## wiped out: it arrives once next_wave_kill_ratio (half) of the current wave is dead, so waves
## overlap. When the last wave has spawned and every enemy is dead, it is CLEARED and its exit
## door opens.
## Enemies are spawned through an EnemySpawner child (enemy_spawner.gd) whose Marker3D children sit
## on the section's tiles, and every enemy is alerted so it hunts the player right away.

signal section_activated(section: Node3D)
signal wave_started(section: Node3D, wave_index: int, enemy_count: int)
signal section_cleared(section: Node3D)

enum Phase {
	WAITING,
	ACTIVE,
	CLEARED,
}

const GROUP_PLAYER: StringName = &"player"
const METHOD_ALERT: StringName = &"alert"
const METHOD_IS_DEAD: StringName = &"is_dead"
## Must match LevelLayout.Kind.CORRIDOR.
const KIND_CORRIDOR: int = 0

@export_group("Waves")
## Seconds between the player entering and the first wave appearing.
@export var first_wave_delay: float = 0.6
## Seconds between the current wave reaching next_wave_kill_ratio and the next one appearing.
@export var wave_delay: float = 1.5
## Share of the current wave that must be dead before the next wave comes (rounded up, so a wave
## of 3 needs 2 kills). 1 waits for the whole wave.
@export_range(0.0, 1.0) var next_wave_kill_ratio: float = 0.5
## Spawn points closer than this to a living enemy are avoided when there are others.
@export var spawn_point_clear_radius: float = 1.5
## Enemies spawn at least this far from the player when the section has room for it.
@export var min_spawn_distance: float = 9.0
## Fallback distance used when too few tiles are that far away.
@export var fallback_spawn_distance: float = 5.0
## Enemies that fall below this height are removed so a wave can't get stuck.
@export var kill_height: float = -20.0

## LevelLayout.Kind of this section.
var kind: int = 0
## Position in the level, from 0.
var index: int = 0
## Which corridor / arena this is, from 1.
var kind_number: int = 1
## Waves in order; each is an Array[PackedScene], one entry per enemy.
var waves: Array = []
var entrance_door: Node3D
var exit_door: Node3D
var entry_cell: Vector2i = Vector2i.ZERO
var entry_direction: Vector2i = Vector2i(0, -1)
## Walkable tile -> steps from the entry tile.
var cell_distances: Dictionary = {}
## Health packs placed in this section (health_pack.gd), put back by reset_section().
var health_packs: Array[Node3D] = []

var _generator: Node
var _spawner: Node3D
var _phase: Phase = Phase.WAITING
var _wave_index: int = -1
## Every living enemy of this section, from any wave.
var _wave_enemies: Array[Node3D] = []
## Living enemies of the newest wave, and how many it started with.
var _current_wave: Array[Node3D] = []
var _current_wave_size: int = 0
var _wave_timer: float = 0.0
var _player: Node3D


func setup(generator: Node, spawner: Node3D) -> void:
	_generator = generator
	_spawner = spawner


func get_phase() -> Phase:
	return _phase


func is_active() -> bool:
	return _phase == Phase.ACTIVE


func is_cleared() -> bool:
	return _phase == Phase.CLEARED


## 0-based index of the wave in play, or -1 before the first wave.
func get_wave_index() -> int:
	return _wave_index


func get_wave_count() -> int:
	return waves.size()


## Living enemies of this section, from every wave.
func get_alive_count() -> int:
	_remove_dead_enemies()
	return _wave_enemies.size()


## True when the next wave is on its way (the newest wave is broken enough) or there is none left.
func is_next_wave_due() -> bool:
	_remove_dead_enemies()
	return _wave_index + 1 < waves.size() and _is_current_wave_broken()


## Total enemies over all waves.
func get_total_enemy_count() -> int:
	var total: int = 0
	for wave in waves:
		total += (wave as Array).size()
	return total


func has_cell(cell: Vector2i) -> bool:
	return cell_distances.has(cell)


## Where a player who dies in this section comes back: one tile inside the entrance.
func get_respawn_cell() -> Vector2i:
	var inside: Vector2i = entry_cell + entry_direction
	if cell_distances.has(inside):
		return inside
	return entry_cell


func add_health_pack(pack: Node3D) -> void:
	health_packs.append(pack)


## Removes the enemies in play, puts used health packs back and starts the waves over.
## The entrance stays shut.
func reset_section() -> void:
	if _phase != Phase.ACTIVE:
		return
	for pack in health_packs:
		if is_instance_valid(pack):
			pack.call(&"reset_pack")
	for enemy in _wave_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_wave_enemies.clear()
	_current_wave.clear()
	_current_wave_size = 0
	_wave_index = -1
	_wave_timer = first_wave_delay + wave_delay


## Starts the section as if the player had just walked in.
func activate() -> void:
	if _phase != Phase.WAITING:
		return
	_phase = Phase.ACTIVE
	_wave_index = -1
	_wave_timer = first_wave_delay
	if entrance_door != null:
		entrance_door.call(&"close")
	section_activated.emit(self)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.WAITING:
			if _is_player_inside():
				activate()
		Phase.ACTIVE:
			_update_waves(delta)


func _update_waves(delta: float) -> void:
	_remove_dead_enemies()
	if _wave_index + 1 >= waves.size():
		if _wave_enemies.is_empty():
			_clear_section()
		return

	if not _is_current_wave_broken():
		return
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	_spawn_wave(_wave_index + 1)


func _is_current_wave_broken() -> bool:
	if _wave_index < 0:
		return true
	var killed: int = _current_wave_size - _current_wave.size()
	var needed: int = ceili(float(_current_wave_size) * clampf(next_wave_kill_ratio, 0.0, 1.0))
	return killed >= needed


func _spawn_wave(wave_index: int) -> void:
	_wave_index = wave_index
	_wave_timer = wave_delay
	_current_wave.clear()
	_current_wave_size = 0
	var scenes: Array[PackedScene] = []
	scenes.assign(waves[wave_index])
	if scenes.is_empty() or _spawner == null:
		wave_started.emit(self, wave_index, 0)
		return

	var points: Array[Node3D] = _pick_spawn_points(scenes.size())
	var spawned: Array[Node3D] = []
	spawned.assign(_spawner.call(&"spawn_enemies", scenes, points))
	for enemy in spawned:
		if enemy.has_method(METHOD_ALERT):
			enemy.call(METHOD_ALERT)
		_wave_enemies.append(enemy)
		_current_wave.append(enemy)
	_current_wave_size = spawned.size()
	wave_started.emit(self, wave_index, spawned.size())


func _clear_section() -> void:
	_phase = Phase.CLEARED
	if exit_door != null:
		exit_door.call(&"open")
	section_cleared.emit(self)


## Picks spawn tiles away from the player. Corridors prefer the tiles furthest from the entrance,
## so enemies come from ahead; arenas pick at random among the far tiles.
func _pick_spawn_points(count: int) -> Array[Node3D]:
	var player_position: Vector3 = _get_player_position()
	var all_points: Array[Node3D] = []
	all_points.assign(_spawner.call(&"get_spawn_points"))
	var scored: Array = []
	for point in all_points:
		var flat_distance: float = Vector2(point.global_position.x - player_position.x, point.global_position.z - player_position.z).length()
		var cell: Vector2i = point.get_meta(&"cell", Vector2i.ZERO)
		var score: float = randf() * 3.0
		if kind == KIND_CORRIDOR:
			score += float(cell_distances.get(cell, 0)) * 0.5 + randf() * 3.0
		else:
			score += flat_distance * 0.05 + randf() * 4.0
		scored.append([score, flat_distance, point])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))

	var picked: Array[Node3D] = []
	for required_distance in [min_spawn_distance, fallback_spawn_distance, 2.5]:
		for entry in scored:
			if picked.size() >= count:
				break
			var point: Node3D = entry[2]
			if picked.has(point) or float(entry[1]) < required_distance:
				continue
			if required_distance > 2.5 and _is_point_crowded(point):
				continue
			picked.append(point)
		if picked.size() >= count:
			break
	return picked


func _is_point_crowded(point: Node3D) -> bool:
	var radius_squared: float = spawn_point_clear_radius * spawn_point_clear_radius
	for enemy in _wave_enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_squared_to(point.global_position) < radius_squared:
			return true
	return false


func _is_player_inside() -> bool:
	if _generator == null or HealthManager.is_dead():
		return false
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(GROUP_PLAYER) as Node3D
	if _player == null:
		return false
	var cell: Vector2i = _generator.call(&"world_to_cell", _player.global_position)
	return cell_distances.has(cell) and cell != entry_cell


func _get_player_position() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(GROUP_PLAYER) as Node3D
	if _player == null:
		return global_position
	return _player.global_position


func _remove_dead_enemies() -> void:
	for enemy_index in range(_wave_enemies.size() - 1, -1, -1):
		if _is_gone(_wave_enemies[enemy_index]):
			_wave_enemies.remove_at(enemy_index)
	for enemy_index in range(_current_wave.size() - 1, -1, -1):
		if _is_gone(_current_wave[enemy_index]):
			_current_wave.remove_at(enemy_index)


## Untyped on purpose: a freed enemy can't be passed through a typed parameter.
func _is_gone(entry: Variant) -> bool:
	if not is_instance_valid(entry):
		return true
	var enemy: Node3D = entry as Node3D
	if enemy == null or enemy.is_queued_for_deletion():
		return true
	if enemy.has_method(METHOD_IS_DEAD) and bool(enemy.call(METHOD_IS_DEAD)):
		return true
	if enemy.global_position.y < kill_height:
		enemy.queue_free()
		return true
	return false
