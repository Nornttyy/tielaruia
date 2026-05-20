# 全局设置 autoload。当前只有主音量。
# 设置 master_volume 时自动应用到 AudioServer 总线 0。
extends Node

var master_volume: float = 1.0:
	set(v):
		master_volume = clamp(v, 0.0, 1.0)
		_apply_to_audio_server()


func _ready() -> void:
	_apply_to_audio_server()


func _apply_to_audio_server() -> void:
	var db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(0, db)
