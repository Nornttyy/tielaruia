# 回归: 缩放后的方块贴图不该有半透明像素 (alpha 只能 0 或 1).
# LANCZOS 缩放会在透明边缘产生半透明 → 草看着半透明. _smart_resize 现卡硬 alpha.
extends GutTest


func _assert_binary_alpha(tile_id: int, name: String) -> void:
	var tex = ArtCache.block_textures.get(tile_id)
	assert_not_null(tex, "%s 该有贴图" % name)
	if tex == null:
		return
	var img: Image = tex.get_image()
	var bad: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var a: float = img.get_pixel(x, y).a
			if a > 0.02 and a < 0.98:
				bad += 1
	assert_eq(bad, 0, "%s 不该有半透明像素 (半透明 %d 个 = 看着发虚)" % [name, bad])


func test_grass_no_semitransparent() -> void:
	_assert_binary_alpha(Tiles.GRASS, "草")


func test_leaves_no_semitransparent() -> void:
	_assert_binary_alpha(Tiles.LEAVES, "树叶")


func test_dirt_no_semitransparent() -> void:
	_assert_binary_alpha(Tiles.DIRT, "泥土")
