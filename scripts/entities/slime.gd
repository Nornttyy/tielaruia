# 史莱姆: 跳向玩家, 接触造成伤害, HP=10, 死亡掉 slime_jelly。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

# Terraria 风血量基线 (玩家 100 HP, 5 颗心): 普通难度 25 HP / 6 dmg.
# 木剑 3 × 9 击, 钻剑 20 × 2 击. 接触伤 6 → 100HP 玩家被锁住吃 17 下死 (含 i-frame).
# 简单 / 困难: HP × 0.7 / 1.4 (见 _ready); 伤害另外有 GameSettings.damage_multiplier 0.5/1/1.5.
const BASE_MAX_HEALTH := 25
const CONTACT_DAMAGE := 6
const GRAVITY := 675.0
const SWIM_GRAVITY := 150.0   # 水里重力 (慢沉)
const SWIM_MAX_SINK := 52.0   # 最大下沉速度
# 跳高/跳远: 每次跳前随机挑 (tile, 16 px 一格).
# 高度 1-2 格, 距离 0-3 格. 由物理公式反算 vy/vx.
const HOP_HEIGHT_MIN_TILES := 1.0
const HOP_HEIGHT_MAX_TILES := 2.0
const HOP_DIST_MIN_TILES := 0.0
const HOP_DIST_MAX_TILES := 3.0
const HOP_COOLDOWN_MIN := 0.8
const HOP_COOLDOWN_MAX := 1.8
const AGGRO_RANGE_PX := 120.0   # 10 tiles
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12

var max_health: int = BASE_MAX_HEALTH      # _ready 里按难度缩放
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null  # 缓存 player ref, 每帧避免 get_nodes_in_group
var _cached_cm: Node = null  # 缓存 chunk_manager (每帧 _is_in_water 不用查 3 层)
var _hop_timer: float = 0.5
var _hit_flash: float = 0.0
const ENEMY_IFRAME_SEC := 0.2
var _iframe_t: float = 0.0
var _water_dmg_timer: float = 0.0   # 水里持续扣血计时
var _is_dying: bool = false
var _current_hop_vx: float = 0.0  # 本次跳跃的目标横速 (空中维持用, 含方向符号)
# 中立/敌对状态: 白天默认中立 (闲逛, 接触不伤害). 晚上自动敌对.
# 白天被玩家打 → 也变敌对 (撑到死或被遗忘) — 像 Minecraft 中立怪.
var _is_provoked: bool = false


func _is_hostile() -> bool:
	return _is_provoked or TimeOfDay.is_night()

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# 难度缩放: 简单 ×0.7 / 普通 ×1.0 / 困难 ×1.4 (见 GameSettings.enemy_hp_multiplier)
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.slime_frames
	sprite.play("idle")
	# hop 动画不循环, 播完会停在最后那个"压扁落地"帧, 看着像被压扁
	# 接 animation_finished, 落地后切回 idle
	sprite.animation_finished.connect(_on_anim_done)
	add_to_group("slimes")
	# slime 不跟玩家物理碰撞 (玩家能穿过 slime, 像 Terraria/MC).
	# 接触伤害靠 _check_player_contact 距离判断, 不依赖物理碰撞.
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


# slime 身体在水里吗 (识别 4 个水位)
func _is_in_water() -> bool:
	if _cached_cm == null or not is_instance_valid(_cached_cm):
		var terrain: Node = get_tree().get_first_node_in_group("terrain_layer")
		if terrain == null:
			return false
		var world: Node = terrain.get_parent()
		if world == null:
			return false
		_cached_cm = world.get("chunk_manager")
		if _cached_cm == null:
			return false
	var tx: int = int(floor(global_position.x / float(TILE_SIZE)))
	var ty: int = int(floor((global_position.y - 5.0) / float(TILE_SIZE)))
	var t: int = _cached_cm.get_tile(tx, ty)
	return t == Tiles.WATER or t == Tiles.WATER_L1 \
			or t == Tiles.WATER_L2 or t == Tiles.WATER_L3


