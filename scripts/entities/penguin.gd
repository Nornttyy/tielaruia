# 企鹅: 雪原专属, 中立慢动物. 走得慢, HP 中等, 掉羽毛 + 生肉.
extends "res://scripts/entities/animal_base.gd"

func _ready() -> void:
	max_health = 8
	walk_speed = 28.0  # 比牛慢, 摇摇晃晃
	drop_table = [
		["raw_meat", 100, 1, 1],
		["leather", 50, 1, 1],  # 羽毛暂用 leather 代替
	]
	sprite_frames = ArtCache.cow_frames
	super._ready()
	add_to_group("animals")
	# 染白带黑头: 模拟企鹅. 后续可换专属 sprite
	if sprite != null:
		sprite.modulate = Color(1.0, 1.0, 1.15)
