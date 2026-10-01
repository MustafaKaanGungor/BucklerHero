extends RefCounted

## Tile layout of a generated level. Pure data: no nodes, no physics.
## The level is a grid of square tiles (Vector2i, x = world x, y = world z). Every walkable tile
## belongs to exactly one section; sections are chained in the order given to generate(), each one
## starting right behind the previous one's exit. Apart from that one doorway, sections never touch:
## there is always at least one empty tile between them, so walls never get shared by accident.
## Tunables are plain vars; level_generator.gd copies its exports into them before generate().

enum Kind {
	CORRIDOR,
	ARENA,
	EXIT,
}

const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# Corridor shape.
var corridor_min_turns: int = 1
var corridor_max_turns: int = 3
var corridor_min_run: int = 2
var corridor_max_run: int = 4
var corridor_min_tiles: int = 8
## Extra run length added every this many sections, so later corridors are a little longer.
var corridor_run_growth_sections: int = 4
var corridor_wide_chance: float = 0.35
var corridor_nook_chance: float = 0.35

# Arena shape.
var arena_min_size: int = 8
var arena_max_size: int = 11
var arena_min_pillars: int = 2
var arena_max_pillars: int = 5

# Verticality (heights in metres). See _add_features().
var arena_platform_height: float = 2.2
var arena_max_platforms: int = 2
var arena_min_boxes: int = 2
var arena_max_boxes: int = 5
var corridor_raise_height: float = 1.2
var corridor_raise_chance: float = 0.75
var corridor_max_boxes: int = 2
var box_min_height: float = 0.9
var box_max_height: float = 1.3
var tall_box_height: float = 2.0
var box_pair_chance: float = 0.3
var stairs_chance: float = 0.5

# Retries.
var max_section_attempts: int = 20
var max_level_attempts: int = 30

## Walkable tile -> section index.
var cells: Dictionary = {}
## Solid tiles inside a section's footprint (arena pillars) -> section index.
var solid: Dictionary = {}
## Edge key (see get_edge_key) -> index of the section the door leads into.
var door_edges: Dictionary = {}
## One Dictionary per section, in order. Keys: kind, index, kind_number, cells (Array[Vector2i]),
## solid (Array[Vector2i]), entry_cell, entry_direction, exit_cell, exit_direction (ZERO if none).
var sections: Array[Dictionary] = []
## Raised and climbable things, one Dictionary each, with a "type":
## &"block": a solid raised floor filling whole tiles. Keys: cells (a rectangle, Array[Vector2i]), height.
## &"ramp" / &"stairs": one tile rising from the floor to height along direction (Vector2i, uphill).
## &"box": a free-standing crate smaller than its tile. Keys: cell, footprint (share of the tile),
##   offset (Vector2, -1..1 of the free room around it), height.
var features: Array[Dictionary] = []
## Tile -> feature type, for every tile a feature sits on.
var feature_cells: Dictionary = {}
## Tile -> height of the floor at the tile centre, for tiles that are raised (blocks, ramps).
var floor_heights: Dictionary = {}
var start_cell: Vector2i = Vector2i.ZERO
var start_direction: Vector2i = Vector2i(0, -1)

var _rng: RandomNumberGenerator


## Builds a layout for these section kinds (Kind values, in order). Returns false if every attempt failed.
func generate(rng: RandomNumberGenerator, kinds: Array[int]) -> bool:
	_rng = rng
	for attempt in range(maxi(max_level_attempts, 1)):
		_clear()
		if _try_generate(kinds):
			_add_features()
			return true
	_clear()
	return false


func is_walkable(cell: Vector2i) -> bool:
	return cells.has(cell)


func get_section_index(cell: Vector2i) -> int:
	return int(cells.get(cell, -1))


## True when a body can walk straight from tile a to the neighbouring tile b: both walkable and
## either in the same section or joined by a doorway.
func are_connected(a: Vector2i, b: Vector2i) -> bool:
	if not cells.has(a) or not cells.has(b):
		return false
	if int(cells[a]) == int(cells[b]):
		return true
	return door_edges.has(get_edge_key(a, b))


static func get_edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return Vector4i(a.x, a.y, b.x, b.y)
	return Vector4i(b.x, b.y, a.x, a.y)


