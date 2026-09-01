class_name HudPresenter
extends RefCounted

static func refresh(m: Node) -> void:
		m.hud.set_stamina(m.player.stamina / m.player.max_stamina)
		m.hud.update_minimap(m.player, m.zone)
		var spread_val: float = 0.0
		var wp: Variant = m.player.get("weapon")
		if wp != null and wp is Weapon:
			var w: Weapon = wp as Weapon
			if w.has_method("current_reticle_spread"):
				var ret_v: Variant = w.call("current_reticle_spread")
				if ret_v is float:
					spread_val = ret_v as float
				elif ret_v is int:
					spread_val = float(ret_v as int)
			else:
				spread_val = w.current_spread()
		m.hud.set_spread(6.0 + spread_val * 9.0)
		var wid: String = ""
		if wp is Weapon:
			wid = (wp as Weapon).weapon_id
		m.hud.set_crosshair_visible(wid != "")
		if m.player.nearby_loot:
			m.hud.set_interact("按 E 拾取  " + m.player.nearby_loot.describe())
		elif m.player.vehicle:
			m.hud.set_interact("按 F 下车")
		elif m.player.nearby_vehicle:
			var ride_value: Variant = m.player.nearby_vehicle.get("ride_label")
			var ride_text: String = str(ride_value) if ride_value != null else "驾驶吉普车"
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
		else:
			m.hud.set_interact("")
		var label_text: String = ""
		if wp is Weapon:
			label_text = (wp as Weapon).label()
		else:
			label_text = "波克剑"
		m.hud.set_weapon_name(label_text)
		var cur_id: String = ""
		if wp is Weapon:
			cur_id = (wp as Weapon).weapon_id
		if cur_id == "":
			m.hud.set_ammo_text("--")
		if m.get("_map_id") == "wild" and m.get("wild_world"):
			var state: String = ""
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
			var dn: Variant = m.get("daynight")
			var phase_name: String = ""
			if dn != null and dn is Node and (dn as Node).has_method("phase_name"):
				phase_name = str((dn as Node).call("phase_name"))
			var ww: Variant = m.get("wild_world")
			var region_name: String = ""
			if ww != null and ww is Node and (ww as Node).has_method("get_region_name"):
				region_name = str((ww as Node).call("get_region_name", m.player.global_position))
			m.hud.set_zone_text(region_name)
			m.hud.set_world_state("原创旷野 · %s%s\nM 地图  ·  N 背包  ·  F 骑乘  ·  H 口哨  ·  T 时光" % [phase_name, state])
			var quest_text: String = ""
			if m.has_method("quest_status_text"):
				quest_text = str(m.call("quest_status_text"))
			if quest_text != "":
				m.hud.set_world_state("原创旷野 · %s%s\n%s\nM 地图  ·  N 背包  ·  F 骑乘  ·  H 口哨  ·  T 时光" % [phase_name, state, quest_text])
		else:
			var zone_v: Variant = m.get("zone")
			if zone_v is Zone:
				m.hud.set_zone_text((zone_v as Zone).status_text())
			else:
				m.hud.set_zone_text("")
			m.hud.set_world_state("群岛战场\nM 地图选择")
			var zone2: Variant = m.get("zone")
			var active: bool = false
			var outside: bool = false
			if zone2 is Zone:
				active = (zone2 as Zone).active
				outside = (zone2 as Zone).is_outside(m.player.global_position)
			m.hud.set_danger(active and outside)
		var shown: bool = false
		var map_id_v: Variant = m.get("_map_id")
		var ww_v: Variant = m.get("wild_world")
		if str(map_id_v) == "wild" and ww_v != null:
			var trials_v: Variant = ww_v.get("trials")
			if trials_v is Array:
				for trial in trials_v as Array:
					if trial == null or not trial.has_method("hud_status"):
						continue
					var ts: Array = trial.call("hud_status", m.player.global_position) as Array
					if ts.size() > 1 and float(ts[1]) >= 0.0:
						m.hud.set_capture(str(ts[0]), float(ts[1]))
						shown = true
						break
			if not shown:
				var tree: SceneTree = m.get_tree() as SceneTree
				if tree:
					for enemy in tree.get_nodes_in_group("wild_enemy"):
						if enemy is WildDragon and (enemy as WildDragon).alive and enemy.global_position.distance_to(m.player.global_position) < 110.0:
							m.hud.set_capture("火山巨龙", (enemy as WildDragon).hp / 260.0)
							shown = true
							break
		var cps_v: Variant = m.get("capture_points")
		if cps_v is Array:
			for cp in cps_v as Array:
				if cp == null or not cp.has_method("hud_status"):
					continue
				var st: Array = cp.call("hud_status", m.player) as Array
				if st.size() > 1 and float(st[1]) >= 0.0:
					m.hud.set_capture(str(st[0]), float(st[1]))
					shown = true
					break
		if not shown:
			m.hud.set_capture("", -1.0)
