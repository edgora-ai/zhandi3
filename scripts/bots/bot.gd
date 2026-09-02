class_name Bot
extends CharacterBody3D
const SOLDIER_GLB = preload("res://assets/models/soldier.glb")  # // FIX: AUD-P0-4 preload
## AI 战士：空降 → 搜刮 → 跑圈/占点 → 交战。贴地移动 + 简单避障，无限后备弹药

signal died(victim, killer)

enum State { DROP, LOOT, ROTATE, FIGHT, CAPTURE }

@export var MAX_HP := 100.0 # // FIX: M13 魔法数抽离
@export var WALK := 4.2 # // FIX: M13
@export var RUN := 6.4 # // FIX: M13
const GRAVITY := 22.0
@export var SIGHT_RANGE := 65.0 # // FIX: M13/M14 LOD距离分级
@export var FIGHT_DIST := 20.0 # // FIX: M13

var hp := MAX_HP
var armor := 0.0
var alive := true
var damage_mult := 1.0
var regen_rate := 0.0
var display_name := "Bot"
var kills := 0
var skill := 1.0               # 越大越准（1.0=基准，>1 更准）；散布用 1.8*(1.5-skill) 方向已修正
var zone: Zone
var terrain: Terrain

var state := State.DROP
var weapon: Weapon
var move_target := Vector3.ZERO
var aim_target: CharacterBody3D = null
var target_loot: Loot = null
var _loot_time := 0.0
# // FIX: OPT-A2 拾取失败带时间戳，12s 冷却后允许重试（原注释占位无实现）
var _loot_failed_at: Dictionary = {}   # 存到期时刻（now+冷却）
var _loot_fail_counts: Dictionary = {} # // FIX: OPT-A2 强化：指数退避防"不可达物资无限重试"
# // FIX: OPT-A3 受击警觉期：转向但不开火，无视线不锁定
var _alert_t := 0.0
var _alert_from_pos := Vector3.ZERO
var _alert_source_id := 0 # // FIX: R2-B3 受击源追踪
var squad_id := -1 # // FIX: R4-S 小队编号（8 队×3）
var squad_name := ""
var _suppress_left := 0 # // FIX: R4-11 压制弹余量（进交战时补满 3 发）
var _last_seen_pos := Vector3.ZERO # // FIX: OPT-A3 最后已知位置，丢视后向其搜索
var capture_goal: CapturePoint = null

var _think := 0.0
var _lose_sight := 0.0
var _vision_cd := 0.0 # // FIX: H7 射线节流 0.2s 占位，避免 31Bot≈3000 ray/s
var _cached_enemy: CharacterBody3D = null # // FIX: H7 视锥+距离LOD缓存
var _burst_left := 0
var _burst_pause := 0.0
var _strafe_dir := 1.0
var _head_index := 1
var _corpse_t := -1.0
var _anim_t := 0.0
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _visual: Node3D
var _head: Node3D
var _look_phase := 0.0
var _glance_yaw := 0.0
var _step_cd := 0.0 # // FIX: OPT-E1/REG2 bot 脚步 3D 播放（听声辨位链路补全）
var _tact_hits: int = 0 # // FIX: TACT2 换掩体：单次战斗受击计数
var _tact_cover_t: float = 0.0 # // FIX: TACT2 换掩体：转移冷却标记，0可触发
var _tact_strafe_t: float = 0.0 # // FIX: TACT1 拉枪线：横移翻转间隔计时


var _glb: Node3D
var _ap: AnimationPlayer
var _cur_anim := ""


func setup(p_name: String, p_zone: Zone, p_terrain: Terrain, drop_to: Vector3, seed_value: int = -1, p_squad_id: int = -1, p_squad_name: String = "") -> void:
	squad_id = p_squad_id
	squad_name = p_squad_name
	display_name = p_name
	zone = p_zone
	terrain = p_terrain
	move_target = drop_to
	# // FIX: OPT-G7/REG4 bot skill 纳入 --seed 派生子流（原全局 randf 每局不同）
	if seed_value >= 0:
		var brng := RandomNumberGenerator.new()
		brng.seed = hash(str(seed_value, "_", p_name))
		skill = brng.randf_range(0.7, 1.5)
	else:
		skill = randf_range(0.7, 1.5)


func _ready() -> void:
	add_to_group("combatant")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var body_col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.45
	body_col.shape = cap
	body_col.position.y = 0.72
	add_child(body_col)
	var head_col := CollisionShape3D.new()
	var hs := SphereShape3D.new()
	hs.radius = 0.26
	head_col.shape = hs
	head_col.position.y = 1.56
	add_child(head_col)
	_head_index = head_col.get_index()
	if not _try_glb_visual():
		_build_visual()

	weapon = Weapon.new()
	add_child(weapon)
	weapon.setup(self, false)
	weapon.set_weapon("")
	_think = randf() * 0.3


# glb 视觉：Blender 管线生成的蒙皮士兵与动画；缺失时回退到程序化模型。
func _try_glb_visual() -> bool:
	if not ResourceLoader.exists("res://assets/models/soldier.glb"):
		return false
	var scene_res := SOLDIER_GLB as PackedScene
	if scene_res == null:
		return false
	_glb = scene_res.instantiate()
	add_child(_glb)
	_ap = _glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _ap != null:
		_ap.playback_default_blend_time = 0.12
	if _ap == null:
		_glb.queue_free()
		_glb = null
		return false
	# 按阵营调色板给夹克/长裤/装具染色。
	var palette := [Color(0.55, 0.35, 0.20), Color(0.40, 0.45, 0.30), Color(0.30, 0.35, 0.50), Color(0.50, 0.25, 0.25), Color(0.45, 0.40, 0.25), Color(0.35, 0.45, 0.48)]
	var jacket: Color = palette[randi_range(0, palette.size() - 1)]
	var tint := {
		"soldier_jacket": jacket,
		"soldier_pants": jacket.darkened(0.35),
		"soldier_gear": jacket.darkened(0.45),
	}
	for mi in _glb.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		for s in range(mesh_inst.mesh.get_surface_count()):
			var mat_res := mesh_inst.mesh.surface_get_material(s)
			if mat_res and tint.has(mat_res.resource_name):
				mesh_inst.set_surface_override_material(s, Toon.make_material(tint[mat_res.resource_name], true, 0.012))
	_play(&"idle")
	return true


