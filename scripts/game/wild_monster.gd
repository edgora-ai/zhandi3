class_name WildMonster
extends CharacterBody3D
## 山野小怪：营地巡逻、远程投石、近距离冲锋干扰。

var terrain: Terrain
var player: Player
var alive := true
var hp := 60.0
var display_name := "山地小怪"
var damage_mult := 1.0
var kills := 0

var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _think := 0.0
var _throw_cooldown := 1.0
var _throw_windup := -1.0 # // FIX: OPT-C6 投石前摇计时
var _locked_throw_target := Vector3.ZERO # // FIX: OPT-C6 前摇开始时锁定预判点
var _hit_cooldown := 0.0
var _anim_time := 0.0
var _arm_left: Node3D
var _arm_right: Node3D
var _legs: Array[Node3D] = []
var _flash := 0.0
var _death_t := -1.0
var _attack_cue: MeshInstance3D
var _melee_windup := -1.0
var _stagger_t := 0.0
var _knockback := Vector3.ZERO


func setup(p_terrain: Terrain, p_player: Player) -> void:
	terrain = p_terrain
	player = p_player


func _ready() -> void:
	add_to_group("wild_enemy")
	collision_layer = 4
	collision_mask = 1
	_home = global_position
	_wander_target = global_position
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.55
	col.shape = shape
	col.position.y = 0.78
	add_child(col)
	_build_model()
	_attack_cue = FX.attack_ring(self, 2.15, Color(1.0, 0.34, 0.08, 0.76)) # // FIX: R2-B5 环=伤害距离（原 0.72 vs 2.15 反向误导）


func _build_model() -> void:
	var skin := Toon.make_material(Color(0.72, 0.22, 0.13), true, 0.015)
	var belly := Toon.make_material(Color(0.94, 0.55, 0.28), true, 0.012)
	var cloth := Toon.make_material(Color(0.18, 0.43, 0.50), true, 0.012)
	var dark := Toon.make_material(Color(0.11, 0.08, 0.065), true, 0.008)
	var bone := Toon.make_material(Color(0.92, 0.82, 0.58), true, 0.006)
	_sphere(self, 0.48, skin, Vector3(0, 1.15, 0), Vector3(1.0, 1.05, 0.86))
	_sphere(self, 0.34, belly, Vector3(0, 1.12, -0.36), Vector3(0.85, 1.0, 0.35))
	_sphere(self, 0.41, skin, Vector3(0, 1.76, -0.05), Vector3(1.15, 0.92, 1.0))
	_sphere(self, 0.24, belly, Vector3(0, 1.63, -0.40), Vector3(1.0, 0.72, 1.15))
	for sx in [-1.0, 1.0]:
		_sphere(self, 0.055, dark, Vector3(sx * 0.15, 1.82, -0.38), Vector3.ONE)
		var horn := _capsule(self, 0.055, 0.48, bone, Vector3(sx * 0.32, 2.12, -0.03))
		horn.rotation_degrees.z = sx * -34.0
	_part(Vector3(0.75, 0.26, 0.55), cloth, Vector3(0, 0.76, 0.03), self)
	# 投掷袋与木棒明确提示远近两种攻击方式。
	_sphere(self, 0.30, dark, Vector3(0.45, 1.05, 0.30), Vector3(0.7, 1.0, 0.55))
	_arm_left = _make_limb(Vector3(-0.52, 1.42, 0), skin, true)
	_arm_right = _make_limb(Vector3(0.52, 1.42, 0), skin, true)
	var club := _part(Vector3(0.13, 0.13, 1.05), dark, Vector3(0, -0.62, -0.38), _arm_right)
	club.rotation_degrees.x = 18.0
	for sx in [-0.24, 0.24]:
		var leg := _make_limb(Vector3(sx, 0.78, 0), skin, false)
		_legs.append(leg)


