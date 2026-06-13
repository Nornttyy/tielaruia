# 火魔 (Imp) art: 小型飞行恶魔. 红身 + 角 + 蝙蝠翅膀 + 黄眼 + 黑描边.
# 2 帧动画 (翅膀拍动). idle/move 用 2 帧轮播; attack 同 move.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(28, 12, 12),     # 黑描边
	"r": Color8(190, 40, 35),    # 红身主
	"R": Color8(130, 25, 22),    # 暗红阴影
	"l": Color8(225, 70, 50),    # 红高光
	"y": Color8(255, 215, 70),   # 黄眼
	"k": Color8(60, 25, 20),     # 翅膀脉络深红黑
	"o": Color8(255, 110, 50),   # 嘴/角橙红高光
}

# 飞行帧 1: 翅膀往下
const _F0 := [
	"................",
	"......n..n......",   # 头顶 2 个小角
	".....nrn.nrn....",
	".....nrrnrrn....",
	"....nrrlrlrrn...",   # 头 + l 高光
	"....nrynryrn....",   # 黄眼
	"....nrrnnrrrn...",   # 嘴
	"....nrronrrrn...",   # o = 嘴里橙红
	".....nrrrrnn....",   # 下巴 / 脖子
	"...nknrrrrnkn...",   # k = 翅膀根
	"..nkkk.rrr.kkkn.",   # 翅膀展开 (空隙用 . 透明, 用户检查时改对了)
	"..nkkkkrrkkkkkn.",
	"...nkkkRRkkkkn..",   # 翅膀往下
	"....nkkkRkkn....",
	".....nrrrrn.....",   # 脚
	".....nn..nn.....",
]

# 飞行帧 2: 翅膀往上
const _F1 := [
	"..nkn........nkn",   # 翅膀拍到顶
	".nkkkn..n..nkkkn",
	"..nkkknnrnnkkkn.",
	"....nrn.nrn.....",   # 头 + 角
	"....nrrnrrn.....",
	"....nrrlrlrn....",
	"....nrynryrn....",   # 眼
	"....nrrnnrrrn...",   # 嘴
	"....nrronrrrn...",
	".....nrrrrnn....",
	"......nrrrrn....",
	"......nrrrrrn...",
	".......nrrrn....",
	".......nrrn.....",
	".....nrrnnrrn...",   # 脚
	"....n.....n.....",
]


# 飞行帧 M: 翅膀平展 (上↔下 之间), 夹进去 = 上→平→下→平 4 帧拍翅, 更顺
const _FM := [
	"................",
	"......n..n......",
	".....nrn.nrn....",
	".....nrrnrrn....",
	"....nrrlrlrrn...",
	"....nrynryrn....",
	"....nrrnnrrrn...",
	"....nrronrrrn...",
	".....nrrrrnn....",
	"nkkknrrrrnkkkn..",
	".nkkkkrrkkkkn...",
	"...nknrrrnkn....",
	"....nrrrrn......",
	".....nrrn.......",
	".....nrrrrn.....",
	".....nn..nn.....",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t0: ImageTexture = PixelArt.grid_to_texture(_F0, PALETTE)
	var tm: ImageTexture = PixelArt.grid_to_texture(_FM, PALETTE)
	var t1: ImageTexture = PixelArt.grid_to_texture(_F1, PALETTE)
	for anim in ["idle", "move", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 8.0)
		sf.set_animation_loop(anim, true)
		for fr in [t1, tm, t0, tm]:
			sf.add_frame(anim, fr)
	return sf
