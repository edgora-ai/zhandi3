class_name Loot
extends Node3D
## 地面战利品：武器/护甲/医疗包/弹药，彩色光柱标识

const RARITY_COLOR := {1: Color(0.85, 0.85, 0.85), 2: Color(0.30, 0.60, 1.0), 3: Color(0.75, 0.35, 1.0)}

var kind := "weapon"          # weapon | armor | medkit | ammo | mushroom | meat | dragon_scale
var weapon_id := "rifle"
var amount := 0               # 护甲值/治疗量/弹药数
var rarity := 1
var consumed := false

var _item: Node3D
var _t := 0.0


static func spawn(parent: Node, pos: Vector3, p_kind: String, p_weapon_id: String = "", p_amount: int = 0, p_rarity: int = 1) -> Loot:
	var l := Loot.new()
	l.kind = p_kind
	l.weapon_id = p_weapon_id
	l.amount = p_amount
	l.rarity = p_rarity
	l.position = pos
	parent.add_child(l)
	return l


func _ready() -> void:
	add_to_group("loot")
	_build_visual()


func _build_visual() -> void:
	# 光柱
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.22
	bc.bottom_radius = 0.22
	bc.height = 9.0
	bc.radial_segments = 10
	bc.cap_top = false
	bc.cap_bottom = false
	beam.mesh = bc
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rc: Color = RARITY_COLOR[rarity]
	bm.albedo_color = Color(rc.r, rc.g, rc.b, 0.09)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.position.y = 4.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	# 物品本体
	_item = Node3D.new()
	_item.position.y = 0.55
	add_child(_item)
	match kind:
		"weapon":
			_build_weapon_model(rc)
		"armor":
			_build_box(Vector3(0.42, 0.5, 0.16), Color(0.25, 0.45, 0.85))
		"medkit":
			_build_box(Vector3(0.4, 0.22, 0.4), Color(0.92, 0.92, 0.92))
			_build_box(Vector3(0.26, 0.08, 0.1), Color(0.85, 0.15, 0.12), Vector3(0, 0.12, 0))
			_build_box(Vector3(0.1, 0.08, 0.26), Color(0.85, 0.15, 0.12), Vector3(0, 0.12, 0))
		"ammo":
			_build_box(Vector3(0.34, 0.2, 0.24), Color(0.45, 0.38, 0.2))
		"mushroom":
			_build_mushroom()
		"meat":
			_build_box(Vector3(0.52, 0.25, 0.36), Color(0.72, 0.18, 0.13))
			_build_box(Vector3(0.18, 0.12, 0.48), Color(0.94, 0.78, 0.62), Vector3(0.28, 0, 0))
		"dragon_scale":
			_build_scale()
		"wood":
			_build_log()
		"seed":
			_build_seed()
		"orb":
			_build_orb()
		"fairy":
			_build_fairy()
		"master_sword":
			_build_master_sword()
		"monster_part":
			_build_horn()


