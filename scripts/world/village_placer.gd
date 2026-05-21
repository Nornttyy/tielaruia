# 把 VillagePrefab 盖章到 ChunkManager (+可选 TileMapLayer)。
# 写法: 通过 chunk_manager.set_tile 保存到 chunk delta (跨卸载持久),
# 同时直接写 TileMapLayer 让视觉立刻更新。
class_name VillagePlacer extends RefCounted

const VillagePrefab = preload("res://scripts/world/village_prefab.gd")


# 在 anchor 处盖章。返回需要 spawn 村民的世界坐标列表。
static func place(
		chunk_manager: ChunkManager,
		terrain_layer: TileMapLayer,
		prefab: Dictionary,
		anchor: Vector2i
) -> Array:
	var villager_spawns: Array = []
	for house in prefab.houses:
		var house_anchor: Vector2i = anchor + Vector2i(house.anchor_x, house.anchor_y)
		for row_idx in range(house.grid.size()):
			var row: String = house.grid[row_idx]
			for col_idx in range(row.length()):
				var ch: String = row[col_idx]
				var tid: int = VillagePrefab.char_to_tile(ch)
				if tid == -1:
					continue
				var pos: Vector2i = house_anchor + Vector2i(col_idx, row_idx)
				chunk_manager.set_tile(pos.x, pos.y, tid)
				if terrain_layer != null:
					terrain_layer.set_cell(pos, tid, Vector2i.ZERO)
		if house.get("villager_offset", null) != null:
			var off = house.villager_offset
			villager_spawns.append(house_anchor + Vector2i(off[0], off[1]))
	return villager_spawns
