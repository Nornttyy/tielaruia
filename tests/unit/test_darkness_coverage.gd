# 黑暗/光照层纹理上限必须盖住"拉到最远"(camera_zoom 最小 0.5) 的整屏.
# 否则屏幕边缘那圈没被黑暗层覆盖 = 中间有阴影、边上太亮没阴影 (用户报的"放大没照到").
extends GutTest

const DarknessLayer = preload("res://scripts/world/darkness_layer.gd")

# camera_zoom 下限 (game_settings.gd clampf 到 0.5..2.5) + project.godot 基准视口.
const MIN_ZOOM := 0.5
const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0


func test_max_texture_covers_most_zoomed_out_view() -> void:
	var tile := float(DarknessLayer.TILE_SIZE)
	var buf: int = DarknessLayer.BUFFER_TILES
	# 跟 darkness_layer._update_viewport 里 need_w/need_h 算法一致
	var need_w: int = int(ceil(VIEWPORT_W / (MIN_ZOOM * tile))) + buf * 2
	var need_h: int = int(ceil(VIEWPORT_H / (MIN_ZOOM * tile))) + buf * 2
	gut.p("[darkness] 最远缩放需 %dx%d tile, MAX %dx%d" % [
		need_w, need_h, DarknessLayer.MAX_W, DarknessLayer.MAX_H])
	assert_true(DarknessLayer.MAX_W >= need_w,
		"MAX_W(%d) 必须 >= 最远缩放屏宽 %d (否则边缘没阴影太亮)" % [DarknessLayer.MAX_W, need_w])
	assert_true(DarknessLayer.MAX_H >= need_h,
		"MAX_H(%d) 必须 >= 最远缩放屏高 %d" % [DarknessLayer.MAX_H, need_h])
