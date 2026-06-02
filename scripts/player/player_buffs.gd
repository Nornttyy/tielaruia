# 玩家临时增益 (buff) 组件。挂在 Player 下, 与 PlayerHealth/PlayerMana 同级。
# 4 种 kind: speed(跑快) / jump(跳高) / mining(挖快) / regen(慢回血)。
# 同种 buff 再吃刷新时长; 不同种叠加。regen 活跃时每秒帮玩家回血。
extends Node

signal buffs_changed

const SPEED_MUL := 1.4               # 跑快倍数
const JUMP_MUL := 1.3                # 跳高倍数 (乘到负的 JUMP_VELOCITY → 更高)
const MINING_MUL := 1.8              # 挖快倍数
const BUFF_REGEN_INTERVAL := 1.0     # regen buff: 每 1 秒
const BUFF_REGEN_AMOUNT := 2         # 回 2 点 (比自然回血快)

var _active: Dictionary = {}   # kind:String -> remaining_secs:float
var _total: Dictionary = {}    # kind:String -> total_secs:float (给 HUD 算倒计时比例)
var _regen_t: float = 0.0


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var changed: bool = false
	for kind in _active.keys():          # keys() 是副本, 迭代中可 erase
		_active[kind] -= delta
		if _active[kind] <= 0.0:
			_active.erase(kind)
			_total.erase(kind)
			changed = true
	# regen buff: 持续回血
	if _active.has("regen"):
		_regen_t += delta
		if _regen_t >= BUFF_REGEN_INTERVAL:
			_regen_t -= BUFF_REGEN_INTERVAL
			var hp: Node = get_parent().get_node_or_null("PlayerHealth")
			if hp != null and hp.has_method("heal"):
				hp.heal(BUFF_REGEN_AMOUNT)
	else:
		_regen_t = 0.0
	if changed:
		buffs_changed.emit()


func apply(kind: String, secs: float) -> void:
	if kind == "" or secs <= 0.0:
		return
	# 取最长 (再吃个短 buff 不该缩短已有的长 buff)
	var new_secs: float = maxf(_active.get(kind, 0.0), secs)
	_active[kind] = new_secs
	_total[kind] = maxf(_total.get(kind, 0.0), new_secs)
	buffs_changed.emit()


func is_active(kind: String) -> bool:
	return _active.has(kind)


func remaining(kind: String) -> float:
	return _active.get(kind, 0.0)


func remaining_frac(kind: String) -> float:
	var total: float = _total.get(kind, 1.0)
	return clamp(_active.get(kind, 0.0) / maxf(total, 0.001), 0.0, 1.0)


func active_kinds() -> Array:
	return _active.keys()


func speed_mul() -> float:
	return SPEED_MUL if _active.has("speed") else 1.0


func jump_mul() -> float:
	return JUMP_MUL if _active.has("jump") else 1.0


func mining_mul() -> float:
	return MINING_MUL if _active.has("mining") else 1.0
