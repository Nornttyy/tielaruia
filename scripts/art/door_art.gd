# 门像素画：16×32 (2 tile 高) 用于 Door scene 的 Sprite2D。
# 注意区分：blocks_art.gd 里的 _DOOR_CLOSED 是 16×16 的"图标 / TileMap 缩略"，
# 而这里是放置后玩家看到的完整门 (双 tile)。
#
# 动画: closed / open 两个静态帧；切换由 Door scene 在交互时 set。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"d": Color8(109, 76, 65),    # 门板
	"D": Color8(78, 52, 46),     # 门框/纹路
	"l": Color8(141, 110, 99),   # 高光
	"h": Color8(200, 200, 200),  # 把手金属
	"w": Color8(180, 220, 240),  # 小窗 (玻璃)
}

const _CLOSED := [
	"DDDDDDDDDDDDDDDD",
	"DllllllllllllllD",
	"DlDDDDDDDDDDDDlD",
	"DlDddddddddddDlD",
	"DlDdwwwwwwwwdDlD",
	"DlDdwddddddwdDlD",
	"DlDdwwwwwwwwdDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDDDDDDDDDDDDlD",
	"DllllllllllllllD",
	"DDDDDDDDDDDDDDDD",
	"DDDDDDDDDDDDDDDD",
	"DllllllllllllllD",
	"DlDDDDDDDDDDDDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddhhddddddDlD",
	"DlDddhhddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDDDDDDDDDDDDlD",
	"DllllllllllllllD",
	"DDDDDDDDDDDDDDDD",
	"DDDDDDDDDDDDDDDD",
]

# 打开：门旋向左侧，仅左侧 4 px 显示门体；其余 12 px 是空气，玩家可穿过
const _OPEN := [
	"DDDD............",
	"DlllD...........",
	"DlDDD...........",
	"Dlddl...........",
	"Dlddw...........",
	"Dldwd...........",
	"Dlddw...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"DlDDD...........",
	"DlllD...........",
	"DDDD............",
	"DDDD............",
	"DlllD...........",
	"DlDDD...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddh...........",
	"Dlddh...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"Dlddl...........",
	"DlDDD...........",
	"DlllD...........",
	"DDDD............",
	"DDDD............",
]


static func get_closed_texture() -> ImageTexture:
	return PixelArt.grid_to_texture(_CLOSED, PALETTE)


static func get_open_texture() -> ImageTexture:
	return PixelArt.grid_to_texture(_OPEN, PALETTE)
