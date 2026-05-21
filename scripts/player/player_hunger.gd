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


func _tick_heal(_delta: float) -> void:
    # Task 2 接 PlayerHealth；此处先空实现，保持帧逻辑结构。
    pass


func _maybe_emit() -> void:
    var cur_i := int(current)
    if cur_i != _last_emit_int:
        _last_emit_int = cur_i
        hunger_changed.emit(cur_i, MAX)
