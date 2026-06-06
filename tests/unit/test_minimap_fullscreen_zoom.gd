# 全屏大地图该比角落小地图显示更多 tile (扩张=看更广), 不是更少.
# bug: FULLSCREEN_ZOOM 太大(24) → 大地图反而比小地图更放大 = 只看到玩家旁边一小片.
extends GutTest

const Minimap = preload("res://scripts/ui/minimap_view.gd")


func test_fullscreen_shows_more_tiles_than_small_minimap():
	# 小地图横向能看多少 tile
	var small_tiles_x: int = Minimap.MAP_PIXEL_WIDTH / Minimap.ZOOM_DEFAULT
	# 全屏大地图横向能看多少 tile (按 1280 宽屏算; FULLSCREEN_SCALE=1.0 占满)
	var full_tiles_x: int = int(1280 * Minimap.FULLSCREEN_SCALE) / Minimap.FULLSCREEN_ZOOM
	assert_gt(full_tiles_x, small_tiles_x,
		"全屏大地图该比小地图看到更多 tile (实测 全屏 %d vs 小图 %d). FULLSCREEN_ZOOM=%d 太大了" % [
			full_tiles_x, small_tiles_x, Minimap.FULLSCREEN_ZOOM])
