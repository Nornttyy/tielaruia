extends GutTest

# TileData 是 autoload。测试里通过 load() 直接拿到类（避免依赖注册顺序）。
const TileDataClass = preload("res://scripts/world/tile_data.gd")
var td: Node


func before_each():
	td = TileDataClass.new()
	add_child_autofree(td)


func test_air_is_not_solid():
	assert_false(td.is_solid(td.AIR), "空气不实心")


func test_stone_is_solid():
	assert_true(td.is_solid(td.STONE), "石头实心")


func test_bedrock_is_unbreakable():
	assert_false(td.is_mineable(td.BEDROCK), "基岩不可挖")


func test_grass_mineable_by_bare_hand():
	assert_true(td.is_mineable(td.GRASS), "草可挖")
	assert_eq(td.required_tool_tier(td.GRASS, "pickaxe"), 0, "草徒手挖")


func test_stone_needs_pickaxe():
	assert_eq(td.required_tool_tier(td.STONE, "pickaxe"), 1, "石头需 1 级镐")
	assert_eq(td.required_tool_tier(td.STONE, "axe"), -1, "斧头挖不了石头")


func test_grass_drops_dirt_or_self():
	# drops_for 是概率抽样，多跑几次保证有产出
	var any_drop := false
	for _i in 20:
		var drops = td.drops_for(td.GRASS, "")
		if drops.has("dirt") or drops.has("grass"):
			any_drop = true
			break
	assert_true(any_drop, "草 20 次抽样至少掉一次 dirt 或 grass")
