extends GutTest

const Autotile = preload("res://scripts/world/autotile.gd")


func test_mask_isolated():
	# query 全返回 false → mask = 0
	var query := func(_x: int, _y: int): return false
	assert_eq(Autotile.compute_mask(0, 0, query), 0)


func test_mask_all_solid():
	var query := func(_x: int, _y: int): return true
	assert_eq(Autotile.compute_mask(0, 0, query), 0xFF)


func test_mask_only_north():
	# 只有 (5, 9) 是闭的 = N 邻居
	var query := func(x: int, y: int): return x == 5 and y == 9
	# bit 0 = N
	assert_eq(Autotile.compute_mask(5, 10, query), 1)


func test_mask_only_east():
	var query := func(x: int, y: int): return x == 6 and y == 10
	# bit 1 = E
	assert_eq(Autotile.compute_mask(5, 10, query), 2)


func test_mask_diagonal_NE():
	var query := func(x: int, y: int): return x == 6 and y == 9
	# bit 4 = NE
	assert_eq(Autotile.compute_mask(5, 10, query), 16)


func test_mask_NE_corner_full():
	# N + E + NE 都闭
	var solid: Dictionary = {Vector2i(5, 9): true, Vector2i(6, 10): true, Vector2i(6, 9): true}
	var query := func(x: int, y: int): return solid.has(Vector2i(x, y))
	# bits 0 (N) | 1 (E) | 4 (NE) = 19
	assert_eq(Autotile.compute_mask(5, 10, query), 19)
