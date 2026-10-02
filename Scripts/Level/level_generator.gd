extends "res://Scripts/main.gd"

## Generates a whole level at startup and runs it.
## A level is always corridor, arena, corridor, arena ... corridor (arena_count arenas, one more
## corridor than arenas), then a small exit. Every section locks the player in until all its enemy
## waves are dead. Difficulty rises from section to section and from wave to wave, only through how
## many enemies spawn and which types; enemy stats are never changed.
## The layout itself is level_layout.gd (tiles); this script builds the geometry, the doors and the
## sections (level_section.gd), decides the waves, handles death and level completion, and gives
## enemies paths around walls through get_navigation_direction() (group level_navigation).

signal level_generated(level_number: int, level_seed: int)
signal level_completed(level_number: int)
## The run started over from the first level (after the death or victory screen).
signal run_restarted
## The final level was finished; the victory screen takes over (it calls restart_run()).
signal run_won

const LevelLayout = preload("res://Scripts/Level/level_layout.gd")
const LevelSection = preload("res://Scripts/Level/level_section.gd")
const LevelDoor = preload("res://Scripts/Level/level_door.gd")
const EnemySpawner = preload("res://Scripts/Enemies/enemy_spawner.gd")
const HealthPack = preload("res://Scripts/Level/health_pack.gd")
const GROUP_LEVEL_NAVIGATION: StringName = &"level_navigation"
const WALL_TEXTURE: Texture2D = preload("res://Assets/images (1).jpg")

@export_group("Level")
## Seed for the layout and the waves. 0 picks a random seed; the seed in use is printed at startup
## so a level can be played again by entering it here.
@export var level_seed: int = 0
## Arenas per level. There is always one more corridor than arenas (first and last are corridors).
@export var arena_count: int = 4
## Starting level number. Each finished level adds one, which raises every enemy budget.
@export var level_number: int = 1
## Finishing this level (stepping on its exit pad after the last corridor) wins the run and shows
## the victory screen instead of building the next level. 0 = endless.
@export var final_level: int = 2

@export_group("Geometry")
## Size of one layout tile in metres. Corridors are one or two tiles wide.
@export var tile_size: float = 4.0
## Height of walls and doors. An invisible ceiling sits on top so nobody climbs out.
@export var wall_height: float = 8.0
## Thickness of the walls.
@export var wall_thickness: float = 0.6
## Wall tint in corridors.
@export var corridor_wall_color: Color = Color(0.62, 0.66, 0.74)
## Wall tint in arenas.
@export var arena_wall_color: Color = Color(0.8, 0.68, 0.56)
## Floor tint in corridors.
@export var corridor_floor_color: Color = Color(0.38, 0.4, 0.44)
## Floor tint in arenas.
@export var arena_floor_color: Color = Color(0.5, 0.44, 0.38)
## Colour of the glowing pad that finishes the level.
@export var exit_pad_color: Color = Color(0.2, 0.9, 0.5)
## World size of one repeat of the wall/floor texture.
@export var texture_world_size: float = 4.0

@export_group("Corridor Shape")
## Fewest and most turns in a corridor.
@export var corridor_min_turns: int = 1
@export var corridor_max_turns: int = 3
## Shortest and longest straight run between turns, in tiles.
@export var corridor_min_run: int = 2
@export var corridor_max_run: int = 4
## Corridors smaller than this many tiles are thrown away and rolled again.
@export var corridor_min_tiles: int = 8
## Runs get one tile longer every this many sections.
@export var corridor_run_growth_sections: int = 4
## Chance that a run (not the last) is two tiles wide.
@export_range(0.0, 1.0) var corridor_wide_chance: float = 0.35
## Chance of a small dead-end nook off the side.
@export_range(0.0, 1.0) var corridor_nook_chance: float = 0.35

@export_group("Arena Shape")
## Smallest and largest arena width in tiles. Later arenas are bigger.
@export var arena_min_size: int = 8
@export var arena_max_size: int = 11
## Fewest and most cover pillars in an arena.
@export var arena_min_pillars: int = 2
@export var arena_max_pillars: int = 5

@export_group("Enemy Types")
## Every enemy type the level can spawn. The arrays below line up with this one.
@export var enemy_scenes: Array[PackedScene] = [
	preload("res://Scenes/Enemies/runner_enemy.tscn"),
	preload("res://Scenes/Enemies/melee_enemy.tscn"),
	preload("res://Scenes/Enemies/thrower_enemy.tscn"),
	preload("res://Scenes/Enemies/gunner_enemy.tscn"),
	preload("res://Scenes/Enemies/brute_enemy.tscn"),
	preload("res://Scenes/Enemies/mortar_enemy.tscn"),
]
## How much of a wave's budget each type uses. Stronger types cost more.
@export var enemy_costs: Array[float] = [1.0, 2.0, 2.0, 3.0, 4.0, 4.0]
## First section (0 = the first corridor) a type can appear in.
@export var enemy_first_section: Array[int] = [0, 0, 1, 2, 3, 5]
## Relative chance of each type before the heavy bias.
@export var enemy_weights: Array[float] = [1.0, 1.2, 1.0, 0.9, 0.8, 0.7]

