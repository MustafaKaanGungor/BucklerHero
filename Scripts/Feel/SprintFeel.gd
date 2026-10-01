extends Node

@export_group("Speed")
## Maximum sprint speed after the sprint ramp finishes.
@export var sprint_speed: float = 10.8
## Enables gradual sprint speed buildup instead of instant max sprint.
@export var enable_sprint_speed_ramp: bool = true
## Speed used when sprint first starts.
@export var sprint_start_speed: float = 8.0
## Speed added per second while sprint is held.
@export var sprint_speed_gain_per_second: float = 8.8

@export_group("Camera Feel")
## Extra FOV added as sprint builds up.
@export var sprint_fov_bonus: float = 15.5
## Vertical bob amount while sprinting.
@export var sprint_bob_amount: float = 0.2
## Frequency multiplier applied while sprinting.
@export var sprint_bob_frequency_multiplier: float = 0.55
## Roll multiplier while sprinting.
@export var sprint_roll_multiplier: float = 1.28
