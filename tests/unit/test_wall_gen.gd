# 背景墙生成 + autotile 连接.
# 修复用户报的两个 bug:
#  ① "地下蘑菇后面没墙" → _fill_walls_chunk 去掉"植物格跳过", 地下植物后面也铺墙.
#  ② "背景墙连接不起来" → make_wall_query 改 is_wall_tile, 任何墙互相连(土/石交界不再有缝).
extends GutTest

const WG = preload("res://scripts/world/world_generator.gd")
const Autotile = preload("res://scripts/world/autotile.gd")


# Bug①: 地下蘑菇(植物)格后面该有背景墙. (原先 is_plant 跳过 → 留个洞)
func test_wall_fills_behind_underground_mushroom() -> void:
	var height := 40
	var c = WG.empty_chunk(0, height)
	var cw: int = c.tiles.size()
	var heights := {}
	for lx in cw:
		heights[lx] = 10                    # 地表在 y=10
	c.tiles[5][20] = Tiles.MUSHROOM         # 地下 (y=20) 放一颗蘑菇
	WG._fill_walls_chunk(c, heights, cw, height)
	assert_ne(c.walls[5][20], Tiles.AIR, "地下蘑菇格后面该有墙, 不该留洞")
	assert_eq(c.walls[5][5], Tiles.AIR, "天上 (y<surf) 仍不该有墙")


# 假 chunk_manager: (x,1)=石墙 (x,2)=空气 其余=土墙. 测墙的跨type连接.
class _FakeWallCM:
	func get_wall(_x: int, y: int) -> int:
		if y == 1:
			return 20    # Tiles.STONE_WALL
		if y == 2:
			return 0     # Tiles.AIR (无墙)
		return 19        # Tiles.DIRT_WALL


# Bug②: 不同墙type 该互相连(autotile), 否则土墙/石墙交界画出缝 = "连不起来".
func test_wall_autotile_connects_across_types() -> void:
	var q: Callable = Autotile.make_wall_query(Tiles.DIRT_WALL, _FakeWallCM.new())
	assert_true(q.call(0, 0), "同种墙(土墙)该相连")
	assert_true(q.call(0, 1), "不同种墙(石墙)也该相连 — 修复后")
	assert_false(q.call(0, 2), "空气(无墙)不该相连")
