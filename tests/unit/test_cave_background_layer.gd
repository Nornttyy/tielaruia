extends GutTest

const CaveBackgroundLayer = preload("res://scripts/world/cave_background_layer.gd")


func test_original_backgrounds_keep_tile_size_instead_of_screen_stretch():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_eq(cl._texture(2).get_size(), Vector2(128, 96))
	assert_eq(cl._texture(33).get_size(), Vector2(128, 96), "160px 原图的重复尾部不应产生接缝")
	assert_ne(cl._texture(2).get_image().get_data(), cl._texture(33).get_image().get_data(), "雪地使用自己的地下原片")

func test_biome_fade_reaches_new_texture_without_restarting_on_every_update():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	cl.set_biome(2)
	for i in 20:
		cl.set_biome(2)
		cl._process(0.05)
	assert_eq(cl._weights, {2: 1.0})
	for style in cl.STYLES.values():
		for i in style.size():
			assert_not_null(cl._texture(style[i]))
			assert_eq(cl._texture(style[i]).get_height(), 16 if i % 2 == 0 else 96, "过渡边与平铺正文不能混用")


func test_initial_alpha_is_zero():
	# 地表时矿洞背景应不可见 (用 set_layer_alpha 接口, 因为 ParallaxBackground 没 modulate)
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_eq(cl.current_alpha(), 0.0, "初始 _layer_alpha 应 = 0 (地表不见)")


func test_set_layer_alpha_propagates():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	cl.set_layer_alpha(0.7)
	assert_almost_eq(cl.current_alpha(), 0.7, 0.01, "set_layer_alpha 应改 _shallow_alpha")
	assert_almost_eq(cl.deep_alpha(), 0.7, 0.01, "单 alpha 接口同步给 deep_alpha")


func test_set_depth_alphas_split():
	# 双 alpha 接口: 浅 0.6 + 深 0 (浅石头层只露岩壁不露钟乳石)
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	cl.set_depth_alphas(0.6, 0.0)
	assert_almost_eq(cl.shallow_alpha(), 0.6, 0.01)
	assert_eq(cl.deep_alpha(), 0.0)


func test_process_does_not_crash():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(3)
	pass_test("3 帧 process 不崩")
