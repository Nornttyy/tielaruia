# 天气状态机. 挂在 World 下面.
# 状态: "clear" (晴天) / "rainy" (下雨).
# 随机切换: 晴天 5-10 分钟 → 雨 1-3 分钟 → 晴天.
# 启动时晴天.
extends Node

signal weather_changed(state: String)
signal lightning_flash

const CLEAR_MIN_SEC := 60.0     # 晴天最短 1 分钟 (测试方便, 真要部署可拉长到 300)
const CLEAR_MAX_SEC := 180.0    # 晴天最长 3 分钟
const RAIN_MIN_SEC := 30.0
const RAIN_MAX_SEC := 90.0

# 雨中闪雷间隔 (秒)
const LIGHTNING_MIN_INTERVAL := 8.0
const LIGHTNING_MAX_INTERVAL := 25.0

var state: String = "clear"
var _time_left: float = 0.0
var _lightning_t: float = 0.0


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


func _enter_state(s: String) -> void:
	state = s
	if s == "clear":
		_time_left = randf_range(CLEAR_MIN_SEC, CLEAR_MAX_SEC)
	else:
		_time_left = randf_range(RAIN_MIN_SEC, RAIN_MAX_SEC)
		_lightning_t = randf_range(LIGHTNING_MIN_INTERVAL, LIGHTNING_MAX_INTERVAL)
	weather_changed.emit(s)


# 测试 / 调试用: 强制切到某天气
func force_state(s: String) -> void:
	_enter_state(s)


func is_raining() -> bool:
	return state == "rainy"
