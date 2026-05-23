# 手持物品视觉. 跟着 hotbar 选中的物品显示在玩家手里, 攻击/挖矿时挥摆动画.
# 由 player_controller 在 _ready 绑定 inventory + 每帧 set_facing; 由 player_action 在
# 挥剑/挖矿时调 play_swing.
extends Sprite2D

const HAND_OFFSET_X := 5.0     # 手相对玩家中心 x 偏移
const HAND_OFFSET_Y := -12.0   # y (玩家中部胸口位置)
const SWING_ANGLE_DEG := 75.0
const SWING_DURATION := 0.18

var _player_inventory: Node = null
var _facing_right: bool = true
var _tween: Tween = null


func _ready() -> void:
	centered = true
	position = Vector2(HAND_OFFSET_X, HAND_OFFSET_Y)
	visible = false
	z_index = 1  # 画在玩家身体前面


# player_controller._ready 调
func bind_inventory(inv: Node) -> void:
	_player_inventory = inv
	if inv.has_signal("hotbar_selection_changed"):
		inv.hotbar_selection_changed.connect(_on_changed)
	if inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_changed)
	_refresh()


# player_controller._physics_process 每帧调 (face 跟着 player flip_h 走)
func set_facing(right: bool) -> void:
	if right == _facing_right:
		return
	_facing_right = right
	# 镜像 + 反向手偏移
	scale.x = 1.0 if right else -1.0
	position.x = HAND_OFFSET_X if right else -HAND_OFFSET_X


# player_action 调: 一次挥砍/挥镐动画
func play_swing() -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rotation = 0.0
	_tween = create_tween()
	var dir: float = 1.0 if _facing_right else -1.0
	# 起手: 向后抬 (反向 ~30°), 然后劈到前方 +75°, 再回 0
	_tween.tween_property(self, "rotation", deg_to_rad(-30.0 * dir), SWING_DURATION * 0.25)
	_tween.tween_property(self, "rotation", deg_to_rad(SWING_ANGLE_DEG * dir), SWING_DURATION * 0.35)
	_tween.tween_property(self, "rotation", 0.0, SWING_DURATION * 0.40)


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
