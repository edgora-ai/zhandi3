class_name Weapon
extends Node3D
## 武器逻辑：hitscan 射击、扩散、后座、换弹、机瞄；玩家有视模型，bot 仅逻辑

signal ammo_changed(mag: int, reserve: int)
signal fired
signal reload_started
signal hit_landed(part: String) # // FIX: D4/CB17 命中带部位，供爆头 hitmarker
signal weapon_changed(id: String) # // FIX: VIS1 武器名事件驱动：--screenshot 等每帧早退场景也能同步标签

const WEAPONS: Dictionary = {
	"rifle": {
		"label": "突击步枪", "damage": 12.0, "head_mult": 2.0, "rpm": 540.0,
		"mag": 30, "start_reserve": 90, "spread": 1.3, "ads_spread": 0.45,
		"reload": 1.8, "auto": true, "zoom": 1.3, "range": 220.0, "recoil": 0.95,  # // FIX: RC2
		"falloff_start": 120.0, "falloff_end": 220.0, "falloff_min": 0.75,
		"bloom_add": 0.12, "bloom_cap": 0.90, "bloom_recovery": 0.7, "ads_bloom_scale": 0.50,
	},
	"dmr": {
		"label": "射手步枪", "damage": 35.0, "head_mult": 2.2, "rpm": 150.0,
		"mag": 12, "start_reserve": 36, "spread": 0.8, "ads_spread": 0.12,
		"reload": 2.1, "auto": false, "zoom": 2.4, "range": 350.0, "recoil": 1.85,  # // FIX: RC2
		"falloff_start": 250.0, "falloff_end": 350.0, "falloff_min": 0.85,
		"bloom_add": 0.22, "bloom_cap": 0.65, "bloom_recovery": 0.45, "ads_bloom_scale": 0.35,
	},
	"smg": {
		"label": "冲锋枪", "damage": 8.0, "head_mult": 1.8, "rpm": 800.0,
		"mag": 36, "start_reserve": 108, "spread": 2.0, "ads_spread": 1.0,
		"reload": 1.5, "auto": true, "zoom": 1.15, "range": 130.0, "recoil": 0.55,  # // FIX: RC2
		"falloff_start": 60.0, "falloff_end": 130.0, "falloff_min": 0.40,
		"bloom_add": 0.18, "bloom_cap": 1.25, "bloom_recovery": 1.6, "ads_bloom_scale": 0.55,
	},
	"shotgun": {
		"label": "霰弹枪", "damage": 8.0, "head_mult": 1.5, "rpm": 75.0,
		"mag": 6, "start_reserve": 24, "spread": 4.5, "ads_spread": 3.0,
		"reload": 2.4, "auto": false, "zoom": 1.1, "range": 40.0, "recoil": 2.2,  # // FIX: RC2
		"pellets": 7, "falloff_start": 10.0, "falloff_end": 25.0, "falloff_min": 0.25,
		"bloom_add": 0.28, "bloom_cap": 0.80, "bloom_recovery": 0.3, "ads_bloom_scale": 0.70,
	},
	"lmg": {
		"label": "轻机枪", "damage": 11.0, "head_mult": 1.6, "rpm": 480.0,
		"mag": 60, "start_reserve": 120, "spread": 2.2, "ads_spread": 0.9,
		"reload": 3.6, "auto": true, "zoom": 1.2, "range": 200.0, "recoil": 0.95,  # // FIX: RC2
		"falloff_start": 110.0, "falloff_end": 200.0, "falloff_min": 0.7,
		"bloom_add": 0.14, "bloom_cap": 1.35, "bloom_recovery": 0.9, "ads_bloom_scale": 0.55,
	},
	"bow": {
		"label": "猎弓", "damage": 0.0, "head_mult": 1.0, "rpm": 60.0,
		"mag": 1, "start_reserve": 24, "spread": 0.0, "ads_spread": 0.0,
		"reload": 0.5, "auto": false, "zoom": 1.35, "range": 0.0, "recoil": 0.0,
		"bloom_add": 0.0, "bloom_cap": 0.0, "bloom_recovery": 0.0, "ads_bloom_scale": 1.0,
	},
}

@export var base_fov: float = 75.0
const GUNMETAL: Color = Color(0.15, 0.16, 0.18)
var BASE_FOV: float = 75.0

