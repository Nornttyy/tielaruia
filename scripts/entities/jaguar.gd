# 美洲豹: 丛林专属, 敌对快攻动物. HP 高, 跑得快, 掉皮革 + 生肉.
# 简化: 当 animal_base 实现 (有 wander), 但 walk_speed 高 + 攻击玩家.
# (未来可改成专门的 enemy 类 with melee AI)
extends "res://scripts/entities/animal_base.gd"

func _ready() -> void:
	max_health = 14
	walk_speed = 75.0  # 比牛 (40) 快 ~2x
	drop_table = [
		["raw_meat", 100, 1, 2],
		["leather", 90, 1, 2],
	]
	sprite_frames = ArtCache.cow_frames
	super._ready()
	add_to_group("animals")
	# 染橙色像豹皮
	if sprite != null:
		sprite.modulate = Color(1.4, 0.85, 0.4)
