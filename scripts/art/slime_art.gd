# 史莱姆像素画：16×12 帧。
# 动画: idle (呼吸 2 帧)、hop (蓄力→起跳→腾空→落地 4 帧)。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"g": Color8(70, 130, 205),   # 基色蓝
	"G": Color8(40, 90, 160),    # 阴影 (深蓝)
	"h": Color8(125, 180, 235),  # 高光 (浅蓝)
	"e": Color8(26, 26, 26),     # 眼
}

const _IDLE_A := [
	"................",
	"......gggg......",
	"....ghhhhhhg....",
	"...gggggggggg...",
	"..gggggggggggg..",
	"..ggeeggggeegg..",
	"..ggeeggggeegg..",
	"..gggggggggggg..",
	"..gggggggggggg..",
	"..gGgggggggggGg.",
	"...GGGGGGGGGG...",
	"................",
]

# 呼吸：略微压扁
const _IDLE_B := [
	"................",
	"................",
	".....ghhhhhg....",
	"...ggggggggggg..",
	"..gggggggggggg..",
	"..gggggggggggg..",
	"..ggeeggggeegg..",
	"..ggeeggggeegg..",
	"..gggggggggggg..",
	"..gGgggggggggGg.",
	"...GGGGGGGGGG...",
	"................",
]

# Hop 帧 0: 蓄力 (压扁)
const _HOP_ANTICIPATE := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"....ghhhhhhhh...",
	"..gggggggggggg..",
	".ggeegggggggeeg.",
	".gGGGGGGGGGGGGg.",
	"..GGGGGGGGGGGG..",
	"...GGGGGGGGGG...",
	"................",
]

# Hop 帧 1: 起跳 (拉长)
const _HOP_TAKEOFF := [
	"................",
	".....ghhhhg.....",
	"....gggggggg....",
	"...gggggggggg...",
	"...ggeeggeegg...",
	"...ggeeggeegg...",
	"...gggggggggg...",
	"...gggggggggg...",
	"....gggggggg....",
	"....gGGGGGGg....",
	".....GGGGGG.....",
	"................",
]

# Hop 帧 2: 腾空 (球形)
const _HOP_AIRBORNE := [
	"................",
	"......gggg......",
	"....ghhhhhhg....",
	"...gggggggggg...",
	"..gggggggggggg..",
	"..ggeeggggeegg..",
	"..gggggggggggg..",
	"..gggggggggggg..",
	"..gGGgggggggGGg.",
	"...GGGGGGGGGG...",
	"................",
	"................",
]

# Hop 帧 3: 落地 (再压扁一次)
const _HOP_LAND := _HOP_ANTICIPATE


# 史莱姆王专属王冠 (16×8). 单独一张图, 贴在王头顶 — 自己的金色, 不受身体染蓝/受击闪红影响.
# 3 个尖顶 (各 2 px) + 红宝石尖 + 带高光阴影的金底座 + 3 颗内嵌红宝石.
const CROWN_PALETTE := {
	".": Color(0, 0, 0, 0),
	"y": Color8(232, 190, 72),    # 金 (暖色)
	"Y": Color8(255, 226, 130),   # 金高光
	"G": Color8(168, 124, 44),    # 金阴影
	"O": Color8(214, 58, 72),     # 红宝石
}

const _CROWN := [
	"...OO..OO..OO...",
	"...yy..yy..yy...",
	"...yy..yy..yy...",
	"...yy..yy..yy...",
	"...YyyyyyyyyG...",
	"...yOyyOyyOyy...",
	"...yyyyyyyyyy...",
	"...GGGGGGGGGG...",
]


static func build_crown_texture() -> ImageTexture:
	return PixelArt.grid_to_texture(_CROWN, CROWN_PALETTE)


static func build_sprite_frames() -> SpriteFrames:
	return PixelArt.build_sprite_frames({
		"idle": {"frames": [_IDLE_A, _IDLE_B], "fps": 2.5, "loop": true},
		"hop": {"frames": [_HOP_ANTICIPATE, _HOP_TAKEOFF, _HOP_AIRBORNE, _HOP_LAND], "fps": 8.0, "loop": false},
	}, PALETTE)
