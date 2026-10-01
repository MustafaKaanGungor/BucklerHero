extends Node

signal total_loudness_changed(current_total_loudness: float, max_total_loudness: float, total_loudness_ratio: float, is_full: bool)

const SOURCE_WALK: StringName = &"walk"
const SOURCE_CROUCH: StringName = &"crouch"
const SOURCE_SPRINT: StringName = &"sprint"
const SOURCE_SLIDE: StringName = &"slide"
const SOURCE_WALL_RUN: StringName = &"wall_run"
const SOURCE_CLIMB: StringName = &"climb"
const SOURCE_JUMP: StringName = &"jump"
const SOURCE_LANDING: StringName = &"landing"
const SOURCE_SOUND: StringName = &"sound"

@export_group("Total Loudness Pool")
## Maximum permanent loudness the level can build before later full-bar logic starts.
@export var max_total_loudness: float = 100.0
## Total loudness at level start.
@export var starting_total_loudness: float = 0.0
## Stops all increases once the permanent meter reaches full.
@export var stop_increase_when_full: bool = true
## Smallest value change that emits a HUD update.
@export var emit_change_threshold: float = 0.001

@export_group("Smooth Fill")
## Queues gained loudness so the permanent meter rises smoothly instead of snapping.
@export var enable_smooth_fill: bool = true
## Base amount of queued loudness that can enter the total meter each second.
@export var smooth_fill_units_per_second: float = 16.0
## Extra fill speed based on queued loudness; bigger events still feel responsive.
@export var smooth_fill_queue_catchup: float = 2.2
## Smallest fill speed while there is queued loudness.
@export var smooth_fill_min_units_per_second: float = 1.5

@export_group("Continuous Increase")
## Full normal loudness adds this fraction of the total bar every second.
@export var continuous_fill_ratio_per_second: float = 0.035
## Higher values make quiet continuous movement add much less total loudness.
@export var continuous_loudness_curve: float = 1.2
## Normal loudness below this ratio does not add permanent loudness.
@export var continuous_min_source_ratio: float = 0.015

@export_group("Instant Increase")
## Full one-shot loudness adds this fraction of the total bar.
@export var instant_fill_ratio: float = 0.10
## Higher values make small one-shot sounds add much less total loudness.
@export var instant_loudness_curve: float = 1.1
## One-shot loudness below this ratio does not add permanent loudness.
@export var instant_min_source_ratio: float = 0.01

@export_group("Source Gates")
## Prevents normal walking from ever increasing permanent total loudness.
@export var ignore_walk_total_loudness: bool = true
## Prevents crouch movement from ever increasing permanent total loudness.
@export var ignore_crouch_total_loudness: bool = true
## Landing sound must pass this normal loudness value before it increases total loudness.
@export var landing_min_loudness_for_total: float = 25.0

@export_group("Source Multipliers")
## Total loudness multiplier for walking if ignore_walk_total_loudness is disabled.
@export var walk_total_multiplier: float = 0.0
## Total loudness multiplier for crouch movement if ignore_crouch_total_loudness is disabled.
@export var crouch_total_multiplier: float = 0.0
## Total loudness multiplier for sprinting.
@export var sprint_total_multiplier: float = 0.25
## Total loudness multiplier for sliding.
@export var slide_total_multiplier: float = 0.15
## Total loudness multiplier for wall running.
@export var wall_run_total_multiplier: float = 0.30
## Total loudness multiplier for climbing.
@export var climb_total_multiplier: float = 0.40
## Total loudness multiplier for jump takeoff sounds.
@export var jump_total_multiplier: float = 0.05
## Total loudness multiplier for landing sounds.
@export var landing_total_multiplier: float = 0.65
## Total loudness multiplier for generic sound events.
@export var sound_total_multiplier: float = 1.0

var _current_total_loudness: float = 0.0
var _queued_total_loudness: float = 0.0
var _last_emitted_total_loudness: float = -1.0
var _last_emitted_full: bool = false


func _ready() -> void:
	reset_total_loudness()


func _process(delta: float) -> void:
	_apply_queued_total_loudness(delta)


func reset_total_loudness(value: float = -1.0) -> void:
	if value < 0.0:
		value = starting_total_loudness

	_current_total_loudness = clampf(value, 0.0, get_max_total_loudness())
	_queued_total_loudness = 0.0
	_emit_total_loudness_changed(true)


func get_total_loudness() -> float:
	return _current_total_loudness


func get_queued_total_loudness() -> float:
	return _queued_total_loudness


func get_max_total_loudness() -> float:
	return maxf(max_total_loudness, 0.0)


func get_total_loudness_ratio() -> float:
	return clampf(_current_total_loudness / maxf(get_max_total_loudness(), 0.001), 0.0, 1.0)


func is_total_loudness_full() -> bool:
	return _current_total_loudness >= get_max_total_loudness() - 0.001


## Adds permanent loudness from active movement over time.
func add_continuous_loudness(
	source_loudness: float,
	source_max_loudness: float,
	source_name: StringName,
	delta: float
) -> float:
	if delta <= 0.0:
		return 0.0
	if not _can_source_increase_total(source_name, source_loudness):
		return 0.0

	var source_ratio: float = _get_source_ratio(source_loudness, source_max_loudness)
	if source_ratio < clampf(continuous_min_source_ratio, 0.0, 1.0):
		return 0.0

	var shaped_ratio: float = pow(source_ratio, maxf(continuous_loudness_curve, 0.001))
	var total_gain: float = get_max_total_loudness()
	total_gain *= maxf(continuous_fill_ratio_per_second, 0.0)
	total_gain *= shaped_ratio
	total_gain *= _get_source_multiplier(source_name)
	total_gain *= maxf(delta, 0.0)
	return add_total_loudness(total_gain)