var owner_body: CharacterBody3D
var is_player: bool = false
var weapon_id: String = ""
var data: Dictionary = {}
var mag_left: int = 0
var reserve: int = 0
var last_shot_msec: int = 0
var is_ads: bool = false
var reloading: bool = false

var viewmodel: Node3D
var muzzle: Node3D
var _flash: OmniLight3D
var _cool: float = 0.0
var _reload_left: float = 0.0
var _kick: float = 0.0
var _bob_t: float = 0.0
var _bloom: float = 0.0
var _forced_dir: Vector3 = Vector3.ZERO

# W4 feedback state
var _burst_idx: int = 0
var _burst_last_msec: int = 0
var _vm_pos_offset: Vector3 = Vector3.ZERO
var _vm_rot_offset: Vector3 = Vector3.ZERO
const BURST_RESET_MS: int = 350

# Viewmodel per-weapon impulses (position + rotation), layered with ADS/reload/bob
const VM_POS_RIFLE: Vector3 = Vector3(0.0, -0.009, 0.038)
const VM_ROT_RIFLE: Vector3 = Vector3(0.42, 0.10, -0.06)
const VM_POS_SMG: Vector3 = Vector3(0.0, -0.007, 0.028)
const VM_ROT_SMG: Vector3 = Vector3(0.30, 0.09, -0.05)
const VM_POS_DMR: Vector3 = Vector3(0.0, -0.012, 0.050)
const VM_ROT_DMR: Vector3 = Vector3(0.55, 0.07, -0.04)
const VM_POS_SHOTGUN: Vector3 = Vector3(0.0, -0.018, 0.072)
const VM_ROT_SHOTGUN: Vector3 = Vector3(0.85, 0.12, -0.09)
const VM_POS_LMG: Vector3 = Vector3(0.0, -0.011, 0.045)
const VM_ROT_LMG: Vector3 = Vector3(0.48, 0.11, -0.07)
const VM_POS_BOW: Vector3 = Vector3.ZERO
const VM_ROT_BOW: Vector3 = Vector3.ZERO


func setup(p_owner: CharacterBody3D, p_is_player: bool) -> void:
	owner_body = p_owner
	is_player = p_is_player


func set_weapon(id: String, p_mag: int = -1, p_reserve: int = -1) -> void:
	weapon_id = id
	if viewmodel and (id == "" or id == "bow"):
		viewmodel.queue_free()
		viewmodel = null
		muzzle = null
		_flash = null
	# Always reset W4 feedback state, even for empty id, without invalid access
	_bloom = 0.0
	_burst_idx = 0
	_burst_last_msec = 0
	_vm_pos_offset = Vector3.ZERO
	_vm_rot_offset = Vector3.ZERO
	_kick = 0.0
	if id == "":
		data = {}
		mag_left = 0
		reserve = 0
		reloading = false
		_cool = 0.0
		ammo_changed.emit(0, 0)
		weapon_changed.emit(id)
		return
	var src: Variant = WEAPONS.get(id, {})
	var src_dict: Dictionary = src as Dictionary if src is Dictionary else {}
	if src_dict.is_empty():
		data = {}
		mag_left = 0
		reserve = 0
		reloading = false
		_cool = 0.0
		ammo_changed.emit(0, 0)
		weapon_changed.emit(id)
		return
	data = src_dict
	var mag_val: Variant = data.get("mag", 30)
	var mag_int: int = int(mag_val) if mag_val is int else int(float(mag_val)) if mag_val is float else 30
	var reserve_val: Variant = data.get("start_reserve", 0)
	var reserve_int: int = int(reserve_val) if reserve_val is int else int(float(reserve_val)) if reserve_val is float else 0
	mag_left = p_mag if p_mag >= 0 else mag_int
	reserve = p_reserve if p_reserve >= 0 else reserve_int
	reloading = false
	_cool = 0.0
	if is_player and id != "bow":
		_build_viewmodel()
	ammo_changed.emit(mag_left, reserve)
	weapon_changed.emit(id)


func label() -> String:
	var lb: Variant = data.get("label", "波克剑")
	if lb is String:
		return lb as String
	return str(lb)


func hold_trigger() -> void:
	var auto_val: Variant = data.get("auto", false)
	var auto_bool: bool = false
	if auto_val is bool:
		auto_bool = auto_val as bool
	if not auto_bool:
		return
	_try_fire()


func pull_trigger() -> void:
	_try_fire()


