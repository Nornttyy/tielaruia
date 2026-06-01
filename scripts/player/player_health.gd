# 玩家血量节点。挂在 Player 下。
# 信号: health_changed(cur,max), damaged(amount,src), died
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source_pos: Vector2)
signal died

const BASE_MAX_HEALTH := 100        # 起始上限 (5 颗心)
const MAX_HEALTH_CAP := 400         # 永久 +HP 上限 (20 颗心, Terraria 风)
const HP_PER_CRYSTAL := 20          # 生命水晶 +20 max HP
const IFRAMES_SEC := 0.6
const TILE_SIZE := 12
const LAVA_TICK_INTERVAL := 0.5     # 每 0.5s 扣一次血
const LAVA_DAMAGE_PER_TICK := 5     # 每次扣 5 → 满血 100 在 10s 内烧死 (用户调: 20 太狠)
const REGEN_INTERVAL := 2.0          # 自然回血: 每 2 秒回一次
const REGEN_AMOUNT := 1             # 每次回 1 点 (~0.5 HP/s, 很慢, 背景回血)
const REGEN_DELAY_AFTER_HIT := 4.0   # 受击后 4 秒内不回 (打架仍有紧张感)

# MAX_HEALTH 现在是 var (不是 const) — 生命水晶能永久加上限.
# 旧代码 hp.MAX_HEALTH 引用照样工作 (var 名同).
var MAX_HEALTH: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _iframe_timer: float = 0.0
var _was_in_iframe: bool = false
var _lava_tick_t: float = 0.0
var _regen_t: float = 0.0
var _since_hit_t: float = 999.0      # 初始视为很久没被打 (一开始未满血就能回)


func _physics_process(delta: float) -> void:
	if _iframe_timer > 0.0:
		_iframe_timer = max(0.0, _iframe_timer - delta)
		_update_iframe_flash()
	elif _was_in_iframe:
		_clear_iframe_flash()
		_was_in_iframe = false
	# 岩浆扣血: 玩家脚下或身上有 LAVA tile → 持续扣 (bypass iframes)
	_lava_tick_t += delta
	if _lava_tick_t >= LAVA_TICK_INTERVAL:
		_lava_tick_t = 0.0
		_check_lava_damage()
	# 自然慢回血: 离上次受击 >= REGEN_DELAY 且未满血 → 每 REGEN_INTERVAL 回 REGEN_AMOUNT.
	# 直接改 current_health + emit (不走 heal(), 不碰 iframe).
	_since_hit_t += delta
	if is_alive() and current_health < MAX_HEALTH and _since_hit_t >= REGEN_DELAY_AFTER_HIT:
		_regen_t += delta
		if _regen_t >= REGEN_INTERVAL:
			_regen_t -= REGEN_INTERVAL
			current_health = min(MAX_HEALTH, current_health + REGEN_AMOUNT)
			health_changed.emit(current_health, MAX_HEALTH)
	else:
		_regen_t = 0.0


# 判断 tile id 是否为岩浆 (含 3 个流动深度 L1/L2/L3 + 满格 LAVA)
func _is_lava(tid: int) -> bool:
	return tid == Tiles.LAVA or tid == Tiles.LAVA_L1 or tid == Tiles.LAVA_L2 or tid == Tiles.LAVA_L3


# 检查玩家脚 + 头 tile 有没有 LAVA, 有就扣血. 用 chunk_manager 查 tile.
func _check_lava_damage() -> void:
	if not is_alive():
		return
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var cm = _get_chunk_manager()
	if cm == null:
		return
	var tile_x: int = int(floor(player.global_position.x / TILE_SIZE))
	# 玩家 collision: pos (0,-13.75) size (12.5, 27.5) (1.25x), 脚底在 global_position.y, 头在 y - 27.5.
	# 脚 tile y = floor((y - 1) / 12), 用 y-1 防贴底时算到下面那格. 头 tile = floor((y-27.5) / 12).
	# 老代码用 floor(y/12) - 1 是 bug — 漏掉脚踩在岩浆顶时的检测 (玩家站岩浆里不扣血).
	var foot_y: int = int(floor((player.global_position.y - 1.0) / TILE_SIZE))
	var head_y: int = int(floor((player.global_position.y - 27.5) / TILE_SIZE))
	if _is_lava(cm.get_tile(tile_x, foot_y)) or _is_lava(cm.get_tile(tile_x, head_y)):
		# 直接扣血不进 iframe (环境伤害每 0.5s 一跳). clamp 飘字真实扣血.
		var lava_loss: int = min(LAVA_DAMAGE_PER_TICK, current_health)
		current_health = max(0, current_health - LAVA_DAMAGE_PER_TICK)
		health_changed.emit(current_health, MAX_HEALTH)
		damaged.emit(LAVA_DAMAGE_PER_TICK, player.global_position)
		Effects.spawn_damage_number(player.global_position + Vector2(0, -8),
				lava_loss, Color(1.0, 0.4, 0.2))
		if current_health == 0:
			died.emit()


