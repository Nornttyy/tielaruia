# 放下块时的 scale bounce 动画。给目标 tile 上叠一个 Sprite2D，
# scale 从 (1.2, 1.2) → (1.0, 1.0) 用 Tween 100ms，完成自删。
# texture 取该 tile 的 block_texture (来自 ArtCache.block_textures)。
extends Sprite2D

const TILE_SIZE := 16
const BOUNCE_DURATION := 0.1
const START_SCALE := 1.2
const END_SCALE := 1.0


func setup(tile_coord: Vector2i, tile_id: int) -> void:
	if ArtCache.block_textures.has(tile_id):
		texture = ArtCache.block_textures[tile_id]
	centered = false
	global_position = Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
	var center := global_position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	scale = Vector2(START_SCALE, START_SCALE)
	_align_to_center(center)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_scale_around_center.bind(center),
		START_SCALE, END_SCALE, BOUNCE_DURATION)
	tween.tween_callback(queue_free)


func _set_scale_around_center(s: float, center: Vector2) -> void:
	scale = Vector2(s, s)
	_align_to_center(center)


func _align_to_center(center: Vector2) -> void:
	global_position = center - Vector2(TILE_SIZE / 2.0 * scale.x, TILE_SIZE / 2.0 * scale.y)
