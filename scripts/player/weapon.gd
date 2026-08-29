class_name Weapon
extends Node3D
## 武器逻辑：hitscan 射击、扩散、后座、换弹、机瞄；玩家有视模型，bot 仅逻辑

signal ammo_changed(mag: int, reserve: int)
signal fired
signal reload_started
signal hit_landed(part: String) # // FIX: D4/CB17 命中带部位，供爆头 hitmarker
signal weapon_changed(id: String) # // FIX: VIS1 武器名事件驱动：--screenshot 等每帧早退场景也能同步标签

const WEAPONS := {
	"rifle": {
		"label": "突击步枪", "damage": 12.0, "head_mult": 2.0, "rpm": 540.0,
		"mag": 30, "start_reserve": 90, "spread": 1.3, "ads_spread": 0.45,
		"reload": 1.8, "auto": true, "zoom": 1.3, "range": 220.0, "recoil": 0.35,
		"falloff_start": 120.0, "falloff_end": 220.0, "falloff_min": 0.75, # // FIX: OPT-C1 距离衰减
	},
	"dmr": {
		"label": "射手步枪", "damage": 35.0, # // FIX: R4-13 34×2 三发对 75甲+100血差 0.4 不死的悬崖 "head_mult": 2.2, "rpm": 150.0,
		"mag": 12, "start_reserve": 36, "spread": 0.8, "ads_spread": 0.12,
		"reload": 2.1, "auto": false, "zoom": 2.4, "range": 350.0, "recoil": 1.2,
		"falloff_start": 250.0, "falloff_end": 350.0, "falloff_min": 0.85, # // FIX: OPT-C1
	},
	"smg": {
		# // FIX: R2-B4 裸 DPS 120→96（原 SMG ≤60m 全域最快，步枪生态位数学不成立——复审 TTK 矩阵结论）
		"label": "冲锋枪", "damage": 8.0, "head_mult": 1.8, "rpm": 800.0,
		"mag": 36, "start_reserve": 108, "spread": 2.0, "ads_spread": 1.0,
		"reload": 1.5, "auto": true, "zoom": 1.15, "range": 130.0, "recoil": 0.2,
		"falloff_start": 60.0, "falloff_end": 130.0, "falloff_min": 0.40, # // FIX: OPT-C1 近战段武器远距惩罚
	},
	"shotgun": {
		# // FIX: R4-W1 武器库扩容：霰弹枪（12m 内一枪位，25m 后急剧衰减）——补近战霸主生态位
		"label": "霰弹枪", "damage": 8.0, "head_mult": 1.5, "rpm": 75.0,
		"mag": 6, "start_reserve": 24, "spread": 4.5, "ads_spread": 3.0,
		"reload": 2.4, "auto": false, "zoom": 1.1, "range": 40.0, "recoil": 1.6,
		"pellets": 7, "falloff_start": 10.0, "falloff_end": 25.0, "falloff_min": 0.25,
	},
	"lmg": {
		# // FIX: R4-W2 轻机枪（60 弹压制位，换弹惩罚重）
		"label": "轻机枪", "damage": 11.0, "head_mult": 1.6, "rpm": 480.0,
		"mag": 60, "start_reserve": 120, "spread": 2.2, "ads_spread": 0.9,
		"reload": 3.6, "auto": true, "zoom": 1.2, "range": 200.0, "recoil": 0.5,
		"falloff_start": 110.0, "falloff_end": 200.0, "falloff_min": 0.7,
	},
	"bow": {
		"label": "猎弓", "damage": 0.0, "head_mult": 1.0, "rpm": 60.0,
		"mag": 1, "start_reserve": 24, "spread": 0.0, "ads_spread": 0.0,
		"reload": 0.5, "auto": false, "zoom": 1.35, "range": 0.0, "recoil": 0.0,
	},
}

