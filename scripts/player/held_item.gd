# 手持物品视觉. 跟着 hotbar 选中的物品显示在玩家手里, 攻击/挖矿时挥摆动画.
# 由 player_controller 在 _ready 绑定 inventory + 每帧 set_facing; 由 player_action 在
# 挥剑/挖矿时调 play_swing.
#
# 关键点: sprite 的旋转/缩放支点 = 玩家手部. 用 centered=false + offset 把贴图的
# 底部中心对齐到 position 这个"手"点, 这样挥摆时手柄不离手, 像真的握住一样.
extends Sprite2D

const HAND_OFFSET_X := 4.0     # 手相对玩家中心 x 偏移 (TILE_SIZE 16→12 后跟玩家缩 0.75)
const HAND_OFFSET_Y := -8.0    # y (玩家中部胸口位置)
const TOOL_SIZE := 1.0         # 工具 (剑/镐/斧) 原大小 16px (用户要求"工具太小了" → 0.7→1.0)
const BLOCK_SIZE := 0.55       # 方块/材料 缩到 55% (~9px)
const SWING_ANGLE_DEG := 75.0
const SWING_DURATION := 0.18

var _player_inventory: Node = null
var _facing_right: bool = true
var _tween: Tween = null
var _current_size: float = TOOL_SIZE
var _eating: bool = false
var _eat_phase: float = 0.0   # 进食动画时间累积 (秒)
# 攻击期间锁 facing: player_controller 每帧 set_facing 跟玩家走路方向,
# 攻击中翻 facing 会让 sprite 镜像但旋转值还是攻击时算的 → 朝向乱套. 锁住期间忽略.
var _attack_locked: bool = false


func _ready() -> void:
	# 支点放在贴图底部中心: 玩家手抓在物品底端 (剑柄 / 方块底沿)
	centered = false
	offset = Vector2(-8, -16)
	position = Vector2(HAND_OFFSET_X, HAND_OFFSET_Y)
	visible = false
	z_index = 1  # 画在玩家身体前面


func bind_inventory(inv: Node) -> void:
	_player_inventory = inv
	if inv.has_signal("hotbar_selection_changed"):
		inv.hotbar_selection_changed.connect(_on_changed)
	if inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_changed)
	_refresh()


func set_facing(right: bool) -> void:
	# 攻击中: 忽略 player_controller 的 facing 更新, 否则跟 play_thrust/swing 算的
	# 旋转值打架 (sprite 翻面但旋转还是攻击方向 → 朝向反了)
	if _attack_locked:
		return
	if right == _facing_right:
		return
	_facing_right = right
	_apply_scale()
	position.x = HAND_OFFSET_X if right else -HAND_OFFSET_X


# 进食动画开始: 食物上下抖动 + 微微旋转, 模拟"啃咬"
func start_eat() -> void:
	_eating = true
	_eat_phase = 0.0
	# 把潜在的挥摆 tween 杀掉, 避免冲突
	if _tween != null and _tween.is_valid():
		_tween.kill()


# 进食动画结束: 食物归位
func stop_eat() -> void:
	_eating = false
	_eat_phase = 0.0
	position = Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
	rotation = 0.0


func _process(delta: float) -> void:
	if not _eating or not visible:
		return
	_eat_phase += delta
	# 每 0.4 秒一次"啃咬" 循环 (2 秒共 5 口的节奏)
	var t: float = fmod(_eat_phase, 0.4) / 0.4   # 0..1 循环
	# 食物上下抖: 嘴边 (y - 6) ↔ 手里 (y + 0), 用正弦曲线让上下平滑
	var lift: float = sin(t * PI) * 6.0   # 0 → 6 → 0
	position = Vector2(
		HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X,
		HAND_OFFSET_Y - lift
	)
	# 食物轻微转一下, 看起来在咬
	var dir: float = 1.0 if _facing_right else -1.0
	rotation = sin(t * PI) * 0.25 * dir   # 最多 ±0.25 rad ≈ 14 度


func play_swing() -> void:
	# 节奏性挥摆 (挖矿/砍木用): 朝当前 facing 摆 ±75°
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rotation = 0.0
	_tween = create_tween()
	var dir: float = 1.0 if _facing_right else -1.0
	_tween.tween_property(self, "rotation", deg_to_rad(-30.0 * dir), SWING_DURATION * 0.25)
	_tween.tween_property(self, "rotation", deg_to_rad(SWING_ANGLE_DEG * dir), SWING_DURATION * 0.35)
	_tween.tween_property(self, "rotation", 0.0, SWING_DURATION * 0.40)


