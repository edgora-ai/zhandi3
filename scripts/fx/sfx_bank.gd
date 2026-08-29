class_name SfxBank
extends Node
## 音效池：2D 全局音 + 3D 位置音，循环复用播放器节点

const SOUNDS := {
	"shot_rifle": "res://assets/sfx/shot_rifle.wav",
	"shot_dmr": "res://assets/sfx/shot_dmr.wav",
	"shot_smg": "res://assets/sfx/shot_smg.wav",
	"hit": "res://assets/sfx/hit.wav",
	"sword_whoosh": "res://assets/sfx/sword_whoosh.wav",
	"heavy_impact": "res://assets/sfx/heavy_impact.wav",
	"enemy_charge": "res://assets/sfx/enemy_charge.wav",
	"zone_alarm": "res://assets/sfx/zone_alarm.wav",
	"capture": "res://assets/sfx/capture.wav",
	"victory": "res://assets/sfx/victory.wav",
	"defeat": "res://assets/sfx/defeat.wav",
	"pickup": "res://assets/sfx/pickup.wav",
	"cook": "res://assets/sfx/cook.wav",
	"thunder": "res://assets/sfx/thunder.wav",
	"explosion": "res://assets/sfx/explosion.wav",
	"freeze": "res://assets/sfx/freeze.wav",
	"stasis": "res://assets/sfx/stasis.wav",
	# // FIX: OPT-E1/REG3 弓射击音独立（原复用 hit.wav 命中确认音，"发射=命中"混淆）
	"shot_bow": "res://assets/sfx/bow_release.wav",
	"bow_draw": "res://assets/sfx/bow_draw.wav",
	# // FIX: FX1 换弹双段音 / OPT-D3 心跳 / REG2 四类脚步 / REG1 独立雨声
	"reload_start": "res://assets/sfx/reload_start.wav",
	"reload_end": "res://assets/sfx/reload_end.wav",
	"heartbeat": "res://assets/sfx/heartbeat.wav",
	"footstep_grass": "res://assets/sfx/footstep_grass.wav",
	"footstep_sand": "res://assets/sfx/footstep_sand.wav",
	"footstep_wood": "res://assets/sfx/footstep_wood.wav",
	"footstep_water": "res://assets/sfx/footstep_water.wav",
	"rain_loop": "res://assets/sfx/rain_loop.wav",
	# // FIX: OPT-E3/FX14 交互缺口补齐
	"ui_click": "res://assets/sfx/ui_click.wav",
	"weapon_switch": "res://assets/sfx/weapon_switch.wav",
	"dodge_whoosh": "res://assets/sfx/dodge_whoosh.wav",
	"water_splash": "res://assets/sfx/water_splash.wav",
	"smoke_pop": "res://assets/sfx/smoke_pop.wav",
	"engine_loop": "res://assets/sfx/engine_loop.wav",
	"korok_reward": "res://assets/sfx/korok_reward.wav",
	"animal_pig": "res://assets/sfx/animal_pig.wav",
	"animal_wolf": "res://assets/sfx/animal_wolf.wav",
	"animal_bear": "res://assets/sfx/animal_bear.wav",
	"mount_neigh": "res://assets/sfx/mount_neigh.wav",
	"chest_open": "res://assets/sfx/chest_open.wav",
	"blood_stinger": "res://assets/sfx/blood_stinger.wav", # // FIX: R2-3 血月 stinger 此前未注册（死调用）
	"zone_tick": "res://assets/sfx/zone_tick.wav", # // FIX: R2-8 圈外掉血专用低鸣（原复用 hit.wav）
}

var _streams := {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _idx_2d := 0
var _idx_3d := 0
var _print_budget := 40 # // FIX: FX18/E2 日志限量：默认只打前 40 条，--verbose-sfx 恢复全量
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer
var _boss_on := false
var _night_player: AudioStreamPlayer
var _night_on := false


func _bus_for(name: String) -> String:
	# 业务分 bus：与 audio/bus_layout.tres 四分轨一致，缺省回落 SFX
	if name in ["music", "music_night", "boss", "victory", "defeat"]:
		return "Music"
	if name in ["ambience", "snowwind", "volcano", "rain_loop", "snow_loop"]:
		return "Ambience"
	if name in ["pickup", "capture", "cook"]:
		return "UI"
	return "SFX"


func _ready() -> void:
	for key in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_2d.append(p)
	for i in range(16):
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		# // FIX: M10 统一 3D 衰减：ATTENUATION_INVERSE_DISTANCE + max_distance 90 / unit 18 — 已验证
		p.max_distance = 90.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 18.0
		add_child(p)
		_pool_3d.append(p)
	# // FIX: OPT-E1/REG5 Master 挂 Limiter（ceiling -1dB）：多声叠加不再爆音削顶
	var master := AudioServer.get_bus_index("Master")
	if master >= 0 and AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, limiter)