## Breadth-first step counts from start over connected walkable tiles. Only tiles of only_section
## are visited when it is 0 or more.
func get_distance_field(start: Vector2i, only_section: int = -1) -> Dictionary:
	var distances: Dictionary = {}
	if not cells.has(start):
		return distances
	distances[start] = 0
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var next_distance: int = int(distances[cell]) + 1
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if distances.has(neighbor) or not are_connected(cell, neighbor):
				continue
			if only_section >= 0 and int(cells[neighbor]) != only_section:
				continue
			distances[neighbor] = next_distance
			queue.append(neighbor)
	return distances


func _clear() -> void:
	cells.clear()
	solid.clear()
	door_edges.clear()
	sections.clear()
	features.clear()
	feature_cells.clear()
	floor_heights.clear()


func _try_generate(kinds: Array[int]) -> bool:
	var forward: Vector2i = start_direction
	var entry: Vector2i = start_cell
	var direction: Vector2i = forward
	var previous_exit: Vector2i = Vector2i.ZERO
	var has_previous: bool = false
	var kind_counts: Dictionary = {}

	for index in range(kinds.size()):
		var kind: int = kinds[index]
		var kind_number: int = int(kind_counts.get(kind, 0)) + 1
		var section: Dictionary = {}
		for attempt in range(maxi(max_section_attempts, 1)):
			var candidate: Dictionary = _build_section(kind, index, kind_number, entry, direction, forward)
			if candidate.is_empty():
				continue
			if _fits(candidate, has_previous, previous_exit):
				section = candidate
				break
		if section.is_empty():
			return false

		kind_counts[kind] = kind_number
		_commit(section, has_previous, previous_exit)
		if kind == Kind.EXIT or index == kinds.size() - 1:
			break
		previous_exit = section["exit_cell"]
		direction = section["exit_direction"]
		entry = previous_exit + direction
		has_previous = true

	return _is_level_connected()


func _build_section(kind: int, index: int, kind_number: int, entry: Vector2i, direction: Vector2i, forward: Vector2i) -> Dictionary:
	var section: Dictionary = {}
	match kind:
		Kind.CORRIDOR:
			section = _build_corridor(index, entry, direction, forward)
		Kind.ARENA:
			section = _build_arena(kind_number, entry, direction, forward)
		_:
			section = _build_exit(entry, direction)
	if section.is_empty():
		return section
	section["kind"] = kind
	section["index"] = index
	section["kind_number"] = kind_number
	section["entry_cell"] = entry
	section["entry_direction"] = direction
	return section


## A winding corridor: straight runs joined by left/right turns. It never heads back against the
## level's forward direction, so it can't fold into itself. Some runs are two tiles wide and some
## have a small side nook. It starts and ends one tile wide so doors fit.
func _build_corridor(index: int, entry: Vector2i, direction: Vector2i, forward: Vector2i) -> Dictionary:
	var cell_list: Array[Vector2i] = [entry]
	var cell_set: Dictionary = {entry: true}
	var position: Vector2i = entry
	var heading: Vector2i = direction
	var growth: int = 0
	if corridor_run_growth_sections > 0:
		growth = index / corridor_run_growth_sections
	var turns: int = _rng.randi_range(corridor_min_turns, maxi(corridor_max_turns, corridor_min_turns))
	var runs: int = turns + 1
	# Straight runs (centre line only) for the feature pass: raised stretches go on narrow ones.
	var run_list: Array[Dictionary] = []

	for run in range(runs):
		var length: int = _rng.randi_range(corridor_min_run, maxi(corridor_max_run, corridor_min_run) + growth)
		var is_last_run: bool = run == runs - 1
		if is_last_run:
			length = maxi(length, 2)
		var is_wide: bool = not is_last_run and _rng.randf() < corridor_wide_chance
		var side: Vector2i = _turn_right(heading) if _rng.randf() < 0.5 else _turn_left(heading)
		var run_cells: Array[Vector2i] = []
		for step in range(length):
			position += heading
			_add_cell(cell_list, cell_set, position)
			run_cells.append(position)
			if is_wide and not (run == 0 and step < 1):
				_add_cell(cell_list, cell_set, position + side)
		run_list.append({"cells": run_cells, "heading": heading, "wide": is_wide})
		if not is_last_run:
			var options: Array[Vector2i] = []
			for option in [_turn_left(heading), _turn_right(heading)]:
				if option != -forward:
					options.append(option)
			heading = options[_rng.randi_range(0, options.size() - 1)]

	var exit_cell: Vector2i = position
	var exit_next: Vector2i = exit_cell + heading

	if _rng.randf() < corridor_nook_chance and cell_list.size() > 6:
		var anchor: Vector2i = cell_list[_rng.randi_range(2, cell_list.size() - 4)]
		var nook_direction: Vector2i = DIRECTIONS[_rng.randi_range(0, DIRECTIONS.size() - 1)]
		var nook: Array[Vector2i] = [anchor + nook_direction, anchor + nook_direction * 2]
		var nook_ok: bool = true
		for nook_cell in nook:
			if _manhattan(nook_cell, entry) < 3 or _manhattan(nook_cell, exit_cell) < 3:
				nook_ok = false
		if nook_ok:
			for nook_cell in nook:
				_add_cell(cell_list, cell_set, nook_cell)

	# The tile past the exit belongs to the next section; only the exit tile may touch it.
	for direction_check in DIRECTIONS:
		var neighbor: Vector2i = exit_next + direction_check
		if neighbor != exit_cell and cell_set.has(neighbor):
			return {}
	if cell_set.has(exit_next) or cell_list.size() < corridor_min_tiles:
		return {}

	return {
		"cells": cell_list,
		"solid": [] as Array[Vector2i],
		"exit_cell": exit_cell,
		"exit_direction": heading,
		"runs": run_list,
	}


