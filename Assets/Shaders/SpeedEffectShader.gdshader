shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float speed_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);

uniform vec4 line_color : source_color = vec4(0.76, 0.92, 1.0, 0.72);
uniform float line_count : hint_range(8.0, 180.0) = 72.0;
uniform float line_width : hint_range(0.001, 0.08) = 0.018;
uniform float line_scroll_speed : hint_range(0.0, 18.0) = 5.2;
uniform float line_cutoff : hint_range(0.0, 1.0) = 0.54;
uniform float center_radius : hint_range(0.0, 1.0) = 0.28;
uniform float outer_fade_start : hint_range(0.0, 1.0) = 0.50;

uniform float blur_radius : hint_range(0.0, 1.0) = 0.18;
uniform float blur_amount : hint_range(0.0, 5.0) = 1.25;
uniform float blur_inner : hint_range(0.0, 1.0) = 0.58;
uniform float blur_outer : hint_range(0.0, 1.0) = 0.78;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec3 vignette_tint = vec3(0.72, 0.86, 1.0);

const float TAU_VALUE = 6.28318530718;


float hash_1d(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}


float get_speed_line_mask(vec2 uv, float strength) {
	vec2 offset = uv - center;
	float radius = length(offset);
	if (radius <= center_radius) {
		return 0.0;
	}

	float angle = atan(offset.y, offset.x);
	float angle_ratio = (angle + 3.14159265359) / TAU_VALUE;
	float line_cell = floor(angle_ratio * line_count);
	float line_local = fract(angle_ratio * line_count);
	float line_noise = hash_1d(line_cell + floor(TIME * line_scroll_speed));
	float line_visible = step(line_cutoff, line_noise);
	float line_core = 1.0 - smoothstep(line_width, line_width * 2.8, abs(line_local - 0.5));

	float radial_flow = fract((radius * 4.4) - (TIME * line_scroll_speed) + line_noise);
	float radial_tail = smoothstep(0.0, 0.22, radial_flow) * (1.0 - smoothstep(0.22, 1.0, radial_flow));
	float center_fade = smoothstep(center_radius, center_radius + 0.20, radius);
	float outer_fade = smoothstep(outer_fade_start, 0.98, radius);
	return line_visible * line_core * radial_tail * center_fade * outer_fade * strength;
}


void fragment() {
	float strength = clamp(speed_strength, 0.0, 1.0);
	vec4 original_color = texture(screen_texture, SCREEN_UV);
	vec4 blurred_color = textureLod(screen_texture, SCREEN_UV, blur_amount * strength);

	float distance_from_center = length(UV - center);
	float blur_mask = smoothstep(blur_inner - blur_radius, blur_outer, distance_from_center) * strength;
	vec3 final_color = mix(original_color.rgb, blurred_color.rgb, blur_mask);

	float speed_lines = get_speed_line_mask(UV, strength);
	final_color += line_color.rgb * speed_lines * line_color.a;

	float vignette_mask = smoothstep(blur_inner, blur_outer, distance_from_center) * vignette_strength * strength;
	final_color = mix(final_color, final_color * vignette_tint, vignette_mask);

	COLOR = vec4(final_color, original_color.a);
}
