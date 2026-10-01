extends Node

signal loudness_changed(current_loudness: float, max_loudness: float, loudness_ratio: float, loudness_state: StringName)

const STATE_QUIET: StringName = &"quiet"
const STATE_NOISY: StringName = &"noisy"
const STATE_LOUD: StringName = &"loud"

const MOVEMENT_NONE: StringName = &"none"
const MOVEMENT_WALK: StringName = &"walk"
const MOVEMENT_CROUCH: StringName = &"crouch"
const MOVEMENT_SPRINT: StringName = &"sprint"
const MOVEMENT_SLIDE: StringName = &"slide"
const MOVEMENT_WALL_RUN: StringName = &"wall_run"
const MOVEMENT_CLIMB: StringName = &"climb"
## Source tag for permanent total loudness gained from jump takeoff sounds.
const TOTAL_SOURCE_JUMP: StringName = &"jump"
## Source tag for permanent total loudness gained from landing impact sounds.
const TOTAL_SOURCE_LANDING: StringName = &"landing"
## Source tag for permanent total loudness gained from generic sound events.
const TOTAL_SOURCE_SOUND: StringName = &"sound"

@export_group("Loudness Pool")
## Maximum loudness value used by stealth detection and the HUD bar.
@export var max_loudness: float = 100.0
## End of the quiet state as a 0-1 ratio.
@export var quiet_max_ratio: float = 0.25
## End of the noisy state as a 0-1 ratio.
@export var noisy_max_ratio: float = 0.65

@export_group("Movement Loudness")
## Highest continuous movement loudness while sprinting.
@export var sprint_loudness: float = 68.0
## Quiet takeoff loudness when a sprint jump boost starts; landing creates the loud sound.
@export var sprint_jump_loudness: float = 8.0
## Quiet takeoff loudness when a normal jump starts; landing creates the loud sound.
@export var jump_loudness: float = 6.0
## Quiet takeoff loudness when jumping out of a slide; landing creates the loud sound.
@export var slide_jump_loudness: float = 7.0
## Continuous loudness while climbing or pulling over an edge.
@export var climb_loudness: float = 46.0
## Continuous loudness while wall running.
@export var wall_run_loudness: float = 40.0
## Continuous loudness while sliding.
@export var slide_loudness: float = 32.0
## Continuous loudness while walking.
@export var walk_loudness: float = 18.0
## Very quiet takeoff loudness when a crouch jump starts.
@export var crouch_jump_loudness: float = 5.0
## Continuous loudness while crouch moving.
@export var crouch_loudness: float = 5.0

@export_group("Landing Loudness")
## Lowest landing loudness after the minimum drop height is reached.
@export var landing_min_loudness: float = 0.0
## Base one-shot loudness available from landing height.
@export var landing_base_loudness: float = 20.0
## Extra landing loudness available from fall speed and drop height.
@export var landing_drop_loudness_bonus: float = 45.0
## Drop height where landing loudness starts increasing.
@export var landing_min_drop_height: float = 0.001
## Drop height where landing loudness reaches full drop bonus.
@export var landing_max_drop_height: float = 10.0
## Fall speed where landing loudness starts increasing.
@export var landing_min_fall_speed: float = 0.1
## Fall speed where landing loudness reaches full fall bonus.
@export var landing_max_fall_speed: float = 10.0
## Extra loudness multiplier from the existing landing impact feel.
@export var landing_impact_loudness_multiplier: float = 30.0
## How much fall speed can strengthen the height-based landing result.
@export var landing_fall_speed_height_influence: float = 0.25
## How much impact feel can strengthen the height-based landing result.
@export var landing_impact_height_influence: float = 0.25
## Curves landing loudness so small drops stay softer.
@export var landing_loudness_curve: float = 0.78

@export_group("Response")
## How much the bar jumps immediately when a one-shot sound is detected.
@export var instant_rise_ratio: float = 0.72
## Smooth rise speed after a one-shot sound jump.
@export var rise_lerp_speed: float = 34.0
## Smooth fall speed after one-shot sound noise ends.
@export var fall_lerp_speed: float = 18.0
## How fast one-shot sound targets decay back to silence.
@export var target_decay_per_second: float = 130.0
## Step speed used when movement loudness climbs toward its movement value.
@export var movement_rise_per_second: float = 42.0
## Step speed used when movement loudness falls toward a quieter movement value.
@export var movement_fall_per_second: float = 72.0
## Smallest value change that emits a HUD update.
@export var emit_change_threshold: float = 0.04

