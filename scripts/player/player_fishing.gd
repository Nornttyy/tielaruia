# 钓鱼组件。挂在 Player 下, 与 PlayerHealth/PlayerBuffs 同级。
# 状态机: idle → waiting(等咬钩) → biting(收竿窗口) → (收竿成功 / 超时跑掉) → idle。
# 玩家持鱼竿右键 → on_rod_click(): idle 时甩竿, biting 时收竿, waiting 时空收。
# 视觉(浮标/鱼线) 由 _spawn_bobber/_on_bite/_despawn_bobber 处理 (F4 填实, 这里逻辑为主)。
extends Node

signal caught(item_id: String)

const PixelArt = preload("res://scripts/art/pixel_art.gd")
const CANCEL_DIST_PX := 9 * 12   # 玩家离浮标超 9 tile → 取消
# 红白浮标 8×8
const _BOBBER := [
	"..kkkk..",
	".krrrrk.",
	"krrrrrrk",
	"krrrrrrk",
	"kwwwwwwk",
	".kwwwwk.",
	"..kkkk..",
	"........",
]
const _BOBBER_PAL := {
	".": Color(0, 0, 0, 0),
	"k": Color8(120, 30, 30),
	"r": Color8(220, 60, 60),
	"w": Color8(245, 245, 245),
}

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
var _bobber: Sprite2D = null
var _line: Line2D = null
var _bobber_base_y: float = 0.0   # 浮标静止 y (咬钩时往下沉)


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
			return
	# 视觉: 鱼线跟着玩家; 玩家走太远则取消
	if _state != "idle":
		var p := get_parent() as Node2D
		if p != null and _bobber != null \
				and p.global_position.distance_to(_bobber.global_position) > CANCEL_DIST_PX:
			_reset()
			return
		_update_line()


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


# === 视觉: 浮标 (Sprite2D) + 鱼线 (Line2D), top_level 挂 effects_root (仿钩爪) ===
func _effects_root() -> Node:
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	return root if root != null else get_parent()


func _spawn_bobber(tile: Vector2i) -> void:
	_despawn_bobber()
	var pos := Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
	_bobber_base_y = pos.y
	var root: Node = _effects_root()
	# 鱼线 (竿→浮标), 细麻绳棕
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.55, 0.4, 0.25)
	_line.top_level = true
	_line.add_point(pos)
	_line.add_point(pos)
	root.add_child(_line)
	# 浮标
	_bobber = Sprite2D.new()
	_bobber.texture = PixelArt.grid_to_texture(_BOBBER, _BOBBER_PAL)
	_bobber.top_level = true
	_bobber.global_position = pos
	root.add_child(_bobber)
	_update_line()


# 咬钩: 浮标猛地往下沉几 px (视觉 cue, 不弹文字), 配轻音效
func _on_bite() -> void:
	if _bobber != null and is_instance_valid(_bobber):
		_bobber.global_position.y = _bobber_base_y + 4.0
	if SfxBank != null:
		SfxBank.play("place", 0.08)   # 轻"咚" (复用放置声, 小音量)


func _update_line() -> void:
	if _line == null or not is_instance_valid(_line):
		return
	var p := get_parent() as Node2D
	if p != null:
		# 竿尖大概在玩家腰偏上
		_line.set_point_position(0, p.global_position + Vector2(4, -16))
	if _bobber != null and is_instance_valid(_bobber):
		_line.set_point_position(1, _bobber.global_position)


func _despawn_bobber() -> void:
	if _bobber != null and is_instance_valid(_bobber):
		_bobber.queue_free()
	_bobber = null
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
