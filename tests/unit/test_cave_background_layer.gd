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
	assert_almost_eq(cl.current_alpha(), 0.7, 0.01, "set_layer_alpha 应改 _layer_alpha")


func test_process_does_not_crash():
	var cl = CaveBackgroundLayer.new()
	add_child_autofree(cl)
	await wait_frames(3)
	pass_test("3 帧 process 不崩")
