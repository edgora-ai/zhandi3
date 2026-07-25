class_name ChoppableTree
extends StaticBody3D
## 可砍伐的树干：受击两次后倒伏。树冠卡片由 Props 置零隐藏，倒伏后留木桩与木材。

var hp := 2
var tree_node: Node3D
var props: Props

var _falling := false
var _done := false
var _fall_t := 0.0
var _axis := Vector3.RIGHT
var _start_basis := Basis.IDENTITY


func configure(p_tree: Node3D, p_props: Props, radius: float, height: float) -> void:
	tree_node = p_tree
	props = p_props
	collision_layer = 1
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	col.shape = cyl
	col.position.y = height * 0.5
	add_child(col)


func is_plant() -> bool:
	return true


func get_hit_part(_idx: int) -> String:
	return "body"


func take_damage(_amount: float, from: Variant = null, _part_name: String = "body") -> void:
	if _falling:
		return
	hp -= 1
	FX.impact(global_position + Vector3(0, 1.2, 0))
	if hp <= 0:
		_begin_fall(from)


func _begin_fall(from: Variant) -> void:
	_falling = true
	_start_basis = tree_node.transform.basis
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	if from != null and from is Node3D:
		away = tree_node.global_position - (from as Node3D).global_position
		away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	away = away.normalized()
	_axis = Vector3.UP.cross(away).normalized()
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if props:
		props.chop_canopy(tree_node)
	DamageNumber.spawn_at(get_tree().current_scene, tree_node.global_position + Vector3(0, 2.2, 0), "砍倒!", Color(0.95, 0.75, 0.30))


func _physics_process(delta: float) -> void:
	if not _falling or _done:
		return
	_fall_t += delta
	var k := minf(_fall_t / 1.2, 1.0)
	var angle := k * k * 1.62
	tree_node.transform = Transform3D(Basis(_axis, angle) * _start_basis, tree_node.transform.origin)
	if k >= 1.0:
		_done = true
		if props:
			props.finish_chop(tree_node)
