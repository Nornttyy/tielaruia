# 挖进度裂纹覆盖层。每个 tile 最多一个 Sprite2D 子节点显示裂纹。
# 用 dict 索引避免重复 instantiate。
extends Node2D

const TILE_SIZE := 16

var _active: Dictionary = {}  # Vector2i → Sprite2D


# ratio 0..1。0 或 >=1 视作清除。
# <= 0.25 stage 0；<= 0.5 stage 1；<= 0.75 stage 2；< 1.0 stage 3
func set_progress(tile_coord: Vector2i, ratio: float) -> void:
	if ratio <= 0.0 or ratio >= 1.0:
		clear(tile_coord)
		return
	var stage: int = 3
	if ratio <= 0.25:
		stage = 0
	elif ratio <= 0.5:
		stage = 1
	elif ratio <= 0.75:
		stage = 2
	var sprite: Sprite2D = _active.get(tile_coord, null)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.global_position = Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
		add_child(sprite)
		_active[tile_coord] = sprite
	sprite.texture = ArtCache.crack_textures[stage]


func clear(tile_coord: Vector2i) -> void:
	if _active.has(tile_coord):
		_active[tile_coord].queue_free()
		_active.erase(tile_coord)


func active_count() -> int:
	return _active.size()
