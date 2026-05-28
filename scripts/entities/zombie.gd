# 僵尸: 夜间地表刷怪. 走路向玩家移动, 接触造成伤害, HP=15, 死亡掉 bone.
# 与 slime 区别: 不跳, 持续走动 (slow walk), 视线半径更大.
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const GRAVITY := 675.0
const SWIM_GRAVITY := 150.0
const SWIM_MAX_SINK := 52.0
const SWIM_UP_SPEED := -34.0
const JUMP_VY := -195.0
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12

# 子类可覆盖 (jaguar 等). 用 var 不用 const.
# Terraria 风: 木剑 3 × 20 击 / 钻剑 20 × 3 击. 100HP 玩家被打 12 击死.
var max_health: int = 60
var contact_damage: int = 8
var walk_speed: float = 28.0
var aggro_range_px: float = 180.0
var entity_group: String = "zombies"   # 子类可改成 "animals" 等
var sprite_frames_override: SpriteFrames = null   # _ready 前由子类设
# 死亡掉落: 数组每条 [item_id, count_min, count_max], 各 100% 掉
var drop_table: Array = [["bone", 1, 3]]

var current_health: int = 60
var _cached_player: Node2D = null
var _cached_cm: Node = null  # 缓存 chunk_manager, 每帧避免 group + parent 查 3 次
var _hit_flash: float = 0.0
const ENEMY_IFRAME_SEC := 0.2
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = sprite_frames_override if sprite_frames_override != null else ArtCache.zombie_frames
	sprite.play("idle")
	add_to_group(entity_group)
	add_to_group("slimes")  # 共享 slime 攻击/查找逻辑 (剑挥范围/出生点死亡清除)
	# 难度缩放 (animal 子类的 max_health 也跟着, 但牛羊掉血也少, 影响可接受).
	# 注意: 子类如果在自己 _ready 里又设了 max_health, 会盖掉这里 — 见 animal_base 处理.
	max_health = max(1, int(round(max_health * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	# 不跟玩家物理碰撞 (用户要求生物不可挡路, 接触伤害靠距离检测)
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
	# 性能: 距玩家 > 50 tile 且站地板 → skip 整帧 (zombie aggro 半径 240px, 玩家远了也只能闲晃)
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

	# 僵尸会游泳: 水里弱重力 + 慢慢上浮追玩家
	var in_water: bool = _is_in_water()
	if in_water:
		velocity.y += SWIM_GRAVITY * delta
		if velocity.y > SWIM_MAX_SINK:
			velocity.y = SWIM_MAX_SINK
		# 想往上游 (头出水时停止上浮, 不然飞天)
		if not _is_head_above_water():
			velocity.y = min(velocity.y, SWIM_UP_SPEED)
	elif not is_on_floor():
		velocity.y += GRAVITY * delta

	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= aggro_range_px:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * walk_speed
		sprite.flip_h = dir < 0
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 80.0 * delta)
		if abs(velocity.x) < 5.0 and sprite.animation != "idle":
			sprite.play("idle")

	move_and_slide()
	# 撞墙 + 落地 → 小跳避障
	if is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
		velocity.y = JUMP_VY
		_jump_cooldown = 0.5

	_check_player_contact()


func _get_cm():
	if _cached_cm != null and is_instance_valid(_cached_cm):
		return _cached_cm
	var terrain: Node = get_tree().get_first_node_in_group("terrain_layer")
	if terrain == null:
		return null
	var world: Node = terrain.get_parent()
	if world == null:
		return null
	_cached_cm = world.get("chunk_manager")
	return _cached_cm


static func _is_water_tile(tid: int) -> bool:
	return tid == Tiles.WATER or tid == Tiles.WATER_L1 \
			or tid == Tiles.WATER_L2 or tid == Tiles.WATER_L3


func _is_in_water() -> bool:
	var cm = _get_cm()
	if cm == null:
		return false
	var tx: int = int(floor(global_position.x / float(TILE_SIZE)))
	var ty: int = int(floor((global_position.y - 11.0) / float(TILE_SIZE)))
	return _is_water_tile(cm.get_tile(tx, ty))


# 头是否露出水面 (上浮上到水面就停, 不要无限往天上飞)
func _is_head_above_water() -> bool:
	var cm = _get_cm()
	if cm == null:
		return true
	var tx: int = int(floor(global_position.x / float(TILE_SIZE)))
	var ty: int = int(floor((global_position.y - 22.0) / float(TILE_SIZE)))
	return not _is_water_tile(cm.get_tile(tx, ty))


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
	if global_position.distance_to(player.global_position) > 15.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(contact_damage, global_position, 97.0)


# 跟 slime 同接口 (玩家挥剑统一调 take_damage)
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
	# 掉落: 遍历 drop_table, 每条按 count_min..count_max 随机数量掉
	for entry in drop_table:
		var item_id: String = entry[0]
		var n: int = randi_range(entry[1], entry[2])
		for _i in n:
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
