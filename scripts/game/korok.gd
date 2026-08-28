class_name Korok
extends Node3D
## 探索精灵小精灵：谜题解开时从原地蹦出，挥手蹦跳几秒后缩小消失。

var _t := 0.0
var _arm_l: Node3D
var _arm_r: Node3D
var _body: Node3D


# 在 pos 处蹦出一只探索精灵，并朝向 face（通常是玩家）。
static func spawn(parent: Node, pos: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	var k := Korok.new()
	parent.add_child(k)
	k.global_position = pos
	var look := face - pos
	look.y = 0.0
	if look.length_squared() > 0.01:
		k.rotation.y = atan2(look.normalized().x, look.normalized().z) + PI
	DamageNumber.spawn_at(parent, pos + Vector3(0, 1.30, 0), "解谜成功！", Color(0.75, 1.0, 0.45))


func _ready() -> void:
	_build()


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var wood := Toon.make_material(Color(0.48, 0.32, 0.16), true, 0.010)
	var wood_dark := Toon.make_material(Color(0.30, 0.19, 0.09), true, 0.008)
	var leaf := Toon.make_material(Color(0.35, 0.62, 0.20), true, 0.008)
	var dark := Toon.make_material(Color(0.08, 0.07, 0.05), false)
	# 圆木身体与两道树皮环纹。
	var trunk := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.20
	tm.height = 0.52
	tm.radial_segments = 10
	tm.rings = 5
	trunk.mesh = tm
	trunk.material_override = wood
	trunk.position.y = 0.30
	_body.add_child(trunk)
	for i in range(2):
		var ring := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.205
		rm.bottom_radius = 0.205
		rm.height = 0.035
		rm.radial_segments = 10
		ring.mesh = rm
		ring.material_override = wood_dark
		ring.position.y = 0.16 + i * 0.22
		_body.add_child(ring)
	# 叶面具：大叶片遮脸，露出双眼。
	var mask := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.19
	mm.height = 0.38
	mm.radial_segments = 9
	mm.rings = 5
	mask.mesh = mm
	mask.material_override = leaf
	mask.position = Vector3(0, 0.48, -0.14)
	mask.scale = Vector3(0.85, 1.15, 0.45)
	_body.add_child(mask)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.035
		em.height = 0.07
		em.radial_segments = 7
		em.rings = 4
		eye.mesh = em
		eye.material_override = dark
		eye.position = Vector3(sx * 0.07, 0.50, -0.235)
		_body.add_child(eye)
	# 头顶小芽。
	var sprout := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.005
	sm.bottom_radius = 0.02
	sm.height = 0.14
	sm.radial_segments = 6
	sprout.mesh = sm
	sprout.material_override = wood_dark
	sprout.position = Vector3(0, 0.66, 0.02)
	_body.add_child(sprout)
	var bud := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.07
	bm.height = 0.14
	bm.radial_segments = 7
	bm.rings = 4
	bud.mesh = bm
	bud.material_override = leaf
	bud.position = Vector3(0.03, 0.74, 0.02)
	bud.scale = Vector3(1.0, 0.5, 0.7)
	_body.add_child(bud)
	# 细枝手臂与叶片手掌：举过头顶挥手。
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.20, 0.40, 0)
		_body.add_child(arm)
		var twig := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.028
		cm.height = 0.24
		cm.radial_segments = 6
		twig.mesh = cm
		twig.material_override = wood_dark
		twig.position.y = 0.10
		arm.add_child(twig)
		var hand := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.06
		hm.height = 0.12
		hm.radial_segments = 7
		hand.mesh = hm
		hand.material_override = leaf
		hand.position = Vector3(0, 0.24, 0)
		hand.scale = Vector3(1.0, 0.6, 0.8)
		arm.add_child(hand)
		if sx < 0.0:
			_arm_l = arm
		else:
			_arm_r = arm
	# 两只小脚。
	for sx in [-1.0, 1.0]:
		var foot := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.045
		fm.height = 0.12
		fm.radial_segments = 6
		foot.mesh = fm
		foot.material_override = wood_dark
		foot.position = Vector3(sx * 0.09, 0.02, 0)
		_body.add_child(foot)
	scale = Vector3.ONE * 0.01


func _process(delta: float) -> void:
	_t += delta
	# 蹦出时带回弹放大，退场时快速缩小。
	var s := 1.0
	if _t < 0.45:
		var u := _t / 0.45 - 1.0
		s = 1.0 + 2.4 * u * u * u + 1.4 * u * u
	elif _t > 3.6:
		s = maxf(0.01, 1.0 - (_t - 3.6) / 0.4)
	scale = Vector3.ONE * s
	# 双手挥摆、原地小蹦、身体轻转。
	_arm_l.rotation.z = 2.4 + sin(_t * 9.0) * 0.5
	_arm_r.rotation.z = -2.4 - sin(_t * 9.0 + 0.6) * 0.5
	_body.position.y = absf(sin(_t * 4.5)) * 0.12
	_body.rotation.y = sin(_t * 2.2) * 0.25
	if _t > 4.0:
		queue_free()
