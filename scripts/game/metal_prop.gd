class_name MetalProp
extends RigidBody3D
## 磁力金属块：古代铁皮箱，可被磁力吸附搬运/投掷。高速撞击对敌人造成伤害。

var held := false


static func create(parent: Node, pos: Vector3) -> MetalProp:
	var p := MetalProp.new()
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group("metal_prop")
	mass = 6.0
	contact_monitor = true
	max_contacts_reported = 4
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.8, 0.8)
	col.shape = shape
	add_child(col)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 0.8, 0.8)
	body.mesh = bm
	body.material_override = Toon.make_material(Color(0.16, 0.18, 0.22), true, 0.014)
	add_child(body)
	# 四条古代纹路发光边。
	for i in range(4):
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.84, 0.06, 0.06)
		strip.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(0.08, 0.80, 0.75)
		smat.emission_enabled = true
		smat.emission = Color(0.05, 0.85, 0.75)
		smat.emission_energy_multiplier = 1.6
		strip.material_override = smat
		strip.position = Vector3(0, 0.28 - i * 0.19, 0.41)
		add_child(strip)
	body_entered.connect(_on_body_entered)


# 磁吸搬运：软性飞向持握点，保持碰撞。
func magnet_hold(point: Vector3) -> void:
	held = true
	var to := point - global_position
	linear_velocity = to * clampf(to.length() * 1.2, 2.0, 8.0)
	angular_velocity = angular_velocity.move_toward(Vector3.ZERO, 0.4)


func magnet_release(impulse: Vector3) -> void:
	held = false
	linear_velocity = impulse


func _on_body_entered(body: Node) -> void:
	var speed := linear_velocity.length()
	if speed < 4.0 or body == self:
		return
	if body.has_method("take_damage") and (body.is_in_group("wild_enemy") or body.is_in_group("wildlife") or body.is_in_group("combatant")):
		body.take_damage(10.0 + speed * 2.0, self, "body")
		FX.impact(global_position)
