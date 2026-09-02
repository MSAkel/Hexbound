shader_type canvas_item;
render_mode blend_mix, unshaded;

// Kenney smoke and slash sprites store density in RGB on a black field.
// Use luminance as alpha and keep the puff white so mix-blend cannot go muddy.
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = max(tex.r, max(tex.g, tex.b));
	COLOR = vec4(1.0, 1.0, 1.0, COLOR.a * mask);
}
