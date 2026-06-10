# 远程玩家 sprite. 不响应输入, 只跟 NetworkManager 推送的位置. 用 lerp 平滑
# (避免网络抖动导致瞬移).
# 由 world.gd 在收到 NetworkManager.remote_player_joined 信号时实例化.
extends Node2D

# 收到的目标位置 (lerp target). 实际位置 (self.global_position) 平滑追上.
var peer_id: String = ""   # 这个远程玩家对应的 peer (多人时区分谁是谁)
var _target_pos: Vector2 = Vector2.ZERO
var _facing_right: bool = true
var _current_anim: String = "idle"
const LERP_SPEED := 8.0   # 每秒收敛 8/s, 0.1s 内大致到位

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	# 远程玩家用跟本地玩家一样的正常外观 (用户要求联机不给玩家染色). 靠头顶名字区分谁是谁.
	_sprite.sprite_frames = ArtCache.player_frames
	_sprite.play("idle")
	_sprite.modulate = Color.WHITE  # 不染色, 正常颜色
	z_index = 1
	add_to_group("remote_player")   # 聊天气泡靠这个组找到对方位置
	# 设置: "显示玩家名字" 开关控制头顶名字显隐 (切换立刻生效)
	_apply_name_visibility()
	if GameSettings != null and GameSettings.has_signal("settings_changed"):
		GameSettings.settings_changed.connect(_apply_name_visibility)


func _apply_name_visibility() -> void:
	if _name_label != null and GameSettings != null:
		_name_label.visible = GameSettings.mp_show_names


func _process(delta: float) -> void:
	# 位置平滑追 target
	var t: float = clamp(delta * LERP_SPEED, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, t)
	# 动画状态
	if _sprite.animation != _current_anim:
		_sprite.play(_current_anim)
	_sprite.flip_h = not _facing_right


# 由 NetworkManager 调: 更新目标
func apply_pos(x: float, y: float, facing: int, anim: String) -> void:
	_target_pos = Vector2(x, y)
	_facing_right = facing >= 0
	_current_anim = anim
	# 初始: 如果还没设过 (global_position == 0), 直接 snap 到目标
	if global_position == Vector2.ZERO:
		global_position = _target_pos


func set_player_name(n: String) -> void:
	if _name_label != null:
		_name_label.text = n


# PvP: 剑/箭命中判定用的身子半径 (远程玩家是一点, 给个半径才好打中)
func melee_hit_radius() -> float:
	return 8.0


# PvP: 被打中闪红一下 (乐观反馈; 真实扣血在对方那端)
func flash_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


# 对方死亡 → 半透明"幽灵"(只调透明度, 不染色); 复活 → 恢复正常. 由 world 收到 pdead/pres 调.
func set_dead(dead: bool) -> void:
	if _sprite == null:
		return
	if dead:
		_sprite.modulate = Color(1, 1, 1, 0.35)   # 只变淡 (死了), 不偏色
	else:
		_sprite.modulate = Color.WHITE  # 跟 _ready 一致, 正常颜色