func _play(clip: StringName) -> void:
	if _ap == null or _cur_anim == clip:
		return
	if _ap.has_animation(clip):
		# glTF 导入的动画默认不循环（loop_mode=0），持续状态剪辑手动开循环。
		var anim_res := _ap.get_animation(clip)
		if anim_res and anim_res.loop_mode == Animation.LOOP_NONE and not (clip in [&"windup", &"smash", &"hit", &"die", &"buck", &"dash", &"attack", &"death"]):
			anim_res.loop_mode = Animation.LOOP_LINEAR
		_cur_anim = clip
		_ap.play(clip)


func _build_visual() -> void:
	var palette := [Color(0.55, 0.35, 0.20), Color(0.40, 0.45, 0.30), Color(0.30, 0.35, 0.50), Color(0.50, 0.25, 0.25), Color(0.45, 0.40, 0.25), Color(0.35, 0.45, 0.48)]
	var jacket: Color = palette[randi_range(0, palette.size() - 1)]
	var pants := jacket.darkened(0.35)
	var skin := Color(0.87, 0.70, 0.55)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	# 骨盆 + 躯干（全部挂在 _visual 下，整体做起伏/前倾/呼吸）
	_bp(Vector3(0.34, 0.24, 0.27), pants, Vector3(0, 0.76, 0), _visual)
	_caps(_visual, 0.29, 0.92, jacket, Vector3(0, 1.10, 0))
	# 战术背心 + 胸前弹匣袋
	_bp(Vector3(0.42, 0.42, 0.33), jacket.darkened(0.40), Vector3(0, 1.16, 0), _visual, 0.010)
	for i in range(3):
		_bp(Vector3(0.09, 0.13, 0.06), jacket.darkened(0.58), Vector3(-0.11 + i * 0.11, 1.13, -0.19), _visual, 0.006)
	# 背包 + 包盖 + 侧袋
	_bp(Vector3(0.36, 0.44, 0.18), jacket.darkened(0.45), Vector3(0, 1.18, 0.28), _visual, 0.010)
	_bp(Vector3(0.30, 0.10, 0.16), jacket.darkened(0.58), Vector3(0, 1.43, 0.28), _visual, 0.006)
	_bp(Vector3(0.10, 0.20, 0.12), jacket.darkened(0.52), Vector3(0.22, 1.10, 0.24), _visual, 0.006)
	# 腰带 + 腿挂包
	_bp(Vector3(0.40, 0.09, 0.32), pants.darkened(0.35), Vector3(0, 0.86, 0), _visual, 0.006)
	_bp(Vector3(0.12, 0.16, 0.10), pants.darkened(0.25), Vector3(0.20, 0.70, -0.06), _visual, 0.006)

	# 头部独立枢轴：脸、头盔都挂在 _head 上，能转头看人。
	_head = Node3D.new()
	_head.position = Vector3(0, 1.50, 0)
	_visual.add_child(_head)
	_sph(_head, 0.21, 0.40, skin, Vector3(0, 0.08, 0))
	# 眼白 + 瞳孔：大比例眼睛是卡通角色“有脸”的关键。
	for sx in [-1.0, 1.0]:
		var white := _sph(_head, 0.052, 0.09, Color(0.96, 0.96, 0.94), Vector3(sx * 0.078, 0.10, -0.155), 0.0)
		white.scale = Vector3(1.0, 1.35, 0.55)
		var pupil := _sph(_head, 0.026, 0.05, Color(0.10, 0.09, 0.10), Vector3(sx * 0.078, 0.095, -0.195), 0.0)
		pupil.scale = Vector3(1.0, 1.35, 0.45)
		var brow := _bp(Vector3(0.075, 0.018, 0.02), Color(0.16, 0.12, 0.10), Vector3(sx * 0.078, 0.185, -0.175), _head, 0.0)
		brow.rotation_degrees.z = sx * -8.0
	_bp(Vector3(0.05, 0.07, 0.05), skin.darkened(0.08), Vector3(0, 0.03, -0.20), _head, 0.0)
	# 头盔：盔体 + 帽檐 + 盔带
	_sph(_head, 0.25, 0.32, jacket.darkened(0.35), Vector3(0, 0.17, 0))
	var brim := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.265
	bm.bottom_radius = 0.265
	bm.height = 0.035
	bm.radial_segments = 10
	brim.mesh = bm
	brim.material_override = Toon.make_material(jacket.darkened(0.42), true, 0.008)
	brim.position.y = 0.115
	_head.add_child(brim)
	_bp(Vector3(0.05, 0.12, 0.03), jacket.darkened(0.55), Vector3(0.20, 0.05, 0), _head, 0.0)
	_bp(Vector3(0.05, 0.12, 0.03), jacket.darkened(0.55), Vector3(-0.20, 0.05, 0), _head, 0.0)

	# 四肢：肩/肘、髋/膝两级枢轴，行走时带关节弯曲。
	var arms := _make_arm(Vector3(-0.43, 1.38, 0), jacket, skin)
	_arm_l = arms[0]
	_elbow_l = arms[1]
	var arms_r := _make_arm(Vector3(0.43, 1.38, 0), jacket, skin)
	_arm_r = arms_r[0]
	_elbow_r = arms_r[1]
	var legs := _make_leg(Vector3(-0.15, 0.74, 0), pants)
	_leg_l = legs[0]
	_knee_l = legs[1]
	var legs_r := _make_leg(Vector3(0.15, 0.74, 0), pants)
	_leg_r = legs_r[0]
	_knee_r = legs_r[1]

	# 步枪挂在右手：机匣 + 枪管 + 弹匣 + 枪托
	var gun := Node3D.new()
	gun.position = Vector3(0, -0.60, -0.14)
	_arm_r.add_child(gun)
	_bp(Vector3(0.07, 0.11, 0.44), Color(0.14, 0.15, 0.17), Vector3.ZERO, gun, 0.006)
	var barrel := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.018
	bc.bottom_radius = 0.018
	bc.height = 0.24
	bc.radial_segments = 6
	barrel.mesh = bc
	barrel.material_override = Toon.make_material(Color(0.10, 0.11, 0.13), false)
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0, 0.02, -0.32)
	gun.add_child(barrel)
	_bp(Vector3(0.05, 0.13, 0.06), Color(0.20, 0.21, 0.23), Vector3(0, -0.10, 0.04), gun, 0.0)
	_bp(Vector3(0.06, 0.09, 0.14), jacket.darkened(0.50), Vector3(0, -0.01, 0.27), gun, 0.006)


