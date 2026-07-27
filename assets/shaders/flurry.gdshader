shader_type canvas_item;

// 林克时间屏幕效果：边缘蓝色渐晕，中心保持清晰。
uniform float strength : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.15, 1.0)) * 1.6;
	float vig = smoothstep(0.38, 1.0, d);
	vec3 blue = vec3(0.14, 0.42, 0.85);
	COLOR = vec4(blue, vig * 0.42 * strength);
}