func pull_trigger_dir(dir: Vector3) -> void:
	if weapon_id == "" or reloading or _cool > 0.0 or mag_left <= 0:
		return
	var rpm_v: Variant = data.get("rpm", 0.0)
	var rpm_f: float = float(rpm_v) if rpm_v is float or rpm_v is int else 0.0
	if rpm_f <= 0.0:
		return
	_cool = 60.0 / rpm_f
	mag_left -= 1
	# Use current bloom for this forced shot, then add bloom once after
	_forced_dir = dir
	_fire_ray()
	_forced_dir = Vector3.ZERO
	_add_bloom_once()
	last_shot_msec = Time.get_ticks_msec()
	_burst_last_msec = last_shot_msec
	var flash_size: float = 0.020 if is_player else 0.13
	FX.muzzle_flash(muzzle_world(), flash_size)
	if is_player and _flash:
		_flash.light_energy = 0.22
		_flash.omni_range = 0.60
	elif _flash:
		_flash.light_energy = 3.0
		_flash.omni_range = 5.0
	fired.emit()


# // FIX: RELC 换弹取消：冲刺/机瞄按下/跳跃时中断（保留当前弹匣+进冷却 0.2s），防止换弹成站桩锁
func cancel_reload() -> void:
	if not reloading:
		return
	reloading = false
	_reload_left = 0.0
	_cool = maxf(_cool, 0.2)


func start_reload() -> void:
	if reloading or weapon_id == "":
		return
	var mag_v: Variant = data.get("mag", 0)
	var mag_i: int = int(mag_v) if mag_v is int else int(float(mag_v)) if mag_v is float else 0
	if mag_left >= mag_i or reserve <= 0:
		return
	reloading = true
	var reload_v: Variant = data.get("reload", 0.0)
	var reload_f: float = float(reload_v) if reload_v is float or reload_v is int else 0.0
	_reload_left = reload_f
	if is_player:
		var sfx: Variant = owner_body.get_tree().get_first_node_in_group("sfx_bank")
		if sfx != null and sfx is Node and (sfx as Node).has_method("play"):
			(sfx as Node).call("play", "reload_start", -6.0)
	reload_started.emit()


func set_ads(on: bool) -> void:
	is_ads = on and weapon_id != "" and is_player


func current_spread() -> float:
	if weapon_id == "":
		return 0.0
	var ads_spread_v: Variant = data.get("ads_spread", 0.0)
	var spread_v: Variant = data.get("spread", 0.0)
	var s: float = 0.0
	if is_ads:
		if ads_spread_v is float:
			s = ads_spread_v as float
		elif ads_spread_v is int:
			s = float(ads_spread_v as int)
		else:
			s = float(spread_v) if spread_v is float or spread_v is int else 0.0
	else:
		if spread_v is float:
			s = spread_v as float
		elif spread_v is int:
			s = float(spread_v as int)
	if owner_body != null and owner_body.get("prone") == true:
		s *= 0.65
	var speed: float = Vector3(owner_body.velocity.x, 0, owner_body.velocity.z).length() if owner_body else 0.0
	s *= 1.0 + speed * 0.09
	if owner_body and not owner_body.is_on_floor():
		s *= 1.8
	return s


func current_reticle_spread() -> float:
	if weapon_id == "":
		return 0.0
	var base: float = current_spread()
	var scale: float = 1.0
	if is_ads:
		var raw: Variant = data.get("ads_bloom_scale", 0.5)
		if raw is float:
			scale = raw as float
		elif raw is int:
			scale = float(raw as int)
		else:
			scale = 0.5
	else:
		scale = 1.0
	return base + _bloom * scale


func _effective_spread_deg() -> float:
	if weapon_id == "":
		return 0.0
	var base: float = current_spread()
	var scale: float = 1.0
	if is_ads:
		var raw: Variant = data.get("ads_bloom_scale", 0.5)
		if raw is float:
			scale = raw as float
		elif raw is int:
			scale = float(raw as int)
		else:
			scale = 0.5
	else:
		scale = 1.0
	return base + _bloom * scale


func _add_bloom_once() -> void:
	if weapon_id == "":
		return
	var add_v: Variant = data.get("bloom_add", 0.0)
	var cap_v: Variant = data.get("bloom_cap", 0.0)
	var add_f: float = 0.0
	var cap_f: float = 0.0
	if add_v is float:
		add_f = add_v as float
	elif add_v is int:
		add_f = float(add_v as int)
	if cap_v is float:
		cap_f = cap_v as float
	elif cap_v is int:
		cap_f = float(cap_v as int)
	if cap_f <= 0.0:
		return
	_bloom = minf(_bloom + add_f, cap_f)


