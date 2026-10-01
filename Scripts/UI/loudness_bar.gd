extends Control

@export_group("Nodes")
## ProgressBar node that displays current movement loudness.
@export var progress_bar_path: NodePath = NodePath("LoudnessProgressBar")

@export_group("Colors")
## Color at complete silence.
@export var silent_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Color through the quiet state.
@export var quiet_color: Color = Color(0.42, 0.82, 0.32, 1.0)
## Color through the noisy state.
@export var noisy_color: Color = Color(0.98, 0.76, 0.18, 1.0)
## Color through the loud state.
@export var loud_color: Color = Color(0.96, 0.16, 0.12, 1.0)

@export_group("Fallback Thresholds")
## Quiet state ends here if the manager is not available.
@export var quiet_max_ratio: float = 0.25
## Noisy state ends here if the manager is not available.
@export var noisy_max_ratio: float = 0.65

var _progress_bar: ProgressBar
var _fill_style: StyleBoxFlat


func _ready() -> void:
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	_cache_fill_style()
	_connect_loudness_manager()
	_refresh_bar()


func _process(_delta: float) -> void:
	_refresh_bar()


func _cache_fill_style() -> void:
	if _progress_bar == null:
		return

	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill_style == null:
		return

	_fill_style = fill_style.duplicate() as StyleBoxFlat
	_progress_bar.add_theme_stylebox_override(&"fill", _fill_style)


func _connect_loudness_manager() -> void:
	var loudness_changed_callback: Callable = Callable(self, "_on_loudness_changed")
	if not LoudnessManger.loudness_changed.is_connected(loudness_changed_callback):
		LoudnessManger.loudness_changed.connect(loudness_changed_callback)


func _on_loudness_changed(
	current_loudness: float,
	max_loudness: float,
	loudness_ratio: float,
	_loudness_state: StringName
) -> void:
	_set_bar_values(current_loudness, max_loudness, loudness_ratio)


func _refresh_bar() -> void:
	_set_bar_values(
		LoudnessManger.get_loudness(),
		LoudnessManger.get_max_loudness(),
		LoudnessManger.get_loudness_ratio()
	)


func _set_bar_values(current_loudness: float, max_loudness: float, loudness_ratio: float) -> void:
	if _progress_bar == null:
		return

	var safe_max_loudness: float = maxf(max_loudness, 0.001)
	var clean_ratio: float = clampf(loudness_ratio, 0.0, 1.0)
	_progress_bar.max_value = safe_max_loudness
	_progress_bar.value = clampf(current_loudness, 0.0, safe_max_loudness)
	_update_fill_color(clean_ratio)


func _update_fill_color(loudness_ratio: float) -> void:
	if _fill_style == null:
		return

	var quiet_limit: float = clampf(LoudnessManger.quiet_max_ratio, 0.001, 0.999)
	var noisy_limit: float = clampf(LoudnessManger.noisy_max_ratio, quiet_limit + 0.001, 1.0)
	if quiet_limit <= 0.001:
		quiet_limit = clampf(quiet_max_ratio, 0.001, 0.999)
	if noisy_limit <= quiet_limit:
		noisy_limit = clampf(noisy_max_ratio, quiet_limit + 0.001, 1.0)

	if loudness_ratio <= quiet_limit:
		var quiet_ratio: float = loudness_ratio / quiet_limit
		_fill_style.bg_color = silent_color.lerp(quiet_color, quiet_ratio)
		return

	if loudness_ratio <= noisy_limit:
		var noisy_ratio: float = (loudness_ratio - quiet_limit) / maxf(noisy_limit - quiet_limit, 0.001)
		_fill_style.bg_color = quiet_color.lerp(noisy_color, noisy_ratio)
		return

	var loud_ratio: float = (loudness_ratio - noisy_limit) / maxf(1.0 - noisy_limit, 0.001)
	_fill_style.bg_color = noisy_color.lerp(loud_color, loud_ratio)
