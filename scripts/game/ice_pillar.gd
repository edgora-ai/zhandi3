class_name IcePillar
extends StaticBody3D
## 制冰冰柱：河床生根的六角冰柱，顶出水面 1m，可站立渡河。至多 3 根，超出顶替最旧。

var _body: Node3D


static func create(parent: Node, base_pos: Vector3, height: float) -> IcePillar:
	var p := IcePillar.new()
	parent.add_child(p)
	p.global_position = base_pos
	p._build(height)
	return p


func _build(h: float) -> void:
	# _body 以柱底为原点，mesh/碰撞按 h 放置；升起时整体 scale.y 从 0 拉长。
	_body = Node3D.new()
	add_child(_body)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.9
	shape.height = h
	col.shape = shape
	col.position.y = h * 0.5
	_body.add_child(col)
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.60, 0.82, 0.94, 0.55)
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.roughness = 0.12
	ice_mat.emission_enabled = true
	ice_mat.emission = Color(0.30, 0.50, 0.60)
	ice_mat.emission_energy_multiplier = 0.35
	var body_mesh := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.82
	bm.bottom_radius = 0.95
	bm.height = h
	bm.radial_segments = 6
	body_mesh.mesh = bm
	body_mesh.material_override = ice_mat
	body_mesh.position.y = h * 0.5
	_body.add_child(body_mesh)
	# 顶部霜盖。
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.86
	cm.bottom_radius = 0.82
	cm.height = 0.10
	cm.radial_segments = 6
	cap.mesh = cm
	cap.material_override = Toon.make_material(Color(0.88, 0.95, 0.98), true, 0.008)
	cap.position.y = h + 0.03
	_body.add_child(cap)
	# 升起动画。
	_body.scale.y = 0.02
	var tween := create_tween()
	tween.tween_property(_body, "scale:y", 1.0, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func shatter() -> void:
	FX.impact(global_position + Vector3(0, 1.0, 0))
	var tween := create_tween()
	tween.tween_property(_body, "scale:y", 0.02, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