@export_group("Combo Loudness")
## Enables louder stealth feedback when loud movements are chained quickly.
@export var enable_combo_loudness: bool = true
## Time allowed between movement changes and loud events before combo starts fading.
@export var combo_window: float = 1.15
## Neutral combo multiplier used when no combo is active.
@export var combo_base_multiplier: float = 1.0
## Highest loudness multiplier a movement chain can build.
@export var combo_max_multiplier: float = 1.85
## Combo added when the player starts a movement after quiet or air time.
@export var movement_start_combo_gain: float = 0.08
## Combo added when quickly changing from one movement type to another.
@export var movement_transition_combo_gain: float = 0.14
## Combo added by normal jumps.
@export var jump_combo_gain: float = 0.16
## Combo added by sprint jumps.
@export var sprint_jump_combo_gain: float = 0.28
## Combo added by slide jumps.
@export var slide_jump_combo_gain: float = 0.24
## Combo added by crouch jumps.
@export var crouch_jump_combo_gain: float = 0.06
## Combo added by any landing.
@export var landing_combo_gain: float = 0.16
## Extra combo added by high or fast landings.
@export var landing_drop_combo_gain: float = 0.34
## How fast the combo multiplier falls back after the combo window ends.
@export var combo_decay_per_second: float = 0.7
## How strongly combo affects continuous movement loudness.
@export var movement_combo_multiplier_influence: float = 0.8
## How strongly combo affects jump and landing loudness.
@export var event_combo_multiplier_influence: float = 1.0

@export_group("Lower Randomness")
## Enables lower-only random variation so repeated movement sounds are not identical.
@export var enable_lower_randomness: bool = true
## Lowest random movement multiplier; 1.0 is the configured movement maximum.
@export var movement_random_min_multiplier: float = 0.72
## Lowest random jump/sound multiplier; 1.0 is the configured event maximum.
@export var event_random_min_multiplier: float = 0.82
## Lowest random landing multiplier; 1.0 is the configured landing maximum.
@export var landing_random_min_multiplier: float = 0.78
## Fastest time before the movement random target changes.
@export var movement_random_min_interval: float = 0.10
## Slowest time before the movement random target changes.
@export var movement_random_max_interval: float = 0.24
## Smooth speed for movement random changes.
@export var movement_random_lerp_speed: float = 9.0

@export_group("Scaling")
## Horizontal speed that counts as full movement noise.
@export var movement_speed_reference: float = 12.0
## Horizontal speed below this is treated as stillness.
@export var minimum_moving_speed: float = 0.08
## How strongly player input affects walking and crouching loudness.
@export var movement_input_power: float = 0.6
## Small extra takeoff loudness from fast jump speed; landing carries most jump noise.
@export var jump_speed_loudness_bonus: float = 1.0
## Horizontal jump speed where the jump speed bonus reaches full strength.
@export var jump_speed_bonus_full_speed: float = 12.0

var _current_loudness: float = 0.0
var _target_loudness: float = 0.0
var _event_loudness: float = 0.0
var _movement_loudness: float = 0.0
var _movement_updated_this_frame: bool = false
var _combo_multiplier: float = 1.0
var _combo_timer: float = 0.0
var _last_movement_state: StringName = MOVEMENT_NONE
var _movement_random_multiplier: float = 1.0
var _movement_random_target: float = 1.0
var _movement_random_timer: float = 0.0
var _last_random_movement_state: StringName = MOVEMENT_NONE
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_emitted_loudness: float = -1.0
var _last_emitted_state: StringName = &""


func _ready() -> void:
	_random.randomize()
	reset_loudness()


func _physics_process(delta: float) -> void:
	_decay_loudness(delta)


