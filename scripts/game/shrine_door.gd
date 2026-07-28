class_name ShrineDoor
extends Area3D
## 神庙入口：试炼完成后门口显示"按 E 进入神庙"，黑场传送进地底石室。

var trial: ShrineTrial
var interior: ShrineInterior


static func create(shrine: Node3D, local_pos: Vector3, p_trial: ShrineTrial, p_interior: ShrineInterior) -> ShrineDoor:
	var d := ShrineDoor.new()
	d.trial = p_trial
	d.interior = p_interior
	d.add_to_group("shrine_door")
	shrine.add_child(d)
	d.position = local_pos
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.8
	col.shape = shape
	d.add_child(col)
	d.body_entered.connect(d._on_enter)
	d.body_exited.connect(d._on_exit)
	return d


func _on_enter(body: Node) -> void:
	if body is Player and trial and trial.completed:
		body.nearby_shrine_door = self


func _on_exit(body: Node) -> void:
	if body is Player and body.nearby_shrine_door == self:
		body.nearby_shrine_door = null


func enter(player: Player) -> void:
	if interior == null:
		return
	var scene := get_tree().current_scene
	player.nearby_shrine_door = null
	if scene and scene.get("hud") != null:
		var dest := interior.entry_point()
		scene.hud.fade_transition(func() -> void:
			player.global_position = dest
			player.velocity = Vector3.ZERO
		)
