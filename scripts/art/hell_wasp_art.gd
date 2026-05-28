# 地狱蜂 (Hell Wasp): 飞行 + 远距冲撞怪. 红黑条纹蜂身 + 红翅 + 大尖刺.
# 2 帧 (翅膀颤抖), idle/move/attack 共享.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(20, 10, 10),     # 黑描边
	"k": Color8(45, 18, 15),     # 暗红黑条纹
	"r": Color8(195, 35, 35),    # 红条纹
	"R": Color8(135, 22, 22),    # 暗红
	"o": Color8(255, 105, 50),   # 高光橙
	"y": Color8(255, 230, 80),   # 黄眼
	"w": Color8(245, 200, 200),  # 翅膀淡红 (半透感)
	"W": Color8(180, 130, 130),  # 翅膀脉络
}

# 翅膀帧 1: 张开
const _F0 := [
	"................",
	"...wwwn..nwww...",   # 翅膀展开
	"..wwWwn..nwWww..",
	"..wWww.....wWww.",   # 翅膀脉络
	"...www.....www..",
	".....nkkRkn.....",   # 头
	".....nkyykn.....",   # 黄眼
	".....nkRRkn.....",   # 头部红
	"....nkrkrkrkn...",   # 身体条纹 (k=黑红, r=红)
	"....nrkrkrkrn...",
	"....nkrkrkrkn...",
	".....nkrrkn.....",
	"......nkkn......",
	".......nn.......",
	"......nnn.......",   # 尖刺
	".......n........",
]

# 翅膀帧 2: 收起 (颤动)
const _F1 := [
	"................",
	"................",
	"....nwwn.nwwn...",   # 翅膀收
	"...wwwn..nwww...",
	"....nw.....wn...",
	".....nkkRkn.....",
	".....nkyykn.....",
	".....nkRRkn.....",
	"....nkrkrkrkn...",
	"....nrkrkrkrn...",
	"....nkrkrkrkn...",
	".....nkrrkn.....",
	"......nkkn......",
	".......nn.......",
	"......nnn.......",
	".......n........",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t0: ImageTexture = PixelArt.grid_to_texture(_F0, PALETTE)
	var t1: ImageTexture = PixelArt.grid_to_texture(_F1, PALETTE)
	for anim in ["idle", "move", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 14.0)   # 翅膀拍动快
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, t0)
		sf.add_frame(anim, t1)
	return sf
