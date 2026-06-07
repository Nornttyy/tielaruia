# 哈比鸟 (Harpy): 天空浮岛附近飞行怪. 看见玩家 260px 内俯冲撞过来, 撞 8 伤 + 击退.
# HP 24. 死了掉 1-2 feather. 仿 hell_wasp 但调成天空版 (despawn 看离 spawn 远近).
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const HIT_FLASH_SEC := 0.1
const TILE_SIZE := ChunkConstants.TILE_SIZE
const BASE_MAX_HEALTH := 24
const CONTACT_DAMAGE := 8
const PATROL_SPEED := 27.5
const CHARGE_SPEED := 60.0
const AGGRO_RANGE_PX := 130.0
const ENEMY_IFRAME_SEC := 0.15
const DESPAWN_BELOW_TILES := 100   # 掉到 spawn 下方 100 tile (到地面了) → despawn

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _charge_target: Vector2 = Vector2.ZERO
var _charge_t: float = 0.0
var _charge_cooldown: float = 0.0
var _spawn_y_tile: int = -1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.harpy_frames
	sprite.play("move")
	add_to_group("harpies")
	add_to_group("slimes")
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		_check_player_contact()
		return
	if _is_dying:
		return
	if _spawn_y_tile < 0:
		_spawn_y_tile = int(floor(global_position.y / TILE_SIZE))
	# 天空 despawn: 掉到 spawn 下方太远 (到地面了)
	var y_tile: int = int(floor(global_position.y / TILE_SIZE))
	if y_tile > _spawn_y_tile + DESPAWN_BELOW_TILES:
		if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
			NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))   # 越界 despawn 也告诉 client, 防残留幽灵
		queue_free()
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	_charge_t = max(0.0, _charge_t - delta)
	_charge_cooldown = max(0.0, _charge_cooldown - delta)
	var player := _find_player()
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dx0: float = player.global_position.x - global_position.x
	var dy0: float = player.global_position.y - global_position.y
	if dx0 * dx0 + dy0 * dy0 > 360000.0:   # 玩家 >600px → idle
		velocity = Vector2.ZERO
		return
	var dist: float = global_position.distance_to(player.global_position)
	if _charge_t > 0.0:
		var dir: Vector2 = (_charge_target - global_position).normalized()
		velocity = dir * CHARGE_SPEED
	elif dist <= AGGRO_RANGE_PX:
		if _charge_cooldown <= 0.0:
			_charge_target = player.global_position
			_charge_t = 0.6
			_charge_cooldown = 1.4
		else:
			var to_player: Vector2 = player.global_position - global_position
			var dir: Vector2 = to_player.normalized()
			velocity = Vector2(-dir.y, dir.x) * PATROL_SPEED
	else:
		velocity = Vector2.ZERO
	sprite.flip_h = velocity.x < 0
	move_and_slide()
	_check_player_contact()


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > 10.0 or dy < -22.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 200.0)
	_charge_t = 0.0


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
		_charge_t = 0.0
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	for _i in randi_range(1, 2):
		_spawn_drop("feather")
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
