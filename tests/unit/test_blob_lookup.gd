extends GutTest

const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


func test_isolated_block():
	# mask 0 = 无任何邻居
	assert_eq(BlobLookup.mask_to_key(0), "OOOO....")


func test_only_north_neighbor():
	# N (bit 0) = 1, 其它 0
	assert_eq(BlobLookup.mask_to_key(1), "COOO....")


func test_north_and_east_no_corner():
	# N + E 闭, NE 角缺 (concave): bits 0|1 = 3
	assert_eq(BlobLookup.mask_to_key(0b0000_0011), "CCOOX...")


func test_north_and_east_with_corner():
	# N + E + NE: bits 0|1|16 = 19
	assert_eq(BlobLookup.mask_to_key(0b0001_0011), "CCOOI...")


func test_north_open_makes_ne_dot():
	# E + NE 但 N 开 → NE 角不重要
	assert_eq(BlobLookup.mask_to_key(0b0001_0010), "OCOO....")


func test_fully_interior():
	# 全 8 邻居都在: mask = 0xFF
	assert_eq(BlobLookup.mask_to_key(0xFF), "CCCCIIII")


func test_variant_keys_count_47():
	# 47 唯一 variant key
	assert_eq(BlobLookup.VARIANT_KEYS.size(), 47)


func test_variant_keys_unique():
	var seen := {}
	for k in BlobLookup.VARIANT_KEYS:
		assert_false(seen.has(k), "重复 key: %s" % k)
		seen[k] = true


func test_atlas_coord_isolated_is_origin():
	# 索引 0 (OOOO....) → atlas (0, 0)
	assert_eq(BlobLookup.ATLAS_COORD[0], Vector2i(0, 0))


func test_atlas_coord_for_mask_255_points_to_CCCCIIII():
	# mask 0xFF (全 8 邻居) 必须映射到 "CCCCIIII" (全闭 + 全 interior 角) 这个 key,
	# 它代表"完全被包围"的内部块, 无任何边缘装饰. T4 (art_cache.gd) 用此格作 inventory icon.
	# 此处不绑定具体索引/坐标 (字典序排序可能让它在 4-闭组首位 31, 不是末尾 46).
	var coord: Vector2i = BlobLookup.ATLAS_COORD[255]
	var idx: int = coord.x + coord.y * 8
	assert_eq(BlobLookup.VARIANT_KEYS[idx], "CCCCIIII")


# ─── Slope-aware 82-blob 测试 (草+土斜接) ──────────────────────────────

func test_slope_isolated_no_slope_flags():
	# mask 0 = 完全孤立, 4 角都"两相邻边都开 + 对角无" → 4 个 "_"
	assert_eq(BlobLookup.mask_to_slope_key(0), "OOOO....____")


func test_slope_only_SE_diagonal():
	# 只 SE 邻居 (mask = 32 = bit 5): 4 边都开 + SE 对角在 + 其它 3 角对角无
	# 角字符仍是 "." (因为 sides 都开 → corner 是 ".")
	# slope 字符: NE/SW/NW = "_" (无 diag); SE = "P" (有 diag)
	# 总 key: "OOOO" (sides 4) + "...." (corners 4) + "_P__" (slopes 4) = 12 chars
	assert_eq(BlobLookup.mask_to_slope_key(32), "OOOO...._P__")


func test_slope_only_NE_diagonal():
	# 只 NE (mask = 16 = bit 4): slope NE 位应 "P", 其它 "_"
	assert_eq(BlobLookup.mask_to_slope_key(16), "OOOO....P___")


func test_slope_fully_interior():
	# mask 0xFF: 全 8 邻居都闭, 4 角都 I (interior), slope 全 "-" (sides 都闭, 不适用)
	assert_eq(BlobLookup.mask_to_slope_key(0xFF), "CCCCIIII----")


func test_slope_variant_keys_82():
	# slope-aware key 应有 82 唯一变体
	assert_eq(BlobLookup.SLOPE_VARIANT_KEYS.size(), 82)


func test_slope_atlas_coord_size_256():
	assert_eq(BlobLookup.SLOPE_ATLAS_COORD.size(), 256)


func test_slope_atlas_coord_in_range():
	for v in BlobLookup.SLOPE_ATLAS_COORD:
		assert_true(v.x >= 0 and v.x < BlobLookup.SLOPE_ATLAS_COLS, "col 越界: %d" % v.x)
		assert_true(v.y >= 0 and v.y < BlobLookup.SLOPE_ATLAS_ROWS, "row 越界: %d" % v.y)


func test_slope_atlas_coord_unique_count_82():
	var seen := {}
	for v in BlobLookup.SLOPE_ATLAS_COORD:
		seen[v] = true
	assert_eq(seen.size(), 82)


func test_atlas_coord_size_256():
	assert_eq(BlobLookup.ATLAS_COORD.size(), 256)


func test_atlas_coord_in_range():
	# 所有坐标在 8×6 范围内
	for v in BlobLookup.ATLAS_COORD:
		assert_true(v.x >= 0 and v.x < 8, "col 越界: %d" % v.x)
		assert_true(v.y >= 0 and v.y < 6, "row 越界: %d" % v.y)


func test_atlas_coord_only_47_unique():
	var seen := {}
	for v in BlobLookup.ATLAS_COORD:
		seen[v] = true
	assert_eq(seen.size(), 47)
