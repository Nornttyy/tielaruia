extends GutTest

const PlayerArt = preload("res://scripts/art/player_art.gd")

func _default_appearance() -> Dictionary:
	return {
		"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
		"cape_style": 0, "chest_size": 1,
		"skin_color": Color8(255, 218, 185), "hair_color": Color8(121, 85, 72),
		"shirt_color": Color8(229, 57, 53), "pants_color": Color8(38, 70, 130),
		"cape_color": Color8(150, 40, 50), "eye_color": Color8(60, 110, 70),
	}

func test_build_returns_sprite_frames_with_all_anims():
	var sf = PlayerArt.build_sprite_frames(_default_appearance())
	assert_true(sf is SpriteFrames, "返回 SpriteFrames")
	for anim in ["idle", "walk", "jump", "fall", "hurt"]:
		assert_true(sf.has_animation(anim), "有动画 %s" % anim)

func test_canvas_is_24x48():
	var sf = PlayerArt.build_sprite_frames(_default_appearance())
	var tex = sf.get_frame_texture("idle", 0)
	assert_eq(tex.get_width(), 24, "宽 24")
	assert_eq(tex.get_height(), 48, "高 48")

func test_no_arg_uses_default_and_matches_appearance_default():
	# 无参 = 默认 appearance, 两者首帧逐像素一致 (锁"默认基准")。
	var a = PlayerArt.build_sprite_frames()
	var b = PlayerArt.build_sprite_frames(_default_appearance())
	var ia = a.get_frame_texture("idle", 0).get_image()
	var ib = b.get_frame_texture("idle", 0).get_image()
	for y in range(48):
		for x in range(24):
			assert_eq(ia.get_pixel(x, y), ib.get_pixel(x, y), "默认基准像素 (%d,%d) 一致" % [x, y])

func test_shirt_color_pixel_follows_appearance():
	var ap = _default_appearance()
	ap["shirt_color"] = Color8(10, 200, 30)
	var sf = PlayerArt.build_sprite_frames(ap)
	var img = sf.get_frame_texture("idle", 0).get_image()
	# 躯干区 (row 16..30) 应有衬衫主色
	assert_true(_has_color_near(img, Color8(10, 200, 30), range(16, 31), range(6, 19)), "躯干有所选衬衫色")

func test_eye_has_white_and_iris():
	var ap = _default_appearance()
	ap["eye_color"] = Color8(200, 30, 30)
	var sf = PlayerArt.build_sprite_frames(ap)
	var img = sf.get_frame_texture("idle", 0).get_image()
	# 头部眼区同时有近白 (眼白) 和所选眼珠色
	assert_true(_has_color_near(img, Color(1, 1, 1, 1), range(8, 24), range(8, 22), 0.18), "眼区有眼白")
	assert_true(_has_color_near(img, Color8(200, 30, 30), range(8, 24), range(8, 22), 0.12), "眼区有所选眼珠色")

func test_unknown_shirt_style_falls_back_no_crash():
	var ap = _default_appearance()
	ap["shirt_style"] = 99   # 未画的款 → 回退默认, 不崩
	var sf = PlayerArt.build_sprite_frames(ap)
	assert_true(sf.has_animation("idle"), "未知款回退不崩")

func test_hairstyles_differ():
	var imgs := []
	for hs in range(4):
		var ap = _default_appearance(); ap["hair_style"] = hs
		imgs.append(PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image())
	for a in range(4):
		for c in range(a + 1, 4):
			var diff := 0
			for y in range(6, 24):
				for x in range(24):
					if imgs[a].get_pixel(x, y) != imgs[c].get_pixel(x, y):
						diff += 1
			assert_gt(diff, 0, "发型 %d 与 %d 不同" % [a, c])

func test_hair_color_follows_appearance():
	var ap = _default_appearance(); ap["hair_color"] = Color8(20, 180, 220)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color_near(img, Color8(20, 180, 220), range(6, 22), range(6, 20)), "头发是所选色")

func test_skin_color_follows_appearance():
	var ap = _default_appearance(); ap["skin_color"] = Color8(120, 80, 55)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color_near(img, Color8(120, 80, 55), range(8, 22), range(8, 22)), "脸是所选肤色")

func test_pants_color_follows_appearance():
	var ap = _default_appearance(); ap["pants_color"] = Color8(20, 160, 60)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color_near(img, Color8(20, 160, 60), range(27, 43), range(7, 18)), "裤子是所选色")

func test_female_body_differs_from_male():
	var m = _default_appearance(); m["gender"] = 0
	var f = _default_appearance(); f["gender"] = 1
	var im = PlayerArt.build_sprite_frames(m).get_frame_texture("idle", 0).get_image()
	var iff = PlayerArt.build_sprite_frames(f).get_frame_texture("idle", 0).get_image()
	var diff := 0
	for y in range(48):
		for x in range(24):
			if im.get_pixel(x, y) != iff.get_pixel(x, y):
				diff += 1
	assert_gt(diff, 10, "女身体与男身体有明显差异 (重画比例)")

func test_chest_size_changes_female_torso():
	var f0 = _default_appearance(); f0["gender"] = 1; f0["chest_size"] = 0
	var f5 = _default_appearance(); f5["gender"] = 1; f5["chest_size"] = 5
	var i0 = PlayerArt.build_sprite_frames(f0).get_frame_texture("idle", 0).get_image()
	var i5 = PlayerArt.build_sprite_frames(f5).get_frame_texture("idle", 0).get_image()
	var diff := 0
	for y in range(13, 26):   # 胸口区
		for x in range(24):
			if i0.get_pixel(x, y) != i5.get_pixel(x, y):
				diff += 1
	assert_gt(diff, 0, "胸围 0 与 5 在胸口区像素不同")

func test_male_ignores_chest_size():
	var m0 = _default_appearance(); m0["gender"] = 0; m0["chest_size"] = 0
	var m5 = _default_appearance(); m5["gender"] = 0; m5["chest_size"] = 5
	var i0 = PlayerArt.build_sprite_frames(m0).get_frame_texture("idle", 0).get_image()
	var i5 = PlayerArt.build_sprite_frames(m5).get_frame_texture("idle", 0).get_image()
	for y in range(48):
		for x in range(24):
			assert_eq(i0.get_pixel(x, y), i5.get_pixel(x, y), "男版不受 chest_size 影响 (%d,%d)" % [x, y])

# helper: 在 row/col 范围内是否有接近 target 的像素 (容差比较)
func _has_color_near(img: Image, target: Color, rows, cols, tol := 0.06) -> bool:
	for y in rows:
		for x in cols:
			var c = img.get_pixel(x, y)
			if c.a > 0.5 and abs(c.r - target.r) < tol and abs(c.g - target.g) < tol and abs(c.b - target.b) < tol:
				return true
	return false