func _make_limb(pos: Vector3, mat: Material, arm: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	_capsule(pivot, 0.12 if arm else 0.15, 0.72, mat, Vector3(0, -0.32, 0))
	if not arm:
		_part(Vector3(0.32, 0.16, 0.42), mat, Vector3(0, -0.72, -0.10), pivot)
	return pivot


func _part(size: Vector3, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, shape_scale: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = shape_scale
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func get_hit_part(_shape_idx: int) -> String:
	return "body"


func apply_melee_impulse(direction: Vector3, strength: float, heavy: bool = false) -> void:
	if not alive:
		return
	var push := direction
	push.y = 0.0
	if push.length_squared() < 0.01:
		return
	_stagger_t = 0.50 if heavy else 0.28
	_knockback = push.normalized() * strength * (1.0 if heavy else 0.75)
	_melee_windup = -1.0
	_hit_cooldown = maxf(_hit_cooldown, 0.55)
	if _attack_cue:
		_attack_cue.visible = false


func take_damage(amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if not alive:
		return
	hp -= amount
	_flash = 0.14
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.2, 0), str(int(amount)), Color(1.0, 0.85, 0.25))
	if hp > 0.0:
		return
	alive = false
	if from and from.get("kills") != null:
		from.kills += 1
	if from and from.has_method("give_rupees"):
		from.give_rupees(2)
	Loot.spawn(get_tree().current_scene, global_position + Vector3(0, 0.2, 0), "meat", "", 1, 1)
	Loot.spawn(get_tree().current_scene, global_position + Vector3(0.5, 0.2, 0.3), "mushroom", "", 1, 1)
	Loot.spawn(get_tree().current_scene, global_position + Vector3(-0.4, 0.2, 0.2), "monster_part", "", 1, 1)
	DamageNumber.spawn_at(get_tree().current_scene, global_position + Vector3(0, 2.4, 0), "击败!", Color(1.0, 0.55, 0.20))
	var scene := get_tree().current_scene
	if scene and scene.get("hud") != null and from == scene.get("player"):
		scene.hud.add_feed("你 击败了 山地小怪")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_death_t = 0.0


func _physics_process(delta: float) -> void:
	if _death_t >= 0.0:
		_death_t += delta
		rotation.z = lerpf(rotation.z, 1.5, minf(1.0, delta * 6.0))
		position.y -= delta * 0.4
		if _death_t > 1.0:
			queue_free()
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		scale = Vector3.ONE * (1.0 + _flash * 1.2)
	if not alive or player == null or not is_instance_valid(player) or terrain == null:
		return
	_throw_cooldown = maxf(0.0, _throw_cooldown - delta)
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_anim_time += delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var move_dir := Vector3.ZERO
	if _stagger_t > 0.0:
		_stagger_t = maxf(0.0, _stagger_t - delta)
		move_dir = _knockback / 6.2
		_knockback = _knockback.move_toward(Vector3.ZERO, delta * 14.0)
	elif _melee_windup >= 0.0:
		# 小怪近身也先抬棒提示，给闪避与盾反留下稳定反应窗口。
		_melee_windup += delta
		if _attack_cue:
			_attack_cue.visible = true
			var cue_phase := clampf(_melee_windup / 0.42, 0.0, 1.0)
			_attack_cue.scale = Vector3.ONE * lerpf(1.35, 0.72, cue_phase)
		_arm_right.rotation.x = lerpf(_arm_right.rotation.x, -2.35, minf(1.0, delta * 11.0))
		if _melee_windup >= 0.42:
			if distance < 2.15:
				player.take_damage(14.0, self)
			_melee_windup = -1.0
			_hit_cooldown = 1.0
			if _attack_cue:
				_attack_cue.visible = false
			var sfx_hit := get_tree().get_first_node_in_group("sfx_bank")
			if sfx_hit:
				sfx_hit.play_at("heavy_impact", global_position, -9.0, 1.18)
	elif distance < 12.0:
		move_dir = to_player.normalized()
		if distance < 1.7 and _hit_cooldown <= 0.0:
			_melee_windup = 0.0
			move_dir = Vector3.ZERO
			var sfx_charge := get_tree().get_first_node_in_group("sfx_bank")
			if sfx_charge:
				sfx_charge.play_at("enemy_charge", global_position + Vector3(0, 1.0, 0), -10.0, 1.28)
	elif distance < 46.0:
		# // FIX: OPT-C6/CB13 投石 0.55s 前摇：脚下攻击环放大提示 + 蓄力音，锁定发射瞬间预判点（可闪避）
		if _throw_windup >= 0.0:
			_throw_windup -= delta
			move_dir = Vector3.ZERO
			if _attack_cue:
				_attack_cue.visible = true
				_attack_cue.scale = Vector3.ONE * (1.4 + (0.55 - _throw_windup) * 2.2)
			if _throw_windup <= 0.0:
				_throw_windup = -1.0
				if _attack_cue:
					_attack_cue.visible = false
				_throw_at_player_locked()
				_throw_cooldown = randf_range(1.8, 2.7)
		else:
			move_dir = to_player.normalized() * 0.25
			if _throw_cooldown <= 0.0:
				_throw_windup = 0.55
				_locked_throw_target = player.global_position + Vector3(0, 1.0, 0) + player.velocity * 0.25
				var sfx_windup := get_tree().get_first_node_in_group("sfx_bank")
				if sfx_windup:
					sfx_windup.play_at("enemy_charge", global_position + Vector3(0, 1.0, 0), -10.0, 0.9)
	else:
		_think -= delta
		if _think <= 0.0:
			_think = randf_range(2.0, 4.0)
			_wander_target = _home + Vector3(randf_range(-13, 13), 0, randf_range(-13, 13))
		move_dir = _wander_target - global_position
		move_dir.y = 0.0
		if move_dir.length() > 1.0:
			move_dir = move_dir.normalized() * 0.55
	var speed := 6.2 if distance < 12.0 else 3.2
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	velocity.y = -4.0
	# 避水：下一步会走进深水就停在岸边，并把游荡目标改回出生点一侧。
	if terrain:
		var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta * 2.0
		if terrain.is_in_water(next.x, next.z) and terrain.get_height(next.x, next.z) < Terrain.WATER_LEVEL - 0.35:
			velocity.x = 0.0
			velocity.z = 0.0
			_wander_target = _home
	move_and_slide()
	if not is_on_floor():
		global_position.y = terrain.get_height(global_position.x, global_position.z) + 0.05
	if move_dir.length_squared() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(move_dir.x, move_dir.z) + PI, delta * 8.0)
	var stride := clampf(Vector2(velocity.x, velocity.z).length() / 6.2, 0.0, 1.0) * 0.65
	for i in range(_legs.size()):
		_legs[i].rotation.x = sin(_anim_time * 9.0 + i * PI) * stride
	_arm_left.rotation.x = -sin(_anim_time * 9.0) * stride * 0.7
	if _melee_windup < 0.0:
		_arm_right.rotation.x = lerpf(_arm_right.rotation.x, -1.25 if distance > 12.0 and distance < 46.0 else sin(_anim_time * 9.0) * stride, delta * 6.0)


func _throw_at_player_locked() -> void:
	# // FIX: OPT-C6 使用前摇开始时锁定的预判点（预警期玩家位移可躲）；直调（测试钩子）时回退实时预判
	var origin := global_position + Vector3(0, 1.55, 0)
	var target := _locked_throw_target
	if target == Vector3.ZERO and player:
		target = player.global_position + Vector3(0, 1.0, 0) + player.velocity * 0.25
	var delta := target - origin
	var horizontal := Vector3(delta.x, 0, delta.z)
	var flight_time := clampf(horizontal.length() / 13.0, 0.35, 1.5)
	var launch := horizontal / flight_time
	launch.y = (delta.y + 0.5 * 9.0 * flight_time * flight_time) / flight_time
	var projectile := WildProjectile.new()
	projectile.configure("rock", launch, 12.0, self)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
