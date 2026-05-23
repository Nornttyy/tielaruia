# 手持物品视觉. 跟着 hotbar 选中的物品显示在玩家手里, 攻击/挖矿时挥摆动画.
# 由 player_controller 在 _ready 绑定 inventory + 每帧 set_facing; 由 player_action 在
# 挥剑/挖矿时调 play_swing.
#
# 关键点: sprite 的旋转/缩放支点 = 玩家手部. 用 centered=false + offset 把贴图的
# 底部中心对齐到 position 这个"手"点, 这样挥摆时手柄不离手, 像真的握住一样.
extends Sprite2D

const HAND_OFFSET_X := 5.0     # 手相对玩家中心 x 偏移
const HAND_OFFSET_Y := -10.0   # y (玩家中部胸口位置)
const TOOL_SIZE := 0.7         # 工具 (剑/镐/斧) 缩到 70% (~11px)
const BLOCK_SIZE := 0.55       # 方块/材料 缩到 55% (~9px)
const SWING_ANGLE_DEG := 75.0
const SWING_DURATION := 0.18

var _player_inventory: Node = null
var _facing_right: bool = true
var _tween: Tween = null
var _current_size: float = TOOL_SIZE


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
	if right == _facing_right:
		return
	_facing_right = right
	_apply_scale()
	position.x = HAND_OFFSET_X if right else -HAND_OFFSET_X


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


func play_swing_directional(target_angle: float) -> void:
	# 定向挥击 (挥剑用): 沿 target_angle 方向划 90° 弧.
	# 攻击时把 sprite 朝向锁到鼠标方向, 避免移动中翻面让剑乱飞.
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)  # 跟鼠标走, 不跟玩家走路方向
	var s: float = 1.0 if _facing_right else -1.0
	var base: float = s * (target_angle + PI / 2.0)
	var start_a: float = base - deg_to_rad(45.0)
	var end_a:   float = base + deg_to_rad(45.0)
	rotation = start_a
	_tween = create_tween()
	_tween.tween_property(self, "rotation", end_a, SWING_DURATION)


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
