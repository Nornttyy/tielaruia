# 死人箱 (Mimic): 矿洞陷阱怪. 玩家右键 / 砍 MIMIC_CHEST → 爆炸 + 这里 spawn.
# Terraria 风血厚怪: HP 90 / 接触 16 dmg. 跳得高 (-340 撞墙跳).
# 死了掉 1-2 个好东西 (gold_ingot / iron_ingot / diamond_ore 随机).
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const GRAVITY := 675.0
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12

# 木剑 30 击, 钻剑 5 击. 接触 16 dmg → 100HP 玩家 6 击死, 鼓励远战.
const BASE_MAX_HEALTH := 90
const CONTACT_DAMAGE := 16
const WALK_SPEED := 40.0      # 慢 (重箱子)
const AGGRO_RANGE_PX := 240.0
const JUMP_VY := -340.0       # 跳得高 (像章鱼)
const ENEMY_IFRAME_SEC := 0.2

# 死人箱可掉的奖励 (打死后随机 1-2 种)
const DROP_POOL := ["gold_ingot", "iron_ingot", "copper_ingot", "diamond_ore", "cooked_meat"]

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# 难度缩放放最前面 (.new() 没 sprite 子节点时仍能正确生效)
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.mimic_frames
	sprite.play("attack")  # 死人箱出生就张嘴扑过来, 没有 idle
	add_to_group("mimics")
	add_to_group("slimes")  # 共享剑挥击范围 + 死亡组清理
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		return
	if _is_dying:
		return
	# 性能: 距玩家 > 50 tile 跳过
	var _p := _find_player()
	if _p != null and is_on_floor():
		var _dx: float = _p.global_position.x - global_position.x
		var _dy: float = _p.global_position.y - global_position.y
		if _dx * _dx + _dy * _dy > 360000.0:
			velocity = Vector2.ZERO
			return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
	# 重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	# 追玩家
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * WALK_SPEED
		sprite.flip_h = dir < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	move_and_slide()
	# 撞墙 + 落地 → 跳 (mimic 跳得高)
	if is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
		velocity.y = JUMP_VY
		_jump_cooldown = 0.6
	_check_player_contact()


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_cached_player = null
		return null
	_cached_player = players[0]
	return _cached_player


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > 18.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 150.0)


# 同 slime/zombie/spider 接口
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0:
		return false
	if _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -8), amount)
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		dir.y -= 0.4
		dir = dir.normalized()
		velocity = dir * knockback
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 随机 1-2 个 DROP_POOL 的物品 (好东西, 弥补玩家挨炸的损失)
	var n: int = randi_range(1, 2)
	for _i in n:
		var item_id: String = DROP_POOL[randi() % DROP_POOL.size()]
		_spawn_drop(item_id)
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
