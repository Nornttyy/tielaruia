extends GutTest

# 空岛数量按世界大小: 小 1 / 中 2-3 / 大 3-5 (跟金字塔同款)
func test_skyisland_count_range_per_size():
	var prev: int = GameSettings.current_world_size
	GameSettings.current_world_size = 0
	assert_eq(GameSettings.skyisland_count_range(), [1, 1], "小世界 1 个")
	GameSettings.current_world_size = 1
	assert_eq(GameSettings.skyisland_count_range(), [2, 3], "中世界 2-3 个")
	GameSettings.current_world_size = 2
	assert_eq(GameSettings.skyisland_count_range(), [3, 5], "大世界 3-5 个")
	GameSettings.current_world_size = prev   # 还原, 不影响后续 test


const WG = preload("res://scripts/world/world_generator.gd")

func test_sky_island_chunks_nonempty():
	var chunks = WG._sky_island_chunks(777)
	assert_gt(chunks.size(), 0, "至少有一个空岛所在 chunk")

func test_sky_island_has_cloud_grass_chest():
	var chunks = WG._sky_island_chunks(777)
	var cx: int = chunks[0]
	var c = WG.generate_chunk(777, cx, 256)
	var cloud := 0
	var grass_sky := 0
	var chest := 0
	for lx in 64:
		for y in range(8, 60):   # 天空层 (远在地表 surf~115 之上)
			match c.tiles[lx][y]:
				Tiles.CLOUD: cloud += 1
				Tiles.GRASS: grass_sky += 1
				Tiles.DIAMOND_CHEST: chest += 1
	assert_gt(cloud, 20, "空岛云块够多 (岛体)")
	assert_gt(grass_sky, 5, "空岛有草顶")
	assert_eq(chest, 1, "空岛中心一个钻石宝箱")
	assert_gt(c.treasure_spots.size(), 0, "宝箱记进 treasure_spots (chunk_manager 会填战利品)")

func test_sky_island_deterministic():
	var chunks = WG._sky_island_chunks(2024)
	var cx: int = chunks[0]
	var a = WG.generate_chunk(2024, cx, 256)
	var b = WG.generate_chunk(2024, cx, 256)
	for lx in 64:
		assert_eq(a.tiles[lx], b.tiles[lx], "列 %d 两次生成完全一致" % lx)
