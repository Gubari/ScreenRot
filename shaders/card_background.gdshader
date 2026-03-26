shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(0.3, 0.3, 0.4, 0.6);
uniform vec4 fill_color : source_color = vec4(0.05, 0.05, 0.1, 0.7);
uniform float border_width : hint_range(0.0, 0.05) = 0.015;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;
uniform float time_speed : hint_range(0.0, 5.0) = 0.8;

void fragment() {
	vec2 uv = UV;

	// Base fill
	vec4 col = fill_color;

	// Border
	float border = step(uv.x, border_width) + step(1.0 - border_width, uv.x)
				 + step(uv.y, border_width) + step(1.0 - border_width, uv.y);
	border = clamp(border, 0.0, 1.0);
	col = mix(col, border_color, border);

	// Subtle edge glow that pulses
	float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float glow = smoothstep(0.0, 0.15, edge_dist);
	float pulse = 0.8 + 0.2 * sin(TIME * time_speed);
	col.rgb += border_color.rgb * (1.0 - glow) * glow_intensity * pulse;

	// CRT scanlines
	float scanline = sin(uv.y * 400.0) * 0.5 + 0.5;
	col.rgb -= scanline * scanline_strength;

	COLOR = col;
}