## A roomy, roundish arena behind a one-tile entrance. Its outline is a circle, a rounded square
## or an octagon cut from an n x n square; a few pillars give cover. The exit is on the far side or
## on the left or right, never back toward the start of the level.
func _build_arena(kind_number: int, entry: Vector2i, direction: Vector2i, forward: Vector2i) -> Dictionary:
	var size: int = clampi(arena_min_size + _rng.randi_range(0, 1) + ((kind_number - 1) / 2) + (kind_number - 1) % 2, arena_min_size, maxi(arena_max_size, arena_min_size))
	var shape: int = _rng.randi_range(0, 2)
	var side: Vector2i = _turn_right(direction)
	var center_column: int = (size / 2) - _rng.randi_range(0, 1 - (size % 2))

	var cell_list: Array[Vector2i] = [entry]
	var cell_set: Dictionary = {entry: true}
	var body: Dictionary = {}
	for row in range(size):
		for column in range(size):
			var nx: float = ((float(column) + 0.5) / float(size)) * 2.0 - 1.0
			var ny: float = ((float(row) + 0.5) / float(size)) * 2.0 - 1.0
			var inside: bool = false
			match shape:
				0:
					inside = (nx * nx) + (ny * ny) <= 1.08
				1:
					inside = pow(absf(nx), 4.0) + pow(absf(ny), 4.0) <= 1.0
				_:
					inside = absf(nx) + absf(ny) <= 1.5
			if not inside:
				continue
			var cell: Vector2i = entry + direction * (row + 1) + side * (column - center_column)
			body[cell] = true
			_add_cell(cell_list, cell_set, cell)

	var first_body_cell: Vector2i = entry + direction
	if not body.has(first_body_cell):
		return {}

	# Exit: the tile furthest along the chosen direction, nearest the middle on ties.
	var exit_options: Array[Vector2i] = []
	for option in [direction, side, -side]:
		if option != -forward:
			exit_options.append(option)
	var exit_direction: Vector2i = exit_options[_rng.randi_range(0, exit_options.size() - 1)]
	var middle: Vector2i = entry + direction * ((size / 2) + 1)
	var exit_cell: Vector2i = first_body_cell
	var best_reach: int = -1000000
	var best_offset: int = 1000000
	for cell in body.keys():
		var reach: int = _dot(cell, exit_direction)
		var offset: int = absi(_dot(cell - middle, Vector2i(exit_direction.y, -exit_direction.x)))
		if reach > best_reach or (reach == best_reach and offset < best_offset):
			best_reach = reach
			best_offset = offset
			exit_cell = cell
	var exit_next: Vector2i = exit_cell + exit_direction
	for direction_check in DIRECTIONS:
		var neighbor: Vector2i = exit_next + direction_check
		if neighbor != exit_cell and cell_set.has(neighbor):
			return {}

	# Pillars: fully surrounded tiles away from the doors and from each other.
	var solid_cells: Array[Vector2i] = []
	var pillar_target: int = _rng.randi_range(arena_min_pillars, maxi(arena_max_pillars, arena_min_pillars))
	var candidates: Array = body.keys()
	for attempt in range(40):
		if solid_cells.size() >= pillar_target or candidates.is_empty():
			break
		var pillar: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
		if _manhattan(pillar, first_body_cell) < 3 or _manhattan(pillar, exit_cell) < 3:
			continue
		var is_clear: bool = true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var around: Vector2i = pillar + Vector2i(dx, dy)
				if not body.has(around) or solid_cells.has(around):
					is_clear = false
		if not is_clear:
			continue
		solid_cells.append(pillar)
		body.erase(pillar)
		cell_list.erase(pillar)
		cell_set.erase(pillar)

	return {
		"cells": cell_list,
		"solid": solid_cells,
		"exit_cell": exit_cell,
		"exit_direction": exit_direction,
	}


