class_name SmokeGrenade
extends RigidBody3D
## 烟雾弹：掷出 1.6s 后起烟，烟球持续 18s，期间遮挡 bot 视线（bot 查 smoke 组）

const FUSE := 1.6
const SMOKE_LIFE := 18.0
const SMOKE_RADIUS := 4.5

var _t := 0.0
var _smoking := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	can_sleep = false
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = Toon.make_material(Color(0.30, 0.35, 0.30), true, 0.005)
	add_child(mi)
	var col := CollisionShape3D.new()
	var cs := SphereShape3D.new()
	cs.radius = 0.09
	col.shape = cs
	add_child(col)


func _process(delta: float) -> void:
	if _smoking:
		return
	_t += delta
	if _t >= FUSE:
		_smoking = true
		_start_smoke()


func _start_smoke() -> void:
	# // FIX: OPT-E3 起烟气压声（原完全无声）
	var _sfx_s := get_tree().get_first_node_in_group("sfx_bank")
	if _sfx_s:
		_sfx_s.play_at("smoke_pop", global_position, -8.0)
	freeze = true
	add_to_group("smoke")
	for i in range(11):
		var puff := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 8
		sm.rings = 5
		puff.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.92, 0.93, 0.95, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
		puff.material_override = m
		puff.position = Vector3(randf_range(-1.6, 1.6), randf_range(0.2, 2.0), randf_range(-1.6, 1.6))
		puff.scale = Vector3.ONE * 0.3
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		var tw := puff.create_tween()
		tw.tween_property(puff, "scale", Vector3.ONE * randf_range(2.4, 3.4), 2.5).set_ease(Tween.EASE_OUT)
		tw.tween_interval(SMOKE_LIFE - 6.0)
		tw.tween_property(puff, "scale", Vector3.ONE * 0.05, 3.5).set_ease(Tween.EASE_IN)
	var done := create_tween()
	done.tween_interval(SMOKE_LIFE)
	done.tween_callback(queue_free)