func _maybe_reset_burst() -> void:
	var now: int = Time.get_ticks_msec()
	if _burst_last_msec != 0 and now - _burst_last_msec > BURST_RESET_MS:
		_burst_idx = 0


func _yaw_pattern_bias(wid: String, idx: int) -> float:
	match wid:
		"rifle":
			match idx % 4:
				0: return 0.11
				1: return -0.14
				2: return 0.09
				3: return -0.10
				_: return 0.08
		"smg":
			match idx % 5:
				0: return 0.10
				1: return -0.12
				2: return 0.08
				3: return -0.07
				4: return 0.06
				_: return 0.05
		"dmr":
			# Must not be zero amplitude fake pattern
			match idx % 4:
				0: return 0.14
				1: return -0.11
				2: return 0.10
				3: return -0.13
				_: return 0.12
		"shotgun":
			match idx % 4:
				0: return 0.18
				1: return -0.16
				2: return 0.12
				3: return -0.10
				_: return 0.14
		"lmg":
			# Not pure random - deterministic pattern with small noise added externally
			match idx % 6:
				0: return 0.09
				1: return 0.07
				2: return -0.08
				3: return 0.11
				4: return -0.09
				5: return 0.06
				_: return 0.08
		_: return 0.0


func _pitch_pattern_offset(wid: String, idx: int) -> float:
	match wid:
		"rifle":
			match idx % 4:
				0: return 0.00
				1: return 0.04
				2: return -0.02
				3: return 0.03
				_: return 0.01
		"smg":
			match idx % 5:
				0: return 0.00
				1: return 0.02
				2: return -0.01
				3: return 0.015
				4: return -0.005
				_: return 0.0
		"dmr":
			match idx % 4:
				0: return 0.00
				1: return 0.08
				2: return -0.05
				3: return 0.06
				_: return 0.02
		"shotgun":
			match idx % 4:
				0: return 0.00
				1: return 0.10
				2: return -0.06
				3: return 0.07
				_: return 0.03
		"lmg":
			match idx % 6:
				0: return 0.00
				1: return 0.03
				2: return -0.02
				3: return 0.04
				4: return -0.01
				5: return 0.02
				_: return 0.01
		_: return 0.0


func _vm_pos_impulse(wid: String) -> Vector3:
	match wid:
		"rifle": return VM_POS_RIFLE
		"smg": return VM_POS_SMG
		"dmr": return VM_POS_DMR
		"shotgun": return VM_POS_SHOTGUN
		"lmg": return VM_POS_LMG
		_: return Vector3.ZERO


func _vm_rot_impulse(wid: String) -> Vector3:
	match wid:
		"rifle": return VM_ROT_RIFLE
		"smg": return VM_ROT_SMG
		"dmr": return VM_ROT_DMR
		"shotgun": return VM_ROT_SHOTGUN
		"lmg": return VM_ROT_LMG
		_: return Vector3.ZERO


static func conical_spread_dir(base_dir: Vector3, angle_rad: float, u: float, v: float) -> Vector3:
	# Deterministic uniform disk mapped to tangent cone, read-only helper for 10k validation
	var dir: Vector3 = base_dir.normalized()
	if angle_rad <= 0.0:
		return dir
	var theta: float = TAU * u
	var radius: float = sqrt(v) * tan(angle_rad)
	var up_ref: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var right: Vector3 = dir.cross(up_ref).normalized()
	var upv: Vector3 = right.cross(dir).normalized()
	var off_x: float = cos(theta) * radius
	var off_y: float = sin(theta) * radius
	var out: Vector3 = (dir + right * off_x + upv * off_y).normalized()
	return out


func _apply_spread(dir: Vector3, angle_rad: float) -> Vector3:
	var u: float = randf()
	var v: float = randf()
	return conical_spread_dir(dir, angle_rad, u, v)


