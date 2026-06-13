# 死人箱 (Mimic) sprite art. 跟 zombie/spider 一样手画 ASCII pattern, 单帧 SpriteFrames.
# 2 帧动画: idle = 看起来像普通宝箱 (但锁眼是红的, 仔细看才发现);
#         attack = 嘴张开露出尖牙 + 红色内膛 (玩家进 aggro 后切换).
# walk 复用 attack (mimic 跑起来嘴一直张着).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(40, 25, 15),    # 黑描边
	"w": Color8(168, 116, 69),  # 木板主色
	"W": Color8(141, 93, 53),   # 木板阴影
	"l": Color8(208, 158, 110), # 木板高光
	"m": Color8(218, 165, 80),  # 黄铜包角
	"M": Color8(150, 105, 40),  # 黄铜阴影
	"o": Color8(60, 35, 20),    # 锁孔 (普通箱用)
	"r": Color8(220, 35, 35),   # 红眼 / 嘴内红
	"R": Color8(140, 18, 18),   # 嘴内深红
	"t": Color8(250, 245, 230), # 尖牙白
	"e": Color8(255, 240, 100), # 眼睛黄 (attack 模式)
}

# idle: 闭嘴, 看起来像宝箱 — 唯一线索是锁眼颜色红, 不仔细看会以为是普通锁
const _IDLE := [
	"................",
	"................",
	".nnnnnnnnnnnnnn.",
	".nmmwwwwwwwwmmn.",
	".nmwlwwwwwwlwmn.",
	".nmwwwwwwwwwwmn.",
	".nnnnnnnnnnnnnn.",
	".nwwwwwmmwwwwwn.",
	".nwlwwwmrmwwwln.",
	".nwwwwwmmwwwwwn.",
	".nwwwwwwwwwwwwn.",
	".nwlwwwwwwwwwln.",
	".nWWwwwwwwwwWWn.",
	".nmmwwwwwwwwmmn.",
	".nnnnnnnnnnnnnn.",
	"..nn........nn..",
]

# attack: 盖子掀开露出红色血盆大口 + 上下排尖牙. 红眼睛黄瞳孔从盖子内冒出
const _ATTACK := [
	"..nnnnnnnnnnnn..",
	".nmmRRRRRRRRmmn.",
	".nmRrrrrrrrrrmn.",
	".nmRrtttttttRmn.",
	".nmRrrrrrrrrRmn.",
	".nnnRRRRRRRRnnn.",
	".nwwwerrrrewwwn.",
	".nwlwerrrrewwwn.",
	".nwwwerrrrewwwn.",
	".nwwwwwttwwwwwn.",
	".nwlwwwwwwwwwln.",
	".nWWwwwwwwwwWWn.",
	".nmmwwwwwwwwmmn.",
	".nnnnnnnnnnnnnn.",
	"..nn........nn..",
	"..nn........nn..",
]

# attack 半合: 嘴咬下来 (红膛变薄, 上下牙快咬合) — 跟 _ATTACK 轮播 = 一咬一咬
const _ATTACK_MID := [
	"................",
	"..nnnnnnnnnnnn..",
	".nmmRRRRRRRRmmn.",
	".nmRrtttttttRmn.",
	".nnnRRRRRRRRnnn.",
	".nwwwerrrrewwwn.",
	".nwlwerrrrewwwn.",
	".nwwwwwttwwwwwn.",
	".nwwwwwwwwwwwwn.",
	".nwlwwwwwwwwwln.",
	".nWWwwwwwwwwWWn.",
	".nmmwwwwwwwwmmn.",
	".nnnnnnnnnnnnnn.",
	"..nn........nn..",
	"..nn........nn..",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var idle_tex: ImageTexture = PixelArt.grid_to_texture(_IDLE, PALETTE)
	var attack_tex: ImageTexture = PixelArt.grid_to_texture(_ATTACK, PALETTE)
	var attack_mid_tex: ImageTexture = PixelArt.grid_to_texture(_ATTACK_MID, PALETTE)
	# idle: 闭着 (玩家进 aggro 前)
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", idle_tex)
	# walk + attack: 张嘴扑 + 一咬一咬 (大张 ↔ 半合 轮播)
	for anim in ["walk", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 6.0)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, attack_tex)
		sf.add_frame(anim, attack_mid_tex)
	return sf
