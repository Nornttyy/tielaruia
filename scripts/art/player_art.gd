# 玩家像素画: 泰拉瑞亚式 24×48 侧面单眼。按 CharacterData.appearance_dict() 分层拼装:
# 披风(后) → 身体(皮肤+靴) → 裤子 → 衬衫 → 头发。每层 24×48, 后画盖前画。
# 朝右版; 运行时 flip_h 朝左 (player_controller 处理)。
# Plan 2: 只画默认款 (短发/T恤/长裤/无披风) + 男女身体; 其它款式号回退默认 (Plan 4 逐批补)。
#
# 构建方式: 用小"积木块"(ascii 子图) + _place 摆放坐标拼每帧, 比手摆整张 48 行更不易错位。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")
const W := 24
const H := 48

const DEFAULT_APPEARANCE := {
	"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
	"cape_style": 0, "chest_size": 1,
	"skin_color": Color8(255, 218, 185), "hair_color": Color8(121, 85, 72),
	"shirt_color": Color8(229, 57, 53), "pants_color": Color8(38, 70, 130),
	"cape_color": Color8(150, 40, 50), "eye_color": Color8(60, 110, 70),
}

# 固定色 (不随 appearance)
const _BOOT := Color8(74, 47, 26)
const _BOOT_SH := Color8(48, 30, 15)
const _EYE_DARK := Color8(30, 28, 26)
const _MOUTH := Color8(150, 70, 70)
const _WHITE := Color(0.98, 0.98, 1.0, 1)
const _OUTLINE := Color8(28, 24, 30)   # 泰拉瑞亚式黑描边 (略暖的近黑)

# ---- 积木块 (朝右; 大写=阴影) ----
# 头 (皮肤 s / 阴影 k); 侧脸朝右, 眼在偏右 (W 眼白 / i 眼珠 / e 睫毛瞳); 鼻在最右; 嘴 m。
const _HEAD := [
	"..ssssss...",
	".ssssssss..",
	".sssssssss.",
	".sssssssWi.",
	".sssssssWi.",
	".sssssssWi.",
	".kssssssss.",
	".kssssssss.",
	"..ksssss...",
	"...ssss....",
	"...ksss....",
]
# 女头: 同尺寸, 加睫毛 (眼上一排 e) + 眼珠大一点, 一眼区分。
const _HEAD_F := [
	"..ssssss...",
	".ssssssss..",
	".sssssssee.",
	".sssssssWi.",
	".sssssssWi.",
	".sssssssWi.",
	".kssssssss.",
	".kssssssss.",
	"..ksssss...",
	"...ssss....",
	"...ksss....",
]
# 短发: 盖头顶 + 后脑 (朝右 → 后脑在左)。
# 自然顺滑短发: 顺着头顶弧线, 前额一缕斜下, 后侧自然垂, 不是死板圆球。
const _HAIR_SHORT := [
	"...2hh...",
	"..2hhhh..",
	".2hhhhhh.",
	".h2hhhhhh",
	"hh2hhhhH.",
	"hhhhhh...",
	"Hhhh.....",
	"hh.......",
]
# 长发: 顺后背 (左) 垂下到肩。
const _HAIR_LONG := [
	"..HHHHH..",
	".hhhhhhh.",
	"hhhhhhhh.",
	"Hhhh.....",
	"hhhh.....",
	"Hhh......",
	"hhh......",
	"hhh......",
	"Hhh......",
	"hhh......",
	".Hh......",
]
# 马尾: 短顶 + 后脑扎一束往左下翘。
const _HAIR_PONYTAIL := [
	"..HHHHH..",
	".hhhhhhh.",
	"hhhhhhhh.",
	"HhhH.....",
	"hh.......",
	"hhh......",
	".Hhh.....",
	"..hh.....",
]
# 呆毛: 短发 + 头顶一根翘起。
const _HAIR_AHOGE := [
	"....hh...",
	"...Hh....",
	"..HHHHH..",
	".hhhhhhh.",
	"hhhhhhhh.",
	"Hhhh.....",
	"hhh......",
]
# 躯干 (衬衫 w / 阴影 D), 8 宽 × 15 高 (肩到腰)。
# 阴影沿后侧(左)一整列 + 衣摆一条, 立体感 (不再散点像波点)。
const _TORSO := [
	".wwwDDwwww.",
	"1wwwwwwww1.",
	"1wwwwwwwww1",
	"1wwwwwwwww1",
	"D1wwwwwww11",
	"D1wwwwwww11",
	"Dwwwwwwww11",
	"Dwwwwwwww11",
	"Dwwwwwwww11",
	"Dwwwwwwww11",
	"DDDDDDDDD11",
	".wwwwwww1..",
	".Dwwwww11..",
]
# 垂下的胳膊: 袖子(衬衫 w/D) + 小臂(皮肤 s/k) + 手, 3 宽。画在衣服前面。
const _ARM := [
	"ww.",
	"www",
	"Dww",
	"Dss",
	"sss",
	"ssk",
	"ssk",
	"skk",
	".kk",
]
# 后臂 (远侧那条手, 画在身体后面): 整体用深色 (袖 D / 小臂 k) 表示在后/远。
const _ARM_BACK := [
	"DD.",
	"DDD",
	"DDD",
	"Dkk",
	"kkk",
	"kkk",
	"kkk",
	"kkk",
	".kk",
]
# 单腿 (裤子 b / 阴影 B), 3 宽 × 15 高。后侧(左)一列阴影, 立体 (不再中间散点)。
const _LEG := [
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
	"Bbbb3",
]
# 迈步腿: 往前迈 (髋在左上→脚在右下, 脚朝前)。走路用, 脚一前一后落地, 不上下抖。
const _LEG_FWD := [
	"Bbbb..",
	"Bbbb..",
	".Bbbb.",
	".Bbbb.",
	".Bbbb.",
	"..bbbb",
	"..bbbb",
	"..bbbb",
	"..bbbb",
]
# 迈步腿: 往后蹬 (髋在右上→脚在左下, 脚朝后)。
const _LEG_BACK := [
	"..bbbb",
	"..bbbb",
	".bbbb.",
	".bbbb.",
	".bbbb.",
	"Bbbb..",
	"Bbbb..",
	"Bbbb..",
	"Bbbb..",
]
# 靴 (o / 阴影 O / 高光 P), 5 宽。带鞋面高光 + 鞋底深色。
const _BOOT_B := [
	"ooPoo",
	"ooooo",
	"OOOOO",
	"OOOOO",
]