@export_group("Difficulty")
## Enemy budget of the first corridor; each later section adds corridor_budget_per_section.
@export var corridor_budget_base: float = 5.0
@export var corridor_budget_per_section: float = 1.5
## Enemy budget of an arena at section 0; each section adds arena_budget_per_section.
@export var arena_budget_base: float = 16.0
@export var arena_budget_per_section: float = 3.5
## Budget added to every section for each level finished.
@export var level_budget_bonus: float = 6.0
## Waves in a corridor, plus one from corridor_extra_wave_from_section on.
@export var corridor_waves: int = 2
@export var corridor_extra_wave_from_section: int = 4
## Waves in an arena, plus one from arena_extra_wave_from_section on.
@export var arena_waves: int = 3
@export var arena_extra_wave_from_section: int = 5
## Each later wave of a section gets this much more budget share than the one before
## (first wave 1, second 1 + ramp, ...).
@export var wave_budget_ramp: float = 0.35
## Later sections favour expensive types: a type's chance is multiplied by
## 1 + bias * (cost - 1), with bias growing by this much per section ...
@export var heavy_bias_per_section: float = 0.06
## ... and by this much per wave inside a section.
@export var heavy_bias_per_wave: float = 0.08
## Arenas unlock enemy types this many sections early, for more variety.
@export var arena_unlock_lead: int = 1
## Each arena wave starts with this many different types (if the budget allows) before filling up.
@export var arena_min_enemy_types: int = 3
## Most enemies in a single wave.
@export var corridor_max_per_wave: int = 5
@export var arena_max_per_wave: int = 9
## Fewest enemies in a single wave. Expensive types are skipped while they would leave too little
## budget for this many; if the budget still runs short, the cheapest type fills the gap.
@export var corridor_min_per_wave: int = 2
@export var arena_min_per_wave: int = 3

@export_group("Verticality")
## Height of the raised platforms in arenas. Enemies can jump about 2.6 m, so keep it below that.
@export var arena_platform_height: float = 2.2
## Most raised platforms per arena (big arenas get a second one more often than not).
@export var arena_max_platforms: int = 2
## Fewest and most boxes per arena.
@export var arena_min_boxes: int = 2
@export var arena_max_boxes: int = 5
## Height of the raised stretches in corridors.
@export var corridor_raise_height: float = 1.2
## Chance a corridor has a raised stretch (up a slope, along, back down).
@export_range(0.0, 1.0) var corridor_raise_chance: float = 0.75
## Most boxes per corridor (pushed against the walls).
@export var corridor_max_boxes: int = 2
## Height range of ordinary boxes; the player can jump onto them.
@export var box_min_height: float = 0.9
@export var box_max_height: float = 1.3
## Height of the tall box in a low/tall box pair (climb the low one first).
@export var tall_box_height: float = 2.0
## Chance an arena box comes as a low/tall pair.
@export_range(0.0, 1.0) var box_pair_chance: float = 0.3
## Chance a slope is stairs instead of a ramp. Stairs only look like steps: they collide as a ramp,
## so enemies can walk up them.
@export_range(0.0, 1.0) var stairs_chance: float = 0.5
## Height of one stair step.
@export var stair_step_height: float = 0.3
## Box colour.
@export var box_color: Color = Color(0.62, 0.48, 0.3)
## Colour of platforms, raised floors, ramps and stairs.
@export var raised_color: Color = Color(0.55, 0.55, 0.6)

@export_group("Health Packs")
## Health each pack gives back. The player has 100.
@export var health_pack_heal: float = 35.0
## Packs every arena has, in its corners (away from the doors), so reaching one means running around.
@export var arena_health_packs: int = 1
## Chance of one more pack in the first arena, in the opposite corner from the first ...
@export_range(0.0, 1.0) var arena_extra_pack_chance: float = 0.15
## ... rising by this much with every later arena.
@export_range(0.0, 1.0) var arena_extra_pack_chance_per_arena: float = 0.1
## Corridors before this section index never get a pack (the player starts at full health).
@export var corridor_health_pack_first_section: int = 2
## Chance that a corridor has a pack near its far end ...
@export_range(0.0, 1.0) var corridor_health_pack_chance: float = 0.45
## ... raised by this much for every corridor in a row that had none, and reset after one that had
## one. With the defaults, at most two corridors in a row go without, and runs of packs are rare.
@export_range(0.0, 1.0) var corridor_health_pack_chance_gain: float = 0.35
## Corridor packs go on tiles at least this share of the way from the entrance to the far end.
@export_range(0.0, 1.0) var corridor_health_pack_min_progress: float = 0.65

@export_group("Navigation")
## Half the width enemies need when checking whether a straight line is walkable.
@export var navigation_clearance: float = 0.4
## How many tiles of the path ahead an enemy may cut toward when the way is clear.
@export var navigation_lookahead: int = 6

var _layout: RefCounted
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _level_root: Node3D
var _sections: Array[Node3D] = []
var _current_section: Node3D
var _active_seed: int = 0
var _is_completing: bool = false
var _wall_materials: Dictionary = {}
var _floor_materials: Dictionary = {}
var _navigation_target_cell: Vector2i = Vector2i(2147483647, 0)
var _navigation_field: Dictionary = {}
var _corridors_without_pack: int = 0
var _start_level_number: int = 1
var _run_kills: int = 0
var _run_time: float = 0.0
var _best_rank: int = -1
var _is_run_won: bool = false


func _ready() -> void:
	add_to_group(GROUP_LEVEL_NAVIGATION)
	_start_level_number = level_number
	ComboMeter.rank_changed.connect(_on_combo_rank_changed)
	generate_level()
	super._ready()


func _process(delta: float) -> void:
	if not HealthManager.is_dead() and not _is_run_won:
		_run_time += delta


## Starts the whole run again: back to the starting level (a new layout when level_seed is 0),
## first corridor, with health, stamina, combo meter and loudness reset. Called by the death screen.
func restart_run() -> void:
	level_number = _start_level_number
	_is_run_won = false
	for projectile in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		projectile.queue_free()
	generate_level()
	_run_kills = 0
	_run_time = 0.0
	_best_rank = -1
	if player != null and is_instance_valid(player):
		player.set_physics_process(true)
		if player.has_method(&"stop_shield_charge"):
			player.call(&"stop_shield_charge")
		player.velocity = Vector3.ZERO
		spawn_player()
		player.reset_physics_interpolation()
	HealthManager.reset_health()
	StaminaManager.reset_stamina()
	ComboMeter.reset()
	LoudnessManger.reset_loudness()
	TotalLoudnessManager.reset_total_loudness()
	InputManager.reset_movement_state()
	run_restarted.emit()


