# 主菜单背景元素：云、远山、树剪影、地面噪点。
# 全部用 ASCII 网格 + PixelArt 生成。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const _CLOUD_PALETTE := {
	".": Color(0, 0, 0, 0),
	"w": Color8(255, 245, 230, 200),   # 暖白半透
	"W": Color8(240, 220, 200, 230),   # 略暗高光
}

# 24×8 椭圆云
const _CLOUD_ROWS := [
	"........wwwwwww.........",
	".....wwwwwwwwwwwww......",
	"...wwwwWWWWWWwwwwwww....",
	"..wwwwWWWWWWWWWwwwwwww..",
	"..wwwwwWWWWWWWWwwwwwww..",
	"...wwwwwwwwwwwwwwwww....",
	".....wwwwwwwwwwwww......",
	".........wwwww..........",
]

const _HILL_PALETTE := {
	".": Color(0, 0, 0, 0),
	"h": Color8(74, 56, 88),    # 紫灰
	"H": Color8(54, 40, 64),    # 深紫
}

# 80×10 起伏远山轮廓
const _HILL_ROWS := [
	"...........................hh.........................hhh.......................",
	"..........................hhhh.......................hhhhhh.....................",
	".....hh..................hhhhhh......hhh............hhhhhhhh..........hhh.......",
	"....hhhh................hhhhhhhh....hhhhh..........hhhhhhhhhh........hhhhh......",
	"...hhhhhh..............hhhhHHHHhh..hhhhhhh........hhhhHHHHHHhh......hhhhhhh.....",
	"..hhhhhhhh............hhhhHHHHHHhhhhhhHHhhhh.....hhhHHHHHHHHHHhh...hhhhHHhhhh...",
	".hhhhHHHHhh..........hhhHHHHHHHHHhhhHHHHHhhhh...hhHHHHHHHHHHHHHh..hhhHHHHHhhh...",
	"hhhhHHHHHHhh........hhHHHHHHHHHHHHhHHHHHHHHhhh.hhHHHHHHHHHHHHHHhhhhHHHHHHHHhhhhh",
	"hhHHHHHHHHHHhhhhhhhhHHHHHHHHHHHHHHHHHHHHHHHHHhhhHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhh",
	"HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
]

const _TREE_PALETTE := {
	".": Color(0, 0, 0, 0),
	"t": Color8(20, 14, 24),    # 近黑剪影
}

# 12×16 尖顶树剪影
const _TREE_ROWS := [
	".....tt.....",
	"....tttt....",
	"...tttttt...",
	"..tttttttt..",
	"...tttttt...",
	"..tttttttt..",
	".tttttttttt.",
	"..tttttttt..",
	".tttttttttt.",
	"tttttttttttt",
	".tttttttttt.",
	"tttttttttttt",
	".....tt.....",
	".....tt.....",
	".....tt.....",
	".....tt.....",
]

const _GROUND_PALETTE := {
	".": Color8(58, 36, 22),    # 暗棕底
	"d": Color8(74, 50, 30),    # 略亮棕
	"D": Color8(42, 26, 16),    # 更暗
}

# 16×8 重复用噪点地面贴图
const _GROUND_ROWS := [
	"..d...D...d..D..",
	".D...d...D..d...",
	"d..D...d...D...d",
	"...d..D...d.D...",
	".D...d..D..d...D",
	"d.D..d.D..d.D..d",
	"..d..D..d.D...d.",
	"D..d.D..d.D...D.",
]


const _BIRD_PALETTE := {
	".": Color(0, 0, 0, 0),
	"b": Color8(55, 48, 64, 235),   # 远处小鸟剪影 (略带紫灰, 不死黑)
}

# 9×4 飞鸟剪影 ("M" 形翅膀)
const _BIRD_ROWS := [
	"bb.....bb",
	".bb...bb.",
	"..bb.bb..",
	"...bbb...",
]


static func make_cloud() -> ImageTexture:
	return PixelArt.grid_to_texture(_CLOUD_ROWS, _CLOUD_PALETTE)


static func make_bird() -> ImageTexture:
	return PixelArt.grid_to_texture(_BIRD_ROWS, _BIRD_PALETTE)


static func _circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			if Vector2(x - cx, y - cy).length() <= r:
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, c)


# 好看的森林树: 棕树干 + 圆树冠 (暖绿) + 左上高光 + 右下阴影. variant 0=圆胖, 1=高瘦双层.
static func make_forest_tree(variant: int = 0) -> ImageTexture:
	var w := 22
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = w / 2.0
	var trunk := Color8(120, 82, 52)
	var trunk_sh := Color8(92, 62, 40)
	# 树干 (底部 ~9px, 3px 宽)
	for y in range(h - 9, h):
		img.set_pixel(int(cx) - 1, y, trunk)
		img.set_pixel(int(cx), y, trunk)
		img.set_pixel(int(cx) + 1, y, trunk_sh)
	var g := Color8(92, 156, 72)       # 暖绿基
	var hl := Color8(142, 198, 98)     # 受光高光
	var sh := Color8(58, 116, 56)      # 阴影
	if variant == 0:
		_circle(img, cx, 13.0, 8.5, g)        # 主树冠
		_circle(img, cx - 6, 16.0, 6.0, g)    # 左下鼓
		_circle(img, cx + 6, 16.0, 6.0, g)    # 右下鼓
		_circle(img, cx + 5, 18.0, 4.5, sh)   # 右下阴影
		_circle(img, cx - 4, 9.0, 5.0, hl)    # 左上高光
	else:
		_circle(img, cx, 17.0, 7.0, g)        # 下层
		_circle(img, cx, 9.5, 6.0, g)         # 上层
		_circle(img, cx + 4, 19.0, 4.0, sh)
		_circle(img, cx - 3, 6.5, 4.0, hl)
	return ImageTexture.create_from_image(img)


# 暖色太阳圆盘 (中心亮白黄 → 边缘暖橙, 边缘微软). 程序画圆比 ASCII 圆.
static func make_sun(size: int = 30) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = size / 2.0
	var r: float = size / 2.0 - 0.5
	var inner := Color8(255, 249, 214)
	var outer := Color8(255, 206, 120)
	for y in size:
		for x in size:
			var d: float = Vector2(x + 0.5 - c, y + 0.5 - c).length()
			if d <= r:
				var t: float = d / r
				var col: Color = inner.lerp(outer, t)
				if t > 0.82:
					col.a = 1.0 - (t - 0.82) / 0.18 * 0.55   # 边缘柔化
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func make_hill() -> ImageTexture:
	return PixelArt.grid_to_texture(_HILL_ROWS, _HILL_PALETTE)


static func make_tree() -> ImageTexture:
	return PixelArt.grid_to_texture(_TREE_ROWS, _TREE_PALETTE)


static func make_ground_noise() -> ImageTexture:
	return PixelArt.grid_to_texture(_GROUND_ROWS, _GROUND_PALETTE)
