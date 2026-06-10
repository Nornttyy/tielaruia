# 起床战争地图: 一排浮空小岛 (每人一座), 岛间留空隙 (要搭桥过去), 中央一座金岛。
# 每岛: 石平台 + 一张床 (BED+BED_RIGHT) + 记下铁生成点/商店点坐标。
# 固定布局 (不靠种子) → 各端本地生成同图 = 公平。返回 {spawns, iron_points, shop_points, gold_point}。
extends RefCounted

const TILE_SIZE := 12
const N_ISLANDS := 8
const ISLAND_HALF := 5        # 岛半宽 (总宽 11 格)
const GAP := 14               # 岛间空隙 (留给搭桥)
const FLOOR_Y := 120          # 岛面行
const SKY_CLEAR_TOP := 55     # 从这行往下清空 → 开口朝天 (有光)
const VOID_BOTTOM := 150       # 清到这行 → 岛下面是虚空 (掉下去 = 死)


static func build(world) -> Dictionary:
	if world == null or not world.has_method("_set_tile"):
		return {}
	var cm = world.get("chunk_manager")
	var wlayer = world.get("wall_layer")
	var step: int = (ISLAND_HALF * 2 + 1) + GAP
	var total: int = N_ISLANDS * step
	var left: int = -total / 2

	# 清空整片 (开口朝天 + 虚空) + 清背景墙
	for x in range(left - 6, left + total + 6):
		for y in range(SKY_CLEAR_TOP, VOID_BOTTOM):
			world._set_tile(x, y, Tiles.AIR)
			if cm != null:
				cm.set_wall(x, y, Tiles.AIR)
			if wlayer != null:
				wlayer.erase_cell(Vector2i(x, y))

	var spawns: Array = []
	var iron_points: Array = []
	var shop_points: Array = []
	for i in N_ISLANDS:
		var ix: int = left + i * step + ISLAND_HALF   # 岛中心列
		# 石平台 2 行
		for d in range(-ISLAND_HALF, ISLAND_HALF + 1):
			world._set_tile(ix + d, FLOOR_Y, Tiles.STONE)
			world._set_tile(ix + d, FLOOR_Y + 1, Tiles.STONE)
		# 床 (床头 + 床尾) 摆在平台上
		world._set_tile(ix, FLOOR_Y - 1, Tiles.BED)
		world._set_tile(ix + 1, FLOOR_Y - 1, Tiles.BED_RIGHT)
		spawns.append(Vector2(float(ix) * TILE_SIZE + TILE_SIZE * 0.5, float(FLOOR_Y - 2) * TILE_SIZE))
		iron_points.append(Vector2i(ix - 3, FLOOR_Y - 1))
		shop_points.append(Vector2i(ix + 4, FLOOR_Y - 1))

	# 中央金岛 (中点上方一点的小平台)
	var gx: int = left + total / 2
	for d in range(-3, 4):
		world._set_tile(gx + d, FLOOR_Y - 8, Tiles.STONE)
	var gold_point := Vector2i(gx, FLOOR_Y - 9)

	# 小地图开局全标记探索
	var mm = world.get("minimap_data")
	if mm != null and cm != null:
		for x in range(left - 6, left + total + 6):
			for y in range(SKY_CLEAR_TOP, FLOOR_Y + 3):
				mm.mark_one(cm, x, y)

	return {"spawns": spawns, "iron_points": iron_points, "shop_points": shop_points, "gold_point": gold_point}
