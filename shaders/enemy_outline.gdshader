shader_type canvas_item;
render_mode blend_mix;

// Crveni outline oko alfa siluete (radi i uz scale sprite-a ako su pikseli oštri).
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float thickness_px : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float alpha_inside : hint_range(0.0, 1.0) = 0.5;
uniform float alpha_edge : hint_range(0.0, 1.0) = 0.5;
/// -1.0 = isključeno. Boss shoot: donji deo frejma (tenk baza) providan da vidi sloj nogu.
uniform float leg_cutout_uv_y : hint_range(-1.0, 1.0) = -1.0;

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float sample_cutout_alpha(vec2 uv) {
	vec4 c = texture(TEXTURE, uv);
	float a = c.a;
	if (leg_cutout_uv_y >= 0.0 && uv.y > leg_cutout_uv_y) {
		a = 0.0;
	}
	return a;
}

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * max(thickness_px, 1.0);
	vec4 col = texture(TEXTURE, UV);
	if (leg_cutout_uv_y >= 0.0 && UV.y > leg_cutout_uv_y) {
		col.a = 0.0;
	}
	float a = col.a;

	float n = 0.0;
	n = max(n, sample_cutout_alpha(UV + vec2(ps.x, 0.0)));
	n = max(n, sample_cutout_alpha(UV + vec2(-ps.x, 0.0)));
	n = max(n, sample_cutout_alpha(UV + vec2(0.0, ps.y)));
	n = max(n, sample_cutout_alpha(UV + vec2(0.0, -ps.y)));
	n = max(n, sample_cutout_alpha(UV + vec2(ps.x, ps.y)));
	n = max(n, sample_cutout_alpha(UV + vec2(-ps.x, ps.y)));
	n = max(n, sample_cutout_alpha(UV + vec2(ps.x, -ps.y)));
	n = max(n, sample_cutout_alpha(UV + vec2(-ps.x, -ps.y)));

	if (a <= alpha_inside && n > alpha_edge) {
		COLOR = outline_color * v_modulate;
	} else {
		COLOR = col * v_modulate;
	}
}
