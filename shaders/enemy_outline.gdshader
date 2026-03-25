shader_type canvas_item;
render_mode blend_mix;

// Crveni outline oko alfa siluete (radi i uz scale sprite-a ako su pikseli oštri).
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float thickness_px : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float alpha_inside : hint_range(0.0, 1.0) = 0.5;
uniform float alpha_edge : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * max(thickness_px, 1.0);
	vec4 col = texture(TEXTURE, UV);
	float a = col.a;

	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(ps.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(ps.x, ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a);
	n = max(n, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a);

	// Spoljašnji prsten: ovde je alfa mala, ali u susedstvu ima sprite-a.
	if (a <= alpha_inside && n > alpha_edge) {
		COLOR = outline_color;
	} else {
		COLOR = col;
	}
}
