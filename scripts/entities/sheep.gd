# 羊: 中速, HP 低, 掉 wool + raw_meat.
extends "res://scripts/entities/animal_base.gd"

func _ready() -> void:
	max_health = 8
	walk_speed = 55.0
	drop_table = [
		["wool", 100, 1, 2],
		["raw_meat", 80, 1, 1],
	]
	sprite_frames = ArtCache.sheep_frames
	super._ready()
	add_to_group("sheep")
