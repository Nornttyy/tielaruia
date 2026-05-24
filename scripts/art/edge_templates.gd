# scripts/art/edge_templates.gd
# 5 族 × 47 边缘模板. 每模板 16×16, 字符语义:
#   .  透明 (显示下面的内部纹理)
#   o  外描边 (outline, 最暗)
#   e  边缘暗影 (edge shadow)
#   h  边缘高光 (edge highlight)
#   H  强高光 (顶部/光照面)
# 调色时按方块自己的 _P_xxx 调色板的 _o/_e/_h/_H 槽位染色.
#
# 模板由 `_compose(style, variant_key)` 用每族风格 dict 生成. 风格 dict 里的字符串
# 都是手画的 (每族独家): 顶/底边各 2 行 (16 字符), 左/右边各 2 列 (12 字符高), 外凸
# 圆角削角点数, 内凹 L 形像素列表. 这样 5 族 × 47 = 235 个变体来自 5 个风格 dict.
extends RefCounted

const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


# tile_id → 边缘族名
const FAMILY_OF: Dictionary = {
	BlocksArt.GRASS: "soil",
	BlocksArt.DIRT: "soil",
	BlocksArt.SAND: "soil",
	BlocksArt.STONE: "rock",
	BlocksArt.DEEP_STONE: "rock",
	BlocksArt.BEDROCK: "rock",
	BlocksArt.COAL_ORE: "rock",
	BlocksArt.IRON_ORE: "rock",
	BlocksArt.PLANKS: "wood",
	BlocksArt.LEAVES: "leaf",
	BlocksArt.LEAVES_PINE: "leaf",
	BlocksArt.LEAVES_AUTUMN: "leaf",
	BlocksArt.GRASS_WALL: "wall",
	BlocksArt.DIRT_WALL: "wall",
	BlocksArt.STONE_WALL: "wall",
}


# ─────────────────────────────────────────────────────────────────────────────
# 各族风格 dict (T10-T14 逐族填). 未填的族用 _BLANK_STYLE 占位 (生成全透明 47 模板).
# ─────────────────────────────────────────────────────────────────────────────

# 占位: 全透明 (视觉等同 T2 的 blank 状态)
const _BLANK_STYLE := {
	"top_row0":    "................",
	"top_row1":    "................",
	"bot_row14":   "................",
	"bot_row15":   "................",
	"left_col0":   "............",
	"left_col1":   "............",
	"right_col14": "............",
	"right_col15": "............",
	"corner_round": 0,
	"concave": [],
}

# 石族 (T10): 硬朗描边 + 顶满高光 + 1px 小圆角 + 2px L 形内凹阴影
# 设计意图: 顶部 1 行强 H + 1 行 e 过渡 (光从上来), 其它 3 边各 1px o + 1px e,
# 外凸角削 1 像素 (方正石头感), 内凹角画 3 像素 L (e) 强调岩石断面.
const _ROCK_STYLE := {
	"top_row0":    "HHHHHHHHHHHHHHHH",
	"top_row1":    "eeeeeeeeeeeeeeee",
	"bot_row14":   "eeeeeeeeeeeeeeee",
	"bot_row15":   "oooooooooooooooo",
	"left_col0":   "oooooooooooo",
	"left_col1":   "eeeeeeeeeeee",
	"right_col14": "eeeeeeeeeeee",
	"right_col15": "oooooooooooo",
	"corner_round": 1,
	"concave": [[0, 0, "e"], [1, 0, "e"], [0, 1, "e"]],
}

# 土族 (T11): 碎描边 + 暖顶高光 + 2px 大圆角 + 单点内凹 + "颗粒掉落感"
# 设计意图: 顶部 H 主调中夹 e 凹坑 (拟泥块凹凸), 底/左/右边 1px o 描边 +
# 1px 内侧偶发 e 颗粒. 外凸角削 2px (土质柔软). 内凹角仅 1px e (土的断面糊一点).
const _SOIL_STYLE := {
	"top_row0":    "HHeHHHeHHHHeHHHe",
	"top_row1":    "eeeeeHeeeeeHeeee",
	"bot_row14":   "eeeeeeeeeeeeeeee",
	"bot_row15":   "oeoooeooooeooooo",
	"left_col0":   "oooeoooooeoo",
	"left_col1":   "............",
	"right_col14": "............",
	"right_col15": "ooeoooooeooo",
	"corner_round": 2,
	"concave": [[0, 0, "e"]],
}

