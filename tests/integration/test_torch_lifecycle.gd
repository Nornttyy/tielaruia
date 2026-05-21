extends GutTest

const WorldLighting = preload("res://scripts/world/world_lighting.gd")


# 测试 helper: 构造 World-like 父节点 + TorchLights sibling + WorldLighting
func _make_scene() -> Dictionary:
	var root := Node2D.new()
	add_child_autofree(root)
	var torch_lights := Node2D.new()
	torch_lights.name = "TorchLights"
	root.add_child(torch_lights)
	var wl = WorldLighting.new()
	wl.name = "WorldLighting"
	root.add_child(wl)
	return {"root": root, "torch_lights": torch_lights, "wl": wl}


func test_spawn_torch_creates_light() -> void:
	var s = _make_scene()
	s.wl.on_tile_placed(5, 10, Tiles.TORCH)
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 1, "应有 1 个火把光")


func test_despawn_torch_removes_light() -> void:
	var s = _make_scene()
	s.wl.on_tile_placed(3, 7, Tiles.TORCH)
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 1, "先有 1 个")
	s.wl.on_tile_removed(3, 7, Tiles.TORCH)
	await get_tree().process_frame
	await get_tree().process_frame  # queue_free 需要一帧
	assert_eq(s.torch_lights.get_child_count(), 0, "光应被 free")


func test_non_torch_tile_ignored() -> void:
	var s = _make_scene()
	s.wl.on_tile_placed(1, 1, Tiles.STONE)
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 0, "非 TORCH tile 不应建光")


func test_spawn_is_idempotent() -> void:
	var s = _make_scene()
	s.wl.on_tile_placed(5, 5, Tiles.TORCH)
	s.wl.on_tile_placed(5, 5, Tiles.TORCH)  # 重复
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 1, "幂等: 同坐标重复 spawn 只生成 1 个")


func test_chunk_unload_clears_torches_in_range() -> void:
	var s = _make_scene()
	# 在 chunk 0 (x=0..63) 内放 2 个, chunk 1 (x=64..127) 内放 1 个
	s.wl.on_tile_placed(10, 50, Tiles.TORCH)
	s.wl.on_tile_placed(40, 60, Tiles.TORCH)
	s.wl.on_tile_placed(80, 50, Tiles.TORCH)
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 3, "总共 3 个")
	# 卸载 chunk 0
	s.wl.on_chunk_unloaded(0, 64)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 1, "只剩 chunk 1 的 1 个")


func test_chunk_load_rebuilds_torches() -> void:
	var s = _make_scene()
	# 模拟 chunk 数据: 64 列 × 100 行, 在 (5, 50) 和 (20, 30) 是 TORCH, 其余 AIR
	var tiles: Array = []
	for lx in 64:
		var col: Array = []
		for y in 100:
			col.append(Tiles.AIR)
		tiles.append(col)
	tiles[5][50] = Tiles.TORCH
	tiles[20][30] = Tiles.TORCH
	s.wl.on_chunk_loaded(0, 64, tiles)
	await get_tree().process_frame
	assert_eq(s.torch_lights.get_child_count(), 2, "应重建 2 个火把光")
