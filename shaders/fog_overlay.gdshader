shader_type canvas_item;

uniform vec4 fog_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;
uniform float noise_speed : hint_range(0.0, 2.0) = 0.2;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;

// Simple noise function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// Value noise
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    // Four corners in 2D of a tile
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    // Smooth interpolation
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a)* u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    // Get the base texture color
    vec4 color = texture(TEXTURE, UV);
    
    // Create animated noise
    vec2 noise_uv = UV * noise_scale;
    noise_uv.y += TIME * noise_speed;
    float noise_value = noise(noise_uv);
    
    // Mix the fog color with the noise
    vec4 fog = mix(fog_color, fog_color * (1.0 + noise_value * noise_strength), 0.5);
    
    // Only apply fog where the texture is visible
    if (color.a > 0.0) {
        COLOR = fog;
    } else {
        COLOR = vec4(0.0);
    }
} 