# 主入口
static func build_sprite_frames(appearance: Dictionary = DEFAULT_APPEARANCE) -> SpriteFrames:
	var pal := _palette_from(appearance)
	var anims := {
		"idle": {"frames": [_frame(appearance, "idle_a"), _frame(appearance, "idle_b")], "fps": 2.0, "loop": true},
		"walk": {"frames": [_frame(appearance, "walk_a"), _frame(appearance, "idle_a"), _frame(appearance, "walk_c"), _frame(appearance, "idle_a")], "fps": 10.0, "loop": true},
		"jump": {"frames": [_frame(appearance, "jump")], "fps": 1.0, "loop": false},
		"fall": {"frames": [_frame(appearance, "fall")], "fps": 1.0, "loop": false},
		"hurt": {"frames": [_frame(appearance, "hurt")], "fps": 1.0, "loop": false},
	}
	return PixelArt.build_sprite_frames(anims, pal)


static func _frame(ap: Dictionary, pose: String) -> Array:
	var layers := [
		_cape_layer(ap, pose),
		_body_layer(ap, pose),
		_pants_layer(ap, pose),
		_shirt_layer(ap, pose),
		_arm_layer(ap, pose),    # 侧面只画近侧一只手 (在衣服前面); 走路前后摆
		_hair_layer(ap, pose),
	]
	# 描边跑两遍 = 2px 粗黑边 (泰拉瑞亚式, 用户要更粗)。
	return _outline(_outline(_composite(layers)))


# 泰拉瑞亚式黑描边: 沿小人轮廓外缘 (空格且 4-邻接有实心) 补一圈 'L'。
static func _outline(grid: Array) -> Array:
	var out: Array = grid.duplicate(true)
	for y in H:
		for x in W:
			if grid[y].substr(x, 1) != ".":
				continue
			var adj := false
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var ny: int = y + d[0]
				var nx: int = x + d[1]
				if ny >= 0 and ny < H and nx >= 0 and nx < W and grid[ny].substr(nx, 1) != ".":
					adj = true
					break
			if adj:
				out[y] = _set_char(out[y], x, "L")
	return out


