extends Control

@export_group("Nodes")
## ProgressBar node that displays permanent level loudness.
@export var progress_bar_path: NodePath = NodePath("TotalLoudnessProgressBar")

@export_group("Colors")
## Fill color when the level has no built-up loudness.
@export var empty_color: Color = Color(0.953, 0.918, 0.807, 1.0)
## Fill color while total loudness is building.
@export var building_color: Color = Color(0.615, 0.732, 0.257, 1.0)
## Fill color when total loudness is close to full.
@export var warning_color: Color = Color(0.95, 0.72, 0.18, 1.0)
## Fill color when total loudness is full.
@export var full_color: Color = Color(0.96, 0.14, 0.1, 1.0)

@export_group("Thresholds")
## Ratio where the bar starts blending toward warning.
@export var warning_ratio: float = 0.65
## Ratio where the bar starts blending toward full danger.
@export var full_warning_ratio: float = 0.9

@export_group("Display Smoothing")
## How fast the HUD fill visually catches up to the manager value.
@export var visual_smooth_speed: float = 12.0
## Minimum visible fill speed while the bar is catching up.
@export var visual_min_units_per_second: float = 2.0
## Snaps tiny value differences so the bar does not shimmer.
@export var visual_snap_threshold: float = 0.005

var _progress_bar: ProgressBar
var _fill_style: StyleBoxFlat
var _displayed_total_loudness: float = 0.0
var _target_total_loudness: float = 0.0
var _target_max_total_loudness: float = 100.0


func _ready() -> void:
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	_cache_fill_style()
	_connect_total_loudness_manager()
	_refresh_bar()
	_displayed_total_loudness = _target_total_loudness
	_draw_bar()


func _process(delta: float) -> void:
	_refresh_bar()
	_update_displayed_total_loudness(delta)


func _cache_fill_style() -> void:
	if _progress_bar == null:
		return

	var fill_style: StyleBoxFlat = _progress_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill_style == null:
		return

	_fill_style = fill_style.duplicate() as StyleBoxFlat
	_progress_bar.add_theme_stylebox_override(&"fill", _fill_style)


func _connect_total_loudness_manager() -> void:
	var total_loudness_changed_callback: Callable = Callable(self, "_on_total_loudness_changed")
	if not TotalLoudnessManager.total_loudness_changed.is_connected(total_loudness_changed_callback):
		TotalLoudnessManager.total_loudness_changed.connect(total_loudness_changed_callback)


func _on_total_loudness_changed(
	current_total_loudness: float,
	max_total_loudness: float,
	total_loudness_ratio: float,
	_is_full: bool
) -> void:
	_set_bar_values(current_total_loudness, max_total_loudness, total_loudness_ratio)


func _refresh_bar() -> void:
	_set_bar_values(
		TotalLoudnessManager.get_total_loudness(),
		TotalLoudnessManager.get_max_total_loudness(),
		TotalLoudnessManager.get_total_loudness_ratio()
	)


func _set_bar_values(current_total_loudness: float, max_total_loudness: float, _total_loudness_ratio: float) -> void:
	_target_max_total_loudness = maxf(max_total_loudness, 0.001)
	_target_total_loudness = clampf(current_total_loudness, 0.0, _target_max_total_loudness)


func _update_displayed_total_loudness(delta: float) -> void:
	if _progress_bar == null:
		return
	if delta <= 0.0:
		_draw_bar()
		return

	var value_gap: float = _target_total_loudness - _displayed_total_loudness
	if absf(value_gap) <= maxf(visual_snap_threshold, 0.0):
		_displayed_total_loudness = _target_total_loudness
	else:
		var smooth_blend: float = 1.0 - exp(-maxf(visual_smooth_speed, 0.001) * delta)
		var smoothed_value: float = lerpf(_displayed_total_loudness, _target_total_loudness, smooth_blend)
		var minimum_step: float = maxf(visual_min_units_per_second, 0.0) * delta
		if absf(smoothed_value - _displayed_total_loudness) < minimum_step:
			smoothed_value = move_toward(_displayed_total_loudness, _target_total_loudness, minimum_step)

		_displayed_total_loudness = clampf(smoothed_value, 0.0, _target_max_total_loudness)

	_draw_bar()


func _draw_bar() -> void:
	if _progress_bar == null:
		return

	var display_ratio: float = clampf(_displayed_total_loudness / maxf(_target_max_total_loudness, 0.001), 0.0, 1.0)
	_progress_bar.max_value = _target_max_total_loudness
	_progress_bar.value = clampf(_displayed_total_loudness, 0.0, _target_max_total_loudness)
	_update_fill_color(display_ratio)


func _update_fill_color(total_loudness_ratio: float) -> void:
	if _fill_style == null:
		return

	var warning_limit: float = clampf(warning_ratio, 0.001, 0.999)
	var full_warning_limit: float = clampf(full_warning_ratio, warning_limit + 0.001, 1.0)
	if total_loudness_ratio <= warning_limit:
		var building_ratio: float = total_loudness_ratio / warning_limit
		_fill_style.bg_color = empty_color.lerp(building_color, building_ratio)
		return

	if total_loudness_ratio <= full_warning_limit:
		var warning_blend: float = (total_loudness_ratio - warning_limit) / maxf(full_warning_limit - warning_limit, 0.001)
		_fill_style.bg_color = building_color.lerp(warning_color, warning_blend)
		return

	var full_blend: float = (total_loudness_ratio - full_warning_limit) / maxf(1.0 - full_warning_limit, 0.001)
	_fill_style.bg_color = warning_color.lerp(full_color, full_blend)
