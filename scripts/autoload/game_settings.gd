# 全局设置 autoload。当前只有主音量。
# 设置 master_volume 时自动应用到 AudioServer 总线 0。
extends Node

var master_volume: float = 1.0:
	set(v):
		master_volume = clamp(v, 0.0, 1.0)
		_apply_to_audio_server()

# 当前游戏会话的世界配置 (主菜单 "新游戏" 配置面板写入)
# difficulty: 0=简单, 1=普通, 2=困难
var current_difficulty: int = 1
var current_world_name: String = ""


# 难度对玩家受伤的乘数: 简单 0.5x, 普通 1.0x, 困难 1.5x
func damage_multiplier() -> float:
	match current_difficulty:
		0: return 0.5
		2: return 1.5
		_: return 1.0


func _ready() -> void:
	_apply_to_audio_server()


func _apply_to_audio_server() -> void:
	var db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(0, db)
