extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

func test_feather_item_def():
	var def = ItemDB.get_def("feather")
	assert_not_null(def, "feather 物品存在")
	assert_eq(def["placeable_tile_id"], -1, "羽毛不是方块")

func test_feather_has_icon():
	assert_true(ItemsArt.has_icon("feather"), "羽毛有图标")
	var tex = ItemsArt.get_icon("feather")
	assert_eq(tex.get_image().get_width(), 16, "图标 16 宽")

func test_harpy_frames_built():
	assert_not_null(ArtCache.harpy_frames, "哈比鸟 SpriteFrames 已建")
	assert_true(ArtCache.harpy_frames.has_animation("move"), "有 move 动画")


const HarpyScene = preload("res://scenes/entities/harpy.tscn")

func test_harpy_instantiates_and_no_player_collision():
	var h = HarpyScene.instantiate()
	add_child_autofree(h)
	await wait_frames(2)
	assert_eq(h.collision_layer, 0, "哈比鸟 collision_layer=0 (玩家不被它挡)")
	assert_true(h.is_in_group("slimes"), "在通用敌人组 slimes (武器能打)")
	assert_true(h.is_in_group("harpies"), "在 harpies 组")

func test_harpy_drops_feather_on_death():
	var h = HarpyScene.instantiate()
	add_child_autofree(h)
	await wait_frames(2)
	h.take_damage(9999, Vector2.ZERO, 0.0)   # 一击毙
	await wait_frames(2)
	var drops = get_tree().get_nodes_in_group("item_drops")
	var has_feather := false
	for d in drops:
		if d.get("item_id") == "feather":
			has_feather = true
	assert_true(has_feather, "哈比鸟死了掉羽毛")


const WG = preload("res://scripts/world/world_generator.gd")

func test_sky_island_records_harpy_spots():
	var chunks = WG._sky_island_chunks(777)
	var c = WG.generate_chunk(777, chunks[0], 256)
	assert_gt(c.harpy_spawn_spots.size(), 0, "空岛 chunk 记了哈比鸟出生点")
	for spot in c.harpy_spawn_spots:
		assert_lt(spot.y, 60, "哈比鸟出生点在天空层 (y<60)")
