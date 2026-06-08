# 玩家像素画: 泰拉瑞亚式 **正面** 小人 (18×28)。两只白眼睛 + 大蓬松头发 + 两只手, 没嘴。
# 按 CharacterData.appearance_dict() 分层拼装: 身体(皮肤+脸+鞋) → 裤子 → 衬衫(+袖) → 头发。
# 正面对称; 朝向用 flip_h (左右镜像没差, 正面通用)。1px 黑描边。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")
const W := 18
const H := 28

const DEFAULT_APPEARANCE := {
	"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
	"cape_style": 0, "chest_size": 1,
	"skin_color": Color8(255, 218, 185), "hair_color": Color8(190, 110, 60),
	"shirt_color": Color8(220, 210, 180), "pants_color": Color8(70, 90, 150),
	"cape_color": Color8(150, 40, 50), "eye_color": Color8(70, 110, 170),
}

const _SHOE := Color8(74, 47, 26)
const _SHOE_SH := Color8(48, 30, 15)
const _WHITE := Color(0.98, 0.98, 1.0, 1)
const _OUTLINE := Color8(30, 26, 30)

# ---- 积木块 (正面对称; 大写=阴影) ----
# 脸 (皮肤 s / 阴影 k): 两只白眼睛 (W 眼白 / i 眼珠), 没嘴。8 宽 × 8 高。
const _HEAD := [
	"..ssss..",
	".ssssss.",
	"ssssssss",
	"sWWssWWs",
	"siissiis",
	"ssssssss",
	".kssssk.",
	"..ssss..",
]
# 女脸: 加睫毛 (e 在眼上)。
const _HEAD_F := [
	"..ssss..",
	".seeees.",
	"ssssssss",
	"sWWssWWs",
	"siissiis",
	"ssssssss",
	".kssssk.",
	"..ssss..",
]
# 大蓬松头发 (盖头顶 + 两侧, 留脸): 14 宽 × 8 高。h 主色 / H 阴影。
const _HAIR_SHORT := [
	"...h.h.hh.....",
	"..hhhhhhhhh...",
	".hhhhhhhhhhh..",
	"hhhhhhhhhhhh..",
	"hhhhhhhhhhhh..",
	"hhhh....hhhh..",
	"Hhh......hhH..",
	"hh........hh..",
]
# 长发: 蓬松顶 + 两侧垂长。
const _HAIR_LONG := [
	"...h.h.hh.....",
	"..hhhhhhhhh...",
	".hhhhhhhhhhh..",
	"hhhhhhhhhhhh..",
	"hhhhhhhhhhhh..",
	"hhhh....hhhh..",
	"hhh......hhh..",
	"hhh......hhh..",
	"Hhh......hhH..",
	"hh........hh..",
]
# 马尾/扎起: 顶蓬松 + 收边。
const _HAIR_PONYTAIL := [
	"....hhhh.h....",
	"..hhhhhhhh....",
	".hhhhhhhhh....",
	"hhhhhhhhhh....",
	"hhhhhhhhhh....",
	"hhh....hhh....",
	"Hh......hH....",
	"h........h....",
]
# 呆毛: 蓬松 + 头顶翘一撮。
const _HAIR_AHOGE := [
	".....hh.......",
	"...h.hh.hh....",
	"..hhhhhhhhh...",
	".hhhhhhhhhhh..",
	"hhhhhhhhhhhh..",
	"hhhh....hhhh..",
	"Hhh......hhH..",
	"hh........hh..",
]
# 躯干 (衬衫 w / 阴影 D), 正面带肩 + 两侧袖。10 宽 × 7 高。
const _TORSO := [
	".wwwwwwww.",
	"wwwwwwwwww",
	"DwwwwwwwwD",
	"DwwwwwwwwD",
	"DwwwwwwwwD",
	"DwwwwwwwwD",
	".DwwwwwwD.",
]
# 两只手 (皮肤, 垂在袖子下两侧)。整片 (含中间空)。10 宽 × 2 高。
const _HANDS := [
	"s........s",
	"k........k",
]
# 单腿 (裤 b / 阴影 B)。3 宽 × 5 高。
const _LEG := [
	"Bbb",
	"Bbb",
	"Bbb",
	"Bbb",
	"Bbb",
]
# 鞋 (o / O)。4 宽 × 2 高。
const _SHOE_B := [
	"oooo",
	"OOOO",
]


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
		_body_layer(ap, pose),
		_pants_layer(ap, pose),
		_shirt_layer(ap, pose),
		_hair_layer(ap, pose),
	]
	return _outline(_composite(layers))