func reset_loudness() -> void:
	_current_loudness = 0.0
	_target_loudness = 0.0
	_event_loudness = 0.0
	_movement_loudness = 0.0
	_movement_updated_this_frame = false
	_combo_multiplier = maxf(combo_base_multiplier, 1.0)
	_combo_timer = 0.0
	_last_movement_state = MOVEMENT_NONE
	_movement_random_multiplier = 1.0
	_movement_random_target = 1.0
	_movement_random_timer = 0.0
	_last_random_movement_state = MOVEMENT_NONE
	_emit_loudness_changed(true)


func get_loudness() -> float:
	return _current_loudness


func get_max_loudness() -> float:
	return maxf(max_loudness, 0.0)


func get_loudness_ratio() -> float:
	return clampf(_current_loudness / maxf(get_max_loudness(), 0.001), 0.0, 1.0)


func get_loudness_state() -> StringName:
	var loudness_ratio: float = get_loudness_ratio()
	var quiet_limit: float = clampf(quiet_max_ratio, 0.0, 0.999)
	var noisy_limit: float = clampf(noisy_max_ratio, quiet_limit + 0.001, 1.0)
	if loudness_ratio <= quiet_limit:
		return STATE_QUIET
	if loudness_ratio <= noisy_limit:
		return STATE_NOISY
	return STATE_LOUD


func update_player_movement(
	delta: float,
	horizontal_speed: float,
	input_strength: float,
	on_floor: bool,
	is_sprinting: bool,
	is_sliding: bool,
	is_wall_running: bool,
	is_climbing: bool,
	is_crouching: bool
) -> void:
	if delta <= 0.0:
		return

	var movement_state: StringName = _get_movement_state(
		horizontal_speed,
		input_strength,
		on_floor,
		is_sprinting,
		is_sliding,
		is_wall_running,
		is_climbing,
		is_crouching
	)
	var movement_loudness: float = _get_movement_loudness_for_state(
		movement_state,
		horizontal_speed,
		input_strength
	)
	_update_movement_combo(movement_state, movement_loudness)
	movement_loudness = _apply_movement_randomness(movement_loudness, movement_state, delta)
	movement_loudness = _apply_combo_multiplier(movement_loudness, movement_combo_multiplier_influence)
	_update_movement_loudness(movement_loudness, delta)
	_push_total_continuous_loudness(movement_loudness, movement_state, delta)


func register_jump(is_sprint_jump: bool, is_crouch_jump: bool, is_slide_jump: bool, horizontal_speed: float) -> void:
	var jump_noise: float = jump_loudness
	if is_sprint_jump:
		jump_noise = sprint_jump_loudness
	elif is_crouch_jump:
		jump_noise = crouch_jump_loudness
	elif is_slide_jump:
		jump_noise = slide_jump_loudness

	_register_combo_action(_get_jump_combo_gain(is_sprint_jump, is_crouch_jump, is_slide_jump))
	if not is_sprint_jump:
		jump_noise += _get_jump_speed_bonus(horizontal_speed)
	jump_noise = _apply_event_randomness(jump_noise, event_random_min_multiplier)
	push_loudness(jump_noise, event_combo_multiplier_influence, TOTAL_SOURCE_JUMP)


func register_landing(fall_speed: float, drop_height: float, landing_impact: float = 0.0) -> void:
	var height_ratio: float = _get_range_ratio(drop_height, landing_min_drop_height, landing_max_drop_height)
	if height_ratio <= 0.0:
		return

	var fall_ratio: float = _get_range_ratio(fall_speed, landing_min_fall_speed, landing_max_fall_speed)
	var impact_ratio: float = clampf(landing_impact, 0.0, 1.0)
	var shaped_height_ratio: float = pow(height_ratio, maxf(landing_loudness_curve, 0.001))
	var height_assisted_ratio: float = shaped_height_ratio
	height_assisted_ratio += shaped_height_ratio * fall_ratio * maxf(landing_fall_speed_height_influence, 0.0)
	height_assisted_ratio += shaped_height_ratio * impact_ratio * maxf(landing_impact_height_influence, 0.0)
	height_assisted_ratio = clampf(height_assisted_ratio, 0.0, 1.0)

	var landing_max_noise: float = maxf(landing_base_loudness, 0.0) + maxf(landing_drop_loudness_bonus, 0.0)
	landing_max_noise += maxf(landing_impact, 0.0) * maxf(landing_impact_loudness_multiplier, 0.0) * shaped_height_ratio
	var landing_noise: float = lerpf(maxf(landing_min_loudness, 0.0), landing_max_noise, height_assisted_ratio)
	landing_noise = _apply_event_randomness(landing_noise, landing_random_min_multiplier)
	_register_combo_action(maxf(landing_combo_gain, 0.0) + (maxf(landing_drop_combo_gain, 0.0) * shaped_height_ratio))
	# TotalLoudnessManager filters low/green landings before they can build permanent loudness.
	push_loudness(landing_noise, event_combo_multiplier_influence, TOTAL_SOURCE_LANDING)


