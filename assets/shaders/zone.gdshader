shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never, fog_disabled;

// 缩圈结界：竖向能量纹 + 向上滚动的扫描线 + 近地增亮，远处也清晰可见。
// FIX: OPT-H1/VIS4 危险配色：蓝→红橙渐变（底部更浓的墙裙），读作"危险边界"而非镜头瑕疵
uniform vec4 tint : source_color = vec4(1.0, 0.42, 0.18, 1.0);
uniform float scroll_speed = 0.45;

void fragment() {
	float stripes = sin(UV.x * 96.0) * 0.5 + 0.5;
	float scroll = fract(UV.y * 5.0 + TIME * scroll_speed);
	float scan = smoothstep(0.0, 0.12, scroll) * smoothstep(0.38, 0.12, scroll);
	float ground_glow = smoothstep(0.55, 0.0, UV.y);
	float a = 0.14 + stripes * 0.06 + scan * 0.20 + ground_glow * 0.22;
	vec3 col = tint.rgb * (0.9 + scan * 0.9 + ground_glow * 0.4);
	ALBEDO = col;
	EMISSION = tint.rgb * (0.25 + scan * 0.8 + ground_glow * 0.3);
	ALPHA = clamp(a, 0.0, 1.0);
}
