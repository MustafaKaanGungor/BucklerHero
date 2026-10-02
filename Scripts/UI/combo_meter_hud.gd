extends Control

## Bottom-centre combo meter: a big rank letter (D to S) with its word under it and a bar that shows
## how far into the rank you are, draining as the meter drains. Reads the ComboMeter autoload.
## The letter pops when the rank goes up and shakes when it drops; the bar turns icy while a shield
## charge is carrying enemies (the meter is frozen). Fades out when the meter is empty.
## Plays a short stinger when the rank goes up, higher-pitched for higher ranks. Reaching S (weapons
## empowered) instead plays a bigger power-up sound, bursts the EmpowerFlash screen glow and shakes
## the camera.
## Builds its own nodes; the scene only places this Control.

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")

@export_group("Look")
## Letter colour per rank, D to S.
@export var rank_colors: Array[Color] = [
	Color(0.55, 0.65, 0.8),
	Color(0.45, 0.85, 0.5),
	Color(0.95, 0.85, 0.3),
	Color(1.0, 0.55, 0.2),
	Color(1.0, 0.25, 0.25),
]
## Bar colour while the meter is frozen by a carrying shield charge.
@export var frozen_color: Color = Color(0.55, 0.9, 1.0)
## Size of the rank letter.
@export var letter_font_size: int = 140
## Size of the rank word.
@export var word_font_size: int = 26
## Bar size in pixels.
@export var bar_size: Vector2 = Vector2(260.0, 12.0)

@export_group("Sound")
## Volume of the rank-up stinger, in decibels.
@export var rank_up_volume_db: float = -6.0
## Pitch of the stinger at rank D; each rank above adds rank_up_pitch_step.
@export var rank_up_base_pitch: float = 0.9
@export var rank_up_pitch_step: float = 0.12

@export_group("S Rank")
## Rank that counts as reaching S (ComboMeter: 4).
@export var s_rank: int = 4
## Screen flash fired on reaching S (a screen_flash.gd node with trigger MANUAL).
@export var s_flash_path: NodePath = NodePath("../EmpowerFlash")
## Camera shake on reaching S, from 0 (none) to 1 (strongest).
@export_range(0.0, 1.0) var s_screen_shake: float = 0.45
## Volume of the S power-up sound, in decibels.
@export var s_volume_db: float = -3.0
## Letter pop scale on reaching S (bigger than a normal rank up).
@export var s_pop_scale: float = 2.0

@export_group("Motion")
## Seconds the meter takes to fade in or out.
@export var fade_time: float = 0.25
## Scale of the letter pop when the rank goes up.
@export var rank_up_pop_scale: float = 1.45
## Seconds the pop takes to settle.
@export var pop_time: float = 0.3
## Shake distance in pixels when the rank drops.
@export var rank_down_shake: float = 10.0

var _letter: Label
var _word: Label
var _bar_back: ColorRect
var _bar_fill: ColorRect
var _alpha: float = 0.0
var _pop_tween: Tween
var _shake_time: float = 0.0
var _rank_up_player: AudioStreamPlayer
var _message: Label
var _message_time: float = 0.0
var _weapons: Node
var _s_rank_player: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter = Label.new()
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_letter.add_theme_font_size_override(&"font_size", letter_font_size)
	_letter.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_letter.add_theme_constant_override(&"outline_size", 14)
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letter)

	_word = Label.new()
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.add_theme_font_size_override(&"font_size", word_font_size)
	_word.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_word.add_theme_constant_override(&"outline_size", 6)
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_word)

	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.0, 0.0, 0.0, 0.55)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar_fill)

	_rank_up_player = AudioStreamPlayer.new()
	_rank_up_player.stream = _build_rank_up_sound()
	_rank_up_player.volume_db = rank_up_volume_db
	add_child(_rank_up_player)
	_s_rank_player = AudioStreamPlayer.new()
	_s_rank_player.stream = _build_s_rank_sound()
	_s_rank_player.volume_db = s_volume_db
	add_child(_s_rank_player)

	modulate.a = 0.0
	ComboMeter.rank_changed.connect(_on_rank_changed)
	# The crossbow's "no combo" warning lives outside this control, which fades out when empty.
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override(&"font_size", 30)
	_message.add_theme_color_override(&"font_color", Color(1.0, 0.3, 0.2))
	_message.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_message.add_theme_constant_override(&"outline_size", 8)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	get_parent().add_child.call_deferred(_message)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var letter_height: float = float(letter_font_size) * 1.15
	_letter.position = Vector2(0.0, 0.0)
	_letter.size = Vector2(size.x, letter_height)
	_letter.pivot_offset = _letter.size * Vector2(0.5, 0.7)
	_word.position = Vector2(0.0, letter_height - 6.0)
	_word.size = Vector2(size.x, float(word_font_size) * 1.4)
	_bar_back.position = Vector2((size.x - bar_size.x) * 0.5, letter_height + float(word_font_size) * 1.4)
	_bar_back.size = bar_size


