shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never, blend_mix;

// W2 zone wall: subtle energy wall with vertical stripes, upward scan and ground emphasis, top-faded.
uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.34, 1.0);
uniform float scroll_speed = 0.45;

void fragment() {
	float stripes = sin(UV.x * 96.0) * 0.5 + 0.5;
	float scroll = fract(UV.y * 5.0 + TIME * scroll_speed);
	float scan = smoothstep(0.0, 0.12, scroll) * (1.0 - smoothstep(0.12, 0.38, scroll));
	float ground_glow = 1.0 - smoothstep(0.0, 0.55, UV.y);
	float top_fade = 1.0 - smoothstep(0.68, 1.0, UV.y);
	float a = 0.07 + stripes * 0.015 + scan * 0.06 + ground_glow * 0.08;
	a *= top_fade;
	vec3 col = tint.rgb * (0.9 + scan * 0.25 + ground_glow * 0.15);
	ALBEDO = col;
	EMISSION = tint.rgb * (0.08 + scan * 0.22 + ground_glow * 0.10) * top_fade;
	ALPHA = clamp(a, 0.0, 1.0);
}