## Two tiles past the last door. Standing on the far one finishes the level.
func _build_exit(entry: Vector2i, direction: Vector2i) -> Dictionary:
	return {
		"cells": [entry, entry + direction] as Array[Vector2i],
		"solid": [] as Array[Vector2i],
		"exit_cell": entry + direction,
		"exit_direction": Vector2i.ZERO,
	}


## The section may not overlap anything, and may only touch earlier sections through its entry tile
## sitting against the previous exit tile.
func _fits(section: Dictionary, has_previous: bool, previous_exit: Vector2i) -> bool:
	var entry: Vector2i = section["entry_cell"]
	var footprint: Array[Vector2i] = []
	footprint.append_array(section["cells"])
	footprint.append_array(section["solid"])
	for cell in footprint:
		if cells.has(cell) or solid.has(cell):
			return false
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if not cells.has(neighbor) and not solid.has(neighbor):
				continue
			if has_previous and cell == entry and neighbor == previous_exit:
				continue
			return false
		# Diagonal contact would leave two walls meeting at a single corner; keep a clean gap.
		for dx in [-1, 1]:
			for dy in [-1, 1]:
				var diagonal: Vector2i = cell + Vector2i(dx, dy)
				if (cells.has(diagonal) or solid.has(diagonal)) and not (has_previous and _manhattan(diagonal, previous_exit) <= 1 and _manhattan(cell, entry) <= 1):
					return false
	return true


func _commit(section: Dictionary, has_previous: bool, previous_exit: Vector2i) -> void:
	var index: int = int(section["index"])
	for cell in section["cells"]:
		cells[cell] = index
	for cell in section["solid"]:
		solid[cell] = index
	if has_previous:
		door_edges[get_edge_key(previous_exit, section["entry_cell"])] = index
	sections.append(section)


func _is_level_connected() -> bool:
	if sections.is_empty():
		return false
	var distances: Dictionary = get_distance_field(start_cell)
	for cell in cells.keys():
		if not distances.has(cell):
			return false
	return true


func _add_cell(cell_list: Array[Vector2i], cell_set: Dictionary, cell: Vector2i) -> void:
	if cell_set.has(cell):
		return
	cell_set[cell] = true
	cell_list.append(cell)


static func _turn_right(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)


static func _turn_left(direction: Vector2i) -> Vector2i:
	return Vector2i(direction.y, -direction.x)


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _dot(a: Vector2i, b: Vector2i) -> int:
	return (a.x * b.x) + (a.y * b.y)


# --- Verticality ------------------------------------------------------------------------------

## Adds raised platforms, ramps, stairs and boxes. Runs after the layout is final, so it never
## changes which tiles are walkable: every feature can be walked around, climbed or jumped onto.
## Nothing goes within two tiles of a doorway, so doors, spawn and respawn tiles stay flat.
func _add_features() -> void:
	for section in sections:
		match int(section["kind"]):
			Kind.CORRIDOR:
				_add_corridor_features(section)
			Kind.ARENA:
				_add_arena_features(section)


