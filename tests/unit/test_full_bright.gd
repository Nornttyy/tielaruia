# 战斗房全亮 (用户: 战斗时光照遮挡视野). force_full_bright=true → compute_region 整片 MAX_LIGHT。
extends GutTest

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")


func after_each() -> void:
	TileLightGrid.force_full_bright = false   # 别污染别的测试


func test_full_bright_returns_all_max() -> void:
	TileLightGrid.force_full_bright = true
	# 没传 chunk_manager (null) 也该直接返回全亮, 不走 BFS (BFS 会读 cm 崩)
	var grid: PackedByteArray = TileLightGrid.compute_region(null, 0, 0, 8, 6, Vector2i(0, 0), [])
	assert_eq(grid.size(), 48, "8×6 = 48 格")
	var all_max := true
	for v in grid:
		if v != TileLightGrid.MAX_LIGHT:
			all_max = false
	assert_true(all_max, "全亮时每格都该是 MAX_LIGHT(15) → 黑暗层 alpha=0")


func test_flag_defaults_off() -> void:
	# 默认关 (单机/生存房正常光照)
	assert_false(TileLightGrid.force_full_bright, "默认该是关的")