static func _dy(pose: String) -> int:
	return 1 if pose == "idle_b" else 0


# 身体层: 脸 + 两手 + 鞋 (躯干/腿留空)。男女不同脸。
static func _body_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	var head: Array = _HEAD_F if int(ap.get("gender", 0)) == 1 else _HEAD
	_place(g, 5 + dy, 5, head)
	_place(g, 18 + dy, 4, _HANDS)   # 两手垂在衬衫下
	_place_shoes(g, pose, dy)
	return g


static func _pants_layer(_ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match pose:
		"walk_a":   # 左腿前(下) 右腿后(上一点) — 走路交替
			_place(g, 20 + dy, 5, _LEG)
			_place(g, 21 + dy, 10, _LEG)
		"walk_c":
			_place(g, 21 + dy, 5, _LEG)
			_place(g, 20 + dy, 10, _LEG)
		"jump":
			_place(g, 20 + dy, 5, _slice(_LEG, 0, 4))
			_place(g, 20 + dy, 10, _slice(_LEG, 0, 4))
		_:          # idle/fall: 双腿站开
			_place(g, 20 + dy, 5, _LEG)
			_place(g, 20 + dy, 10, _LEG)
	return g


static func _shirt_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	if int(ap.get("gender", 0)) == 1:
		_place(g, 13 + dy, 4, _female_torso(int(ap.get("chest_size", 1))))
	else:
		_place(g, 13 + dy, 4, _TORSO)
	return g


# 女躯干: 同位, 腰略收 + 胸口 (上排) 微鼓。正面对称。
static func _female_torso(cs: int) -> Array:
	cs = clampi(cs, 0, 5)
	var rows := [
		".wwwwwwww.",
		"wwwwwwwwww",
		"DwwwwwwwwD",
		".DwwwwwwD.",
		".DwwwwwwD.",
		".DwwwwwwD.",
		"..DwwwwD..",
	]
	# 胸 (row 1-2) 微鼓: cs 越大中间略饱满 (低分辨率, 仅细微)
	return rows


static func _hair_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var dy := _dy(pose)
	match int(ap.get("hair_style", 0)):
		1:
			_place(g, 1 + dy, 2, _HAIR_LONG)
		2:
			_place(g, 1 + dy, 2, _HAIR_PONYTAIL)
		3:
			_place(g, 0 + dy, 2, _HAIR_AHOGE)
		_:
			_place(g, 1 + dy, 2, _HAIR_SHORT)
	return g


static func _place_shoes(g: Array, pose: String, dy: int) -> void:
	match pose:
		"walk_a":
			_place(g, 25 + dy, 4, _SHOE_B)
			_place(g, 26 + dy, 9, _SHOE_B)
		"walk_c":
			_place(g, 26 + dy, 4, _SHOE_B)
			_place(g, 25 + dy, 9, _SHOE_B)
		"jump":
			_place(g, 24 + dy, 4, _SHOE_B)
			_place(g, 24 + dy, 9, _SHOE_B)
		_:
			_place(g, 25 + dy, 4, _SHOE_B)
			_place(g, 25 + dy, 9, _SHOE_B)


static func _palette_from(ap: Dictionary) -> Dictionary:
	var skin: Color = ap.get("skin_color", DEFAULT_APPEARANCE["skin_color"])
	var hair: Color = ap.get("hair_color", DEFAULT_APPEARANCE["hair_color"])
	var shirt: Color = ap.get("shirt_color", DEFAULT_APPEARANCE["shirt_color"])
	var pants: Color = ap.get("pants_color", DEFAULT_APPEARANCE["pants_color"])
	var eye: Color = ap.get("eye_color", DEFAULT_APPEARANCE["eye_color"])
	return {
		".": Color(0, 0, 0, 0),
		"s": skin, "k": skin.darkened(0.18),
		"h": hair, "H": hair.darkened(0.28),
		"w": shirt, "D": shirt.darkened(0.18),
		"b": pants, "B": pants.darkened(0.28),
		"i": eye, "W": _WHITE, "e": skin.darkened(0.30),
		"o": _SHOE, "O": _SHOE_SH,
		"L": _OUTLINE,
	}


# ---- 网格工具 ----
static func _blank() -> Array:
	var g: Array = []
	for y in H:
		g.append(".".repeat(W))
	return g


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


static func _slice(block: Array, from: int, n: int) -> Array:
	return block.slice(from, from + n)