@export var base_fov := 75.0 # // FIX: M13 @export 可调—FOV可在编辑器实时调参；WEAPONS平衡表集中可调详见下
const GUNMETAL := Color(0.15, 0.16, 0.18) # // FIX: M13 武器数值WEAPONS集中表为关卡平衡可调源，策划可不改代码调参（reserve/mag/damage/spread等）
var BASE_FOV := 75.0 # // FIX: R4-U1 设置面板可调 FOV（原 const）

var owner_body: CharacterBody3D
var is_player := false
var weapon_id := ""
var data := {}
var mag_left := 0
var reserve := 0
var last_shot_msec := 0   # NPC 受惊反应：记录最近一次开火时间
var is_ads := false
var reloading := false

var viewmodel: Node3D
var muzzle: Node3D
var _flash: OmniLight3D
var _cool := 0.0
var _reload_left := 0.0
var _kick := 0.0
var _bob_t := 0.0
var _bloom := 0.0 # // FIX: OPT-C2 连射 bloom（度），每发 +0.15 上限 1.2，停火回落
var _forced_dir := Vector3.ZERO # // FIX: R4-11 压制弹强制方向


func setup(p_owner: CharacterBody3D, p_is_player: bool) -> void:
	owner_body = p_owner
	is_player = p_is_player


func set_weapon(id: String, p_mag: int = -1, p_reserve: int = -1) -> void:
	weapon_id = id
	# 猎弓使用玩家侧的弓模型，先清掉上一把枪的视模型。
	if viewmodel and (id == "" or id == "bow"):
		viewmodel.queue_free()
		viewmodel = null
		muzzle = null
		_flash = null
	if id == "":
		data = {}
		mag_left = 0
		reserve = 0
		ammo_changed.emit(0, 0)
		return
	data = WEAPONS[id]
	mag_left = p_mag if p_mag >= 0 else data.mag
	reserve = p_reserve if p_reserve >= 0 else data.start_reserve
	reloading = false
	_cool = 0.0
	if is_player and id != "bow":
		_build_viewmodel()
	ammo_changed.emit(mag_left, reserve)
	weapon_changed.emit(id)


func label() -> String:
	return data.get("label", "波克剑")


func hold_trigger() -> void:
	if not data.get("auto", false):
		return
	_try_fire()


func pull_trigger() -> void:
	_try_fire()


# // FIX: R4-11 bot 压制弹：朝指定方向强制一发（带额外散布）
func pull_trigger_dir(dir: Vector3) -> void:
	if weapon_id == "" or reloading or _cool > 0.0 or mag_left <= 0:
		return
	_cool = 60.0 / data.rpm
	mag_left -= 1
	_forced_dir = dir
	_fire_ray()
	_forced_dir = Vector3.ZERO
	last_shot_msec = Time.get_ticks_msec()
	FX.muzzle_flash(muzzle_world())
	fired.emit()


func start_reload() -> void:
	if reloading or weapon_id == "" or mag_left >= data.mag or reserve <= 0:
		return
	reloading = true
	_reload_left = data.reload
	# // FIX: FX1 换弹开始音（拔匣），与 reload 时长对齐由 _process 完成音收尾
	if is_player:
		var sfx := owner_body.get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.play("reload_start", -6.0)
	reload_started.emit()


func set_ads(on: bool) -> void:
	is_ads = on and weapon_id != "" and is_player


func current_spread() -> float:
	if weapon_id == "":
		return 0.0
	var s: float = data.ads_spread if is_ads else data.spread
	if owner_body.get("prone") == true:
		s *= 0.65
	var speed := Vector3(owner_body.velocity.x, 0, owner_body.velocity.z).length()
	s *= 1.0 + speed * 0.09
	if not owner_body.is_on_floor():
		s *= 1.8
	return s


