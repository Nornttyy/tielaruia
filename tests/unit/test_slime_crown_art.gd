# 史莱姆王王冠贴图: 16×8, 有金色实心像素 + 红宝石.
extends GutTest

const SlimeArt = preload("res://scripts/art/slime_art.gd")


func test_crown_texture_size() -> void:
	var tex := SlimeArt.build_crown_texture()
	assert_not_null(tex, "王冠贴图应生成")
	assert_eq(tex.get_width(), 16, "王冠宽应 16")
	assert_eq(tex.get_height(), 8, "王冠高应 8")


func test_crown_has_gold_and_gem() -> void:
	var img := SlimeArt.build_crown_texture().get_image()
	var opaque := 0
	var gold := 0
	var gem := 0
	for x in img.get_width():
		for y in img.get_height():
			var c := img.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			opaque += 1
			if c.r > 0.5 and c.g > 0.4 and c.b < 0.5:
				gold += 1          # 金: 红绿高蓝低
			elif c.r > 0.6 and c.g < 0.4 and c.b < 0.45:
				gem += 1           # 红宝石: 红高绿蓝低
	assert_gt(opaque, 20, "王冠应有足够实心像素 (got %d)" % opaque)
	assert_gt(gold, 10, "王冠应有金色像素 (got %d)" % gold)
	assert_gt(gem, 0, "王冠应有红宝石像素 (got %d)" % gem)
