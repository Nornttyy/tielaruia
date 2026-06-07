# 网格辅助: 纯逻辑 (世界坐标→tile 吸附) + 实例化 + 初始状态。
# 网格画面靠用户亲眼验收 (无 GUI), 这里只测能测的。
extends GutTest

const GridOverlay = preload("res://scripts/world/grid_overlay.gd")


func test_snap_to_tile_positive() -> void:
	# TILE_SIZE=12: (0..11)→0, (12..23)→1
	assert_eq(GridOverlay.snap_to_tile(Vector2(0, 0)), Vector2i(0, 0), "(0,0) → 格(0,0)")
	assert_eq(GridOverlay.snap_to_tile(Vector2(11, 11)), Vector2i(0, 0), "(11,11) 还在格(0,0)")
	assert_eq(GridOverlay.snap_to_tile(Vector2(12, 12)), Vector2i(1, 1), "(12,12) → 格(1,1)")
	assert_eq(GridOverlay.snap_to_tile(Vector2(30, 25)), Vector2i(2, 2), "(30,25) → 格(2,2)")


func test_snap_to_tile_negative() -> void:
	# 负坐标也要 floor (不是向 0 取整), 否则左/上边那格会偏
	assert_eq(GridOverlay.snap_to_tile(Vector2(-1, -1)), Vector2i(-1, -1), "(-1,-1) → 格(-1,-1)")
	assert_eq(GridOverlay.snap_to_tile(Vector2(-12, -12)), Vector2i(-1, -1), "(-12,-12) → 格(-1,-1)")
	assert_eq(GridOverlay.snap_to_tile(Vector2(-13, -13)), Vector2i(-2, -2), "(-13,-13) → 格(-2,-2)")


func test_starts_inactive() -> void:
	var g = GridOverlay.new()
	add_child_autofree(g)
	assert_false(g._active, "网格默认关闭 (按 Ctrl 才开)")
	assert_eq(g.z_index, 90, "叠加在地形之上")
