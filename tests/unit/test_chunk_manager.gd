extends GutTest

const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
var cm: ChunkManager


func before_each():
	cm = ChunkManagerClass.new()
	add_child_autofree(cm)
	cm.setup(42)


func test_ensure_loaded_around_zero_loads_5_chunks():
	# VIEW_RADIUS = 2, 加载 -2..2 共 5 个
	cm.ensure_loaded(0)
	assert_eq(cm.loaded_chunk_count(), 5)
	for cx in [-2, -1, 0, 1, 2]:
		assert_true(cm.is_chunk_loaded(cx), "chunk %d 应加载" % cx)


func test_ensure_loaded_idempotent():
	cm.ensure_loaded(0)
	cm.ensure_loaded(0)
	assert_eq(cm.loaded_chunk_count(), 5)


func test_unload_far_from_keeps_only_close():
	cm.ensure_loaded(0)
	# 移动到 chunk 5, 卸载 keep_radius=2 外的
	cm.ensure_loaded(5)   # 3..7 加载
	cm.unload_far_from(5, 2)   # 保留 3..7, 卸载 -2..2
	assert_eq(cm.loaded_chunk_count(), 5)
	for cx in [3, 4, 5, 6, 7]:
		assert_true(cm.is_chunk_loaded(cx))
	for cx in [-2, -1, 0, 1, 2]:
		assert_false(cm.is_chunk_loaded(cx))


func test_get_tile_unloaded_returns_air():
	# chunk 100 未加载
	assert_eq(cm.get_tile(100 * 64, 50), Tiles.AIR)


func test_get_tile_loaded_returns_generated():
	cm.ensure_loaded(0)
	# 任意 chunk 0 的某 y 不该全是 AIR
	var found_solid: bool = false
	for x in 64:
		for y in 256:
			if cm.get_tile(x, y) != Tiles.AIR:
				found_solid = true
				break
		if found_solid:
			break
	assert_true(found_solid, "chunk 0 应该有非空气 tile")


func test_set_tile_writes_to_delta():
	cm.ensure_loaded(0)
	cm.set_tile(10, 100, Tiles.STONE)
	assert_eq(cm.get_tile(10, 100), Tiles.STONE)


func test_delta_persists_across_unload_reload():
	cm.ensure_loaded(0)
	cm.set_tile(10, 100, Tiles.STONE)
	# 卸载 chunk 0
	cm.unload_far_from(10, 2)   # 卸 -2..2
	assert_false(cm.is_chunk_loaded(0))
	# 加载回来
	cm.ensure_loaded(0)
	assert_eq(cm.get_tile(10, 100), Tiles.STONE, "delta 应在 reload 后恢复")


func test_chunk_loaded_signal_emits():
	var loaded: Array = []
	cm.chunk_loaded.connect(func(c: Chunk): loaded.append(c.chunk_x))
	cm.ensure_loaded(0)
	assert_eq(loaded.size(), 5)
	for cx in [-2, -1, 0, 1, 2]:
		assert_true(cx in loaded)


func test_chunk_unloaded_signal_emits():
	cm.ensure_loaded(0)
	var unloaded: Array = []
	cm.chunk_unloaded.connect(func(cx: int): unloaded.append(cx))
	cm.unload_far_from(5, 2)   # 卸 -2..2 = 5 个
	assert_eq(unloaded.size(), 5)
