# 僵尸像素画: 16×24 帧.
# 动画: idle (呼吸 2 帧), walk (左右脚 2 帧).
# 配色: 暗绿皮 + 暗紫破衣 + 暗红眼.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"s": Color8(86, 130, 70),    # 皮基色 暗黄绿
	"S": Color8(54, 90, 48),     # 皮阴影
	"h": Color8(118, 158, 92),   # 皮高光
	"c": Color8(60, 40, 70),     # 破衣紫
	"C": Color8(38, 26, 50),     # 衣阴影
	"e": Color8(180, 30, 30),    # 眼红
	"k": Color8(20, 12, 18),     # 极深 (鞋/缝)
	"r": Color8(120, 30, 30),    # 锈/血红
}

# 站立 - 重心居中
const _IDLE_A := [
	"................",
	".....sssss......",
	"....shhhhhs.....",
	"....shsshss.....",
	"....sseeses.....",
	"....shhssss.....",
	".....sssss......",
	".....SsssS......",
	"....scccccs.....",
	"...sccCCccs.....",
	"...scccccccs....",
	"...sccccccrs....",
	"...sCcccccCc....",
	"....cccccccc....",
	"....cCccccCc....",
	"....ccccccc.....",
	"....cccccc......",
	"....sssssss.....",
	"....sssssss.....",
	"....ssssssss....",
	"....SS....SS....",
	"....SS....SS....",
	"....kk....kk....",
	"................",
]

# 站立 - 微微呼吸 (头微抬)
const _IDLE_B := [
	"................",
	"................",
	".....sssss......",
	"....shhhhhs.....",
	"....shsshss.....",
	"....sseeses.....",
	"....shhssss.....",
	".....sssss......",
	".....SsssS......",
	"....scccccs.....",
	"...sccCCccs.....",
	"...scccccccs....",
	"...sccccccrs....",
	"...sCcccccCc....",
	"....cccccccc....",
	"....cCccccCc....",
	"....ccccccc.....",
	"....cccccc......",
	"....sssssss.....",
	"....sssssss.....",
	"....SS....SS....",
	"....SS....SS....",
	"....kk....kk....",
	"................",
]

# 走 - 左脚前, 右脚后, 双臂前伸
const _WALK_A := [
	"................",
	".....sssss......",
	"....shhhhhs.....",
	"....shsshss.....",
	"....sseeses.....",
	"....shhssss.....",
	".sssssssss......",
	".shhhhhhSs......",
	".sssccccs.......",
	"....cccccs......",
	"...sccCCccs.....",
	"...scccccccs....",
	"...sccccccrs....",
	"...sCcccccCc....",
	"....cccccccc....",
	"....cCccccCc....",
	"....ccccccc.....",
	"....cccccc......",
	"....sssssss.....",
	"....sssssss.....",
	"...SS......SS...",
	"...SS......SS...",
	"...kk......kk...",
	"................",
]

# 走 - 右脚前, 左脚后, 双臂略垂
const _WALK_B := [
	"................",
	".....sssss......",
	"....shhhhhs.....",
	"....shsshss.....",
	"....sseeses.....",
	"....shhssss.....",
	".....sssss......",
	".....SsssS......",
	"....scccccs.....",
	"...sccCCccss....",
	"...sccccccchss..",
	"...sccccccrshs..",
	"...sCcccccCcsh..",
	"....cccccccc....",
	"....cCccccCc....",
	"....ccccccc.....",
	"....cccccc......",
	"....sssssss.....",
	"....sssssss.....",
	"....ssssssss....",
	".SS......SS.....",
	".SS......SS.....",
	".kk......kk.....",
	"................",
]


# 走 - 过渡 (双脚并拢居中 + 手臂收回): 夹在左伸/右伸之间, 手臂一摆一摆 = 4 帧蹒跚更连贯
const _WALK_PASS := [
	"................",
	".....sssss......",
	"....shhhhhs.....",
	"....shsshss.....",
	"....sseeses.....",
	"....shhssss.....",
	".....sssss......",
	".....SsssS......",
	"....scccccs.....",
	"...sccCCccs.....",
	"...scccccccs....",
	"...sccccccrs....",
	"...sCcccccCc....",
	"....cccccccc....",
	"....cCccccCc....",
	"....ccccccc.....",
	"....cccccc......",
	"....sssssss.....",
	"....sssssss.....",
	"....ssssssss....",
	".....SS..SS.....",
	".....SS..SS.....",
	".....kk..kk.....",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	return PixelArt.build_sprite_frames({
		"idle": {"frames": [_IDLE_A, _IDLE_B], "fps": 2.0, "loop": true},
		"walk": {"frames": [_WALK_A, _WALK_PASS, _WALK_B, _WALK_PASS], "fps": 6.0, "loop": true},
	}, PALETTE)
