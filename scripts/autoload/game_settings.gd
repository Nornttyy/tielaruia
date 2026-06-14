# 全局设置 autoload。音量 + 图形开关 (持久化到 user://settings.cfg)。
# 改设置时自动落盘 + 发 settings_changed 信号让其他系统响应.
extends Node

const SETTINGS_PATH := "user://settings.cfg"

# 任何 graphics 字段变 → 这个信号广播. world.gd 等会接住重新 apply.
signal settings_changed()

var _suppress_save: bool = false   # 拖音量滑条时临时置位: 应用音频但不落盘 (松手再存)
var master_volume: float = 1.0:
	set(v):
		master_volume = clamp(v, 0.0, 1.0)
		_apply_to_audio_server()
		if not _suppress_save:
			_save()

# 拖动音量滑条时用: 立即应用音频但不落盘 (滑条 value_changed 每像素一次, 不然拖一下写几十次盘).
func set_master_volume_live(v: float) -> void:
	_suppress_save = true
	master_volume = v
	_suppress_save = false

# 松手时调: 真正存盘一次.
func save_now() -> void:
	_save()

# 当前游戏会话的世界配置 (主菜单 "新游戏" 配置面板写入)
# difficulty: 0=简单, 1=普通, 2=困难
var current_difficulty: int = 1
var current_world_name: String = ""
# 当前世界大小 (0=小 1=中 2=大). 影响 biome 间距 + 金字塔数量.
# 不持久化到 settings.cfg — 是 per-world 的, 从 SaveData 读 (新世界从 start_game opts 写入).
var current_world_size: int = 1


# 世界大小尺度: 小 0.5x / 中 1.0x / 大 1.6x. 用来缩放 BIOME_SLOTS 距离 + 影响 pyramid 数.
# 静态 access: world_generator 静态函数读这个 (autoload 调用 = 同 process 内同 Engine state)
func world_size_scale() -> float:
	match current_world_size:
		0: return 0.5
		2: return 1.6
		_: return 1.0


# 金字塔数量乘数 (1=1 个 / 2=2-3 / 3=3-5 起始)
func pyramid_count_range() -> Array:
	match current_world_size:
		0: return [1, 1]      # 小: 1 个
		2: return [3, 5]      # 大: 3-5 个
		_: return [2, 3]      # 中: 2-3 个 (现行)


# 世纪树已删 (用户要求), world_tree_count_range 函数已移除


# 废弃矿井数量: 小 1 / 中 2-3 / 大 3-5
func mineshaft_count_range() -> Array:
	match current_world_size:
		0: return [1, 1]
		2: return [3, 5]
		_: return [2, 3]


# 空岛数量: 小 1 / 中 2-3 / 大 3-5 (跟金字塔/废弃矿井同款缩放)
func skyisland_count_range() -> Array:
	match current_world_size:
		0: return [1, 1]
		2: return [3, 5]
		_: return [2, 3]

# ===== 图形开关 (用户在设置面板里勾选, 持久化) =====
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

# max_fps: 帧率上限. 0 = 不限. 默认 60. 设置里玩家可选 30/60/120/不限.
var max_fps: int = 60:
	set(v):
		max_fps = max(0, v)
		Engine.max_fps = max_fps
		_save()

# graphics_quality: 画质预设. 0=流畅(关视差+鸟群) / 1=标准(视差开,鸟群关) / 2=精细(都开).
# 总开关: 控最吃性能的视觉层 (视差背景 + 鸟群). 越低越省, 像素本体画质不变。
var graphics_quality: int = 1:
	set(v):
		graphics_quality = clampi(v, 0, 2)
		show_parallax = graphics_quality >= 1   # 各自 setter 会 apply + 存
		show_flocks = graphics_quality >= 2
		_save()

