# 木乃伊 (Mummy): 金字塔守卫. 慢但血厚 + 高伤接触.
# HP 60 / dmg 14 / 速 25 (比骨架战士 80/18/35 弱一档, 平 zombie 30 之上).
# 死了掉 1-3 bone + 30% gold_ingot (古墓陪葬品).
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const GRAVITY := 675.0
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12

const BASE_MAX_HEALTH := 60
const CONTACT_DAMAGE := 14
const WALK_SPEED := 25.0       # 很慢
const AGGRO_RANGE_PX := 200.0
const JUMP_VY := -180.0         # 跳得短 (体重)
const ENEMY_IFRAME_SEC := 0.2

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = ArtCache.mummy_frames
	sprite.play("idle")
	add_to_group("mummies")
	add_to_group("slimes")
	# 难度缩放 (跟其他怪同款)
	if GameSettings != null and GameSettings.has_method("enemy_hp_multiplier"):
		max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		_check_player_contact()  # 远程怪仍能打伤本地(client)玩家; 不跑 AI/移动 (host 权威位置)
		return
	if _is_dying:
		return
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
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * WALK_SPEED
		sprite.flip_h = dir < 0
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 80.0 * delta)
		if abs(velocity.x) < 5.0 and sprite.animation != "idle":
			sprite.play("idle")
	move_and_slide()
	if is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
		velocity.y = JUMP_VY
		_jump_cooldown = 0.8
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
	# AABB 盒重叠 (修踩头躲 bug). 木乃伊体型同僵尸.
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > 10.0 or dy < -10.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 180.0)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0:
		return false
	if _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	# 显示真实扣血量 (clamp 到剩余 HP), 防最后一击显超额数字
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -8), actual_loss)
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
	# 1-3 bone + 30% gold_ingot (古墓陪葬)
	for _i in randi_range(1, 3):
		_spawn_drop("bone")
	if randf() < 0.30:
		_spawn_drop("gold_ingot")
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
