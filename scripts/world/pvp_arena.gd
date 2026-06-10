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
const SKY_CLEAR_TOP := 50   # 从这行往下全清空 → 竞技场开口朝天, 配永久白天 = 全亮 (治"黑漆漆")
const CEIL_Y := FLOOR_Y - 26   # 看不见的天花板行 (空气墙顶; 上面留开口进光)

# 平台层 (相对地面高度 dy, 距中心 from..to 列). 关于中心对称. 少 + 矮 (玩家跳得上).
const _TIERS := [
	{"dy": 4, "from": 18, "to": 70},
	{"dy": 9, "from": 40, "to": 96},
]


# 在 world 盖竞技场, 中心放世界出生点. 返回出生用世界像素坐标 (左侧出生台上).
static func build(world) -> Vector2:
	if world == null or not world.has_method("_set_tile"):
		return Vector2.ZERO
	var cx: int = CENTER_X
	var floor_y: int = FLOOR_Y

	# 1. 清空: 从高处 (SKY_CLEAR_TOP) 一直清到地面下 → 开口朝天 (有光) + 去掉天然山丘。
	#    顺手把背景墙也清掉 (用户要求"删背景墙" → 竞技场背景干净见天空)。
	var cm = world.get("chunk_manager")
	var wlayer = world.get("wall_layer")
	for x in range(cx - HALF, cx + HALF + 1):
		for y in range(SKY_CLEAR_TOP, floor_y + 3):
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

	# 4.5 左右两面砌实心石墙 (用户: 空气墙换成真方块; 顶那道保留隐形). 2 格厚, 从地面升到天花板高度,
	#     看得见 + 挡住玩家. 顶上故意不砌实心 → 留隐形天花板, 光照样从上面开口透进来 (不挡光)。
	for dx in range(0, 2):
		var lx: int = cx - HALF + dx          # 左墙 2 列 (最外 + 内一格)
		var rx: int = cx + HALF - dx          # 右墙 2 列
		for y in range(CEIL_Y, floor_y):      # 天花板高度 → 地面上方一格 (地面行本身已是石)
			world._set_tile(lx, y, Tiles.STONE)
			world._set_tile(rx, y, Tiles.STONE)

	# 5. 隐形天花板 (看不见的碰撞顶): 只关顶, 防玩家从上面逃出 (左右已是实心石墙)
	_build_air_walls(world, cx, floor_y)

	# 6. 小地图开局就全探索完 (用户要求): 把竞技场整片标记成已探索, 不用走过去才显。
	var mm = world.get("minimap_data")
	if mm != null and cm != null:
		for x in range(cx - HALF, cx + HALF + 1):
			for y in range(CEIL_Y - 2, floor_y + 2):
				mm.mark_one(cm, x, y)

	# 出生点: 左侧出生台正上方
	return Vector2(float(cx - 140) * TILE_SIZE + TILE_SIZE * 0.5, float(floor_y - 5) * TILE_SIZE)


# 看不见的天花板: 一个 StaticBody2D, 只 1 块顶部矩形 (左右墙已换成实心石方块, 见 build 步骤 4.5).
# collision_layer=1 (bit0 实心方块层); 玩家 mask 含 bit0 → 顶挡得住但不画出来 = 隐形顶, 不挡光.
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
	_add_wall(body, Vector2((left_px + right_px) * 0.5, ceil_px - thick * 0.5), Vector2(box_w, thick))    # 顶 (隐形)
	world.add_child(body)


static func _add_wall(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = center
	body.add_child(cs)