## What the death screen shows: level, section label, kills, best combo rank letter, time (s).
func get_run_summary() -> Dictionary:
	return {
		"level": level_number,
		"section": _get_section_label(_current_section if _current_section != null else (_sections[0] if not _sections.is_empty() else null)),
		"kills": _run_kills,
		"best_rank": ComboMeter.get_rank_letter(_best_rank) if _best_rank >= 0 else "-",
		"time": _run_time,
	}


## Throws away the current level (if any) and builds a new one for level_number.
func generate_level() -> void:
	_clear_level()
	_active_seed = level_seed
	if _active_seed == 0:
		_active_seed = randi()
	_active_seed += (level_number - 1) * 7919
	_rng.seed = _active_seed

	_layout = LevelLayout.new()
	_copy_layout_settings()
	if not bool(_layout.call(&"generate", _rng, _get_section_kinds())):
		push_error("Level generation failed for seed %d." % _active_seed)
		return
	print("Generated level %d with seed %d" % [level_number, _active_seed])

	_level_root = Node3D.new()
	_level_root.name = "Level"
	add_child(_level_root)
	_build_floor_and_ceiling()
	_build_walls()
	_build_features()
	_build_sections()
	_place_spawn_marker(_layout.get(&"start_cell"), _layout.get(&"start_direction"))
	level_generated.emit(level_number, _active_seed)


func get_level_seed() -> int:
	return _active_seed


func get_layout() -> RefCounted:
	return _layout


func get_sections() -> Array[Node3D]:
	return _sections


## The section the player is fighting in (or last entered), or null before the first one starts.
func get_current_section() -> Node3D:
	return _current_section


func world_to_cell(world_position: Vector3) -> Vector2i:
	var size: float = maxf(tile_size, 0.001)
	return Vector2i(floori(world_position.x / size), floori(world_position.z / size))


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * tile_size, 0.0, (float(cell.y) + 0.5) * tile_size)


## Text for the section HUD.
func get_hud_text() -> String:
	var section: Node3D = _current_section
	if section == null:
		if _sections.is_empty():
			return ""
		section = _sections[0]
	if int(section.get(&"kind")) == LevelLayout.Kind.EXIT:
		return "LEVEL %d COMPLETE" % level_number
	var text: String = "LEVEL %d  ·  %s" % [level_number, _get_section_label(section)]
	if bool(section.call(&"is_cleared")):
		return text + "  ·  CLEARED, MOVE ON"
	if not bool(section.call(&"is_active")):
		return text
	var wave_index: int = int(section.call(&"get_wave_index"))
	var wave_count: int = int(section.call(&"get_wave_count"))
	var alive: int = int(section.call(&"get_alive_count"))
	if wave_index < 0:
		return text + "  ·  WAVE 1/%d INCOMING" % wave_count
	var wave_text: String = "  ·  WAVE %d/%d  ·  %d LEFT" % [wave_index + 1, wave_count, alive]
	if bool(section.call(&"is_next_wave_due")):
		wave_text += "  ·  WAVE %d INCOMING" % (wave_index + 2)
	return text + wave_text


## Which way an enemy at from should walk to reach to, following the level's tiles around walls.
## Returns a flat direction, or ZERO when a straight line is fine (or either point is off the level).
func get_navigation_direction(from: Vector3, to: Vector3) -> Vector3:
	if _layout == null:
		return Vector3.ZERO
	var from_cell: Vector2i = world_to_cell(from)
	var to_cell: Vector2i = world_to_cell(to)
	if from_cell == to_cell or not _is_cell_walkable(from_cell) or not _is_cell_walkable(to_cell):
		return Vector3.ZERO
	if _is_walk_clear(from, to):
		return Vector3.ZERO

	if to_cell != _navigation_target_cell:
		_navigation_target_cell = to_cell
		_navigation_field = _layout.call(&"get_distance_field", to_cell)
	if not _navigation_field.has(from_cell):
		return Vector3.ZERO

	# Follow the distance field downhill and head for the furthest path tile in plain reach.
	var current: Vector2i = from_cell
	var target_point: Vector3 = Vector3.ZERO
	var has_target: bool = false
	for step in range(maxi(navigation_lookahead, 1)):
		var next_cell: Vector2i = _get_downhill_cell(current)
		if next_cell == current:
			break
		current = next_cell
		var point: Vector3 = cell_to_world(current)
		if _is_walk_clear(from, point):
			target_point = point
			has_target = true
		elif has_target:
			break
		else:
			# Not even the next tile is in plain reach (hugging a corner): aim for it anyway.
			target_point = point
			has_target = true
			break
	if not has_target:
		return Vector3.ZERO

	var direction: Vector3 = target_point - from
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return direction.normalized()


## The last level is done: the player stops where they stand and the victory screen shows.
func _win_run() -> void:
	_is_run_won = true
	level_completed.emit(level_number)
	if player != null and is_instance_valid(player):
		if player.has_method(&"stop_shield_charge"):
			player.call(&"stop_shield_charge")
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
	run_won.emit()


## Death ends the run: the player freezes where they fell and the death screen
## (Scripts/UI/death_screen.gd) takes over; it calls restart_run() when the player continues.
## Unlike main.gd, nothing is reset here.
func _on_player_died() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method(&"stop_shield_charge"):
		player.call(&"stop_shield_charge")
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)


func _on_combo_rank_changed(rank: int, _previous_rank: int) -> void:
	_best_rank = maxi(_best_rank, rank)


func _on_enemy_killed(_section: Node3D) -> void:
	_run_kills += 1


func _get_section_label(section: Node3D) -> String:
	if section == null or not is_instance_valid(section):
		return ""
	var kind: int = int(section.get(&"kind"))
	if kind == LevelLayout.Kind.ARENA:
		return "ARENA %d/%d" % [int(section.get(&"kind_number")), arena_count]
	if kind == LevelLayout.Kind.EXIT:
		return "EXIT"
	return "CORRIDOR %d/%d" % [int(section.get(&"kind_number")), arena_count + 1]


func _on_section_activated(section: Node3D) -> void:
	_current_section = section
	if int(section.get(&"kind")) == LevelLayout.Kind.EXIT:
		_complete_level.call_deferred()


