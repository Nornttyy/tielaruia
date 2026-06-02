# 史莱姆王 Boss: 巨大史莱姆, 大跳砸玩家. HP 1000.
# 阶段 (后续 task): 血<50% 召唤小史莱姆; 血越少体型越小、跳越快.
# 收尾 (后续 task): 玩家死/远离 → 消失; 掉 slime_ball + 大量 slime_jelly.
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")

const BASE_MAX_HEALTH := 1000
const CONTACT_DAMAGE := 20
const GRAVITY := 675.0
const TILE_SIZE := 12
const HIT_FLASH_SEC := 0.1
const ENEMY_IFRAME_SEC := 0.15
const AGGRO_RANGE_PX := 600.0
const HOP_HEIGHT_TILES := 4.0
const HOP_DIST_TILES := 5.0
const HOP_COOLDOWN_FULL := 1.6
const HOP_COOLDOWN_LOW := 0.5
const SCALE_FULL := 4.0
const SCALE_LOW := 2.0
const MINION_INTERVAL := 4.0
const MINION_PER_WAVE := 3
const MINION_CAP := 8
const DESPAWN_DISTANCE_PX := 960.0
const DESPAWN_AFTER_SEC := 5.0
const JELLY_DROP_MIN := 20
const JELLY_DROP_MAX := 40

var _far_timer: float = 0.0
var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hop_timer: float = 1.0
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _current_hop_vx: float = 0.0
var _minion_timer: float = MINION_INTERVAL

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _crown: Sprite2D = $Crown


func _ready() -> void:
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.slime_frames
	sprite.play("idle")
	sprite.modulate = Color(0.7, 0.8, 1.1)  # 偏亮蓝 (boss 比普通蓝史莱姆更亮一档, 一眼区分)
	_crown.texture = ArtCache.slime_crown_tex   # 头顶金王冠 (独立贴图, 不被身体染蓝/受击闪红)
	add_to_group("king_slime")
	add_to_group("slimes")
	add_to_group("boss")
	_apply_scale()
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _hp_ratio() -> float:
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)


func _apply_scale() -> void:
	var s: float = lerp(SCALE_LOW, SCALE_FULL, _hp_ratio())
	sprite.scale = Vector2(s, s)
	# 碰撞框跟着身体一起缩放. 之前固定 40×32 不跟着大, 满血大王身子大碰撞小 → 难打中.
	if _collision != null:
		_collision.scale = Vector2(s, s)
	# 王冠跟着体型缩放, 坐在头顶: band 底边贴头顶 (-16-8s), 留 1px 嵌入防缝隙.
	if _crown != null:
		_crown.scale = Vector2(s, s)
		_crown.position = Vector2(0.0, -16.0 - 8.0 * s)


# 近战命中半径: 王身子巨大, 让剑/镐碰到大身子就算命中 (不只认中心一点).
# = 碰撞框半宽 (6.5) × 当前体型 scale. 满血 scale 4 → 26px; 血少体型小 → 半径也小.
# player_action 近战命中检测把这半径加到判定距离上 (普通小怪没此方法 = 半径 0, 行为不变).
func melee_hit_radius() -> float:
	return 6.5 * sprite.scale.x


# 当前跳跃间隔: 血越少越短 (HOP_COOLDOWN_FULL → HOP_COOLDOWN_LOW)
func _hop_cooldown_now() -> float:
	return lerp(HOP_COOLDOWN_LOW, HOP_COOLDOWN_FULL, _hp_ratio())


func _spawn_minions() -> void:
	var existing := get_tree().get_nodes_in_group("slimes").size()
	for i in MINION_PER_WAVE:
		if existing >= MINION_CAP:
			break
		var m = SlimeScene.instantiate()
		var entities: Node = get_tree().get_first_node_in_group("entities_root")
		if entities == null:
			entities = get_parent()
		entities.add_child(m)
		m.global_position = global_position + Vector2(randf_range(-20, 20), -10)
		existing += 1


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	_cached_player = players[0]
	return _cached_player


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		if not _is_dying:
			_check_player_contact()  # 远程王仍能打伤本地(client)玩家
		return
	if _is_dying:
		return
	# 收尾: 玩家死/远离超时 → 直接消失 (不掉东西)
	_check_despawn(delta)
	if _is_dying:
		return
	# 阶段 2: 血 < 50% 周期召唤小兵
	if current_health < max_health / 2:
		_minion_timer -= delta
		if _minion_timer <= 0.0:
			_minion_timer = MINION_INTERVAL
			_spawn_minions()
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color(0.6, 0.5, 1.0)
	_iframe_t = max(0.0, _iframe_t - delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			_attempt_hop()

	move_and_slide()
	if not is_on_floor() and _current_hop_vx != 0.0:
		velocity.x = _current_hop_vx
	_check_player_contact()


func _attempt_hop() -> void:
	_hop_timer = _hop_cooldown_now()
	var player := _find_player()
	var dir: float = 0.0
	if player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		var dx: float = player.global_position.x - global_position.x
		dir = signf(dx) if abs(dx) > float(TILE_SIZE) else (1.0 if randf() < 0.5 else -1.0)
		sprite.flip_h = dir < 0
	else:
		dir = 1.0 if randf() < 0.5 else -1.0
	var h_px: float = HOP_HEIGHT_TILES * TILE_SIZE
	var d_px: float = HOP_DIST_TILES * TILE_SIZE
	var vy_mag: float = sqrt(2.0 * GRAVITY * h_px)
	var vx_mag: float = 0.0 if vy_mag == 0.0 else (d_px * GRAVITY) / (2.0 * vy_mag)
	_current_hop_vx = dir * vx_mag
	velocity.x = _current_hop_vx
	velocity.y = -vy_mag


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	var half: float = 6.0 * sprite.scale.x
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > half or dy < -2.0 * half or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 100.0)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0 or _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -6), actual_loss)
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var d: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity += d * knockback * 0.1
	_apply_scale()
	if current_health == 0:
		_die()
	return true


# 远离消失: 玩家不存在 (死了/离场) 或太远 → 累计计时, 超时直接消失 (不掉落).
func _check_despawn(delta: float) -> void:
	var player := _find_player()
	var far: bool = player == null or global_position.distance_to(player.global_position) > DESPAWN_DISTANCE_PX
	if far:
		_far_timer += delta
		if _far_timer >= DESPAWN_AFTER_SEC:
			_is_dying = true
			queue_free()
	else:
		_far_timer = 0.0


# 在 boss 身上 spawn 一个掉落物 (沿用 slime.gd 的 item_id/count API)
func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -6.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)


func _die() -> void:
	_is_dying = true
	# 掉 1 个 slime_ball + 一大堆 slime_jelly
	_spawn_drop("slime_ball")
	var n := JELLY_DROP_MIN + (randi() % (JELLY_DROP_MAX - JELLY_DROP_MIN + 1))
	for i in n:
		_spawn_drop("slime_jelly")
	queue_free()
