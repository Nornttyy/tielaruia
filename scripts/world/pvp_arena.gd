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

	# 1. 清空: 从高处 (SKY_CLEAR_TOP) 一直清到地面下 → 开口朝天 (有光) + 去掉天然山丘
	for x in range(cx - HALF, cx + HALF + 1):
		for y in range(SKY_CLEAR_TOP, floor_y + 3):
			world._set_tile(x, y, Tiles.AIR)

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

	# 5. 空气墙 (看不见的碰撞墙): 左/右/顶 关住玩家, 防搭方块逃出竞技场
	_build_air_walls(world, cx, floor_y)

	# 出生点: 左侧出生台正上方
	return Vector2(float(cx - 140) * TILE_SIZE + TILE_SIZE * 0.5, float(floor_y - 5) * TILE_SIZE)


# 看不见的碰撞墙: 一个 StaticBody2D, 3 块矩形 (左墙/右墙/天花板). collision_layer=1
# (bit0 实心方块层); 玩家 collision_mask 含 bit0 → 挡得住, 但不画出来 = 空气墙.
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
	var bot_px: float = float(floor_y + 2) * TILE_SIZE
	var box_h: float = bot_px - ceil_px
	var box_w: float = right_px - left_px
	var thick := 16.0
	_add_wall(body, Vector2(left_px - thick * 0.5, (ceil_px + bot_px) * 0.5), Vector2(thick, box_h))      # 左
	_add_wall(body, Vector2(right_px + thick * 0.5, (ceil_px + bot_px) * 0.5), Vector2(thick, box_h))     # 右
	_add_wall(body, Vector2((left_px + right_px) * 0.5, ceil_px - thick * 0.5), Vector2(box_w, thick))    # 顶
	world.add_child(body)


static func _add_wall(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = center
	body.add_child(cs)
