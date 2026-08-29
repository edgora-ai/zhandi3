class_name RemoteBomb
extends RigidBody3D
## 遥控炸弹：球形古代炸弹。X 放置（至多 2 枚），B 遥控引爆。
## 爆炸对敌人造成范围衰减伤害，近距玩家被击退——可用作炸弹跳。

const RADIUS := 4.5
const DAMAGE := 40.0
const SELF_DAMAGE := 12.0

var _light: OmniLight3D
var _fuse := 0.0
var source: Node = null


static func place(parent: Node, pos: Vector3, toss: Vector3, p_source: Node = null) -> RemoteBomb:
	var b := RemoteBomb.new()
	b.source = p_source
	b.position = pos
	parent.add_child(b)
	b.linear_velocity = toss
	return b


func _ready() -> void:
	add_to_group("remote_bomb")
	mass = 0.8
	gravity_scale = 1.6
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.22
	col.shape = shape
	add_child(col)
	# 深蓝球壳 + 古代符文发光环 + 火花点光。
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 12
	sm.rings = 8
	shell.mesh = sm
	shell.material_override = Toon.make_material(Color(0.10, 0.14, 0.22), true, 0.012)
	add_child(shell)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.225
	bm.bottom_radius = 0.225
	bm.height = 0.05
	bm.radial_segments = 12
	band.mesh = bm
	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.albedo_color = Color(0.10, 0.85, 0.80)
	band_mat.emission_enabled = true
	band_mat.emission = Color(0.05, 0.90, 0.80)
	band_mat.emission_energy_multiplier = 2.0
	band.material_override = band_mat
	add_child(band)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 0.9, 0.8)
	_light.light_energy = 0.6
	_light.omni_range = 2.5
	_light.position.y = 0.3
	add_child(_light)


func _process(delta: float) -> void:
	_fuse += delta
	_light.light_energy = 0.45 + 0.35 * absf(sin(_fuse * 22.0) * sin(_fuse * 7.3))


func detonate() -> void:
	var scene := get_tree().current_scene
	var pos := global_position
	# 敌伤：范围衰减。玩家走专用自伤分支，去重避免 40+12 双伤。
	var damaged: Dictionary = {}
	var total := 0 # // FIX: R4-10 聚合总伤
	var scene_player: Node = null
	if scene and scene.get("player") != null:
		scene_player = scene.get("player")
	for group in ["wild_enemy", "wildlife", "combatant"]:
		for target in get_tree().get_nodes_in_group(group):
			if target == scene_player:
				continue
			if target == source:
				continue
			if damaged.has(target.get_instance_id()):
				continue
			if not (target is CharacterBody3D) or not target.alive:
				continue
			var d: float = target.global_position.distance_to(pos)
			if d > RADIUS:
				continue
			if target.has_method("take_damage"):
				target.take_damage(DAMAGE * clampf(1.0 - d / RADIUS, 0.25, 1.0), source if source else self, "body")
				total += int(DAMAGE * clampf(1.0 - d / RADIUS, 0.25, 1.0)) # // FIX: R4-10 爆炸总伤聚合
				damaged[target.get_instance_id()] = true
	if total > 0:
		DamageNumber.spawn_at(get_tree().current_scene, pos + Vector3(0, 1.2, 0), str(total), Color(1.0, 0.6, 0.2))
	# 可炸物：裂岩等可破坏物按全额伤害结算。
	for target in get_tree().get_nodes_in_group("crackable"):
		var cd: float = target.global_position.distance_to(pos)
		if cd > RADIUS:
			continue
		if target.has_method("take_damage"):
			target.take_damage(DAMAGE, self, "body")
	# 玩家：近距小伤 + 大击退（炸弹跳）。
	var player: Player = null
	if scene and scene.get("player") != null:
		player = scene.get("player") as Player
	if player and player.alive:
		var dp := player.global_position.distance_to(pos)
		if dp < RADIUS:
			var dir := player.global_position - pos
			dir.y = 0.0
			if dir.length_squared() < 0.01:
				dir = Vector3.RIGHT
			dir = dir.normalized()
			var power := clampf(1.0 - dp / RADIUS, 0.0, 1.0)
			player.velocity += dir * (8.0 * power) + Vector3(0, 6.5 * power, 0)
			if dp < 2.5:
				player.take_damage(SELF_DAMAGE * (1.0 - dp / 2.5), self)
	# 视觉与音效：扩张火球 + 火花 + 爆炸声。
	if scene:
		_flash(scene, pos)
	FX.impact(pos)
	var sfx := get_tree().get_first_node_in_group("sfx_bank")
	if sfx:
		sfx.play_at("explosion", pos, -4.0)
	queue_free()


func _flash(parent: Node, pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 1.0
	fm.height = 2.0
	fm.radial_segments = 12
	fm.rings = 8
	flash.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.45, 0.10)
	fmat.emission_energy_multiplier = 3.0
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = fmat
	parent.add_child(flash)
	flash.global_position = pos
	flash.scale = Vector3.ONE * 0.3
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * RADIUS * 0.9, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(fmat, "albedo_color:a", 0.0, 0.30)
	tween.tween_callback(flash.queue_free)
