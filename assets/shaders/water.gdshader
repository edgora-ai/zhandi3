shader_type spatial;
render_mode cull_disabled, unshaded;

// 深度渐变水色 + 岸线泡沫环 + 波光 + 顶点波浪（参考 Elemental-Serenity 的水体思路）
uniform sampler2D u_height_map;
uniform float u_water_level = 2.0;
uniform float u_ground_half = 250.0;
uniform vec4 color_shallow : source_color = vec4(0.35, 0.76, 0.76, 1.0);
uniform vec4 color_deep : source_color = vec4(0.05, 0.30, 0.52, 1.0);
uniform vec4 color_foam : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform vec4 color_ice : source_color = vec4(0.76, 0.90, 0.98, 1.0);
uniform float wave_speed = 1.0;
uniform float rain_amount : hint_range(0.0, 1.0) = 0.0;
uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;

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

float terrain_h(vec2 xz) {
	vec2 tuv = (xz + u_ground_half) / (u_ground_half * 2.0);
	return texture(u_height_map, tuv).r;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	// 两组低频行波叠加的涌浪
	float open_water = 1.0 - ice_amount * 0.92;
	VERTEX.y += (sin(wp.x * 0.30 + t * 1.4) * 0.11 + sin(wp.z * 0.24 - t * 1.0 + wp.x * 0.12) * 0.09) * open_water;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = u_water_level - terrain_h(v_world.xz);
	float d = clamp(depth / 3.5, 0.0, 1.0);

	// 基础水色：浅滩绿松石 → 深水蓝
	vec3 col = mix(color_shallow.rgb, color_deep.rgb, sqrt(d));
	// 浅滩压低不透明度：透出沙质河床（旷野之息式的清水），深水保持浓色。
	float alpha = mix(0.42, 0.95, sqrt(d));

	float t = TIME * wave_speed;
	// 表面流动波带：波峰亮、波谷暗，肉眼可见的涌动
	float n1 = vnoise(v_world.xz * 0.35 + vec2(t * 0.30, t * 0.18));
	float n2 = vnoise(v_world.xz * 0.18 - vec2(t * 0.12, t * 0.25));
	float band = sin(v_world.x * 0.9 + v_world.z * 0.6 + (n1 + n2) * 4.0 + t * 1.8);
	col *= 0.90 + (n1 * 0.6 + n2 * 0.4) * 0.14 + band * 0.05;

	// 波光：深水区稀疏的细小闪点
	float n3 = vnoise(v_world.xz * 1.4 + vec2(t * 0.6, -t * 0.4));
	float speck = smoothstep(0.965, 0.995, n3) * smoothstep(0.2, 0.6, d);
	col = mix(col, vec3(1.0), speck * 0.25);

	// 岸线泡沫：贴着水线的窄白边 + 向外扩散的细涟漪环
	float foam_zone = smoothstep(0.55, 0.02, depth);
	float ring_p = fract(depth * 3.0 - t * 0.55 + n1 * 0.4);
	float ring = smoothstep(0.0, 0.10, ring_p) * smoothstep(0.32, 0.10, ring_p);
	float breakup = smoothstep(0.35, 0.65, n2);
	float foam = foam_zone * ring * breakup;
	foam += smoothstep(0.05, 0.0, depth) * 0.7;
	foam = clamp(foam, 0.0, 1.0);
	col = mix(col, color_foam.rgb, foam);
	alpha = max(alpha, foam * 0.95);

	// 雨季水片：世界空间格子生成随机扩散的小圆环，不依赖外部雨滴贴图。
	vec2 rain_uv = v_world.xz * 0.72;
	vec2 rain_cell = floor(rain_uv);
	vec2 rain_local = fract(rain_uv) - 0.5;
	float rain_rand = vhash(rain_cell);
	vec2 rain_center = vec2(vhash(rain_cell + 17.0), vhash(rain_cell + 41.0)) - 0.5;
	float rain_phase = fract(t * 0.85 + rain_rand);
	float rain_dist = length(rain_local - rain_center * 0.55);
	float rain_ring = smoothstep(0.035, 0.0, abs(rain_dist - rain_phase * 0.42));
	rain_ring *= smoothstep(1.0, 0.45, rain_phase) * step(0.52, rain_rand) * rain_amount;
	col = mix(col, color_foam.rgb, rain_ring * 0.85);
	alpha = max(alpha, rain_ring * 0.92);

	// 冬季水片：低频冰层 + 细裂纹，仍保留少量深水颜色。
	float ice_noise = vnoise(v_world.xz * 0.075 + vec2(9.2, 3.7));
	float ice_cells = abs(fract(ice_noise * 5.0 + vnoise(v_world.xz * 0.19)) - 0.5);
	float ice_crack = smoothstep(0.055, 0.012, ice_cells);
	float ice_mask = ice_amount * smoothstep(0.08, 0.65, d + ice_noise * 0.35);
	vec3 ice_col = color_ice.rgb * (0.88 + ice_noise * 0.16) - ice_crack * 0.18;
	col = mix(col, ice_col, ice_mask * 0.88);
	alpha = max(alpha, ice_mask * 0.97);

	ALBEDO = col;
	ALPHA = alpha;
}