func _bp(size: Vector3, color: Color, pos: Vector3, parent: Node3D = null, outline: float = 0.012) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Toon.make_material(color, outline > 0.0, outline)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _caps(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, outline: float = 0.012) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 7
	mi.mesh = cm
	mi.material_override = Toon.make_material(color, outline > 0.0, outline)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sph(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3, outline: float = 0.012) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = height
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = Toon.make_material(color, outline > 0.0, outline)
	mi.position = pos
	parent.add_child(mi)
	return mi


# 手臂 = 肩枢轴（上臂）+ 肘枢轴（前臂+手），返回 [肩, 肘]。
func _make_arm(pivot: Vector3, jacket: Color, skin: Color) -> Array:
	var shoulder := Node3D.new()
	shoulder.position = pivot
	_visual.add_child(shoulder)
	_bp(Vector3(0.17, 0.12, 0.17), jacket.darkened(0.30), Vector3(0, 0.02, 0), shoulder)  # 肩甲
	_caps(shoulder, 0.080, 0.32, jacket, Vector3(0, -0.17, 0))                            # 上臂
	var elbow := Node3D.new()
	elbow.position = Vector3(0, -0.33, 0)
	shoulder.add_child(elbow)
	_bp(Vector3(0.10, 0.09, 0.10), jacket.darkened(0.35), Vector3.ZERO, elbow, 0.0)       # 肘部
	_caps(elbow, 0.068, 0.30, jacket.darkened(0.10), Vector3(0, -0.16, 0))                # 前臂
	_sph(elbow, 0.062, 0.11, skin, Vector3(0, -0.33, 0))                                  # 手
	return [shoulder, elbow]


# 腿 = 髋枢轴（大腿）+ 膝枢轴（小腿+军靴），返回 [髋, 膝]。
func _make_leg(pivot: Vector3, pants: Color) -> Array:
	var hip := Node3D.new()
	hip.position = pivot
	_visual.add_child(hip)
	_caps(hip, 0.105, 0.36, pants, Vector3(0, -0.19, 0))                                  # 大腿
	var knee := Node3D.new()
	knee.position = Vector3(0, -0.38, 0)
	hip.add_child(knee)
	_bp(Vector3(0.14, 0.12, 0.08), pants.darkened(0.30), Vector3(0, 0.01, -0.07), knee, 0.0)  # 护膝
	_caps(knee, 0.082, 0.32, pants.darkened(0.10), Vector3(0, -0.14, 0))                  # 小腿
	_bp(Vector3(0.15, 0.10, 0.28), Color(0.16, 0.14, 0.12), Vector3(0, -0.32, -0.04), knee, 0.008)  # 军靴
	return [hip, knee]


func get_aim_origin() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


func get_aim_dir() -> Vector3:
	if aim_target and is_instance_valid(aim_target) and aim_target.alive:
		var chest: Vector3 = aim_target.global_position + Vector3(0, 1.1, 0)
		var d: Vector3 = (chest - get_aim_origin()).normalized()
		var dist := get_aim_origin().distance_to(chest)
		var e := deg_to_rad(1.8 * maxf(0.12, 1.5 - skill) * (1.0 + dist * 0.015)) # // FIX: H3 1.8*maxf(0.12,1.5-skill) 散布已钳制，下限0.12防零散，距离系数0.015线性放大
		d = d.rotated(Vector3.UP, randf_range(-e, e))
		var side := d.cross(Vector3.UP)
		if side.length() > 0.01:
			d = d.rotated(side.normalized(), randf_range(-e, e) * 0.6)
		return d.normalized()
	return -global_transform.basis.z


func get_hit_part(shape_idx: int) -> String:
	return "head" if shape_idx == _head_index else "body"


