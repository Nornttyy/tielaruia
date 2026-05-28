# 玩家血量节点。挂在 Player 下。
# 信号: health_changed(cur,max), damaged(amount,src), died
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source_pos: Vector2)
signal died

const MAX_HEALTH := 100
const IFRAMES_SEC := 0.6
const TILE_SIZE := 12
const LAVA_TICK_INTERVAL := 0.5     # 每 0.5s 扣一次血
const LAVA_DAMAGE_PER_TICK := 5     # 每次扣 5 → 满血 100 在 10s 内烧死 (用户调: 20 太狠)

var current_health: int = MAX_HEALTH
var _iframe_timer: float = 0.0
var _was_in_iframe: bool = false
var _lava_tick_t: float = 0.0


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
	# 玩家 2 格高: 脚 (global_position.y / TILE_SIZE) - 1 到 0 .
	# global_position 是脚底, 所以脚 tile y = floor(y / TILE_SIZE) - 1; 头 y = floor(y / TILE_SIZE) - 2
	var foot_y: int = int(floor(player.global_position.y / TILE_SIZE)) - 1
	var head_y: int = foot_y - 1
	if cm.get_tile(tile_x, foot_y) == Tiles.LAVA or cm.get_tile(tile_x, head_y) == Tiles.LAVA:
		# 直接扣血不进 iframe (环境伤害每 0.5s 一跳)
		current_health = max(0, current_health - LAVA_DAMAGE_PER_TICK)
		health_changed.emit(current_health, MAX_HEALTH)
		damaged.emit(LAVA_DAMAGE_PER_TICK, player.global_position)
		Effects.spawn_damage_number(player.global_position + Vector2(0, -8),
				LAVA_DAMAGE_PER_TICK, Color(1.0, 0.4, 0.2))
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
	var final_amount: int = max(1, int(round(float(amount) * dm)))
	current_health = max(0, current_health - final_amount)
	_iframe_timer = IFRAMES_SEC
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
	# 玩家受伤飘暗红字 (跟打怪暖黄字区分)
	var player_node: Node = get_parent()
	if player_node is Node2D:
		var pos: Vector2 = (player_node as Node2D).global_position + Vector2(0, -9)
		Effects.spawn_damage_number(pos, final_amount, Color(1, 0.35, 0.35))
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