func _try_fire() -> void:
	if weapon_id == "" or reloading or _cool > 0.0:
		return
	if not data.has("rpm"):
		print("[weapon] BUG data keys=%s id='%s' is_player=%s" % [str(data.keys()), weapon_id, str(is_player)])
		if data.is_empty():
			weapon_id = ""
			return
		var fallback: Variant = WEAPONS.get(weapon_id, {})
		if fallback is Dictionary and not (fallback as Dictionary).is_empty():
			data = fallback as Dictionary
		else:
			return
	if mag_left <= 0:
		if is_player:
			start_reload()
		return
	var rpm_v: Variant = data.get("rpm", 0.0)
	var rpm_f: float = float(rpm_v) if rpm_v is float or rpm_v is int else 0.0
	if rpm_f <= 0.0:
		return
	_cool = 60.0 / rpm_f
	mag_left -= 1
	# Burst pattern reset after pause
	_maybe_reset_burst()
	# Fire all pellets with current bloom (before increment) so first shot has base only
	var pellets_v: Variant = data.get("pellets", 1)
	var pellets_i: int = int(pellets_v) if pellets_v is int else int(float(pellets_v)) if pellets_v is float else 1
	for _pellet in range(pellets_i):
		_fire_ray()
	# Bloom exactly once per trigger pull after firing
	_add_bloom_once()
	last_shot_msec = Time.get_ticks_msec()
	_burst_last_msec = last_shot_msec
	_kick = 0.06
	var flash_size: float = 0.020 if is_player else 0.13
	FX.muzzle_flash(muzzle_world(), flash_size)
	if is_player:
		if _flash:
			_flash.light_energy = 0.22
			_flash.omni_range = 0.60
		# Stable learnable pitch/yaw pattern with small bounded noise, ADS lower
		var recoil_v: Variant = data.get("recoil", 0.0)
		var base_recoil: float = float(recoil_v) if recoil_v is float or recoil_v is int else 0.0
		var yaw_bias: float = _yaw_pattern_bias(weapon_id, _burst_idx)
		var pitch_off: float = _pitch_pattern_offset(weapon_id, _burst_idx)
		var pitch_deg: float = base_recoil + pitch_off
		# Small bounded noise only
		pitch_deg += randf_range(-0.025, 0.025)
		var yaw_deg: float = yaw_bias + randf_range(-0.032, 0.032)
		var ads_scale: float = 0.75 if is_ads else 1.0  # // FIX: ADS 缩放 0.75
		pitch_deg *= ads_scale
		yaw_deg *= ads_scale
		owner_body.add_recoil(pitch_deg, yaw_deg)
		# Viewmodel impulse layered, not overwriting
		var vm_pos: Vector3 = _vm_pos_impulse(weapon_id)
		var vm_rot: Vector3 = _vm_rot_impulse(weapon_id)
		if is_ads:
			vm_pos *= 0.55
			vm_rot *= 0.55
		_vm_pos_offset += vm_pos
		_vm_rot_offset += vm_rot
		_burst_idx += 1
	else:
		if _flash:
			_flash.light_energy = 3.0
			_flash.omni_range = 5.0
	ammo_changed.emit(mag_left, reserve)
	fired.emit()


