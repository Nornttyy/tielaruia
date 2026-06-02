extends GutTest

# 空岛数量按世界大小: 小 1 / 中 2-3 / 大 3-5 (跟金字塔同款)
func test_skyisland_count_range_per_size():
	var prev: int = GameSettings.current_world_size
	GameSettings.current_world_size = 0
	assert_eq(GameSettings.skyisland_count_range(), [1, 1], "小世界 1 个")
	GameSettings.current_world_size = 1
	assert_eq(GameSettings.skyisland_count_range(), [2, 3], "中世界 2-3 个")
	GameSettings.current_world_size = 2
	assert_eq(GameSettings.skyisland_count_range(), [3, 5], "大世界 3-5 个")
	GameSettings.current_world_size = prev   # 还原, 不影响后续 test
