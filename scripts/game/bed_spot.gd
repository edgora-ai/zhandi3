class_name BedSpot
extends Node3D
## 床铺：按 E 睡到天亮，生命与精力全满。


func use(p: Player) -> void:
	var scene := get_tree().current_scene
	if scene and scene.get("daynight") != null:
		scene.daynight.t = 0.03
		scene.daynight.blood_moon = false
		scene.daynight._apply()
	p.hp = p.max_hp
	p.stamina = p.max_stamina
	p.health_changed.emit(p.hp, p.armor)
	if p.hud:
		p.hud.add_feed("你睡了个好觉（清晨，状态全满）")
