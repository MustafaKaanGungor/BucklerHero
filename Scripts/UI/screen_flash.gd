extends ColorRect

## Brief coloured glow around the screen edges when the player heals or takes damage.
## One node per kind of flash (see trigger); ui.tscn has HealFlash (green) and DamageFlash (red).
## Full-screen, ignores the mouse, and draws nothing while idle. Bigger amounts flash brighter.

enum Trigger {
	## HealthManager.healed
	HEAL,
	## HealthManager.damaged (hits the shield blocked don't count)
	DAMAGE,
}

const VIGNETTE_SHADER_CODE: String = """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(0.25, 1.0, 0.45, 1.0);
uniform float strength = 0.0;
uniform float inner_radius = 0.25;
uniform float outer_radius = 0.85;
uniform float center_fill = 0.15;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float edge = smoothstep(inner_radius, outer_radius, length(centered) * 1.2);
	COLOR = vec4(flash_color.rgb, strength * mix(center_fill, 1.0, edge));
}
"""

@export_group("Flash")
## Which HealthManager signal makes this node flash.
@export var trigger: Trigger = Trigger.HEAL
## Glow colour.
@export var flash_color: Color = Color(0.25, 1.0, 0.45)
## Opacity at the screen edges for an amount of amount_for_full_flash or more.
@export_range(0.0, 1.0) var max_strength: float = 0.55
## Heal or damage amount that gives the full flash; smaller amounts flash less (but at least min_strength).
@export var amount_for_full_flash: float = 35.0
## Weakest flash for any amount.
@export_range(0.0, 1.0) var min_strength: float = 0.25
## Share of the screen centre that is tinted too (0 = edges only).
@export_range(0.0, 1.0) var center_fill: float = 0.15
## Seconds the glow takes to fade out.
@export var fade_time: float = 0.55

var _strength: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var shader: Shader = Shader.new()
	shader.code = VIGNETTE_SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"flash_color", flash_color)
	_material.set_shader_parameter(&"center_fill", center_fill)
	material = _material
	visible = false
	match trigger:
		Trigger.HEAL:
			HealthManager.healed.connect(_on_amount)
		Trigger.DAMAGE:
			HealthManager.damaged.connect(_on_amount)


func flash(amount_ratio: float) -> void:
	_strength = maxf(_strength, clampf(amount_ratio, min_strength, 1.0))
	visible = true


func _on_amount(amount: float) -> void:
	flash(amount / maxf(amount_for_full_flash, 0.001))


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return
	_strength = maxf(_strength - delta / maxf(fade_time, 0.01), 0.0)
	# Ease out so the glow pops in bright and lingers softly.
	_material.set_shader_parameter(&"strength", max_strength * _strength * _strength)
	if _strength <= 0.0:
		visible = false
