extends GutTest

const CloudLayerScene = preload("res://scenes/world/cloud_layer.tscn")


func test_cloud_layer_creates_three_parallax_layers():
	var cl = CloudLayerScene.instantiate()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_eq(cl.layer_count(), 3, "应有 3 个 ParallaxLayer")


func test_cloud_layer_has_clouds():
	var cl = CloudLayerScene.instantiate()
	add_child_autofree(cl)
	await wait_frames(1)
	# 总云数 = 6 + 5 + 4 = 15
	var total := 0
	for layer in cl.get_children():
		total += layer.get_child_count()
	assert_eq(total, 15)


func test_clouds_move_over_time():
	var cl = CloudLayerScene.instantiate()
	add_child_autofree(cl)
	await wait_frames(1)
	# 取第一朵云的 x
	var first_layer = cl.get_child(0)
	var sprite: Sprite2D = first_layer.get_child(0)
	var x0: float = sprite.position.x
	await wait_frames(30)  # 0.5s
	var x1: float = sprite.position.x
	assert_ne(x0, x1, "云应随时间移动")
