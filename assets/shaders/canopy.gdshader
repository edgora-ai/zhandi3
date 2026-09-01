shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_alpha_prepass  // FIX: AUD-P0-6 透排修正;

// FIX: OPT-F2/TA3 全局日光系数：树冠随昼夜明暗
global uniform float day_light;

// 树冠叶片卡片：广告牌化 + 叶簇贴图 + 三色 ramp（参考 Elemental-Serenity 的 Bush）
uniform sampler2D u_leaf;
uniform vec3 color_shadow : source_color = vec3(0.16, 0.33, 0.11);
uniform vec3 color_mid : source_color = vec3(0.36, 0.60, 0.20);
uniform vec3 color_high : source_color = vec3(0.70, 0.88, 0.38);
uniform float wind_strength = 0.05;

varying vec2 v_uv;
varying float v_light;

void vertex() {
	v_uv = UV;
	v_light = COLOR.r; // MultiMesh 实例色预计算了卡片朝向主光的亮度
	vec3 base = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	// 风：卡片上缘摆动更明显，整棵树相位错开
	float w = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float n = sin(TIME * 1.7 + base.x * 0.35 + base.z * 0.41)
			+ 0.4 * sin(TIME * 3.1 + base.z * 0.7);
	vec3 wp = base + (right * VERTEX.x + up * VERTEX.y) * scale;
	wp += (right * n * 0.8 + vec3(0.0, n * 0.3, 0.0)) * wind_strength * w;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	vec4 tex = texture(u_leaf, v_uv);
	if (tex.a < 0.5) {
		discard;
	}
	// 按卡片朝向对主光的三色 ramp：背光暗部 → 主色 → 高光
	float t = clamp(v_light, 0.0, 1.0);
	vec3 ramp = t < 0.5
			? mix(color_shadow, color_mid, t * 2.0)
			: mix(color_mid, color_high, (t - 0.5) * 2.0);
	// 贴图灰度做叶间明暗
	ALBEDO = ramp * (0.55 + tex.r * 0.65) * day_light;
}
