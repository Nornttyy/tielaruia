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

# ---- 积木块 (朝右; 大写=阴影) ----
# 头 (皮肤 s / 阴影 k); 侧脸朝右, 眼在偏右 (W 眼白 / i 眼珠 / e 睫毛瞳); 鼻在最右; 嘴 m。
const _HEAD := [
	"..sssss..",
	".sssssss.",
	".ssssssss",
	".sssWiess",
	".sssWiess",
	".ksssssss",
	".ksssmsss",
	".kssssss.",
	"..kssss..",
	"...sss...",
	"...kss...",
]
# 短发: 盖头顶 + 后脑 (朝右 → 后脑在左)。
const _HAIR_SHORT := [
	"..HHHHH..",
	".hhhhhhh.",
	"hhhhhhhh.",
	"Hhhh.....",
	"hhh......",
]
# 躯干 (衬衫 w / 阴影 D), 8 宽 × 15 高 (肩到腰)
const _TORSO := [
	".wwwwww.",
	"wwwwwwww",
	"wwwwwwDw",
	"wwwwwwww",
	"wDwwwwww",
	"wwwwwwww",
	"wwwwwwDw",
	"wwwwwwww",
	"wDwwwwww",
	"wwwwwwww",
	"wwwwwwDw",
	"wwwwwwww",
	"wwwwwwww",
	".wwwwww.",
	".wwwwww.",
]
# 前臂 + 手 (皮肤; T恤短袖露小臂), 2 宽
const _ARM := [
	"ww",
	"ww",
	"ww",
	"ss",
	"ss",
	"ss",
	"sk",
]
# 单腿 (裤子 b / 阴影 B), 3 宽 × 15 高
const _LEG := [
	"bbb",
	"bbb",
	"bBb",
	"bbb",
	"bbb",
	"bBb",
	"bbb",
	"bbb",
	"bBb",
	"bbb",
	"bbb",
	"bbb",
	"bbb",
	"bbb",
	"bbb",
]
# 靴 (o / 阴影 O), 4 宽
const _BOOT_B := [
	"ooo.",
	"oooo",
	"OOOO",
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
		_hair_layer(ap, pose),
	]
	return _composite(layers)


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


# 身体层: 头 + 前臂 + 靴 (躯干/腿留空给衣裤)。gender 1 待 Task 3, 现回退男。
static func _body_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	_place(g, 3 + dy, 7, _HEAD)
	# 前臂: 跟姿势。受击/跳手抬高, 下落手外展, 其余垂在体侧前方。
	match pose:
		"hurt", "jump":
			_place(g, 11 + dy, 16, _ARM)
		_:
			_place(g, 17 + dy, 16, _ARM)
	# 靴: 跟腿姿。
	_place_boots(g, pose, dy)
	return g


# 裤子层: pants_style 0 (长裤); 其它号回退。
static func _pants_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match pose:
		"walk_a":   # 一腿前 (右), 一腿后 (左)
			_place(g, 27 + dy, 12, _LEG)
			_place(g, 28 + dy, 8, _LEG)
		"walk_c":   # 反相
			_place(g, 28 + dy, 12, _LEG)
			_place(g, 27 + dy, 8, _LEG)
		"jump":     # 收腿 (短)
			_place(g, 27 + dy, 9, _slice(_LEG, 0, 10))
			_place(g, 27 + dy, 12, _slice(_LEG, 0, 10))
		"fall":     # 展腿
			_place(g, 27 + dy, 7, _LEG)
			_place(g, 27 + dy, 14, _LEG)
		_:          # idle: 双腿并拢
			_place(g, 27 + dy, 9, _LEG)
			_place(g, 27 + dy, 12, _LEG)
	return g


# 衬衫层: shirt_style 0 (T恤); 其它号回退。
static func _shirt_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	_place(g, 13 + dy, 8, _TORSO)
	return g


# 头发层: hair_style 0 (短发); 其它号 Task 4。
static func _hair_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	_place(g, 2 + dy, 7, _HAIR_SHORT)
	return g


# 靴跟腿姿摆放。
static func _place_boots(g: Array, pose: String, dy: int) -> void:
	match pose:
		"walk_a":
			_place(g, 42 + dy, 12, _BOOT_B)
			_place(g, 43 + dy, 8, _BOOT_B)
		"walk_c":
			_place(g, 43 + dy, 12, _BOOT_B)
			_place(g, 42 + dy, 8, _BOOT_B)
		"jump":
			_place(g, 37 + dy, 9, _BOOT_B)
			_place(g, 37 + dy, 12, _BOOT_B)
		"fall":
			_place(g, 42 + dy, 7, _BOOT_B)
			_place(g, 42 + dy, 14, _BOOT_B)
		_:
			_place(g, 42 + dy, 9, _BOOT_B)
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
		"o": _BOOT, "O": _BOOT_SH,
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
