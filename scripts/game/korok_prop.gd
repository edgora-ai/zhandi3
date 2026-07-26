class_name KorokProp
extends StaticBody3D
## 呀哈哈式小谜题：风车（射中会爆出种子）与可疑怪石（推倒露出种子）。

var mode := "pinwheel"
var consumed := false
var _spin := 0.0
var _blades: Node3D
var _tipped := false


func configure(p_mode: String) -> void:
	mode = p_mode
	add_to_group("korok")
	collision_layer = 4
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	col.shape = shape
	col.position.y = 1.2 if mode == "pinwheel" else 0.3
	add_child(col)
	if mode == "pinwheel":
		_build_pinwheel()
	else:
		_build_rock()


func _build_pinwheel() -> void:
	var wood := Toon.make_material(Color(0.42, 0.28, 0.14), true, 0.010)
	var petal := Toon.make_material(Color(0.92, 0.45, 0.30), true, 0.008)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.045
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = 1.6
	pole_mesh.radial_segments = 7
	pole.mesh = pole_mesh
	pole.material_override = wood
	pole.position.y = 0.8
	add_child(pole)
	_blades = Node3D.new()
	_blades.position = Vector3(0, 1.55, 0)
	add_child(_blades)
	for i in range(6):
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.16, 0.02, 0.42)
		blade.mesh = bm
		blade.material_override = petal
		var a := float(i) * TAU / 6.0
		blade.position = Vector3(cos(a) * 0.24, 0, sin(a) * 0.24)
		blade.rotation.y = -a + PI * 0.5
		blade.rotation.z = 0.3
		_blades.add_child(blade)


func _build_rock() -> void:
	var stone := Toon.make_material(Color(0.50, 0.52, 0.48), true, 0.014)
	var moss := Toon.make_material(Color(0.30, 0.50, 0.16), true, 0.008)
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.42
	bm.height = 0.7
	bm.radial_segments = 9
	bm.rings = 5
	body.mesh = bm
	body.material_override = stone
	body.position.y = 0.25
	body.scale = Vector3(1.0, 0.75, 1.0)
	add_child(body)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.3
	cm.height = 0.5
	cm.radial_segments = 8
	cm.rings = 4
	cap.mesh = cm
	cap.material_override = moss
	cap.position = Vector3(0.05, 0.5, 0)
	cap.scale = Vector3(1.0, 0.35, 1.0)
	add_child(cap)


func is_plant() -> bool:
	return true


func get_hit_part(_idx: int) -> String:
	return "body"


func take_damage(_amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if consumed:
		return
	consumed = true
	var scene := get_tree().current_scene
	if mode == "pinwheel":
		_spin = 6.0
		if scene and scene.get("hud") != null:
			scene.hud.add_feed("风车疾转——有什么飞出来了！")
	else:
		_tipped = true
		if scene and scene.get("hud") != null:
			scene.hud.add_feed("怪石翻倒，下面藏着什么！")
	Loot.spawn(scene, global_position + Vector3(0, 0.8, 0), "seed", "", 1, 3)


func _process(delta: float) -> void:
	if mode == "pinwheel":
		_spin = move_toward(_spin, 0.4, delta * 0.8)
		if _blades:
			_blades.rotation.y += delta * _spin * 4.0
	elif _tipped and rotation.z > -1.5:
		rotation.z -= delta * 2.2