## True from finishing the final level until the run restarts.
func is_run_won() -> bool:
	return _is_run_won


func _complete_level() -> void:
	if _is_completing or _is_run_won:
		return
	if final_level > 0 and level_number >= final_level:
		_win_run()
		return
	_is_completing = true
	level_completed.emit(level_number)
	level_number += 1
	generate_level()
	if player != null and is_instance_valid(player):
		if player.has_method(&"stop_shield_charge"):
			player.call(&"stop_shield_charge")
		player.velocity = Vector3.ZERO
		spawn_player()
		player.reset_physics_interpolation()
	HealthManager.reset_health()
	StaminaManager.reset_stamina()
	_is_completing = false


func _get_section_kinds() -> Array[int]:
	var kinds: Array[int] = [LevelLayout.Kind.CORRIDOR]
	for arena in range(maxi(arena_count, 0)):
		kinds.append(LevelLayout.Kind.ARENA)
		kinds.append(LevelLayout.Kind.CORRIDOR)
	kinds.append(LevelLayout.Kind.EXIT)
	return kinds


func _copy_layout_settings() -> void:
	for property in [
		&"corridor_min_turns", &"corridor_max_turns", &"corridor_min_run", &"corridor_max_run", &"corridor_min_tiles",
		&"corridor_run_growth_sections", &"corridor_wide_chance", &"corridor_nook_chance",
		&"arena_min_size", &"arena_max_size", &"arena_min_pillars", &"arena_max_pillars",
		&"arena_platform_height", &"arena_max_platforms", &"arena_min_boxes", &"arena_max_boxes",
		&"corridor_raise_height", &"corridor_raise_chance", &"corridor_max_boxes", &"box_min_height",
		&"box_max_height", &"tall_box_height", &"box_pair_chance", &"stairs_chance",
	]:
		_layout.set(property, get(property))


func _clear_level() -> void:
	_current_section = null
	_sections.clear()
	_corridors_without_pack = 0
	_navigation_target_cell = Vector2i(2147483647, 0)
	_navigation_field = {}
	if _level_root != null and is_instance_valid(_level_root):
		remove_child(_level_root)
		_level_root.queue_free()
	_level_root = null


func _place_spawn_marker(cell: Vector2i, direction: Vector2i) -> void:
	var marker: Node3D = get_node_or_null(player_spawn_path) as Node3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = String(player_spawn_path)
		add_child(marker)
	var yaw: float = atan2(-float(direction.x), -float(direction.y))
	marker.global_transform = Transform3D(Basis(Vector3.UP, yaw), cell_to_world(cell) + Vector3.UP * 0.05)


# --- Geometry -----------------------------------------------------------------------------------

func _build_floor_and_ceiling() -> void:
	var cells: Dictionary = _layout.get(&"cells")
	var solid: Dictionary = _layout.get(&"solid")
	var min_cell: Vector2i = Vector2i(2147483647, 2147483647)
	var max_cell: Vector2i = Vector2i(-2147483647, -2147483647)
	for cell in cells.keys() + solid.keys():
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	min_cell -= Vector2i(2, 2)
	max_cell += Vector2i(2, 2)
	var width: float = float(max_cell.x - min_cell.x + 1) * tile_size
	var depth: float = float(max_cell.y - min_cell.y + 1) * tile_size
	var center: Vector3 = Vector3(float(min_cell.x) * tile_size + width * 0.5, 0.0, float(min_cell.y) * tile_size + depth * 0.5)

	# One seamless collision slab each for floor and ceiling, so bodies never catch on seams.
	_add_box(&"FloorCollision", center + Vector3.DOWN * 0.5, Vector3(width, 1.0, depth), null, true)
	_add_box(&"Ceiling", center + Vector3.UP * (wall_height + 0.5), Vector3(width, 1.0, depth), null, true)

	# Visible floor: one strip per row of tiles per section, tinted by section kind.
	var sections: Array[Dictionary] = _layout.get(&"sections")
	for section in sections:
		var section_index: int = int(section["index"])
		var rows: Dictionary = {}
		var footprint: Array = []
		footprint.append_array(section["cells"])
		footprint.append_array(section["solid"])
		for cell in footprint:
			if not rows.has(cell.y):
				rows[cell.y] = []
			(rows[cell.y] as Array).append(cell.x)
		var material: StandardMaterial3D = _get_floor_material(int(section["kind"]))
		for row in rows.keys():
			var columns: Array = rows[row]
			columns.sort()
			for run in _get_runs(columns):
				var start_x: int = run[0]
				var end_x: int = run[1]
				var strip_width: float = float(end_x - start_x + 1) * tile_size
				var strip_center: Vector3 = Vector3(float(start_x) * tile_size + strip_width * 0.5, -0.05, (float(row) + 0.5) * tile_size)
				_add_box(StringName("Floor%d" % section_index), strip_center, Vector3(strip_width, 0.1, tile_size), material, false)

		if int(section["kind"]) == LevelLayout.Kind.EXIT:
			var pad_cell: Vector2i = section["exit_cell"]
			var pad_material: StandardMaterial3D = StandardMaterial3D.new()
			pad_material.albedo_color = exit_pad_color
			pad_material.emission_enabled = true
			pad_material.emission = exit_pad_color
			pad_material.emission_energy_multiplier = 2.5
			_add_box(&"ExitPad", cell_to_world(pad_cell) + Vector3.UP * 0.03, Vector3(tile_size * 0.7, 0.06, tile_size * 0.7), pad_material, false)

	# Pillars.
	for cell in solid.keys():
		var kind: int = int((sections[int(solid[cell])])["kind"])
		_add_box(&"Pillar", cell_to_world(cell) + Vector3.UP * (wall_height * 0.5 - 0.25), Vector3(tile_size, wall_height + 0.5, tile_size), _get_wall_material(kind), true)


