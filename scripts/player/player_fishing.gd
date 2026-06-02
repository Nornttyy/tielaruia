# 钓鱼组件。挂在 Player 下, 与 PlayerHealth/PlayerBuffs 同级。
# 状态机: idle → waiting(等咬钩) → biting(收竿窗口) → (收竿成功 / 超时跑掉) → idle。
# 玩家持鱼竿右键 → on_rod_click(): idle 时甩竿, biting 时收竿, waiting 时空收。
# 视觉(浮标/鱼线) 由 _spawn_bobber/_on_bite/_despawn_bobber 处理 (F4 填实, 这里逻辑为主)。
extends Node

signal caught(item_id: String)

const BITE_WAIT_MIN := 2.0       # 最短等待 (秒)
const BITE_WAIT_MAX := 5.0       # 最长等待
const REEL_WINDOW := 1.5         # 咬钩后收竿窗口 (秒, 调宽点不太难)
const TILE_SIZE := 12

# 收获表: [item_id, weight]. 权重相对, 不必凑 100 (调稀有度改数字即可)。
const CATCH_TABLE := [
	["salmon", 20], ["tuna", 20], ["octopus", 20], ["sea_urchin", 20],
	["lobster", 20], ["eel", 20], ["sweet_shrimp", 18], ["scallop", 18],
	["seaweed", 15],
]

var _state: String = "idle"        # idle / waiting / biting
var _timer: float = 0.0            # waiting: 距咬钩; biting: 收竿窗口剩余
var _bobber_tile: Vector2i = Vector2i.ZERO


func state() -> String:
	return _state


func is_fishing() -> bool:
	return _state != "idle"


# player_action 持鱼竿右键时调。is_water = 瞄准格是不是水 (由 player_action 查好传进来)。
func on_rod_click(aim_tile: Vector2i, is_water: bool) -> void:
	match _state:
		"idle":
			if is_water:
				_start_cast(aim_tile)
			# 否则: 没对着水, 不开钓 (F4 给个轻提示)
		"waiting":
			_reset()       # 鱼还没咬就收 = 空收, 不惩罚
		"biting":
			_reel_success()


func _start_cast(tile: Vector2i) -> void:
	_bobber_tile = tile
	_state = "waiting"
	_timer = randf_range(BITE_WAIT_MIN, BITE_WAIT_MAX)
	_spawn_bobber(tile)


func _process(delta: float) -> void:
	if _state == "idle":
		return
	_timer -= delta
	if _state == "waiting":
		if _timer <= 0.0:
			_state = "biting"
			_timer = REEL_WINDOW
			_on_bite()
	elif _state == "biting":
		if _timer <= 0.0:
			_reset()       # 收竿窗口过了, 鱼跑


func _reel_success() -> void:
	var item_id: String = _roll_catch()
	var inv: Node = get_parent().get_node_or_null("PlayerInventory") if get_parent() != null else null
	if inv != null and inv.has_method("pickup"):
		inv.pickup(item_id, 1)
	caught.emit(item_id)
	_reset()


# 按权重随机抽 1 个收获
func _roll_catch() -> String:
	var total: int = 0
	for e in CATCH_TABLE:
		total += e[1]
	var r: int = randi() % total
	for e in CATCH_TABLE:
		r -= e[1]
		if r < 0:
			return e[0]
	return CATCH_TABLE[0][0]


func _reset() -> void:
	_state = "idle"
	_timer = 0.0
	_despawn_bobber()


# 测试用: 跳过随机等待, 直接进咬钩
func _force_bite() -> void:
	if _state == "waiting":
		_state = "biting"
		_timer = REEL_WINDOW
		_on_bite()


# === 视觉钩子 (F4 填实; 这里默认空操作, 不影响逻辑/测试) ===
func _spawn_bobber(_tile: Vector2i) -> void:
	pass


func _on_bite() -> void:
	pass


func _despawn_bobber() -> void:
	pass