# // FIX: FX13/E2 池分配优先空闲节点：SMG 连发不再吃掉 UI/命中确认音；全占用回退轮询
func _pick_2d() -> AudioStreamPlayer:
	for p in _pool_2d:
		if not p.playing:
			return p
	var p := _pool_2d[_idx_2d]
	_idx_2d = (_idx_2d + 1) % _pool_2d.size()
	return p


func _pick_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	var p := _pool_3d[_idx_3d]
	_idx_3d = (_idx_3d + 1) % _pool_3d.size()
	return p


func _log(msg: String) -> void:
	if OS.get_cmdline_user_args().has("--verbose-sfx") or _print_budget > 0:
		if not OS.get_cmdline_user_args().has("--verbose-sfx"):
			_print_budget -= 1
		print(msg)


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		print("[sfx] WARN missing sound: ", name) # // FIX: R2-C2a 静默失败曾让 blood_stinger 缺键溜过验收
		return
	if _streams[name] == null:
		print("[sfx] WARN null stream: ", name)
		return
	var p := _pick_2d()
	p.bus = _bus_for(name)
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()
	_log("[sfx] play %s bus=%s vol=%.1f" % [name, p.bus, volume_db])


func play_at(name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		print("[sfx] WARN missing sound: ", name)
		return
	if _streams[name] == null:
		print("[sfx] WARN null stream: ", name)
		return
	var p := _pick_3d()
	p.bus = _bus_for(name)
	p.global_position = pos
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	# // FIX: OPT-E4/FX15 分类衰减：枪声/爆炸 350m（原 90m 截断远距枪声）、脚步 60m、其余 90m
	if name.begins_with("shot_") or name == "explosion" or name == "thunder":
		p.max_distance = 350.0
	elif name.begins_with("footstep"):
		p.max_distance = 60.0
	else:
		p.max_distance = 90.0
	p.play()
	_log("[sfx] play_at %s bus=%s pos=%s" % [name, p.bus, str(pos)])


## 循环背景音乐 + 环境音（风/海浪/鸟鸣）
func start_ambience() -> void:
	var music: AudioStreamWAV = load("res://assets/sfx/music.wav")
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_end = int(music.get_length() * music.mix_rate)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.stream = music
	_music_player.volume_db = -16.0
	add_child(_music_player)
	_music_player.play()

	var amb: AudioStreamWAV = load("res://assets/sfx/ambience.wav")
	amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
	amb.loop_end = int(amb.get_length() * amb.mix_rate)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = "Ambience"
	_ambience_player.stream = amb
	_ambience_player.volume_db = -13.0
	add_child(_ambience_player)
	_ambience_player.play()
	# 夜曲播放器常驻、日常静音，昼夜交替时与白日配乐 3 秒交叉淡入淡出。
	var nmusic: AudioStreamWAV = load("res://assets/sfx/music_night.wav")
	nmusic.loop_mode = AudioStreamWAV.LOOP_FORWARD
	nmusic.loop_end = int(nmusic.get_length() * nmusic.mix_rate)
	_night_player = AudioStreamPlayer.new()
	_night_player.bus = "Music"
	_night_player.stream = nmusic
	_night_player.volume_db = -32.0
	add_child(_night_player)
	_night_player.play()


func set_streams_paused(paused: bool) -> void:
	for p in _pool_2d:
		p.stream_paused = paused
	for p in _pool_3d:
		p.stream_paused = paused
	if _music_player:
		_music_player.stream_paused = paused
	if _ambience_player:
		_ambience_player.stream_paused = paused
	if _boss_player:
		_boss_player.stream_paused = paused
	if _night_player:
		_night_player.stream_paused = paused


func _calc_music_volumes() -> Dictionary:
	# 统一计算三轨目标音量，避免昼夜与 Boss 互盖
	if _boss_on:
		return {"day": -30.0, "night": -32.0, "boss": -13.0}
	if _night_on:
		return {"day": -32.0, "night": -18.0, "boss": -32.0}
	return {"day": -16.0, "night": -32.0, "boss": -32.0}

func _apply_music_volumes(dur: float) -> void:
	var vols := _calc_music_volumes()
	var tw := create_tween()
	tw.set_parallel(true)
	if _music_player:
		tw.tween_property(_music_player, "volume_db", vols["day"], dur)
	if _night_player:
		tw.tween_property(_night_player, "volume_db", vols["night"], dur)
	if _boss_player:
		tw.tween_property(_boss_player, "volume_db", vols["boss"], dur)

# 昼夜音乐切换：入夜白日配乐淡出、夜曲淡入（3 秒缓慢交叉）。
func set_night_music(night: bool) -> void:
	if night == _night_on or _music_player == null or _night_player == null:
		return
	_night_on = night
	_apply_music_volumes(3.0)


# Boss 战音乐：进入战区渐强鼓点、压暗日常配乐；脱离战区淡回。
func set_boss_music(on: bool) -> void:
	if on == _boss_on:
		return
	_boss_on = on
	if on:
		if _boss_player == null:
			var track: AudioStreamWAV = load("res://assets/sfx/boss.wav")
			track.loop_mode = AudioStreamWAV.LOOP_FORWARD
			track.loop_end = int(track.get_length() * track.mix_rate)
			_boss_player = AudioStreamPlayer.new()
			_boss_player.bus = "Music"
			_boss_player.stream = track
			_boss_player.volume_db = -28.0
			add_child(_boss_player)
		_boss_player.play()
		_apply_music_volumes(1.2)
	elif _boss_player:
		var tw2 := create_tween()
		tw2.tween_property(_boss_player, "volume_db", -30.0, 1.2)
		tw2.chain().tween_callback(_boss_player.stop)
		# 同步把日常轨拉回当前昼夜应有音量
		if _music_player or _night_player:
			var vols := _calc_music_volumes()
			var tw3 := create_tween()
			tw3.set_parallel(true)
			if _music_player:
				tw3.tween_property(_music_player, "volume_db", vols["day"], 1.2)
			if _night_player:
				tw3.tween_property(_night_player, "volume_db", vols["night"], 1.2)


# // FIX: L2 Stinger 占位（窗口可验证）— 复用已有音轨，无需外部资产；后续可替换为专用采样。 [stinger] 日志可验证
# 关键事件：Hinox 倒下 / Boss 战胜利。调用方直接复用现有 victory/heavy_impact/defeat。
func play_hinox_down_stinger(pos: Vector3 = Vector3.ZERO) -> void:
	# // FIX: L2 占位实现：复用 victory(胜利动机) + heavy_impact(打击)，窗口通过 [stinger] hinox_down 日志验证。
	print("[stinger] hinox_down at %s" % str(pos))
	if _streams.has("victory"):
		play("victory", -2.0)
	if _streams.has("heavy_impact"):
		if pos != Vector3.ZERO:
			play_at("heavy_impact", pos, -3.0, 0.85)
		else:
			play("heavy_impact", -4.0, 0.85)


func play_boss_victory_stinger() -> void:
	# // FIX: L2 占位实现：复用 victory + heavy_impact；接入点为讨伐结算（main.gd _on_dragon_killed），[stinger] boss_victory 日志可验证
	print("[stinger] boss_victory")
	if _streams.has("victory"):
		play("victory", -2.0)
	if _streams.has("heavy_impact"):
		play("heavy_impact", -5.0, 0.78)


func _exit_tree() -> void:
	# 主动断开 AudioServer playback，避免场景重载后循环流继续持有 WAV 资源。
	for p in _pool_2d:
		p.stop()
		p.stream = null
	for p in _pool_3d:
		p.stop()
		p.stream = null
	if _music_player:
		_music_player.stop()
		_music_player.stream = null
	if _ambience_player:
		_ambience_player.stop()
		_ambience_player.stream = null
	if _boss_player:
		_boss_player.stop()
		_boss_player.stream = null
	if _night_player:
		_night_player.stop()
		_night_player.stream = null
	_streams.clear()
