shader_type canvas_item;
render_mode blend_mul, unshaded;

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.34);
uniform float shadow_size : hint_range(0.0, 64.0, 0.5) = 16.0;
uniform float softness : hint_range(0.0, 32.0, 0.5) = 9.0;
uniform vec2 hex_center = vec2(128.0, 128.0);
uniform float hex_radius = 127.0;

const int SIDES = 6;
const float START_ANGLE_DEG = -90.0;
const float DEG_TO_RAD = 0.01745329252;

// Signed distance to the pointy-top hex. Matches HexStroke._hex_vertices().
float hex_sdf(vec2 p, float radius) {
	float dist = -1e20;
	for (int i = 0; i < SIDES; i++) {
		float ang0 = (START_ANGLE_DEG + float(i) * 60.0) * DEG_TO_RAD;
		float ang1 = (START_ANGLE_DEG + float(i + 1) * 60.0) * DEG_TO_RAD;
		vec2 a = vec2(cos(ang0), sin(ang0)) * radius;
		vec2 b = vec2(cos(ang1), sin(ang1)) * radius;
		vec2 ba = b - a;
		vec2 pa = p - a;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		float segment_dist = length(pa - ba * h);
		float cross = ba.x * pa.y - ba.y * pa.x;
		// Clockwise vertices in y-down space. Inside is to the right of each edge.
		float signed_dist = cross <= 0.0 ? -segment_dist : segment_dist;
		dist = max(dist, signed_dist);
	}
	return dist;
}

void fragment() {
	vec2 pixel = UV * TEXTURE_PIXEL_SIZE;
	vec2 local = pixel - hex_center;
	float d = hex_sdf(local, hex_radius);

	if (d > 0.0) {
		discard;
	}

	float shade = smoothstep(-shadow_size, -softness, d);
	float darken = 1.0 - shadow_color.a * shade;
	COLOR = vec4(vec3(darken), 1.0);
}
