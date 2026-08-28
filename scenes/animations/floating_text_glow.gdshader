shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float aspect = 2.0;
uniform vec4 ink_color : source_color = vec4(0.10, 0.14, 0.20, 0.48);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0) * 2.0;
	float half_len = max(aspect - 1.0, 0.0);
	float sd = length(vec2(max(abs(p.x) - half_len, 0.0), p.y)) - 0.72;

	float ink = 1.0 - smoothstep(-0.28, 0.28, sd);
	float breathe = 0.94 + 0.06 * sin(TIME * 1.6);
	COLOR = vec4(ink_color.rgb, ink * ink_color.a * breathe);
}