## Walls go on every tile edge between a walkable tile and anything it isn't joined to.
## Edges on the same grid line with the same tint are merged into one long box.
func _build_walls() -> void:
	var cells: Dictionary = _layout.get(&"cells")
	var sections: Array[Dictionary] = _layout.get(&"sections")
	var door_edges: Dictionary = _layout.get(&"door_edges")
	# Key Vector3i(line, along, kind) for horizontal (z) lines and vertical (x) lines.
	var horizontal: Dictionary = {}
	var vertical: Dictionary = {}
	for cell in cells.keys():
		var kind: int = int(sections[int(cells[cell])]["kind"])
		for direction in LevelLayout.DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if bool(_layout.call(&"are_connected", cell, neighbor)):
				continue
			if door_edges.has(LevelLayout.get_edge_key(cell, neighbor)):
				continue
			if direction.y != 0:
				var line: int = cell.y + (1 if direction.y > 0 else 0)
				horizontal[Vector2i(line, cell.x)] = kind
			else:
				var line: int = cell.x + (1 if direction.x > 0 else 0)
				vertical[Vector2i(line, cell.y)] = kind

	_add_wall_runs(horizontal, true)
	_add_wall_runs(vertical, false)


func _add_wall_runs(edges: Dictionary, is_horizontal: bool) -> void:
	var by_line: Dictionary = {}
	for key in edges.keys():
		var line_key: Vector2i = Vector2i(key.x, int(edges[key]))
		if not by_line.has(line_key):
			by_line[line_key] = []
		(by_line[line_key] as Array).append(key.y)

	for line_key in by_line.keys():
		var positions: Array = by_line[line_key]
		positions.sort()
		var material: StandardMaterial3D = _get_wall_material(line_key.y)
		for run in _get_runs(positions):
			var length: float = float(int(run[1]) - int(run[0]) + 1) * tile_size
			var along_center: float = float(int(run[0])) * tile_size + length * 0.5
			var line_position: float = float(line_key.x) * tile_size
			var center: Vector3 = Vector3(along_center, wall_height * 0.5 - 0.25, line_position)
			var size: Vector3 = Vector3(length + wall_thickness, wall_height + 0.5, wall_thickness)
			if not is_horizontal:
				center = Vector3(line_position, center.y, along_center)
				size = Vector3(wall_thickness, size.y, size.x)
			_add_box(&"Wall", center, size, material, true)


func _build_sections() -> void:
	var sections: Array[Dictionary] = _layout.get(&"sections")
	var doors: Array[Node3D] = []
	doors.resize(sections.size())

	# Door i sits between section i - 1's exit and section i's entry.
	for index in range(1, sections.size()):
		var previous: Dictionary = sections[index - 1]
		var exit_cell: Vector2i = previous["exit_cell"]
		var direction: Vector2i = previous["exit_direction"]
		var door: StaticBody3D = StaticBody3D.new()
		door.set_script(LevelDoor)
		door.name = "Door%d" % index
		_level_root.add_child(door)
		var edge_center: Vector3 = cell_to_world(exit_cell) + Vector3(float(direction.x), 0.0, float(direction.y)) * (tile_size * 0.5)
		var yaw: float = atan2(-float(direction.x), -float(direction.y))
		door.transform = Transform3D(Basis(Vector3.UP, yaw), edge_center)
		door.call(&"setup", Vector3(tile_size, wall_height, wall_thickness * 0.8), false)
		doors[index] = door

	for section_data in sections:
		var index: int = int(section_data["index"])
		var kind: int = int(section_data["kind"])
		var section: Node3D = Node3D.new()
		section.set_script(LevelSection)
		section.name = "%s%d" % [["Corridor", "Arena", "Exit"][kind], int(section_data["kind_number"])]
		section.set(&"kind", kind)
		section.set(&"index", index)
		section.set(&"kind_number", int(section_data["kind_number"]))
		section.set(&"entry_cell", section_data["entry_cell"])
		section.set(&"entry_direction", section_data["entry_direction"])
		section.set(&"cell_distances", _layout.call(&"get_distance_field", section_data["entry_cell"], index))
		section.set(&"entrance_door", doors[index])
		section.set(&"exit_door", doors[index + 1] if index + 1 < doors.size() else null)
		if kind != LevelLayout.Kind.EXIT:
			section.set(&"waves", _build_waves(index, kind))
		_level_root.add_child(section)

		var spawner: Node3D = Node3D.new()
		spawner.set_script(EnemySpawner)
		spawner.name = "EnemySpawner"
		spawner.set(&"spawn_interval", 0.0)
		spawner.set(&"spawn_on_start", false)
		spawner.set(&"face_center", false)
		section.add_child(spawner)
		for cell in section_data["cells"]:
			if cell == section_data["entry_cell"] or _is_feature_cell(cell, [&"box", &"ramp", &"stairs"]):
				continue
			var marker: Marker3D = Marker3D.new()
			marker.set_meta(&"cell", cell)
			spawner.add_child(marker)
			marker.position = cell_to_world(cell) + Vector3.UP * (get_floor_height(cell) + 0.1)
		spawner.call(&"refresh_spawn_points")

		section.call(&"setup", self, spawner)
		section.connect(&"section_activated", _on_section_activated)
		section.connect(&"enemy_killed", _on_enemy_killed)
		_sections.append(section)
		_place_health_packs(section, section_data)


# --- Health packs -------------------------------------------------------------------------------

