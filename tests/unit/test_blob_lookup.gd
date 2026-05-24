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
	assert_eq(BlobLookup.mask_to_key(0b0000_0011), "CCOO.X..")


func test_north_and_east_with_corner():
	# N + E + NE: bits 0|1|16 = 19
	assert_eq(BlobLookup.mask_to_key(0b0001_0011), "CCOO.I..")


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
