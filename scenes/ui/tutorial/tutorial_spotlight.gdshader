shader_type canvas_item;

// Dims the screen except for up to four rounded-rect holes, each ringed by a pulsing outline.

const int MAX_HOLES = 4;

// xy = top-left, zw = size, in the overlay's pixel space.
uniform vec4 holes[MAX_HOLES];
uniform int hole_count = 0;
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform float dim_alpha : hint_range(0.0, 1.0) = 0.62;
uniform float corner_radius = 14.0;
uniform float feather = 5.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
uniform float outline_width = 3.0;

float sd_round_rect(vec2 p, vec2 center, vec2 half_size, float radius) {
	float r = min(radius, min(half_size.x, half_size.y));
	vec2 q = abs(p - center) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	float d = 1e6;
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) {
			break;
		}
		vec4 hole = holes[i];
		d = min(d, sd_round_rect(p, hole.xy + hole.zw * 0.5, hole.zw * 0.5, corner_radius));
	}
	float dim = dim_alpha * smoothstep(0.0, feather, d);
	float ring = 1.0 - smoothstep(outline_width * 0.5, outline_width * 0.5 + 1.5, abs(d - outline_width * 0.5));
	ring *= step(0.5, float(hole_count));
	float pulse = 0.6 + 0.4 * sin(TIME * 4.0);
	vec4 color = vec4(0.0, 0.0, 0.0, dim);
	COLOR = mix(color, vec4(outline_color.rgb, 1.0), ring * outline_color.a * pulse);
}