func _try_fire() -> void:
	if weapon_id == "" or reloading or _cool > 0.0:
		return
	if not data.has("rpm"):
		print("[weapon] BUG data keys=%s id='%s' is_player=%s" % [str(data.keys()), weapon_id, str(is_player)])
		if data.is_empty():
			weapon_id = ""
			return
		data = WEAPONS[weapon_id] # 自愈：重挂正确数值表
	if mag_left <= 0:
		if is_player:
			start_reload()
		return
	_cool = 60.0 / data.rpm
	mag_left -= 1
	# // FIX: OPT-C2 bloom 累积（机瞄减半），停火在 _process 回落
	_bloom = minf(_bloom + 0.15, 1.2)
	# // FIX: R4-W1 霰弹枪多弹丸（每颗独立散布射线，共享 bloom 一份）
	for _pellet in range(int(data.get("pellets", 1))):
		_fire_ray()
	last_shot_msec = Time.get_ticks_msec()
	_kick = 0.06
	# // FIX: D2/FX3 玩家与 bot 统一枪口焰火舌面片（共享资源，bot 中距可读）
	FX.muzzle_flash(muzzle_world())
	if is_player:
		owner_body.add_recoil(data.recoil * (0.6 if is_ads else 1.0))
		if _flash:
			_flash.light_energy = 3.0
	ammo_changed.emit(mag_left, reserve)
	fired.emit()


func _fire_ray() -> void:
	var origin: Vector3
	var dir: Vector3
	if is_player:
		var cam: Camera3D = owner_body.camera
		origin = cam.global_position
		dir = -cam.global_transform.basis.z
	else:
		origin = owner_body.get_aim_origin()
		dir = owner_body.get_aim_dir()
	# // FIX: OPT-C2 视角系圆锥采样（原世界轴加噪在俯射/沿轴瞄准时散布塌缩）
	var s := deg_to_rad(current_spread() + _bloom * (0.5 if is_ads else 1.0))
	if _forced_dir != Vector3.ZERO:
		dir = _forced_dir
		s += deg_to_rad(4.0) # 压制弹额外散布
	var up_ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right := dir.cross(up_ref).normalized()
	var upv := right.cross(dir).normalized()
	dir = (dir + right * randf_range(-s, s) + upv * randf_range(-s, s)).normalized()

	var mask := 1 | 4 if is_player else 1 | 2 | 4
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * data.range, mask, [owner_body.get_rid()])
	var result := owner_body.get_world_3d().direct_space_state.intersect_ray(query)

	var end_point: Vector3
	if result.is_empty():
		end_point = origin + dir * data.range
	else:
		end_point = result.position
		var col: Object = result.collider
		if col.has_method("take_damage"):
			var part := "body"
			if col.has_method("get_hit_part"):
				part = col.get_hit_part(result.shape)
			var dmg: float = data.damage * owner_body.damage_mult
			if part == "head":
				dmg *= data.head_mult
			# // FIX: OPT-C1 距离衰减（falloff_start→end 线性至 falloff_min）
			var fs: float = data.get("falloff_start", 0.0)
			var fe: float = data.get("falloff_end", 0.0)
			var hit_dist := origin.distance_to(end_point)
			if fs > 0.0 and fe > fs:
				dmg *= lerpf(1.0, data.get("falloff_min", 1.0), clampf((hit_dist - fs) / (fe - fs), 0.0, 1.0))
			# // FIX: OPT-C3/CB19 SMG 近战段补偿：12m 内 ×1.3（近距生态位）
			if weapon_id == "smg" and hit_dist < 12.0:
				dmg *= 1.3
			# // FIX: OPT-B1 时停目标伤害减免 50%，防冻结期白打
			var st: Variant = owner_body.get("_stasis_target")
			if st != null and col == st:
				dmg *= 0.5
			col.take_damage(dmg, owner_body, part)
			if owner_body.get("damage_dealt") != null:
				owner_body.damage_dealt += dmg # // FIX: OPT-H3 结算伤害统计
			# // FIX: D5/FX8 材质区分命中：木材屑/金属火花/泥土/生物血雾，静态物留弹孔
			if col.has_method("is_plant"):
				FX.impact(end_point, Color(0.55, 0.38, 0.18))
			elif col is CharacterBody3D:
				FX.blood(end_point)
			elif col is Guardian or col.has_method("is_metal") or col.is_in_group("metal_prop"): # // FIX: R2-C2e
				FX.impact(end_point, Color(1.0, 0.85, 0.35))
			else:
				FX.impact(end_point, Color(0.62, 0.58, 0.48))
				FX.decal(end_point, result.normal)
			if is_player:
				hit_landed.emit(part)
		else:
			FX.impact(end_point)
	# // FIX: D6/FX9 曳光差异化：DMR 更宽更亮，其余默认
	if weapon_id == "dmr":
		FX.tracer(muzzle_world(), end_point, Color(1.0, 0.96, 0.62), 0.05)
	else:
		FX.tracer(muzzle_world(), end_point, Color(1.0, 0.88, 0.45), 0.025)