static func _set_char(row: String, x: int, c: String) -> String:
	return row.substr(0, x) + c + row.substr(x + 1)


# 合并: 后层非 '.' 盖前层。
static func _composite(layers: Array) -> Array:
	var out := _blank()
	for layer in layers:
		if layer == null:
			continue
		for y in H:
			var base: String = out[y]
			var top: String = layer[y]
			var merged := ""
			for x in W:
				var tc := top.substr(x, 1)
				merged += tc if tc != "." else base.substr(x, 1)
			out[y] = merged
	return out


# idle_b: 整体下沉 1px (呼吸)
static func _dy(pose: String) -> int:
	return 1 if pose == "idle_b" else 0


# 披风层: Plan 2 一律透明 (cape_style 0; 其它号 Plan 4)。
static func _cape_layer(_ap: Dictionary, _pose: String) -> Array:
	return _blank()


# 身体层: 头 + 前臂 + 靴 (躯干/腿留空给衣裤)。男女不同头 (女加睫毛/大眼珠)。
static func _body_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	var head: Array = _HEAD_F if int(ap.get("gender", 0)) == 1 else _HEAD
	_place(g, 11 + dy, 5, head)
	# 靴: 跟腿姿。
	_place_boots(g, pose, dy)
	return g


# 手臂层 (画在衣服前面): 近侧那条胳膊从肩垂下, 袖子(衬衫色)+小臂(皮肤)+手。
# 走路前后摆 (手会动); 受击/跳抬高。
static func _arm_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match pose:
		"hurt", "jump":
			_place(g, 18 + dy, 15, _ARM)   # 手抬高
		"walk_a":
			_place(g, 19 + dy, 16, _ARM)   # 往前上甩 (手在前/右)
		"walk_c":
			_place(g, 24 + dy, 13, _ARM)   # 往后下甩 (手在后/左)
		_:
			_place(g, 22 + dy, 15, _ARM)
	return g


# 后臂层 (画在身体后面): 远侧那只手, 在后方(左)露出, 走路跟前臂**反向**摆。
static func _arm_back_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match pose:
		"hurt", "jump":
			_place(g, 18 + dy, 3, _ARM_BACK)
		"walk_a":   # 前臂往前 → 后臂往后下
			_place(g, 24 + dy, 3, _ARM_BACK)
		"walk_c":   # 前臂往后 → 后臂往前上
			_place(g, 20 + dy, 4, _ARM_BACK)
		_:
			_place(g, 22 + dy, 3, _ARM_BACK)
	return g


# 裤子层: pants_style 0 (长裤); 其它号回退。
static func _pants_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match pose:
		"walk_a":   # 迈步: 前腿往前迈(脚在右), 后腿往后蹬(脚在左); 脚都落地, 不上下抖
			_place(g, 33 + dy, 11, _LEG_FWD)
			_place(g, 33 + dy, 3, _LEG_BACK)
		"walk_c":   # 反相迈步 (前后腿对调, 看着像交替迈步)
			_place(g, 33 + dy, 10, _LEG_FWD)
			_place(g, 33 + dy, 2, _LEG_BACK)
		"jump":     # 收腿 (短)
			_place(g, 33 + dy, 7, _slice(_LEG, 0, 6))
			_place(g, 33 + dy, 12, _slice(_LEG, 0, 6))
		"fall":     # 展腿
			_place(g, 33 + dy, 5, _LEG)
			_place(g, 33 + dy, 14, _LEG)
		_:          # idle: 双腿并拢
			_place(g, 33 + dy, 7, _LEG)
			_place(g, 33 + dy, 12, _LEG)
	return g


# 衬衫层: shirt_style 0 (T恤); 其它号回退。女版用窄躯干 + 胸口前凸 (chest_size)。
static func _shirt_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	if int(ap.get("gender", 0)) == 1:
		_place(g, 21 + dy, 7, _female_torso(int(ap.get("chest_size", 1))))
	else:
		_place(g, 21 + dy, 6, _TORSO)
	return g


