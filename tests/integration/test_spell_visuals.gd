# 法杖魔法弹: 3 种元素贴图主色不同 (绿/蓝/红); fireball.setup 按元素换贴图.
extends GutTest
const FireballScene = preload("res://scenes/entities/fireball.tscn")

func test_spell_frames_distinct_colors() -> void:
	var nature: SpriteFrames = ArtCache.spell_frames_for("nature")
	var ice: SpriteFrames = ArtCache.spell_frames_for("ice")
	var fire: SpriteFrames = ArtCache.spell_frames_for("fire")
	assert_not_null(nature, "自然弹有贴图")
	assert_not_null(ice, "冰霜弹有贴图")
	assert_not_null(fire, "火球有贴图")
	# 取外圈代表像素 (5,7 在 _F0 上是 'r' 外圈色), 比主色调
	var cn := _ring_color(nature)
	var ci := _ring_color(ice)
	var cf := _ring_color(fire)
	assert_gt(cn.g, cn.b, "自然弹偏绿 (绿 > 蓝)")
	assert_gt(ci.b, ci.r, "冰霜弹偏蓝 (蓝 > 红)")
	assert_gt(cf.r, cf.b, "火球偏红 (红 > 蓝)")

func _ring_color(sf: SpriteFrames) -> Color:
	var img: Image = sf.get_frame_texture("fly", 0).get_image()
	return img.get_pixel(5, 7)

func test_fireball_setup_applies_element() -> void:
	for elem in ["nature", "ice", "fire"]:
		var fb = FireballScene.instantiate()
		add_child_autofree(fb)
		fb.setup(Vector2(100, 100), Vector2(200, 100), 8, true, elem)
		await wait_frames(1)
		assert_eq(fb.element, elem, "%s 弹 element 字段正确" % elem)
		assert_eq(fb.sprite.sprite_frames, ArtCache.spell_frames_for(elem),
			"%s 弹贴图 = 对应元素贴图" % elem)
