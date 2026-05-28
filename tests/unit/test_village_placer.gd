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


# 在世界放下 prefab 后, 找一间屋扫一下: 应至少有门 + 若干 PLANKS/STONE.
# 屋型升级带尖顶/烟囱后, 第 0 间不再是规则矩形, 不能硬编角点坐标 → 改成 "有门 + 有墙 + 室内清空" 的语义检查.

const ANCHOR := Vector2i(30, 50)


# 任何 prefab 至少有一间屋, 放下后世界里应至少有 1 个门
func test_place_writes_at_least_one_door():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, ANCHOR)
	var door_count := 0
	for wx in range(ANCHOR.x, ANCHOR.x + 80):
		for wy in range(ANCHOR.y - 12, ANCHOR.y + 1):
			if cm.get_tile(wx, wy) == Tiles.DOOR:
				door_count += 1
	assert_gt(door_count, 0, "村里至少 1 扇门")


# 至少有若干 PLANKS 砖被写 (墙体)
func test_place_writes_planks_walls():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	VillagePlacer.place(cm, null, prefab, ANCHOR)
	var plank_count := 0
	for wx in range(ANCHOR.x, ANCHOR.x + 80):
		for wy in range(ANCHOR.y - 12, ANCHOR.y + 1):
			if cm.get_tile(wx, wy) == Tiles.PLANKS:
				plank_count += 1
	assert_gt(plank_count, 10, "应至少有 10 个 PLANKS 墙体")


# 室内空气检查: 第一间屋 anchor 内部应被清空成 AIR.
# 把 prefab 第 0 间屋读出来, 找一个 "." 格子, 在该位置预放 DIRT, place 后应是 AIR.
func test_place_clears_interior_to_air():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	var h0: Dictionary = prefab.houses[0]
	var grid: Array = h0.grid
	# 找第一个 "." 位置
	var dot_row: int = -1
	var dot_col: int = -1
	for r in grid.size():
		var row_str: String = grid[r]
		for c in row_str.length():
			if row_str[c] == ".":
				dot_row = r
				dot_col = c
				break
		if dot_row != -1:
			break
	assert_ne(dot_row, -1, "第 0 间屋应至少有 1 个 '.'")
	var wx: int = ANCHOR.x + int(h0.anchor_x) + dot_col
	var wy: int = ANCHOR.y + int(h0.anchor_y) + dot_row
	cm.set_tile(wx, wy, Tiles.DIRT)
	VillagePlacer.place(cm, null, prefab, ANCHOR)
	assert_eq(cm.get_tile(wx, wy), Tiles.AIR, "室内 '.' 位置应被清成空气")


func test_place_returns_villager_spawn():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	var spawns = VillagePlacer.place(cm, null, prefab, ANCHOR)
	assert_gt(spawns.size(), 0, "至少 1 个村民 spawn")


# 第一间屋的门确实放在 grid 里 "D" 字符对应的世界坐标
func test_first_house_door_at_grid_position():
	var cm = _make_chunk_manager()
	var prefab = VillagePrefab.load_default()
	var h0: Dictionary = prefab.houses[0]
	var grid: Array = h0.grid
	var d_row: int = -1
	var d_col: int = -1
	for r in grid.size():
		var row_str: String = grid[r]
		var col := row_str.find("D")
		if col != -1:
			d_row = r
			d_col = col
			break
	assert_ne(d_row, -1, "第 0 间屋应至少 1 扇门")
	VillagePlacer.place(cm, null, prefab, ANCHOR)
	var wx: int = ANCHOR.x + int(h0.anchor_x) + d_col
	var wy: int = ANCHOR.y + int(h0.anchor_y) + d_row
	assert_eq(cm.get_tile(wx, wy), Tiles.DOOR, "第 0 间屋门位应是 DOOR")
