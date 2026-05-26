# 青蛙: 沼泽专属, 中立跳跃动物. 比史莱姆 HP 高 + 跳得更远, 但白天/晚上都不主动攻击玩家.
extends "res://scripts/entities/slime.gd"

# 覆盖: 永远中立 (除非被攻击 → 像 minecraft 中立怪)
func _is_hostile() -> bool:
	return _is_provoked


func _ready() -> void:
	super._ready()
	current_health = 18   # 比史莱姆 10 多
	add_to_group("animals")
	# 染绿色像青蛙
	if sprite != null:
		sprite.modulate = Color(0.55, 1.4, 0.55)
