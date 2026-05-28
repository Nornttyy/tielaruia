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


func test_place_clears_interior_to_air():
	var cm = _make_chunk_manager()
	# 提前在屋内放个 DIRT 模拟树/草, 应被清空
	cm.set_tile(36, 48, Tiles.DIRT)
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	# (36, 48) 在 grid row 1 col 1 = ".", 两遍式应把它清成 AIR
	assert_eq(cm.get_tile(36, 48), Tiles.AIR, "屋内 . 位应清成空气")


func test_place_returns_villager_spawn():
	# 用户扩了村庄到 5 间, 至少 1 个 villager spawn (起步小屋必有)
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	var spawns = VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	assert_gt(spawns.size(), 0, "至少 1 个村民 spawn")


func test_first_house_walls_placed():
	# 起步小屋 anchor_x=5, anchor=(30, 50) → 左上 (35, 47)
	# 起步房左上仍然是 PLANKS (角)
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, Vector2i(30, 50))
	assert_eq(cm.get_tile(35, 47), Tiles.PLANKS, "起步小屋左上角 PLANKS")