func _physics_process(delta: float) -> void:
	# 联机远程实体: 不跑 AI / 物理, 位置由 NetworkManager 直接设
	if has_meta("is_remote"):
		return
	if _is_dying:
		return
	# 性能: 距玩家 > 50 tile (800 px) 且站地板 → 整帧 skip. 玩家看不见, 也不会影响 AI 行为.
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

	# 史莱姆怕水: 碰到水继续正常重力下沉 + 每 0.5s 扣 1 HP (玩家可用水陷阱杀)
	var in_water: bool = _is_in_water()
	if in_water:
		_water_dmg_timer -= delta
		if _water_dmg_timer <= 0.0:
			_water_dmg_timer = 0.5
			take_damage(1, global_position)
	else:
		_water_dmg_timer = 0.0
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
	# 自动寻路: hop 高度/距离会根据玩家相对位置调整, 防止砸到玩家头顶.
	var max_h_tiles: float = HOP_HEIGHT_MAX_TILES
	var max_d_tiles: float = HOP_DIST_MAX_TILES
	var min_h_tiles: float = HOP_HEIGHT_MIN_TILES
	# 仅在敌对状态下追玩家. 白天 (未被激怒) 当玩家不存在, 只闲逛.
	if _is_hostile() and player != null \
			and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		var dx: float = player.global_position.x - global_position.x
		var dy: float = player.global_position.y - global_position.y
		# 已经在玩家同列 (≤ 1 tile) 时不跳, 避免直接砸头顶
		if abs(dx) < float(TILE_SIZE):
			return
		dir = signf(dx)
		sprite.flip_h = dir < 0
		# 玩家在下方 ≥ 1 tile → 小跳 (重力会带 slime 自然下落, 不要跃过去)
		if dy > float(TILE_SIZE):
			max_h_tiles = 0.6
			min_h_tiles = 0.3
			max_d_tiles = 1.5
		# 玩家在上方 ≥ 1 tile → 跳高一点跨过障碍 (维持默认上限)
		# 同高 → 维持默认
	else:
		# 闲逛: 50% 几率跳一次, 随机方向 + 小跳 (闲逛不要大跳)
		if randf() < 0.5:
			dir = 1.0 if randf() < 0.5 else -1.0
			sprite.flip_h = dir < 0
			max_h_tiles = 1.0
		else:
			return
	# 本次跳跃: 高度 [min, max] tile, 距离 [0, max_d] tile, 由物理反算 vy/vx
	var h_tiles: float = randf_range(min_h_tiles, max_h_tiles)
	var d_tiles: float = randf_range(HOP_DIST_MIN_TILES, max_d_tiles)
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
	SfxBank.play_at("slime_hop", global_position, 128.0, 0.25)  # 远于 8 tile 静音


func _on_anim_done() -> void:
	if _is_dying:
		return
	if sprite.animation == "hop":
		sprite.play("idle")


func _find_player() -> Node2D:
	# 缓存 player ref, 避免每帧 get_nodes_in_group (25 怪 × 3 调用 = 75 次/帧)
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_cached_player = null
		return null
	_cached_player = players[0]
	return _cached_player


func _check_player_contact() -> void:
	# 中立 (白天未被打) → 不造成接触伤害
	if not _is_hostile():
		return
	var player := _find_player()
	if player == null:
		return
	# 用碰撞框距离判断接触 (玩家半径 ~5px + 史莱姆半径 ~7px, TILE_SIZE 缩后)
	if global_position.distance_to(player.global_position) > 14.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 75.0)


# 返回 true 表示本次造成有效伤害
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0:
		return false
	if _iframe_t > 0.0:
		return false   # i-frame 中, 本次不算
	_iframe_t = ENEMY_IFRAME_SEC
	# 被打了 → 激怒, 白天也变敌对
	_is_provoked = true
	# 实际扣的血 = 最多扣到 0, 别让超额输出显示在飘字上 (用户反馈"数字跟扣血对不上")
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	# 飘字 -N (暖黄, 打怪反馈) — 显示真实扣血量, 不是 raw amount
	Effects.spawn_damage_number(global_position + Vector2(0, -6), actual_loss)
	# 击退: 2D 方向 (target - source) + 向上 0.4 分量; 强度按 knockback 参数 (0 → 不推)
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		dir.y -= 0.4
		dir = dir.normalized()
		velocity = dir * knockback
		_hop_timer = 0.5   # 击退后冷却再跳
	# 压缩弹动: sprite scale Y 压扁
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	# 联机: host 通知 client 这个实体死了 (client 端那个 slime 也会消失)
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
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
