# 史莱姆: 跳向玩家, 接触造成伤害, HP=10, 死亡掉 slime_jelly。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const PlayersUtil = preload("res://scripts/entities/players_util.gd")

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

const SlimeScene = preload("res://scenes/entities/slime.tscn")  # 分裂用 (自引用 preload, Godot 允许)

# 颜色 tier 0绿/1蓝/2红/3紫: modulate 染色(乘色, 蓝=原色不染) + HP/伤害乘数 + 掉 jelly 数.
const _COLOR_TINT := [Color(0.55, 1.25, 0.55), Color(1, 1, 1), Color(1.5, 0.55, 0.55), Color(1.2, 0.6, 1.5)]
const _COLOR_HP_MULT := [0.6, 1.0, 1.8, 2.8]
const _COLOR_DMG_MULT := [0.7, 1.0, 1.5, 2.2]
const _COLOR_JELLY := [1, 1, 2, 3]
# 大小 0小/1中/2大: sprite scale + HP/伤害乘数.
const _SIZE_SCALE := [0.65, 1.0, 1.5]
const _SIZE_HP_MULT := [0.5, 1.0, 1.5]
const _SIZE_DMG_MULT := [0.8, 1.0, 1.2]


# 按"地表下深度 (tile_y - 地表 surf)" 选颜色. rng 让地表绿/蓝按概率.
# 地表(<8): 70% 绿 / 30% 蓝. 浅(8-80): 蓝. 深(80-150): 红. 极深(>=150): 紫.
static func color_for_depth(depth_below_surf: int, rng: RandomNumberGenerator) -> int:
	if depth_below_surf < 8:
		return 0 if rng.randf() < 0.7 else 1
	elif depth_below_surf < 80:
		return 1
	elif depth_below_surf < 150:
		return 2
	return 3


# 刷怪随机大小: 15% 大 / 40% 中 / 45% 小 (大史莱姆稀有, 偶尔遇到才有惊喜).
static func random_spawn_size(rng: RandomNumberGenerator) -> int:
	var r: float = rng.randf()
	if r < 0.15:
		return 2
	elif r < 0.55:
		return 1
	return 0

var max_health: int = BASE_MAX_HEALTH      # _ready 里按 tier+难度缩放
var current_health: int = BASE_MAX_HEALTH
var color_tier: int = 1   # 0绿/1蓝/2红/3紫, 默认蓝 (不调 setup = 旧行为)
var size: int = 1         # 0小/1中/2大, 默认中
var contact_damage: int = CONTACT_DAMAGE   # _apply_tier 按 tier 缩放; CONTACT_DAMAGE 常量当基准
var _base_tint: Color = Color(1, 1, 1)     # tier 染色; 受击闪光后恢复到它
var _cached_player: Node2D = null  # 缓存 player ref, 每帧避免 get_nodes_in_group
var _target_repick: float = 0.0    # 重选最近玩家的倒计时 (联机追最近的人)
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
# 冰冻减速: 1.0=正常, <1=被冰冻枪打中变慢 (跳得矮/近/少). _slow_t 倒计时, 到 0 恢复.
var _slow_mult: float = 1.0
var _slow_t: float = 0.0
# 中毒 (毒液枪): 每 POISON_TICK 秒掉 _poison_dps×tick 血, 持续 _poison_t 秒.
const POISON_TICK := 0.5
var _poison_dps: int = 0
var _poison_t: float = 0.0
var _poison_tick_t: float = 0.0


func _is_hostile() -> bool:
	return _is_provoked or TimeOfDay.is_night()


# 冰冻枪命中: 把 slime 减速 factor 倍 (0.15~1.0), 持续 dur 秒. 多次命中取更慢/更久.
func apply_slow(factor: float, dur: float) -> void:
	_slow_mult = min(_slow_mult, clampf(factor, 0.15, 1.0))
	_slow_t = max(_slow_t, dur)


# 毒液枪命中: 上毒, 每秒掉 dps 血, 持续 dur 秒. 多次命中取更毒/更久.
func apply_poison(dps: int, dur: float) -> void:
	_poison_dps = max(_poison_dps, dps)
	_poison_t = max(_poison_t, dur)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# spawn / 分裂时设颜色+大小.
# add_child 前调: sprite 还没好, 等 _ready 里 _apply_tier 应用 (分裂 / 测试这么用).
# add_child 后调: 已 _ready 过 (默认蓝中已应用), 立即 _apply_tier 重应用新色/大小 (地表刷怪这么用).
func setup(p_color: int, p_size: int) -> void:
	color_tier = clampi(p_color, 0, 3)
	size = clampi(p_size, 0, 2)
	if is_inside_tree() and sprite != null:
		_apply_tier()


