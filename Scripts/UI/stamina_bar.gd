extends Control

@export_group("Nodes")
## ProgressBar node that displays current stamina.
@export var progress_bar_path: NodePath = NodePath("StaminaProgressBar")

@export_group("Colors")
## Fill color while stamina is healthy.
@export var healthy_color: Color = Color(0.42, 0.78, 0.24, 1.0)
## Fill color while stamina is low.
@export var low_color: Color = Color(0.95, 0.72, 0.18, 1.0)
## Fill color when stamina is empty.
@export var empty_color: Color = Color(0.95, 0.18, 0.13, 1.0)
## Ratio where the stamina bar starts using low stamina colors.
@export var low_stamina_ratio: float = 0.28

var _progress_bar: ProgressBar


func _ready() -> void:
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	_connect_stamina_manager()
	_refresh_bar()


func _process(_delta: float) -> void:
	_refresh_bar()


func _connect_stamina_manager() -> void:
	var stamina_changed_callback: Callable = Callable(self, "_on_stamina_changed")
	if not StaminaManager.stamina_changed.is_connected(stamina_changed_callback):
		StaminaManager.stamina_changed.connect(stamina_changed_callback)


func _on_stamina_changed(current_stamina: float, max_stamina: float, stamina_ratio: float) -> void:
	_set_bar_values(current_stamina, max_stamina, stamina_ratio)


func _refresh_bar() -> void:
	_set_bar_values(
		StaminaManager.get_stamina(),
		StaminaManager.get_max_stamina(),
		StaminaManager.get_stamina_ratio()
	)


func _set_bar_values(current_stamina: float, max_stamina: float, stamina_ratio: float) -> void:
	if _progress_bar == null:
		return

	var safe_max_stamina: float = maxf(max_stamina, 0.001)
	var clean_ratio: float = clampf(stamina_ratio, 0.0, 1.0)
	_progress_bar.max_value = safe_max_stamina
	_progress_bar.value = clampf(current_stamina, 0.0, safe_max_stamina)
	_update_fill_color(clean_ratio)


func _update_fill_color(stamina_ratio: float) -> void:
	if _progress_bar == null:
		return

	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill_style == null:
		return

	var low_threshold: float = clampf(low_stamina_ratio, 0.001, 1.0)
	if stamina_ratio <= 0.001:
		fill_style.bg_color = empty_color
		return

	if stamina_ratio < low_threshold:
		var low_ratio: float = stamina_ratio / low_threshold
		fill_style.bg_color = empty_color.lerp(low_color, low_ratio)
		return

	var healthy_ratio: float = (stamina_ratio - low_threshold) / maxf(1.0 - low_threshold, 0.001)
	fill_style.bg_color = low_color.lerp(healthy_color, healthy_ratio)
