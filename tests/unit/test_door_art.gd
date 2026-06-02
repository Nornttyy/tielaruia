# 3 格门: 图案 16×16, 段间无缝 (连起来), 门都不挡玩家, 背包图标存在.
extends GutTest

const BlocksArt = preload("res://scripts/art/blocks_art.gd")


func test_door_patterns_are_16x16() -> void:
	for tid in [BlocksArt.DOOR, BlocksArt.DOOR_MID, BlocksArt.DOOR_TOP, BlocksArt.DOOR_OPEN]:
		var tex := BlocksArt.get_texture(tid)
		assert_eq(tex.get_width(), 16, "门图案宽 16 (tid=%d)" % tid)
		assert_eq(tex.get_height(), 16, "门图案高 16 (tid=%d)" % tid)


func test_door_icon_is_16x16() -> void:
	var tex := BlocksArt.get_door_icon_texture()
	assert_eq(tex.get_width(), 16, "门图标宽 16")
	assert_eq(tex.get_height(), 16, "门图标高 16")


func test_all_door_tiles_pass_through_player() -> void:
	# 门底/中/顶/开 都 solid=false (单独物理层挡怪, 玩家放行)
	assert_false(Tiles.is_solid(Tiles.DOOR), "DOOR 不 solid")
	assert_false(Tiles.is_solid(Tiles.DOOR_MID), "DOOR_MID 不 solid")
	assert_false(Tiles.is_solid(Tiles.DOOR_TOP), "DOOR_TOP 不 solid")
	assert_false(Tiles.is_solid(Tiles.DOOR_OPEN), "DOOR_OPEN 不 solid")


func test_door_segments_are_seamless() -> void:
	# "连起来": 拼接处花纹连续 — 上一段最底行 == 下一段最顶行 (无横边框).
	var bottom := BlocksArt.get_texture(BlocksArt.DOOR).get_image()       # 世界里最下
	var mid := BlocksArt.get_texture(BlocksArt.DOOR_MID).get_image()
	var top := BlocksArt.get_texture(BlocksArt.DOOR_TOP).get_image()      # 世界里最上
	for x in 16:
		# 顶段底行 接 中段顶行
		assert_eq(top.get_pixel(x, 15), mid.get_pixel(x, 0),
			"顶↔中 接缝不连续 x=%d" % x)
		# 中段底行 接 底段顶行
		assert_eq(mid.get_pixel(x, 15), bottom.get_pixel(x, 0),
			"中↔底 接缝不连续 x=%d" % x)