## Flashes a short warning above the meter (the crossbow fired with an empty meter).
func show_message(text: String) -> void:
	_message.text = text
	_message_time = 1.0


func _process(delta: float) -> void:
	if _weapons == null or not is_instance_valid(_weapons):
		_weapons = get_tree().get_first_node_in_group(&"player_melee")
		if _weapons != null and _weapons.has_signal(&"crossbow_dry_fired"):
			_weapons.connect(&"crossbow_dry_fired", show_message.bind("NEED COMBO"))
	if _message.is_inside_tree():
		_message.size = Vector2(size.x, 40.0)
		_message.global_position = global_position + Vector2(0.0, size.y * 0.35)
		_message_time = maxf(_message_time - delta / maxf(Engine.time_scale, 0.001), 0.0)
		_message.modulate.a = clampf(_message_time / 0.3, 0.0, 1.0)
		_message.position.x += sin(_message_time * 60.0) * 6.0 * _message_time
	var rank: int = ComboMeter.get_rank()
	var target_alpha: float = 1.0 if rank >= 0 else 0.0
	_alpha = move_toward(_alpha, target_alpha, delta / maxf(fade_time, 0.01))
	modulate.a = _alpha
	if rank >= 0:
		var color: Color = rank_colors[mini(rank, rank_colors.size() - 1)]
		_letter.text = ComboMeter.get_rank_letter()
		_word.text = ComboMeter.get_rank_word()
		_letter.add_theme_color_override(&"font_color", color)
		_word.add_theme_color_override(&"font_color", color.lerp(Color.WHITE, 0.35))
		_bar_fill.color = frozen_color if ComboMeter.is_frozen() else color
		_bar_fill.size = Vector2(bar_size.x * ComboMeter.get_rank_progress(), bar_size.y)

	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		var strength: float = rank_down_shake * (_shake_time / 0.3)
		_letter.position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.5)
	else:
		_letter.position = Vector2.ZERO


func _on_rank_changed(rank: int, previous_rank: int) -> void:
	if rank > previous_rank:
		if _pop_tween != null and _pop_tween.is_valid():
			_pop_tween.kill()
		var reached_s: bool = rank >= s_rank and previous_rank < s_rank
		_letter.scale = Vector2.ONE * (s_pop_scale if reached_s else rank_up_pop_scale)
		_pop_tween = create_tween()
		_pop_tween.tween_property(_letter, ^"scale", Vector2.ONE, maxf(pop_time, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if reached_s:
			_play_s_rank_effect()
		else:
			_rank_up_player.pitch_scale = maxf(rank_up_base_pitch + rank_up_pitch_step * float(rank), 0.1)
			_rank_up_player.play()
	elif rank >= 0:
		_shake_time = 0.3


## A punchy stinger: a low hit, then two quick rising tones (a fifth apart) with a bright swish.
func _build_rank_up_sound() -> AudioStreamWAV:
	var stinger: PackedFloat32Array = SoundSynth.thud(0.25, 180.0, 70.0, 14.0, 0.8, 30.0, 0.6, 301)
	stinger = SoundSynth.mix(stinger, SoundSynth.tone_sweep(0.22, 440.0, 520.0, 0.05, 0.0, 302), 0.55, 0.02)
	stinger = SoundSynth.mix(stinger, SoundSynth.tone_sweep(0.38, 660.0, 790.0, 0.05, 7.0, 303), 0.6, 0.09)
	stinger = SoundSynth.mix(stinger, SoundSynth.whoosh(0.3, 1500.0, 5000.0, 2500.0, 0.25, 2.0, 304), 0.35, 0.05)
	return SoundSynth.make_wav(SoundSynth.normalize(stinger))


func _play_s_rank_effect() -> void:
	_s_rank_player.play()
	var flash: Node = get_node_or_null(s_flash_path)
	if flash != null and flash.has_method(&"flash"):
		flash.call(&"flash", 1.0)
	var player: Node = get_tree().get_first_node_in_group(&"player")
	var camera: Node = player.get_node_or_null("Head/Camera3D") if player != null else null
	if camera != null and camera.has_method(&"add_screen_shake"):
		camera.call(&"add_screen_shake", s_screen_shake)


## A power-up: a deep boom, a rising rush, and a bright major chord that swells and rings out.
func _build_s_rank_sound() -> AudioStreamWAV:
	var sound: PackedFloat32Array = SoundSynth.thud(0.9, 90.0, 30.0, 4.0, 1.0, 10.0, 0.4, 311)
	sound = SoundSynth.mix(sound, SoundSynth.whoosh(0.6, 200.0, 3000.0, 1500.0, 0.8, 1.8, 312), 0.6)
	for note in [[440.0, 0.0], [554.37, 0.04], [659.25, 0.08], [880.0, 0.12]]:
		var tone: PackedFloat32Array = SoundSynth.tone_sweep(1.1, float(note[0]) * 0.97, float(note[0]), 0.15, 6.0, 313 + int(note[0]))
		sound = SoundSynth.mix(sound, tone, 0.3, 0.35 + float(note[1]))
	return SoundSynth.make_wav(SoundSynth.normalize(sound))
