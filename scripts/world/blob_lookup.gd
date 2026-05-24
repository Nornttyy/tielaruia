# 8-bit 邻居 mask → variant key → atlas 坐标.
# 用于 Terraria 风格自动连接 (blob autotiling).
#
# Mask bit 编号 (LSB 起):
#   0=N, 1=E, 2=S, 3=W, 4=NE, 5=SE, 6=SW, 7=NW
#
# 两套 key 编码 + 两套 atlas 查表:
#   1) 标准 47-blob (用于石/叶/木/墙族): 8 字符 key, atlas 8×6
#   2) Slope-aware 82-blob (用于草+土"slope tile"): 12 字符 key, atlas 12×7
#      多出来的 4 字符是 4 角的 slope 状态 (两相邻边都开 + 对角邻居在 → "P" peninsula).
extends RefCounted


# ─── 标准 47-blob ────────────────────────────────────────────────────────

# 47 唯一 key, 按 (闭边数, 字典序) 排. atlas 索引 = 数组下标.
static var VARIANT_KEYS: Array[String] = _enumerate_keys()

# 256 项: mask → atlas Vector2i (col 0..7, row 0..5).
static var ATLAS_COORD: Array[Vector2i] = _build_atlas_coord()


# 标准 key. 8 字符: chars 0-3 = N/E/S/W (O 开 / C 闭),
#                    chars 4-7 = NE/SE/SW/NW 角 (I/X/.)
static func mask_to_key(mask: int) -> String:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 2) != 0
	var s: bool = (mask & 4) != 0
	var w: bool = (mask & 8) != 0
	var ne: bool = (mask & 16) != 0
	var se: bool = (mask & 32) != 0
	var sw: bool = (mask & 64) != 0
	var nw: bool = (mask & 128) != 0

	var sides := ""
	sides += "C" if n else "O"
	sides += "C" if e else "O"
	sides += "C" if s else "O"
	sides += "C" if w else "O"

	var corners := ""
	corners += _corner_char(n, e, ne)   # NE (index 4)
	corners += _corner_char(s, e, se)   # SE (index 5)
	corners += _corner_char(s, w, sw)   # SW (index 6)
	corners += _corner_char(n, w, nw)   # NW (index 7)

	return sides + corners


static func _corner_char(side_a: bool, side_b: bool, diag: bool) -> String:
	if not (side_a and side_b):
		return "."
	return "I" if diag else "X"


# ─── Slope-aware 82-blob (草+土斜接) ────────────────────────────────────

# slope key 多 4 字符 (8 角字符之后): 4 角的 slope 状态.
# 当两相邻边都开时: 对角邻居在 → "P" (peninsula slope, 画斜三角填角),
#                  对角邻居不在 → "_" (无 slope, 普通圆角).
# 其它情况 (任一相邻边闭) → "-" (slope 不适用).
#
# 顺序: NE-slope, SE-slope, SW-slope, NW-slope (与角同序).

static var SLOPE_VARIANT_KEYS: Array[String] = _enumerate_slope_keys()

# 256 项: mask → atlas Vector2i (col 0..11, row 0..6).
static var SLOPE_ATLAS_COORD: Array[Vector2i] = _build_slope_atlas_coord()

# slope atlas 列数 (12). 行数 ceil(82/12) = 7.
const SLOPE_ATLAS_COLS: int = 12
const SLOPE_ATLAS_ROWS: int = 7


static func mask_to_slope_key(mask: int) -> String:
	var standard: String = mask_to_key(mask)
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 2) != 0
	var s: bool = (mask & 4) != 0
	var w: bool = (mask & 8) != 0
	var ne: bool = (mask & 16) != 0
	var se: bool = (mask & 32) != 0
	var sw: bool = (mask & 64) != 0
	var nw: bool = (mask & 128) != 0

	var slopes := ""
	slopes += _slope_char(n, e, ne)   # NE-slope
	slopes += _slope_char(s, e, se)   # SE-slope
	slopes += _slope_char(s, w, sw)   # SW-slope
	slopes += _slope_char(n, w, nw)   # NW-slope
	return standard + slopes


# 两相邻边都开 + 对角邻居在 → "P"; 都开 + 对角无 → "_"; 其它 → "-".
static func _slope_char(side_a: bool, side_b: bool, diag: bool) -> String:
	if side_a or side_b:
		return "-"
	return "P" if diag else "_"


# ─── 内部: 47-key enumeration ────────────────────────────────────────────

static func _enumerate_keys() -> Array[String]:
	# 扫 256 个 mask, dedup 出 47 个 key, 按 (闭边数, key 字典序) 排序.
	var seen := {}
	for m in range(256):
		var k := mask_to_key(m)
		if not seen.has(k):
			seen[k] = _closed_side_count(m)
	var pairs: Array = []
	for k in seen.keys():
		pairs.append([seen[k], k])
	pairs.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1]
	)
	var result: Array[String] = []
	for p in pairs:
		result.append(p[1])
	return result


static func _closed_side_count(mask: int) -> int:
	var c: int = 0
	if mask & 1: c += 1
	if mask & 2: c += 1
	if mask & 4: c += 1
	if mask & 8: c += 1
	return c


static func _build_atlas_coord() -> Array[Vector2i]:
	var key_to_index := {}
	for i in VARIANT_KEYS.size():
		key_to_index[VARIANT_KEYS[i]] = i
	var result: Array[Vector2i] = []
	result.resize(256)
	for m in range(256):
		var k := mask_to_key(m)
		var idx: int = key_to_index[k]
		result[m] = Vector2i(idx % 8, idx / 8)
	return result


# ─── 内部: slope-key enumeration ────────────────────────────────────────

static func _enumerate_slope_keys() -> Array[String]:
	var seen := {}
	for m in range(256):
		var k := mask_to_slope_key(m)
		if not seen.has(k):
			seen[k] = _closed_side_count(m)
	var pairs: Array = []
	for k in seen.keys():
		pairs.append([seen[k], k])
	pairs.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1]
	)
	var result: Array[String] = []
	for p in pairs:
		result.append(p[1])
	return result


static func _build_slope_atlas_coord() -> Array[Vector2i]:
	var key_to_index := {}
	for i in SLOPE_VARIANT_KEYS.size():
		key_to_index[SLOPE_VARIANT_KEYS[i]] = i
	var result: Array[Vector2i] = []
	result.resize(256)
	for m in range(256):
		var k := mask_to_slope_key(m)
		var idx: int = key_to_index[k]
		result[m] = Vector2i(idx % SLOPE_ATLAS_COLS, idx / SLOPE_ATLAS_COLS)
	return result