func register_sound(loudness_amount: float) -> void:
	var sound_loudness: float = _apply_event_randomness(loudness_amount, event_random_min_multiplier)
	push_loudness(sound_loudness, 0.0, TOTAL_SOURCE_SOUND)


## Registers a one-shot loudness spike and forwards it to the permanent total meter.
func push_loudness(loudness_amount: float, combo_influence: float = 0.0, total_source: StringName = TOTAL_SOURCE_SOUND) -> void:
	var combo_loudness: float = _apply_combo_multiplier(loudness_amount, combo_influence)
	var clean_loudness: float = clampf(combo_loudness, 0.0, get_max_loudness())
	if clean_loudness <= 0.0:
		return

	_push_total_instant_loudness(clean_loudness, total_source)
	_target_loudness = maxf(_target_loudness, clean_loudness)
	if clean_loudness > _event_loudness:
		var instant_blend: float = clampf(instant_rise_ratio, 0.0, 1.0)
		_event_loudness = lerpf(_event_loudness, clean_loudness, instant_blend)
	_rebuild_current_loudness()


func _decay_loudness(delta: float) -> void:
	if delta <= 0.0:
		return

	_update_combo_decay(delta)
	_target_loudness = move_toward(_target_loudness, 0.0, maxf(target_decay_per_second, 0.0) * delta)
	var response_speed: float = fall_lerp_speed
	if _target_loudness > _event_loudness:
		response_speed = rise_lerp_speed

	var response_blend: float = 1.0 - exp(-maxf(response_speed, 0.001) * delta)
	_event_loudness = lerpf(_event_loudness, _target_loudness, response_blend)
	if _event_loudness < 0.01 and _target_loudness <= 0.01:
		_event_loudness = 0.0

	if not _movement_updated_this_frame:
		_movement_loudness = move_toward(
			_movement_loudness,
			0.0,
			maxf(movement_fall_per_second, 0.0) * delta
		)
	_movement_updated_this_frame = false
	if _movement_loudness < 0.01:
		_movement_loudness = 0.0

	_rebuild_current_loudness()


func _update_movement_loudness(movement_loudness: float, delta: float) -> void:
	_movement_updated_this_frame = true
	var clean_loudness: float = clampf(movement_loudness, 0.0, get_max_loudness())
	var step_per_second: float = movement_fall_per_second
	if clean_loudness > _movement_loudness:
		step_per_second = movement_rise_per_second

	_movement_loudness = move_toward(
		_movement_loudness,
		clean_loudness,
		maxf(step_per_second, 0.0) * delta
	)
	_rebuild_current_loudness()


## Sends sustained movement noise to TotalLoudnessManager; that manager smooths the fill.
func _push_total_continuous_loudness(loudness_amount: float, movement_state: StringName, delta: float) -> void:
	if movement_state == MOVEMENT_NONE or loudness_amount <= 0.0:
		return

	TotalLoudnessManager.add_continuous_loudness(
		loudness_amount,
		get_max_loudness(),
		movement_state,
		delta
	)


## Sends jump, landing, and sound spikes to the total meter without changing normal loudness response.
func _push_total_instant_loudness(loudness_amount: float, total_source: StringName) -> void:
	if loudness_amount <= 0.0:
		return

	TotalLoudnessManager.add_instant_loudness(
		loudness_amount,
		get_max_loudness(),
		total_source
	)


func _rebuild_current_loudness() -> void:
	_current_loudness = maxf(_movement_loudness, _event_loudness)
	_emit_loudness_changed()