func _fire_ray() -> void:
	var origin: Vector3 = Vector3.ZERO
	var dir: Vector3 = Vector3.FORWARD
	if is_player:
		var cam: Camera3D = owner_body.camera as Camera3D
		origin = cam.global_position
		dir = -cam.global_transform.basis.z
	else:
		origin = owner_body.get_aim_origin() as Vector3
		dir = owner_body.get_aim_dir() as Vector3
	var total_deg: float = _effective_spread_deg()
	var s: float = deg_to_rad(total_deg)
	if _forced_dir != Vector3.ZERO:
		dir = _forced_dir
		s += deg_to_rad(4.0)
	# Uniform disk mapped to tangent cone
	if s > 0.0:
		dir = _apply_spread(dir, s)
	var range_v: Variant = data.get("range", 0.0)
	var range_f: float = float(range_v) if range_v is float or range_v is int else 0.0
	var mask: int = 1 | 4 if is_player else 1 | 2 | 4
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * range_f, mask, [owner_body.get_rid()])
	var result: Dictionary = owner_body.get_world_3d().direct_space_state.intersect_ray(query)
	var end_point: Vector3 = Vector3.ZERO
	if result.is_empty():
		end_point = origin + dir * range_f
	else:
		end_point = result.position as Vector3
		var col: Object = result.collider as Object
		if col.has_method("take_damage"):
			var part: String = "body"
			if col.has_method("get_hit_part"):
				var shape_v: Variant = result.get("shape", 0)
				var shape_i: int = int(shape_v) if shape_v is int else 0
				var part_v: Variant = col.call("get_hit_part", shape_i)
				if part_v is String:
					part = part_v as String
			var dmg_base_v: Variant = data.get("damage", 0.0)
			var dmg_base: float = float(dmg_base_v) if dmg_base_v is float or dmg_base_v is int else 0.0
			var mult_v: Variant = owner_body.get("damage_mult")
			var mult_f: float = float(mult_v) if mult_v is float or mult_v is int else 1.0
			var dmg: float = dmg_base * mult_f
			if part == "head":
				var hm_v: Variant = data.get("head_mult", 1.0)
				var hm_f: float = float(hm_v) if hm_v is float or hm_v is int else 1.0
				dmg *= hm_f
			var fs_v: Variant = data.get("falloff_start", 0.0)
			var fe_v: Variant = data.get("falloff_end", 0.0)
			var fmin_v: Variant = data.get("falloff_min", 1.0)
			var fs: float = float(fs_v) if fs_v is float or fs_v is int else 0.0
			var fe: float = float(fe_v) if fe_v is float or fe_v is int else 0.0
			var fmin: float = float(fmin_v) if fmin_v is float or fmin_v is int else 1.0
			var hit_dist: float = origin.distance_to(end_point)
			if fs > 0.0 and fe > fs:
				var t: float = clampf((hit_dist - fs) / (fe - fs), 0.0, 1.0)
				dmg *= lerpf(1.0, fmin, t)
			if weapon_id == "smg" and hit_dist < 12.0:
				dmg *= 1.3
			var st: Variant = owner_body.get("_stasis_target")
			if st != null and col == st:
				dmg *= 0.5
			col.call("take_damage", dmg, owner_body, part)
			var dealt_v: Variant = owner_body.get("damage_dealt")
			if dealt_v != null and (dealt_v is float or dealt_v is int):
				var cur: float = float(dealt_v) if dealt_v is float or dealt_v is int else 0.0
				owner_body.set("damage_dealt", cur + dmg)
			if col.has_method("is_plant"):
				FX.impact(end_point, Color(0.55, 0.38, 0.18))
			elif col is CharacterBody3D:
				FX.blood(end_point)
			elif col is Guardian or col.has_method("is_metal") or col.is_in_group("metal_prop"):
				FX.impact(end_point, Color(1.0, 0.85, 0.35))
			else:
				FX.impact(end_point, Color(0.62, 0.58, 0.48))
				var norm_v: Variant = result.get("normal", Vector3.UP)
				var norm: Vector3 = norm_v as Vector3 if norm_v is Vector3 else Vector3.UP
				FX.decal(end_point, norm)
			if is_player:
				hit_landed.emit(part)
		else:
			FX.impact(end_point)
	if weapon_id == "dmr":
		FX.tracer(muzzle_world(), end_point, Color(1.0, 0.96, 0.62), 0.05)
	else:
		FX.tracer(muzzle_world(), end_point, Color(1.0, 0.88, 0.45), 0.025)


