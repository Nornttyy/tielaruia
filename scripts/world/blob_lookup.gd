# 8-bit 邻居 mask → 8 字符 variant key → atlas 坐标. 47 唯一变体.
# 用于 Terraria 风格自动连接 (blob autotiling).
#
# Mask bit 编号 (LSB 起):
#   0=N, 1=E, 2=S, 3=W, 4=NE, 5=SE, 6=SW, 7=NW
#
# Key 8 字符: chars 0-3 = N/E/S/W 边 (O 开 / C 闭),
#             chars 4-7 = NE/SE/SW/NW 角 (I/X/.)
extends RefCounted


# 按"封闭边数"排序的 47 唯一 key. atlas 索引 = 此数组下标.
static var VARIANT_KEYS: Array[String] = _enumerate_keys()

# 256 项查表: mask → atlas Vector2i (col, row). 8 列 6 行.
static var ATLAS_COORD: Array = _build_atlas_coord()


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
	# SE 角: 看 S 和 E (index 4)
	corners += _corner_char(s, e, se)
	# NE 角: 看 N 和 E (index 5)
	corners += _corner_char(n, e, ne)
	# SW 角: 看 S 和 W (index 6)
	corners += _corner_char(s, w, sw)
	# NW 角: 看 N 和 W (index 7)
	corners += _corner_char(n, w, nw)

	return sides + corners


static func _corner_char(side_a: bool, side_b: bool, diag: bool) -> String:
	if not (side_a and side_b):
		return "."
	return "I" if diag else "X"


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


static func _build_atlas_coord() -> Array:
	# 每个 mask 映射到它的 key 在 VARIANT_KEYS 里的下标, 再换算成 (col, row).
	var key_to_index := {}
	for i in VARIANT_KEYS.size():
		key_to_index[VARIANT_KEYS[i]] = i
	var result: Array = []
	result.resize(256)
	for m in range(256):
		var k := mask_to_key(m)
		var idx: int = key_to_index[k]
		result[m] = Vector2i(idx % 8, idx / 8)
	return result