func _update_movement_combo(movement_state: StringName, movement_loudness: float) -> void:
	if not enable_combo_loudness:
		_last_movement_state = movement_state
		return
	if movement_state == MOVEMENT_NONE or movement_loudness <= 0.0:
		_last_movement_state = MOVEMENT_NONE
		return

	if movement_state != _last_movement_state:
		var combo_gain: float = movement_transition_combo_gain
		if _last_movement_state == MOVEMENT_NONE:
			combo_gain = movement_start_combo_gain
		_register_combo_action(combo_gain)

	_last_movement_state = movement_state


func _register_combo_action(combo_gain: float) -> void:
	if not enable_combo_loudness:
		return

	var combo_base: float = maxf(combo_base_multiplier, 1.0)
	var combo_limit: float = maxf(combo_max_multiplier, combo_base)
	_combo_multiplier = clampf(
		maxf(_combo_multiplier, combo_base) + maxf(combo_gain, 0.0),
		combo_base,
		combo_limit
	)
	_refresh_combo_timer()


func _refresh_combo_timer() -> void:
	if not enable_combo_loudness:
		return

	_combo_timer = maxf(_combo_timer, maxf(combo_window, 0.0))


func _update_combo_decay(delta: float) -> void:
	var combo_base: float = maxf(combo_base_multiplier, 1.0)
	if not enable_combo_loudness:
		_combo_multiplier = combo_base
		_combo_timer = 0.0
		return

	if _combo_timer > 0.0:
		_combo_timer = maxf(_combo_timer - delta, 0.0)
		return

	_combo_multiplier = move_toward(
		_combo_multiplier,
		combo_base,
		maxf(combo_decay_per_second, 0.0) * delta
	)


func _apply_combo_multiplier(loudness_amount: float, combo_influence: float) -> float:
	if loudness_amount <= 0.0:
		return 0.0
	if not enable_combo_loudness:
		return loudness_amount

	var influence: float = clampf(combo_influence, 0.0, 2.0)
	var combo_strength: float = maxf(_combo_multiplier - 1.0, 0.0) * influence
	return loudness_amount * (1.0 + combo_strength)


func _get_jump_combo_gain(is_sprint_jump: bool, is_crouch_jump: bool, is_slide_jump: bool) -> float:
	if is_sprint_jump:
		return sprint_jump_combo_gain
	if is_slide_jump:
		return slide_jump_combo_gain
	if is_crouch_jump:
		return crouch_jump_combo_gain
	return jump_combo_gain


func _apply_movement_randomness(loudness_amount: float, movement_state: StringName, delta: float) -> float:
	if loudness_amount <= 0.0 or movement_state == MOVEMENT_NONE:
		_reset_movement_randomness()
		return 0.0
	if not enable_lower_randomness:
		return loudness_amount

	_update_movement_randomness(movement_state, delta)
	return loudness_amount * clampf(_movement_random_multiplier, 0.0, 1.0)


func _update_movement_randomness(movement_state: StringName, delta: float) -> void:
	if movement_state != _last_random_movement_state:
		_movement_random_target = _get_lower_random_multiplier(movement_random_min_multiplier)
		_movement_random_timer = _get_movement_random_interval()
		_last_random_movement_state = movement_state
	elif _movement_random_timer > 0.0:
		_movement_random_timer = maxf(_movement_random_timer - delta, 0.0)
	else:
		_movement_random_target = _get_lower_random_multiplier(movement_random_min_multiplier)
		_movement_random_timer = _get_movement_random_interval()

	var random_blend: float = 1.0 - exp(-maxf(movement_random_lerp_speed, 0.001) * delta)
	_movement_random_multiplier = lerpf(_movement_random_multiplier, _movement_random_target, random_blend)
	_movement_random_multiplier = clampf(_movement_random_multiplier, 0.0, 1.0)


func _reset_movement_randomness() -> void:
	_movement_random_multiplier = 1.0
	_movement_random_target = 1.0
	_movement_random_timer = 0.0
	_last_random_movement_state = MOVEMENT_NONE


func _apply_event_randomness(loudness_amount: float, min_multiplier: float) -> float:
	if loudness_amount <= 0.0:
		return 0.0
	if not enable_lower_randomness:
		return loudness_amount

	return loudness_amount * _get_lower_random_multiplier(min_multiplier)


