class_name FishSpot
extends Node3D
## 河鱼：水中缓慢游动的鱼影，靠近按 E 抓鱼（得兽肉），120 秒后重新出现。# FIX: H20 60s→120s 复核已落地

var player: Player
var available := true
var _t := 0.0
var _respawn := 0.0
var _fish: MeshInstance3D
var _home := Vector3.ZERO


func _ready() -> void:
	add_to_group("fish")
	_home = global_position
	var mat := Toon.make_material(Color(0.20, 0.35, 0.42), true, 0.006)
	_fish = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 8
	mesh.rings = 5
	_fish.mesh = mesh
	_fish.material_override = mat
	_fish.scale = Vector3(0.6, 0.5, 1.4)
	add_child(_fish)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.03, 0.16, 0.14)
	tail.mesh = tm
	tail.material_override = mat
	tail.position = Vector3(0, 0, 0.34)
	tail.rotation_degrees.y = 30.0
	_fish.add_child(tail)


func catch(p: Player) -> void:
	if not available:
		return
	available = false
	_respawn = 120.0
	_fish.visible = false
	p.give_item("meat", 1)
	if p.hud:
		p.hud.add_feed("抓到一条河鱼（兽肉 +1）")


func _process(delta: float) -> void:
	if not available:
		_respawn -= delta
		if _respawn <= 0.0:
			available = true
			_fish.visible = true
		return
	_t += delta
	# 绕小圈游动，偶尔转向。
	position = _home + Vector3(sin(_t * 0.6) * 1.2, sin(_t * 1.7) * 0.06, cos(_t * 0.45) * 1.2)
	rotation.y = _t * 0.6 + PI * 0.5
