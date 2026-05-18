# 粒子工厂 (autoload)。spawn_* 方法实例化对应场景到 effects_root 组下的 Node。
# 找不到 effects_root 则丢到当前场景根 (兜底)。
extends Node


func _root() -> Node:
	var n: Node = get_tree().get_first_node_in_group("effects_root")
	if n != null:
		return n
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene
	return self


func spawn_block_break(tile_coord: Vector2i, tile_id: int) -> void:
	# 占位：实际实现在 Task 4
	pass


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
