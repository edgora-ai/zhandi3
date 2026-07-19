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
}

var _streams := {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _idx_2d := 0
var _idx_3d := 0


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
