class_name WildProjectile
extends CharacterBody3D
## 小怪投掷物、龙焰与飞行器能量弹共用的轻量投射物。

var kind := "rock"
var damage := 12.0
var gravity := 9.0
var lifetime := 6.0
var source: Node = null


func configure(p_kind: String, p_velocity: Vector3, p_damage: float, p_source: Node = null) -> void:
	kind = p_kind
	velocity = p_velocity
	damage = p_damage
	source = p_source
	gravity = 2.0 if kind == "fire" else (0.0 if kind == "energy" else 9.0)


func _ready() -> void:
	add_to_group("wild_projectile")
	collision_layer = 0
	collision_mask = 1 | 2
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.22 if kind == "rock" else 0.30
	col.shape = shape
	add_child(col)
	_build_visual()


func _build_visual() -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22 if kind == "rock" else 0.30
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	mi.mesh = mesh
	if kind == "rock":
		mi.material_override = Toon.make_material(Color(0.43, 0.38, 0.31), true, 0.01)
		mi.scale = Vector3(1.2, 0.8, 1.0)
	else:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.24, 0.035) if kind == "fire" else Color(0.05, 0.92, 1.0)
		glow.emission_enabled = true
		glow.emission = glow.albedo_color
		glow.emission_energy_multiplier = 3.2
		mi.material_override = glow
		var light := OmniLight3D.new()
		light.light_color = glow.albedo_color
		light.light_energy = 2.0
		light.omni_range = 5.0
		add_child(light)
	add_child(mi)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var collision := move_and_collide(velocity * delta)
	if collision:
		var collider: Object = collision.get_collider()
		if OS.get_cmdline_user_args().has("--wildtest"):
			print("[wildtest] projectile collision kind=%s collider=%s pos=%s" % [kind, str(collider), str(global_position)])
		if collider and collider != source and collider.has_method("take_damage"):
			collider.take_damage(damage, source)
		FX.impact(global_position, Color(1.0, 0.25, 0.05) if kind == "fire" else Color(0.25, 0.88, 1.0) if kind == "energy" else Color(0.62, 0.52, 0.38))
		queue_free()
	rotate_x(delta * 7.0)
	rotate_z(delta * 5.0)
