# 放置弹跳: 弹跳块该按世界 tile (12px) 大小, 不是图标 (16px) 大小。
# bug: 直接用 16px 图标 + 写死 12 的缩放 → 弹跳块比放下的格子大一圈 (用户报"放块一瞬间变很大")。
extends GutTest

const PlaceBounceScene = preload("res://scenes/fx/place_bounce.tscn")


func test_bounce_sized_to_tile_not_icon() -> void:
	assert_true(ArtCache.block_icons.has(Tiles.STONE), "石头该有图标 (前置)")
	var pb = PlaceBounceScene.instantiate()
	add_child_autofree(pb)
	pb.setup(Vector2i(0, 0), Tiles.STONE)
	# setup 后 scale = base × START_SCALE; 实际渲染宽 = 贴图宽 × scale。
	# 该 = TILE_SIZE × 1.2 (14.4px) —— 跟图标分辨率无关 (修前是 16×1.2=19.2px = 太大)。
	var rendered_w: float = pb.texture.get_width() * pb.scale.x
	assert_almost_eq(rendered_w, float(pb.TILE_SIZE) * pb.START_SCALE, 0.5,
		"弹跳起手渲染宽该 = TILE_SIZE×1.2 (14.4px), 不是图标 16×1.2 (19.2px)")


func test_bounce_ends_at_tile_size() -> void:
	# 弹跳尾 (END_SCALE=1.0) 渲染该正好 = TILE_SIZE, 跟放下的方块一样大。
	var pb = PlaceBounceScene.instantiate()
	add_child_autofree(pb)
	pb.setup(Vector2i(3, 5), Tiles.STONE)
	pb._set_scale_around_center(pb.END_SCALE, Vector2(42, 66))   # 手动推到结尾态
	var rendered_w: float = pb.texture.get_width() * pb.scale.x
	assert_almost_eq(rendered_w, float(pb.TILE_SIZE), 0.5, "弹跳结尾该 = TILE_SIZE (12px)")
