class_name DiveRing
extends Node3D
## 跳水环呀哈哈：河面睡莲环，游进环心得种子。

var player: Player
var completed := false


func configure(p_player: Player) -> void:
	player = p_player
	add_to_group("dive_ring")
	var lily := Toon.make_material(Color(0.30, 0.55, 0.22), true, 0.008)
	for i in range(8):
		var a := float(i) * TAU / 8.0
		var pad := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.34
		pm.bottom_radius = 0.30
		pm.height = 0.06
		pm.radial_segments = 8
		pad.mesh = pm
		pad.material_override = lily
		pad.position = Vector3(cos(a) * 2.0, 0, sin(a) * 2.0)
		pad.rotation.y = a
		add_child(pad)


func _process(_delta: float) -> void:
	if completed or player == null or not player.is_swimming:
		return
	if player.global_position.distance_to(global_position) < 1.4:
		completed = true
		Loot.spawn(get_tree().current_scene, global_position + Vector3(0, 0.4, 0), "seed", "", 1, 3)
		var scene := get_tree().current_scene
		if scene and scene.get("hud") != null:
			scene.hud.add_feed("从睡莲环里钻出来一颗种子！")