func muzzle_world() -> Vector3:
	if is_player and muzzle:
		return muzzle.global_position
	return owner_body.get_aim_origin() + owner_body.get_aim_dir() * 0.6


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	# // FIX: OPT-C2 bloom 停火回落（约 0.3s 归零）
	_bloom = maxf(0.0, _bloom - delta * 4.0)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			var need: int = data.mag - mag_left
			var take: int = mini(need, reserve)
			mag_left += take
			reserve -= take
			# // FIX: FX1 换弹完成音（上膛 click）
			if is_player:
				var sfx := owner_body.get_tree().get_first_node_in_group("sfx_bank")
				if sfx:
					sfx.play("reload_end", -6.0)
			ammo_changed.emit(mag_left, reserve)
	if _flash and _flash.light_energy > 0.0:
		_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 24.0)
	if not is_player or viewmodel == null:
		return
	# 机瞄 / 腰射切换
	var cam: Camera3D = owner_body.camera
	var target_fov: float = BASE_FOV / (data.get("zoom", 1.0) if is_ads else 1.0)
	cam.fov = lerpf(cam.fov, target_fov, delta * 12.0)
	# // FIX: TA8/D7 视模型 ADS 反缩放：cam.fov 除以 zoom 会让枪模同比放大，按 1/zoom 缩小补偿
	var ads_comp: float = 1.0 / (data.get("zoom", 1.0) if is_ads else 1.0)
	viewmodel.scale = viewmodel.scale.lerp(Vector3.ONE * ads_comp, delta * 12.0)
	var target_pos := Vector3(0.0, -0.155, -0.35) if is_ads else Vector3(0.27, -0.23, -0.5)
	# 后座回弹
	_kick = maxf(0.0, _kick - delta * 0.5)
	target_pos.z += _kick
	# // FIX: FX1 换弹视模型动画：枪体下沉 15° 再回位
	if reloading:
		viewmodel.rotation.x = lerpf(viewmodel.rotation.x, -0.26, delta * 10.0)
	else:
		viewmodel.rotation.x = lerpf(viewmodel.rotation.x, 0.0, delta * 10.0)
	# 移动摆动
	var h_speed := Vector3(owner_body.velocity.x, 0, owner_body.velocity.z).length()
	if owner_body.is_on_floor() and h_speed > 0.5 and not is_ads:
		_bob_t += delta * h_speed * 1.6
		target_pos.y += sin(_bob_t * 2.0) * 0.008
		target_pos.x += cos(_bob_t) * 0.006
	viewmodel.position = viewmodel.position.lerp(target_pos, delta * 14.0)


# ---------- 第一人称视模型（程序化拼装） ----------

