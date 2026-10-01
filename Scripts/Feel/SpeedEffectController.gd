extends CanvasLayer

const METHOD_GET_HORIZONTAL_SPEED: StringName = &"get_horizontal_speed"

@export_group("Player")
## Optional player path; if empty or missing, the effect searches the scene for the player.
@export var player_path: NodePath = NodePath("../Player")
## Allows automatic player lookup when the exported player path is not ready yet.
@export var auto_find_player: bool = true

@export_group("Speed Response")
## Player speed where the effect begins to appear.
@export var speed_effect_start: float = 7.2
## Player speed where the effect reaches full strength.
@export var speed_effect_full: float = 35.0
## Curve for how quickly speed turns into visual strength.
@export var speed_effect_curve: float = 1.25
## How quickly the shader catches up to speed changes.
@export var speed_effect_lerp_speed: float = 8.5
## Overall multiplier for the final shader strength.
@export var speed_effect_strength: float = 2.0

@export_group("Nodes")
## Full-screen ColorRect that owns the speed effect ShaderMaterial.
@export var effect_rect_path: NodePath = NodePath("SpeedEffectRect")

var _player: CharacterBody3D
var _effect_material: ShaderMaterial
var _current_strength: float = 0.0


func _ready() -> void:
	_cache_material()
	_resolve_player()
	_set_shader_strength(0.0)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()

	var target_strength: float = 0.0
	if _player != null and is_instance_valid(_player):
		target_strength = _get_speed_strength(_get_player_speed())

	var blend: float = 1.0 - exp(-maxf(speed_effect_lerp_speed, 0.001) * delta)
	_current_strength = lerpf(_current_strength, target_strength, blend)
	_set_shader_strength(_current_strength)


func _cache_material() -> void:
	var effect_rect: ColorRect = get_node_or_null(effect_rect_path) as ColorRect
	if effect_rect == null:
		return

	_effect_material = effect_rect.material as ShaderMaterial


func _resolve_player() -> void:
	_player = get_node_or_null(player_path) as CharacterBody3D
	if _player != null or not auto_find_player:
		return

	var search_root: Node = get_tree().current_scene
	if search_root == null:
		search_root = get_tree().root
	_player = _find_player(search_root)


func _find_player(search_node: Node) -> CharacterBody3D:
	var player_body: CharacterBody3D = search_node as CharacterBody3D
	if player_body != null and player_body.has_method(METHOD_GET_HORIZONTAL_SPEED):
		return player_body

	for child in search_node.get_children():
		var child_node: Node = child as Node
		var found_player: CharacterBody3D = _find_player(child_node)
		if found_player != null:
			return found_player

	return null


func _get_player_speed() -> float:
	if _player.has_method(METHOD_GET_HORIZONTAL_SPEED):
		return maxf(float(_player.call(METHOD_GET_HORIZONTAL_SPEED)), 0.0)

	var horizontal_velocity: Vector3 = Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	return horizontal_velocity.length()


func _get_speed_strength(player_speed: float) -> float:
	var start_speed: float = maxf(speed_effect_start, 0.0)
	var full_speed: float = maxf(speed_effect_full, start_speed + 0.001)
	var speed_ratio: float = clampf((player_speed - start_speed) / maxf(full_speed - start_speed, 0.001), 0.0, 1.0)
	var shaped_ratio: float = pow(speed_ratio, maxf(speed_effect_curve, 0.001))
	return clampf(shaped_ratio * maxf(speed_effect_strength, 0.0), 0.0, 1.0)


func _set_shader_strength(strength: float) -> void:
	if _effect_material == null:
		return

	_effect_material.set_shader_parameter(&"speed_strength", clampf(strength, 0.0, 1.0))
