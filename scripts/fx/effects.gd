# 粒子工厂 (autoload)。spawn_* 方法实例化对应场景到 effects_root 组下的 Node。
# 找不到 effects_root 则丢到当前场景根 (兜底)。
extends Node

const BlockBreakParticleScene = preload("res://scenes/fx/block_break_particle.tscn")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const TILE_SIZE := 16
const CHIPS_PER_BREAK := 6


func _root() -> Node:
	var n: Node = get_tree().get_first_node_in_group("effects_root")
	if n != null:
		return n
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene
	return self


func spawn_block_break(tile_coord: Vector2i, tile_id: int) -> void:
	var center := Vector2(
		tile_coord.x * TILE_SIZE + TILE_SIZE / 2.0,
		tile_coord.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	var palette: Array = BlocksArt.get_palette(tile_id)
	var parent: Node = _root()
	for i in CHIPS_PER_BREAK:
		var chip = BlockBreakParticleScene.instantiate()
		parent.add_child(chip)
		var angle: float = randf_range(-PI, 0.0)  # 向上半圆
		var speed: float = randf_range(60.0, 140.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var color: Color = palette[i % palette.size()]
		chip.setup(center + Vector2(randf_range(-4, 4), randf_range(-4, 4)), color, vel)


func spawn_place_bounce(tile_coord: Vector2i) -> void:
	# 占位：Task 6
	pass


func spawn_jump_dust(world_pos: Vector2) -> void:
	# Task 5 实现
	pass


func spawn_land_dust(world_pos: Vector2) -> void:
	# Task 5 实现
	pass


func spawn_walk_puff(world_pos: Vector2) -> void:
	# Task 5 实现
	pass
