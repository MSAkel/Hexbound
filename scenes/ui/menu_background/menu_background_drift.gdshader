shader_type canvas_item;

// UV drift avoids moving Controls, which snap to pixels and jitter on UI canvases.
uniform float motion_time = 0.0;
uniform float zoom = 1.12;
uniform vec2 pan_radius = vec2(0.025, 0.033);
uniform float pan_speed = 0.22;

void fragment() {
	vec2 pan = pan_radius * vec2(
		cos(motion_time * pan_speed),
		sin(motion_time * pan_speed)
	);
	vec2 uv = (UV - 0.5) / zoom + 0.5 + pan;
	COLOR = texture(TEXTURE, uv);
}
