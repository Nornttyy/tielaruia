# 木乃伊 (Mummy): 金字塔守卫. 绷带缠裹 + 红眼 + 蹒跚步伐.
# 2 帧 (idle/walk), attack 复用 walk (举手扑过来).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(35, 25, 15),     # 黑描边
	"b": Color8(230, 215, 170),  # 绷带主色 (沙土米黄)
	"B": Color8(175, 155, 115),  # 绷带阴影
	"l": Color8(250, 240, 200),  # 绷带高光
	"r": Color8(225, 55, 55),    # 红眼瞳
	"R": Color8(150, 25, 35),    # 红眼暗
	"k": Color8(55, 35, 20),     # 绷带间隙 (黑棕)
	"d": Color8(20, 10, 8),      # 眼窝黑深
}

# idle: 直立, 双臂下垂, 红眼瞪人
const _IDLE := [
	"................",
	".......nnn......",
	"......nbbbn.....",
	".....nbBBBbn....",
	"....nbblrlBbn...",   # 头, 红眼 r
	"....nbBrlrBbn...",   # 鼻 + 红眼
	"....nbBBBBBbn...",   # 颊 + 嘴
	".....nbbBbbn....",   # 脖
	"....nbBlBlBbn...",   # 胸 (绷带交叉)
	"....nbBBlBBbn...",
	"....nbblBlbbn...",
	"....nbBBkBBbn...",   # 腰带 (k = 绷带带子)
	"....nbBlBlBbn...",   # 腿上段
	"....nbBBBBBbn...",
	"....nbbn.nbbn...",   # 双腿
	"....nkn...nkn...",   # 脚踝 (绷带带子)
]

# walk: 头微低 + 一脚抬起 + 手臂前伸 (扑姿势)
const _WALK := [
	"................",
	".......nnn......",
	"......nbbbn.....",
	".....nbBBBbn....",
	"....nbblrlBbn...",
	"....nbBrlrBbn...",
	"....nbBBBBBbn...",
	"....nbbBbbn.....",
	"...nbBlBlBbn....",   # 手向前伸
	"..nblBBlBBbn....",   # 一手出
	"..nbbblBlbbn....",
	"....nbBkBBbn....",   # 腰带歪
	"....nbBlBBbn....",
	"....nbBBBbbn....",
	"....nbb.nbbn....",   # 一腿抬, 一腿落
	"....nkn...nkn...",
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
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 4.0)   # 慢走
	sf.set_animation_loop("walk", true)
	sf.add_frame("walk", idle_tex)
	sf.add_frame("walk", walk_tex)
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 5.0)
	sf.set_animation_loop("attack", true)
	sf.add_frame("attack", walk_tex)
	return sf