## Corridors: sometimes a raised stretch along the corridor's centre line (up a ramp or stairs,
## along, possibly around a corner, and back down), plus a couple of boxes pushed against the walls.
func _add_corridor_features(section: Dictionary) -> void:
	if _rng.randf() < corridor_raise_chance:
		_add_corridor_raise(section)

	var box_count: int = _rng.randi_range(0, maxi(corridor_max_boxes, 0))
	var section_cells: Array[Vector2i] = []
	section_cells.assign(section["cells"])
	for box in range(box_count):
		for attempt in range(20):
			var cell: Vector2i = section_cells[_rng.randi_range(0, section_cells.size() - 1)]
			if feature_cells.has(cell) or _is_near_door(cell, section, 2):
				continue
			# Push the box against a wall so the corridor stays passable.
			var wall_side: Vector2i = Vector2i.ZERO
			for direction in DIRECTIONS:
				if int(cells.get(cell + direction, -1)) != int(section["index"]):
					wall_side = direction
					break
			if wall_side == Vector2i.ZERO:
				continue
			_add_box(cell, _rng.randf_range(0.35, 0.5), Vector2(wall_side), _rng.randf_range(box_min_height, box_max_height))
			break


## Arenas: one or two raised platforms (2x2 to 3x2 tiles) reached by a ramp or stairs, and a handful
## of boxes, sometimes a low one next to a tall one so they work as steps.
func _add_arena_features(section: Dictionary) -> void:
	var index: int = int(section["index"])
	var body: Array[Vector2i] = []
	for cell in section["cells"]:
		if cell != section["entry_cell"]:
			body.append(cell)
	var platform_count: int = 1
	if body.size() >= 70 and _rng.randf() < 0.6:
		platform_count = 2
	platform_count = mini(platform_count, arena_max_platforms)

	for platform in range(platform_count):
		for attempt in range(40):
			var anchor: Vector2i = body[_rng.randi_range(0, body.size() - 1)]
			var size: Vector2i = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)][_rng.randi_range(0, 2)]
			var block: Array[Vector2i] = []
			var block_ok: bool = true
			for dx in range(size.x):
				for dy in range(size.y):
					var cell: Vector2i = anchor + Vector2i(dx, dy)
					if int(cells.get(cell, -1)) != index or _is_near_door(cell, section, 3) or _has_feature_near(cell):
						block_ok = false
					block.append(cell)
			if not block_ok:
				continue
			# A slope on one side, with a free tile at its foot.
			var direction: Vector2i = DIRECTIONS[_rng.randi_range(0, DIRECTIONS.size() - 1)]
			var edge: Array[Vector2i] = []
			for cell in block:
				if not block.has(cell + direction):
					edge.append(cell)
			var slope_cell: Vector2i = edge[_rng.randi_range(0, edge.size() - 1)] + direction
			var foot: Vector2i = slope_cell + direction
			if int(cells.get(slope_cell, -1)) != index or int(cells.get(foot, -1)) != index:
				continue
			if feature_cells.has(slope_cell) or feature_cells.has(foot) or _is_near_door(slope_cell, section, 2):
				continue
			if not _is_ground_connected(body, block):
				continue
			_add_block(block, arena_platform_height)
			_add_slope(slope_cell, -direction, arena_platform_height)
			# Keep the foot of the slope clear of boxes.
			feature_cells[foot] = &"reserved"
			break

	var box_count: int = _rng.randi_range(arena_min_boxes, maxi(arena_max_boxes, arena_min_boxes))
	for box in range(box_count):
		for attempt in range(25):
			var cell: Vector2i = body[_rng.randi_range(0, body.size() - 1)]
			if feature_cells.has(cell) or _is_near_door(cell, section, 2):
				continue
			var pair_direction: Vector2i = DIRECTIONS[_rng.randi_range(0, DIRECTIONS.size() - 1)]
			var pair_cell: Vector2i = cell + pair_direction
			if _rng.randf() < box_pair_chance and int(cells.get(pair_cell, -1)) == index and not feature_cells.has(pair_cell) and not _is_near_door(pair_cell, section, 2):
				# A low box pushed against a tall one: a two-step climb.
				_add_box(cell, 0.55, Vector2(pair_direction), box_min_height)
				_add_box(pair_cell, 0.6, -Vector2(pair_direction), tall_box_height)
			else:
				var offset: Vector2 = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
				_add_box(cell, _rng.randf_range(0.4, 0.65), offset, _rng.randf_range(box_min_height, box_max_height))
			break

	# The reserved slope feet were only there to keep boxes away.
	for cell in feature_cells.keys():
		if feature_cells[cell] == &"reserved":
			feature_cells.erase(cell)