func _build_box(size: Vector3, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = Toon.make_material(color, true, 0.008)
	mi.position = offset
	_item.add_child(mi)


func _build_weapon_model(rc: Color) -> void:
	_build_box(Vector3(0.09, 0.13, 0.62), Color(0.16, 0.17, 0.19))
	_build_box(Vector3(0.06, 0.2, 0.09), rc, Vector3(0, -0.13, -0.05))
	_build_box(Vector3(0.07, 0.1, 0.2), rc, Vector3(0, -0.02, 0.32))


# 怪物材料：小兽角（两根斜交叉的骨锥）。
func _build_horn() -> void:
	var mat := Toon.make_material(Color(0.88, 0.84, 0.72), true, 0.008)
	for sx in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.02
		hm.bottom_radius = 0.07
		hm.height = 0.42
		hm.radial_segments = 7
		horn.mesh = hm
		horn.material_override = mat
		horn.position = Vector3(sx * 0.10, 0.05, 0)
		horn.rotation_degrees = Vector3(35.0, 0.0, sx * 22.0)
		_item.add_child(horn)


func _build_mushroom() -> void:
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.07
	stem_mesh.bottom_radius = 0.10
	stem_mesh.height = 0.34
	stem_mesh.radial_segments = 8
	stem.mesh = stem_mesh
	stem.material_override = Toon.make_material(Color(0.91, 0.82, 0.62), true, 0.006)
	_item.add_child(stem)
	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.25
	cap_mesh.height = 0.28
	cap_mesh.radial_segments = 10
	cap_mesh.rings = 5
	cap.mesh = cap_mesh
	cap.material_override = Toon.make_material(Color(0.20, 0.68, 0.62), true, 0.008)
	cap.position.y = 0.20
	cap.scale = Vector3(1.25, 0.72, 1.25)
	_item.add_child(cap)


func _build_scale() -> void:
	var scale_mesh := SphereMesh.new()
	scale_mesh.radius = 0.30
	scale_mesh.height = 0.60
	scale_mesh.radial_segments = 10
	scale_mesh.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = scale_mesh
	mi.material_override = Toon.make_material(Color(0.08, 0.78, 0.74), true, 0.01)
	mi.scale = Vector3(0.38, 1.0, 0.72)
	mi.rotation_degrees.z = 28.0
	_item.add_child(mi)


func _build_log() -> void:
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.15
	log_mesh.bottom_radius = 0.17
	log_mesh.height = 0.85
	log_mesh.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = log_mesh
	mi.material_override = Toon.make_material(Color(0.45, 0.31, 0.16), true, 0.008)
	mi.rotation_degrees.z = 84.0
	_item.add_child(mi)
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.155
	ring_mesh.bottom_radius = 0.155
	ring_mesh.height = 0.06
	ring_mesh.radial_segments = 8
	ring.mesh = ring_mesh
	ring.material_override = Toon.make_material(Color(0.62, 0.46, 0.25), true, 0.006)
	ring.rotation_degrees.z = 84.0
	ring.position = Vector3(-0.28, 0.02, 0)
	_item.add_child(ring)


func _build_seed() -> void:
	# 呀哈哈式金种子：自发光小金球 + 两片小叶。
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.85, 0.25)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.15)
	gold.emission_energy_multiplier = 1.6
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.32
	core_mesh.radial_segments = 10
	core_mesh.rings = 6
	core.mesh = core_mesh
	core.material_override = gold
	_item.add_child(core)
	for sx in [-1.0, 1.0]:
		var leaf := MeshInstance3D.new()
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(0.05, 0.02, 0.22)
		leaf.mesh = leaf_mesh
		leaf.material_override = Toon.make_material(Color(0.35, 0.65, 0.2), false)
		leaf.position = Vector3(sx * 0.1, 0.16, 0)
		leaf.rotation_degrees = Vector3(-25, 0, sx * -30)
		_item.add_child(leaf)


func _build_orb() -> void:
	# 精灵宝珠：青色自发光小球 + 环绕光带。
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.30, 0.90, 0.80)
	glow.emission_enabled = true
	glow.emission = Color(0.15, 0.95, 0.80)
	glow.emission_energy_multiplier = 2.2
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.44
	core_mesh.radial_segments = 12
	core_mesh.rings = 7
	core.mesh = core_mesh
	core.material_override = glow
	_item.add_child(core)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.03
	ring_mesh.outer_radius = 0.36
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.material_override = glow
	ring.rotation_degrees.x = 70.0
	_item.add_child(ring)