func muzzle_world() -> Vector3:
	if is_player and muzzle:
		return muzzle.global_position as Vector3
	var origin: Vector3 = owner_body.get_aim_origin() as Vector3
	var dir: Vector3 = owner_body.get_aim_dir() as Vector3
	return origin + dir * 0.6


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	# Bloom decay per-weapon
	if weapon_id != "" and not data.is_empty():
		var rec_v: Variant = data.get("bloom_recovery", 4.0)
		var rec_f: float = float(rec_v) if rec_v is float or rec_v is int else 4.0
		if rec_f > 0.0:
			_bloom = maxf(0.0, _bloom - delta * rec_f)
		else:
			_bloom = maxf(0.0, _bloom - delta * 4.0)
	else:
		_bloom = maxf(0.0, _bloom - delta * 4.0)
	if reloading:
		# // FIX: RELC 换弹取消触发（sprint/jump/ADS/高速移动）
		if is_player and owner_body:
			var _rc := owner_body as Node
			if _rc.get("vehicle") != null and _rc.vehicle != null:
				cancel_reload()
			elif Input.is_action_pressed("sprint") and _rc.get("stamina") != null and float(_rc.stamina) > 1.0:
				cancel_reload()
			elif Input.is_action_just_pressed("jump"):
				cancel_reload()
			elif is_ads:
				cancel_reload()
	if reloading:
		_reload_left -= delta
	if reloading and _reload_left <= 0.0:
		reloading = false
		var mag_v: Variant = data.get("mag", 0)
		var mag_i: int = int(mag_v) if mag_v is int else int(float(mag_v)) if mag_v is float else 0
		var need: int = mag_i - mag_left
		var take: int = mini(need, reserve)
		mag_left += take
		reserve -= take
		if is_player:
				var sfx: Variant = owner_body.get_tree().get_first_node_in_group("sfx_bank")
				if sfx != null and sfx is Node and (sfx as Node).has_method("play"):
					(sfx as Node).call("play", "reload_end", -6.0)
		ammo_changed.emit(mag_left, reserve)
	if _flash and _flash.light_energy > 0.0:
		_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 24.0)
	if not is_player or viewmodel == null:
		return
	var cam: Camera3D = owner_body.camera as Camera3D
	var zoom_v: Variant = data.get("zoom", 1.0)
	var zoom_f: float = float(zoom_v) if zoom_v is float or zoom_v is int else 1.0
	var target_fov: float = BASE_FOV / (zoom_f if is_ads else 1.0)
	var w_fov: float = clampf(delta * 12.0, 0.0, 1.0)
	cam.fov = lerpf(cam.fov, target_fov, w_fov)
	var ads_comp: float = 1.0 / (zoom_f if is_ads else 1.0)
	var w_scale: float = clampf(delta * 12.0, 0.0, 1.0)
	viewmodel.scale = viewmodel.scale.lerp(Vector3.ONE * ads_comp, w_scale)
	var target_pos: Vector3 = Vector3(0.0, -0.155, -0.35) if is_ads else Vector3(0.27, -0.23, -0.5)
	_kick = maxf(0.0, _kick - delta * 0.5)
	target_pos.z += _kick
	# Viewmodel recoil offsets decay robustly (clamped)
	var w_vm: float = clampf(delta * 9.0, 0.0, 1.0)
	_vm_pos_offset = _vm_pos_offset.lerp(Vector3.ZERO, w_vm)
	_vm_rot_offset = _vm_rot_offset.lerp(Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0))
	var effective_pos: Vector3 = target_pos + _vm_pos_offset
	if reloading:
		viewmodel.rotation.x = lerpf(viewmodel.rotation.x, -0.26 + _vm_rot_offset.x, clampf(delta * 10.0, 0.0, 1.0))
		viewmodel.rotation.y = lerpf(viewmodel.rotation.y, _vm_rot_offset.y, clampf(delta * 10.0, 0.0, 1.0))
		viewmodel.rotation.z = lerpf(viewmodel.rotation.z, _vm_rot_offset.z, clampf(delta * 10.0, 0.0, 1.0))
	else:
		viewmodel.rotation.x = lerpf(viewmodel.rotation.x, 0.0 + _vm_rot_offset.x, clampf(delta * 10.0, 0.0, 1.0))
		viewmodel.rotation.y = lerpf(viewmodel.rotation.y, _vm_rot_offset.y, clampf(delta * 10.0, 0.0, 1.0))
		viewmodel.rotation.z = lerpf(viewmodel.rotation.z, _vm_rot_offset.z, clampf(delta * 10.0, 0.0, 1.0))
	var h_speed: float = Vector3(owner_body.velocity.x, 0, owner_body.velocity.z).length()
	if owner_body.is_on_floor() and h_speed > 0.5 and not is_ads:
		_bob_t += delta * h_speed * 1.6
		effective_pos.y += sin(_bob_t * 2.0) * 0.008
		effective_pos.x += cos(_bob_t) * 0.006
	var w_pos: float = clampf(delta * 14.0, 0.0, 1.0)
	viewmodel.position = viewmodel.position.lerp(effective_pos, w_pos)


# ---------- 第一人称视模型（程序化拼装） ----------