## Adds permanent loudness from one-shot actions like landing, jump takeoff, or sound events.
func add_instant_loudness(source_loudness: float, source_max_loudness: float, source_name: StringName) -> float:
	if not _can_source_increase_total(source_name, source_loudness):
		return 0.0

	var source_ratio: float = _get_source_ratio(source_loudness, source_max_loudness)
	if source_ratio < clampf(instant_min_source_ratio, 0.0, 1.0):
		return 0.0

	var shaped_ratio: float = pow(source_ratio, maxf(instant_loudness_curve, 0.001))
	var total_gain: float = get_max_total_loudness()
	total_gain *= maxf(instant_fill_ratio, 0.0)
	total_gain *= shaped_ratio
	total_gain *= _get_source_multiplier(source_name)
	return add_total_loudness(total_gain)


## Adds to the permanent meter; smooth mode queues the gain and releases it over time.
func add_total_loudness(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	if stop_increase_when_full and is_total_loudness_full():
		return 0.0

	var available_capacity: float = get_max_total_loudness() - _current_total_loudness - _queued_total_loudness
	var queued_amount: float = clampf(amount, 0.0, maxf(available_capacity, 0.0))
	if queued_amount <= 0.0:
		return 0.0
	if enable_smooth_fill:
		_queued_total_loudness += queued_amount
		return queued_amount

	return _apply_total_loudness_immediately(queued_amount)


func _apply_queued_total_loudness(delta: float) -> void:
	if delta <= 0.0 or _queued_total_loudness <= 0.0:
		return
	if stop_increase_when_full and is_total_loudness_full():
		_queued_total_loudness = 0.0
		return

	var fill_speed: float = maxf(smooth_fill_units_per_second, 0.0)
	fill_speed += _queued_total_loudness * maxf(smooth_fill_queue_catchup, 0.0)
	fill_speed = maxf(fill_speed, maxf(smooth_fill_min_units_per_second, 0.0))
	var fill_amount: float = minf(_queued_total_loudness, fill_speed * delta)
	fill_amount = minf(fill_amount, get_max_total_loudness() - _current_total_loudness)
	if fill_amount <= 0.0:
		_queued_total_loudness = 0.0
		return

	var added_loudness: float = _apply_total_loudness_immediately(fill_amount)
	_queued_total_loudness = maxf(_queued_total_loudness - added_loudness, 0.0)


func _apply_total_loudness_immediately(amount: float) -> float:
	var previous_total_loudness: float = _current_total_loudness
	_current_total_loudness = clampf(
		_current_total_loudness + amount,
		0.0,
		get_max_total_loudness()
	)
	var added_loudness: float = _current_total_loudness - previous_total_loudness
	if added_loudness > 0.0:
		_emit_total_loudness_changed()
	return added_loudness


func _get_source_ratio(source_loudness: float, source_max_loudness: float) -> float:
	return clampf(maxf(source_loudness, 0.0) / maxf(source_max_loudness, 0.001), 0.0, 1.0)


func _can_source_increase_total(source_name: StringName, source_loudness: float) -> bool:
	if source_name == SOURCE_WALK and ignore_walk_total_loudness:
		return false
	if source_name == SOURCE_CROUCH and ignore_crouch_total_loudness:
		return false
	if source_name == SOURCE_LANDING:
		return source_loudness > maxf(landing_min_loudness_for_total, 0.0)
	return true


func _get_source_multiplier(source_name: StringName) -> float:
	if source_name == SOURCE_WALK:
		return maxf(walk_total_multiplier, 0.0)
	if source_name == SOURCE_CROUCH:
		return maxf(crouch_total_multiplier, 0.0)
	if source_name == SOURCE_SPRINT:
		return maxf(sprint_total_multiplier, 0.0)
	if source_name == SOURCE_SLIDE:
		return maxf(slide_total_multiplier, 0.0)
	if source_name == SOURCE_WALL_RUN:
		return maxf(wall_run_total_multiplier, 0.0)
	if source_name == SOURCE_CLIMB:
		return maxf(climb_total_multiplier, 0.0)
	if source_name == SOURCE_JUMP:
		return maxf(jump_total_multiplier, 0.0)
	if source_name == SOURCE_LANDING:
		return maxf(landing_total_multiplier, 0.0)
	return maxf(sound_total_multiplier, 0.0)


func _emit_total_loudness_changed(force_emit: bool = false) -> void:
	var is_full: bool = is_total_loudness_full()
	var should_emit: bool = force_emit
	should_emit = should_emit or absf(_current_total_loudness - _last_emitted_total_loudness) >= maxf(emit_change_threshold, 0.0)
	should_emit = should_emit or is_full != _last_emitted_full
	if not should_emit:
		return

	_last_emitted_total_loudness = _current_total_loudness
	_last_emitted_full = is_full
	total_loudness_changed.emit(
		_current_total_loudness,
		get_max_total_loudness(),
		get_total_loudness_ratio(),
		is_full
	)
