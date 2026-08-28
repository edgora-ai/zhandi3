class_name FlowerTrail
extends Node3D
## 花径探索精灵：按顺序碰完一串发光花，出种子。

var player: Player
var completed := false
var _flowers: Array[MeshInstance3D] = []
var _next := 0
var _t := 0.0


func configure(p_player: Player, points: Array) -> void:
	player = p_player
	add_to_group("flower_trail")
	for i in range(points.size()):
		var flower := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.22
		fm.height = 0.3
		fm.radial_segments = 8
		fm.rings = 5
		flower.mesh = fm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.55, 0.75)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.65)
		mat.emission_energy_multiplier = 1.6
		flower.material_override = mat
		flower.position = points[i]
		flower.scale = Vector3(1.0, 0.6, 1.0)
		add_child(flower)
		_flowers.append(flower)


func _process(delta: float) -> void:
	if completed or player == null:
		return
	_t += delta
	# 当前目标花脉冲高亮，其余常态。
	for i in range(_flowers.size()):
		var s := 1.0 + (sin(_t * 5.0) * 0.35 if i == _next else 0.0)
		_flowers[i].scale = Vector3(s, 0.6 * s, s)
	if _next < _flowers.size() and player.global_position.distance_to(global_position + _flowers[_next].position) < 1.3:
		_flowers[_next].visible = false
		_next += 1
		if _next >= _flowers.size():
			completed = true
			Loot.spawn(get_tree().current_scene, global_position + _flowers[_flowers.size() - 1].position + Vector3(0, 0.6, 0), "seed", "", 1, 3)
			Korok.spawn(get_tree().current_scene, global_position + _flowers[_flowers.size() - 1].position, player.global_position)
			var scene := get_tree().current_scene
			if scene and scene.get("hud") != null:
				scene.hud.add_feed("花径走到了尽头！")
