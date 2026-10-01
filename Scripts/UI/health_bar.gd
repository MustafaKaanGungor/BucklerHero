extends Control

@export_group("Nodes")
## ProgressBar node that displays current player health.
@export var progress_bar_path: NodePath = NodePath("HealthProgressBar")

@export_group("Colors")
## Fill color while health is high.
@export var healthy_color: Color = Color(0.86, 0.2, 0.2, 1.0)
## Fill color while health is low.
@export var low_color: Color = Color(0.95, 0.5, 0.15, 1.0)
## Ratio where the health bar starts blending toward the low health color.
@export var low_health_ratio: float = 0.3

var _progress_bar: ProgressBar
var _fill_style: StyleBoxFlat


func _ready() -> void:
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	_cache_fill_style()
	_connect_health_manager()
	_refresh_bar()


func _cache_fill_style() -> void:
	if _progress_bar == null:
		return

	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill_style == null:
		return

	_fill_style = fill_style.duplicate() as StyleBoxFlat
	_progress_bar.add_theme_stylebox_override(&"fill", _fill_style)


func _connect_health_manager() -> void:
	var health_changed_callback: Callable = Callable(self, "_on_health_changed")
	if not HealthManager.health_changed.is_connected(health_changed_callback):
		HealthManager.health_changed.connect(health_changed_callback)


func _on_health_changed(current_health: float, max_health: float, health_ratio: float) -> void:
	_set_bar_values(current_health, max_health, health_ratio)


func _refresh_bar() -> void:
	_set_bar_values(
		HealthManager.get_health(),
		HealthManager.get_max_health(),
		HealthManager.get_health_ratio()
	)


func _set_bar_values(current_health: float, max_health: float, health_ratio: float) -> void:
	if _progress_bar == null:
		return

	var safe_max_health: float = maxf(max_health, 0.001)
	_progress_bar.max_value = safe_max_health
	_progress_bar.value = clampf(current_health, 0.0, safe_max_health)
	if _fill_style == null:
		return

	var low_threshold: float = clampf(low_health_ratio, 0.001, 1.0)
	var low_blend: float = clampf(health_ratio / low_threshold, 0.0, 1.0)
	_fill_style.bg_color = low_color.lerp(healthy_color, low_blend)