## Arenas always get arena_health_packs in their corners, sometimes one more (likelier in later
## arenas). Corridors get one near the far end by a chance that grows after every corridor without,
## so the player is never flooded with packs nor starved of them for long.
func _place_health_packs(section: Node3D, section_data: Dictionary) -> void:
	var kind: int = int(section_data["kind"])
	var index: int = int(section_data["index"])
	var cells: Array[Vector2i] = []
	if kind == LevelLayout.Kind.ARENA:
		var count: int = maxi(arena_health_packs, 0)
		var extra_chance: float = arena_extra_pack_chance + arena_extra_pack_chance_per_arena * float(int(section_data["kind_number"]) - 1)
		if _rng.randf() < extra_chance:
			count += 1
		cells = _pick_arena_pack_cells(section_data, count)
	elif kind == LevelLayout.Kind.CORRIDOR and index >= corridor_health_pack_first_section:
		var chance: float = corridor_health_pack_chance + corridor_health_pack_chance_gain * float(_corridors_without_pack)
		if _rng.randf() < chance:
			cells = _pick_corridor_pack_cells(section, section_data)
		_corridors_without_pack = 0 if not cells.is_empty() else _corridors_without_pack + 1

	for cell in cells:
		var pack: Node3D = Node3D.new()
		pack.set_script(HealthPack)
		pack.name = "HealthPack"
		pack.set(&"heal_amount", health_pack_heal)
		section.add_child(pack, true)
		pack.position = cell_to_world(cell) + _get_corner_offset(cell, int(section_data["index"]))
		section.call(&"add_health_pack", pack)


## Corner tiles: far from the arena's middle and boxed in by walls, away from both doors.
## A second pack goes as far from the first as possible.
func _pick_arena_pack_cells(section_data: Dictionary, count: int) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	if count <= 0:
		return picked
	var section_cells: Array[Vector2i] = []
	section_cells.assign(section_data["cells"])
	var entry: Vector2i = section_data["entry_cell"]
	var exit_cell: Vector2i = section_data["exit_cell"]
	var middle: Vector2 = Vector2.ZERO
	for cell in section_cells:
		middle += Vector2(cell)
	middle /= float(maxi(section_cells.size(), 1))

	var scored: Array = []
	for cell in section_cells:
		if _manhattan(cell, entry) <= 3 or _manhattan(cell, exit_cell) <= 2 or _is_feature_cell(cell):
			continue
		# A real corner has a wall on one x side and one y side.
		var closed_x: bool = not section_cells.has(cell + Vector2i(1, 0)) or not section_cells.has(cell + Vector2i(-1, 0))
		var closed_y: bool = not section_cells.has(cell + Vector2i(0, 1)) or not section_cells.has(cell + Vector2i(0, -1))
		if not closed_x or not closed_y:
			continue
		scored.append([Vector2(cell).distance_to(middle) + _rng.randf() * 1.5, cell])
	if scored.is_empty():
		return picked
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))

	var top_count: int = maxi(ceili(scored.size() * 0.4), 1)
	picked.append(scored[_rng.randi_range(0, top_count - 1)][1])
	while picked.size() < count:
		var best: Vector2i = picked[0]
		var best_distance: float = -1.0
		for entry_score in scored:
			var cell: Vector2i = entry_score[1]
			if picked.has(cell):
				continue
			var nearest: float = INF
			for other in picked:
				nearest = minf(nearest, Vector2(cell).distance_to(Vector2(other)))
			if nearest > best_distance:
				best_distance = nearest
				best = cell
		if best_distance < 0.0:
			break
		picked.append(best)
	return picked


## A random tile in the far part of the corridor (dead-end nooks included), never the exit tile.
func _pick_corridor_pack_cells(section: Node3D, section_data: Dictionary) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	var distances: Dictionary = section.get(&"cell_distances")
	var furthest: int = 0
	for cell in distances.keys():
		furthest = maxi(furthest, int(distances[cell]))
	var threshold: int = ceili(float(furthest) * corridor_health_pack_min_progress)
	var candidates: Array[Vector2i] = []
	for cell in distances.keys():
		if int(distances[cell]) >= threshold and cell != section_data["exit_cell"] and not _is_feature_cell(cell):
			candidates.append(cell)
	if not candidates.is_empty():
		candidates.sort()
		picked.append(candidates[_rng.randi_range(0, candidates.size() - 1)])
	return picked


## Pushes a pack from the tile centre toward the walls around it, into the corner.
func _get_corner_offset(cell: Vector2i, section_index: int) -> Vector3:
	var cells: Dictionary = _layout.get(&"cells")
	var reach: float = maxf(tile_size * 0.5 - 1.0, 0.0)
	var push: Vector2 = Vector2.ZERO
	# Per axis, move toward the closed side; a tile closed on both sides (or neither) stays centred.
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var plus_closed: bool = int(cells.get(cell + axis, -1)) != section_index
		var minus_closed: bool = int(cells.get(cell - axis, -1)) != section_index
		if plus_closed != minus_closed:
			push += Vector2(axis) * (reach if plus_closed else -reach)
	return Vector3(push.x, 0.0, push.y)


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _add_box(node_name: StringName, center: Vector3, size: Vector3, material: StandardMaterial3D, with_collision: bool) -> Node3D:
	var node: Node3D
	if with_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		node = body
	else:
		node = Node3D.new()
	node.name = node_name
	if material != null:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		mesh.material = material
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		node.add_child(mesh_instance)
	_level_root.add_child(node, true)
	node.position = center
	return node


## Splits sorted integers into [start, end] runs of consecutive values.
func _get_runs(sorted_values: Array) -> Array:
	var runs: Array = []
	for value in sorted_values:
		if not runs.is_empty() and int(value) == int(runs.back()[1]) + 1:
			runs.back()[1] = int(value)
		else:
			runs.append([int(value), int(value)])
	return runs


func _get_wall_material(kind: int) -> StandardMaterial3D:
	if not _wall_materials.has(kind):
		_wall_materials[kind] = _make_material(arena_wall_color if kind == LevelLayout.Kind.ARENA else corridor_wall_color)
	return _wall_materials[kind]


func _get_floor_material(kind: int) -> StandardMaterial3D:
	if not _floor_materials.has(kind):
		_floor_materials[kind] = _make_material(arena_floor_color if kind == LevelLayout.Kind.ARENA else corridor_floor_color)
	return _floor_materials[kind]


## Height of the floor at a tile's centre: raised for platforms and raised corridor floors, halfway
## up for ramps and stairs, 0 elsewhere (boxes don't count; they are smaller than their tile).
func get_floor_height(cell: Vector2i) -> float:
	if _layout == null:
		return 0.0
	return float((_layout.get(&"floor_heights") as Dictionary).get(cell, 0.0))


