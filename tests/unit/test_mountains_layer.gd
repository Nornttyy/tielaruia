extends GutTest

const MountainsLayer = preload("res://scripts/world/mountains_layer.gd")


func test_ready_creates_three_parallax_layers():
	var ml = MountainsLayer.new()
	add_child_autofree(ml)
	await wait_frames(1)
	assert_eq(ml.layer_count(), 3, "应有 3 个 ParallaxLayer (远/中/近)")


func test_ready_sets_canvas_layer_below_default():
	# 远山的 layer 应 = -9 (在天空 -10 之上, 默认 0 之下)
	var ml = MountainsLayer.new()
	add_child_autofree(ml)
	await wait_frames(1)
	assert_eq(ml.layer, -9, "ParallaxBackground.layer 应 = -9")


func test_each_layer_has_sprite_with_texture():
	var ml = MountainsLayer.new()
	add_child_autofree(ml)
	await wait_frames(1)
	for child in ml.get_children():
		if child is ParallaxLayer:
			assert_eq(child.get_child_count(), 1, "每个 ParallaxLayer 应只 1 个 sprite")
			var sp = child.get_child(0)
			assert_true(sp is Sprite2D, "子节点应是 Sprite2D")
			assert_not_null(sp.texture, "Sprite 应有 texture")


func test_process_does_not_crash():
	var ml = MountainsLayer.new()
	add_child_autofree(ml)
	await wait_frames(3)
	# 跑几帧 _process 不该崩 (会调 TimeOfDay)
	pass_test("3 帧 process 没崩")
