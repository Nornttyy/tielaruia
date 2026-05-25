# 牛: 慢, HP 高, 掉 raw_meat + leather.
extends "res://scripts/entities/animal_base.gd"

func _ready() -> void:
	max_health = 12
	walk_speed = 40.0
	drop_table = [
		["raw_meat", 100, 1, 2],
		["leather", 70, 1, 1],
	]
	sprite_frames = ArtCache.cow_frames
	super._ready()
	add_to_group("cows")