func give_weapon(id: String) -> void:
	if weapon.weapon_id != "":
		# // FIX: R4-2 换枪升级：更稀有的枪在 12m 内允许替换（丢旧枪落地），原首把枪锁死不升级
		var new_rarity: int = {"smg": 1, "rifle": 2, "dmr": 3, "shotgun": 1, "lmg": 2}.get(id, 1)
		var cur_rarity: int = {"smg": 1, "rifle": 2, "dmr": 3, "shotgun": 1, "lmg": 2}.get(weapon.weapon_id, 1)
		var pl_dist := 999.0
		for c in get_tree().get_nodes_in_group("combatant"):
			if c is Player:
				pl_dist = global_position.distance_to(c.global_position)
				break
		if new_rarity <= cur_rarity or pl_dist > 12.0:
			return
		var old_id := weapon.weapon_id
		weapon.set_weapon(id, Weapon.WEAPONS[id].mag, Weapon.WEAPONS[id].start_reserve)
		var pos := global_position
		if terrain:
			pos.y = terrain.get_height(pos.x, pos.z) + 0.1
		Loot.spawn(get_parent(), pos + Vector3(0.6, 0, 0), "weapon", old_id, 0, cur_rarity)
		return
	weapon.set_weapon(id, Weapon.WEAPONS[id].mag, Weapon.WEAPONS[id].start_reserve)


func give_ammo(amount: int) -> void:
	weapon.reserve = mini(240, weapon.reserve + amount) # // FIX: R2-C2d 人机对等（原 999=实战无限）
	# // FIX: H3 换弹受限说明：Bot 同 Player 共用 Weapon.start_reload/mag 钳制，999为硬上限，空匣必经换弹期


# ---------- 感知与决策 ----------

func _think_tick() -> void:
	if not alive:
		return
	# // FIX: OPT-A3 交战态也检查毒圈，圈内威胁加权撤退
	var pos2 := Vector2(global_position.x, global_position.z)
	var outside := zone.active and pos2.distance_to(zone.center) > zone.radius * 0.97
	# 感知最近可见敌人
	var enemy := _find_visible_enemy()
	if enemy:
		if state != State.FIGHT:
			_strafe_dir = 1.0 if randf() < 0.5 else -1.0
			_tact_hits = 0 # // FIX: TACT2 换掩体：新战斗清计数
			_tact_cover_t = 0.0 # // FIX: TACT2 换掩体：新战斗清冷却
			_tact_strafe_t = randf_range(1.5, 3.5) # // FIX: TACT1 拉枪线：入战重置翻转计时
		state = State.FIGHT
		aim_target = enemy
		_lose_sight = 0.0
		_last_seen_pos = enemy.global_position
		_suppress_left = 3 # // FIX: R4-11
		return
	if state == State.FIGHT:
		# // FIX: TACT2 换掩体：单次战斗受击≥3次侧向转移8-12m一次
		if _tact_hits >= 3 and _tact_cover_t == 0.0 and aim_target and is_instance_valid(aim_target):
			var _tact_fwd: Vector3 = (aim_target.global_position - global_position)
			_tact_fwd.y = 0
			if _tact_fwd.length() > 0.5:
				_tact_fwd = _tact_fwd.normalized()
				var _tact_side: Vector3 = _tact_fwd.cross(Vector3.UP).normalized()
				var _tact_sign: float = 1.0 if randf() < 0.5 else -1.0
				var _tact_dist: float = randf_range(8.0, 12.0)
				var _tact_off: Vector3 = _tact_side * (_tact_sign * _tact_dist)
				_tact_off.y = 0
				move_target = global_position + _tact_off
				_tact_cover_t = 1.0
				_tact_hits = 0
		# // FIX: R2-B3b 交战态查圈：圈外且残血强制撤离（原 outside 算完即被 early-return 吞掉，bot 站圈里对枪到毒死）
		if outside and hp < MAX_HP * 0.6:
			state = State.ROTATE
			aim_target = null
			move_target = _random_point_in_zone()
			return
		# // FIX: OPT-A3 丢视 >0.3s 停火（_fight_fire 内 _lose_sight 闸），
		# 1.2s 后放弃目标转 ROTATE；期间朝最后已知位置警戒移动
		_lose_sight += 0.3
		if _lose_sight > 1.2:
			state = State.ROTATE
			aim_target = null
			# 朝最后已知位置搜索逼近，行为更拟人
			if _last_seen_pos != Vector3.ZERO:
				move_target = _last_seen_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		return
	# // FIX: OPT-A3 受击警觉期：转身面向伤害来源方向搜索，但不锁定不开火
	if _alert_t > 0.0:
		_alert_t -= 0.3
		var to_alert := _alert_from_pos - global_position
		to_alert.y = 0
		if to_alert.length() > 1.0:
			rotation.y = lerp_angle(rotation.y, atan2(to_alert.normalized().x, to_alert.normalized().z) + PI, 0.25)
		if randf() < 0.4:
			move_target = global_position + to_alert.normalized() * randf_range(4.0, 8.0)
			state = State.ROTATE
		return
	# // FIX: OPT-A3 交战外同样跑圈优先：圈外必撤（原实现交战 early-return 永不检查毒圈）
	if outside:
		state = State.ROTATE
		move_target = _random_point_in_zone()
		return
	# 非战斗决策：找枪 > 补甲/回血 > 找弹药 > 占点 > 游荡
	# // FIX: OPT-A1 bot 资源行为：缺武器优先找枪（空手搜索半径 140m）；重伤找医疗、无甲找护甲（45m）
	if weapon.weapon_id == "":
		var loot := _find_nearest_loot("weapon", 140.0)
		if loot:
			if target_loot != loot or state != State.LOOT:
				_loot_time = 0.0
			state = State.LOOT
			target_loot = loot
			return
	if hp < MAX_HP * 0.6:
		var med := _find_nearest_loot("medkit", 45.0)
		if med:
			if target_loot != med or state != State.LOOT:
				_loot_time = 0.0
			state = State.LOOT
			target_loot = med
			return
	# // FIX: RES 护甲 <35 即补（原仅 0 才搜，残甲 Bot 等效裸身送 TTK）
	if armor < 35.0:
		var arm := _find_nearest_loot("armor", 45.0)
		if arm:
			if target_loot != arm or state != State.LOOT:
				_loot_time = 0.0
			state = State.LOOT
			target_loot = arm
			return
	# // FIX: RES 弹药不足一半即搜（原仅全空才搜，Bot 带 5 发进战白送）
	var _tot_ammo: int = weapon.reserve + weapon.mag_left
	var _mag_cap: int = int(weapon.data.get("mag", 30)) if weapon.weapon_id != "" else 30
	if weapon.weapon_id != "" and _tot_ammo < _mag_cap:
		var ammo_loot := _find_nearest_loot("ammo")
		if ammo_loot:
			if target_loot != ammo_loot or state != State.LOOT:
				_loot_time = 0.0
			state = State.LOOT
			target_loot = ammo_loot
			return
	if state != State.CAPTURE and randf() < 0.15:
		var cp := _find_capture_point()
		if cp:
			state = State.CAPTURE
			capture_goal = cp
			move_target = cp.global_position
			return
	if state == State.LOOT:
		if target_loot == null or not is_instance_valid(target_loot) or target_loot.consumed:
			state = State.ROTATE
			_loot_time = 0.0
	if state in [State.ROTATE, State.CAPTURE, State.DROP]:
		if global_position.distance_to(move_target) < 3.0 or state == State.DROP:
			# 到达后小范围游荡
			state = State.ROTATE
			move_target = global_position + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))


