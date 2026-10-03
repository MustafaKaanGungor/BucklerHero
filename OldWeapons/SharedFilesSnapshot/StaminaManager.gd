extends Node

signal stamina_changed(current_stamina: float, max_stamina: float, stamina_ratio: float)
signal stamina_depleted

@export_group("Stamina Pool")
## Maximum stamina value; the stamina bar starts full.
@export var max_stamina: float = 200.0 ##Bilerek fazla yaptım ama çokta fazla değil mantık anlaşılsın diye
## Minimum stamina needed before a draining movement can start.
@export var minimum_action_stamina: float = 1.0
## Stamina needed to unlock stamina actions again after stamina is exhausted.
@export var exhausted_recovery_stamina: float = 18.0

@export_group("Drain Per Second")
## Highest drain: stamina spent each second while climbing.
@export var climb_stamina_per_second: float = 34.0
## Second highest drain: stamina spent each second while wall running.
@export var wall_run_stamina_per_second: float = 25.0
## Sliding drain: stamina spent each second while sliding.
@export var slide_stamina_per_second: float = 16.0
## Lowest drain: stamina spent each second while sprinting.
@export var sprint_stamina_per_second: float = 7.0
## Stamina spent each second while charging with the shield (not while braking).
@export var shield_charge_stamina_per_second: float = 14.0

@export_group("Instant Costs")
## Slide jump is a one-shot cost; higher than slide and lower than wall run.
@export var slide_jump_stamina_cost: float = 10.0
## Sprint jump is a one-shot cost when the sprint jump boost starts.
@export var sprint_jump_stamina_cost: float = 10.0

@export_group("Recovery")
## Enables stamina recovery when no stamina-draining movement is active.
@export var enable_recovery: bool = true
## Stamina recovered each second after the recovery delay.
@export var recovery_per_second: float = 18.0
## Delay after spending stamina before recovery starts.
@export var recovery_delay: float = 0.45

var _current_stamina: float = 100.0
var _recovery_block_timer: float = 1.0
var _is_spending_this_frame: bool = false
var _is_exhausted_recovery_locked: bool = false


func _ready() -> void:
	reset_stamina()


func _physics_process(delta: float) -> void:
	if _is_spending_this_frame:
		_is_spending_this_frame = false
		return

	if _recovery_block_timer > 0.0:
		_recovery_block_timer = maxf(_recovery_block_timer - delta, 0.0)
		return

	if enable_recovery:
		_add_stamina(maxf(recovery_per_second, 0.0) * delta)


func reset_stamina() -> void:
	_current_stamina = maxf(max_stamina, 0.0)
	_recovery_block_timer = 0.0
	_is_exhausted_recovery_locked = false
	_emit_stamina_changed()


func get_stamina() -> float:
	return _current_stamina


func get_max_stamina() -> float:
	return maxf(max_stamina, 0.0)


func get_stamina_ratio() -> float:
	return clampf(_current_stamina / maxf(get_max_stamina(), 0.001), 0.0, 1.0)


func can_sprint() -> bool:
	return _can_use_continuous_action()


func can_slide() -> bool:
	return _can_use_continuous_action()


func can_slide_jump() -> bool:
	return _can_use_instant_action(slide_jump_stamina_cost)


func can_wall_run() -> bool:
	return _can_use_continuous_action()


func can_sprint_jump() -> bool:
	return _can_use_instant_action(sprint_jump_stamina_cost)


func can_climb() -> bool:
	return _can_use_continuous_action()


func can_shield_charge() -> bool:
	return _can_use_continuous_action()


func drain_sprint(delta: float) -> bool:
	return _drain_stamina(sprint_stamina_per_second, delta)


func drain_slide(delta: float) -> bool:
	return _drain_stamina(slide_stamina_per_second, delta)


func drain_wall_run(delta: float) -> bool:
	return _drain_stamina(wall_run_stamina_per_second, delta)