# camera_zoom: 摄像机大小 (越小看得越远, 越大看得越近). World 的 Camera2D 同步.
# 默认 1.0. 范围 1.0 (最远/最缩) ~ 2.0 (近距离/最放大). 滚轮/滑块都走这个 clamp.
# (下限从 0.8 抬到 1.0: 用户嫌滚轮拉太远. clamp 下限 1.0 会把旧存档的 0.8/0.5 自动夹回.)
var camera_zoom: float = 1.0:
	set(v):
		var clamped: float = clampf(v, 1.0, 2.0)
		if camera_zoom == clamped: return
		camera_zoom = clamped
		_save_and_emit()

# scroll_wheel_zoom: 鼠标滚轮干啥. false=切换快捷栏物品 (默认), true=缩放摄像头.
var scroll_wheel_zoom: bool = false:
	set(v):
		if scroll_wheel_zoom == v: return
		scroll_wheel_zoom = v
		_save_and_emit()
# 连续放置: 按住右键就连续放方块 (默认开, 像 Terraria); 关掉就一下一个
var continuous_place: bool = true:
	set(v):
		if continuous_place == v: return
		continuous_place = v
		_save()

# creative_mode: 创造模式 (飞行/秒挖秒放/无限方块/不掉血). 会话变量 — 按"每个世界"存在
# save_data 里, 不写全局 settings.cfg. 读档/新建/暂停切时由 main / pause_menu 设置它.
var creative_mode: bool = false

# current_language: UI 语言. "zh" / "en" / "ja" / "ko". 默认中文.
# Locale autoload 读这个值 + 发 language_changed 信号让 UI 刷新.
var current_language: String = "zh":
	set(v):
		if current_language == v: return
		current_language = v
		_save()

# player_name: 玩家自己起的名字. 显示在死亡画面 / 联机时给对方看 / 存档 metadata.
# 长度限 1-16, 空字符串 fallback "玩家". 持久化到 settings.cfg.
var player_name: String = "玩家":
	set(v):
		var trimmed: String = v.strip_edges()
		if trimmed.length() > 16:
			trimmed = trimmed.substr(0, 16)
		if trimmed.is_empty():
			trimmed = "玩家"
		if player_name == trimmed: return
		player_name = trimmed
		_save()

# 怪物血条 / 血量数字开关. 默认都开. 玩家可在设置里关掉减视觉杂乱.
var show_enemy_hp_bar: bool = true:
	set(v):
		if show_enemy_hp_bar == v: return
		show_enemy_hp_bar = v
		_save_and_emit()   # HealthBar 监听 settings_changed 立刻重画

var show_enemy_hp_number: bool = true:
	set(v):
		if show_enemy_hp_number == v: return
		show_enemy_hp_number = v
		_save_and_emit()

# ===== 多人游戏设置 =====
# 联机时是否显示别人头顶的名字
var mp_show_names: bool = true:
	set(v):
		if mp_show_names == v: return
		mp_show_names = v
		_save_and_emit()   # remote_player 监听 settings_changed 立刻显/隐名字
# 联机聊天开关 (关掉就不弹聊天框/不显聊天栏)
var mp_chat_enabled: bool = true:
	set(v):
		if mp_chat_enabled == v: return
		mp_chat_enabled = v
		_save()
# 我开房时每个公共房最多几人 (2..8). 只影响我当 host 的房。
var mp_max_players: int = 8:
	set(v):
		var c: int = clampi(v, 2, 8)
		if mp_max_players == c: return
		mp_max_players = c
		_save()
# 我开房时的难度 (0简/1普/2难). 我当 host → 这个难度同步给所有人 (经 hello)。
var mp_host_difficulty: int = 1:
	set(v):
		var c: int = clampi(v, 0, 2)
		if mp_host_difficulty == c: return
		mp_host_difficulty = c
		_save()


# 难度对玩家受伤的乘数: 简单 0.5x, 普通 1.0x, 困难 1.5x
func damage_multiplier() -> float:
	match current_difficulty:
		0: return 0.5
		2: return 1.5
		_: return 1.0


