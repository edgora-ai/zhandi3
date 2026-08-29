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
	# // FIX: OPT-B6/R5 阵营 mask：玩家箭命中 bot/怪物层；野怪投射物也命中 bot（PvE 不再只打玩家）
	collision_mask = (1 | 2 | 4) if kind == "arrow" else (1 | 2 | 4)
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
		# // FIX: OPT-H4/FX12 去逐颗 OmniLight（同屏动态光预算），自发光 3.2→4.2 保持可见度
		glow.emission_energy_multiplier = 4.2
		mi.material_override = glow
	add_child(mi)


var _trail_t := 0.0

func _physics_process(delta: float) -> void:
	# // FIX: OPT-H4/FX12 火球/能量弹拖尾（无光小烟点，节奏 0.08s）
	if kind == "fire" or kind == "energy":
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.08
			FX.impact(global_position, Color(1.0, 0.35, 0.08) if kind == "fire" else Color(0.10, 0.75, 1.0))
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var collision := move_and_collide(velocity * delta)
	if collision:
		var collider: Object = collision.get_collider()
		# // FIX: OPT-B2/CB2 弹反规则统一：完美窗口（0.18s）内才原路弹回；
		# 普通举盾按 0.25 倍扣血 + 10 精力，不再无限免费反弹
		if collider is Player and (collider as Player).blocking:
			var facing: Vector3 = -(collider as Player).global_transform.basis.z
			if facing.dot(velocity.normalized()) < -0.3:
				var now_s := Time.get_ticks_msec() / 1000.0
				if now_s - (collider as Player)._block_start < 0.18:
					var back_dir := Vector3.ZERO
					if source and is_instance_valid(source) and source is Node3D:
						back_dir = ((source as Node3D).global_position + Vector3(0, 1.2, 0) - global_position).normalized()
					else:
						back_dir = -velocity.normalized()
					velocity = back_dir * maxf(18.0, velocity.length() * 1.4)
					lifetime = 3.0
					# // FIX: OPT-B2/R30 弹反后可命中任意阵营（含施法者），source 换成玩家防自伤
					collision_mask = 1 | 2 | 4
					source = collider
					collider.parry_count += 1
					if collider.hud:
						collider.hud.add_feed("弹反！")
					return
				# 普通格挡：减伤结算后投射物消耗（// FIX: R2-B5 精力不足时不再享受 75% 减伤，与枪弹路径同 gate）
				if (collider as Player).get("stamina") != null and float((collider as Player).get("stamina")) > 0.0:
					(collider as Player)._drain_stamina(10.0)
					(collider as Player).take_damage(damage * 0.25, source if source and is_instance_valid(source) else null, "body")
				else:
					(collider as Player).take_damage(damage, source if source and is_instance_valid(source) else null, "body")
				FX.parry_flash(global_position)
				queue_free()
				return
		if OS.get_cmdline_user_args().has("--wildtest"):
			print("[wildtest] projectile collision kind=%s collider=%s pos=%s" % [kind, str(collider), str(global_position)])
		var valid_source: Node = source if source and is_instance_valid(source) else null
		# // FIX: R2-B5 阵营过滤：野怪投射物不再互伤/杀动物（龙火球清营地、投石怪互耗）；
		# bot（combatant 组，非 wild_enemy/wildlife）保持可被打（R5 验收）
		var wild_source := valid_source != null and not (valid_source is Player) and not (valid_source is Bot)
		var is_wild_target: bool = collider != null and (collider.is_in_group("wild_enemy") or collider.is_in_group("wildlife"))
		if collider and collider != valid_source and collider.has_method("take_damage") and not (wild_source and is_wild_target):
			# // FIX: OPT-B6 部位判定：按被击中形状求部位，箭爆头 ×1.5（可触发西诺克斯独眼）
			var part := "body"
			var shape_idx: Variant = collision.get_collider_shape()
			if collider.has_method("get_hit_part") and shape_idx is int:
				part = collider.get_hit_part(shape_idx) # // FIX: OPT-B6 部位判定（带类型守卫）
			var final_dmg := damage
			if kind == "arrow" and part == "head":
				final_dmg *= 1.5
			collider.take_damage(final_dmg, valid_source, part)
			# // FIX: OPT-C5 弓命中反馈：接 hit_landed（播 hit 音 + hitmarker）
			if valid_source is Player:
				var w: Variant = valid_source.get("weapon")
				if w != null and w.has_signal("hit_landed"):
					w.hit_landed.emit(part)
		FX.impact(global_position, Color(1.0, 0.25, 0.05) if kind == "fire" else Color(0.25, 0.88, 1.0) if kind == "energy" else Color(0.62, 0.52, 0.38))
		queue_free()
	if kind != "arrow":
		rotate_x(delta * 7.0)
		rotate_z(delta * 5.0) # // FIX: R2-C1c 箭矢直飞（原 7rad/s 翻滚）
