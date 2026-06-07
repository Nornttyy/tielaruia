# 恶魔眼: 飞行怪. 不受重力, 漂浮追玩家.
# 夜晚地表 + 地穴深处出没. HP 20 / 接触 8 伤 (Terraria 风, 玩家 100HP 12 击死).
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12

const BASE_MAX_HEALTH := 20    # 钻剑 20 一击, 木剑 3 × 7 击. 难度缩放见 _ready.
const CONTACT_DAMAGE := 8
const FLY_SPEED := 60.0       # 飞行速度 (慢但稳)
const AGGRO_RANGE_PX := 240.0  # 看见 20 tile 内追
const ENEMY_IFRAME_SEC := 0.2
# 飞行不受重力, 但漂动给一点缓动让它"活的"感觉
const BOB_AMPLITUDE := 4.0      # 上下漂动幅度 (px)
const BOB_PERIOD := 1.5         # 周期 (秒)

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _bob_t: float = 0.0
var _base_y: float = 0.0  # spawn 时 y 位置, 漂动以此为基
var _force_aggro_t: float = 0.0  # 被打了强制进入 aggro 一会, 让 _base_y 跟着同步避免漂移

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# 难度缩放放在最前面: 测试用 .new() 直造时没 sprite 子节点, 但 max_health 仍要正确.
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.demon_eye_frames
	sprite.play("idle")
	add_to_group("demon_eyes")
	add_to_group("slimes")  # 共享剑挥范围 + 出生点死亡清除
	_base_y = global_position.y
	_bob_t = randf() * BOB_PERIOD   # 随机起始相位, 多只眼睛不同步
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
	# 性能: 距玩家 > 50 tile 直接 skip
	var _p := _find_player()
	if _p != null:
		var _dx: float = _p.global_position.x - global_position.x
		var _dy: float = _p.global_position.y - global_position.y
		if _dx * _dx + _dy * _dy > 360000.0:
			velocity = Vector2.ZERO
			return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	_force_aggro_t = max(0.0, _force_aggro_t - delta)
	_bob_t += delta
	# 飞行 AI: 朝玩家方向漂, 速度恒定 (不受重力)
	var player := _find_player()
	var in_aggro: bool = player != null and (global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX or _force_aggro_t > 0.0)
	if in_aggro:
		var to_player: Vector2 = player.global_position - global_position
		var dir: Vector2 = to_player.normalized() if to_player.length() > 1.0 else Vector2.ZERO
		velocity = dir * FLY_SPEED
		sprite.flip_h = dir.x < 0
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if in_aggro:
		# 追玩家时 Y 也跟着动 (velocity.y 已经被 move_and_slide 应用)
		# 同步 base_y 让退出 aggro 后 bob 从当前位置开始
		_base_y = global_position.y
	else:
		# 闲逛: bob 上下漂浮在 _base_y 周围
		var bob: float = sin(_bob_t / BOB_PERIOD * TAU) * BOB_AMPLITUDE
		global_position.y = _base_y + bob
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
	# AABB (飞行怪, dy 范围更宽因为它悬空, 玩家中部 ~ dy=-11).
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > 10.0 or dy < -22.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 100.0)


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
	# 击退: 给它一点漂移. 老 bug: 直接 _base_y += dir.y * 5 → 远距离用弓多打几下
	# _base_y 单向漂移, 眼睛飞到天上 / 钻地. 改成强制进入 aggro 2s, aggro 模式
	# 每帧 _base_y = global_position.y 自动同步, 击退就回正常 bob 轨道.
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity = dir * knockback
		_force_aggro_t = 2.0
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 掉 1 个 lens (新材料占位, M3 用)
	_spawn_drop("lens")
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
