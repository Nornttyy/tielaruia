# 玩家饱食度节点。挂在 Player 下。
# 信号: hunger_changed(cur,max)
# 与 PlayerHealth 对称。
extends Node

signal hunger_changed(current: int, maximum: int)

const MAX := 100
const DEPLETE_PER_SEC := 100.0 / (10.0 * 60.0)  # ≈0.1667，10 分钟掉满
const HUNGRY_THRESHOLD := 30                     # < 30 → 攻击 debuff + HUD 抖动
const HEAL_THRESHOLD := 80                       # ≥ 80 → 自动回 HP
const HEAL_INTERVAL_SEC := 5.0
const HEAL_AMOUNT := 1
const HUNGRY_ATK_MULT := 0.8

var current: float = float(MAX)
var _heal_timer: float = 0.0
var _last_emit_int: int = MAX
var _health_override: Node = null  # 测试注入用


func _physics_process(delta: float) -> void:
	current = max(0.0, current - DEPLETE_PER_SEC * delta)
	_tick_heal(delta)
	_maybe_emit()


func consume(amount: int) -> void:
	if amount <= 0:
		return
	current = min(float(MAX), current + float(amount))
	_maybe_emit()


func refill_full() -> void:
	current = float(MAX)
	_heal_timer = 0.0
	_maybe_emit()


func get_attack_multiplier() -> float:
	return HUNGRY_ATK_MULT if int(current) < HUNGRY_THRESHOLD else 1.0


func is_hungry() -> bool:
	return int(current) < HUNGRY_THRESHOLD


func emit_state() -> void:
	# 公共方法：HUD 绑定或加载存档时强制同步一次
	_last_emit_int = -1
	_maybe_emit()


func set_health_node_for_test(h: Node) -> void:
	_health_override = h


func _get_health() -> Node:
	if _health_override != null:
		return _health_override
	var parent := get_parent()
	return null if parent == null else parent.get_node_or_null("PlayerHealth")


func _tick_heal(delta: float) -> void:
	var hp: Node = _get_health()
	if hp == null or not hp.is_alive():
		_heal_timer = 0.0
		return
	if int(current) < HEAL_THRESHOLD:
		_heal_timer = 0.0
		return
	if hp.current_health >= hp.MAX_HEALTH:
		_heal_timer = 0.0
		return
	_heal_timer += delta
	if _heal_timer >= HEAL_INTERVAL_SEC:
		_heal_timer -= HEAL_INTERVAL_SEC
		hp.heal(HEAL_AMOUNT)


func _maybe_emit() -> void:
	# 用 ceil 避免: 1 帧后 99.997 → int=99 → HUD 立刻显示 9.5, 永远到不了满格
	# ceil(99.997)=100, 当 current ∈ (99, 100] 都显示 100 满 (6 秒后才降到 99 显示 9.5)
	var cur_i := int(ceil(current))
	if cur_i != _last_emit_int:
		_last_emit_int = cur_i
		hunger_changed.emit(cur_i, MAX)
