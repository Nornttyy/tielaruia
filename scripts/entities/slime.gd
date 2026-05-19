# 史莱姆: 跳向玩家, 接触造成伤害, HP=4, 死亡掉 slime_ball。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const MAX_HEALTH := 6   # 木剑 4 dmg × 2 击, 石剑 7 dmg × 1 击
const CONTACT_DAMAGE := 2
const GRAVITY := 900.0
const HOP_VY := -200.0          # 跳高 ~22 px, 能跨 1 格 (16 px) 但跨不过 2 格
const HOP_VX := 65.0
const HOP_COOLDOWN_MIN := 0.8
const HOP_COOLDOWN_MAX := 1.8
const AGGRO_RANGE_PX := 160.0   # 10 tiles
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 16

var current_health: int = MAX_HEALTH
var _hop_timer: float = 0.5
var _hit_flash: float = 0.0
var _is_dying: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = ArtCache.slime_frames
	sprite.play("idle")
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
	# 撞墙 + 落地 → 下次跳转反方向 (避免卡墙原地)
	if is_on_wall() and is_on_floor():
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
	velocity.x = dir * HOP_VX
	velocity.y = HOP_VY
	sprite.play("hop")


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
func take_damage(amount: int, _source_pos: Vector2 = Vector2.ZERO) -> bool:
	if _is_dying or amount <= 0:
		return false
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	# 掉 1-2 个 slime_ball
	var n := 1 + (randi() % 2)
	for i in n:
		_spawn_drop("slime_ball")
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
