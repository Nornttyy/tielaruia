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
	# 挥击/放置身体姿势已删 (用户要求): 不该再有这俩动画
	assert_false(sf.has_animation("swing"), "swing 身体姿势已删")
	assert_false(sf.has_animation("place"), "place 身体姿势已删")


# 跳跃 2 帧, 一次性不循环 (蹬地→腾空)
func test_jump_is_two_frames_no_loop():
	var sf = PlayerArt.build_sprite_frames(_default_appearance())
	assert_eq(sf.get_frame_count("jump"), 2, "jump 该 2 帧")
	assert_false(sf.get_animation_loop("jump"), "jump 不循环 (放一次)")

# 女角色 胸 squash-stretch: 上抬帧上挺(-1), 落脚帧下沉外鼓(+1), 站立回位(0)。
func test_soft_jiggle_phases():
	assert_eq(PlayerArt._soft_jiggle("walk_b"), -1, "腾空/过渡帧: 胸上挺 (stretch)")
	assert_eq(PlayerArt._soft_jiggle("walk_a"), 1, "落脚帧: 胸下沉外鼓 (squash)")
	assert_eq(PlayerArt._soft_jiggle("idle_a"), 0, "站立回位")


func test_hair_sway_alternates():
	assert_eq(PlayerArt._hair_sway("walk_a"), 2, "迈左脚发梢甩向后 (±2 更夸张)")
	assert_eq(PlayerArt._hair_sway("walk_c"), -2, "迈右脚发梢甩向前")
	assert_eq(PlayerArt._hair_sway("idle_a"), 0, "站立发不甩")


func test_chest_squash_stretch_no_collapse():
	# squash-stretch: stretch(-1)上挺 / squash(+1)外鼓 / rest(0), 三态各不同, 都不塌陷。
	var rest = PlayerArt._female_torso(4, 0)
	var stretch = PlayerArt._female_torso(4, -1)
	var squash = PlayerArt._female_torso(4, 1)
	assert_ne(rest, stretch, "上挺 ≠ 回位")
	assert_ne(rest, squash, "外鼓 ≠ 回位")
	assert_ne(stretch, squash, "上挺 ≠ 外鼓")
	# 三个状态都不塌陷 (隆起占的行各不相同, 没挤成一行)
	for t in [rest, stretch, squash]:
		assert_ne(t[1], t[2], "隆起不塌 (第1行≠第2行)")
		assert_ne(t[2], t[3], "隆起不塌 (第2行≠第3行)")


func test_sway_block_moves_lower_half_only():
	var block = ["abcd", "efgh", "ijkl", "mnop"]   # 4 行
	var swayed = PlayerArt._sway_block(block, 1)
	assert_eq(swayed[0], "abcd", "上半发根不动")
	assert_eq(swayed[1], "efgh", "上半发根不动")
	assert_ne(swayed[2], "ijkl", "下半发梢右移")
	assert_eq(PlayerArt._sway_block(block, 0), block, "dir=0 不变")


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

func test_shirt_style_vest_changes_render():
	# 背心款 (shirt_style 1) 露胳膊, 跟 T恤 (袖子) 不同
	var a = _default_appearance()
	var b = _default_appearance(); b["shirt_style"] = 1
	var ia = PlayerArt.build_sprite_frames(a).get_frame_texture("idle", 0).get_image()
	var ib = PlayerArt.build_sprite_frames(b).get_frame_texture("idle", 0).get_image()
	assert_gt(_count_diff(ia, ib), 0, "背心款(裸臂)与 T恤不同")

func test_pants_style_skirt_changes_render():
	# 裙子款 (pants_style 2) 裸腿 + 盖裙, 跟长裤不同
	var a = _default_appearance()
	var b = _default_appearance(); b["pants_style"] = 2
	var ia = PlayerArt.build_sprite_frames(a).get_frame_texture("idle", 0).get_image()
	var ib = PlayerArt.build_sprite_frames(b).get_frame_texture("idle", 0).get_image()
	assert_gt(_count_diff(ia, ib), 0, "裙子款与长裤不同")

func test_shirt_style_swim_changes_render():
	# 泳衣款 (shirt_style 6) 露肚短上衣, 跟 T恤不同
	var a = _default_appearance()
	var b = _default_appearance(); b["shirt_style"] = 6
	var ia = PlayerArt.build_sprite_frames(a).get_frame_texture("idle", 0).get_image()
	var ib = PlayerArt.build_sprite_frames(b).get_frame_texture("idle", 0).get_image()
	assert_gt(_count_diff(ia, ib), 0, "泳衣款与 T恤不同")

func test_pants_style_trunks_changes_render():
	# 泳裤款 (pants_style 7) 短裤+裸腿, 跟长裤不同
	var a = _default_appearance()
	var b = _default_appearance(); b["pants_style"] = 7
	var ia = PlayerArt.build_sprite_frames(a).get_frame_texture("idle", 0).get_image()
	var ib = PlayerArt.build_sprite_frames(b).get_frame_texture("idle", 0).get_image()
	assert_gt(_count_diff(ia, ib), 0, "泳裤款与长裤不同")

func test_shoe_color_applies():
	var ap = _default_appearance(); ap["shoe_color"] = Color8(10, 200, 30)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color(img, Color8(10, 200, 30)), "鞋色出现")

func test_swim_trunks_barefoot():
	# 泳裤 (pants 7) 光脚: 不画鞋, 所以鞋色不出现
	var ap = _default_appearance(); ap["pants_style"] = 7; ap["shoe_color"] = Color8(10, 200, 30)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_false(_has_color(img, Color8(10, 200, 30)), "泳裤光脚, 鞋色不出现")

func test_unknown_style_no_crash():
	var ap = _default_appearance(); ap["shirt_style"] = 99; ap["hair_style"] = 99
	var sf = PlayerArt.build_sprite_frames(ap)
	assert_true(sf.has_animation("idle"), "未知款回退不崩")
