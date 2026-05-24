extends GutTest

const LavaDripLayer = preload("res://scripts/world/lava_drip_layer.gd")


func test_ready_does_not_crash():
	var ld: LavaDripLayer = LavaDripLayer.new()
	add_child_autofree(ld)
	await wait_frames(2)
	pass_test("ready 不崩")


func test_initial_alpha_is_zero():
	var ld: LavaDripLayer = LavaDripLayer.new()
	add_child_autofree(ld)
	await wait_frames(1)
	assert_eq(ld.modulate.a, 0.0, "初始 alpha=0 (地表不可见)")


func test_spawn_one_creates_drip():
	var ld: LavaDripLayer = LavaDripLayer.new()
	add_child_autofree(ld)
	await wait_frames(1)
	ld.spawn_one_for_test()
	await wait_frames(1)
	assert_eq(ld.drip_count(), 1, "spawn 后应有 1 个 drip")
