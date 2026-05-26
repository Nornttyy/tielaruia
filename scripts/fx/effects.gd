# 粒子工厂 (autoload)。spawn_* 方法实例化对应场景到 effects_root 组下的 Node。
# 找不到 effects_root 则丢到当前场景根 (兜底)。
extends Node

const BlockBreakParticleScene = preload("res://scenes/fx/block_break_particle.tscn")
const DustParticleScene = preload("res://scenes/fx/dust_particle.tscn")
const PlaceBounceScene = preload("res://scenes/fx/place_bounce.tscn")
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


func spawn_place_bounce(tile_coord: Vector2i, tile_id: int = -1) -> void:
	if tile_id == -1:
		return
	var pb = PlaceBounceScene.instantiate()
	_root().add_child(pb)
	pb.setup(tile_coord, tile_id)


func spawn_jump_dust(world_pos: Vector2) -> void:
	var parent: Node = _root()
	for i in 4:
		var d = DustParticleScene.instantiate()
		parent.add_child(d)
		d.setup(world_pos + Vector2(randf_range(-5, 5), randf_range(-2, 2)),
			randf_range(0.7, 1.0))


func spawn_land_dust(world_pos: Vector2) -> void:
	var parent: Node = _root()
	for i in 6:
		var d = DustParticleScene.instantiate()
		parent.add_child(d)
		d.setup(world_pos + Vector2(randf_range(-8, 8), randf_range(-1, 1)),
			randf_range(1.0, 1.4))


func spawn_damage_number(world_pos: Vector2, amount: int, color: Color = Color(1, 0.9, 0.5)) -> void:
	# 砍怪 / 玩家受伤时, 头上飘一个 "-N" 数字, 0.7s 上升 + 渐隐.
	# color: 默认暖黄 (打怪); 玩家受伤可传 Color(1, 0.4, 0.4) 暗红.
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 14)
	# 随机水平偏移避免数字叠在一起 (连续多发命中)
	var jitter_x: float = randf_range(-6.0, 6.0)
	lbl.position = world_pos + Vector2(-8.0 + jitter_x, -16.0)
	lbl.z_index = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root().add_child(lbl)
	# Tween: 向上飘 18 px, alpha 1 → 0, 0.7s
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)


func spawn_walk_puff(world_pos: Vector2) -> void:
	var parent: Node = _root()
	var d = DustParticleScene.instantiate()
	parent.add_child(d)
	d.setup(world_pos + Vector2(randf_range(-2, 2), 0), 0.6)
