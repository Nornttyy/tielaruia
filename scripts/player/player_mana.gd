# 玩家魔力节点. 挂在 Player 下 (跟 PlayerHealth 同层).
# mana = 整数 (0..MAX_MANA), 每 _process 自动回 REGEN_PER_SEC * delta.
# 法杖发火球前调 try_consume(cost) → 成功扣 mana 并返 true.
extends Node

signal mana_changed(current: int, maximum: int)

const BASE_MAX_MANA := 100
const MAX_MANA_CAP := 200        # 上限 (10 颗星, Terraria 风)
const MANA_PER_CRYSTAL := 20     # 魔力水晶 +20 max
const REGEN_PER_SEC := 5.0   # 满血 100, 20s 全回

# var (非 const) — 未来星辰碎片之类可永久 +max
var MAX_MANA: int = BASE_MAX_MANA
var current_mana: int = BASE_MAX_MANA

var _regen_accum: float = 0.0


func _process(delta: float) -> void:
	if current_mana >= MAX_MANA:
		return
	_regen_accum += REGEN_PER_SEC * delta
	var add: int = int(floor(_regen_accum))
	if add > 0:
		_regen_accum -= float(add)
		current_mana = min(MAX_MANA, current_mana + add)
		mana_changed.emit(current_mana, MAX_MANA)


# 检查 + 消耗 (原子). 不够返 false 不扣.
func try_consume(cost: int) -> bool:
	if cost <= 0:
		return true
	# 对战房: 魔力无限 (不扣) → 法杖/魔法枪随便放, 跟箭/子弹/血药/方块一样无限
	if NetworkManager != null and NetworkManager.combat_enabled():
		return true
	if current_mana < cost:
		return false
	current_mana -= cost
	mana_changed.emit(current_mana, MAX_MANA)
	return true


# 满魔 (复活时调)
func refill_full() -> void:
	current_mana = MAX_MANA
	mana_changed.emit(current_mana, MAX_MANA)


# 永久 +MAX 用 (将来加星辰碎片之类)
func extend_max(amount: int) -> void:
	MAX_MANA += amount
	current_mana = min(MAX_MANA, current_mana + amount)
	mana_changed.emit(current_mana, MAX_MANA)


# 用魔力水晶: 永久 +MANA_PER_CRYSTAL max + 也加同量当前 mana.
# 已达 cap 返 false (玩家不能再吃). 否则返 true.
func try_extend_max(amount: int = MANA_PER_CRYSTAL) -> bool:
	if MAX_MANA >= MAX_MANA_CAP:
		return false
	MAX_MANA = min(MAX_MANA_CAP, MAX_MANA + amount)
	current_mana = min(MAX_MANA, current_mana + amount)
	mana_changed.emit(current_mana, MAX_MANA)
	return true
