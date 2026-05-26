# 僵尸: 夜间地表刷怪. 走路向玩家移动, 接触造成伤害, HP=15, 死亡掉 bone.
# 与 slime 区别: 不跳, 持续走动 (slow walk), 视线半径更大.
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const MAX_HEALTH := 15
const CONTACT_DAMAGE := 3
const GRAVITY := 900.0
const SWIM_GRAVITY := 200.0
const SWIM_MAX_SINK := 70.0
const SWIM_UP_SPEED := -45.0   # 头还在水里时向上漂的最大速度
const WALK_SPEED := 38.0
const AGGRO_RANGE_PX := 240.0   # 15 tiles
const JUMP_VY := -260.0         # 撞墙时小跳避障 (1 格)
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 16

var current_health: int = MAX_HEALTH
var _hit_flash: float = 0.0
var _is_dying: bool = false
var _jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.sprite_frames = ArtCache.zombie_frames
	sprite.play("idle")
	add_to_group("zombies")
	add_to_group("slimes")  # 共享 slime 攻击/查找逻辑 (剑挥范围/出生点死亡清除)


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
		if _dx * _dx + _dy * _dy > 640000.0:
			velocity = Vector2.ZERO
			return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
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
	# 撞墙 + 落地 → 小跳避障
	if is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
		velocity.y = JUMP_VY
		_jump_cooldown = 0.5

	_check_player_contact()


func _get_cm():
	var terrain: Node = get_tree().get_first_node_in_group("terrain_layer")
	if terrain == null:
		return null
	var world: Node = terrain.get_parent()
	if world == null:
		return null
	return world.get("chunk_manager")


static func _is_water_tile(tid: int) -> bool:
	return tid == Tiles.WATER or tid == Tiles.WATER_L1 \
			or tid == Tiles.WATER_L2 or tid == Tiles.WATER_L3


func _is_in_water() -> bool:
	var cm = _get_cm()
	if cm == null:
		return false
	var tx: int = int(floor(global_position.x / 16.0))
	var ty: int = int(floor((global_position.y - 11.0) / 16.0))
	return _is_water_tile(cm.get_tile(tx, ty))


# 头是否露出水面 (上浮上到水面就停, 不要无限往天上飞)
func _is_head_above_water() -> bool:
	var cm = _get_cm()
	if cm == null:
		return true
	var tx: int = int(floor(global_position.x / 16.0))
	var ty: int = int(floor((global_position.y - 22.0) / 16.0))
	return not _is_water_tile(cm.get_tile(tx, ty))


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > 20.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position)


# 跟 slime 同接口 (玩家挥剑统一调 take_damage)
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> bool:
	if _is_dying or amount <= 0:
		return false
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -10), amount)
	if source_pos != Vector2.ZERO:
		var dx: float = global_position.x - source_pos.x
		var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
		velocity.x = kb_dir * 80.0
		velocity.y = -100.0
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 掉 1-3 个 bone
	var n := 1 + (randi() % 3)
	for _i in n:
		_spawn_drop("bone")
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