const THRUST_DURATION := 0.15
const THRUST_OFFSET_PX := 10.0   # 工具向前突进的距离 (TILE_SIZE 缩 0.75)
const PICKAXE_ATTACK_DURATION := 1.0   # 用户改 0.7→1.0 转慢一点


# 镐攻击: 工具全周转 360°. 用户改: 起始朝鼠标 (target_angle), 不再总从上方开始.
# target_angle: 鼠标相对玩家的角度 (radians, 0 = 右). 默认 -PI/2 = 上 (兼容老调用).
func play_pickaxe_attack(target_angle: float = -PI / 2.0) -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	# 跟着鼠标 facing (跟剑 sweep 同套路, 不靠玩家走路方向)
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)
	_attack_locked = true
	# sprite 默认朝上 (tip 在 -y), 要让 tip 起步朝 target_angle 得 + PI/2.
	# facing_left 时 sprite 已水平翻转, 旋转要反向.
	var s: float = 1.0 if _facing_right else -1.0
	var start_rot: float = wrapf(s * (target_angle + PI / 2.0), -PI, PI)
	rotation = start_rot
	_tween = create_tween()
	var dir: float = 1.0 if _facing_right else -1.0
	_tween.tween_property(self, "rotation", start_rot + deg_to_rad(360.0 * dir), PICKAXE_ATTACK_DURATION)
	_tween.tween_callback(func():
		rotation = 0.0
		_attack_locked = false
	)


# 戳 (剑): 朝鼠标方向向前突再收回, 不旋转 (跟挥不同, 挥是转圈弧)
func play_thrust(target_angle: float) -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false   # 先解锁, set_facing 才能跟着鼠标转
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)
	_attack_locked = true    # 锁住, 后续 player_controller set_facing 被忽略
	var dir_vec := Vector2(cos(target_angle), sin(target_angle))
	var base_pos := Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
	var thrust_pos := base_pos + dir_vec * THRUST_OFFSET_PX
	# 工具锋朝鼠标 (突刺感). sword sprite 默认朝上, 要朝水平方向得 + PI/2.
	# facing_left 时 sprite 已水平翻转, 旋转要反向 (跟 play_swing_directional 同套路).
	var s: float = 1.0 if _facing_right else -1.0
	rotation = wrapf(s * (target_angle + PI / 2.0), -PI, PI)
	position = base_pos
	_tween = create_tween()
	_tween.tween_property(self, "position", thrust_pos, THRUST_DURATION * 0.4).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", base_pos, THRUST_DURATION * 0.6).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		rotation = 0.0
		_attack_locked = false
	)


func play_swing_directional(target_angle: float) -> void:
	# 定向挥击 (挥剑用): 沿 target_angle 方向划 180° 半圆 (用户改: Terraria 风).
	# 攻击时把 sprite 朝向锁到鼠标方向, 避免移动中翻面让剑乱飞.
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)  # 跟鼠标走, 不跟玩家走路方向
	_attack_locked = true
	var s: float = 1.0 if _facing_right else -1.0
	# wrapf 把 base 归一到 [-PI, PI), 防止 facing_left + target_left 的 -7PI/4 那种值
	var base: float = wrapf(s * (target_angle + PI / 2.0), -PI, PI)
	var start_a: float = base - deg_to_rad(90.0)
	var end_a:   float = base + deg_to_rad(90.0)
	rotation = start_a
	_tween = create_tween()
	_tween.tween_property(self, "rotation", end_a, SWING_DURATION)
	_tween.tween_callback(func(): _attack_locked = false)


func _on_changed(_arg = null) -> void:
	_refresh()


func _refresh() -> void:
	if _player_inventory == null:
		visible = false
		return
	var slot = _player_inventory.current_hotbar_slot()
	if slot == null:
		visible = false
		return
	var tex: Texture2D = ArtCache.get_inventory_icon(slot.item_id)
	if tex == null:
		visible = false
		return
	texture = tex
	visible = true
	# 工具用原大小, 其他物品缩小
	_current_size = TOOL_SIZE if _is_tool(slot.item_id) else BLOCK_SIZE
	_apply_scale()


func _is_tool(item_id: String) -> bool:
	var def = ItemDB.get_def(item_id)
	return def != null and def.tool_kind != ""


func _apply_scale() -> void:
	var sx: float = _current_size if _facing_right else -_current_size
	scale = Vector2(sx, _current_size)