func _find_visible_enemy() -> CharacterBody3D:
	# // FIX: H7 0.2s 射线节流+视锥/距离LOD：远距>40m且背身过滤已在 loop 内，非可见周期直接复用缓存
	if _vision_cd > 0.0 and _cached_enemy and is_instance_valid(_cached_enemy) and _cached_enemy.alive:
		if global_position.distance_to(_cached_enemy.global_position) <= SIGHT_RANGE:
			return _cached_enemy
	# 本次真正做射线，重置节流
	_vision_cd = 0.20
	var best: CharacterBody3D = null
	var best_d := SIGHT_RANGE
	var eye := get_aim_origin()
	var fwd := -global_transform.basis.z
	# // FIX: H7 距离LOD: 40m外每隔1个跳过射线，保留近距精度
	var idx := 0
	for c in get_tree().get_nodes_in_group("combatant"):
		idx += 1
		if c == self or not c.alive:
			continue
		# // FIX: TEAM 同队不互射（8队×3，队友是友军非敌人）
		if squad_id >= 0 and c.get("squad_id") != null and int(c.get("squad_id")) == squad_id:
			continue
		var d := global_position.distance_to(c.global_position)
		if d > best_d:
			continue
		var to_c: Vector3 = (c.global_position - global_position).normalized()
		# // FIX: OPT-A3 背后全向感知 8m→3m：更远的背身必须进入视野（fwd.dot ≥ 0）才被感知
		if d > 3.0 and fwd.dot(to_c) < 0.0:
			continue
		if d > 40.0 and (idx % 2 == 0):
			continue # // FIX: H7 远距LOD跳过一半射线
	# // FIX: OPT-A4 索敌采样高度自适应：趴姿胶囊顶 ~0.9m，射线终点取目标碰撞半高而非硬编码 1.4m
		var target_eye: Vector3 = c.global_position + Vector3(0, _target_sample_height(c), 0)
		var query := PhysicsRayQueryParameters3D.create(eye, target_eye, 1 | 2 | 4, [get_rid()])
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and result.collider == c and not _smoke_blocks(eye, target_eye):
			best = c
			best_d = d
	_cached_enemy = best
	return best


# // FIX: OPT-A4 目标胸口采样高度：按碰撞形状上限估算（站立 capsule ~1.4m、趴姿 capsule ~0.9m），远距趴姿减半感知
func _target_sample_height(c: Node3D) -> float:
	var h := 1.4
	for child in c.get_children():
		var col := child as CollisionShape3D
		if col and col.shape is CapsuleShape3D:
			var cap := col.shape as CapsuleShape3D
			h = maxf(h, col.position.y + cap.height * 0.5)
			break
	var dist := global_position.distance_to(c.global_position)
	if h < 1.1 and dist > 20.0:
		h *= 0.9 # 趴姿远距感知略降（×0.9 高度 + 近距保底），不再完全隐形
	return minf(h, 1.45)


# 烟雾球遮挡视线：线段与烟球求交
func _smoke_blocks(a: Vector3, b: Vector3) -> bool:
	for s in get_tree().get_nodes_in_group("smoke"):
		var c: Vector3 = s.global_position
		var ab := b - a
		var t: float = clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if (a + ab * t).distance_to(c) < SmokeGrenade.SMOKE_RADIUS:
			return true
	return false


func _find_nearest_loot(kind: String, max_dist: float = 90.0) -> Loot:
	# // FIX: OPT-A2 失败物资 12s 冷却（原注释占位无实现导致 8s 死循环）；_loot_failed_pos 已删除
	var now_ms := Time.get_ticks_msec()
	# 清理过期失败记录（存的是到期时刻）
	for fid in _loot_failed_at.keys():
		if now_ms > int(_loot_failed_at[fid]):
			_loot_failed_at.erase(fid)
	var best: Loot = null
	var best_d := max_dist
	for item in get_tree().get_nodes_in_group("loot"):
		if item.consumed or item.kind != kind:
			continue
		if _loot_failed_at.has(item.get_instance_id()):
			continue
		var d := global_position.distance_to(item.global_position)
		if d < best_d:
			best = item
			best_d = d
	return best


