class_name WarpBeacon
extends StaticBody3D
## 测绘传送水晶：塔顶基座上的古代水晶。E 激活后成为传送点（M 地图传送）。

var warp_name := "测绘塔"
var activated := false
var _crystal: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0


static func create(parent: Node, pos: Vector3, p_name: String) -> WarpBeacon:
	var b := WarpBeacon.new()
	b.warp_name = p_name
	b.position = pos
	parent.add_child(b)
	return b


func _ready() -> void:
	add_to_group("warp_beacon")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.0
	col.shape = shape
	col.position.y = 0.5
	add_child(col)
	# 石基座 + 悬浮水晶。
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.34
	bm.bottom_radius = 0.46
	bm.height = 0.5
	bm.radial_segments = 8
	base.mesh = bm
	base.material_override = Toon.make_material(Color(0.42, 0.44, 0.48), true, 0.012)
	base.position.y = 0.25
	add_child(base)
	_crystal = MeshInstance3D.new()
	var cm := PrismMesh.new()
	cm.size = Vector3(0.30, 0.62, 0.30)
	_crystal.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(0.15, 0.85, 0.78, 0.85)
	cmat.emission_enabled = true
	cmat.emission = Color(0.05, 0.90, 0.80)
	cmat.emission_energy_multiplier = 1.8
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crystal.material_override = cmat
	_crystal.position.y = 0.85
	add_child(_crystal)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.2, 0.95, 0.85)
	_light.light_energy = 0.9
	_light.omni_range = 5.0
	_light.position.y = 1.0
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_crystal.position.y = 0.85 + sin(_t * 2.2) * 0.06
	_crystal.rotation.y += delta * 1.2


func activate(_player: Player) -> void:
	var scene := get_tree().current_scene
	if activated:
		if scene and scene.get("hud") != null:
			scene.hud.add_feed("%s 的测绘点已激活（M 地图可传送）" % warp_name)
		return
	activated = true
	var cmat := _crystal.material_override as StandardMaterial3D
	cmat.emission_energy_multiplier = 3.2
	_light.light_energy = 1.6
	if scene and scene.has_method("_activate_warp"):
		scene._activate_warp(warp_name, global_position)


func is_available() -> bool:
	return not activated
