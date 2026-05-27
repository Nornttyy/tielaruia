# 美洲豹: 丛林专属敌对动物. 继承 zombie 的追击逻辑, 改快 + HP 高 + 掉肉/皮.
# 跟僵尸不一样的: 白天活动 (zombie 夜里刷), 视野更远.
extends "res://scripts/entities/zombie.gd"

func _ready() -> void:
	# 覆盖 zombie 默认参数 (必须在 super._ready() 之前 set)
	max_health = 14
	walk_speed = 75.0           # zombie 38, 豹快 2x
	contact_damage = 4          # zombie 3
	aggro_range_px = 320.0      # zombie 240, 豹视野更远
	entity_group = "animals"    # 用 animals 组 (跟牛/羊一样, 按上限刷)
	sprite_frames_override = ArtCache.jaguar_frames
	drop_table = [
		["raw_meat", 1, 2],
		["leather", 1, 2],
	]
	super._ready()
