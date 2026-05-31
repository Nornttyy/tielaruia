# 粒子工厂 (autoload)。spawn_* 方法实例化对应场景到 effects_root 组下的 Node。
# 找不到 effects_root 则丢到当前场景根 (兜底)。
extends Node

const BlockBreakParticleScene = preload("res://scenes/fx/block_break_particle.tscn")
const DustParticleScene = preload("res://scenes/fx/dust_particle.tscn")
const PlaceBounceScene = preload("res://scenes/fx/place_bounce.tscn")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const TILE_SIZE := 12
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
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 4:
		var pos: Vector2 = world_pos + Vector2(randf_range(-5, 5), randf_range(-2, 2))
		var scl: float = randf_range(0.7, 1.0)
		# 池: 几乎零开销复用. 兜底 instantiate (池满 / 池没建)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)


func spawn_land_dust(world_pos: Vector2) -> void:
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 6:
		var pos: Vector2 = world_pos + Vector2(randf_range(-8, 8), randf_range(-1, 1))
		var scl: float = randf_range(1.0, 1.4)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)


func spawn_steam_puff(world_pos: Vector2) -> void:
	# 水碰岩浆冒一小撮蒸汽 (复用尘埃粒子, 向上飘散)
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 5:
		var pos: Vector2 = world_pos + Vector2(randf_range(-4, 4), randf_range(-3, 1))
		var scl: float = randf_range(0.8, 1.2)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)


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
	var pos: Vector2 = world_pos + Vector2(randf_range(-2, 2), 0)
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	if pool != null and pool.request_dust(pos, 0.6):
		return
	var d = DustParticleScene.instantiate()
	_root().add_child(d)
	d.setup(pos, 0.6)


# 爆炸 (死人箱触发): 红黄火光粒子 30 颗向四面散开 + 黑烟 + 飞溅木屑碎片.
# 用 BlockBreakParticle 当弹片 (颜色覆盖成爆炸色).
func spawn_explosion(world_pos: Vector2) -> void:
	var parent: Node = _root()
	# 爆炸色板: 红 → 橙 → 黄 → 黑烟
	var explosion_palette: Array = [
		Color8(255, 230, 90),   # 黄亮
		Color8(255, 150, 40),   # 橙
		Color8(220, 60, 30),    # 红
		Color8(40, 30, 25),     # 黑烟
		Color8(255, 200, 80),   # 黄
		Color8(200, 50, 40),    # 暗红
	]
	for i in 30:  # 比普通破方块 6 颗多很多 → "爆炸感"
		var chip = BlockBreakParticleScene.instantiate()
		parent.add_child(chip)
		var angle: float = randf_range(-PI, PI)   # 全方向 (不只是向上)
		var speed: float = randf_range(120.0, 280.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var color: Color = explosion_palette[i % explosion_palette.size()]
		chip.setup(world_pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), color, vel)