func _build_fairy() -> void:
	# 小精灵：粉色发光小球 + 四片透明翅翼。
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.55, 0.75)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.40, 0.65)
	glow.emission_energy_multiplier = 2.4
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.14
	core_mesh.height = 0.28
	core_mesh.radial_segments = 10
	core_mesh.rings = 6
	core.mesh = core_mesh
	core.material_override = glow
	_item.add_child(core)
	var wing_mat := StandardMaterial3D.new()
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat.albedo_color = Color(1.0, 0.9, 1.0, 0.5)
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(0.16, 0.02, 0.10)
			wing.mesh = wm
			wing.material_override = wing_mat
			wing.position = Vector3(sx * 0.12, 0.06, sz * 0.06)
			wing.rotation_degrees.z = sx * -25.0
			_item.add_child(wing)


func _build_master_sword() -> void:
	# 古代剑：金色剑身插在小石台上。
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(0.95, 0.85, 0.45)
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.75, 0.3)
	gold.emission_energy_multiplier = 1.4
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.85, 0.12)
	blade.mesh = bm
	blade.material_override = gold
	blade.position.y = 0.55
	blade.rotation_degrees.z = 12.0
	_item.add_child(blade)
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.22, 0.05, 0.16)
	guard.mesh = gm
	guard.material_override = Toon.make_material(Color(0.20, 0.18, 0.22), true, 0.006)
	guard.position = Vector3(0.05, 0.16, 0)
	guard.rotation_degrees.z = 12.0
	_item.add_child(guard)
	var stone := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.5, 0.22, 0.5)
	stone.mesh = sm
	stone.material_override = Toon.make_material(Color(0.45, 0.47, 0.44), true, 0.010)
	stone.position.y = -0.06
	_item.add_child(stone)


func _process(delta: float) -> void:
	if consumed:
		return
	_t += delta
	_item.rotation.y = _t * 1.6
	_item.position.y = 0.55 + sin(_t * 2.2) * 0.1


func describe() -> String:
	match kind:
		"weapon":
			return Weapon.WEAPONS[weapon_id].label
		"armor":
			return "护甲 +%d" % amount
		"medkit":
			return "医疗包 +%d" % amount
		"ammo":
			return "弹药 +%d" % amount
		"mushroom":
			return "海拉鲁蘑菇 ×%d（收入背包）" % amount
		"meat":
			return "兽肉 ×%d（收入背包）" % amount
		"dragon_scale":
			return "龙鳞 ×%d（收入背包）" % amount
		"wood":
			return "木材 ×%d（收入背包）" % amount
		"seed":
			return "海拉鲁种子（闪光）"
		"orb":
			return "精灵宝珠（生命上限 +10）"
		"fairy":
			return "小精灵（死亡时复活一次）"
		"master_sword":
			return "古代剑（近战伤害 42）"
	return ""


func apply_to(target: CharacterBody3D) -> void:
	if consumed:
		return
	match kind:
		"weapon":
			if target.has_method("give_weapon"):
				target.give_weapon(weapon_id)
		"armor":
			target.armor = minf(100.0, target.armor + amount)
			if target.has_signal("health_changed"):
				target.health_changed.emit(target.hp, target.armor)
		"medkit":
			var cap := 100.0
			if "max_hp" in target:
				cap = float(target.get("max_hp"))
			target.hp = minf(cap, target.hp + amount)
			if target.has_signal("health_changed"):
				target.health_changed.emit(target.hp, target.armor)
		"ammo":
			if target.has_method("give_ammo"):
				target.give_ammo(amount)
		"mushroom", "meat", "dragon_scale", "wood", "monster_part":
			if target.has_method("give_item"):
				target.give_item(kind, amount)
		"seed":
			if target.has_method("collect_seed"):
				target.collect_seed()
		"orb":
			if target.has_method("collect_orb"):
				target.collect_orb()
		"fairy":
			if target.get("fairies") != null:
				target.fairies += 1
				if target.hud:
					target.hud.add_feed("捉到一只小精灵（共 %d 只）" % int(target.fairies))
		"master_sword":
			if target.has_method("equip_master_sword"):
				target.equip_master_sword()
	consumed = true
	if target is Player:
		var sfx := target.get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.play("pickup")
	queue_free()
