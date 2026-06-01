extends GutTest

# world_lighting: 放下锅 → 在 TorchLights 下生成一盏光 (复用 TorchFx)
func test_pot_spawns_light():
	var root := Node2D.new()
	add_child_autofree(root)
	var torch_lights := Node2D.new()
	torch_lights.name = "TorchLights"
	root.add_child(torch_lights)
	var WL = preload("res://scripts/world/world_lighting.gd")
	var wl = WL.new()
	wl.name = "WorldLighting"
	root.add_child(wl)
	await wait_frames(1)
	# 放锅 (世界坐标 5,5)
	wl.on_tile_placed(5, 5, Tiles.COOKING_POT)
	assert_eq(torch_lights.get_child_count(), 1, "锅应生成 1 盏光")
	# 拆锅 → 光消失
	wl.on_tile_removed(5, 5, Tiles.COOKING_POT)
	await wait_frames(1)
	assert_eq(torch_lights.get_child_count(), 0, "拆锅光应消失")