func _build_viewmodel() -> void:
	if viewmodel:
		viewmodel.queue_free()
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	add_child(viewmodel)
	viewmodel.position = Vector3(0.27, -0.23, -0.5)

	var gun := Node3D.new()
	viewmodel.add_child(gun)
	var metal := Toon.make_material(GUNMETAL, true, 0.004)
	var accent_color: Color = {"rifle": Color(0.35, 0.42, 0.28), "dmr": Color(0.55, 0.42, 0.28), "smg": Color(0.25, 0.30, 0.40), "shotgun": Color(0.55, 0.38, 0.16), "lmg": Color(0.30, 0.34, 0.30)}[weapon_id]
	var accent := Toon.make_material(accent_color, true, 0.004)

	var recv := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.07, 0.10, 0.40)
	recv.mesh = rb
	recv.material_override = metal
	gun.add_child(recv)

	var barrel := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.016
	bc.bottom_radius = 0.016
	bc.height = 0.30 if weapon_id != "smg" else 0.18
	bc.radial_segments = 6
	barrel.mesh = bc
	barrel.material_override = metal
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0, 0.015, -0.30)
	gun.add_child(barrel)

	var mag := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.05, 0.13, 0.07)
	mag.mesh = mb
	mag.material_override = accent
	mag.position = Vector3(0, -0.09, -0.03)
	mag.rotation_degrees.x = 12.0
	gun.add_child(mag)

	var stock := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.055, 0.085, 0.15)
	stock.mesh = sb
	stock.material_override = accent
	stock.position = Vector3(0, -0.01, 0.24)
	gun.add_child(stock)

	var sight := MeshInstance3D.new()
	var kb := BoxMesh.new()
	kb.size = Vector3(0.03, 0.035, 0.06)
	sight.mesh = kb
	sight.material_override = metal
	sight.position = Vector3(0, 0.065, -0.05)
	gun.add_child(sight)

	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.015, -0.48)
	gun.add_child(muzzle)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.78, 0.4)
	_flash.light_energy = 0.0
	_flash.omni_range = 5.0
	_flash.omni_attenuation = 2.0
	muzzle.add_child(_flash)

	# 程序化手部：右手握把、左手托护木，袖口按武器配色
	# // FIX: VIS2/D7 手臂胶囊缩小下移：默认视角不再有巨大胶囊体伸入画面底部
	var skin := Toon.make_material(Color(0.87, 0.70, 0.55), true, 0.003)
	var sleeve := Toon.make_material(accent_color.darkened(0.15), true, 0.003)
	var hand_r := MeshInstance3D.new()
	var hr := SphereMesh.new()
	hr.radius = 0.045
	hr.height = 0.08
	hr.radial_segments = 8
	hr.rings = 4
	hand_r.mesh = hr
	hand_r.material_override = skin
	hand_r.scale = Vector3(0.9, 1.1, 1.3)
	hand_r.position = Vector3(0.005, -0.075, 0.10)
	gun.add_child(hand_r)
	var arm_r := MeshInstance3D.new()
	var ar := CapsuleMesh.new()
	ar.radius = 0.030
	ar.height = 0.24
	ar.radial_segments = 6
	arm_r.mesh = ar
	arm_r.material_override = sleeve
	arm_r.rotation_degrees = Vector3(-38.0, 0.0, -12.0)
	arm_r.position = Vector3(0.06, -0.28, 0.30)
	gun.add_child(arm_r)
	var hand_l := MeshInstance3D.new()
	var hl := SphereMesh.new()
	hl.radius = 0.042
	hl.height = 0.075
	hl.radial_segments = 8
	hl.rings = 4
	hand_l.mesh = hl
	hand_l.material_override = skin
	hand_l.scale = Vector3(1.0, 0.9, 1.2)
	hand_l.position = Vector3(-0.01, -0.035, -0.19)
	gun.add_child(hand_l)
	var arm_l := MeshInstance3D.new()
	var al := CapsuleMesh.new()
	al.radius = 0.030
	al.height = 0.24
	al.radial_segments = 6
	arm_l.mesh = al
	arm_l.material_override = sleeve
	arm_l.rotation_degrees = Vector3(-52.0, 22.0, 14.0)
	arm_l.position = Vector3(-0.13, -0.25, 0.02)
	gun.add_child(arm_l)
