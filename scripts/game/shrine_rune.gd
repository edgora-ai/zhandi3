class_name ShrineRune
extends StaticBody3D
## 神庙试炼的符文靶：悬浮发光环，被射中后点亮。

var activated := false
var trial: Node
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _t := 0.0
var _dim: StandardMaterial3D
var _lit: StandardMaterial3D


func _ready() -> void:
	collision_layer = 4
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	add_child(col)
	_dim = StandardMaterial3D.new()
	_dim.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dim.albedo_color = Color(0.10, 0.35, 0.38)
	_dim.emission_enabled = true
	_dim.emission = Color(0.05, 0.55, 0.58)
	_dim.emission_energy_multiplier = 0.9
	_lit = StandardMaterial3D.new()
	_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lit.albedo_color = Color(0.85, 1.0, 0.95)
	_lit.emission_enabled = true
	_lit.emission = Color(0.6, 1.0, 0.85)
	_lit.emission_energy_multiplier = 3.0
	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.30
	ring_mesh.outer_radius = 0.48
	ring_mesh.rings = 18
	ring_mesh.ring_segments = 8
	_ring.mesh = ring_mesh
	_ring.material_override = _dim
	add_child(_ring)
	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.32
	core_mesh.radial_segments = 10
	core_mesh.rings = 6
	_core.mesh = core_mesh
	_core.material_override = _dim
	add_child(_core)


func is_plant() -> bool:
	return true   # 命中特效用火花而不是血雾


func get_hit_part(_idx: int) -> String:
	return "body"


func take_damage(_amount: float, _from: Variant = null, _part_name: String = "body") -> void:
	if activated:
		return
	activated = true
	_ring.material_override = _lit
	_core.material_override = _lit
	if trial and trial.has_method("on_rune_hit"):
		trial.on_rune_hit(self)


func reset_rune() -> void:
	activated = false
	_ring.material_override = _dim
	_core.material_override = _dim


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * (1.5 if activated else 0.5)
	position.y += sin(_t * 2.0) * 0.0016
