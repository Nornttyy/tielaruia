# 出生点找地表: 只认"那列最顶上的实心方块是地表类", 避免把洞里被挖空的深处沙/泥当地表.
extends GutTest

const World = preload("res://scripts/world/world.gd")


# 建一个 200 高的列, pairs=[[start_y, tile, count], ...], 其余 AIR.
func _col(pairs: Array) -> Array:
	var c: Array = []
	c.resize(200)
	for i in 200:
		c[i] = Tiles.AIR
	for p in pairs:
		for k in p[2]:
			c[p[0] + k] = p[1]
	return c


func test_clean_grass_surface():
	var col := _col([[100, Tiles.GRASS, 1], [101, Tiles.DIRT, 20]])
	assert_eq(World._surface_y_of_column(col), 100, "干净草地表 → 100")


func test_pit_to_deep_mud_skipped():
	# 地表被挖穿: 一路空到 130 才有 DIRT(顶实心), 深处 160 有 MUD(上面是洞空)
	# 老 bug 会选 160 的 MUD; 新逻辑看顶实心=DIRT(非地表类) → 跳过这列
	var col := _col([[130, Tiles.DIRT, 5], [160, Tiles.MUD, 1]])
	assert_eq(World._surface_y_of_column(col), -1, "顶实心是泥土/被挖穿 → 跳过, 绝不选深处 MUD")


func test_all_air_skipped():
	assert_eq(World._surface_y_of_column(_col([])), -1, "全空列跳过")


func test_stone_surface_skipped():
	assert_eq(World._surface_y_of_column(_col([[100, Tiles.STONE, 10]])), -1, "顶实心是石头 → 跳过 (不在地表上出生在石头里)")


func test_desert_sand_surface_ok():
	# 沙漠真地表是沙: 顶实心=SAND → 合法
	assert_eq(World._surface_y_of_column(_col([[100, Tiles.SAND, 10]])), 100, "沙漠沙地表合法")