func _get_lower_random_multiplier(min_multiplier: float) -> float:
	var clean_min: float = clampf(min_multiplier, 0.0, 1.0)
	return _random.randf_range(clean_min, 1.0)


func _get_movement_random_interval() -> float:
	var min_interval: float = maxf(movement_random_min_interval, 0.0)
	var max_interval: float = maxf(movement_random_max_interval, min_interval)
	return _random.randf_range(min_interval, max_interval)


func _get_movement_state(
	horizontal_speed: float,
	input_strength: float,
	on_floor: bool,
	is_sprinting: bool,
	is_sliding: bool,
	is_wall_running: bool,
	is_climbing: bool,
	is_crouching: bool
) -> StringName:
	if is_climbing:
		return MOVEMENT_CLIMB
	if is_wall_running:
		return MOVEMENT_WALL_RUN
	if is_sliding:
		return MOVEMENT_SLIDE
	if not on_floor:
		return MOVEMENT_NONE
	if horizontal_speed <= minimum_moving_speed and input_strength <= 0.01:
		return MOVEMENT_NONE
	if is_sprinting:
		return MOVEMENT_SPRINT
	if is_crouching:
		return MOVEMENT_CROUCH
	return MOVEMENT_WALK


func _get_movement_loudness_for_state(movement_state: StringName, horizontal_speed: float, input_strength: float) -> float:
	if movement_state == MOVEMENT_CLIMB:
		return _scale_active_state_loudness(climb_loudness, horizontal_speed)
	if movement_state == MOVEMENT_WALL_RUN:
		return _scale_active_state_loudness(wall_run_loudness, horizontal_speed)
	if movement_state == MOVEMENT_SLIDE:
		return _scale_active_state_loudness(slide_loudness, horizontal_speed)
	if movement_state == MOVEMENT_SPRINT:
		return _scale_active_state_loudness(sprint_loudness, horizontal_speed)
	if movement_state == MOVEMENT_CROUCH:
		return _scale_ground_loudness(crouch_loudness, horizontal_speed, input_strength)
	if movement_state == MOVEMENT_WALK:
		return _scale_ground_loudness(walk_loudness, horizontal_speed, input_strength)
	return 0.0


func _scale_active_state_loudness(base_loudness: float, horizontal_speed: float) -> float:
	var speed_ratio: float = clampf(horizontal_speed / maxf(movement_speed_reference, 0.001), 0.0, 1.0)
	return maxf(base_loudness, 0.0) * lerpf(0.65, 1.0, speed_ratio)


func _scale_ground_loudness(base_loudness: float, horizontal_speed: float, input_strength: float) -> float:
	var speed_ratio: float = clampf(horizontal_speed / maxf(movement_speed_reference, 0.001), 0.0, 1.0)
	var input_ratio: float = pow(clampf(input_strength, 0.0, 1.0), maxf(movement_input_power, 0.001))
	var movement_ratio: float = maxf(speed_ratio, input_ratio)
	return maxf(base_loudness, 0.0) * clampf(movement_ratio, 0.0, 1.0)


func _get_jump_speed_bonus(horizontal_speed: float) -> float:
	var speed_ratio: float = clampf(horizontal_speed / maxf(jump_speed_bonus_full_speed, 0.001), 0.0, 1.0)
	return speed_ratio * maxf(jump_speed_loudness_bonus, 0.0)


func _get_range_ratio(value: float, min_value: float, max_value: float) -> float:
	var clean_min: float = maxf(min_value, 0.0)
	var clean_max: float = maxf(max_value, clean_min + 0.001)
	return clampf((maxf(value, 0.0) - clean_min) / maxf(clean_max - clean_min, 0.001), 0.0, 1.0)


func _emit_loudness_changed(force_emit: bool = false) -> void:
	var loudness_state: StringName = get_loudness_state()
	var should_emit: bool = force_emit
	should_emit = should_emit or absf(_current_loudness - _last_emitted_loudness) >= maxf(emit_change_threshold, 0.0)
	should_emit = should_emit or loudness_state != _last_emitted_state
	if not should_emit:
		return

	_last_emitted_loudness = _current_loudness
	_last_emitted_state = loudness_state
	loudness_changed.emit(_current_loudness, get_max_loudness(), get_loudness_ratio(), loudness_state)
