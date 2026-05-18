# 玩家像素画：12×24 帧。
# 动画: idle (呼吸 bob 2 帧)、walk (步态 4 帧)、jump (蹲腿 1 帧)、fall (展开 1 帧)。
# 朝向用 Sprite2D.flip_h 在运行时处理，本文件只画"面向右"的版本。
#
# 用法:
#   var sf = PlayerArt.build_sprite_frames()
#   animated_sprite_2d.sprite_frames = sf
#   animated_sprite_2d.play("idle")
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"h": Color8(121, 85, 72),    # 头发暖棕
	"H": Color8(78, 52, 46),     # 头发阴影
	"s": Color8(255, 218, 185),  # 皮肤 (略亮)
	"k": Color8(217, 168, 122),  # 皮肤阴影
	"e": Color8(20, 20, 20),     # 眼睛
	"m": Color8(200, 80, 80),    # 嘴
	"w": Color8(229, 57, 53),    # 衬衫红
	"W": Color8(183, 28, 28),    # 衬衫红阴影
	"b": Color8(38, 70, 130),    # 裤子深蓝 (牛仔感)
	"B": Color8(19, 47, 90),     # 裤子阴影
	"o": Color8(74, 47, 26),     # 靴棕
	"O": Color8(48, 30, 15),     # 靴阴影
}

# 基础站姿 (脚踏地面在 row 23)
const _IDLE_A := [
	"............",
	"....hHhh....",
	"...HsssssH..",
	"...hsssssh..",
	"...hsesesh..",
	"...ksssssk..",
	"...ssmmss...",
	"....skss....",
	"...wwwwww...",
	"..wWwwwwWw..",
	"..wwwwwwww..",
	"..wwwwwwww..",
	"..wWwwwwWw..",
	"...wwwwww...",
	"...wwwwww...",
	"..bbbbbbbb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..bBb..bBb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..ooo..ooo..",
	"..OOO..OOO..",
]

# 呼吸 bob：整体下沉 1 像素 (顶部空 1 行，鞋仍贴地)
const _IDLE_B := [
	"............",
	"............",
	"....hHhh....",
	"...HsssssH..",
	"...hsssssh..",
	"...hsesesh..",
	"...ksssssk..",
	"...ssmmss...",
	"....skss....",
	"...wwwwww...",
	"..wWwwwwWw..",
	"..wwwwwwww..",
	"..wwwwwwww..",
	"..wWwwwwWw..",
	"...wwwwww...",
	"...wwwwww...",
	"..bbbbbbbb..",
	"..bbb..bbb..",
	"..bBb..bBb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..ooo..ooo..",
	"..OOO..OOO..",
]

# Walk A (左脚向前, 右脚向后)：左腿稍短 (鞋上移 1)，右腿正常
const _WALK_A := [
	"............",
	"....hHhh....",
	"...HsssssH..",
	"...hsssssh..",
	"...hsesesh..",
	"...ksssssk..",
	"...ssmmss...",
	"....skss....",
	"...wwwwww...",
	"..wWwwwwWw..",
	"..wwwwwwww..",
	"..wwwwwwww..",
	"..wWwwwwWw..",
	"...wwwwww...",
	"...wwwwww...",
	"..bbbbbbbb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..bBb..bBb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..ooo..bbb..",
	"..OOO..bbb..",
	".......OOO..",
]

# Walk B (中性)：同 idle_a
const _WALK_B := _IDLE_A

# Walk C (右脚向前, 左脚向后)：右腿稍短
const _WALK_C := [
	"............",
	"....hHhh....",
	"...HsssssH..",
	"...hsssssh..",
	"...hsesesh..",
	"...ksssssk..",
	"...ssmmss...",
	"....skss....",
	"...wwwwww...",
	"..wWwwwwWw..",
	"..wwwwwwww..",
	"..wwwwwwww..",
	"..wWwwwwWw..",
	"...wwwwww...",
	"...wwwwww...",
	"..bbbbbbbb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..bBb..bBb..",
	"..bbb..bbb..",
	"..bbb..bbb..",
	"..bbb..ooo..",
	"..bbb..OOO..",
	"..OOO.......",
]

# 跳跃：腿收起、手臂略上扬
const _JUMP := [
	"............",
	"....hHhh....",
	"...HsssssH..",
	"...hsssssh..",
	"...hsesesh..",
	"...ksssssk..",
	"...ssmmss...",
	"....skss....",
	".s.wwwwww.s.",   # 手臂上抬
	".sWwwwwwwWs.",
	"..wwwwwwww..",
	"..wwwwwwww..",
	"..wWwwwwWw..",
	"...wwwwww...",
	"...wwwwww...",
	"..bbbbbbbb..",
	"..bbbbbbbb..",
	"..bBbbbbBb..",
	"...bbbbbb...",
	"...bbbbbb...",
	"....bbbb....",
	"....oOOo....",
	"....OOOO....",
	"............",
]

# 下落：身体张开
const _FALL := [
	"............",
	"....hHhh....",
	"...HsssssH..",
	"...hsssssh..",
	"...hsesesh..",
	"...ksssssk..",
	"...ssmmss...",
	"....skss....",
	"s..wwwwww..s",   # 手臂下垂展开
	"sWwwwwwwwwWs",
	"..wwwwwwww..",
	"..wwwwwwww..",
	"..wWwwwwWw..",
	"...wwwwww...",
	"...wwwwww...",
	"..bbbbbbbb..",
	".bbb....bbb.",
	".bbb....bbb.",
	".bBb....bBb.",
	".bbb....bbb.",
	".bbb....bbb.",
	".bbb....bbb.",
	".ooo....ooo.",
	".OOO....OOO.",
]


static func build_sprite_frames() -> SpriteFrames:
	return PixelArt.build_sprite_frames({
		"idle": {"frames": [_IDLE_A, _IDLE_B], "fps": 2.0, "loop": true},
		"walk": {"frames": [_WALK_A, _WALK_B, _WALK_C, _WALK_B], "fps": 10.0, "loop": true},
		"jump": {"frames": [_JUMP], "fps": 1.0, "loop": false},
		"fall": {"frames": [_FALL], "fps": 1.0, "loop": false},
	}, PALETTE)
