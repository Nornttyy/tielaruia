# 生成器后处理: 1 格台阶地表 → 拐角铺对应朝向草斜砖.
extends GutTest
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

class FakeChunk:
	var tiles: Array
	func _init(width: int, height: int):
		tiles = []
		for _x in width:
			var col := []
			for _y in height:
				col.append(Tiles.AIR)
			tiles.append(col)

# 造一列: 顶 (surf) GRASS, 下面 DIRT 填到底
func _fill_col(c, lx: int, surf: int, height: int) -> void:
	c.tiles[lx][surf] = Tiles.GRASS
	for y in range(surf + 1, height):
		c.tiles[lx][y] = Tiles.DIRT

func test_step_up_right_places_slope_r() -> void:
	var H := 40
	var c = FakeChunk.new(4, H)
	var heights := {}
	# 列 0 地表 y=20, 列 1 地表 y=19 (高 1 格 → 向右升) , 列 2/3 同 19
	_fill_col(c, 0, 20, H); heights[0] = 20
	_fill_col(c, 1, 19, H); heights[1] = 19
	_fill_col(c, 2, 19, H); heights[2] = 19
	_fill_col(c, 3, 19, H); heights[3] = 19
	WorldGenerator._place_slopes_chunk(c, heights, 0, 4, H)
	# ◢ 应放在低列(0)地表上方那格 (0, 19)
	assert_eq(c.tiles[0][19], Tiles.GRASS_SLOPE_R, "向右升 → ◢ 放 (0,19)")

func test_step_up_left_places_slope_l() -> void:
	var H := 40
	var c = FakeChunk.new(4, H)
	var heights := {}
	# 列 0/1 地表 y=19, 列 2 地表 y=20 (低 1 格 → 向左升回 19)
	_fill_col(c, 0, 19, H); heights[0] = 19
	_fill_col(c, 1, 19, H); heights[1] = 19
	_fill_col(c, 2, 20, H); heights[2] = 20
	_fill_col(c, 3, 20, H); heights[3] = 20
	WorldGenerator._place_slopes_chunk(c, heights, 0, 4, H)
	# 列1(h=19) vs 列2(h=20): h1=h0+1 → ◣ 放低列(2)地表上方那格 (2,19)
	assert_eq(c.tiles[2][19], Tiles.GRASS_SLOPE_L, "向左升 → ◣ 放 (2,19)")

func test_flat_no_slope() -> void:
	var H := 40
	var c = FakeChunk.new(3, H)
	var heights := {}
	for x in 3:
		_fill_col(c, x, 19, H); heights[x] = 19
	WorldGenerator._place_slopes_chunk(c, heights, 0, 3, H)
	for x in 3:
		assert_ne(c.tiles[x][18], Tiles.GRASS_SLOPE_R, "平地不铺坡")
		assert_ne(c.tiles[x][18], Tiles.GRASS_SLOPE_L, "平地不铺坡")
