# 火魔 (Imp): 地狱飞行远程怪. 不重力, 在玩家周围悬停 + 隔几秒丢火球.
# HP 22 / dmg 0 (不近战) / 飞行 + 远距离压制. 死了掉 1-2 hell_stone + 偶发 obsidian.
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const FireballScene = preload("res://scenes/entities/fireball.tscn")

const HIT_FLASH_SEC := 0.1
const TILE_SIZE := ChunkConstants.TILE_SIZE

# Terraria 风: HP 50 (远程怪比近战更脆少点). 火球 14 dmg (见 fireball.gd).
const BASE_MAX_HEALTH := 50
const FLY_SPEED := 35.0
const AGGRO_RANGE_PX := 260.0
const HOVER_DISTANCE_PX := 90.0  # 想保持的距离 (太近就退后)
const ATTACK_COOLDOWN_SEC := 1.6
const ENEMY_IFRAME_SEC := 0.2

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _attack_cooldown: float = 1.0   # 出生 1s 后才开火
var _bob_phase: float = 0.0
var _spawn_y_tile: int = -1  # 出生 y_tile (despawn 用), -1 = 未设

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# 难度缩放放最前面 (.new() 没 sprite 子节点时仍能正确生效)
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.imp_frames
	sprite.play("move")
	add_to_group("imps")
	add_to_group("slimes")
	_bob_phase = randf() * TAU
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		_remote_attack(delta)  # 远程 imp 仍朝本地(client)玩家开火; 位置由 host 同步, 火球本地打本地玩家
		return
	if _is_dying:
		return
	# 首次进入 _physics_process 缓存 spawn_y_tile (那时 global_position 已经被 spawner 设好)
	if _spawn_y_tile < 0:
		_spawn_y_tile = int(floor(global_position.y / TILE_SIZE))
	# 地狱边界: 飞出 spawn_y 以上 32 tile 才 despawn (老阈值 200 太紧, 击退一下就被消失 bug)
	# 同时绝对地狱顶 (y < 180) 保险 despawn — 玩家拉到地表也不带上去
	var y_tile: int = int(floor(global_position.y / TILE_SIZE))
	if y_tile < 180 or y_tile < _spawn_y_tile - 32:
		if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
			NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))   # 越界 despawn 也要告诉 client, 否则残留幽灵
		queue_free()
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_bob_phase += delta * 3.0
	# 性能跳过
	var _p := _find_player()
	if _p != null:
		var _dx: float = _p.global_position.x - global_position.x
		var _dy: float = _p.global_position.y - global_position.y
		if _dx * _dx + _dy * _dy > 360000.0:
			velocity = Vector2.ZERO
			return
	var player := _find_player()
	if player == null or global_position.distance_to(player.global_position) > AGGRO_RANGE_PX:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# 飞行 AI: 维持 HOVER_DISTANCE_PX 距离玩家, 不近不远
	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if dist > 0.01 else Vector2.ZERO
	if dist > HOVER_DISTANCE_PX + 20.0:
		velocity = dir * FLY_SPEED      # 靠近
	elif dist < HOVER_DISTANCE_PX - 20.0:
		velocity = -dir * FLY_SPEED * 0.7  # 退后 (慢些, 别甩出去)
	else:
		velocity = Vector2(-dir.y, dir.x) * 30.0  # 绕圈 (垂直方向漂)
	sprite.flip_h = to_player.x < 0
	# 加点 bobbing 上下漂
	velocity.y += sin(_bob_phase) * 6.0
	move_and_slide()
	# 开火: cooldown 到 + 看得见玩家 → 发火球
	if _attack_cooldown <= 0.0 and dist <= AGGRO_RANGE_PX:
		_attack_cooldown = ATTACK_COOLDOWN_SEC
		_shoot_fireball(player.global_position)


func _shoot_fireball(target_pos: Vector2) -> void:
	var fb = FireballScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(fb)
	fb.setup(global_position, target_pos)


# 联机 client: 远程 imp 不跑 AI/移动 (位置由 host 同步), 但仍朝本地玩家定期开火.
# 火球本地生成本地打本地玩家 (跟接触伤害一样: 每个玩家面对自己这边的怪/火球, 不用同步火球).
func _remote_attack(delta: float) -> void:
	if _is_dying:
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	var player := _find_player()
	if player == null:
		return
	if _attack_cooldown <= 0.0 and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		_attack_cooldown = ATTACK_COOLDOWN_SEC
		_shoot_fireball(player.global_position)


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_cached_player = null
		return null
	_cached_player = players[0]
	return _cached_player


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0:
		return false
	if _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -8), actual_loss)
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity = dir * knockback
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 必掉 1-2 hell_stone + 25% obsidian + 10% diamond
	for _i in randi_range(1, 2):
		_spawn_drop("hell_stone")
	if randf() < 0.25:
		_spawn_drop("obsidian")
	if randf() < 0.10:
		_spawn_drop("diamond")   # 修: 原写 "diamond_ore" item_db 里没有 → 掉了捡不起来
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
