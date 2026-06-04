# 陡崖识别: 给地表高度 (world_x → surf_y, y 越大越低), 判断某列是不是崖唇.
extends GutTest

const WorldGen = preload("res://scripts/world/world_generator.gd")


func test_is_cliff_detects_right_drop():
	# 0..7 高(y=100), 8..10 低(y=110); 崖在 7|8 之间
	var heights := {0:100,1:100,2:100,3:100,4:100,5:100,6:100,7:100,8:110,9:110,10:110}
	assert_eq(WorldGen._is_cliff(heights, 2, 4, 8), 0, "x=2 离崖 >4 列, 平地")
	assert_ne(WorldGen._is_cliff(heights, 4, 4, 8), 0, "x=4 (崖前4列) 该判成崖唇")


func test_is_cliff_left_drop():
	# 低在左: 0..2 低(110), 3..10 高(100); 崖在 2|3, x=6 往左看到崖
	var heights := {0:110,1:110,2:110,3:100,4:100,5:100,6:100,7:100,8:100,9:100,10:100}
	assert_eq(WorldGen._is_cliff(heights, 6, 4, 8), -1, "x=6 左侧4列是崖 → 返回 -1")


func test_is_cliff_small_drop_no():
	# 只掉 3 格 < min_drop 8 → 不算崖
	var heights := {0:100,1:100,2:100,3:100,4:100,5:103,6:103,7:103,8:103,9:103}
	assert_eq(WorldGen._is_cliff(heights, 1, 4, 8), 0, "只掉 3 格 < 8, 不算崖")


func test_is_cliff_missing_neighbor_safe():
	# chunk 边界: 邻列不在 dict 里 → 不报错, 算平地
	var heights := {5:100}
	assert_eq(WorldGen._is_cliff(heights, 5, 4, 8), 0, "邻列缺失 → 安全返回 0")
