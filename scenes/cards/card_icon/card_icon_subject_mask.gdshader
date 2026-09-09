shader_type canvas_item;

// Same UV layout as the Hex shelf behind this icon. Alpha zeroes outside the hex silhouette.
uniform sampler2D hex_mask : filter_nearest, repeat_disable;

void fragment() {
	vec4 subject := texture(TEXTURE, UV);
	float mask_a := texture(hex_mask, UV).a;
	COLOR = vec4(subject.rgb, subject.a * mask_a);
}
