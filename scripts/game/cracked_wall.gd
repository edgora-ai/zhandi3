class_name CrackedWall
extends StaticBody3D
## 可炸开的裂岩：遥控炸弹轰开（近战重击也能慢慢砍开），崩落后露出洞窟奖励。
## 崩落奖励：reward="orb" 精灵宝珠 / "monster_part" 怪物材料 / "meat" 兽肉。

var hp := 35.0
var reward := "orb"
var _broken := false
var _size := Vector3(4.5, 3.2, 1.0)


static func create(parent: Node, pos: Vector3, yaw: float, size: Vector3, p_reward: String) -> CrackedWall:
	var w := CrackedWall.new()
	w._size = size
	w.reward = p_reward
	w.position = pos
	w.rotation.y = yaw
	parent.add_child(w)
	w._build()
	return w


func _build() -> void:
	collision_layer = 1
	add_to_group("crackable")
	var stone := Toon.make_material(Color(0.36, 0.38, 0.40), true, 0.014)
	var crack_mat := Toon.make_material(Color(0.08, 0.08, 0.09), true, 0.006)
	# 三块略有错动的岩板拼出墙体，裂缝用深色细条表达（旷野之息的可炸岩标志）。
	for i in range(3):
		var slab := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(_size.x / 3.0 - 0.06, _size.y * (0.94 + 0.05 * (i % 2)), _size.z)
		slab.mesh = mesh
		slab.material_override = stone
		slab.position = Vector3((i - 1) * _size.x / 3.0, _size.y * 0.5 + 0.04 * ((i + 1) % 2), 0)
		add_child(slab)
		var crack := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.10, _size.y * 0.9, _size.z + 0.04)
		crack.mesh = cm
		crack.material_override = crack_mat
		crack.position = slab.position + Vector3(_size.x / 6.0 - 0.02, 0, 0)
		crack.rotation_degrees.z = 12.0 if i % 2 == 0 else -9.0
		add_child(crack)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _size
	col.shape = shape
	col.position.y = _size.y * 0.5
	add_child(col)


func take_damage(amount: float, _from: Variant = null, _part_name: String = "body") -> void:
	if _broken:
		return
	hp -= amount
	FX.impact(global_position + Vector3(randf_range(-1, 1), _size.y * 0.6, randf_range(-0.5, 0.5)), Color(0.6, 0.6, 0.62))
	if hp <= 0.0:
		_break_apart()


func _break_apart() -> void:
	_broken = true
	var scene := get_tree().current_scene
	# 崩落：碎石块向外飞出，随后露出洞窟奖励。
	for i in range(6):
		var debris := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3.ONE * randf_range(0.3, 0.62)
		debris.mesh = dm
		debris.material_override = Toon.make_material(Color(0.36, 0.38, 0.40), true, 0.012)
		scene.add_child(debris)
		debris.global_position = global_position + Vector3(randf_range(-1.2, 1.2), randf_range(0.4, _size.y), 0)
		var target := debris.global_position + Vector3(randf_range(-3.5, 3.5), randf_range(1.0, 2.6), randf_range(-2.5, 3.5))
		var tw := debris.create_tween()
		tw.set_parallel(true)
		tw.tween_property(debris, "global_position", target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(debris, "scale", Vector3.ONE * 0.2, 0.8)
		tw.chain().tween_callback(debris.queue_free)
	FX.impact(global_position + Vector3(0, _size.y * 0.5, 0), Color(0.7, 0.68, 0.62))
	var back := global_transform.basis.z * 1.2
	match reward:
		"orb":
			Loot.spawn(scene, global_position + back, "orb", "", 1, 3)
		"monster_part":
			Loot.spawn(scene, global_position + back, "monster_part", "", 3, 2)
		"meat":
			Loot.spawn(scene, global_position + back, "meat", "", 2, 2)
	if scene and scene.get("hud") != null:
		scene.hud.add_feed("裂岩崩开了！")
	queue_free()
