shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_bottom : source_color = vec4(0.26, 0.46, 0.14, 1.0);
uniform vec4 albedo_top : source_color = vec4(0.62, 0.80, 0.30, 1.0);
uniform float sway_strength = 0.18;
uniform float sway_speed = 2.0;

void vertex() {
	float w = UV.y;
	float phase = MODEL_MATRIX[3].x * 0.35 + MODEL_MATRIX[3].z * 0.41;
	float s = sin(TIME * sway_speed + phase);
	VERTEX.x += s * sway_strength * w;
	VERTEX.z += s * sway_strength * 0.6 * w;
}

void fragment() {
	ALBEDO = mix(albedo_bottom.rgb, albedo_top.rgb, UV.y) * COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
