# 恶魔眼 sprite: 手画 16×16 ASCII pattern (用户改: 老 PNG 太丑).
# 黑描边 + 红血球 + 白虹膜 + 黑瞳孔 + 白闪光. Terraria 风的飘眼.
# 跟项目其他怪物 art 风格统一 (没外部 PNG).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(15, 15, 15),     # 黑描边 + 瞳孔
	"r": Color8(195, 35, 35),    # 血红主色
	"R": Color8(130, 18, 18),    # 暗红阴影
	"w": Color8(245, 235, 230),  # 白虹膜
	"g": Color8(255, 255, 255),  # 高光闪点
}

# 圆盘状眼睛, 11×11 直径居中 (用户改: 要更圆). 瞳孔正中带高光闪点
const _IDLE := [
	"................",
	"................",
	"................",
	"......nnnnn.....",
	"....nRRRRRRRn...",
	"...nRrrrrrrrRn..",
	"...nRrwwwwwrRn..",
	"...nRrwnnnwrRn..",
	"...nRrwngnwrRn..",
	"...nRrwnnnwrRn..",
	"...nRrwwwwwrRn..",
	"...nRrrrrrrrRn..",
	"....nRRRRRRRn...",
	"......nnnnn.....",
	"................",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: ImageTexture = PixelArt.grid_to_texture(_IDLE, PALETTE)
	# 跟其他怪 SpriteFrames 接口对齐: idle / move / attack 都用同一帧
	for anim in ["idle", "move", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 4.0)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, tex)
	return sf
