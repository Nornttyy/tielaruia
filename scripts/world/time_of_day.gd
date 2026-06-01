# 昼夜循环 (autoload).
# time ∈ [0, 1) 一个完整日夜.
#   0.0-0.2 夜
#   0.2-0.3 日出 (lerp)
#   0.3-0.7 白天
#   0.7-0.8 日落 (lerp)
#   0.8-1.0 夜
# DAY_DURATION_SEC = 1200s (20 分钟一个日夜, ~10 分白天 + 10 分黑夜) — 跟 Minecraft 一致.
#
# 用法:
#   TimeOfDay.is_night()  → bool
#   TimeOfDay.sky_light_level()  → int 0..7 (给 DarknessLayer 用)
#   TimeOfDay.sky_color()  → Color (给天空背景用)
extends Node

const DAY_DURATION_SEC := 1200.0   # 20 分钟一个日夜 (Minecraft 标准, ~10 分白天 + 10 分黑夜)
const NIGHT_LIGHT := 4          # 夜里地表光值 (0..15, 越大越亮; 月光不至于全黑)
const DAY_LIGHT := 15           # 白天地表光值

const DAY_SKY := Color(0.55, 0.78, 0.95)      # 浅蓝
const DUSK_SKY := Color(0.85, 0.55, 0.40)     # 橙红
const NIGHT_SKY := Color(0.04, 0.05, 0.12)    # 深蓝紫

var time: float = 0.35  # 启动从早晨开始
# 时间流速倍数. 默认 1.0 (正常). 玩家上床睡觉时 world.gd 调高到 10.0 加速跳夜.
var time_multiplier: float = 1.0


func _process(delta: float) -> void:
	# 联机 client: 时间完全由 host 广播 (world._on_remote_time_weather 设 TimeOfDay.time).
	# 本地不再自走, 否则会跟 host 的广播打架 → 昼夜来回漂移/跳变.
	if NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host:
		return
	time += delta * time_multiplier / DAY_DURATION_SEC
	if time >= 1.0:
		time -= 1.0


# 当前是否夜间 (用于刷怪逻辑)
func is_night() -> bool:
	return time < 0.2 or time >= 0.8


# 当前是否白天
func is_day() -> bool:
	return time >= 0.3 and time < 0.7


# 0..1 浮点光度: 0=最黑, 1=最亮. 用于天空颜色 / 光强 lerp.
func day_factor() -> float:
	if time < 0.2:
		return 0.0
	elif time < 0.3:
		return (time - 0.2) / 0.1  # 日出 lerp 0→1
	elif time < 0.7:
		return 1.0
	elif time < 0.8:
		return 1.0 - (time - 0.7) / 0.1  # 日落 lerp 1→0
	else:
		return 0.0


# 0..7 整数, 给 TileLightGrid.compute_light 当地表块的"天光值".
func sky_light_level() -> int:
	var f: float = day_factor()
	return int(round(lerp(float(NIGHT_LIGHT), float(DAY_LIGHT), f)))


# 当前天空背景色 (白天蓝 / 黄昏橙 / 夜深紫)
func sky_color() -> Color:
	var f: float = day_factor()
	if f >= 0.8:
		return DAY_SKY
	if f <= 0.0:
		return NIGHT_SKY
	# 0..0.5 = night→dusk (warmer), 0.5..1 = dusk→day (cooler)
	if f < 0.5:
		return NIGHT_SKY.lerp(DUSK_SKY, f * 2.0)
	else:
		return DUSK_SKY.lerp(DAY_SKY, (f - 0.5) * 2.0)