func drain_climb(delta: float) -> bool:
	return _drain_stamina(climb_stamina_per_second, delta)


func drain_shield_charge(delta: float) -> bool:
	return _drain_stamina(shield_charge_stamina_per_second, delta)


## Hook grapple: zipping and swinging drain at MovementGrapple's rates.
func drain_grapple(delta: float, swinging: bool) -> bool:
	var rate: float = MovementGrapple.swing_stamina_per_second if swinging else MovementGrapple.zip_stamina_per_second
	return _drain_stamina(rate, delta)


## Hook grapple latch cost (MovementGrapple.latch_stamina_cost).
func spend_grapple() -> bool:
	var cost: float = maxf(MovementGrapple.latch_stamina_cost, 0.0)
	if not _can_use_instant_action(cost):
		return false
	_spend_stamina(cost)
	return true


func spend_slide_jump() -> bool:
	if not can_slide_jump():
		return false

	_spend_stamina(maxf(slide_jump_stamina_cost, 0.0))
	return true


func spend_sprint_jump() -> bool:
	if not can_sprint_jump():
		return false

	_spend_stamina(maxf(sprint_jump_stamina_cost, 0.0))
	return true


func _has_action_stamina() -> bool:
	return _current_stamina >= maxf(minimum_action_stamina, 0.0)


func _can_use_continuous_action() -> bool:
	_update_exhausted_recovery_lock()
	if _is_exhausted_recovery_locked:
		return false
	if not _has_action_stamina():
		_start_exhausted_recovery_lock()
		return false
	return true


func _can_use_instant_action(stamina_cost: float) -> bool:
	_update_exhausted_recovery_lock()
	if _is_exhausted_recovery_locked:
		return false
	if not _has_action_stamina():
		_start_exhausted_recovery_lock()
		return false
	return _current_stamina >= maxf(stamina_cost, minimum_action_stamina)


func _drain_stamina(stamina_per_second: float, delta: float) -> bool:
	if not _can_use_continuous_action():
		return false

	_spend_stamina(maxf(stamina_per_second, 0.0) * maxf(delta, 0.0))
	if not _has_action_stamina():
		_start_exhausted_recovery_lock()
		return false
	return true


func _spend_stamina(amount: float) -> void:
	if amount <= 0.0:
		return

	_is_spending_this_frame = true
	_recovery_block_timer = maxf(recovery_delay, 0.0)
	var previous_stamina: float = _current_stamina
	_current_stamina = clampf(_current_stamina - amount, 0.0, get_max_stamina())
	if not is_equal_approx(previous_stamina, _current_stamina):
		_emit_stamina_changed()
	if not _has_action_stamina():
		_start_exhausted_recovery_lock()
	if _current_stamina <= 0.0 and previous_stamina > 0.0:
		_start_exhausted_recovery_lock()
		stamina_depleted.emit()


func _add_stamina(amount: float) -> void:
	if amount <= 0.0:
		return

	var previous_stamina: float = _current_stamina
	_current_stamina = clampf(_current_stamina + amount, 0.0, get_max_stamina())
	if not is_equal_approx(previous_stamina, _current_stamina):
		_emit_stamina_changed()
	_update_exhausted_recovery_lock()


func _start_exhausted_recovery_lock() -> void:
	_is_exhausted_recovery_locked = true


func _update_exhausted_recovery_lock() -> void:
	if not _is_exhausted_recovery_locked:
		return

	var recovery_unlock_stamina: float = maxf(exhausted_recovery_stamina, minimum_action_stamina)
	recovery_unlock_stamina = minf(recovery_unlock_stamina, get_max_stamina())
	if _current_stamina >= recovery_unlock_stamina:
		_is_exhausted_recovery_locked = false


func _emit_stamina_changed() -> void:
	stamina_changed.emit(_current_stamina, get_max_stamina(), get_stamina_ratio())
