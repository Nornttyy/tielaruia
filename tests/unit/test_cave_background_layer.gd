extends GutTest

const CaveBackgroundLayer = preload("res://scripts/world/cave_background_layer.gd")


func test_ready_creates_three_parallax_layers():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_eq(cl.layer_count(), 3, "应有 3 个 ParallaxLayer (远岩壁/钟乳石/水晶)")


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


# 群系色调: set_biome_tint 给所有岩壁/钟乳石/水晶精灵设 RGB (a 不动). 地下也按群系变.
func test_set_biome_tint_colors_sprites():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	cl.set_layer_alpha(1.0)   # 让精灵 a=1, 方便看 rgb
	cl.set_biome_tint(Color(0.5, 1.0, 1.4))   # 偏冰蓝 (雪原下)
	await wait_frames(1)
	var sp = cl._rock_sprites[0]
	assert_almost_eq(sp.modulate.r, 0.5, 0.01, "tint 把 R 压到 0.5")
	assert_almost_eq(sp.modulate.b, 1.4, 0.01, "tint 把 B 提到 1.4 (偏蓝)")
	assert_almost_eq(sp.modulate.a, 1.0, 0.01, "alpha 不被 tint 改")
