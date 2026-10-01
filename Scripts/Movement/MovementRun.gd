extends Node

@export_group("Sprint Speed")
## Maximum sprint speed after the sprint ramp finishes.
@export var sprint_speed: float = 12.8
## Enables gradual sprint speed buildup instead of instant max sprint.
@export var enable_sprint_speed_ramp: bool = true
## Speed used when sprint first starts.
@export var sprint_start_speed: float = 10.0
## Speed added per second while sprint is held.
@export var sprint_speed_gain_per_second: float = 8.8

@export_group("Slide Jump Combo Speed")
## Enables temporary speed gained from chaining slide and jump actions.
@export var enable_slide_jump_combo_speed: bool = true
## Time the combo speed bonus stays strong after each combo action.
@export var combo_speed_hold_time: float = 5.0
## Speed bonus gained when jumping out of a slide.
@export var combo_bonus_per_slide_jump: float = 0.75
## Speed bonus gained when starting a slide from recent jump momentum.
@export var combo_bonus_per_jump_slide: float = 0.55
## Maximum total speed bonus from slide and jump combos.
@export var combo_max_speed_bonus: float = 4.5
## Speed bonus removed per second after the hold time expires.
@export var combo_speed_decay_per_second: float = 3.0
## Portion of combo speed added immediately to sprint start speed.
@export var combo_sprint_start_speed_multiplier: float = 0.65

var _active_combo_speed_bonus: float = 0.0

@export_group("Sprint Jump")
## Allows sprinting to add jump height and forward power.
@export var enable_sprint_jump_boost: bool = true
## Jump height multiplier at full sprint jump power.
@export var sprint_jump_height_multiplier: float = 1.14
## Forward speed added when jumping out of sprint.
@export var sprint_jump_forward_boost: float = 4.0
## Maximum horizontal speed after sprint jump boost.
@export var sprint_jump_max_horizontal_speed: float = 14.5
## Uses sprint ramp and current speed to scale sprint jump power.
@export var sprint_jump_uses_sprint_power: bool = true
## Minimum sprint jump power when sprinting has just started.
@export var sprint_jump_min_power: float = 0.35


func set_combo_speed_bonus(combo_speed_bonus: float) -> void:
	_active_combo_speed_bonus = _get_combo_speed_bonus(combo_speed_bonus)


func get_sprint_speed_limit() -> float:
	return maxf(sprint_speed, 0.0) + _active_combo_speed_bonus


func get_sprint_start_speed() -> float:
	var combo_start_bonus: float = _active_combo_speed_bonus * clampf(combo_sprint_start_speed_multiplier, 0.0, 1.0)
	return clampf(sprint_start_speed + combo_start_bonus, 0.0, get_sprint_speed_limit())


func get_sprint_ramp_speed(sprint_pressed_time: float) -> float:
	var speed_limit: float = get_sprint_speed_limit()
	if not enable_sprint_speed_ramp:
		return speed_limit

	var start_speed: float = get_sprint_start_speed()
	var sprint_gain: float = maxf(sprint_speed_gain_per_second, 0.0)
	return minf(start_speed + (sprint_pressed_time * sprint_gain), speed_limit)


func get_sprint_ramp_blend(sprint_pressed_time: float) -> float:
	if not enable_sprint_speed_ramp:
		return 1.0

	var start_speed: float = get_sprint_start_speed()
	var speed_limit: float = get_sprint_speed_limit()
	var speed_range: float = maxf(speed_limit - start_speed, 0.001)
	return clampf((get_sprint_ramp_speed(sprint_pressed_time) - start_speed) / speed_range, 0.0, 1.0)


func get_sprint_ramp_duration() -> float:
	if not enable_sprint_speed_ramp:
		return 0.0

	var start_speed: float = get_sprint_start_speed()
	var speed_range: float = maxf(get_sprint_speed_limit() - start_speed, 0.0)
	var sprint_gain: float = maxf(sprint_speed_gain_per_second, 0.001)
	return speed_range / sprint_gain


func get_sprint_jump_power(
	is_sprinting: bool,
	sprint_ramp_blend: float,
	horizontal_speed: float
) -> float:
	if not is_sprinting:
		return 0.0
	if not sprint_jump_uses_sprint_power:
		return 1.0

	var speed_power: float = 0.0
	var speed_limit: float = get_sprint_speed_limit()
	if speed_limit > 0.0:
		speed_power = clampf(horizontal_speed / speed_limit, 0.0, 1.0)

	var sprint_power: float = maxf(clampf(sprint_ramp_blend, 0.0, 1.0), speed_power)
	sprint_power = maxf(sprint_power, sprint_jump_min_power)
	return clampf(sprint_power, 0.0, 1.0)


func get_combo_speed_bonus_after_gain(current_bonus: float, gained_bonus: float) -> float:
	if not enable_slide_jump_combo_speed:
		return 0.0

	var max_bonus: float = maxf(combo_max_speed_bonus, 0.0)
	return clampf(current_bonus + maxf(gained_bonus, 0.0), 0.0, max_bonus)


func get_combo_speed_bonus_after_decay(current_bonus: float, combo_timer: float, delta: float) -> float:
	if not enable_slide_jump_combo_speed:
		return 0.0
	if combo_timer > 0.0:
		return _get_combo_speed_bonus(current_bonus)

	var decay: float = maxf(combo_speed_decay_per_second, 0.0) * delta
	return maxf(_get_combo_speed_bonus(current_bonus) - decay, 0.0)


func get_combo_speed_hold_time() -> float:
	if not enable_slide_jump_combo_speed:
		return 0.0
	return maxf(combo_speed_hold_time, 0.0)


func get_combo_speed_blend() -> float:
	var max_bonus: float = maxf(combo_max_speed_bonus, 0.001)
	return clampf(_active_combo_speed_bonus / max_bonus, 0.0, 1.0)


func _get_combo_speed_bonus(combo_speed_bonus: float) -> float:
	if not enable_slide_jump_combo_speed:
		return 0.0
	return clampf(combo_speed_bonus, 0.0, maxf(combo_max_speed_bonus, 0.0))