## True if a feature sits on this tile (of one of these types, when given).
func _is_feature_cell(cell: Vector2i, types: Array = []) -> bool:
	var feature_cells: Dictionary = _layout.get(&"feature_cells")
	if not feature_cells.has(cell):
		return false
	return types.is_empty() or types.has(feature_cells[cell])


## Platforms, raised corridor floors, ramps, stairs and boxes. All solid on layer 1.
func _build_features() -> void:
	var features: Array[Dictionary] = []
	features.assign(_layout.get(&"features"))
	var raised_material: StandardMaterial3D = _make_material(raised_color)
	var box_material: StandardMaterial3D = _make_material(box_color)
	for feature in features:
		match feature["type"]:
			&"block":
				_build_block(feature, raised_material)
			&"ramp":
				_build_ramp(feature, raised_material)
			&"stairs":
				_build_stairs(feature, raised_material)
			&"box":
				_build_box(feature, box_material)


## A raised floor: one solid box over its whole rectangle of tiles, so its top has no seams.
func _build_block(feature: Dictionary, material: StandardMaterial3D) -> void:
	var min_cell: Vector2i = Vector2i(2147483647, 2147483647)
	var max_cell: Vector2i = Vector2i(-2147483647, -2147483647)
	for cell in feature["cells"]:
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	var height: float = float(feature["height"])
	var size: Vector3 = Vector3(float(max_cell.x - min_cell.x + 1) * tile_size, height, float(max_cell.y - min_cell.y + 1) * tile_size)
	var center: Vector3 = Vector3(float(min_cell.x) * tile_size + size.x * 0.5, height * 0.5, float(min_cell.y) * tile_size + size.z * 0.5)
	_add_box(&"Platform", center, size, material, true)


## A wedge filling one tile, low at the downhill edge and height at the uphill edge.
func _build_ramp(feature: Dictionary, material: StandardMaterial3D) -> void:
	var body: StaticBody3D = _make_slope_body(feature)
	var prism: PrismMesh = _make_slope_prism(feature)
	prism.material = material
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = prism
	body.add_child(mesh_instance)


## Steps you can see, but a smooth wedge to collide with, so enemies (which can't step up) and the
## player both walk up them evenly.
func _build_stairs(feature: Dictionary, material: StandardMaterial3D) -> void:
	var body: StaticBody3D = _make_slope_body(feature)
	var height: float = float(feature["height"])
	var step_count: int = maxi(ceili(height / maxf(stair_step_height, 0.05)), 1)
	var step_depth: float = tile_size / float(step_count)
	for step in range(step_count):
		var step_top: float = height * float(step + 1) / float(step_count)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(step_depth, step_top, tile_size)
		mesh.material = material
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		# In the body's space +X is downhill; the first step sits at the downhill edge.
		mesh_instance.position = Vector3(tile_size * 0.5 - step_depth * (float(step) + 0.5), step_top * 0.5 - height * 0.5, 0.0)
		body.add_child(mesh_instance)


## The collision body of a ramp or stairs: a wedge-shaped convex shape. In its own space the uphill
## edge is at -X and the downhill edge at +X.
func _make_slope_body(feature: Dictionary) -> StaticBody3D:
	var cell: Vector2i = feature["cell"]
	var uphill: Vector2i = feature["direction"]
	var height: float = float(feature["height"])
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Slope"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = _make_slope_prism(feature).create_convex_shape(true, false)
	body.add_child(collision)
	_level_root.add_child(body, true)
	# Local -X points uphill.
	var yaw: float = atan2(float(uphill.y), -float(uphill.x))
	body.transform = Transform3D(Basis(Vector3.UP, yaw), cell_to_world(cell) + Vector3.UP * (height * 0.5))
	return body


func _make_slope_prism(feature: Dictionary) -> PrismMesh:
	var prism: PrismMesh = PrismMesh.new()
	# left_to_right 0 puts the top edge straight above the -X bottom edge: a right-angled wedge.
	prism.left_to_right = 0.0
	prism.size = Vector3(tile_size, float(feature["height"]), tile_size)
	return prism


func _build_box(feature: Dictionary, material: StandardMaterial3D) -> void:
	var cell: Vector2i = feature["cell"]
	var height: float = float(feature["height"])
	var side: float = tile_size * clampf(float(feature["footprint"]), 0.1, 1.0)
	var room: float = (tile_size - side) * 0.5
	var offset: Vector2 = feature["offset"]
	var center: Vector3 = cell_to_world(cell) + Vector3(offset.x * room, height * 0.5, offset.y * room)
	_add_box(&"Box", center, Vector3(side, height, side), material, true)


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = WALL_TEXTURE
	material.albedo_color = color
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	var scale: float = 1.0 / maxf(texture_world_size, 0.01)
	material.uv1_scale = Vector3(scale, scale, scale)
	material.roughness = 0.9
	return material


# --- Waves --------------------------------------------------------------------------------------

## The enemy lists for every wave of a section. The section's budget is shared out with later
## waves getting more, and later waves (and sections) lean toward stronger types.
func _build_waves(section_index: int, kind: int) -> Array:
	var is_arena: bool = kind == LevelLayout.Kind.ARENA
	var level_bonus: float = level_budget_bonus * float(maxi(level_number - 1, 0))
	var budget: float = corridor_budget_base + corridor_budget_per_section * float(section_index) + level_bonus
	var wave_count: int = corridor_waves + (1 if section_index >= corridor_extra_wave_from_section else 0)
	if is_arena:
		budget = arena_budget_base + arena_budget_per_section * float(section_index) + level_bonus
		wave_count = arena_waves + (1 if section_index >= arena_extra_wave_from_section else 0)
	wave_count = maxi(wave_count, 1)

	var total_share: float = 0.0
	for wave in range(wave_count):
		total_share += 1.0 + wave_budget_ramp * float(wave)

	var waves: Array = []
	for wave in range(wave_count):
		var share: float = (1.0 + wave_budget_ramp * float(wave)) / maxf(total_share, 0.001)
		waves.append(_compose_wave(budget * share, section_index, wave, is_arena))
	return waves


