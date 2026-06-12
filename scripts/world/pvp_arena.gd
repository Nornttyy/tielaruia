# 对战房专属竞技场: 在世界里 stamp 一座大型左右对称的竞技场.
# 固定布局 (不靠随机种子) → 每个客户端各自本地生成同一张图 = 公平 + 不用同步上万 tile.
# 关于中心列 cx 左右镜像; 地面 + 少量矮平台掩体 + 两端出生台.
# 改 (用户): 删中央石柱"墙"; 平台更少更矮 (跳得上去); 清到天上 = 永久白天全亮; 加空气墙防逃出.
extends RefCounted

const WIDTH := 300          # 总宽 (300 格)
const HALF := 150           # 半宽
const CENTER_X := 0         # 固定中心列 (各客户端同坐标 = 公平)
const FLOOR_Y := 122        # 固定地面行 (近地表)
const TILE_SIZE := 12
const SKY_CLEAR_TOP := 50   # 从这行往下全清空 → 竞技场开口朝天 (上方留natural air, 不用清)
const CEIL_TILES_ABOVE := 150       # 顶部空气墙离地面 150 格 (用户要求: 竖直空间很大)
const CEIL_Y := FLOOR_Y - CEIL_TILES_ABOVE   # 看不见的天花板行 (顶空气墙)
# 用户改: 删两侧空气墙 → 竞技场做成漂浮平台, 掉下去 = 死。
const EDGE_VOID := 30       # 平台两侧再往外清 30 格虚空 (踩出/被打出边缘 = 掉下去)
const VOID_DEPTH := 30      # 地面往下清 30 格虚空 (平台漂浮, 下面是空)
const DEATH_DROP := 18      # 掉到地面下 18 格 = 死亡线 (越过即秒杀, 见 PlayerHealth)


# 掉到这个 y (像素) 以下 = 虚空死. PlayerHealth 每帧查 (对战房才生效)。
static func death_y_px() -> float:
	return float(FLOOR_Y + DEATH_DROP) * TILE_SIZE


# 随机出生点 (沿地面随机铺开 → 各玩家/每次复活落点不同, 用户: 出生点不能一样 + 防蹲点)。
# x 在平台内随机, y 在地面上方 5 格 (落到地面/平台上)。
static func random_spawn() -> Vector2:
	var x: int = CENTER_X + randi_range(-HALF + 12, HALF - 12)
	return Vector2(float(x) * TILE_SIZE + TILE_SIZE * 0.5, float(FLOOR_Y - 5) * TILE_SIZE)

# 平台层 (相对地面高度 dy, 距中心 from..to 列). 关于中心对称. 少 + 矮 (玩家跳得上).
const _TIERS := [
	{"dy": 4, "from": 18, "to": 70},
	{"dy": 9, "from": 40, "to": 96},
]


# 在 world 盖竞技场, 中心放世界出生点. 返回出生用世界像素坐标 (左侧出生台上).
static func build(world) -> Vector2:
	if world == null or not world.has_method("_set_tile"):
		return Vector2.ZERO
	# 地基铺设期间不广播 tile (几万格): 各端各自本地铺同一张图, 只有玩家手动搭/挖才同步 (防洪水)。
	if "_arena_building" in world:
		world._arena_building = true
	var cx: int = CENTER_X
	var floor_y: int = FLOOR_Y

	# 1. 清空: 从高处 (SKY_CLEAR_TOP) 一直清到地面下 → 开口朝天 (有光) + 去掉天然山丘。
	#    顺手把背景墙也清掉 (用户要求"删背景墙" → 竞技场背景干净见天空)。
	var cm = world.get("chunk_manager")
	var wlayer = world.get("wall_layer")
	# 清得比地面宽 (两侧各多 EDGE_VOID 格) + 比地面深 (往下 VOID_DEPTH 格) → 平台两侧+下面是虚空。
	for x in range(cx - HALF - EDGE_VOID, cx + HALF + EDGE_VOID + 1):
		for y in range(SKY_CLEAR_TOP, floor_y + VOID_DEPTH + 1):
			world._set_tile(x, y, Tiles.AIR)
			if cm != null:
				cm.set_wall(x, y, Tiles.AIR)         # 清背景墙数据
			if wlayer != null:
				wlayer.erase_cell(Vector2i(x, y))    # 清背景墙视觉

	# 2. 地面: 2 行实心石, 全宽
	for x in range(cx - HALF, cx + HALF + 1):
		world._set_tile(x, floor_y, Tiles.STONE)
		world._set_tile(x, floor_y + 1, Tiles.STONE)

	# 3. 对称矮平台掩体 (木平台). 中央 ±from 内留通道. (已删中央石柱 + 中央高台)
	for t in _TIERS:
		var py: int = floor_y - int(t["dy"])
		for d in range(int(t["from"]), int(t["to"]) + 1):
			world._set_tile(cx - d, py, Tiles.WOOD_PLATFORM)
			world._set_tile(cx + d, py, Tiles.WOOD_PLATFORM)

	# 4. 两端对称出生台 (离中心远, 给弓拉开距离)
	for d in range(-3, 4):
		world._set_tile(cx - 140 + d, floor_y - 4, Tiles.WOOD_PLATFORM)
		world._set_tile(cx + 140 + d, floor_y - 4, Tiles.WOOD_PLATFORM)

	# 4.5 (用户: 删两侧空气墙) — 平台两侧敞开, 掉下去 = 死 (见步骤 1 清出的虚空 + PlayerHealth 死亡线)。

	# 5. 只剩顶部隐形天花板 (防云靴二段跳飞出顶); 两侧不再有墙, 掉下去会死。
	_build_air_walls(world, cx, floor_y)

	# 6. 小地图开局就全探索完 (用户要求): 标记竞技场地面附近一片 (天花板 150 格太高, 上面是空, 不用标)。
	var mm = world.get("minimap_data")
	if mm != null and cm != null:
		for x in range(cx - HALF, cx + HALF + 1):
			for y in range(floor_y - 40, floor_y + 2):
				mm.mark_one(cm, x, y)

	if "_arena_building" in world:
		world._arena_building = false   # 地基铺完, 之后玩家搭/挖正常广播
	# 出生点: 左侧出生台正上方
	return Vector2(float(cx - 140) * TILE_SIZE + TILE_SIZE * 0.5, float(floor_y - 5) * TILE_SIZE)


# 只剩顶部隐形天花板 (离地 CEIL_TILES_ABOVE=150 格), 防云靴二段跳飞出顶。
# 两侧不再有墙 (用户: 掉下去 = 死). collision_layer=1 (实心方块层), 隐形不挡光/视野。
static func _build_air_walls(world, cx: int, floor_y: int) -> void:
	var old = world.get_node_or_null("ArenaWalls")
	if old != null:
		old.free()   # 重进同一世界不叠加
	var body := StaticBody2D.new()
	body.name = "ArenaWalls"
	body.collision_layer = 1
	body.collision_mask = 0
	var left_px: float = float(cx - HALF) * TILE_SIZE
	var right_px: float = float(cx + HALF + 1) * TILE_SIZE
	var ceil_px: float = float(CEIL_Y) * TILE_SIZE
	var box_w: float = right_px - left_px
	var thick := 16.0
	# 顶 (隐形天花板, 离地 150 格) — 只剩这一道
	_add_wall(body, Vector2((left_px + right_px) * 0.5, ceil_px - thick * 0.5), Vector2(box_w, thick))
	world.add_child(body)


static func _add_wall(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = center
	body.add_child(cs)
