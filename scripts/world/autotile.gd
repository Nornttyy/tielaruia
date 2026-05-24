# 统一邻居 mask 计算 + TileMapLayer set_cell 的帮手.
# query 参数: Callable(x: int, y: int) -> bool, 返回邻居 (x, y) 是否"与我同族" (闭).
extends RefCounted

const BlobLookup = preload("res://scripts/world/blob_lookup.gd")
const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")


# 计算 8-bit 邻居 mask. bits: 0=N 1=E 2=S 3=W 4=NE 5=SE 6=SW 7=NW.
static func compute_mask(world_x: int, world_y: int, query: Callable) -> int:
	var m: int = 0
	if query.call(world_x,     world_y - 1): m |= 1    # N
	if query.call(world_x + 1, world_y):     m |= 2    # E
	if query.call(world_x,     world_y + 1): m |= 4    # S
	if query.call(world_x - 1, world_y):     m |= 8    # W
	if query.call(world_x + 1, world_y - 1): m |= 16   # NE
	if query.call(world_x + 1, world_y + 1): m |= 32   # SE
	if query.call(world_x - 1, world_y + 1): m |= 64   # SW
	if query.call(world_x - 1, world_y - 1): m |= 128  # NW
	return m


# 写入单格 TileMapLayer (按邻居 mask 自动算 atlas_coord).
# source_id 通常 = tile_id (TileSet 注册时 ID == tile_id).
# slope tile (GRASS/DIRT) 用 SLOPE_ATLAS_COORD, 其它用标准 ATLAS_COORD.
static func refresh_tile(layer: TileMapLayer, world_pos: Vector2i, source_id: int, query: Callable) -> void:
	var mask: int = compute_mask(world_pos.x, world_pos.y, query)
	var atlas: Vector2i
	if EdgeTemplates.is_slope_tile(source_id):
		atlas = BlobLookup.SLOPE_ATLAS_COORD[mask]
	else:
		atlas = BlobLookup.ATLAS_COORD[mask]
	layer.set_cell(world_pos, source_id, atlas)


# 重算 (world_pos) + 8 邻居共 9 格. 用于放置/破坏后让周围 atlas_coord 一起更新.
# 每个邻居各自需要查它自己的 source_id (可能是不同方块), 通过 layer.get_cell_source_id 拿到.
# 邻居若为空气 (source_id == -1) 则跳过.
# 注意: 这里假设所有邻居用同一个 query — 适用于"前景层全部走 is_solid"的场景.
# 若邻居 tile 是叶子 (需 species 查询), 调用方应单独调 refresh_tile 提供正确 query.
static func refresh_with_neighbors(layer: TileMapLayer, world_pos: Vector2i, query: Callable) -> void:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := world_pos + Vector2i(dx, dy)
			var sid: int = layer.get_cell_source_id(p)
			if sid == -1:
				continue
			refresh_tile(layer, p, sid, query)


# 创建前景层邻居查询. 按 tile_id 类型分:
# - LEAVES/LEAVES_PINE/LEAVES_AUTUMN: 只认相同 species (同种叶子才算闭)
# - 其它 (实心方块): 认任何实心方块为邻居 (Tiles.is_solid)
# 注意: 此 query 用于前景 tiles, 不用于墙层 walls.
static func make_terrain_query(tile_id: int, chunk_manager: Object) -> Callable:
	const LEAVES = 6
	const LEAVES_PINE = 11
	const LEAVES_AUTUMN = 12
	if tile_id == LEAVES or tile_id == LEAVES_PINE or tile_id == LEAVES_AUTUMN:
		return func(x: int, y: int): return chunk_manager.get_tile(x, y) == tile_id
	return func(x: int, y: int): return Tiles.is_solid(chunk_manager.get_tile(x, y))


# 创建背景墙邻居查询. 各种墙各自独立: 只认相同 wall id.
static func make_wall_query(wall_id: int, chunk_manager: Object) -> Callable:
	return func(x: int, y: int): return chunk_manager.get_wall(x, y) == wall_id