func _find_capture_point() -> CapturePoint:
	var best: CapturePoint = null
	var best_d := 130.0
	for cp in get_tree().get_nodes_in_group("capture_point"):
		if cp.owner_body == self:
			continue
		var d := global_position.distance_to(cp.global_position)
		if d < best_d:
			best = cp
			best_d = d
	return best


func _random_point_in_zone() -> Vector3:
	var ang := randf() * TAU
	var r := randf() * zone.radius * 0.7
	var x: float = zone.center.x + cos(ang) * r
	var z: float = zone.center.y + sin(ang) * r
	return Vector3(x, terrain.get_height(x, z), z)


# ---------- 每帧行为 ----------

func _physics_process(delta: float) -> void:
	if not alive:
		_update_corpse(delta)
		return
	_vision_cd = maxf(0.0, _vision_cd - delta) # // FIX: H7 射线节流计时
	_tact_strafe_t = maxf(0.0, _tact_strafe_t - delta) # // FIX: TACT1 拉枪线：翻转间隔倒计时
	_think -= delta
	if _think <= 0.0:
		# 远距 AI（>80m 无可见目标）降频至 0.5Hz，近距保持 3Hz
		var far := true
		if aim_target and is_instance_valid(aim_target) and aim_target.alive:
			far = false
		else:
			for c in get_tree().get_nodes_in_group("combatant"):
				if c != self and c.alive and global_position.distance_to(c.global_position) < 80.0:
					far = false
					break
		_think = 0.5 if far else 0.3
		_think_tick()

	var move_dir := Vector3.ZERO
	var speed := WALK
	match state:
		State.DROP:
			move_dir = (move_target - global_position)
			move_dir.y = 0
			move_dir = move_dir.normalized()
			speed = 7.0
			if is_on_floor():
				state = State.LOOT
		State.FIGHT:
			move_dir = _fight_move()
			speed = WALK
			_fight_fire(delta)
		State.LOOT:
			if target_loot and is_instance_valid(target_loot) and not target_loot.consumed:
				_loot_time += delta
				if _loot_time > 8.0:
					# // FIX: OPT-A2/P3 失败指数退避：12s→24→48→96→192s，不可达物资不再无限重试
					var fid: int = target_loot.get_instance_id()
					var cnt: int = int(_loot_fail_counts.get(fid, 0)) + 1
					_loot_fail_counts[fid] = cnt
					_loot_failed_at[fid] = Time.get_ticks_msec() + 12000 * (1 << mini(cnt, 4))
					target_loot = null
					_loot_time = 0.0
					state = State.ROTATE
				else:
					move_dir = _seek(target_loot.global_position)
					speed = RUN
					if global_position.distance_to(target_loot.global_position) < 1.8:
						target_loot.apply_to(self)
						_loot_time = 0.0
						target_loot = null
						state = State.ROTATE
			else:
				state = State.ROTATE
		State.ROTATE, State.CAPTURE:
			move_dir = _seek(move_target)
			speed = RUN

	if move_dir != Vector3.ZERO:
		move_dir = _avoid_obstacles(move_dir)
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(move_dir * speed, 22.0 * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y = maxf(velocity.y - GRAVITY * delta, -30.0)
	move_and_slide()

	# // FIX: OPT-E1/REG2 bot 移动脚步声（3D，随速度节流），20+ bot 不再无声移动
	_step_cd = maxf(0.0, _step_cd - delta)
	var bot_spd := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and bot_spd > 1.5 and _step_cd <= 0.0:
		_step_cd = 0.40 if bot_spd > 5.0 else 0.55
		var _sfx_step := get_tree().get_first_node_in_group("sfx_bank")
		if _sfx_step:
			_sfx_step.play_at("footstep_grass", global_position, -14.0, randf_range(0.9, 1.1))

	# 朝向
	var face := move_dir
	if state == State.FIGHT and aim_target and is_instance_valid(aim_target):
		face = (aim_target.global_position - global_position)
		face.y = 0
	if face.length_squared() > 0.01:
		var target_yaw: float = atan2(face.normalized().x, face.normalized().z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 8.0)

	if regen_rate > 0.0 and hp < MAX_HP:
		hp = minf(MAX_HP, hp + regen_rate * delta)

	# 程序动画：两级关节步态 + 身体起伏/前倾 + 呼吸 + 头部注视；交战端枪。
	var h_speed := Vector2(velocity.x, velocity.z).length()
	_anim_t += delta * (1.1 + h_speed * 2.3)
	var amp := clampf(h_speed / RUN, 0.0, 1.0)
	var swing := sin(_anim_t) * 0.62 * amp
	if _visual == null:
		# glb 路径由骨骼动画驱动：交战端枪 / 奔跑 / 走步 / 站立。
		if state == State.FIGHT and aim_target:
			_play(&"fight")
			if _ap:
				_ap.speed_scale = 1.0
		elif h_speed > (WALK + RUN) * 0.5:
			_play(&"run")
			if _ap:
				_ap.speed_scale = clampf(h_speed / RUN, 0.8, 1.5)  # // FIX: SS glb 步速同步防滑步
		elif h_speed > 0.5:
			_play(&"walk")
			if _ap:
				_ap.speed_scale = clampf(h_speed / WALK, 0.7, 1.3)  # // FIX: SS
		else:
			_play(&"idle")
			if _ap:
				_ap.speed_scale = 1.0
		return
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	# 小腿在后摆→前迈时弯曲；手臂与腿反相，肘部带微弯。
	_knee_l.rotation.x = maxf(0.0, sin(_anim_t)) * 0.85 * amp
	_knee_r.rotation.x = maxf(0.0, -sin(_anim_t)) * 0.85 * amp
	# 身体：两倍频起伏 + 速度前倾；站立时只剩呼吸。
	_visual.position.y = abs(cos(_anim_t)) * 0.055 * amp + sin(_anim_t * 0.9) * 0.012 * (1.0 - amp)
	_visual.rotation.x = lerpf(_visual.rotation.x, amp * 0.13, delta * 6.0)
	if state == State.FIGHT and aim_target and is_instance_valid(aim_target):
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.35, delta * 10.0)
		_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, -0.06, delta * 10.0)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.95, delta * 10.0)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.55, delta * 10.0)
		_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, -0.85, delta * 10.0)
	else:
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, swing * 0.75, delta * 12.0)
		_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, -0.22 - maxf(0.0, -sin(_anim_t)) * 0.35 * amp, delta * 12.0)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -swing * 0.75, delta * 12.0)
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.0, delta * 10.0)
		_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, -0.22 - maxf(0.0, sin(_anim_t)) * 0.35 * amp, delta * 12.0)
	# 头部：平时偶尔环顾一下（交战时身体已面向目标）。
	_look_phase -= delta
	if _look_phase <= 0.0:
		_look_phase = randf_range(2.5, 5.0)
		_glance_yaw = randf_range(-0.55, 0.55)
	_head.rotation.y = lerp_angle(_head.rotation.y, _glance_yaw if _look_phase < 1.2 else 0.0, delta * 3.0)


