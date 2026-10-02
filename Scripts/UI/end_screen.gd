extends Control

## End-of-run screen for generated levels, in two kinds (ui.tscn has one node of each):
## DEATH (DeathScreen) when the player dies, VICTORY (VictoryScreen) when the level generator emits
## run_won after the final level. Sequence:
## 1. INTRO: the game slows to intro_time_scale while a screen-reading overlay tints the view
##    (dark red and grey for death, warm gold for victory) and the title scales in; a sting plays.
## 2. SHOWN: the game pauses and the run summary appears (level and section reached or levels
##    cleared, enemies slain, best combo rank, time), then a blinking prompt.
## 3. Click, Space or Enter restarts the run from the first level's first corridor through
##    restart_run() on the level generator (group level_navigation), and the screen fades away.
## Without a level generator (the main.tscn test level) it stays hidden and main.gd's instant
## respawn is used instead. Builds its own nodes; runs while the tree is paused.

signal continued

enum Kind {
	DEATH,
	VICTORY,
}

enum Phase {
	HIDDEN,
	INTRO,
	SHOWN,
	LEAVING,
}

const SoundSynth = preload("res://Scripts/Audio/sound_synth.gd")
const GROUP_LEVEL_NAVIGATION: StringName = &"level_navigation"
const METHOD_RESTART_RUN: StringName = &"restart_run"
const METHOD_GET_RUN_SUMMARY: StringName = &"get_run_summary"
const SIGNAL_RUN_WON: StringName = &"run_won"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_JUMP: StringName = &"move_jump"
const ACTION_ACCEPT: StringName = &"ui_accept"

