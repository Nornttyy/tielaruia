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
	# 远程玩家暂用默认外观 (联机外观同步是后续, 见 spec 非目标). 加 modulate 偏色区分.
	_sprite.sprite_frames = ArtCache.player_frames
	_sprite.play("idle")
	_sprite.modulate = Color(0.7, 0.9, 1.0)  # 偏蓝, 跟本地玩家 (白) 区分
	z_index = 1
	add_to_group("remote_player")   # 聊天气泡靠这个组找到对方位置


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
	tw.tween_property(_sprite, "modulate", Color(0.7, 0.9, 1.0), 0.18)


# 对方死亡 → 半透明灰"幽灵"; 复活 → 恢复偏蓝. 由 world 收到 pdead/pres 调.
func set_dead(dead: bool) -> void:
	if _sprite == null:
		return
	if dead:
		_sprite.modulate = Color(0.6, 0.6, 0.7, 0.35)
	else:
		_sprite.modulate = Color(0.7, 0.9, 1.0)  # 跟 _ready 一致的偏蓝
