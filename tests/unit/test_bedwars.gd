# 起床战争纯逻辑: 岛归属判定 + 分岛 + 自己床判定。
extends GutTest

const BedwarsArena = preload("res://scripts/world/bedwars_arena.gd")
const BedwarsManager = preload("res://scripts/net/bedwars_manager.gd")


func test_island_of_col() -> void:
	var c0: int = BedwarsArena.island_center_col(0)
	assert_eq(BedwarsArena.island_of_col(c0), 0, "岛中心列属于岛 0")
	var c1: int = BedwarsArena.island_center_col(1)
	assert_eq(BedwarsArena.island_of_col(c1), 1, "下一座岛中心属于岛 1")
	# 岛之间的空隙 → 不属于任何岛
	assert_eq(BedwarsArena.island_of_col(c0 + BedwarsArena.ISLAND_HALF + 5), -1, "空隙不属于任何岛")


func test_next_free_slot() -> void:
	var m = BedwarsManager.new()
	add_child_autofree(m)
	m._assigned = {"a": 0, "b": 1}
	assert_eq(m._next_free_slot(), 2, "0/1 占了 → 下一个 2")
	m._assigned = {"a": 0, "b": 2}
	assert_eq(m._next_free_slot(), 1, "0/2 占了 → 补 1")


func test_owns_own_bed_only() -> void:
	var m = BedwarsManager.new()
	add_child_autofree(m)
	m._my_slot = 1
	assert_true(m.owns_bed_col(BedwarsArena.island_center_col(1)), "自己岛的床 = 自己的")
	assert_false(m.owns_bed_col(BedwarsArena.island_center_col(2)), "别人岛的床 = 不是自己的")
