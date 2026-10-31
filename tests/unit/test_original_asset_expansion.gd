extends GutTest
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Content = preload("res://scripts/items/original_content.gd")
const Art = preload("res://scripts/art/building_art.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const Fishing = preload("res://scripts/player/player_fishing.gd")

func test_active_inventory_uses_original_png_pixels():
	for id in ItemDB.all_item_ids():
		if preload("res://scripts/world/classic_materials.gd").ITEMS.has(id):
			assert_not_null(ArtCache.get_inventory_icon(id))
			continue
		assert_true(Content.ORIGINAL_ITEM_IDS.has(id), id)
		var original := Pack.source_image("Item_%d.png" % Content.ORIGINAL_ITEM_IDS[id])
		assert_not_null(original, id)
		if id in ["apple", "apple_pie"]:
			original = original.get_region(Rect2i(0, 0, original.get_width(), original.get_height() / 3))
		var icon := ArtCache.get_inventory_icon(id)
		assert_not_null(icon, id)
		if icon != null: assert_eq(icon.get_image().get_data(), original.get_data(), id)

func test_custom_catalog_and_fishing_rewards_are_closed():
	for id in ["railgun", "tesla_gun", "hell_staff", "leaf_blade", "cloud_boots", "demon_heart", "wood_beam_wall", "nonexistent_future_item"]:
		assert_false(ItemDB.is_available(id), id)
	for reward in Fishing.CATCH_TABLE: assert_true(ItemDB.is_available(reward[0]))

func test_tables_chairs_and_closed_door_are_assembled_from_source():
	for entry in [[Art.CHAIR, 15], [Art.TABLE, 14]]:
		var whole := Art.furniture_image(entry[0])
		var sheet := Pack.source_image("Tiles_%d.png" % entry[1])
		var size := Art.footprint(entry[0])
		for y in size.y:
			for x in size.x:
				assert_eq(whole.get_region(Rect2i(x * 16, y * 16, 16, 16)).get_data(), sheet.get_region(Rect2i(x * 18, y * 18, 16, 16)).get_data())
	assert_eq(Art.door_image().get_region(Rect2i(0, 0, 16, 16)).get_data(), Pack.source_image("Tiles_10.png").get_region(Rect2i(0, 0, 16, 16)).get_data())

func test_new_building_materials_have_full_autotile_and_collision():
	var ts := preload("res://scripts/world/tileset_builder.gd").build()
	for id in ["glass", "gray_brick", "red_brick", "clay"]:
		var tid: int = ItemDB.get_def(id).placeable_tile_id
		assert_true(Tiles.is_solid(tid))
		var source: TileSetAtlasSource = ts.get_source(tid)
		assert_gt(source.get_tiles_count(), 40)
		assert_eq(source.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0), 1)

func test_clay_generated_deterministically_and_obtainable():
	var count := 0
	for cx in [-2, 0, 2]:
		var a = Generator.generate_chunk(42, cx)
		var b = Generator.generate_chunk(42, cx)
		assert_eq(a.tiles, b.tiles)
		for col in a.tiles:
			for tid in col:
				if tid == 130: count += 1
	assert_gt(count, 0)
	assert_eq(Tiles.drops_for(130, "pickaxe"), {"clay": 1})
	assert_eq(RecipeDB.get_recipe("red_brick").ingredients, {"clay": 2})
	for id in ["wood_chair", "wood_table", "glass_wall"]: assert_eq(RecipeDB.get_recipe(id).requires, "workbench")
