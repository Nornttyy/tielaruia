extends GutTest

# 主菜单背景树覆盖填充: stretch=expand 后窗口变形, 树不该"挤到中间"留空, 要铺满整屏。
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const BASE := Vector2(1280, 720)


func _covers(view: Vector2) -> bool:
	var t: Dictionary = MainMenu._cover_transform(view, BASE)
	var covered := Vector2(BASE.x * t.scale, BASE.y * t.scale)
	return covered.x >= view.x - 0.01 and covered.y >= view.y - 0.01


func test_cover_fills_all_aspects():
	# 宽屏 / 缩窄 / 竖屏(手机) / 超宽 都该被树盖满, 不留空白
	for view in [Vector2(1280, 720), Vector2(1920, 720), Vector2(640, 720), Vector2(800, 1200), Vector2(2400, 1080)]:
		assert_true(_covers(view), "%s 该被背景树铺满 (cover, 不挤中间留空)" % str(view))


func test_cover_default_is_identity():
	var t: Dictionary = MainMenu._cover_transform(BASE, BASE)
	assert_almost_eq(float(t.scale), 1.0, 0.001, "默认 16:9 不缩放 (跟原来一样)")
	assert_almost_eq(Vector2(t.offset).x, 0.0, 0.001, "默认无偏移")
	assert_almost_eq(Vector2(t.offset).y, 0.0, 0.001)


func test_cover_centers_overflow():
	# 更宽视口 → 水平刚好盖满, 垂直多出 → 上下各裁一半 (offset.y 负)
	var t: Dictionary = MainMenu._cover_transform(Vector2(1920, 720), BASE)
	assert_almost_eq(float(t.scale), 1.5, 0.001, "按更大的轴缩放 (1920/1280)")
	assert_lt(Vector2(t.offset).y, 0.0, "垂直溢出居中裁掉 (上移)")