# 女躯干 (衬衫): 7 宽窄身 + 腰收; 胸口 (上 4 行) 朝右(前)按 chest_size 0..5 前凸。
static func _female_torso(cs: int) -> Array:
	cs = clampi(cs, 0, 5)
	var rows := [
		".wwwww.",
		"Dwwwww.",
		"Dwwwwww",
		"Dwwwwww",
		"Dwwwwww",
		"Dwwww..",
		"Dwwww..",
		"Dwwwww.",
		"Dwwwwww",
		"Dwwwwww",
		"DDDDDw.",
		".wwww..",
		".wwww..",
		".wwww..",
		".wwww..",
	]
	# 胸口前凸: rows 1..4 在右侧(前)加 cs 列 (最前一列 D 阴影)。
	if cs > 0:
		var bulge: String = ("w".repeat(cs - 1) + "D") if cs >= 1 else ""
		for r in range(1, 5):
			rows[r] = rows[r] + bulge
	return rows


# 头发层: 4 款 (0 短发 / 1 长发 / 2 马尾 / 3 呆毛); 未知号回退短发。
static func _hair_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match int(ap.get("hair_style", 0)):
		1:
			_place(g, 10 + dy, 6, _HAIR_LONG)
		2:
			_place(g, 10 + dy, 6, _HAIR_PONYTAIL)
		3:
			_place(g, 8 + dy, 6, _HAIR_AHOGE)
		_:
			_place(g, 8 + dy, 6, _HAIR_SHORT)
	return g


# 靴跟腿姿摆放。
static func _place_boots(g: Array, pose: String, dy: int) -> void:
	match pose:
		"walk_a":   # 前脚(右) + 后脚(左), 同一地面高度 (不上下)
			_place(g, 42 + dy, 13, _BOOT_B)
			_place(g, 42 + dy, 3, _BOOT_B)
		"walk_c":
			_place(g, 42 + dy, 12, _BOOT_B)
			_place(g, 42 + dy, 2, _BOOT_B)
		"jump":
			_place(g, 41 + dy, 7, _BOOT_B)
			_place(g, 41 + dy, 12, _BOOT_B)
		"fall":
			_place(g, 42 + dy, 5, _BOOT_B)
			_place(g, 42 + dy, 14, _BOOT_B)
		_:
			_place(g, 42 + dy, 7, _BOOT_B)
			_place(g, 42 + dy, 12, _BOOT_B)


static func _palette_from(ap: Dictionary) -> Dictionary:
	var skin: Color = ap.get("skin_color", DEFAULT_APPEARANCE["skin_color"])
	var hair: Color = ap.get("hair_color", DEFAULT_APPEARANCE["hair_color"])
	var shirt: Color = ap.get("shirt_color", DEFAULT_APPEARANCE["shirt_color"])
	var pants: Color = ap.get("pants_color", DEFAULT_APPEARANCE["pants_color"])
	var cape: Color = ap.get("cape_color", DEFAULT_APPEARANCE["cape_color"])
	var eye: Color = ap.get("eye_color", DEFAULT_APPEARANCE["eye_color"])
	return {
		".": Color(0, 0, 0, 0),
		"s": skin, "k": skin.darkened(0.18),
		"h": hair, "H": hair.darkened(0.28),
		"w": shirt, "D": shirt.darkened(0.28),
		"b": pants, "B": pants.darkened(0.28),
		"c": cape, "C": cape.darkened(0.28),
		"i": eye, "W": _WHITE, "e": _EYE_DARK, "m": _MOUTH,
		"o": _BOOT, "O": _BOOT_SH, "P": _BOOT.lightened(0.22),
		"L": _OUTLINE,
		# 高光 (亮面, 加细节): 衬衫/头发/裤子各一档亮
		"1": shirt.lightened(0.16), "2": hair.lightened(0.24), "3": pants.lightened(0.16),
	}


# ---- 网格工具 ----
static func _blank() -> Array:
	var g: Array = []
	for y in H:
		g.append(".".repeat(W))
	return g


# 把 block (ascii 子图) 摆到 grid 的 (top,left); 越界裁掉; '.' 不覆盖 (透明)。
static func _place(grid: Array, top: int, left: int, block: Array) -> void:
	for by in block.size():
		var gy := top + by
		if gy < 0 or gy >= H:
			continue
		var brow: String = block[by]
		var row: String = grid[gy]
		var merged := ""
		for x in W:
			var bx := x - left
			var bc := "."
			if bx >= 0 and bx < brow.length():
				bc = brow.substr(bx, 1)
			merged += bc if bc != "." else row.substr(x, 1)
		grid[gy] = merged


# 取 block 的前 n 行 (收腿用)。
static func _slice(block: Array, from: int, n: int) -> Array:
	return block.slice(from, from + n)
