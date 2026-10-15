shader_type canvas_item;

// Crops the painted interior of a hex background into a rounded square with a dark rim.
// Lets the staff token keep its hex art on the square board. Expects a square TextureRect in scale mode.

// Half size of the square cut from the texture, in texture UV. Fits inside the 221x253 hex rim.
uniform vec2 crop_half = vec2(0.31, 0.27);
// Token half side in control UV. Matches CardIcon.TOKEN_HALF_RATIO on the board tile.
uniform float half_extent = 0.442;
uniform float corner_radius = 0.085;
uniform float border_width = 0.035;
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 centered = UV - 0.5;
	vec2 q = abs(centered) - vec2(half_extent - corner_radius);
	float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius;
	float aa = fwidth(dist);

	vec4 color = texture(TEXTURE, vec2(0.5) + centered / half_extent * crop_half);
	color.a = 1.0;
	color = mix(color, border_color, smoothstep(-border_width - aa, -border_width, dist));
	color.a *= 1.0 - smoothstep(-aa, 0.0, dist);
	COLOR = color * tint;
}
