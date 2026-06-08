extends GutTest

const PlayerArt = preload("res://scripts/art/player_art.gd")

func _default_appearance() -> Dictionary:
	return PlayerArt.DEFAULT_APPEARANCE.duplicate(true)

# 整图扫描: 图里有没有接近 target 的像素 (稳, 不依赖固定坐标)。
func _has_color(img: Image, target: Color, tol := 0.08) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var c = img.get_pixel(x, y)
			if c.a > 0.5 and abs(c.r - target.r) < tol and abs(c.g - target.g) < tol and abs(c.b - target.b) < tol:
				return true
	return false

func _count_diff(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n

func test_build_has_all_anims():
	var sf = PlayerArt.build_sprite_frames(_default_appearance())
	assert_true(sf is SpriteFrames, "返回 SpriteFrames")
	for anim in ["idle", "walk", "jump", "fall", "hurt"]:
		assert_true(sf.has_animation(anim), "有动画 %s" % anim)

func test_canvas_size():
	var tex = PlayerArt.build_sprite_frames(_default_appearance()).get_frame_texture("idle", 0)
	assert_eq(tex.get_width(), PlayerArt.W, "宽 = W")
	assert_eq(tex.get_height(), PlayerArt.H, "高 = H")

func test_no_arg_matches_default():
	var a = PlayerArt.build_sprite_frames().get_frame_texture("idle", 0).get_image()
	var b = PlayerArt.build_sprite_frames(_default_appearance()).get_frame_texture("idle", 0).get_image()
	assert_eq(_count_diff(a, b), 0, "无参 = 默认 appearance")

func test_shirt_color_applies():
	var ap = _default_appearance(); ap["shirt_color"] = Color8(10, 200, 30)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color(img, Color8(10, 200, 30)), "衬衫色出现")

func test_pants_color_applies():
	var ap = _default_appearance(); ap["pants_color"] = Color8(20, 160, 60)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color(img, Color8(20, 160, 60)), "裤子色出现")

func test_hair_color_applies():
	var ap = _default_appearance(); ap["hair_color"] = Color8(20, 180, 220)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color(img, Color8(20, 180, 220)), "头发色出现")

func test_eye_has_white_and_iris():
	var ap = _default_appearance(); ap["eye_color"] = Color8(200, 30, 30)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color(img, Color(1, 1, 1, 1), 0.12), "有眼白")
	assert_true(_has_color(img, Color8(200, 30, 30), 0.12), "有眼珠色")

func test_hairstyles_differ():
	var imgs := []
	for hs in range(4):
		var ap = _default_appearance(); ap["hair_style"] = hs
		imgs.append(PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image())
	for a in range(4):
		for c in range(a + 1, 4):
			assert_gt(_count_diff(imgs[a], imgs[c]), 0, "发型 %d 与 %d 不同" % [a, c])

func test_female_differs_from_male():
	var m = _default_appearance(); m["gender"] = 0
	var f = _default_appearance(); f["gender"] = 1
	var im = PlayerArt.build_sprite_frames(m).get_frame_texture("idle", 0).get_image()
	var iff = PlayerArt.build_sprite_frames(f).get_frame_texture("idle", 0).get_image()
	assert_gt(_count_diff(im, iff), 0, "男女不同")

func test_chest_size_changes_female():
	# 女生胸围滑条每动一格都要看得见变化 (修 '调了没反应')
	var imgs := []
	for cs in range(6):
		var ap = _default_appearance(); ap["gender"] = 1; ap["chest_size"] = cs
		imgs.append(PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image())
	for cs in range(5):
		assert_gt(_count_diff(imgs[cs], imgs[cs + 1]), 0, "胸围 %d→%d 有变化" % [cs, cs + 1])

func test_chest_size_male_unaffected():
	# 胸围只对女生生效, 男生调它不该变
	var a = _default_appearance(); a["gender"] = 0; a["chest_size"] = 0
	var b = _default_appearance(); b["gender"] = 0; b["chest_size"] = 5
	var ia = PlayerArt.build_sprite_frames(a).get_frame_texture("idle", 0).get_image()
	var ib = PlayerArt.build_sprite_frames(b).get_frame_texture("idle", 0).get_image()
	assert_eq(_count_diff(ia, ib), 0, "男生不受胸围影响")

func test_unknown_style_no_crash():
	var ap = _default_appearance(); ap["shirt_style"] = 99; ap["hair_style"] = 99
	var sf = PlayerArt.build_sprite_frames(ap)
	assert_true(sf.has_animation("idle"), "未知款回退不崩")
