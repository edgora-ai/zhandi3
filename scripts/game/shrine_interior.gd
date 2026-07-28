class_name ShrineInterior
extends Node3D
## 神庙地底石室：试炼完成后从神庙门进入的古代石厅。
## 中央是置有精灵宝珠的导师台座，入口/出口法阵双向传送（旷野之息式导师房）。

var trial: ShrineTrial
var door_pos := Vector3.ZERO
var _exit_area: Area3D


static func create(parent: Node, origin: Vector3, p_trial: ShrineTrial, p_door: Vector3) -> ShrineInterior:
	var si := ShrineInterior.new()
	si.trial = p_trial
	si.door_pos = p_door
	parent.add_child(si)
	si.global_position = origin
	si._build()
	return si


func entry_point() -> Vector3:
	return global_transform * Vector3(0, 0.3, -3.5)


func _build() -> void:
	var stone := Toon.make_material(Color(0.30, 0.33, 0.36), true, 0.014)
	var stone_dark := Toon.make_material(Color(0.16, 0.18, 0.21), true, 0.012)
	var ancient := StandardMaterial3D.new()
	ancient.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ancient.albedo_color = Color(0.045, 0.90, 0.82)
	ancient.emission_enabled = true
	ancient.emission = Color(0.02, 0.96, 0.84)
	ancient.emission_energy_multiplier = 2.4
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	# 16x12 石厅：地板/天花/四面墙。
	_part(Vector3(16, 0.5, 12), stone_dark, Vector3(0, -0.25, 0), stone, body)
	_part(Vector3(16, 0.5, 12), stone_dark, Vector3(0, 5.45, 0), stone, body)
	_part(Vector3(16, 5.4, 0.5), stone, Vector3(0, 2.45, 6), stone, body)
	_part(Vector3(16, 5.4, 0.5), stone, Vector3(0, 2.45, -6), stone, body)
	_part(Vector3(0.5, 5.4, 12), stone, Vector3(-8, 2.45, 0), stone, body)
	_part(Vector3(0.5, 5.4, 12), stone, Vector3(8, 2.45, 0), stone, body)
	# 四角符柱与墙面符文带：古代科技的青色冷光。
	for cx in [-6.8, 6.8]:
		for cz in [-4.8, 4.8]:
			_part(Vector3(0.6, 4.6, 0.6), stone_dark, Vector3(cx, 2.3, cz), stone, body)
			_part(Vector3(0.10, 2.4, 0.12), stone_dark, Vector3(cx * 0.96, 2.2, cz * 0.96), ancient, body)
	for i in range(6):
		_part(Vector3(0.14, 1.6, 0.10), stone_dark, Vector3(-6.0 + i * 2.4, 3.6, 5.72), ancient, body)
	# 后墙巨型发光圆徽与环绕符文，石室的视觉中心。
	var emblem := MeshInstance3D.new()
	var em := CylinderMesh.new()
	em.top_radius = 1.3
	em.bottom_radius = 1.3
	em.height = 0.12
	em.radial_segments = 24
	emblem.mesh = em
	emblem.material_override = ancient
	emblem.rotation_degrees.x = 90.0
	emblem.position = Vector3(0, 2.9, 5.68)
	add_child(emblem)
	for i in range(8):
		var ang := i * TAU / 8.0
		var rune := _part(Vector3(0.12, 0.55, 0.10), stone_dark, Vector3(sin(ang) * 2.1, 2.9 + cos(ang) * 2.1, 5.70), ancient, body)
		rune.rotation_degrees.z = rad_to_deg(-ang)
	# 导师台座与台上的精灵宝珠（试炼完成的奖励，只有解锁石门后才能拿到）。
	_part(Vector3(1.4, 0.3, 1.4), stone_dark, Vector3(0, 0.15, 3.6), stone, body)
	var pedestal := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.65
	pm.height = 1.1
	pm.radial_segments = 12
	pedestal.mesh = pm
	pedestal.material_override = stone
	pedestal.position = Vector3(0, 0.85, 3.6)
	add_child(pedestal)
	_part(Vector3(0.9, 0.12, 0.9), stone_dark, Vector3(0, 1.44, 3.6), ancient, body)
	Loot.spawn(get_tree().current_scene, global_transform * Vector3(0, 1.9, 3.6), "orb", "", 1, 3)
	# 入口法阵（落点）与出口法阵（站上去 E 离开）。
	_ring(Vector3(0, 0.10, -3.5), ancient)
	_ring(Vector3(-4.0, 0.10, -3.5), ancient)
	_exit_area = Area3D.new()
	var ecol := CollisionShape3D.new()
	var eshape := SphereShape3D.new()
	eshape.radius = 1.3
	ecol.shape = eshape
	_exit_area.add_child(ecol)
	_exit_area.position = Vector3(-4.0, 0.5, -3.5)
	add_child(_exit_area)
	_exit_area.body_entered.connect(_on_exit_pad_enter)
	_exit_area.body_exited.connect(_on_exit_pad_exit)
	# 两盏青色点光支撑石室氛围（全局环境光在这里几乎为零）。
	for lz in [-3.0, 3.5]:
		var light := OmniLight3D.new()
		light.light_color = Color(0.15, 0.85, 0.75)
		light.light_energy = 1.4
		light.omni_range = 11.0
		light.position = Vector3(0, 4.4, lz)
		add_child(light)


func _part(size: Vector3, _mat_dark: Material, pos: Vector3, mat: Material, body: StaticBody3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if body:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		body.add_child(col)
	return mi


func _ring(pos: Vector3, mat: Material) -> void:
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.10
	rm.outer_radius = 1.15
	rm.rings = 20
	rm.ring_segments = 8
	ring.mesh = rm
	ring.material_override = mat
	ring.rotation_degrees.x = 90.0
	ring.position = pos
	add_child(ring)


func _on_exit_pad_enter(body: Node) -> void:
	if body is Player:
		body.nearby_shrine_exit = self


func _on_exit_pad_exit(body: Node) -> void:
	if body is Player and body.nearby_shrine_exit == self:
		body.nearby_shrine_exit = null


func leave(player: Player) -> void:
	var scene := get_tree().current_scene
	player.nearby_shrine_exit = null
	if scene and scene.get("hud") != null:
		var back := door_pos
		scene.hud.fade_transition(func() -> void:
			player.global_position = back
			player.velocity = Vector3.ZERO
		)
