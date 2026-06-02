extends GutTest

# blocks_art.gd 是 RefCounted (无 class_name), 测试里要 preload 才能用 (Tiles/ItemDB/ArtCache 是 autoload 直接用)
const BlocksArt = preload("res://scripts/art/blocks_art.gd")

# 云块: 实心可挖, 木镐就能挖, 掉 cloud 物品; cloud 物品能放回 CLOUD tile.
func test_cloud_tile_is_solid_mineable():
	assert_true(Tiles.is_solid(Tiles.CLOUD), "云块实心 (能站上去)")
	assert_true(Tiles.is_mineable(Tiles.CLOUD), "云块可挖")

func test_cloud_drops_cloud_item():
	# drops_for 权重 100 → cloud 必出 (dict: {item_id: count})
	var drops: Dictionary = Tiles.drops_for(Tiles.CLOUD, "")
	assert_true(drops.has("cloud"), "挖云块掉 cloud 物品")

func test_cloud_item_places_cloud_tile():
	var def = ItemDB.get_def("cloud")
	assert_not_null(def, "cloud 物品存在")
	assert_eq(def["placeable_tile_id"], Tiles.CLOUD, "cloud 物品放下去是 CLOUD tile")

func test_cloud_has_texture():
	var tex = BlocksArt.get_texture(Tiles.CLOUD)
	assert_not_null(tex, "云块有贴图")
	var img: Image = tex.get_image()
	assert_eq(img.get_width(), 16, "云块贴图 16 宽")
	assert_eq(img.get_height(), 16, "云块贴图 16 高")

func test_cloud_icon_in_artcache():
	# art_cache 的 tile_ids 列表漏了云块 → 这两个为 null (库存/世界都没图)
	assert_not_null(ArtCache.block_textures.get(Tiles.CLOUD), "art_cache 有云块世界贴图")
	assert_not_null(ArtCache.block_icons.get(Tiles.CLOUD), "art_cache 有云块库存图标")

func test_cloud_in_tileset_ids():
	# 漏了 tileset_builder 注册 → 世界里云块不显示也不报错, 必须查
	var src: String = FileAccess.get_file_as_string("res://scripts/world/tileset_builder.gd")
	assert_true(src.find("Tiles.CLOUD") != -1, "tileset_builder 必须注册 CLOUD")
