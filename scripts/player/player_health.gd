# 玩家血量节点。挂在 Player 下。
# 信号: health_changed(cur,max), damaged(amount,src), died
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source_pos: Vector2)
signal died

const MAX_HEALTH := 20
const IFRAMES_SEC := 0.5

var current_health: int = MAX_HEALTH
var _iframe_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if _iframe_timer > 0.0:
		_iframe_timer = max(0.0, _iframe_timer - delta)


func is_alive() -> bool:
	return current_health > 0


func is_invulnerable() -> bool:
	return _iframe_timer > 0.0


# 返回 true 表示真的受了伤 (没在 i-frames 中且还活着)
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> bool:
	if amount <= 0 or not is_alive() or is_invulnerable():
		return false
	# 难度乘数: 简单 0.5x, 普通 1.0x, 困难 1.5x
	var dm: float = 1.0
	if GameSettings != null and GameSettings.has_method("damage_multiplier"):
		dm = GameSettings.damage_multiplier()
	var final_amount: int = max(1, int(round(float(amount) * dm)))
	current_health = max(0, current_health - final_amount)
	_iframe_timer = IFRAMES_SEC
	damaged.emit(final_amount, source_pos)
	# 玩家受伤飘暗红字 (跟打怪暖黄字区分)
	var player_node: Node = get_parent()
	if player_node is Node2D:
		var pos: Vector2 = (player_node as Node2D).global_position + Vector2(0, -12)
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
