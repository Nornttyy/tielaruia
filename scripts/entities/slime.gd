# 史莱姆: 跳向玩家, 接触造成伤害, HP=10, 死亡掉 slime_jelly。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const MAX_HEALTH := 10   # 木剑 3 dmg × 4 击, 石剑 5 dmg × 2 击
const CONTACT_DAMAGE := 2
const GRAVITY := 900.0
# 跳高/跳远: 每次跳前随机挑 (tile, 16 px 一格).
# 高度 1-2 格, 距离 0-3 格. 由物理公式反算 vy/vx.
const HOP_HEIGHT_MIN_TILES := 1.0
const HOP_HEIGHT_MAX_TILES := 2.0
const HOP_DIST_MIN_TILES := 0.0
const HOP_DIST_MAX_TILES := 3.0
const HOP_COOLDOWN_MIN := 0.8
const HOP_COOLDOWN_MAX := 1.8
const AGGRO_RANGE_PX := 160.0   # 10 tiles
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 16

var current_health: int = MAX_HEALTH
var _hop_timer: float = 0.5
var _hit_flash: float = 0.0
var _is_dying: bool = false
var _current_hop_vx: float = 0.0  # 本次跳跃的目标横速 (空中维持用, 含方向符号)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = ArtCache.slime_frames
	sprite.play("idle")
	# hop 动画不循环, 播完会停在最后那个"压扁落地"帧, 看着像被压扁
	# 接 animation_finished, 落地后切回 idle
	sprite.animation_finished.connect(_on_anim_done)
	add_to_group("slimes")


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		# 落地 → 摩擦 + 准备下次跳
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			_attempt_hop()

	move_and_slide()
	# 空中贴墙时 move_and_slide.slide() 会把横速归零导致跳成垂直, 过不去方块.
	# 维持空中横速 = 本次跳跃设定的 _current_hop_vx (含方向符号).
	if not is_on_floor() and _current_hop_vx != 0.0:
		velocity.x = _current_hop_vx
	# 撞墙 + 落地 → 下次跳转反方向 (避免卡墙原地). 只有 _hop_timer 接近触发时才反向,
	# 给 slime 多次跳跃机会越过方块.
	if is_on_wall() and is_on_floor() and _hop_timer < 0.05:
		velocity.x = 0
		sprite.flip_h = not sprite.flip_h
		_hop_timer = min(_hop_timer, 0.2)
	_check_player_contact()


func _attempt_hop() -> void:
	_hop_timer = randf_range(HOP_COOLDOWN_MIN, HOP_COOLDOWN_MAX)
	var player := _find_player()
	var dir: float = 0.0
	if player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		# 朝玩家跳
		dir = signf(player.global_position.x - global_position.x)
		sprite.flip_h = dir < 0
	else:
		# 闲逛: 50% 几率跳一次, 随机方向
		if randf() < 0.5:
			dir = 1.0 if randf() < 0.5 else -1.0
			sprite.flip_h = dir < 0
		else:
			return
	# 本次跳跃: 高度 1-2 tile, 距离 0-3 tile, 由物理反算 vy/vx
	var h_tiles: float = randf_range(HOP_HEIGHT_MIN_TILES, HOP_HEIGHT_MAX_TILES)
	var d_tiles: float = randf_range(HOP_DIST_MIN_TILES, HOP_DIST_MAX_TILES)
	var h_px: float = h_tiles * TILE_SIZE
	var d_px: float = d_tiles * TILE_SIZE
	# h = vy² / (2g) → vy = sqrt(2*g*h)
	var vy_mag: float = sqrt(2.0 * GRAVITY * h_px)
	# 滞空 = 2*vy/g, 距离 = vx * 滞空 → vx = d*g / (2*vy)
	var vx_mag: float = 0.0 if vy_mag == 0.0 else (d_px * GRAVITY) / (2.0 * vy_mag)
	_current_hop_vx = dir * vx_mag
	velocity.x = _current_hop_vx
	velocity.y = -vy_mag
	sprite.play("hop")


func _on_anim_done() -> void:
	if _is_dying:
		return
	if sprite.animation == "hop":
		sprite.play("idle")


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	# 用碰撞框距离判断接触 (玩家半径 ~6px + 史莱姆半径 ~8px)
	if global_position.distance_to(player.global_position) > 18.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position)


# 返回 true 表示本次造成有效伤害
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> bool:
	if _is_dying or amount <= 0:
		return false
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	# 击退: 远离 source (轻度, 不要弹太远)
	if source_pos != Vector2.ZERO:
		var dx: float = global_position.x - source_pos.x
		var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
		velocity.x = kb_dir * 90.0
		velocity.y = -80.0
		_hop_timer = 0.5  # 击退后冷却再跳
	# 压缩弹动: sprite scale Y 压扁
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	# 掉 1-2 个 slime_jelly
	var n := 1 + (randi() % 2)
	for i in n:
		_spawn_drop("slime_jelly")
	queue_free()


func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-3.0, 3.0), -4.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)
