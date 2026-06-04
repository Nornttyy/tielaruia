# 青蛙: 沼泽专属, 中立跳跃动物. 比史莱姆 HP 高 + 跳得更远, 但白天/晚上都不主动攻击玩家.
extends "res://scripts/entities/slime.gd"

# 覆盖: 永远中立 (除非被攻击 → 像 minecraft 中立怪)
func _is_hostile() -> bool:
	return _is_provoked


func _ready() -> void:
	super._ready()
	# 青蛙比同档史莱姆肉 ~30% + 出生满血. (旧代码只设 current_health=18 不动 max_health,
	# slime 有 tier 系统后默认 max=25, 导致青蛙出生 18/25 不满血; max_health 已含难度缩放, 这里按比例提升保留它)
	max_health = int(round(max_health * 1.3))
	current_health = max_health
	add_to_group("animals")
	# 染绿色像青蛙
	if sprite != null:
		sprite.modulate = Color(0.55, 1.4, 0.55)