func _build_viewmodel() -> void:
	if viewmodel:
		viewmodel.queue_free()
	viewmodel = Node3D.new()
	viewmodel.name = "Viewmodel"
	add_child(viewmodel)
	viewmodel.position = Vector3(0.27, -0.23, -0.5)

	var gun: Node3D = Node3D.new()
	viewmodel.add_child(gun)
	var metal: Material = Toon.make_material(GUNMETAL, true, 0.004)
	var accent_color: Color = Color(0.35, 0.42, 0.28)
	match weapon_id:
		"rifle": accent_color = Color(0.35, 0.42, 0.28)
		"dmr": accent_color = Color(0.55, 0.42, 0.28)
		"smg": accent_color = Color(0.25, 0.30, 0.40)
		"shotgun": accent_color = Color(0.55, 0.38, 0.16)
		"lmg": accent_color = Color(0.30, 0.34, 0.30)
		_: accent_color = Color(0.35, 0.42, 0.28)
	var accent: Material = Toon.make_material(accent_color, true, 0.004)

	var recv: MeshInstance3D = MeshInstance3D.new()
	var rb: BoxMesh = BoxMesh.new()
	rb.size = Vector3(0.07, 0.10, 0.40)
	recv.mesh = rb
	recv.material_override = metal
	gun.add_child(recv)

	var barrel: MeshInstance3D = MeshInstance3D.new()
	var bc: CylinderMesh = CylinderMesh.new()
	bc.top_radius = 0.016
	bc.bottom_radius = 0.016
	bc.height = 0.30 if weapon_id != "smg" else 0.18
	bc.radial_segments = 6
	barrel.mesh = bc
	barrel.material_override = metal
	barrel.rotation_degrees.x = 90.0
	barrel.position = Vector3(0, 0.015, -0.30)
	gun.add_child(barrel)

	var mag: MeshInstance3D = MeshInstance3D.new()
	var mb: BoxMesh = BoxMesh.new()
	mb.size = Vector3(0.05, 0.13, 0.07)
	mag.mesh = mb
	mag.material_override = accent
	mag.position = Vector3(0, -0.09, -0.03)
	mag.rotation_degrees.x = 12.0
	gun.add_child(mag)

	var stock: MeshInstance3D = MeshInstance3D.new()
	var sb: BoxMesh = BoxMesh.new()
	sb.size = Vector3(0.055, 0.085, 0.15)
	stock.mesh = sb
	stock.material_override = accent
	stock.position = Vector3(0, -0.01, 0.24)
	gun.add_child(stock)

	var sight: MeshInstance3D = MeshInstance3D.new()
	var kb: BoxMesh = BoxMesh.new()
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
	_flash.omni_range = 0.75 if is_player else 5.0
	_flash.omni_attenuation = 2.0
	muzzle.add_child(_flash)

	var skin: Material = Toon.make_material(Color(0.87, 0.70, 0.55), true, 0.003)
	var sleeve: Material = Toon.make_material(accent_color.darkened(0.15), true, 0.003)
	var hand_r: MeshInstance3D = MeshInstance3D.new()
	var hr: SphereMesh = SphereMesh.new()
	hr.radius = 0.045
	hr.height = 0.08
	hr.radial_segments = 8
	hr.rings = 4
	hand_r.mesh = hr
	hand_r.material_override = skin
	hand_r.scale = Vector3(0.9, 1.1, 1.3)
	hand_r.position = Vector3(0.005, -0.075, 0.10)
	gun.add_child(hand_r)
	var arm_r: MeshInstance3D = MeshInstance3D.new()
	var ar: CapsuleMesh = CapsuleMesh.new()
	ar.radius = 0.030
	ar.height = 0.24
	ar.radial_segments = 6
	arm_r.mesh = ar
	arm_r.material_override = sleeve
	arm_r.rotation_degrees = Vector3(-38.0, 0.0, -12.0)
	arm_r.position = Vector3(0.06, -0.28, 0.30)
	gun.add_child(arm_r)
	var hand_l: MeshInstance3D = MeshInstance3D.new()
	var hl: SphereMesh = SphereMesh.new()
	hl.radius = 0.042
	hl.height = 0.075
	hl.radial_segments = 8
	hl.rings = 4
	hand_l.mesh = hl
	hand_l.material_override = skin
	hand_l.scale = Vector3(1.0, 0.9, 1.2)
	hand_l.position = Vector3(-0.01, -0.035, -0.19)
	gun.add_child(hand_l)
	var arm_l: MeshInstance3D = MeshInstance3D.new()
	var al: CapsuleMesh = CapsuleMesh.new()
	al.radius = 0.030
	al.height = 0.24
	al.radial_segments = 6
	arm_l.mesh = al
	arm_l.material_override = sleeve
	arm_l.rotation_degrees = Vector3(-52.0, 22.0, 14.0)
	arm_l.position = Vector3(-0.13, -0.25, 0.02)
	gun.add_child(arm_l)
