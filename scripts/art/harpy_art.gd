# 哈比鸟 (Harpy): 天空浮岛附近飞行怪. 白羽身 + 棕翼 + 黄喙. 2 帧拍翅 (上/下).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(45, 33, 26),     # 黑褐描边
	"w": Color8(245, 240, 230),  # 白羽主
	"W": Color8(208, 196, 178),  # 白羽阴影
	"t": Color8(184, 140, 92),   # 棕翼
	"T": Color8(140, 100, 62),   # 棕翼深
	"y": Color8(245, 198, 70),   # 黄喙/爪
	"e": Color8(40, 30, 25),     # 眼
}

# 帧 0: 翅膀上扬
const _F0 := [
	"......nwwn......",
	".....nwwwwn.....",
	"..t..nwewen..t..",
	".tTn.nwyywn.nTt.",
	"tTTnnwwwwwwnnTTt",
	".tTnwwwWWwwwnTt.",
	"..nwwwWWWWwwwn..",
	"..nwwWWWWWWwwn..",
	"...nwwWWWWwwn...",
	"...nwwwwwwwwn...",
	"....nwwwwwwn....",
	".....nwwwwn.....",
	"......nyynn.....",
	".....ny..yn.....",
	"....ny....yn....",
	"................",
]

# 帧 1: 翅膀下压
const _F1 := [
	"......nwwn......",
	".....nwwwwn.....",
	".....nwewen.....",
	".....nwyywn.....",
	"..nnnwwwwwwnnn..",
	".tTnwwwWWwwwnTt.",
	"tTTwwwWWWWwwwTTt",
	".tTnwWWWWWWwnTt.",
	"..tnwwWWWWwwnt..",
	"...nwwwwwwwwn...",
	"....nwwwwwwn....",
	".....nwwwwn.....",
	"......nyynn.....",
	".....ny..yn.....",
	"....ny....yn....",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t0: ImageTexture = PixelArt.grid_to_texture(_F0, PALETTE)
	var t1: ImageTexture = PixelArt.grid_to_texture(_F1, PALETTE)
	for anim in ["idle", "move", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 10.0)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, t0)
		sf.add_frame(anim, t1)
	return sf
