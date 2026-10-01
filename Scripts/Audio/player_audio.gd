extends Node

## Footstep, jump and landing sounds. Child of the Player (player.tscn) and read-only toward it:
## steps come from the distance the player covers on the floor (or along a wall while wall
## running); jumps and landings come from the player's jumped / landed signals.
## Sounds are synthesized once in _ready (sound_synth.gd): four footstep variants picked at random,
## a push-off for jumps, and a thump for landings that gets louder and deeper with fall speed.

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")
const METHOD_GET_HORIZONTAL_SPEED: StringName = &"get_horizontal_speed"
const METHOD_IS_SLIDING: StringName = &"is_sliding"
const METHOD_IS_CROUCHING: StringName = &"is_crouching"
const METHOD_IS_WALL_RUNNING: StringName = &"is_wall_running"
const METHOD_IS_CLIMBING: StringName = &"is_climbing"
const FOOTSTEP_VARIANTS: int = 4

@export_group("Footsteps")
## Metres between steps at walking speed.
@export var walk_stride: float = 1.8
## Metres between steps at full sprint speed.
@export var sprint_stride: float = 2.7
## Speeds that map to walk_stride and sprint_stride.
@export var walk_speed: float = 4.7
@export var sprint_speed: float = 12.8
## Metres between steps while wall running.
@export var wall_run_stride: float = 2.4
## No steps below this horizontal speed.
@export var min_step_speed: float = 1.0
## Footstep volume when walking / sprinting, in decibels (interpolated by speed).
@export var walk_step_volume_db: float = -20.0
@export var sprint_step_volume_db: float = -13.0
## Volume change while crouch-walking.
@export var crouch_step_volume_offset_db: float = -8.0
## Footstep volume while wall running.
@export var wall_run_step_volume_db: float = -15.0

@export_group("Jump And Landing")
## Jump push-off volume, in decibels.
@export var jump_volume_db: float = -14.0
## Landings slower than this (m/s downward) are silent; stepping off a curb shouldn't thud.
@export var min_landing_speed: float = 3.0
## Fall speed that gives the loudest, deepest landing.
@export var heavy_landing_speed: float = 20.0
## Landing volume for a light and for a heavy landing.
@export var light_landing_volume_db: float = -18.0
@export var heavy_landing_volume_db: float = -3.0

@export_group("Variation")
## Random pitch change per sound.
@export_range(0.0, 0.5) var pitch_variation: float = 0.08

var _player: CharacterBody3D
var _step_players: Array[AudioStreamPlayer] = []
var _jump_player: AudioStreamPlayer
var _landing_player: AudioStreamPlayer
var _step_distance: float = 0.0
var _last_position: Vector3 = Vector3.ZERO
var _last_variant: int = -1


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	for variant in range(FOOTSTEP_VARIANTS):
		var step: PackedFloat32Array = SoundSynth.thud(0.13, 120.0 + 12.0 * variant, 70.0, 40.0, 0.9, 45.0, 0.45 + 0.08 * variant, 51 + variant)
		_step_players.append(_add_player("Step%d" % variant, step))
	var push: PackedFloat32Array = SoundSynth.thud(0.12, 140.0, 80.0, 35.0, 0.8, 40.0, 0.5, 61)
	push = SoundSynth.mix(push, SoundSynth.whoosh(0.22, 300.0, 900.0, 400.0, 0.3, 1.4, 62), 0.6, 0.02)
	_jump_player = _add_player("Jump", push)
	var landing: PackedFloat32Array = SoundSynth.thud(0.3, 110.0, 45.0, 14.0, 1.0, 30.0, 0.4, 63)
	_landing_player = _add_player("Landing", landing)

	if _player != null:
		_last_position = _player.global_position
		_player.connect(&"jumped", _on_jumped)
		_player.connect(&"landed", _on_landed)


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var position_now: Vector3 = _player.global_position
	var moved: Vector3 = position_now - _last_position
	_last_position = position_now
	# Teleports (respawn, level change) don't count as walking.
	if moved.length() > 3.0:
		_step_distance = 0.0
		return

	var is_wall_running: bool = _player_bool(METHOD_IS_WALL_RUNNING)
	var on_ground: bool = _player.is_on_floor() and not _player_bool(METHOD_IS_SLIDING)
	if _player_bool(METHOD_IS_CLIMBING) or (not on_ground and not is_wall_running):
		# Next step lands soon after touching down again.
		_step_distance = maxf(_step_distance, walk_stride * 0.6)
		return

	var speed: float = _player_float(METHOD_GET_HORIZONTAL_SPEED, Vector2(_player.velocity.x, _player.velocity.z).length())
	if speed < min_step_speed:
		_step_distance = walk_stride * 0.6
		return

	_step_distance += Vector2(moved.x, moved.z).length()
	var speed_ratio: float = clampf((speed - walk_speed) / maxf(sprint_speed - walk_speed, 0.001), 0.0, 1.0)
	var stride: float = wall_run_stride if is_wall_running else lerpf(walk_stride, sprint_stride, speed_ratio)
	if _step_distance < stride:
		return
	_step_distance = fmod(_step_distance, maxf(stride, 0.1))

	var volume: float = lerpf(walk_step_volume_db, sprint_step_volume_db, speed_ratio)
	if is_wall_running:
		volume = wall_run_step_volume_db
	elif _player_bool(METHOD_IS_CROUCHING):
		volume += crouch_step_volume_offset_db
	_play_step(volume, 1.0 + 0.06 * speed_ratio)


func _play_step(volume_db: float, pitch: float) -> void:
	var variant: int = randi_range(0, FOOTSTEP_VARIANTS - 1)
	if variant == _last_variant:
		variant = (variant + 1) % FOOTSTEP_VARIANTS
	_last_variant = variant
	_play(_step_players[variant], volume_db, pitch)


func _on_jumped(kind: StringName, strength: float) -> void:
	var pitch: float = 1.0
	if kind == &"wall":
		pitch = 1.12
	elif kind == &"climb":
		pitch = 1.06
	_play(_jump_player, jump_volume_db + clampf(strength - 1.0, -0.5, 0.5) * 6.0, pitch)
	_step_distance = 0.0


func _on_landed(fall_speed: float, _impact: float) -> void:
	if fall_speed < min_landing_speed:
		return
	var ratio: float = clampf((fall_speed - min_landing_speed) / maxf(heavy_landing_speed - min_landing_speed, 0.001), 0.0, 1.0)
	_play(_landing_player, lerpf(light_landing_volume_db, heavy_landing_volume_db, ratio), lerpf(1.1, 0.8, ratio))
	# The landing is the step; the next one comes a full stride later.
	_step_distance = 0.0


func _play(player: AudioStreamPlayer, volume_db: float, pitch: float) -> void:
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch * (1.0 + randf_range(-pitch_variation, pitch_variation)), 0.1)
	player.play()


func _add_player(player_name: String, samples: PackedFloat32Array) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.stream = SoundSynth.make_wav(SoundSynth.normalize(samples))
	player.max_polyphony = 2
	add_child(player)
	return player


func _player_bool(method: StringName) -> bool:
	if _player == null or not _player.has_method(method):
		return false
	return bool(_player.call(method))


func _player_float(method: StringName, fallback: float) -> float:
	if _player == null or not _player.has_method(method):
		return fallback
	return float(_player.call(method))