func _add_block(block_cells: Array[Vector2i], height: float) -> void:
	features.append({"type": &"block", "cells": block_cells, "height": height})
	for cell in block_cells:
		feature_cells[cell] = &"block"
		floor_heights[cell] = height


## A ramp or stairs (picked at random) on one tile, rising toward uphill.
func _add_slope(cell: Vector2i, uphill: Vector2i, height: float) -> void:
	var type: StringName = &"stairs" if _rng.randf() < stairs_chance else &"ramp"
	features.append({"type": type, "cell": cell, "direction": uphill, "height": height})
	feature_cells[cell] = type
	floor_heights[cell] = height * 0.5


func _add_box(cell: Vector2i, footprint: float, offset: Vector2, height: float) -> void:
	features.append({"type": &"box", "cell": cell, "footprint": footprint, "offset": offset.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0)), "height": height})
	feature_cells[cell] = &"box"


func _is_near_door(cell: Vector2i, section: Dictionary, distance: int) -> bool:
	if _manhattan(cell, section["entry_cell"]) <= distance:
		return true
	return section["exit_direction"] != Vector2i.ZERO and _manhattan(cell, section["exit_cell"]) <= distance


## True if this tile or any of its eight neighbours already holds a feature.
func _has_feature_near(cell: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if feature_cells.has(cell + Vector2i(dx, dy)):
				return true
	return false


## True if, with blocked tiles taken out, every other body tile can still be reached on the ground.
func _is_ground_connected(body: Array[Vector2i], blocked: Array[Vector2i]) -> bool:
	var open: Dictionary = {}
	for cell in body:
		if not blocked.has(cell) and feature_cells.get(cell, &"") != &"block":
			open[cell] = true
	if open.is_empty():
		return false
	var start: Vector2i = open.keys()[0]
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if open.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				queue.append(neighbor)
	return seen.size() == open.size()


## Picks a stretch of 3-6 tiles on the corridor's centre line, off the door tiles and wide parts.
## Its first and last tiles become slopes and must sit on a straight bit (the tiles before and after
## continue in the same direction), so you always walk onto a slope from its low end. The tiles in
## between are raised, corners included.
func _add_corridor_raise(section: Dictionary) -> void:
	var path: Array[Vector2i] = [section["entry_cell"]]
	var wide_cells: Dictionary = {}
	for run in section.get("runs", []):
		path.append_array(run["cells"])
		if bool(run["wide"]):
			for cell in run["cells"]:
				wide_cells[cell] = true
	if path.size() < 6:
		return

	for attempt in range(60):
		var length: int = _rng.randi_range(3, 6)
		if path.size() - length - 1 < 1:
			continue
		var first: int = _rng.randi_range(1, path.size() - length - 1)
		var last: int = first + length - 1
		var stretch: Array[Vector2i] = path.slice(first, last + 1)
		var stretch_ok: bool = true
		for cell in stretch:
			# One tile from the doors is enough here: the door and respawn tiles stay flat.
			if _is_near_door(cell, section, 1) or feature_cells.has(cell) or wide_cells.has(cell):
				stretch_ok = false
		if not stretch_ok:
			continue
		var uphill: Vector2i = path[first + 1] - path[first]
		if path[first] - path[first - 1] != uphill:
			continue
		var travel_out: Vector2i = path[last] - path[last - 1]
		if path[last + 1] - path[last] != travel_out:
			continue

		for piece in _split_straight(stretch.slice(1, stretch.size() - 1)):
			_add_block(piece, corridor_raise_height)
		_add_slope(path[first], uphill, corridor_raise_height)
		_add_slope(path[last], -travel_out, corridor_raise_height)
		return


## Splits a chain of neighbouring tiles into straight pieces (each a one-tile-wide rectangle).
func _split_straight(chain: Array[Vector2i]) -> Array:
	var pieces: Array = []
	var current: Array[Vector2i] = []
	for cell in chain:
		if current.size() >= 2:
			var along_x: bool = current[0].y == current[1].y
			var fits: bool = (along_x and cell.y == current[0].y) or (not along_x and cell.x == current[0].x)
			if not fits:
				# The corner tile stays in the piece it ended; the next piece starts after it.
				pieces.append(current)
				current = []
		current.append(cell)
	if not current.is_empty():
		pieces.append(current)
	return pieces
