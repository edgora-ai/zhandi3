class_name SfxBank
extends Node
## 音效池：2D 全局音 + 3D 位置音，循环复用播放器节点

const SOUNDS := {
	"shot_rifle": "res://assets/sfx/shot_rifle.wav",
	"shot_dmr": "res://assets/sfx/shot_dmr.wav",
	"shot_smg": "res://assets/sfx/shot_smg.wav",
	"hit": "res://assets/sfx/hit.wav",
	"zone_alarm": "res://assets/sfx/zone_alarm.wav",
	"capture": "res://assets/sfx/capture.wav",
	"victory": "res://assets/sfx/victory.wav",
	"defeat": "res://assets/sfx/defeat.wav",
	"pickup": "res://assets/sfx/pickup.wav",
	"cook": "res://assets/sfx/cook.wav",
}

var _streams := {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _idx_2d := 0
var _idx_3d := 0
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _boss_player: AudioStreamPlayer
var _boss_on := false


func _ready() -> void:
	for key in SOUNDS:
		_streams[key] = load(SOUNDS[key])
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool_2d.append(p)
	for i in range(16):
		var p := AudioStreamPlayer3D.new()
		p.bus = "Master"
		p.max_distance = 120.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 6.0
		add_child(p)
		_pool_3d.append(p)


func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool_2d[_idx_2d]
	_idx_2d = (_idx_2d + 1) % _pool_2d.size()
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()


func play_at(name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool_3d[_idx_3d]
	_idx_3d = (_idx_3d + 1) % _pool_3d.size()
	p.global_position = pos
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


## 循环背景音乐 + 环境音（风/海浪/鸟鸣）
func start_ambience() -> void:
	var music: AudioStreamWAV = load("res://assets/sfx/music.wav")
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_end = int(music.get_length() * music.mix_rate)
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = music
	_music_player.volume_db = -16.0
	add_child(_music_player)
	_music_player.play()

	var amb: AudioStreamWAV = load("res://assets/sfx/ambience.wav")
	amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
	amb.loop_end = int(amb.get_length() * amb.mix_rate)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.stream = amb
	_ambience_player.volume_db = -13.0
	add_child(_ambience_player)
	_ambience_player.play()


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
			_boss_player.stream = track
			_boss_player.volume_db = -28.0
			add_child(_boss_player)
		_boss_player.play()
		var tw := create_tween()
		tw.set_parallel(true)
		if _music_player:
			tw.tween_property(_music_player, "volume_db", -30.0, 1.2)
		tw.tween_property(_boss_player, "volume_db", -13.0, 1.2)
	elif _boss_player:
		var tw2 := create_tween()
		tw2.set_parallel(true)
		if _music_player:
			tw2.tween_property(_music_player, "volume_db", -16.0, 1.2)
		tw2.tween_property(_boss_player, "volume_db", -30.0, 1.2)
		tw2.chain().tween_callback(_boss_player.stop)


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
	_streams.clear()
