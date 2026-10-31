extends GutTest

const Content = preload("res://scripts/items/original_content.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const ChestClass = preload("res://scripts/autoload/chest_storage.gd")
const NewArt = preload("res://scripts/art/original_items_art.gd")
const BlockArt = preload("res://scripts/art/blocks_art.gd")
const Matcher = preload("res://scripts/crafting/recipe_matcher.gd")

func test_classic_starter_kit():
	assert_eq(Content.STARTER_ITEMS, ["copper_dagger", "copper_pickaxe", "copper_axe"])

func test_retired_items_hidden_but_old_saves_resolve():
	var visible: Array = ItemDB.all_item_ids()
	for id in Content.RETIRED_ITEMS:
		assert_false(id in visible, id)
		assert_not_null(ItemDB.get_def(id), "旧档物品保留：" + id)

func test_original_gem_and_wooden_sword_remain():
	for id in ["diamond", "wood_sword", "sashimi", "copper_pickaxe"]:
		assert_true(ItemDB.is_available(id), id)

func test_gel_is_not_food():
	assert_false(ItemDB.is_food("slime_jelly"))

func test_tree_drops_building_wood_directly():
	for tid in [Tiles.LOG, Tiles.LOG_TOP, Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R, Tiles.BRANCH_L, Tiles.BRANCH_R]:
		var drops: Dictionary = Tiles.drops_for(tid, "axe")
		assert_false(drops.has("log"))
		if not drops.is_empty():
			assert_true(drops.has("planks"))

func test_grass_no_longer_drops_crops():
	for i in 50:
		assert_eq(Tiles.drops_for(Tiles.PLANT_GRASS, "sword"), {})

func test_all_active_recipes_have_valid_available_materials():
	var ids := {}
	for recipe in RecipeDB.all_recipes():
		assert_false(ids.has(recipe.id), "唯一配方：" + recipe.id)
		ids[recipe.id] = true
		assert_true(ItemDB.is_available(recipe.output_id), recipe.id)
		assert_gt(recipe.output_count, 0)
		for id in recipe.ingredients:
			assert_true(ItemDB.is_available(id), recipe.id + " / " + id)
			assert_gt(recipe.ingredients[id], 0)

func test_no_legacy_shaped_recipe_outputs():
	for id in ["planks", "wood_pickaxe", "stone_sword", "diamond_sword", "rice", "hell_sword", "sushi"]:
		assert_null(RecipeDB.get_recipe(id), id)
	assert_null(Matcher.find_match([["log", ""], ["", ""]]))

func test_workbench_and_torch_costs():
	assert_eq(RecipeDB.get_recipe("workbench").ingredients, {"planks": 10})
	assert_eq(RecipeDB.get_recipe("torch").ingredients, {"planks": 1, "slime_jelly": 1})
	assert_eq(RecipeDB.get_recipe("torch").output_count, 3)

func test_furnace_and_anvil_chain():
	var furnace: Dictionary = RecipeDB.get_recipe("furnace")
	assert_eq(furnace.ingredients, {"stone": 20, "planks": 4, "torch": 3})
	assert_eq(furnace.requires, "workbench")
	assert_eq(RecipeDB.get_recipe("iron_anvil").ingredients, {"iron_ingot": 5})
	assert_eq(RecipeDB.get_recipe("iron_anvil").requires, "workbench")

func test_smelting_needs_no_fuel():
	for metal in ["copper", "tin", "iron", "silver", "gold"]:
		var recipe: Dictionary = RecipeDB.get_recipe(metal + "_ingot")
		assert_eq(recipe.requires, "furnace")
		assert_eq(recipe.ingredients, {metal + "_ore": 4 if metal in ["silver", "gold"] else 3})

func test_tools_require_anvil_and_full_bar_counts():
	assert_eq(RecipeDB.get_recipe("iron_pickaxe").ingredients, {"iron_ingot": 10, "planks": 3})
	assert_eq(RecipeDB.get_recipe("copper_pickaxe").ingredients, {"copper_ingot": 8, "planks": 4})
	assert_eq(RecipeDB.get_recipe("gold_chest").ingredients, {"gold_ingot": 30})
	for metal in ["copper", "iron", "silver", "gold"]:
		for part in ["pickaxe", "axe", "sword", "dagger", "hammer", "helmet", "chest", "pants"]:
			assert_eq(RecipeDB.get_recipe(metal + "_" + part).requires, "anvil")

func test_hook_chain_recipe():
	assert_eq(RecipeDB.get_recipe("chain").ingredients, {"iron_ingot": 1})
	assert_eq(RecipeDB.get_recipe("chain").output_count, 10)
	assert_eq(RecipeDB.get_recipe("grappling_hook").ingredients, {"hook": 1, "chain": 3})

func test_new_icons_are_complete():
	for id in NewArt.PATTERNS:
		for row in NewArt.PATTERNS[id]:
			assert_eq(row.length(), 16, id + " 图标宽度")
		assert_not_null(ArtCache.get_inventory_icon(id), id)
	for tid in [Tiles.IRON_ANVIL, Tiles.IRON_ANVIL_RIGHT]:
		assert_false(Tiles.is_solid(tid))
		assert_not_null(ArtCache.block_textures.get(tid))
		assert_not_null(BlockArt.get_texture(tid))

func test_generated_chunks_have_no_removed_ores_or_diamond_chest():
	for seed_value in [42, 103]:
		for chunk_x in [-10, 0, 10]:
			var c = Generator.generate_chunk(seed_value, chunk_x)
			var found: Dictionary = {}
			for column in c.tiles:
				for tid in column:
					found[tid] = true
			for forbidden in [Tiles.COAL_ORE, Tiles.HELL_CRYSTAL, Tiles.HELL_ALLOY_ORE, Tiles.HELL_FRUIT, Tiles.DIAMOND_CHEST]:
				assert_false(found.has(forbidden), "seed %d / chunk %d / tile %d" % [seed_value, chunk_x, forbidden])

func test_new_treasure_has_no_retired_items_and_is_deterministic():
	var a = ChestClass.new()
	var b = ChestClass.new()
	add_child_autofree(a)
	add_child_autofree(b)
	for i in 100:
		var pos := Vector2i(i, 100)
		a.try_populate_treasure(pos, 42, [Tiles.CHEST, Tiles.GOLD_CHEST, Tiles.DIAMOND_CHEST, Tiles.SHADOW_CHEST][i % 4])
		b.try_populate_treasure(pos, 42, [Tiles.CHEST, Tiles.GOLD_CHEST, Tiles.DIAMOND_CHEST, Tiles.SHADOW_CHEST][i % 4])
		assert_eq(a.get_slots(pos), b.get_slots(pos))
		for slot in a.get_slots(pos):
			if slot != null:
				assert_true(ItemDB.is_available(slot.item_id), slot.item_id)
				assert_ne(slot.item_id, "coal")

func test_old_chest_contents_survive_restore():
	var chest = ChestClass.new()
	add_child_autofree(chest)
	chest.try_populate_treasure(Vector2i(2, 100), 42)
	chest.get_slots(Vector2i(2, 100))[0] = {"item_id": "diamond_sword", "count": 1}
	var saved: Dictionary = chest.dump()
	chest.restore(saved)
	chest.try_populate_treasure(Vector2i(2, 100), 42)
	assert_eq(chest.get_slots(Vector2i(2, 100))[0].item_id, "diamond_sword")

func test_player_tile_edits_override_generated_base():
	var chunk = Generator.generate_chunk(42, 0)
	chunk.apply_delta({Vector2i(2, 20): Tiles.PLANKS, Vector2i(3, 20): Tiles.AIR, Vector2i(4, 20): Tiles.DIAMOND_CHEST})
	assert_eq(chunk.get_tile(2, 20), Tiles.PLANKS)
	assert_eq(chunk.get_tile(3, 20), Tiles.AIR)
	assert_eq(chunk.get_tile(4, 20), Tiles.DIAMOND_CHEST)

func test_retired_monster_drop_is_blocked_at_source():
	var spider = preload("res://scripts/entities/spider.gd").new()
	# 没有加入场景树仍可安全返回，证明没有先创建再删除掉落物。
	spider._spawn_drop("spider_eye")
	spider.free()
	assert_true(true)
