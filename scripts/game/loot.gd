class_name Loot
extends Node3D
## 地面战利品：武器/护甲/医疗包/弹药，彩色光柱标识

const RARITY_COLOR := {1: Color(0.85, 0.85, 0.85), 2: Color(0.30, 0.60, 1.0), 3: Color(0.75, 0.35, 1.0)}

var kind := "weapon"          # weapon | armor | medkit | ammo
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
			target.hp = minf(100.0, target.hp + amount)
			if target.has_signal("health_changed"):
				target.health_changed.emit(target.hp, target.armor)
		"ammo":
			if target.has_method("give_ammo"):
				target.give_ammo(amount)
	consumed = true
	if target is Player:
		var sfx := target.get_tree().get_first_node_in_group("sfx_bank")
		if sfx:
			sfx.play("pickup")
	queue_free()