# 难度对怪物 HP 的乘数: 简单 0.7x (易杀), 普通 1.0x (基准), 困难 1.4x (怪更硬).
# 怪在 _ready 里 max_health = int(round(base * enemy_hp_multiplier())).
# 跟 damage_multiplier 一起把"简单/普通/困难"做成真有质感的三档.
func enemy_hp_multiplier() -> float:
	match current_difficulty:
		0: return 0.7
		2: return 1.4
		_: return 1.0


func _ready() -> void:
	_load()
	_apply_to_audio_server()
	Engine.max_fps = max_fps   # 应用帧率上限 (没存档时也保证默认生效)


func _apply_to_audio_server() -> void:
	var db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(0, db)


func _save_and_emit() -> void:
	_save()
	settings_changed.emit()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("graphics", "show_parallax", show_parallax)
	cfg.set_value("graphics", "show_flocks", show_flocks)
	cfg.set_value("graphics", "water_sim_enabled", water_sim_enabled)
	cfg.set_value("graphics", "quality", graphics_quality)
	cfg.set_value("video", "max_fps", max_fps)
	cfg.set_value("camera", "zoom", camera_zoom)
	cfg.set_value("locale", "language", current_language)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("hud", "enemy_hp_bar", show_enemy_hp_bar)
	cfg.set_value("hud", "enemy_hp_number", show_enemy_hp_number)
	cfg.set_value("input", "scroll_wheel_zoom", scroll_wheel_zoom)
	cfg.set_value("input", "continuous_place", continuous_place)
	cfg.set_value("mp", "show_names", mp_show_names)
	cfg.set_value("mp", "chat_enabled", mp_chat_enabled)
	cfg.set_value("mp", "max_players", mp_max_players)
	cfg.set_value("mp", "host_difficulty", mp_host_difficulty)
	cfg.save(SETTINGS_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # 文件不存在 → 用默认值
	# 直接赋字段, 绕开 setter 避免 _ready 阶段多次重存盘
	master_volume = clamp(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
	# 画质预设 (总管视差+鸟群): 默认 1 标准 (视差开/鸟群关, 跟旧默认一致). setter 会应用到 parallax/flocks。
	water_sim_enabled = true
	graphics_quality = clampi(int(cfg.get_value("graphics", "quality", 1)), 0, 2)
	# 帧率上限 (0=不限). setter 会应用 Engine.max_fps。
	max_fps = max(0, int(cfg.get_value("video", "max_fps", 60)))
	camera_zoom = clampf(float(cfg.get_value("camera", "zoom", 1.0)), 1.0, 2.0)
	# 语言: 只接受 4 个支持的代码, 其他值退回中文
	var saved_lang: String = String(cfg.get_value("locale", "language", "zh"))
	current_language = saved_lang if ["zh", "en", "ja", "ko"].has(saved_lang) else "zh"
	# 玩家名: setter 自己会 strip + clamp + empty fallback
	player_name = String(cfg.get_value("player", "name", "玩家"))
	# 怪物血条/数字开关: 默认都开
	show_enemy_hp_bar = bool(cfg.get_value("hud", "enemy_hp_bar", true))
	show_enemy_hp_number = bool(cfg.get_value("hud", "enemy_hp_number", true))
	scroll_wheel_zoom = bool(cfg.get_value("input", "scroll_wheel_zoom", false))
	continuous_place = bool(cfg.get_value("input", "continuous_place", true))
	# 多人游戏设置
	mp_show_names = bool(cfg.get_value("mp", "show_names", true))
	mp_chat_enabled = bool(cfg.get_value("mp", "chat_enabled", true))
	mp_max_players = clampi(int(cfg.get_value("mp", "max_players", 8)), 2, 8)
	mp_host_difficulty = clampi(int(cfg.get_value("mp", "host_difficulty", 1)), 0, 2)