# 叶族 (T12): 簇状描边 + 啃咬圆角 + 大量透明缝隙 (叶子轮廓不规则感)
# 设计意图: 顶部 h 高光 (温和), 不规则间隔有 "." 让内部叶纹路透出来.
# 侧边/底边同样断断续续. 外凸角削 2px + 锯齿. 内凹角仅 1px 暗 (叶面薄).
const _LEAF_STYLE := {
	"top_row0":    "hh.hh.hh.hh.hhh.",
	"top_row1":    "h.h..hh..h.hh.h.",
	"bot_row14":   ".h.h.h.hh.h.hh..",
	"bot_row15":   "h.hh..h.h.hh.h.h",
	"left_col0":   "h.hh.h.hh.h.",
	"left_col1":   "............",
	"right_col14": "............",
	"right_col15": "hh.h.hh.h.h.",
	"corner_round": 2,
	"concave": [[0, 0, "e"]],
}


# ─────────────────────────────────────────────────────────────────────────────
# 5 族模板字典. TEMPLATES[family][variant_key] = Array[String] 16 行 × 16 字符.
# ─────────────────────────────────────────────────────────────────────────────

static var TEMPLATES: Dictionary = _build_all_templates()


static func _build_all_templates() -> Dictionary:
	return {
		"rock": _build_family(_ROCK_STYLE),
		"soil": _build_family(_SOIL_STYLE),
		"leaf": _build_family(_LEAF_STYLE),
		"wall": _build_family(_BLANK_STYLE),
		"wood": _build_family(_BLANK_STYLE),
	}


static func _build_family(style: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for vk in BlobLookup.VARIANT_KEYS:
		result[vk] = _compose(style, vk)
	return result


# 按 variant_key (8 字符: 4 边 + 4 角) 组合 style 里的边缘片段 → 16×16 ASCII 网格.
# 规则:
#   - N/E/S/W 边 (key[0..3] == "O") 开时画对应 2 行/2 列边缘
#   - 两相邻边都开时削外凸角 (corner_round 像素)
#   - 角字符为 "X" 时画内凹 L (对角邻居缺时的内角阴影)
#   - 角字符为 "I" 或 "." 时不画 (interior 无需; 边开时已被边覆盖)
static func _compose(style: Dictionary, key: String) -> Array:
	# 初始全 "." 网格
	var grid: Array = []
	for _y in 16:
		var row: Array = []
		for _x in 16:
			row.append(".")
		grid.append(row)

	var n_open: bool = key.substr(0, 1) == "O"
	var e_open: bool = key.substr(1, 1) == "O"
	var s_open: bool = key.substr(2, 1) == "O"
	var w_open: bool = key.substr(3, 1) == "O"

	# 顶边 (rows 0, 1)
	if n_open:
		for x in 16:
			grid[0][x] = style.top_row0.substr(x, 1)
			grid[1][x] = style.top_row1.substr(x, 1)
	# 底边 (rows 14, 15)
	if s_open:
		for x in 16:
			grid[14][x] = style.bot_row14.substr(x, 1)
			grid[15][x] = style.bot_row15.substr(x, 1)
	# 左边 (cols 0, 1, rows 2..13)
	if w_open:
		for i in 12:
			grid[i + 2][0] = style.left_col0.substr(i, 1)
			grid[i + 2][1] = style.left_col1.substr(i, 1)
	# 右边 (cols 14, 15, rows 2..13)
	if e_open:
		for i in 12:
			grid[i + 2][14] = style.right_col14.substr(i, 1)
			grid[i + 2][15] = style.right_col15.substr(i, 1)

	# 外凸圆角: 两相邻边都开时, 削掉 r×r 角像素
	var r: int = style.corner_round
	if r > 0:
		if n_open and w_open:
			for dy in r:
				for dx in r:
					grid[dy][dx] = "."
		if n_open and e_open:
			for dy in r:
				for dx in r:
					grid[dy][15 - dx] = "."
		if s_open and w_open:
			for dy in r:
				for dx in r:
					grid[15 - dy][dx] = "."
		if s_open and e_open:
			for dy in r:
				for dx in r:
					grid[15 - dy][15 - dx] = "."

	# 内凹角. key[4..7] = NE/SE/SW/NW 角状态.
	# "X" = 两相邻边闭但对角邻居缺 → 画 L 形阴影像素
	var concave: Array = style.concave
	if key.substr(4, 1) == "X":  # NE
		for pt in concave:
			grid[pt[1]][15 - pt[0]] = pt[2]
	if key.substr(5, 1) == "X":  # SE
		for pt in concave:
			grid[15 - pt[1]][15 - pt[0]] = pt[2]
	if key.substr(6, 1) == "X":  # SW
		for pt in concave:
			grid[15 - pt[1]][pt[0]] = pt[2]
	if key.substr(7, 1) == "X":  # NW
		for pt in concave:
			grid[pt[1]][pt[0]] = pt[2]

	# Array[Array[String]] → Array[String]
	var result: Array = []
	for row in grid:
		result.append("".join(row))
	return result