# 按 color_tier + size 算 HP/接触伤 (× 难度) + 染色 + 缩放. _ready 调 (sprite 已就绪).
func _apply_tier() -> void:
	var hp_f: float = float(BASE_MAX_HEALTH) * _COLOR_HP_MULT[color_tier] * _SIZE_HP_MULT[size]
	max_health = max(1, int(round(hp_f * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	contact_damage = max(1, int(round(float(CONTACT_DAMAGE) * _COLOR_DMG_MULT[color_tier] * _SIZE_DMG_MULT[size])))
	_base_tint = _COLOR_TINT[color_tier]
	if sprite != null:  # 裸实例 (测试 Slime.new()) 没 sprite, 只算数值不染色/缩放
		sprite.modulate = _base_tint
		sprite.scale = Vector2(_SIZE_SCALE[size], _SIZE_SCALE[size])


func _ready() -> void:
	# 数值先行: 血量/伤害/染色 (含难度缩放) 不依赖 sprite, 必须先算.
	# 测试里 Slime.new() 是裸实例 (没 AnimatedSprite2D 子节点), sprite 为 null;
	# 之前 sprite.sprite_frames 在 _apply_tier 前崩 → max_health 没算 → 难度缩放失效.
	_apply_tier()
	add_to_group("slimes")
	if sprite != null:
		sprite.sprite_frames = ArtCache.slime_frames
		sprite.play("idle")
		# hop 动画不循环, 播完停在"压扁落地"帧; 接 animation_finished 落地后切回 idle
		sprite.animation_finished.connect(_on_anim_done)
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
		_check_player_contact()  # 远程怪仍能打伤本地(client)玩家; 不跑 AI/移动 (host 权威位置)
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
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else _base_tint
	_iframe_t = max(0.0, _iframe_t - delta)
	# 冰冻减速倒计时 + 冰蓝提示 (受击闪光优先, 不抢闪光帧)
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			_slow_mult = 1.0
			if _hit_flash <= 0.0 and sprite != null:
				sprite.modulate = _base_tint   # 解冻 → 恢复本色
		elif _hit_flash <= 0.0 and sprite != null:
			sprite.modulate = _base_tint * Color(0.55, 0.8, 1.5)  # 冻住时偏冰蓝
	# 中毒: 每 POISON_TICK 秒掉一截血 (毒液枪). take_damage 自带受击闪光当反馈.
	if _poison_t > 0.0:
		_poison_t -= delta
		_poison_tick_t -= delta
		if _poison_tick_t <= 0.0:
			_poison_tick_t = POISON_TICK
			take_damage(max(1, int(round(_poison_dps * POISON_TICK))), global_position)
		if _poison_t <= 0.0:
			_poison_dps = 0

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
	# 被冰冻减速时跳得更不频繁 (_slow_mult 越小, 冷却越长)
	_hop_timer = randf_range(HOP_COOLDOWN_MIN, HOP_COOLDOWN_MAX) / max(0.15, _slow_mult)
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
	# 被冰冻减速时跳得更矮更近 (_slow_mult 缩放横/竖速)
	_current_hop_vx = dir * vx_mag * _slow_mult
	velocity.x = _current_hop_vx
	velocity.y = -vy_mag * _slow_mult
	sprite.play("hop")
	SfxBank.play_at("slime_hop", global_position, 128.0, 0.25)  # 远于 8 tile 静音


func _on_anim_done() -> void:
	if _is_dying:
		return
	if sprite.animation == "hop":
		sprite.play("idle")


func _find_player() -> Node2D:
	# 联机: 追"最近的玩家"(含加入的人), 不只盯房主。单机时只有本地玩家, 行为不变。
	# 每 0.3s 重选一次目标 (省得每帧 get_nodes_in_group)。
	_target_repick -= 0.016
	if _cached_player != null and is_instance_valid(_cached_player) and _target_repick > 0.0:
		return _cached_player
	_target_repick = 0.3
	_cached_player = PlayersUtil.nearest_player(get_tree(), global_position)
	return _cached_player


func _check_player_contact() -> void:
	# 中立 (白天未被打) → 不造成接触伤害
	if not _is_hostile():
		return
	var player := _find_player()
	if player == null:
		return
	# AABB 盒重叠 (修踩头躲 bug). 史莱姆 12×10, 玩家 10×22.
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > 11.0 or dy < -10.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(contact_damage, global_position, 75.0)


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
	# 压缩弹动: sprite scale Y 压扁 (按体型 base scale 缩放, 不然大史莱姆弹完会缩回 1.0)
	var base_s: float = _SIZE_SCALE[size]
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(base_s * 1.25, base_s * 0.75), 0.06)
	tween.tween_property(sprite, "scale", Vector2(base_s, base_s), 0.12)
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	# 联机: host 通知 client 这个实体死了 (client 端那个 slime 也会消失)
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 按颜色 tier 掉 slime_jelly (绿1/蓝1/红2/紫3)
	for i in _COLOR_JELLY[color_tier]:
		_spawn_drop("slime_jelly")
	# 大/中: 裂成 2 只同色小一档 (小不裂)
	if size > 0:
		_split()
	queue_free()


# 在死亡点附近 spawn 2 只同色 size-1 的史莱姆, 给点散开横速 (像泰拉瑞亚炸开).
func _split() -> void:
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	if entities == null:
		return
	for i in 2:
		var child = SlimeScene.instantiate()
		child.setup(color_tier, size - 1)   # 同色, 小一档
		entities.add_child(child)
		child.global_position = global_position + Vector2(randf_range(-6.0, 6.0), -4.0)
		if "velocity" in child:
			child.velocity = Vector2(randf_range(-50.0, 50.0), -130.0)   # 弹开


func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-3.0, 3.0), -4.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)
