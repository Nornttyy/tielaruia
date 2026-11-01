extends GutTest

const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Blob = preload("res://scripts/world/blob_lookup.gd")
const Builder = preload("res://scripts/world/tileset_builder.gd")

func test_source_files_are_real_original_sheets():
	assert_eq(Pack.source_image("Tiles_0.png").get_size(), Vector2i(288, 270))
	assert_eq(Pack.source_image("Player_0_0.png").get_size(), Vector2i(40, 1118))
	assert_eq(Pack.source_image("Tree_Tops_0.png").get_size(), Vector2i(246, 82))

func test_all_connected_terrain_variants_have_visible_pixels():
	for tile_id in Pack.TERRAIN:
		var atlas: ImageTexture = Pack.block_atlas(tile_id)
		assert_not_null(atlas, "素材不存在：%s" % tile_id)
		if atlas == null: continue
		var img := atlas.get_image()
		assert_eq(img.get_size(), Vector2i(128, 128 * Pack.CONTACT_PAGES))
		for i in Blob.VARIANT_KEYS.size():
			var cell := img.get_region(Rect2i((i % 8) * 16, (i / 8) * 16, 16, 16))
			assert_false(cell.is_invisible(), "%s 的 %s 不能切到透明间隔" % [tile_id, Blob.VARIANT_KEYS[i]])

func test_runtime_terrain_is_loaded_from_source_not_old_placeholder():
	var source := Pack.terrain_cell(Pack.source_image("Tiles_0.png"), "CCCCIIII")
	var atlas_coord: Vector2i = Blob.ATLAS_COORD[255]
	var runtime: Image = ArtCache.block_textures[Tiles.DIRT].get_image().get_region(Rect2i(atlas_coord * 12, Vector2i(12, 12)))
	source.resize(12, 12, Image.INTERPOLATE_NEAREST)
	assert_eq(runtime.get_data(), source.get_data())

func test_crowns_and_branches_are_large_sprites_without_new_collision():
	var ts: TileSet = Builder.build()
	assert_eq(ts.tile_size, Vector2i(12, 12), "不改变旧世界坐标")
	var crown: TileSetAtlasSource = ts.get_source(Tiles.LOG_TOP)
	assert_eq(crown.texture_region_size, Vector2i(86, 72))
	assert_eq(crown.get_tiles_count(), 15)
	for i in 3:
		var tile = crown.get_tile_data(Vector2i(i, 0), 0)
		assert_eq(tile.get_collision_polygons_count(0), 0, "树冠不能变成隐形墙")
		assert_eq(tile.texture_origin, Vector2i(0, 30))
	assert_eq(ts.get_source(Tiles.BRANCH_L).texture_region_size, Vector2i(30, 30))

func test_player_frames_have_fixed_bounds_and_real_walk_cycle():
	var frames := Pack.player_frames()
	assert_eq(frames.get_frame_count("walk"), 14)
	assert_eq(frames.get_frame_count("idle"), 1)
	var unique := {}
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			var img := frames.get_frame_texture(animation, i).get_image()
			assert_eq(img.get_size(), Vector2i(32, 48))
			assert_false(img.is_invisible())
			if animation == "walk": unique[hash(img.get_data())] = true
	assert_gte(unique.size(), 8, "行走不能只重复两张图")

func test_clothing_and_hair_colors_still_work():
	var red := Pack.player_frame({"shirt_color": Color.RED}, 0).get_image()
	var blue := Pack.player_frame({"shirt_color": Color.BLUE}, 0).get_image()
	assert_ne(red.get_data(), blue.get_data())

func test_starter_tool_icons_are_not_placeholders():
	for pair in [["copper_dagger", "Item_3507.png"], ["copper_axe", "Item_3506.png"], ["copper_pickaxe", "Item_3509.png"]]:
		assert_eq(ArtCache.get_inventory_icon(pair[0]).get_image().get_data(), Pack.source_image(pair[1]).get_data())

func test_enemy_animations_match_callers():
	assert_true(ArtCache.slime_frames.has_animation("hop"))
	assert_true(ArtCache.zombie_frames.has_animation("walk"))
	assert_true(ArtCache.demon_eye_frames.has_animation("idle"))

func test_shoe_color_survives_all_walk_frames_and_action_frames():
	for gender in [0,1]:
		for frame in [0,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]:
			var red := Pack.player_frame({"gender":gender,"shoe_color":Color.RED}, frame).get_image()
			var blue := Pack.player_frame({"gender":gender,"shoe_color":Color.BLUE}, frame).get_image()
			var changed := 0
			for y in range(40,48):
				for x in 32:
					if red.get_pixel(x,y) != blue.get_pixel(x,y): changed += 1
			assert_gte(changed,8,"脚部鞋色必须可见，不再裁掉末尾像素：%d/%d" % [gender,frame])
	var image := Pack.player_frame({"shoe_color": Color8(170,85,40)},0).get_image()
	image.save_png("/tmp/tielaruia-player-shoes.png")
