# 天气状态机. 挂在 World 下面.
# 状态: "clear" (晴天) / "rainy" (下雨).
# 随机切换: 晴天 5-10 分钟 → 雨 1-3 分钟 → 晴天.
# 启动时晴天.
extends Node

signal weather_changed(state: String)
signal lightning_flash

const CLEAR_MIN_SEC := 90.0     # 晴天最短 1.5 分钟
const CLEAR_MAX_SEC := 240.0    # 晴天最长 4 分钟
const RAIN_MIN_SEC := 30.0
const RAIN_MAX_SEC := 90.0
# 进游戏第一次晴天缩短, 让玩家快点见到雨
const FIRST_CLEAR_MIN_SEC := 20.0
const FIRST_CLEAR_MAX_SEC := 40.0

# 雨中闪雷间隔 (秒)
const LIGHTNING_MIN_INTERVAL := 8.0
const LIGHTNING_MAX_INTERVAL := 25.0

var state: String = "clear"
var _time_left: float = 0.0
var _lightning_t: float = 0.0
var _first_clear: bool = true


func _ready() -> void:
	_enter_state("clear")


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		if state == "clear":
			_enter_state("rainy")
		else:
			_enter_state("clear")
	if state == "rainy":
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(LIGHTNING_MIN_INTERVAL, LIGHTNING_MAX_INTERVAL)
			lightning_flash.emit()
	# F10 强制切换 (debug)
	if Input.is_action_just_pressed("toggle_weather"):
		toggle()


func _enter_state(s: String) -> void:
	state = s
	if s == "clear":
		if _first_clear:
			_time_left = randf_range(FIRST_CLEAR_MIN_SEC, FIRST_CLEAR_MAX_SEC)
			_first_clear = false
		else:
			_time_left = randf_range(CLEAR_MIN_SEC, CLEAR_MAX_SEC)
	else:
		_time_left = randf_range(RAIN_MIN_SEC, RAIN_MAX_SEC)
		_lightning_t = randf_range(LIGHTNING_MIN_INTERVAL, LIGHTNING_MAX_INTERVAL)
	print("[Weather] → ", s, " (持续 ", "%.1f" % _time_left, "s)")
	weather_changed.emit(s)


# 切换天气 (debug 用)
func toggle() -> void:
	if state == "clear":
		_enter_state("rainy")
	else:
		_enter_state("clear")


# 测试 / 调试用: 强制切到某天气
func force_state(s: String) -> void:
	_enter_state(s)


func is_raining() -> bool:
	return state == "rainy"
