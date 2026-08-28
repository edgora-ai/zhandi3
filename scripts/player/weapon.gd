class_name Weapon
extends Node3D
## 武器逻辑：hitscan 射击、扩散、后座、换弹、机瞄；玩家有视模型，bot 仅逻辑

signal ammo_changed(mag: int, reserve: int)
signal fired
signal reload_started
signal hit_landed

const WEAPONS := {
	"rifle": {
		"label": "突击步枪", "damage": 12.0, "head_mult": 2.0, "rpm": 540.0,
		"mag": 30, "start_reserve": 90, "spread": 1.3, "ads_spread": 0.45,
		"reload": 1.8, "auto": true, "zoom": 1.3, "range": 220.0, "recoil": 0.35,
	},
	"dmr": {
		"label": "射手步枪", "damage": 34.0, "head_mult": 2.2, "rpm": 150.0,
		"mag": 12, "start_reserve": 36, "spread": 0.8, "ads_spread": 0.12,
		"reload": 2.1, "auto": false, "zoom": 2.4, "range": 350.0, "recoil": 1.2,
	},
	"smg": {
		"label": "冲锋枪", "damage": 9.0, "head_mult": 1.8, "rpm": 800.0,
		"mag": 36, "start_reserve": 108, "spread": 2.0, "ads_spread": 1.0,
		"reload": 1.5, "auto": true, "zoom": 1.15, "range": 130.0, "recoil": 0.2,
	},
	"bow": {
		"label": "猎弓", "damage": 0.0, "head_mult": 1.0, "rpm": 60.0,
		"mag": 1, "start_reserve": 24, "spread": 0.0, "ads_spread": 0.0,
		"reload": 0.5, "auto": false, "zoom": 1.35, "range": 0.0, "recoil": 0.0,
	},
}

@export var base_fov := 75.0 # // FIX: M13 @export 可调—FOV可在编辑器实时调参；WEAPONS平衡表集中可调详见下
const GUNMETAL := Color(0.15, 0.16, 0.18) # // FIX: M13 武器数值WEAPONS集中表为关卡平衡可调源，策划可不改代码调参（reserve/mag/damage/spread等）
const BASE_FOV := 75.0

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


func label() -> String:
	return data.get("label", "波克剑")


func hold_trigger() -> void:
	if not data.get("auto", false):
		return
	_try_fire()


func pull_trigger() -> void:
	_try_fire()


func start_reload() -> void:
	if reloading or weapon_id == "" or mag_left >= data.mag or reserve <= 0:
		return
	reloading = true
	_reload_left = data.reload
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
	if mag_left <= 0:
		if is_player:
			start_reload()
		return
	_cool = 60.0 / data.rpm
	mag_left -= 1
	_fire_ray()
	last_shot_msec = Time.get_ticks_msec()
	_kick = 0.06
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
	var s := deg_to_rad(current_spread())
	dir = (dir + Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))).normalized()

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
			col.take_damage(dmg, owner_body, part)
			if col.has_method("is_plant"):
				FX.impact(end_point)
			else:
				FX.blood(end_point)
			if is_player:
				hit_landed.emit()
		else:
			FX.impact(end_point)
	FX.tracer(muzzle_world(), end_point)


func muzzle_world() -> Vector3:
	if is_player and muzzle:
		return muzzle.global_position
	return owner_body.get_aim_origin() + owner_body.get_aim_dir() * 0.6


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			reloading = false
			var need: int = data.mag - mag_left
			var take: int = mini(need, reserve)
			mag_left += take
			reserve -= take
			ammo_changed.emit(mag_left, reserve)
	if _flash and _flash.light_energy > 0.0:
		_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 24.0)
	if not is_player or viewmodel == null:
		return
	# 机瞄 / 腰射切换
	var cam: Camera3D = owner_body.camera
	var target_fov: float = BASE_FOV / (data.get("zoom", 1.0) if is_ads else 1.0)
	cam.fov = lerpf(cam.fov, target_fov, delta * 12.0)
	var target_pos := Vector3(0.0, -0.155, -0.35) if is_ads else Vector3(0.27, -0.23, -0.5)
	# 后座回弹
	_kick = maxf(0.0, _kick - delta * 0.5)
	target_pos.z += _kick
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
	var accent_color: Color = {"rifle": Color(0.35, 0.42, 0.28), "dmr": Color(0.55, 0.42, 0.28), "smg": Color(0.25, 0.30, 0.40)}[weapon_id]
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
	ar.radius = 0.038
	ar.height = 0.30
	ar.radial_segments = 6
	arm_r.mesh = ar
	arm_r.material_override = sleeve
	arm_r.rotation_degrees = Vector3(-38.0, 0.0, -12.0)
	arm_r.position = Vector3(0.06, -0.24, 0.26)
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
	al.radius = 0.038
	al.height = 0.30
	al.radial_segments = 6
	arm_l.mesh = al
	arm_l.material_override = sleeve
	arm_l.rotation_degrees = Vector3(-52.0, 22.0, 14.0)
	arm_l.position = Vector3(-0.12, -0.21, -0.02)
	gun.add_child(arm_l)
