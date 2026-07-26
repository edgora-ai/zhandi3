class_name LootChest
extends StaticBody3D
## 古代宝箱：藏防具。E 开箱一次，盖子翻开、金光冒出、给一件防具。

var item := "armor_soldier"
var opened := false
var _lid: Node3D


static func create(parent: Node, pos: Vector3, p_item: String, yaw: float = 0.0) -> LootChest:
	var c := LootChest.new()
	c.item = p_item
	parent.add_child(c)
	c.global_position = pos
	c.rotation.y = yaw
	return c


func _ready() -> void:
	add_to_group("loot_chest")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.6, 0.6)
	col.shape = shape
	col.position.y = 0.3
	add_child(col)
	var wood := Toon.make_material(Color(0.30, 0.20, 0.10), true, 0.012)
	var gold := Toon.make_material(Color(0.72, 0.55, 0.20), true, 0.008)
	# 箱体与描金边。
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.45, 0.6)
	body.mesh = bm
	body.material_override = wood
	body.position.y = 0.225
	add_child(body)
	for sy in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.10, 0.47, 0.64)
		band.mesh = sm
		band.material_override = gold
		band.position = Vector3(sy * 0.28, 0.225, 0)
		add_child(band)
	# 盖子（开启时后翻）。
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.45, 0.30)
	add_child(_lid)
	var lid_mesh := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.9, 0.10, 0.6)
	lid_mesh.mesh = lm
	lid_mesh.material_override = wood
	lid_mesh.position = Vector3(0, 0.05, -0.30)
	_lid.add_child(lid_mesh)
	# 发光锁孔。
	var lock := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.12, 0.14, 0.05)
	lock.mesh = km
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.albedo_color = Color(0.10, 0.85, 0.80)
	lmat.emission_enabled = true
	lmat.emission = Color(0.05, 0.90, 0.80)
	lmat.emission_energy_multiplier = 1.8
	lock.material_override = lmat
	lock.position = Vector3(0, 0.32, -0.32)
	add_child(lock)


func open(player: Player) -> void:
	if opened:
		return
	opened = true
	player.give_item(item, 1)
	var labels := {"armor_soldier": "士兵铠甲", "armor_climber": "攀爬者手套", "armor_barbarian": "蛮族护符"}
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("宝箱：获得 %s！（背包里使用即装备）" % str(labels.get(item, item)))
	FX.impact(global_position + Vector3(0, 0.7, 0))
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play("pickup", -4.0)
	# 盖子后翻。
	var tween := create_tween()
	tween.tween_property(_lid, "rotation_degrees:x", -105.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
