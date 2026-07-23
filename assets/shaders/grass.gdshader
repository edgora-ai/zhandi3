shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_opaque;

// 草丛卡片：交叉面片 + 多叶片贴图 + 行进风场 + 三段色带
uniform sampler2D u_blade;
uniform vec4 color_shadow : source_color = vec4(0.16, 0.34, 0.10, 1.0);
uniform vec4 color_dark : source_color = vec4(0.28, 0.55, 0.15, 1.0);
uniform vec4 color_light : source_color = vec4(0.60, 0.85, 0.30, 1.0);
uniform float wind_speed = 1.6;
uniform float wind_strength = 0.20;

varying float v_mask;
varying vec2 v_world;
varying vec2 v_uv;

float vhash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(vhash(i), vhash(i + vec2(1.0, 0.0)), f.x),
			mix(vhash(i + vec2(0.0, 1.0)), vhash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_mask = UV.y;
	v_uv = UV;
	vec3 base = MODEL_MATRIX[3].xyz;
	v_world = base.xz;

	// 行进门风场：两层不同频率/速度的滚动噪声叠加成阵风
	float t = TIME * wind_speed;
	float g1 = vnoise(base.xz * 0.10 + vec2(t * 0.45, t * 0.30));
	float g2 = vnoise(base.xz * 0.028 + vec2(t * 0.22, -t * 0.10));
	float gust = (g1 * 0.6 + g2 * 0.4 - 0.5) * 2.0 * wind_strength;
	float bend = gust * v_mask * v_mask;
	VERTEX.x += bend * 0.35;
	VERTEX.z += bend;
	// 弯曲时叶尖略下压，保持弧线长度感
	VERTEX.y -= abs(bend) * 0.35 * v_mask;
}

void fragment() {
	vec4 tex = texture(u_blade, v_uv);
	if (tex.a < 0.5) {
		discard;
	}
	vec3 c = mix(color_shadow.rgb, color_dark.rgb, smoothstep(0.0, 0.45, v_mask));
	c = mix(c, color_light.rgb, smoothstep(0.45, 1.0, v_mask));
	// 大尺度明暗斑驳，草甸的呼吸感
	float patch = vnoise(v_world * 0.045);
	c *= 0.86 + patch * 0.28;
	// 贴图灰度做叶间明暗
	ALBEDO = c * (0.6 + tex.r * 0.55) * COLOR.rgb;
}