func _compose_wave(budget: float, section_index: int, wave: int, is_arena: bool) -> Array[PackedScene]:
	var unlock_section: int = section_index + (arena_unlock_lead if is_arena else 0)
	var available: Array[int] = []
	for type_index in range(enemy_scenes.size()):
		if enemy_scenes[type_index] == null:
			continue
		if _get_first_section(type_index) <= unlock_section:
			available.append(type_index)
	var picks: Array[PackedScene] = []
	if available.is_empty():
		return picks

	var cap: int = maxi(arena_max_per_wave if is_arena else corridor_max_per_wave, 1)
	var minimum: int = clampi(arena_min_per_wave if is_arena else corridor_min_per_wave, 1, cap)
	var bias: float = heavy_bias_per_section * float(section_index) + heavy_bias_per_wave * float(wave)
	var remaining: float = budget
	var cheapest: int = available[0]
	for type_index in available:
		if _get_cost(type_index) < _get_cost(cheapest):
			cheapest = type_index
	var cheapest_cost: float = _get_cost(cheapest)

	if is_arena:
		var pool: Array[int] = available.duplicate()
		for variety in range(mini(arena_min_enemy_types, available.size())):
			if picks.size() >= cap:
				break
			var type_index: int = _pick_enemy_type(pool, bias, _get_spendable(remaining, picks.size(), minimum, cheapest_cost))
			if type_index < 0:
				break
			picks.append(enemy_scenes[type_index])
			remaining -= _get_cost(type_index)
			pool.erase(type_index)

	while picks.size() < cap:
		var type_index: int = _pick_enemy_type(available, bias, _get_spendable(remaining, picks.size(), minimum, cheapest_cost))
		if type_index < 0:
			break
		picks.append(enemy_scenes[type_index])
		remaining -= _get_cost(type_index)

	while picks.size() < minimum:
		picks.append(enemy_scenes[cheapest])
	return picks


## Budget the next pick may use while still leaving enough for the cheapest type to reach minimum.
func _get_spendable(remaining: float, picked: int, minimum: int, cheapest_cost: float) -> float:
	var still_needed: int = maxi(minimum - picked - 1, 0)
	return remaining - float(still_needed) * cheapest_cost


func _pick_enemy_type(candidates: Array[int], bias: float, remaining: float) -> int:
	var total: float = 0.0
	var weights: Array[float] = []
	for type_index in candidates:
		var weight: float = 0.0
		var cost: float = _get_cost(type_index)
		if cost <= remaining + 0.001:
			var base_weight: float = enemy_weights[type_index] if type_index < enemy_weights.size() else 1.0
			weight = maxf(base_weight, 0.0) * maxf(1.0 + bias * (cost - 1.0), 0.0)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return -1
	var roll: float = _rng.randf() * total
	for candidate in range(candidates.size()):
		roll -= weights[candidate]
		if roll <= 0.0 and weights[candidate] > 0.0:
			return candidates[candidate]
	for candidate in range(candidates.size() - 1, -1, -1):
		if weights[candidate] > 0.0:
			return candidates[candidate]
	return -1


func _get_cost(type_index: int) -> float:
	return maxf(enemy_costs[type_index], 0.1) if type_index < enemy_costs.size() else 1.0


func _get_first_section(type_index: int) -> int:
	return enemy_first_section[type_index] if type_index < enemy_first_section.size() else 0


# --- Navigation ---------------------------------------------------------------------------------

func _is_cell_walkable(cell: Vector2i) -> bool:
	return (_layout.get(&"cells") as Dictionary).has(cell)


func _get_downhill_cell(cell: Vector2i) -> Vector2i:
	var best: Vector2i = cell
	var best_distance: int = int(_navigation_field.get(cell, 0))
	for direction in LevelLayout.DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if not _navigation_field.has(neighbor):
			continue
		if not bool(_layout.call(&"are_connected", cell, neighbor)):
			continue
		var distance: int = int(_navigation_field[neighbor])
		if distance < best_distance:
			best_distance = distance
			best = neighbor
	return best


## True when a body navigation_clearance wide can walk the straight line from a to b without
## leaving the walkable, connected tiles. Checks the centre line and both edges of that width.
func _is_walk_clear(a: Vector3, b: Vector3) -> bool:
	var flat: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length: float = flat.length()
	if length <= 0.001:
		return true
	var side: Vector3 = Vector3(-flat.z, 0.0, flat.x) / length
	var start_cell: Vector2i = world_to_cell(a)
	for lateral in [0.0, navigation_clearance, -navigation_clearance]:
		var offset: Vector3 = side * float(lateral)
		var previous: Vector2i = start_cell
		var first: Vector2i = world_to_cell(a + offset)
		if first != start_cell and not _can_step(start_cell, first):
			if float(lateral) == 0.0:
				return false
			continue
		previous = first
		var steps: int = maxi(ceili(length / 0.75), 1)
		for step in range(1, steps + 1):
			var cell: Vector2i = world_to_cell(a + offset + flat * (float(step) / float(steps)))
			if cell == previous:
				continue
			if not _can_step(previous, cell):
				return false
			previous = cell
	return true


func _can_step(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var delta: Vector2i = to_cell - from_cell
	if absi(delta.x) + absi(delta.y) == 1:
		return bool(_layout.call(&"are_connected", from_cell, to_cell))
	if absi(delta.x) == 1 and absi(delta.y) == 1:
		var via_x: Vector2i = from_cell + Vector2i(delta.x, 0)
		var via_y: Vector2i = from_cell + Vector2i(0, delta.y)
		var through_x: bool = bool(_layout.call(&"are_connected", from_cell, via_x)) and bool(_layout.call(&"are_connected", via_x, to_cell))
		var through_y: bool = bool(_layout.call(&"are_connected", from_cell, via_y)) and bool(_layout.call(&"are_connected", via_y, to_cell))
		return through_x and through_y
	return false