func _seek(target: Vector3) -> Vector3:
	var d := target - global_position
	d.y = 0
	if d.length() < 0.5:
		return Vector3.ZERO
	return d.normalized()


func _fight_move() -> Vector3:
	if not aim_target or not is_instance_valid(aim_target):
		return Vector3.ZERO
	var to_t := aim_target.global_position - global_position
	to_t.y = 0
	var dist: float = to_t.length()
	var fwd: Vector3 = to_t.normalized()
	var side: Vector3 = fwd.cross(Vector3.UP) * _strafe_dir
	var move: Vector3 = side
	# // FIX: RANGE DMR 近距(<15m)主动后拉保距，防玩家贴脸白嫖木桩
	if weapon.weapon_id == "dmr" and dist < 15.0:
		move = (side * 0.4 - fwd * 0.95).normalized()
	# // FIX: TACT 残血(≤40%)时后拉求生，不再原地横移送死
	elif hp < MAX_HP * 0.4 and dist < 30.0:
		move = (side * 0.5 - fwd * 0.9).normalized()
	elif dist > FIGHT_DIST + 10.0:
		move = (side * 0.6 + fwd * 0.8).normalized()
	elif dist < FIGHT_DIST - 8.0:
		move = (side * 0.6 - fwd * 0.8).normalized()
	# // FIX: TACT1 拉枪线：横移翻转间隔随机化1.5-3.5s才可能翻转（原固定randf()<0.01每帧概率）
	if _tact_strafe_t <= 0.0:
		_strafe_dir *= -1.0
		_tact_strafe_t = randf_range(1.5, 3.5)
	return move


func _fight_fire(delta: float) -> void:
	if not aim_target or not is_instance_valid(aim_target) or not aim_target.alive or weapon.weapon_id == "":
		return
	if weapon.mag_left <= 0:
		weapon.start_reload()
		return
	# // FIX: TACT3 预换弹：FIGHT中弹匣<25%且距目标>15m且未警觉时主动换弹
	if _alert_t <= 0.0 and not weapon.reloading and weapon.weapon_id != "":
		var _tact_mag_cap: int = int(weapon.data.get("mag", 30)) if not weapon.data.is_empty() else 30
		if _tact_mag_cap > 0 and weapon.mag_left < _tact_mag_cap * 0.25:
			var _tact_d2: float = global_position.distance_to(aim_target.global_position)
			if _tact_d2 > 15.0 and weapon.reserve > 0:
				weapon.start_reload()
				return
	# // FIX: OPT-A3 烟雾遮断视线即停火：目标被烟遮挡时不开火（压制弹只打最后已知位置）
	var dist := global_position.distance_to(aim_target.global_position)
	if dist > weapon.data.range * 0.85:
		return
	# // FIX: TACT 距离窗：霰弹只近战开火，DMR 只中远开火（避免 bot 近身拿霰弹/DMR 站桩）
	if weapon.weapon_id == "shotgun" and dist > 22.0:
		return
	if weapon.weapon_id == "dmr" and dist < 12.0:
		return
	# // FIX: R4-11 烟雾压制：丢视后朝最后已知位置盲射最多 3 发（原入烟=完全无敌窗），超出即真停火
	if _lose_sight > 0.3:
		if _suppress_left > 0 and weapon.mag_left > 0 and _burst_pause <= 0.0 and _last_seen_pos != Vector3.ZERO:
			_suppress_left -= 1
			_burst_pause = randf_range(0.5, 0.8)
			var to_last: Vector3 = (_last_seen_pos + Vector3(0, 1.0, 0) - get_aim_origin()).normalized()
			weapon.pull_trigger_dir(to_last)
		return
	if _smoke_blocks(get_aim_origin(), aim_target.global_position + Vector3(0, 1.1, 0)):
		return
	if _burst_pause > 0.0:
		_burst_pause -= delta
		return
	if _burst_left <= 0:
		# // FIX: OPT-A6/REG6 连发停顿 ÷ skill（原 ×skill 使越准的 bot 打得越慢，难度被抵消）
		_burst_left = randi_range(3, 6)
		_burst_pause = randf_range(0.35, 0.9) / skill
		return
	# // FIX: OPT-A3 受击警觉期未结束不开火（反应时间 ≥0.5s，含转向）
	if _alert_t > 0.0:
		return
	# 只有大致朝向目标时才开火
	var fwd := -global_transform.basis.z
	var to_t: Vector3 = (aim_target.global_position - global_position).normalized()
	if fwd.dot(to_t) > 0.85:
		weapon.pull_trigger()
		_burst_left -= 1


