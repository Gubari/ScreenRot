shader_type canvas_item;

/// Samo reže donji deo shoot frejma (bez outline-a).
uniform float leg_cutout_uv_y : hint_range(-1.0, 1.0) = -1.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (leg_cutout_uv_y >= 0.0 && UV.y > leg_cutout_uv_y) {
		c.a = 0.0;
	}
	COLOR = c * v_modulate;
}