const SCREEN_SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.05, 0.04, 1.0);
uniform float desaturate = 1.0;
uniform float tint_strength = 0.65;
uniform float darken = 0.35;
uniform float vignette_darken = 0.55;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(grey), amount * desaturate);
	color = mix(color, vec3(grey) * tint.rgb * 2.2, amount * tint_strength);
	vec2 centred = UV - vec2(0.5);
	float vignette = smoothstep(0.2, 0.85, length(centred) * 1.35);
	color *= 1.0 - amount * (darken + vignette_darken * vignette);
	COLOR = vec4(color, 1.0);
}
"""

@export_group("Kind")
## DEATH shows on HealthManager.died; VICTORY on the level generator's run_won.
@export var kind: Kind = Kind.DEATH

@export_group("Timing")
## Game speed during the intro, before the pause.
@export_range(0.05, 1.0) var intro_time_scale: float = 0.2
## Real seconds from the trigger to the paused summary.
@export var intro_time: float = 1.6
## Real seconds after the summary appears before the prompt shows and input is accepted.
@export var prompt_delay: float = 0.8
## Real seconds the screen takes to clear after continuing.
@export var leave_time: float = 0.45

@export_group("Look")
@export var title_text: String = "DEFEATED"
@export var title_color: Color = Color(0.85, 0.08, 0.06)
@export var title_font_size: int = 120
@export var text_font_size: int = 30
@export var prompt_text: String = "CLICK OR PRESS SPACE TO TRY AGAIN"
## Overlay: tint colour, how much colour drains to grey (0..1), how strongly the tint is applied,
## how much the whole view darkens and how much more the edges darken.
@export var overlay_tint: Color = Color(0.55, 0.05, 0.04)
@export_range(0.0, 1.0) var overlay_desaturate: float = 1.0
@export_range(0.0, 1.0) var overlay_tint_strength: float = 0.65
@export_range(0.0, 1.0) var overlay_darken: float = 0.35
@export_range(0.0, 1.0) var overlay_vignette_darken: float = 0.55
## One of these lines is shown under the title, picked at random.
@export var subtitles: Array[String] = [
	"The arena keeps what it kills.",
	"Your combo ends here.",
	"Steel dulled. Blood spent.",
	"Back to the first corridor.",
	"They will remember this one.",
]

@export_group("Sound")
## Volume of the sting (death: a falling, dark sting; victory: a rising fanfare), in decibels.
@export var sting_volume_db: float = -2.0

var _phase: Phase = Phase.HIDDEN
var _phase_time: float = 0.0
var _overlay: ColorRect
var _overlay_material: ShaderMaterial
var _title: Label
var _subtitle: Label
var _stats: Label
var _prompt: Label
var _sting_player: AudioStreamPlayer
var _connected_level: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	if kind == Kind.DEATH:
		HealthManager.died.connect(_begin)


func _exit_tree() -> void:
	if _phase != Phase.HIDDEN and is_inside_tree():
		get_tree().paused = false
	Engine.time_scale = 1.0


func is_showing() -> bool:
	return _phase != Phase.HIDDEN


func _begin() -> void:
	if _get_level() == null or _phase != Phase.HIDDEN:
		return
	_phase = Phase.INTRO
	_phase_time = 0.0
	_subtitle.text = subtitles.pick_random() if not subtitles.is_empty() else ""
	_stats.text = ""
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_stats.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	visible = true
	_sting_player.play()


func _process(delta: float) -> void:
	if kind == Kind.VICTORY:
		_connect_level()
	if _phase == Phase.HIDDEN:
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	_phase_time += real_delta
	match _phase:
		Phase.INTRO:
			var progress: float = clampf(_phase_time / maxf(intro_time, 0.01), 0.0, 1.0)
			Engine.time_scale = lerpf(1.0, intro_time_scale, clampf(progress * 3.0, 0.0, 1.0))
			_set_overlay_amount(_ease_out(progress))
			_title.modulate.a = clampf((progress - 0.25) / 0.5, 0.0, 1.0)
			_title.scale = Vector2.ONE * lerpf(1.25, 1.0, _ease_out(clampf((progress - 0.25) / 0.5, 0.0, 1.0)))
			if progress >= 1.0:
				_show_summary()
		Phase.SHOWN:
			_subtitle.modulate.a = clampf(_phase_time / 0.4, 0.0, 1.0)
			_stats.modulate.a = clampf((_phase_time - 0.2) / 0.4, 0.0, 1.0)
			if _phase_time >= prompt_delay:
				_prompt.modulate.a = 0.55 + 0.45 * sin((_phase_time - prompt_delay) * TAU * 0.8)
		Phase.LEAVING:
			var fade: float = 1.0 - clampf(_phase_time / maxf(leave_time, 0.01), 0.0, 1.0)
			_set_overlay_amount(fade)
			modulate.a = fade
			if fade <= 0.0:
				_phase = Phase.HIDDEN
				visible = false
				modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if _phase != Phase.SHOWN or _phase_time < prompt_delay:
		return
	if event.is_echo():
		return
	if event.is_action_pressed(ACTION_ATTACK) or event.is_action_pressed(ACTION_JUMP) or event.is_action_pressed(ACTION_ACCEPT):
		get_viewport().set_input_as_handled()
		_continue()


func _show_summary() -> void:
	_phase = Phase.SHOWN
	_phase_time = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = true
	_title.modulate.a = 1.0
	_title.scale = Vector2.ONE
	var level: Node = _get_level()
	if level != null and level.has_method(METHOD_GET_RUN_SUMMARY):
		var summary: Dictionary = level.call(METHOD_GET_RUN_SUMMARY)
		var total_seconds: int = int(float(summary.get("time", 0.0)))
		var heading: String = "Reached  LEVEL %d  ·  %s" % [int(summary.get("level", 1)), String(summary.get("section", ""))]
		if kind == Kind.VICTORY:
			var levels: int = int(summary.get("level", 1))
			heading = "All %d level%s cleared" % [levels, "" if levels == 1 else "s"]
		_stats.text = "%s\nEnemies slain  %d     Best rank  %s     Time  %d:%02d" % [
			heading,
			int(summary.get("kills", 0)),
			String(summary.get("best_rank", "-")),
			total_seconds / 60,
			total_seconds % 60,
		]


func _continue() -> void:
	_phase = Phase.LEAVING
	_phase_time = 0.0
	get_tree().paused = false
	Engine.time_scale = 1.0
	_prompt.modulate.a = 0.0
	var level: Node = _get_level()
	if level != null and level.has_method(METHOD_RESTART_RUN):
		level.call(METHOD_RESTART_RUN)
	continued.emit()


func _get_level() -> Node:
	return get_tree().get_first_node_in_group(GROUP_LEVEL_NAVIGATION)


## The level generator joins its group after the HUD is ready, so the victory screen connects late.
func _connect_level() -> void:
	if _connected_level != null and is_instance_valid(_connected_level):
		return
	var level: Node = _get_level()
	if level == null or not level.has_signal(SIGNAL_RUN_WON):
		return
	level.connect(SIGNAL_RUN_WON, _begin)
	_connected_level = level


func _set_overlay_amount(amount: float) -> void:
	_overlay_material.set_shader_parameter(&"amount", clampf(amount, 0.0, 1.0))


func _ease_out(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - (1.0 - clamped) * (1.0 - clamped)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = SCREEN_SHADER_CODE
	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter(&"tint", overlay_tint)
	_overlay_material.set_shader_parameter(&"desaturate", overlay_desaturate)
	_overlay_material.set_shader_parameter(&"tint_strength", overlay_tint_strength)
	_overlay_material.set_shader_parameter(&"darken", overlay_darken)
	_overlay_material.set_shader_parameter(&"vignette_darken", overlay_vignette_darken)
	_overlay.material = _overlay_material
	add_child(_overlay)

	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_title = _make_label(title_text, title_font_size, title_color, 18)
	column.add_child(_title)
	_subtitle = _make_label("", int(text_font_size * 0.9), Color(0.85, 0.8, 0.8), 6)
	column.add_child(_subtitle)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 30.0)
	column.add_child(spacer)
	_stats = _make_label("", text_font_size, Color(1.0, 1.0, 1.0), 6)
	column.add_child(_stats)
	var spacer_2: Control = Control.new()
	spacer_2.custom_minimum_size = Vector2(0.0, 40.0)
	column.add_child(spacer_2)
	_prompt = _make_label(prompt_text, int(text_font_size * 0.85), Color(1.0, 0.85, 0.6), 6)
	column.add_child(_prompt)

	_sting_player = AudioStreamPlayer.new()
	_sting_player.stream = _build_sting()
	_sting_player.volume_db = sting_volume_db
	add_child(_sting_player)


func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override(&"outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.resized.connect(func() -> void: label.pivot_offset = label.size * 0.5)
	return label


func _build_sting() -> AudioStreamWAV:
	if kind == Kind.VICTORY:
		return _build_victory_sting()
	return _build_death_sting()


## A deep impact, then a slow, falling minor tone over a low rumble.
func _build_death_sting() -> AudioStreamWAV:
	var sting: PackedFloat32Array = SoundSynth.thud(1.2, 70.0, 28.0, 3.0, 1.2, 6.0, 0.35, 501)
	sting = SoundSynth.mix(sting, SoundSynth.tone_sweep(1.8, 220.0, 130.0, 0.1, 4.0, 502), 0.35, 0.15)
	sting = SoundSynth.mix(sting, SoundSynth.tone_sweep(1.8, 261.6, 155.6, 0.1, 4.0, 503), 0.25, 0.25)
	sting = SoundSynth.mix(sting, SoundSynth.growl(1.6, 40.0, 0.8, 504), 0.4, 0.05)
	return SoundSynth.make_wav(SoundSynth.normalize(sting))


## A boom, then a rising major arpeggio (C, E, G, high C) that swells into a ringing chord with a
## bright shimmer on top.
func _build_victory_sting() -> AudioStreamWAV:
	var sting: PackedFloat32Array = SoundSynth.thud(0.9, 110.0, 45.0, 5.0, 1.0, 8.0, 0.5, 511)
	var notes: Array[float] = [261.63, 329.63, 392.0, 523.25]
	for index in range(notes.size()):
		var tone: PackedFloat32Array = SoundSynth.tone_sweep(1.9 - 0.12 * float(index), notes[index] * 0.98, notes[index], 0.08, 5.0, 512 + index)
		sting = SoundSynth.mix(sting, tone, 0.3, 0.1 + 0.12 * float(index))
	sting = SoundSynth.mix(sting, SoundSynth.whoosh(1.2, 2000.0, 7000.0, 4000.0, 0.5, 2.2, 520), 0.25, 0.45)
	return SoundSynth.make_wav(SoundSynth.normalize(sting))
