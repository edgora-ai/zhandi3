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
	gravity = 2.0 if kind == "fire" else (0.0 if kind == "energy" else (6.0 if kind == "arrow" else 9.0))


func _ready() -> void:
	add_to_group("wild_projectile")
	collision_layer = 0
	collision_mask = (1 | 4) if kind == "arrow" else (1 | 2)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.22 if kind == "rock" else 0.30
	col.shape = shape
	add_child(col)
	_build_visual()


func _build_visual() -> void:
	if kind == "arrow":
		var shaft := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.035, 0.035, 0.75)
		shaft.mesh = sm
		shaft.material_override = Toon.make_material(Color(0.55, 0.40, 0.20), true, 0.006)
		add_child(shaft)
		var head := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.0
		hm.bottom_radius = 0.05
		hm.height = 0.12
		hm.radial_segments = 6
		head.mesh = hm
		head.material_override = Toon.make_material(Color(0.70, 0.72, 0.75), true, 0.006)
		head.rotation_degrees.x = -90.0
		head.position = Vector3(0, 0, -0.42)
		add_child(head)
		var tail := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.02, 0.12, 0.10)
		tail.mesh = tm
		tail.material_override = Toon.make_material(Color(0.90, 0.92, 0.95), false)
		tail.position = Vector3(0, 0, 0.36)
		add_child(tail)
		if velocity.length_squared() > 0.01:
			look_at(global_position + velocity, Vector3.UP)
		return
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
		# 弹反：举盾且面向投射物时，石头被原路弹回（旷野之息弹反）。
		if collider is Player and collider.blocking:
			var facing: Vector3 = -(collider as Player).global_transform.basis.z
			if facing.dot(velocity.normalized()) < -0.3:
				var back_dir := Vector3.ZERO
				if source and is_instance_valid(source) and source is Node3D:
					back_dir = ((source as Node3D).global_position + Vector3(0, 1.2, 0) - global_position).normalized()
				else:
					back_dir = -velocity.normalized()
				velocity = back_dir * maxf(18.0, velocity.length() * 1.4)
				lifetime = maxf(lifetime, 3.0)
				collision_mask = 1 | 4
				source = collider
				lifetime = 3.0
				collider.parry_count += 1
				if collider.hud:
					collider.hud.add_feed("弹反！")
				return
		if OS.get_cmdline_user_args().has("--wildtest"):
			print("[wildtest] projectile collision kind=%s collider=%s pos=%s" % [kind, str(collider), str(global_position)])
		var valid_source: Node = source if source and is_instance_valid(source) else null
		if collider and collider != valid_source and collider.has_method("take_damage"):
			collider.take_damage(damage, valid_source)
		FX.impact(global_position, Color(1.0, 0.25, 0.05) if kind == "fire" else Color(0.25, 0.88, 1.0) if kind == "energy" else Color(0.62, 0.52, 0.38))
		queue_free()
	rotate_x(delta * 7.0)
	rotate_z(delta * 5.0)
