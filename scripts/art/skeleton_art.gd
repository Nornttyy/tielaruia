# 骨架战士 (Skeleton Warrior): 地狱近战怪. 白骨身 + 红眼 + 拿短剑.
# 2 帧动画 (idle / walk), attack 复用 walk (举剑挥的姿势已经在 walk 里).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(22, 18, 20),     # 黑描边
	"b": Color8(232, 228, 215),  # 白骨主
	"B": Color8(180, 175, 160),  # 骨阴影
	"H": Color8(248, 245, 235),  # 骨高光
	"r": Color8(225, 35, 30),    # 红眼 + 武器红
	"R": Color8(140, 18, 15),    # 暗红
	"s": Color8(95, 95, 110),    # 剑铁
	"S": Color8(150, 150, 170),  # 剑高光
	"k": Color8(45, 30, 18),     # 剑柄棕
}

# 站立: 头骨 (空眼眶+红眼) + 肋骨 + 手 + 短剑垂直握
const _IDLE := [
	"................",
	".......nnn......",
	"......nbbbn.....",
	".....nbHHbn.....",
	".....nbrnrbn....",   # 眼眶 + 红眼 r
	".....nbHnnb.....",   # 鼻
	"......nbbn......",
	"......nbnn......",
	".....nbbbbn.....",
	"....nbBbBbbn....",
	"....nbBbBbbn.s..",   # 肋骨 + 剑刃靠右
	"....nbBbBbbnSs..",
	"......nbbnnnsk..",   # 剑柄
	"......nbbn..ks..",
	".....nbbbbn.....",
	".....nb..bn.....",
]

# 走步: 头微低 + 抬腿 + 剑挥
const _WALK := [
	"................",
	"................",
	".......nnn......",
	"......nbbbn.....",
	".....nbHHbn.....",
	".....nbrnrbn....",
	".....nbHnnb.....",
	"......nbbn......",
	"......nbnn..sS..",   # 剑挥起
	".....nbbbbnSss..",
	"....nbBbBbbnSk..",
	"....nbBbBbbnnsk.",
	"......nbbn......",
	".....nbbnbn.....",   # 一腿向前
	"....nb...bn.....",
	".....n....n.....",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var idle_tex: ImageTexture = PixelArt.grid_to_texture(_IDLE, PALETTE)
	var walk_tex: ImageTexture = PixelArt.grid_to_texture(_WALK, PALETTE)
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", idle_tex)
	# walk: 用 idle + walk 两帧轮播
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 6.0)
	sf.set_animation_loop("walk", true)
	sf.add_frame("walk", idle_tex)
	sf.add_frame("walk", walk_tex)
	# attack: 同 walk (举剑动作已在 walk 里)
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 6.0)
	sf.set_animation_loop("attack", true)
	sf.add_frame("attack", walk_tex)
	return sf
