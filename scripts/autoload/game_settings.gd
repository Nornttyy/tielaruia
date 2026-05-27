# 全局设置 autoload。音量 + 图形开关 (持久化到 user://settings.cfg)。
# 改设置时自动落盘 + 发 settings_changed 信号让其他系统响应.
extends Node

const SETTINGS_PATH := "user://settings.cfg"

# 任何 graphics 字段变 → 这个信号广播. world.gd 等会接住重新 apply.
signal settings_changed()

var master_volume: float = 1.0:
	set(v):
		master_volume = clamp(v, 0.0, 1.0)
		_apply_to_audio_server()
		_save()

# 当前游戏会话的世界配置 (主菜单 "新游戏" 配置面板写入)
# difficulty: 0=简单, 1=普通, 2=困难
var current_difficulty: int = 1
var current_world_name: String = ""

# ===== 图形开关 (用户在设置面板里勾选, 持久化) =====
# show_rain: 下雨粒子, 关掉省 GPU
var show_rain: bool = true:
	set(v):
		if show_rain == v: return
		show_rain = v
		_save_and_emit()

# show_parallax: 远景视差 (云 + 远山 + 矿洞远景), 关掉省 draw_call
var show_parallax: bool = true:
	set(v):
		if show_parallax == v: return
		show_parallax = v
		_save_and_emit()

# show_flocks: 鸟群 / 蝠群 等装饰小动物, 关掉省 sprite 数
var show_flocks: bool = true:
	set(v):
		if show_flocks == v: return
		show_flocks = v
		_save_and_emit()

# water_sim_enabled: 流水模拟. 关掉 = 静止水 (放水仍是水, 但不流), 大型水库省 CPU
var water_sim_enabled: bool = true:
	set(v):
		if water_sim_enabled == v: return
		water_sim_enabled = v
		_save_and_emit()

# camera_zoom: 摄像机大小 (越小看得越远, 越大看得越近). World 的 Camera2D 同步.
# 默认 1.2 (跟 world.tscn 原值一致). 范围 0.5 (远视野) ~ 2.5 (近距离)
var camera_zoom: float = 0.8:
	set(v):
		var clamped: float = clampf(v, 0.5, 2.5)
		if camera_zoom == clamped: return
		camera_zoom = clamped
		_save_and_emit()


# 难度对玩家受伤的乘数: 简单 0.5x, 普通 1.0x, 困难 1.5x
func damage_multiplier() -> float:
	match current_difficulty:
		0: return 0.5
		2: return 1.5
		_: return 1.0


func _ready() -> void:
	_load()
	_apply_to_audio_server()


func _apply_to_audio_server() -> void:
	var db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(0, db)


func _save_and_emit() -> void:
	_save()
	settings_changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("graphics", "show_rain", show_rain)
	cfg.set_value("graphics", "show_parallax", show_parallax)
	cfg.set_value("graphics", "show_flocks", show_flocks)
	cfg.set_value("graphics", "water_sim_enabled", water_sim_enabled)
	cfg.set_value("camera", "zoom", camera_zoom)
	cfg.save(SETTINGS_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # 文件不存在 → 用默认值
	# 直接赋字段, 绕开 setter 避免 _ready 阶段多次重存盘
	master_volume = clamp(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	# 图形开关: UI 已删, perf 优化默认: 远景/水开, 鸟蝠/雨关
	show_rain = true       # 雨已彻底删, 这个 flag 没意义
	show_parallax = true   # 远山+矿洞背景, 不卡
	show_flocks = false    # 鸟蝠 perf: 36 sprite × 2 每帧 sin 扑翼, 默认关
	water_sim_enabled = true
	camera_zoom = clampf(float(cfg.get_value("camera", "zoom", 0.8)), 0.5, 2.5)
