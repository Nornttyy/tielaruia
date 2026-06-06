# 背景墙铺满 (植物除外) + 锤子 验收.
extends GutTest

const WG = preload("res://scripts/world/world_generator.gd")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")
const CraftingPanel = preload("res://scripts/ui/crafting_panel.gd")

const _HAMMERS := ["wood_hammer", "stone_hammer", "copper_hammer", "iron_hammer",
		"silver_hammer", "gold_hammer", "diamond_hammer", "hell_hammer"]


func test_is_plant_basic() -> void:
	assert_true(Tiles.is_plant(Tiles.PLANT_GRASS), "小草=植物")
	assert_true(Tiles.is_plant(Tiles.LEAVES), "树叶=植物")
	assert_true(Tiles.is_plant(Tiles.CACTUS), "仙人掌=植物")
	assert_true(Tiles.is_plant(Tiles.MUSHROOM), "蘑菇=植物")
	assert_false(Tiles.is_plant(Tiles.STONE), "石头≠植物")
	assert_false(Tiles.is_plant(Tiles.DIRT), "土≠植物")


func test_wall_drop_mapping() -> void:
	assert_eq(Tiles.wall_drop_item(Tiles.DIRT_WALL), "dirt_wall")
	assert_eq(Tiles.wall_drop_item(Tiles.STONE_WALL), "stone_wall")
	assert_eq(Tiles.wall_drop_item(Tiles.GRASS_WALL), "grass_wall")
	assert_eq(Tiles.wall_drop_item(Tiles.WOOD_WALL), "wood_wall")
	assert_true(Tiles.is_wall_tile(Tiles.DIRT_WALL))
	assert_false(Tiles.is_wall_tile(Tiles.STONE))


func test_surface_blocks_have_walls_sky_does_not() -> void:
	var c = WG.generate_chunk(4242, 0, 256)
	var surf_with_wall := 0
	var sky_with_wall := 0
	var plant_with_wall := 0
	var plant_seen := 0
	for lx in 64:
		var surf: int = c.surfaces[lx]
		if surf < 5 or surf > 250:
			continue
		# 地表块背后该有墙 (除非地表那格是植物)
		if not Tiles.is_plant(c.tiles[lx][surf]) and c.walls[lx][surf] != Tiles.AIR:
			surf_with_wall += 1
		# 天空 (surf 上方 3 格) 不该有墙
		if c.walls[lx][surf - 3] != Tiles.AIR:
			sky_with_wall += 1
		# 任何植物格背后不该有墙
		for y in range(surf, 256):
			if Tiles.is_plant(c.tiles[lx][y]):
				plant_seen += 1
				if c.walls[lx][y] != Tiles.AIR:
					plant_with_wall += 1
	gut.p("[墙] 地表有墙列=%d 天空有墙=%d 植物格=%d 植物背后有墙=%d" % [surf_with_wall, sky_with_wall, plant_seen, plant_with_wall])
	assert_gt(surf_with_wall, 40, "大部分地表块背后该有墙 (64 列)")
	assert_eq(sky_with_wall, 0, "天空不该有墙")
	assert_eq(plant_with_wall, 0, "植物格背后不该有墙")


func test_hammers_exist_with_tiers() -> void:
	for i in _HAMMERS.size():
		var id: String = _HAMMERS[i]
		var def = ItemDB.get_def(id)
		assert_not_null(def, "%s 该有定义" % id)
		assert_eq(def.tool_kind, "hammer", "%s tool_kind=hammer" % id)
		assert_eq(def.tool_tier, i + 1, "%s tier 该=%d" % [id, i + 1])


func test_hammer_icons_present_and_distinct() -> void:
	# 游戏内图标走 ArtCache.get_inventory_icon, 漏注册=背包空白
	var prev_data = null
	for id in _HAMMERS:
		var tex = ArtCache.get_inventory_icon(id)
		assert_not_null(tex, "%s 该有游戏内图标" % id)
	# 锤子造型该不同于同材质镐 (不能拿镐图当锤图)
	var hammer_tex = ArtCache.get_inventory_icon("iron_hammer")
	var pick_tex = ArtCache.get_inventory_icon("iron_pickaxe")
	if hammer_tex != null and pick_tex != null:
		assert_ne(hammer_tex.get_image().get_data(), pick_tex.get_image().get_data(),
			"锤子造型该跟镐不一样")


func test_wall_items_placeable_with_icons() -> void:
	for id in ["dirt_wall", "grass_wall", "stone_wall", "wood_wall"]:
		assert_true(ItemDB.is_wall(id), "%s 该是墙物品" % id)
		assert_true(ItemDB.is_placeable(id), "%s 该可放置" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 该有图标" % id)


func test_hammer_recipes_exist() -> void:
	for id in _HAMMERS:
		var r = RecipeDB.get_recipe(id)
		assert_not_null(r, "%s 该有合成配方" % id)
		assert_eq(r.output_id, id, "%s 配方产出该是自己" % id)


func test_hammer_and_wall_have_chinese_names() -> void:
	for id in _HAMMERS:
		assert_true(CraftingPanel._ZH_NAMES.has(id), "%s 该有中文名 (漏了显英文)" % id)
	for id in ["dirt_wall", "grass_wall"]:
		assert_true(CraftingPanel._ZH_NAMES.has(id), "%s 该有中文名" % id)


func test_wall_delta_persists_through_unload_reload() -> void:
	var cm = ChunkManagerClass.new()
	add_child_autofree(cm)
	cm.setup(99)
	cm.ensure_loaded(0)
	# 找 chunk 0 里一个有墙的格 (地表往下), 砸掉它
	var found := false
	var test_x := 0
	var test_y := 0
	for x in range(0, 30):
		for y in range(100, 200):
			if cm.get_wall(x, y) != Tiles.AIR:
				test_x = x
				test_y = y
				found = true
				break
		if found:
			break
	assert_true(found, "chunk 0 该有墙可测")
	cm.set_wall(test_x, test_y, Tiles.AIR)   # 砸墙
	assert_eq(cm.get_wall(test_x, test_y), Tiles.AIR, "砸完该没墙")
	# 卸载再加载 → 墙该还是被砸掉的 (delta 持久)
	cm.unload_far_from(999, 1)   # 把 chunk 0 卸了
	assert_false(cm.is_chunk_loaded(0), "chunk 0 该已卸载")
	cm.ensure_loaded(0)          # 重新加载
	assert_eq(cm.get_wall(test_x, test_y), Tiles.AIR, "重载后砸掉的墙不该回来 (wall delta 生效)")
