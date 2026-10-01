extends Node

@export_group("Gravity")
@export var gravity: float = 23.0
@export var terminal_fall_speed: float = 65.0

@export_group("World")
@export var spawn_height_offset: float = 0.05


func get_gravity() -> float:
	return gravity


func get_terminal_fall_speed() -> float:
	return terminal_fall_speed


func get_spawn_height_offset() -> float:
	return spawn_height_offset
