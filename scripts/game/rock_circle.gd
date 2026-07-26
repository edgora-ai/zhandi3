class_name RockCircle
extends Node3D
## 石头阵呀哈哈：七石一环缺一，站进缺口一秒自动补全出种子。

var player: Player
var completed := false
var _gap_pos := Vector3.ZERO
var _hold := 0.0


func configure(p_player: Player, gap_angle: float) -> void:
	player = p_player
	add_to_group("rock_circle")
	var stone := Toon.make_material(Color(0.52, 0.54, 0.50), true, 0.012)
	for i in range(7):
		var a := gap_angle + (float(i) + 1.0) * TAU / 8.0
		var rock := MeshInstance3D.new()
		var rm := SphereMesh.new()
		rm.radius = 0.30
		rm.height = 0.5
		rm.radial_segments = 7
		rm.rings = 4
		rock.mesh = rm
		rock.material_override = stone
		rock.position = Vector3(cos(a) * 2.2, 0.18, sin(a) * 2.2)
		rock.scale = Vector3(1.0, 0.7, 0.9)
		rock.rotation.y = a
		add_child(rock)
	_gap_pos = Vector3(cos(gap_angle) * 2.2, 0, sin(gap_angle) * 2.2)
	# 缺口处有极淡的引导闪光。
	var hint := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.08
	hm.height = 0.16
	hm.radial_segments = 6
	hm.rings = 4
	hint.mesh = hm
	var hint_mat := StandardMaterial3D.new()
	hint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hint_mat.albedo_color = Color(1.0, 0.9, 0.4, 0.6)
	hint_mat.emission_enabled = true
	hint_mat.emission = Color(1.0, 0.85, 0.3)
	hint_mat.emission_energy_multiplier = 1.2
	hint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hint.material_override = hint_mat
	hint.position = _gap_pos + Vector3(0, 0.35, 0)
	add_child(hint)


func _process(delta: float) -> void:
	if completed or player == null:
		return
	if player.global_position.distance_to(global_position + _gap_pos) < 1.4:
		_hold += delta
		if _hold >= 1.0:
			completed = true
			Loot.spawn(get_tree().current_scene, global_position + _gap_pos + Vector3(0, 0.5, 0), "seed", "", 1, 3)
			var scene := get_tree().current_scene
			if scene and scene.get("hud") != null:
				scene.hud.add_feed("石头阵补全了！")
	else:
		_hold = 0.0