func _avoid_obstacles(dir: Vector3) -> Vector3:
	var from := global_position + Vector3(0, 0.9, 0)
	if not _blocked(from, dir):
		return dir
	var left := dir.rotated(Vector3.UP, 0.7)
	if not _blocked(from, left):
		return left
	var right := dir.rotated(Vector3.UP, -0.7)
	if not _blocked(from, right):
		return right
	return dir.rotated(Vector3.UP, 1.5)


func _blocked(from: Vector3, dir: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 2.2, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ---------- 伤害与死亡 ----------

func take_damage(amount: float, from: Variant = null, part: String = "body") -> void:
	if not alive:
		return
	# // FIX: R4-12 目标侧冻结减半：被玩家时停冻结的 bot 受任意来源伤害减半（原仅 weapon.gd 施法者路径覆盖，bot 弹等绕过就满伤）
	if get_meta("frozen_by_stasis", false):
		amount *= 0.5
	var dmg := amount
	# // FIX: OPT-C3 步枪穿甲：来源为步枪时吸收 0.6→0.45，与玩家侧同规则
	var absorb_ratio := 0.6
	if from is CharacterBody3D:
		var fw: Variant = from.get("weapon")
		if fw != null and fw.get("weapon_id") == "rifle":
			absorb_ratio = 0.45
	if armor > 0.0:
		var absorbed := minf(armor, dmg * absorb_ratio)
		armor -= absorbed
		dmg -= absorbed
	hp -= dmg
	# // FIX: TACT2 换掩体：FIGHT单次战斗受击计数
	if state == State.FIGHT and from is Node3D:
		var _tact_fs: Variant = from.get("squad_id") if from.get("squad_id") != null else -1
		if not (squad_id >= 0 and int(_tact_fs) == squad_id):
			_tact_hits += 1
	# // FIX: OPT-A5 命中反馈：飘字（爆头变红）+ 受击压扁闪动，与野怪同款标准
	var col: Color = Color(1.0, 0.35, 0.30) if part == "head" else Color(1.0, 0.85, 0.25)
	DamageNumber.spawn_at(get_parent(), global_position + Vector3(0, 2.05, 0), "%d%s" % [int(round(dmg)), "爆头" if part == "head" else ""], col)
	_flash_hit()
	# // FIX: OPT-A3/CB5 受击不再瞬锁：非交战态进入 0.5s 警觉期（转身面向来源、不锁定不开火）；
	# 无视线不会隔墙锁定 aim_target；交战态保持当前目标不被打扰
	if from is Node3D and from.is_inside_tree():
		# // FIX: TEAM 同队误伤不锁敌还击（队友流弹不算敌人）
		var _fsq: Variant = from.get("squad_id") if from.get("squad_id") != null else -1
		if squad_id >= 0 and int(_fsq) == squad_id:
			_alert_t = 0.0
			return
		if state != State.FIGHT:
			var sid: int = from.get_instance_id()
			# // FIX: R2-B3 警觉压制漏洞：原每次受击都重置 0.5s 且禁射，持续开火可让 bot 永不还击
			if sid != _alert_source_id or _alert_t <= 0.0:
				_alert_source_id = sid
				_alert_t = 0.5
				_alert_from_pos = from.global_position
				state = State.ROTATE
			else:
				# 同一来源的第二次受击：警觉窗结束，转入交战还击
				_alert_t = 0.0 # // FIX: R3-P0-1 未清 alert 会让 _fight_fire 永久 return（bot 成木桩）
				state = State.FIGHT
				aim_target = from
				_lose_sight = 0.0
	if hp <= 0.0:
		die(from)


func _flash_hit() -> void:
	# // FIX: OPT-A5 受击白闪：glb 与程序化模型统一短促压扁回弹
	var root := _visual if _visual != null else _glb
	if root == null:
		return
	root.scale = Vector3(1.06, 0.94, 1.06)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.12)


func die(from: Variant = null) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	_play(&"death")
	if from and from.get("kills") != null:
		from.kills += 1
	_corpse_t = 0.0
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_drop_loot()
	died.emit(self, from)


# // FIX: R4-S 队友阵亡通知：同队幸存者前往事发点调查（对局像真比赛的队伍感）
func notify_squad_death(pos: Vector3) -> void:
	if not alive or squad_id < 0:
		return
	if global_position.distance_to(pos) < 140.0:
		state = State.ROTATE
		move_target = pos + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		_alert_t = 0.5
		_alert_from_pos = pos


func _drop_loot() -> void:
	var pos := global_position
	pos.y = terrain.get_height(pos.x, pos.z) + 0.1
	if weapon.weapon_id != "":
		Loot.spawn(get_parent(), pos + Vector3(0.5, 0, 0), "weapon", weapon.weapon_id, 0, 2)
	if randf() < 0.35:
		Loot.spawn(get_parent(), pos + Vector3(-0.5, 0, 0), "medkit", "", 50, 1)
	# // FIX: R4-1 bot 死亡掉护甲（原 armor 被尸体带走，护甲经济单向流失）
	if armor > 25.0 and randf() < 0.3:
		Loot.spawn(get_parent(), pos + Vector3(0.5, 0, 0.5), "armor", "", int(armor), 2)


func _update_corpse(delta: float) -> void:
	if _corpse_t < 0.0:
		return
	_corpse_t += delta
	if _corpse_t < 0.4 and _ap == null:
		rotation.z = lerp_angle(rotation.z, PI * 0.5, delta * 10.0)
	elif _corpse_t > 6.0:
		position.y -= delta * 0.4
		if _corpse_t > 8.0:
			_corpse_t = -1.0
			queue_free()