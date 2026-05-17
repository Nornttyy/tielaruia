# 村民像素画：12×24 帧。
# 动画: idle (头左右轻摆 2 帧)。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"h": Color8(198, 40, 40),    # 红帽子
	"H": Color8(140, 20, 20),    # 帽子阴影
	"s": Color8(255, 204, 153),  # 皮肤
	"k": Color8(217, 168, 122),
	"e": Color8(26, 26, 26),
	"m": Color8(165, 80, 60),
	"r": Color8(25, 118, 210),   # 蓝袍
	"R": Color8(13, 71, 161),    # 袍阴影
	"o": Color8(93, 64, 55),     # 棕鞋
	"O": Color8(62, 39, 35),
}

# 帧 A: 头向左微倾
const _IDLE_A := [
	"............",
	"............",
	"...hhhh.....",
	"..HhhhhhH...",
	"...ssss.....",
	"..sseess....",
	"..ssmmss....",
	"..ssssss....",
	"...kssk.....",
	"...rrrrrr...",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rRrrrrRr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rRrrrrRr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rRrrrrRr..",
	"..RRRRRRRR..",
	"..oooooooo..",
	"..OOOOOOOO..",
]

# 帧 B: 头向右微倾
const _IDLE_B := [
	"............",
	"............",
	".....hhhh...",
	"...Hhhhhhh..",
	".....ssss...",
	"....sseess..",
	"....ssmmss..",
	"....ssssss..",
	".....kssk...",
	"...rrrrrr...",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rRrrrrRr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rRrrrrRr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rrrrrrrr..",
	"..rRrrrrRr..",
	"..RRRRRRRR..",
	"..oooooooo..",
	"..OOOOOOOO..",
]


static func build_sprite_frames() -> SpriteFrames:
	return PixelArt.build_sprite_frames({
		"idle": {"frames": [_IDLE_A, _IDLE_B], "fps": 1.5, "loop": true},
	}, PALETTE)
