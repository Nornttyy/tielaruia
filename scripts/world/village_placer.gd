# 把 VillagePrefab 盖章到 ChunkManager (+可选 TileMapLayer)。
# 写法: 通过 chunk_manager.set_tile 保存到 chunk delta (跨卸载持久),
# 同时直接写 TileMapLayer 让视觉立刻更新。
class_name VillagePlacer extends RefCounted

const VillagePrefab = preload("res://scripts/world/village_prefab.gd")


# 在 anchor 处盖章。返回需要 spawn 村民的世界坐标列表。
# 流程: (1) 清出 spawn → 所有屋顶上方一行的整片矩形 (擦树/草, 留出走路 + 头顶空间)
#       (2) 按每间屋的 grid 盖墙/门。
static func place(
		chunk_manager: ChunkManager,
		terrain_layer: TileMapLayer,
		prefab: Dictionary,
		anchor: Vector2i
) -> Array:
	var villager_spawns: Array = []
	# Pass 0: 清整片矩形 - 从 spawn 往右一直到最远屋, 高度从屋顶上方 1 行到 spawn 行
	_clear_bounding_rect(chunk_manager, terrain_layer, prefab, anchor)
	for house in prefab.houses:
		var house_anchor: Vector2i = anchor + Vector2i(house.anchor_x, house.anchor_y)
		var rows: int = house.grid.size()
		if rows == 0:
			continue
		var cols: int = (house.grid[0] as String).length()
		# Pass 1: 房子 footprint 再清一次 (其实 bounding 已覆盖, 但保险)
		for ry in range(rows):
			for cx in range(cols):
				var pos: Vector2i = house_anchor + Vector2i(cx, ry)
				chunk_manager.set_tile(pos.x, pos.y, Tiles.AIR)
		# Pass 2: 按 grid 字符 stamp 墙/门
		for ry in range(rows):
			var row: String = house.grid[ry]
			for cx in range(cols):
				var ch: String = row[cx]
				var tid: int = VillagePrefab.char_to_tile(ch)
				if tid == -1:
					continue
				var pos: Vector2i = house_anchor + Vector2i(cx, ry)
				chunk_manager.set_tile(pos.x, pos.y, tid)
				# 门: 'D' 占 3 格 (底 DOOR + 中 DOOR_MID + 顶 DOOR_TOP).
				# 玩家 2.5 格高, 门洞必须 3 格才进得去; 上 2 格盖掉原墙形成门洞.
				if tid == Tiles.DOOR:
					chunk_manager.set_tile(pos.x, pos.y - 1, Tiles.DOOR_MID)
					chunk_manager.set_tile(pos.x, pos.y - 2, Tiles.DOOR_TOP)
		if house.get("villager_offset", null) != null:
			var off = house.villager_offset
			villager_spawns.append(house_anchor + Vector2i(off[0], off[1]))
	return villager_spawns


# 算出所有屋子的 bounding box, 从 anchor (spawn 列) 起算, 清空内部 (扣掉树/草)。
# 让玩家从 spawn 能直接走到村子。
static func _clear_bounding_rect(
		chunk_manager: ChunkManager,
		terrain_layer: TileMapLayer,
		prefab: Dictionary,
		anchor: Vector2i
) -> void:
	var min_x: int = 0   # 从 anchor (spawn) 起算, 包含 spawn 列
	var max_x: int = 0
	var min_y: int = 0
	for house in prefab.houses:
		var rows: int = house.grid.size()
		if rows == 0:
			continue
		var cols: int = (house.grid[0] as String).length()
		max_x = max(max_x, house.anchor_x + cols - 1)
		min_y = min(min_y, house.anchor_y)
	# y 范围: min_y - 4 (向上多 4 行清树顶/叶) 到 0 (= anchor.y = spawn 行)
	for dy in range(min_y - 4, 1):
		for dx in range(min_x, max_x + 1):
			var pos: Vector2i = anchor + Vector2i(dx, dy)
			chunk_manager.set_tile(pos.x, pos.y, Tiles.AIR)
