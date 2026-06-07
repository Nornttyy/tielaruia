# 放下块时的 scale bounce 动画。给目标 tile 上叠一个 Sprite2D, 轻轻弹一下。
# texture 取该 tile 的 block_icon (UI 图标, 16×16) —— 但世界 tile 是 12px, 所以要先按图标实际
# 分辨率算"基准缩放"把它缩到 12px, 否则弹跳块会比放下的格子大一圈 (用户报"放块时一瞬间变很大")。
# 最终: 渲染从 TILE_SIZE×1.2 (14.4px) 弹回 TILE_SIZE (12px), 跟放下的方块一样大。
extends Sprite2D

const TILE_SIZE := ChunkConstants.TILE_SIZE
const BOUNCE_DURATION := 0.1
const START_SCALE := 1.2
const END_SCALE := 1.0

var _base_scale: float = 1.0   # 图标分辨率 → TILE_SIZE 的换算 (16px 图标 → 0.75)


func setup(tile_coord: Vector2i, tile_id: int) -> void:
	if ArtCache.block_icons.has(tile_id):
		texture = ArtCache.block_icons[tile_id]
	centered = false
	# 基准缩放: 把图标 (可能 16px) 缩到 TILE_SIZE (12px)。防弹跳块比格子大。
	var tw: float = float(texture.get_width()) if texture != null else float(TILE_SIZE)
	_base_scale = TILE_SIZE / tw if tw > 0.0 else 1.0
	var center: Vector2 = Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE) \
			+ Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	_set_scale_around_center(START_SCALE, center)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_scale_around_center.bind(center),
		START_SCALE, END_SCALE, BOUNCE_DURATION)
	tween.tween_callback(queue_free)


func _set_scale_around_center(s: float, center: Vector2) -> void:
	var eff: float = _base_scale * s   # 基准缩放 × 弹跳系数
	scale = Vector2(eff, eff)
	_align_to_center(center)


func _align_to_center(center: Vector2) -> void:
	# 用贴图实际渲染尺寸 (宽×缩放) 居中, 不再写死 TILE_SIZE (图标比 tile 大会偏)
	var tw: float = float(texture.get_width()) if texture != null else float(TILE_SIZE)
	var th: float = float(texture.get_height()) if texture != null else float(TILE_SIZE)
	global_position = center - Vector2(tw * scale.x / 2.0, th * scale.y / 2.0)