func _get_chunk_manager() -> Node:
	var player: Node = get_parent()
	if player == null:
		return null
	if player.has_method("_get_chunk_manager"):
		return player._get_chunk_manager()
	# 兜底: 从 group 拿
	return get_tree().get_first_node_in_group("chunk_manager")


# 取 PlayerInventory (sibling 节点, 用来读盔甲槽和总防御)
func _player_inventory() -> Node:
	var player: Node = get_parent()
	if player == null:
		return null
	return player.get_node_or_null("PlayerInventory")


# i-frame 期间: 10Hz 红/白方波闪 (0.1s 红, 0.1s 正常)
func _update_iframe_flash() -> void:
	_was_in_iframe = true
	var sprite: Node = _player_sprite()
	if sprite == null:
		return
	var t: float = (IFRAMES_SEC - _iframe_timer) * 10.0
	sprite.modulate = Color(1.6, 0.6, 0.6) if int(t) % 2 == 0 else Color.WHITE


func _clear_iframe_flash() -> void:
	var sprite: Node = _player_sprite()
	if sprite != null:
		sprite.modulate = Color.WHITE


func _player_sprite() -> Node:
	var player: Node = get_parent()
	if player == null:
		return null
	return player.get_node_or_null("AnimatedSprite2D")


func is_alive() -> bool:
	return current_health > 0


func is_invulnerable() -> bool:
	return _iframe_timer > 0.0


# 返回 true 表示真的受了伤 (没在 i-frames 中且还活着)
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if amount <= 0 or not is_alive() or is_invulnerable():
		return false
	# 难度乘数: 简单 0.5x, 普通 1.0x, 困难 1.5x
	var dm: float = 1.0
	if GameSettings != null and GameSettings.has_method("damage_multiplier"):
		dm = GameSettings.damage_multiplier()
	var raw_amount: int = int(round(float(amount) * dm))
	# 盔甲减伤: 1 防御 = 0.5 减伤. 减后下限 1 (永远不能完全免疫).
	var inv: Node = _player_inventory()
	if inv != null and inv.has_method("total_defense"):
		var defense: int = inv.total_defense()
		raw_amount -= int(floor(float(defense) * 0.5))
	var final_amount: int = max(1, raw_amount)
	# 飘字显示真实扣血 (clamp 到剩余 HP), 防最后一击显示超额
	var displayed_loss: int = min(final_amount, current_health)
	current_health = max(0, current_health - final_amount)
	_iframe_timer = IFRAMES_SEC
	_since_hit_t = 0.0   # 受击 → 重置回血延迟计时
	# 击退: 沿 (玩家位置 - source) 方向 + 向上 0.4 分量, 设玩家 velocity
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var player_node: Node = get_parent()
		if player_node is CharacterBody2D:
			var target_pos: Vector2 = (player_node as Node2D).global_position
			var to_self: Vector2 = target_pos - source_pos
			var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
			dir.y -= 0.4
			dir = dir.normalized()
			(player_node as CharacterBody2D).velocity = dir * knockback
	damaged.emit(final_amount, source_pos)
	# 玩家受伤飘暗红字 (跟打怪暖黄字区分). 用 displayed_loss 显真实扣血.
	var player_node: Node = get_parent()
	if player_node is Node2D:
		var pos: Vector2 = (player_node as Node2D).global_position + Vector2(0, -9)
		Effects.spawn_damage_number(pos, displayed_loss, Color(1, 0.35, 0.35))
	SfxBank.play("hurt", 0.08)
	health_changed.emit(current_health, MAX_HEALTH)
	if current_health == 0:
		died.emit()
	return true


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	current_health = min(MAX_HEALTH, current_health + amount)
	health_changed.emit(current_health, MAX_HEALTH)


# 复活时调
func revive_full() -> void:
	current_health = MAX_HEALTH
	_iframe_timer = 0.0
	health_changed.emit(current_health, MAX_HEALTH)


# 用生命水晶: 永久 +HP_PER_CRYSTAL max HP + 也加同量当前 HP.
# 已达 cap 返 false (玩家应该不能再吃). 否则返 true.
func try_extend_max(amount: int = HP_PER_CRYSTAL) -> bool:
	if MAX_HEALTH >= MAX_HEALTH_CAP:
		return false
	MAX_HEALTH = min(MAX_HEALTH_CAP, MAX_HEALTH + amount)
	current_health = min(MAX_HEALTH, current_health + amount)
	health_changed.emit(current_health, MAX_HEALTH)
	return true
