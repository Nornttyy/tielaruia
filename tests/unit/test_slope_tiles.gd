# 斜砖 tile 定义 + 属性 + is_slope 助手.
extends GutTest

func test_slope_ids_defined() -> void:
	assert_eq(Tiles.GRASS_SLOPE_R, 92, "GRASS_SLOPE_R = 92")
	assert_eq(Tiles.GRASS_SLOPE_L, 93, "GRASS_SLOPE_L = 93")

func test_slope_is_solid_and_mineable() -> void:
	for s in [Tiles.GRASS_SLOPE_R, Tiles.GRASS_SLOPE_L]:
		assert_true(Tiles.is_solid(s), "斜砖实心 (撑住玩家)")
		assert_true(Tiles.is_mineable(s), "斜砖可挖")

func test_is_slope_helper() -> void:
	assert_true(Tiles.is_slope(Tiles.GRASS_SLOPE_R), "◢ 是斜砖")
	assert_true(Tiles.is_slope(Tiles.GRASS_SLOPE_L), "◣ 是斜砖")
	assert_false(Tiles.is_slope(Tiles.GRASS), "普通草不是斜砖")
	assert_false(Tiles.is_slope(Tiles.AIR), "空气不是斜砖")

func test_slope_drops_dirt() -> void:
	# 挖斜砖掉 dirt (跟草地一致)
	assert_eq(Tiles._PROPS[Tiles.GRASS_SLOPE_R]["drops"][0][0], "dirt", "斜砖掉 dirt")
