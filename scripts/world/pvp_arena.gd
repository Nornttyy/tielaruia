# 对战房专属竞技场: 在世界里 stamp 一座大型左右对称的竞技场 (300 宽 × 35 高).
# 固定布局 (不靠随机种子) → 每个客户端各自本地生成同一张图 = 公平 + 不用同步上万 tile.
# 关于中心列 cx 左右镜像; 地面+对称平台掩体+中央高台+两端出生台.
# 天然地形 / 竞技场地形都不在 chunk_manager._pvp_placed 里 → 对战房挖不动; 只有玩家放的能挖.
extends RefCounted

const WIDTH := 300          # 总宽 (用户要求"做大点": 300 格)
const HEIGHT := 35          # 总高
const HALF := 150           # 半宽 (WIDTH / 2)
const CENTER_X := 0         # 固定中心列 (=spawn 所在 chunk 0 附近; 固定 → 各客户端同坐标 = 公平)
const FLOOR_Y := 122        # 固定地面行 (近地表; 清带后建地面, 不依赖天然地形)
const TILE_SIZE := 12       # 格子像素 (跟全项目一致)

# 平台层 (相对地面的高度 dy, 距中心 from..to 列). 每层关于中心对称.
const _TIERS := [
	{"dy": 6,  "from": 18, "to": 70},
	{"dy": 12, "from": 44, "to": 96},
	{"dy": 18, "from": 14, "to": 52},
	{"dy": 24, "from": 60, "to": 104},
	{"dy": 30, "from": 30, "to": 74},
]

# 在 world 里盖竞技场, 中心放在世界出生点 (那附近区块已加载). 返回出生用世界像素坐标 (左侧出生台上).
static func build(world) -> Vector2:
	if world == null or not world.has_method("_set_tile"):
		return Vector2.ZERO
	var cx: int = CENTER_X        # 竞技场中心列 (固定, 多人各端一致)
	var floor_y: int = FLOOR_Y    # 地面行 (固定)
	var top_y: int = floor_y - (HEIGHT - 1)

	# 1. 清空竞技场竖带 → 空气 (去掉天然山丘, 露出干净竞技场)
	for x in range(cx - HALF, cx + HALF + 1):
		for y in range(top_y, floor_y + 3):
			world._set_tile(x, y, Tiles.AIR)

	# 2. 地面: 2 行实心石 (脚下 + 下面一行), 全宽
	for x in range(cx - HALF, cx + HALF + 1):
		world._set_tile(x, floor_y, Tiles.STONE)
		world._set_tile(x, floor_y + 1, Tiles.STONE)

	# 3. 对称平台掩体 (木平台, 关于中心镜像). 中央 ±from 内留空当通道.
	for t in _TIERS:
		var py: int = floor_y - int(t["dy"])
		for d in range(int(t["from"]), int(t["to"]) + 1):
			world._set_tile(cx - d, py, Tiles.WOOD_PLATFORM)
			world._set_tile(cx + d, py, Tiles.WOOD_PLATFORM)

	# 4. 中央高台: 一根石柱 + 顶部小平台
	for y in range(floor_y - 22, floor_y):
		world._set_tile(cx, y, Tiles.STONE)
	for d in range(-4, 5):
		world._set_tile(cx + d, floor_y - 22, Tiles.WOOD_PLATFORM)

	# 5. 两端对称出生台 (离中心远, 给弓拉开距离)
	for d in range(-3, 4):
		world._set_tile(cx - 140 + d, floor_y - 4, Tiles.WOOD_PLATFORM)
		world._set_tile(cx + 140 + d, floor_y - 4, Tiles.WOOD_PLATFORM)

	# 出生点: 左侧出生台正上方
	return Vector2(float(cx - 140) * TILE_SIZE + TILE_SIZE * 0.5, float(floor_y - 5) * TILE_SIZE)
