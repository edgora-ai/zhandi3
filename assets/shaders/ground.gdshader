shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;

// Elemental-Serenity 的地表思路：基础生物群落色 + 多尺度斑驳 + 季节统一调色。
uniform vec4 season_tint : source_color = vec4(1.0);
uniform vec4 snow_color : source_color = vec4(0.68, 0.78, 0.86, 1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;
varying vec3 v_world_normal;

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
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float macro_patch = vnoise(v_world.xz * 0.035);
	float fine_patch = vnoise(v_world.xz * 0.18 + vec2(17.3, 4.8));
	vec3 col = COLOR.rgb * season_tint.rgb;
	col *= 0.86 + macro_patch * 0.22 + fine_patch * 0.07;

	// 陡坡增加横向岩层，不改变碰撞形状。
	float steep = smoothstep(0.78, 0.48, v_world_normal.y);
	float strata = 0.5 + 0.5 * sin(v_world.y * 2.6 + macro_patch * 5.0);
	col *= 1.0 - steep * strata * 0.12;

	// 雪优先积在朝上的表面，并用噪声打碎边界。
	float snow_noise = macro_patch * 0.65 + fine_patch * 0.35;
	float snow_mask = snow_amount * smoothstep(0.42, 0.78, v_world_normal.y);
	snow_mask *= smoothstep(0.18, 0.62, snow_noise + snow_amount * 0.35);
	col = mix(col, snow_color.rgb * (0.88 + fine_patch * 0.12), snow_mask);

	col *= 1.0 - wetness * (0.12 + macro_patch * 0.08);
	ALBEDO = col;
	ROUGHNESS = mix(0.96, 0.58, wetness);
	SPECULAR = 0.05 + wetness * 0.16;
}
