# 猪: 快, HP 中, 掉 raw_meat 多 + leather 少.
extends "res://scripts/entities/animal_base.gd"

func _ready() -> void:
	max_health = 10
	walk_speed = 70.0
	drop_table = [
		["raw_meat", 100, 2, 3],
		["leather", 35, 1, 1],
	]
	sprite_frames = ArtCache.pig_frames
	super._ready()
	add_to_group("pigs")
