extends GutTest

const VillagePlacer = preload("res://scripts/world/village_placer.gd")
const VillagePrefab = preload("res://scripts/world/village_prefab.gd")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")


func _make_chunk_manager() -> ChunkManager:
	var cm: ChunkManager = ChunkManagerClass.new()
	add_child_autofree(cm)
	cm.setup(42)
	cm.ensure_loaded(0)
	return cm


func test_place_writes_planks_corners():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	# anchor = (30, 50). 房 1 anchor_x=5 anchor_y=-3 → 左上 (35, 47)
	var spawns = VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	# 房 1 左上 (35, 47) 应是 PLANKS (grid row 0 col 0)
	assert_eq(cm.get_tile(35, 47), Tiles.PLANKS, "房 1 左上是 planks")
	# 房 1 右下 (39, 50) 应是 PLANKS (grid row 3 col 4)
	assert_eq(cm.get_tile(39, 50), Tiles.PLANKS, "房 1 右下是 planks")


func test_place_door_at_correct_position():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	# 房 1 grid 行 3 列 0 是 "D" → 世界 (35, 50)
	assert_eq(cm.get_tile(35, 50), Tiles.DOOR, "房 1 门在左下")


func test_place_interior_not_overwritten():
	var cm = _make_chunk_manager()
	# 提前在屋内放个标记 tile (DIRT) 看看会不会被村庄覆盖
	cm.set_tile(36, 48, Tiles.DIRT)
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	# (36, 48) 在 grid row 1 col 1 = "." 应被跳过, 保留 DIRT
	assert_eq(cm.get_tile(36, 48), Tiles.DIRT, ". 不应覆盖已有 tile")


func test_place_returns_villager_spawn():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	var spawns = VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	# 房 1 有 villager_offset = [2, 3], anchor=(35, 47) → spawn (37, 50)
	assert_eq(spawns.size(), 1, "只有房 1 有村民")
	assert_eq(spawns[0], Vector2i(37, 50))


func test_two_houses_dont_overlap():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	# 房 1 左上 (35,47), 房 2 anchor_x=12 → 左上 (42,47)
	# 房 1 右边 col 4 = world x 39, 房 2 左边 col 0 = world x 42, 中间 (40,41) 空
	assert_eq(cm.get_tile(39, 47), Tiles.PLANKS, "房 1 右上角")
	assert_eq(cm.get_tile(42, 47), Tiles.PLANKS, "房 2 左上角")
