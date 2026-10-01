extends Node

signal health_changed(current_health: float, max_health: float, health_ratio: float)
signal damaged(amount: float)
signal died
## A hit was stopped by the braced shield; no health was lost.
signal blocked(amount: float)
## Health was restored; amount is what was actually gained (capped at max health).
signal healed(amount: float)

@export_group("Health Pool")
## Maximum player health; the health bar starts full.
@export var max_health: float = 100.0

@export_group("Feedback")
## Camera kick when the player takes a hit, scaled up for bigger hits. It springs back on its own.
@export var damage_camera_kick_degrees: Vector3 = Vector3(-2.2, 0.0, 1.6)
## Damage that gives the full camera kick.
@export var damage_for_full_camera_kick: float = 15.0
## Share of the damage camera kick used when the shield blocks a hit.
@export_range(0.0, 1.0) var block_camera_kick_multiplier: float = 0.35
## Screen shake for a hit of damage_for_full_camera_kick or more, from 0 (none) to 1 (strongest).
## Smaller hits shake proportionally less; blocked hits use block_camera_kick_multiplier of it.
@export_range(0.0, 1.0) var damage_screen_shake: float = 0.55
## Loudness added to the stealth meter when the shield blocks a hit.
@export var block_loudness: float = 18.0

var _current_health: float = 100.0
var _is_dead: bool = false


func _ready() -> void:
	reset_health()


func reset_health() -> void:
	_current_health = maxf(max_health, 0.0)
	_is_dead = false
	_emit_health_changed()


func get_health() -> float:
	return _current_health


func get_max_health() -> float:
	return maxf(max_health, 0.0)


func get_health_ratio() -> float:
	return clampf(_current_health / maxf(get_max_health(), 0.001), 0.0, 1.0)


func is_dead() -> bool:
	return _is_dead


## Takes health away. Returns false if nothing happened (already dead or no damage).
func damage(amount: float) -> bool:
	if _is_dead or amount <= 0.0:
		return false

	_current_health = clampf(_current_health - amount, 0.0, get_max_health())
	_emit_health_changed()
	damaged.emit(amount)
	if _current_health <= 0.0:
		_is_dead = true
		died.emit()
	return true


## Reports a hit the shield stopped, so camera and sound can react. Takes no health.
func register_block(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	LoudnessManger.register_sound(block_loudness)
	blocked.emit(amount)


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return

	var previous_health: float = _current_health
	_current_health = clampf(_current_health + amount, 0.0, get_max_health())
	_emit_health_changed()
	if _current_health > previous_health:
		healed.emit(_current_health - previous_health)


## How strongly the camera should kick for a hit of this size, from 0 to 1.
func get_camera_kick_strength(amount: float) -> float:
	return clampf(amount / maxf(damage_for_full_camera_kick, 0.001), 0.0, 1.0)


func _emit_health_changed() -> void:
	health_changed.emit(_current_health, get_max_health(), get_health_ratio())
