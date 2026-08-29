class_name HudPresenter
extends RefCounted
## // FIX: R14 最小切面：main._process 的每帧 HUD 刷新块外迁（原 ~90 行内联在上帝类里）。
## 只读 main 状态、只写 HUD，静态入口便于测试与后续拆分。

static func refresh(m: Node) -> void: # 动态访问 main（无 class_name，鸭子类型）
		m.hud.set_stamina(m.player.stamina / m.player.max_stamina)
		m.hud.update_minimap(m.player, m.zone) # // FIX: R3-P02 唯一调用点漏传 zone，安全圈/预览圈从未渲染
		m.hud.set_spread(6.0 + m.player.weapon.current_spread() * 9.0)
		m.hud.set_crosshair_visible(m.player.weapon.weapon_id != "")
		if m.player.nearby_loot:
			m.hud.set_interact("按 E 拾取  " + m.player.nearby_loot.describe())
		elif m.player.vehicle:
			m.hud.set_interact("按 F 下车")
		elif m.player.nearby_vehicle:
			var ride_value: Variant = m.player.nearby_vehicle.get("ride_label")
			var ride_text := str(ride_value) if ride_value != null else "驾驶吉普车"
			m.hud.set_interact("按 F %s" % ride_text)
		elif m.player.nearby_npc:
			m.hud.set_interact("按 E 与%s交谈" % str(m.player.nearby_npc.get("npc_name")))
		elif m.player.nearby_fish:
			m.hud.set_interact("按 E 抓鱼")
		elif m.player.nearby_bed:
			m.hud.set_interact("按 E 睡到天亮")
		elif m.player.nearby_shrine_door:
			m.hud.set_interact("按 E 进入神庙")
		elif m.player.nearby_shrine_exit:
			m.hud.set_interact("按 E 离开神庙")
		elif m.player.nearby_chest:
			m.hud.set_interact("按 E 打开宝箱")
		elif m.player.nearby_beacon:
			m.hud.set_interact("按 E 传送")
		elif m.player.nearby_bed:
			m.hud.set_interact("按 E 睡到天亮")
		elif m.player.nearby_fish:
			m.hud.set_interact("按 E 抓鱼")
		else:
			m.hud.set_interact("")
		m.hud.set_weapon_name(m.player.weapon.label())
		if m.player.weapon.weapon_id == "":
			m.hud.set_ammo_text("--")
		if m._map_id == "wild" and m.wild_world:
			var state := ""
			if m.player.is_swimming:
				state = " · 游泳（Space 上浮 / C 下潜）"
			elif m.player.is_climbing:
				state = " · 攀爬中（W/S 上下 · Space 蹬离）"
			elif m.player.is_gliding:
				state = " · 滑翔伞展开（W 俯冲 / S 减速）"
			elif m.player.vehicle:
				state = " · 骑乘中"
			elif not m.player.is_on_floor() and m.player.velocity.y < -0.55:
				state = " · 按住 Space 展开滑翔伞"
			m.hud.set_zone_text(m.wild_world.get_region_name(m.player.global_position))
			m.hud.set_world_state("原创旷野 · %s%s\nM 地图  ·  N 背包  ·  F 骑乘  ·  H 口哨  ·  T 时光" % [m.daynight.phase_name() if m.daynight else "", state])
			var quest_text: String = m.quest_status_text()
			if quest_text != "":
				m.hud.set_world_state("原创旷野 · %s%s\n%s\nM 地图  ·  N 背包  ·  F 骑乘  ·  H 口哨  ·  T 时光" % [m.daynight.phase_name() if m.daynight else "", state, quest_text])
		else:
			m.hud.set_zone_text(m.zone.status_text())
			m.hud.set_world_state("群岛战场\nM 地图选择")
			m.hud.set_danger(m.zone.active and m.zone.is_outside(m.player.global_position))
		# 占点提示
		var shown := false
		if m._map_id == "wild" and m.wild_world:
			for trial in m.wild_world.trials:
				var ts: Array = trial.hud_status(m.player.global_position)
				if ts[1] >= 0.0:
					m.hud.set_capture(ts[0], ts[1])
					shown = true
					break
			# 巨龙血条：接近火山巨龙时显示（试炼条优先）。
			if not shown:
				for enemy in m.get_tree().get_nodes_in_group("wild_enemy"):
					if enemy is WildDragon and enemy.alive and enemy.global_position.distance_to(m.player.global_position) < 110.0:
						m.hud.set_capture("火山巨龙", enemy.hp / 260.0)
						shown = true
						break
		for cp in m.capture_points:
			var st: Array = cp.hud_status(m.player)
			if st[1] >= 0.0:
				m.hud.set_capture(st[0], st[1])
				shown = true
				break
		if not shown:
			m.hud.set_capture("", -1.0)
