extends Control

## Small "mini combo meter" next to the combo meter: one line per kind of action you just did
## ("BASH", "3x RICOCHET", "2x CRUSH", ...). Doing the same action again while its line is still
## showing brings the line back to full, moves it to the top, raises its count and pops it. A line
## holds for hold_time after its last bump, then fades out over fade_time and is removed; the next
## time that action starts again from 1.
## Listens to MeleeWeapons (group player_melee, found lazily) and HealthManager.died (clears it).
## Builds its own labels; the scene only places this Control (right of HudRoot/ComboMeter).

const GROUP_PLAYER_MELEE: StringName = &"player_melee"
const GROUP_ENEMIES: StringName = &"enemies"
const WEAPON_SHIELD: StringName = &"shield"

@export_group("Actions")
## Shown name and colour per action id.
@export var action_names: Dictionary = {
	&"bash": "BASH",
	&"throw": "THROW",
	&"ricochet": "RICOCHET",
	&"carry": "CARRY",
	&"crush": "CRUSH",
	&"stun": "STUN",
}
@export var action_colors: Dictionary = {
	&"bash": Color(0.92, 0.92, 0.95),
	&"throw": Color(0.6, 0.85, 1.0),
	&"ricochet": Color(0.4, 0.7, 1.0),
	&"carry": Color(0.7, 0.95, 0.9),
	&"crush": Color(1.0, 0.45, 0.25),
	&"stun": Color(1.0, 0.85, 0.3),
}

@export_group("Look")
## Most lines shown at once; the oldest goes when a new action needs room.
@export var max_lines: int = 5
@export var font_size: int = 26
## Gap between lines in pixels.
@export var line_spacing: float = 4.0

@export_group("Timing")
## Seconds a line stays fully visible after its last bump.
@export var hold_time: float = 1.6
## Seconds it then takes to fade out.
@export var fade_time: float = 1.4
## Scale of the pop when a line is bumped, and how long it takes to settle.
@export var pop_scale: float = 1.35
@export var pop_time: float = 0.22

## One line: {"id", "count", "age", "label", "pop"}. Index 0 is the top (most recent).
var _lines: Array[Dictionary] = []
var _weapons: Node
var _player: Node
var _last_carry_count: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	HealthManager.died.connect(clear)


## Adds amount to an action's line (creating it if it isn't showing).
func log_action(action_id: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	var line: Dictionary = {}
	for existing in _lines:
		if existing["id"] == action_id:
			line = existing
			break
	if line.is_empty():
		line = {"id": action_id, "count": 0, "age": 0.0, "label": _make_label(action_id), "pop": 0.0}
		while _lines.size() >= maxi(max_lines, 1):
			var oldest: Dictionary = _lines.pop_back()
			(oldest["label"] as Label).queue_free()
	else:
		_lines.erase(line)
	line["count"] = int(line["count"]) + amount
	line["age"] = 0.0
	line["pop"] = 1.0
	_lines.push_front(line)
	_refresh_text(line)
	_layout()


## Current count of an action's line (0 if it isn't showing). For tests.
func get_count(action_id: StringName) -> int:
	for line in _lines:
		if line["id"] == action_id:
			return int(line["count"])
	return 0


## The lines' texts, top first. For tests.
func get_texts() -> Array[String]:
	var texts: Array[String] = []
	for line in _lines:
		texts.append((line["label"] as Label).text)
	return texts


func clear() -> void:
	for line in _lines:
		(line["label"] as Label).queue_free()
	_lines.clear()


func _process(delta: float) -> void:
	_connect_weapons()
	var removed: bool = false
	for line in _lines.duplicate():
		line["age"] = float(line["age"]) + delta
		line["pop"] = maxf(float(line["pop"]) - delta / maxf(pop_time, 0.01), 0.0)
		var label: Label = line["label"] as Label
		var age: float = float(line["age"])
		var alpha: float = 1.0
		if age > hold_time:
			alpha = 1.0 - clampf((age - hold_time) / maxf(fade_time, 0.01), 0.0, 1.0)
		if alpha <= 0.0:
			label.queue_free()
			_lines.erase(line)
			removed = true
			continue
		label.modulate.a = alpha
		var pop: float = float(line["pop"])
		label.scale = Vector2.ONE * lerpf(1.0, pop_scale, pop * pop)
	if removed:
		_layout()


func _layout() -> void:
	var y: float = 0.0
	for line in _lines:
		var label: Label = line["label"] as Label
		label.position = Vector2(0.0, y)
		label.size = Vector2(size.x, float(font_size) * 1.3)
		label.pivot_offset = Vector2(0.0, label.size.y * 0.5)
		y += label.size.y + line_spacing


func _refresh_text(line: Dictionary) -> void:
	var count: int = int(line["count"])
	var name_text: String = String(action_names.get(line["id"], String(line["id"]).to_upper()))
	(line["label"] as Label).text = name_text if count <= 1 else "%dx %s" % [count, name_text]


func _make_label(action_id: StringName) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", Color(action_colors.get(action_id, Color.WHITE)))
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override(&"outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _connect_weapons() -> void:
	if _weapons != null and is_instance_valid(_weapons):
		return
	_weapons = get_tree().get_first_node_in_group(GROUP_PLAYER_MELEE)
	if _weapons == null:
		return
	_weapons.connect(&"attack_hit", _on_attack_hit)
	_weapons.connect(&"shield_ricocheted", func(_from: Vector3, _target: Node3D) -> void: log_action(&"ricochet"))
	_weapons.connect(&"shield_carry_changed", _on_carry_changed)
	_weapons.connect(&"shield_carry_crushed", func(count: int) -> void: log_action(&"crush", count))
	_weapons.connect(&"shield_charge_stunned", func(_enemy: Node3D) -> void: log_action(&"stun"))
	_weapons.connect(&"shield_charge_started", func() -> void: _last_carry_count = 0)


func _on_attack_hit(weapon_id: StringName, hit_info: Dictionary) -> void:
	var target: Node = hit_info.get("collider") as Node
	if target == null or not target.is_in_group(GROUP_ENEMIES):
		return
	if StringName(hit_info.get("source", &"")) == &"throw":
		# Only the throw's first hit; the ones after it are logged as ricochets.
		if not _is_ricochet_hit():
			log_action(&"throw")
		return
	if weapon_id != WEAPON_SHIELD or _is_player_charging():
		return
	log_action(&"bash")


## Any hit after the throw's first one is a ricochet hit.
func _is_ricochet_hit() -> bool:
	if _weapons == null or not _weapons.has_method(&"get_thrown_shield"):
		return false
	var projectile: Node = _weapons.call(&"get_thrown_shield") as Node
	return projectile != null and int(projectile.call(&"get_hit_count")) > 1


func _on_carry_changed(count: int) -> void:
	if count > _last_carry_count:
		log_action(&"carry", count - _last_carry_count)
	_last_carry_count = count


func _is_player_charging() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")
	return _player != null and _player.has_method(&"is_shield_charging") and bool(_player.call(&"is_shield_charging"))
