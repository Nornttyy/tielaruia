# 玩家像素画: 泰拉瑞亚式 **侧面** 小人 (16×26)。朝右 (flip_h 朝左)。
# 一只眼 (眼白 W + 眼珠 i), 没嘴, 又大又蓬松的头发, 矮壮 Q 版比例 (头大腿短)。
# 按 CharacterData.appearance_dict() 分层拼: 腿(裤+鞋) → 脸 → 衬衫 → 手臂 → 头发。
# 1px 黑描边 (最后一步整体描)。站着轻微呼吸 (上半身下沉 1px); 走路两腿前后迈 + 一只手摆。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")
const W := 16
const H := 26

const DEFAULT_APPEARANCE := {
	"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
	"cape_style": 0, "chest_size": 3,
	"skin_color": Color8(255, 218, 185), "hair_color": Color8(190, 110, 60),
	"shirt_color": Color8(220, 210, 180), "pants_color": Color8(70, 90, 150),
	"cape_color": Color8(150, 40, 50), "eye_color": Color8(70, 110, 170),
	"shoe_color": Color8(74, 47, 26),
}

const _SHOE := Color8(74, 47, 26)
const _SHOE_SH := Color8(48, 30, 15)
const _WHITE := Color(0.98, 0.98, 1.0, 1)
const _OUTLINE := Color8(30, 26, 30)

# ---- 摆放坐标 (composite 16×26; 行 0 顶, 行 25 脚底) ----
const _FACE_TOP := 3
const _FACE_LEFT := 4
const _HAIR_TOP := 0
const _HAIR_LEFT := 1
const _TORSO_TOP := 13
const _TORSO_LEFT := 5
const _HIP := 19          # 腿顶 (胯) 所在行

# ---- 积木块 ----
# 侧脸 (朝右): 眼睛在前 (右) 侧。s 皮肤 / k 阴影 / W 眼白 / i 眼珠。9 宽 × 10 高。
const _FACE := [
	"...ssss..",
	".sssssss.",
	"sssssssss",
	"sssssssss",
	"ssssssWis",   # 眼 (2宽×2高): 左上 1px 白点 W + 其余眼珠 i (填满眼珠, 非震惊眼)
	"ssssssiis",   # 眼珠填满 (后下白点换成眼珠)
	"sssssssss",   # 眼调矮: 去掉第3行眼 → 眼 2宽×2高 (扁一点)
	"sssssssks",   # 脸颊 + 前下颌一点阴影
	"..sssss..",
	"...sss...",   # 脖子
]
# 女脸: 跟男款同款眼 (用户要求去睫毛); 女性区分靠身材/胸, 不靠脸。眼=后列白眼白+前列眼珠, 2宽×2高。
const _FACE_F := [
	"...ssss..",
	".sssssss.",
	"sssssssss",
	"sssssssss",
	"ssssssWis",   # 左上 1px 白点 W + 眼珠 i — 去睫毛, 同男款
	"ssssssiis",   # 眼珠填满 (后下白点换成眼珠)
	"sssssssss",   # 眼调矮: 去掉第3行眼 → 眼 2宽×2高 (扁一点)
	"sssssssks",
	"..sssss..",
	"...sss...",
]

# 大蓬松短发 (盖头顶 + 后脑 + 前额留眼): h 主色 / H 阴影 / 顶 gg 小高光。14 宽 × 11 高。
const _HAIR_SHORT := [
	"....hhhhhh....",
	"..hhhgghhhhh..",
	".hhhhgghhhhhh.",
	"hhhhhgghhhhhh.",
	"hhhhhhhhhhhhhh",
	"hhhhhhhhhhhhh.",
	"hhhhhhhhhhhh..",
	"Hhhhhhhh...hh.",   # 后+顶留发, 中间空出眼睛, 前一缕刘海
	"Hhhhhhh.......",
	".HHhhh........",
	"..HHh.........",
]
# 长发: 同顶, 后脑一大片垂到腰。14 宽 × 16 高。
const _HAIR_LONG := [
	"....hhhhhh....",
	"..hhhgghhhhh..",
	".hhhhgghhhhhh.",
	"hhhhhgghhhhhh.",
	"hhhhhhhhhhhhhh",
	"hhhhhhhhhhhhh.",
	"hhhhhhhhhhhh..",
	"hhhhhhhh...hh.",
	"hhhhhhh.......",
	"hhhhhhh.......",
	"hhhhhh........",
	"hhhhhh........",
	"hhhhhH........",
	"hhhhhH........",
	"Hhhhh.........",
	".HHhh.........",
]
# 马尾: 短发 + 后脑伸出一束 (尾巴另块拼)。
const _HAIR_PONY := [
	"....hhhhhh....",
	"..hhhgghhhhh..",
	".hhhhgghhhhhh.",
	"hhhhhgghhhhhh.",
	"hhhhhhhhhhhhhh",
	"hhhhhhhhhhhhh.",
	"hhhhhhhhhhhh..",
	"HHhhhhhh...HH.",
	"HHHhhhh.......",
	".HHHhh........",
	"..HHh.........",
]
const _PONY_TAIL := [   # 后脑扎起垂下的一束 (拼在后脑外侧)
	"hh.",
	"hhh",
	"hhh",
	"Hhh",
	"hhh",
	"HHh",
	".h.",
]
# 呆毛: 顶上炸开几撮 (尖刺顶)。
const _HAIR_AHOGE := [
	"...h.hh.h.h..",
	"..hhhgghhhhh..",
	".hhhhgghhhhhh.",
	"hhhhhgghhhhhh.",
	"hhhhhhhhhhhhhh",
	"hhhhhhhhhhhhh.",
	"hhhhhhhhhhhh..",
	"HHhhhhhh...HH.",
	"HHHhhhh.......",
	".HHHhh........",
	"..HHh.........",
]

# 女性专属: 短发/呆毛补的后发 (垂到肩下, 让短发也有女生长度)。3 宽 × 7 高, 拼在后脑外侧。
const _BACKLOCK_F := [
	"hhh",
	"hhh",
	"hhh",
	"Hhh",
	"Hhh",
	".Hh",
	".H.",
]

# 干净衬衫 (用户要求删缝): 无后背竖缝/无内部暗纹, 只留领口 + 2 颗纽扣 + 前缘高光 c。
# 细节放可见区 (中间 col3-4 被手臂挡, 不放细节)。7 宽 × 6 高。
const _TORSO := [
	".wwwDDc",   # 领口 DD + 前缘高光 c
	"wwwwwDc",   # 纽扣 D + 前高光 c (后背改平, 无缝)
	"wwwwwwc",   # 光面 (去内部暗缝)
	"wwwwwDc",   # 纽扣 D + 前高光 c
	"wwwwwwc",   # 光面
	".wwwww.",   # 下摆 (平, 去深阴缝)
]
# 手臂 (袖子+手), 垂在身体前。后缘深 D + 前缘亮 c; 手腕一道袖口 cc (凸起)。2 宽 × 6 高。
const _ARM := [
	"Dc",
	"Dc",
	"Dc",
	"cc",
	"ks",
	"kk",
]
# 单腿 (裤 b / 阴影 B / 高光 P)。删外侧裤缝 A → 平裤腿, 只留前缘高光 P + 轻膝褶。3 宽 × 4 高。
const _LEG := [
	"bbP",
	"bBP",
	"bbP",
	"bbb",
]
# 女款细腿 (2 宽, 苗条): 长裤 / 裙下裸腿 / 泳裤 各一版。删外侧裤缝, 只留前高光 P。
const _LEG_F := [
	"bP",
	"bP",
	"bP",
	"bb",
]
const _LEG_SKIN_F := [
	"kp",
	"sp",
	"ks",
	"ks",
]
const _LEG_TRUNK_F := [
	"bP",
	"bP",
	"bP",
	"bb",
]
# 侧鞋 (o / O / 高光 q)。鞋面加鞋带 q。3 宽 × 3 高 (= 腿宽, 不显大)。
const _SHOE_B := [
	"oq.",
	"qoq",
	"OOO",
]
# 光脚 (泳裤时用)。实心脚: 脚背高光 p。删脚底那排(用户要求)。腿被泳裤盖住, 脚是唯一裸皮肤。3 宽 × 2 高。
const _FOOT_BARE := [
	"sp.",
	"sss",
]
# 背心款手臂 (露胳膊, 全皮肤 + 前缘高光 p)。2 宽 × 6 高。
const _ARM_BARE := [
	"sp",
	"sp",
	"ks",
	"ks",
	"sp",
	"kk",
]
# 裙子款的裸腿 (皮肤色 + 前缘高光 p + 后缘阴影 k)。3 宽 × 4 高。
const _LEG_SKIN := [
	"ksp",
	"ksp",
	"kss",
	"kss",
]
# 裙子 (裤色 b 梯形 + 平裙身, 删竖褶缝 + 前高光P + 下摆软角B)。9 宽 × 3 高。
const _SKIRT := [
	".bbbbbbP.",
	"bbbbbbbPb",
	"BbbbbbbPB",
]
# 女三角裤🩲 (比基尼底): 腰带→收窄→裆, 倒三角, 裸腿从两侧+下面露出。裤色 b。6 宽 × 3 高, 放 col5 row_HIP。
const _BIKINI_BOTTOM := [
	"BbbbbP",
	".BbbP.",
	"..bb..",
]
# 泳裤款的腿 (全长盖腿 b + 前缘高光 P; 只脚裸露=跟鞋一样分明, 不再裸腿糊成一条)。3 宽 × 4 高。
const _LEG_TRUNK := [
	"bbP",
	"bBP",
	"bbP",
	"bbb",
]
# 泳衣款男躯干 (光膀子: 皮肤胸膛 + 前缘高光 p + 侧/锁骨阴影 k + 肚脐, 男生只穿泳裤)。7 宽 × 6 高。
const _TORSO_SWIM := [
	".kssss.",
	"kssssps",
	"kssssps",
	".kssss.",
	".sskss.",
	"..sss..",
]


static func build_sprite_frames(appearance: Dictionary = DEFAULT_APPEARANCE) -> SpriteFrames:
	var pal := _palette_from(appearance)
	var anims := {
		"idle": {"frames": [_frame(appearance, "idle_a"), _frame(appearance, "idle_b")], "fps": 2.0, "loop": true},
		"walk": {"frames": [_frame(appearance, "walk_a"), _frame(appearance, "walk_b"), _frame(appearance, "walk_c"), _frame(appearance, "walk_b")], "fps": 10.0, "loop": true},
		# 跳跃 2 帧: 蹬地起跳 → 腾空收腿举手 (一次性, 上升时播完停在腾空帧)
		"jump": {"frames": [_frame(appearance, "jump_a"), _frame(appearance, "jump_b")], "fps": 10.0, "loop": false},
		"fall": {"frames": [_frame(appearance, "fall")], "fps": 1.0, "loop": false},
		"hurt": {"frames": [_frame(appearance, "hurt")], "fps": 1.0, "loop": false},
		# 动作: 挥击 (蓄力→挥下) / 放置 (抬手→伸手). 一次性, 由 player_controller 触发后短暂盖住站/走。
		"swing": {"frames": [_frame(appearance, "swing_a"), _frame(appearance, "swing_b")], "fps": 13.0, "loop": false},
		"place": {"frames": [_frame(appearance, "place_a"), _frame(appearance, "place_b")], "fps": 11.0, "loop": false},
	}
	return PixelArt.build_sprite_frames(anims, pal)


static func _frame(ap: Dictionary, pose: String) -> Array:
	var dy := 0
	if pose == "idle_b":
		dy = 1     # idle_b 上半身下沉 1px = 呼吸
	elif pose == "walk_b":
		dy = -1    # walk_b 过渡帧上半身抬 1px = 走路上下起伏 (更自然)
	elif pose == "jump_b":
		dy = -1    # jump_b 腾空: 上半身再拔高 1px = 跃起的舒展感
	var layers := [
		_legs_layer(ap, pose),        # 腿+鞋 (+裙子) (最底; 不随呼吸动)
		_body_layer(ap, dy),          # 脸+脖
		_shirt_layer(ap, dy, pose),   # 衬衫躯干 (女: 胸随姿势抖动)
		_arm_layer(ap, pose, dy),     # 手臂 (盖在躯干前; 背心款裸臂)
		_hair_layer(ap, dy, pose),    # 头发 (盖在最上; 女: 后发随姿势甩)
	]
	return _outline(_composite(layers))


# 软部位 (女角色的胸 / 后发) 的"滞后位移": 落脚帧下沉, 腾空/passing 帧跟不上 → 走/跳时一弹一弹。
static func _soft_jiggle(pose: String) -> int:
	match pose:
		"walk_a", "walk_c": return 1   # 落脚: 软部位被甩下沉 1px
		"jump_a", "fall": return 1     # 起跳/下落: 惯性滞后下沉
		"hurt": return 1               # 挨打: 晃一下
		_: return 0                    # idle / walk_b(腾空) / jump_b: 回位


static func _body_layer(ap: Dictionary, dy: int) -> Array:
	var g := _blank()
	var head: Array = _FACE_F if int(ap.get("gender", 0)) == 1 else _FACE
	_place(g, _FACE_TOP + dy, _FACE_LEFT, head)
	return g


static func _shirt_layer(ap: Dictionary, dy: int, pose: String = "idle_a") -> Array:
	var g := _blank()
	var female := int(ap.get("gender", 0)) == 1
	var cs := int(ap.get("chest_size", 1))
	var bounce := _soft_jiggle(pose) if female else 0   # 女: 胸随姿势上下弹 1px
	var torso: Array
	if int(ap.get("shirt_style", 0)) == 6:        # 泳衣: 露肚短上衣
		torso = _female_torso_swim(cs, bounce) if female else _TORSO_SWIM
	elif female:
		torso = _female_torso(cs, bounce)
	else:
		torso = _TORSO
	_place(g, _TORSO_TOP + dy, _TORSO_LEFT, torso)
	return g


# 女泳衣躯干 (露肚: 上 3 行衣+胸, 下 3 行肚皮肤)。沙漏腰; cs 简化两档前鼓。
static func _female_torso_swim(cs: int, bounce: int = 0) -> Array:
	cs = clampi(cs, 0, 5)
	# 比基尼上衣 👙 (10宽): 罩杯(镶边D + 高光c) + 挂脖细带。胸前鼓跟 _female_torso 同款大小。
	# 腰/胯皮肤色 (露肚), 形状跟 T恤同款细腰 (用户要身材跨衣服一致)。
	var rows := [
		".sssws....",   # 肩/脖: 挂脖细带 (w)
		"sssDwwc...",   # 上胸: 罩杯上沿镶边 D + 罩杯 + 高光 c
		"swwwwDc...",   # 下胸: 罩杯 + 后背横系带 + 下沿镶边 D + 高光 c
		".sssep....",   # 肚: 露肚 + 罩杯下皮肤阴影 e
		".kss......",   # 腰 (皮肤; 细腰 cols1-3)
		"ksssk.....",   # 胯 (皮肤; cols0-4)
	]
	# 圆润罩杯: 上沿/罩杯峰/下沿 三行。bounce>0 整体下移 1px (走/跳落脚帧胸下沉=抖), 夹 1~3 行。
	var up := clampi(1 + bounce, 1, 3)
	var mid := clampi(2 + bounce, 1, 3)
	var low := clampi(3 + bounce, 1, 3)
	if cs >= 1:
		rows[mid] = _set_char(rows[mid], 7, "w")   # 罩杯 col7 (峰 1px)
	if cs >= 2:
		rows[up] = _set_char(rows[up], 7, "w")     # 上沿 col7
		rows[low] = _set_char(rows[low], 6, "w")   # 下沿 col6 (连住肚)
		rows[low] = _set_char(rows[low], 7, "w")   # 下沿 col7
	if cs >= 3:
		rows[mid] = _set_char(rows[mid], 8, "w")   # 罩杯 col8 (峰 2px)
	if cs >= 4:
		rows[mid] = _set_char(rows[mid], 9, "c")   # 罩杯 col9 峰顶高光 c
		rows[low] = _set_char(rows[low], 8, "e")   # 下沿 col8 皮肤阴影 e
	if cs >= 5:
		rows[up] = _set_char(rows[up], 8, "w")     # 上沿 col8 (上沿满)
	return rows


# 女躯干 (10 宽): 沙漏身, 胸在躯干前 (右)。chest_size 越大胸越饱满。
# 加宽到 10 (composite col5-14) 给胸留鼓的空间: 胸前鼓占 col7-9 = composite 12-14, 最大 3px。
# 胸是前鼓的圆弧 (中胸最饱满, 上下渐收), cs 越大越鼓越大。
static func _female_torso(cs: int, bounce: int = 0) -> Array:
	cs = clampi(cs, 0, 5)
	var rows := [
		".wwwDDc...",   # 肩 + 领口 DD + 前高光 c
		"wwwwwDc...",   # 上胸 (纽扣D + 前高光c)
		"wwwwwwc...",   # 中胸 (光面)
		"wwwwwDc...",   # 下胸 (纽扣D)
		".www......",   # 腰 (照泳衣细腰: cols1-3 = composite 6-8, 后背收1px+前收)
		"wwwww.....",   # 胯 (照泳衣: cols0-4 = composite 5-9)
	]
	# 圆润胸: 上沿/中胸/下沿 三行画峰。bounce>0 把这三行整体下移 1px (走/跳落脚帧胸下沉=抖),
	# 夹在 1~3 行内不侵腰。中胸最鼓, 上下渐收。
	var up := clampi(1 + bounce, 1, 3)
	var mid := clampi(2 + bounce, 1, 3)
	var low := clampi(3 + bounce, 1, 3)
	if cs >= 1:
		rows[mid] = _set_char(rows[mid], 7, "w")   # 中胸 col7 (峰 1px)
	if cs >= 2:
		rows[up] = _set_char(rows[up], 7, "w")     # 上沿 col7
		rows[low] = _set_char(rows[low], 7, "w")   # 下沿 col7 (收尖圆底)
	if cs >= 3:
		rows[mid] = _set_char(rows[mid], 8, "w")   # 中胸 col8 (峰 2px)
	if cs >= 4:
		rows[mid] = _set_char(rows[mid], 9, "c")   # 中胸 col9 峰顶高光 c (球面感: 顶亮)
		rows[low] = _set_char(rows[low], 8, "D")   # 下沿 col8 阴影 D (球面感: 底暗 = 圆)
	if cs >= 5:
		rows[up] = _set_char(rows[up], 8, "w")     # 上沿 col8 (上沿满)
	return rows


static func _arm_layer(ap: Dictionary, pose: String, dy: int) -> Array:
	var g := _blank()
	# 默认 (idle/hurt): 垂在躯干中间 (用户要求手放中间)。走路前后摆; 跳/落抬高。
	var top := 13
	var left := 8
	match pose:
		"walk_a": left = 9;  top = 13   # 手向前
		"walk_c": left = 7;  top = 14   # 手向后
		"jump":   left = 8;  top = 11   # 抬手
		"jump_a": left = 9;  top = 12   # 起跳: 手臂往下后甩 (蹬地)
		"jump_b": left = 8;  top = 8    # 腾空: 手臂高举过头
		"fall":   left = 9;  top = 11
		"hurt":   left = 8;  top = 11
		"swing_a": left = 6;  top = 9    # 挥击蓄力: 手臂抬到后上方
		"swing_b": left = 11; top = 14   # 挥下: 手臂甩到前下方
		"place_a": left = 9;  top = 11   # 放置抬手
		"place_b": left = 11; top = 15   # 放置: 手伸到前下方放方块
	var ss := int(ap.get("shirt_style", 0))
	var arm: Array = _ARM_BARE if (ss == 1 or ss == 6) else _ARM   # 背心/泳衣 露胳膊
	_place(g, top + dy, left, arm)
	return g


# 后发/发尾随姿势左右甩 (女): 走/跳时发梢摆, 发根连头不动 (_sway_block 只动下半截)。
static func _hair_sway(pose: String) -> int:
	match pose:
		"walk_a": return 1     # 迈左脚: 发梢甩向后
		"walk_c": return -1    # 迈右脚: 发梢甩向前
		"jump_a", "fall": return 1
		"hurt": return -1
		_: return 0


# 把块的"下半截"横向移 dir px (上半截不动 = 发根连着头, 不留缝)。dir>0 右移, <0 左移。
static func _sway_block(block: Array, dir: int) -> Array:
	if dir == 0:
		return block
	var out: Array = []
	var n: int = block.size()
	for i in n:
		var row: String = block[i]
		if i < n / 2:
			out.append(row)                       # 上半: 发根, 不动
		elif dir > 0:
			out.append(".".repeat(dir) + row)     # 下半右移 (前补透明)
		else:
			out.append(row.substr(-dir))          # 下半左移 (砍掉左边)
	return out


static func _hair_layer(ap: Dictionary, dy: int, pose: String = "idle_a") -> Array:
	var g := _blank()
	var t := _HAIR_TOP + dy
	var style := int(ap.get("hair_style", 0))
	var female := int(ap.get("gender", 0)) == 1
	var sw := _hair_sway(pose) if female else 0   # 女: 发尾随走/跳甩动
	match style:
		1:
			_place(g, t, _HAIR_LEFT, _sway_block(_HAIR_LONG, sw))   # 长发: 下半发尾甩, 头顶不动
		2:
			_place(g, t, _HAIR_LEFT, _HAIR_PONY)
			_place(g, t + 7, 1, _sway_block(_PONY_TAIL, sw))   # 后脑发束甩
		3:
			_place(g, t, _HAIR_LEFT, _HAIR_AHOGE)
		_:
			_place(g, t, _HAIR_LEFT, _HAIR_SHORT)
	# 女性: 短发/呆毛补后发到肩 → 短发也有女生长度 (脸前侧发绺已按用户要求删除)。
	if female:
		if style == 0 or style == 3:
			_place(g, t + 8, 1, _sway_block(_BACKLOCK_F, sw))   # 后发甩
	return g


# 腿层: 两条腿 + 鞋 (+裙子), 按姿势前后迈 / 抬。裙子款腿裸 (皮肤) + 上面盖裙。
static func _legs_layer(ap: Dictionary, pose: String) -> Array:
	var g := _blank()
	var ps := int(ap.get("pants_style", 0))
	var female := int(ap.get("gender", 0)) == 1   # 女腿细 1px (苗条)
	var leg: Array
	if ps == 2:
		leg = _LEG_SKIN_F if female else _LEG_SKIN       # 裙子: 裸腿 (上面盖裙)
	elif ps == 7:
		leg = _LEG_SKIN_F if female else _LEG_TRUNK      # 泳裤: 女裸腿(配三角裤) / 男全长短裤
	else:
		leg = _LEG_F if female else _LEG
	var foot: Array = _FOOT_BARE if ps == 7 else _SHOE_B   # 泳裤光脚, 其余穿鞋
	match pose:
		"walk_a":   # 迈开: 两脚分开都落地 (宽站, 重心稳)
			_put_leg(g, 4, _HIP, 4, leg, foot)
			_put_leg(g, 9, _HIP, 4, leg, foot)
		"walk_c":   # 收拢: 后脚落地, 前脚抬起迈步 (与 walk_a 不同 → 动起来)
			_put_leg(g, 5, _HIP, 4, leg, foot)
			_put_leg(g, 8, _HIP, 3, leg, foot)
		"walk_b":   # 过渡 (passing): 两腿并拢到身体正下方, 配合上半身抬高 = 走路起伏
			_put_leg(g, 6, _HIP, 4, leg, foot)
			_put_leg(g, 8, _HIP, 4, leg, foot)
		"jump":     # 双腿收起
			_put_leg(g, 5, _HIP, 2, leg, foot)
			_put_leg(g, 9, _HIP, 2, leg, foot)
		"jump_a":   # 起跳蹬地: 一腿蹬直一腿略屈 (发力感)
			_put_leg(g, 5, _HIP, 4, leg, foot)
			_put_leg(g, 9, _HIP, 3, leg, foot)
		"jump_b":   # 腾空收腿: 两腿往上收得更紧 (跃起姿态)
			_put_leg(g, 6, _HIP, 1, leg, foot)
			_put_leg(g, 9, _HIP, 1, leg, foot)
		"fall":     # 双腿张开
			_put_leg(g, 4, _HIP, 4, leg, foot)
			_put_leg(g, 10, _HIP, 4, leg, foot)
		_:          # idle/hurt: 站立, 两腿分开 (脚之间留空隙, 不挨着)
			_put_leg(g, 5, _HIP, 4, leg, foot)
			_put_leg(g, 9, _HIP, 4, leg, foot)
			# 两腿顶部连接 (用户要求): 填裆缝上 2 行, 腿从胯下一截才分开
			var lw := (leg[0] as String).length()
			if 4 - lw > 0:
				var crotch := "b".repeat(4 - lw)
				_place(g, _HIP, 5 + lw, [crotch, crotch])
	if ps == 2:
		_place(g, _HIP - 1, 4, _SKIRT)   # 裙子盖胯+大腿上段, 裸腿露在裙下
	elif ps == 7 and female:
		_place(g, _HIP, 5, _BIKINI_BOTTOM)   # 三角裤盖裆+胯, 裸腿露在两侧/下面
	return g


# 放一条腿 (用给定 leg_block) + 脚 (鞋或光脚 foot_block)。height<4 = 抬腿 (脚离地)。
static func _put_leg(g: Array, col: int, top: int, height: int, leg_block: Array, foot_block: Array) -> void:
	_place(g, top, col, _slice(leg_block, 0, height))
	_place(g, top + height, col, foot_block)   # 脚跟对齐腿, 只往前伸 1px 脚尖 (缩小后不再后伸)


static func _palette_from(ap: Dictionary) -> Dictionary:
	var skin: Color = ap.get("skin_color", DEFAULT_APPEARANCE["skin_color"])
	var hair: Color = ap.get("hair_color", DEFAULT_APPEARANCE["hair_color"])
	var shirt: Color = ap.get("shirt_color", DEFAULT_APPEARANCE["shirt_color"])
	var pants: Color = ap.get("pants_color", DEFAULT_APPEARANCE["pants_color"])
	var eye: Color = ap.get("eye_color", DEFAULT_APPEARANCE["eye_color"])
	var shoe: Color = ap.get("shoe_color", DEFAULT_APPEARANCE["shoe_color"])
	# 加强对比 (用户要求): 深的更深、亮的更亮, 让缝/纽扣/褶皱/明暗更跳眼。
	return {
		".": Color(0, 0, 0, 0),
		"s": skin, "k": skin.darkened(0.26), "p": skin.lightened(0.26),   # p=皮肤高光
		"h": hair, "H": hair.darkened(0.42), "g": hair.lightened(0.48),   # g=头发高光
		"w": shirt, "D": shirt.darkened(0.32), "c": shirt.lightened(0.42), "E": shirt.darkened(0.56), # c高光 E深阴影
		"b": pants, "B": pants.darkened(0.42), "P": pants.lightened(0.44), "A": pants.darkened(0.60), # P高光 A深阴影
		"i": eye, "W": _WHITE, "e": skin.darkened(0.40),
		"o": shoe, "O": shoe.darkened(0.48), "q": shoe.lightened(0.44),   # 鞋(可换色) + 高光 q
		"L": _OUTLINE,
	}


# ---- 网格工具 ----
static func _blank() -> Array:
	var g: Array = []
	for y in H:
		g.append(".".repeat(W))
	return g


static func _composite(layers: Array) -> Array:
	var out := _blank()
	for layer in layers:
		if layer == null:
			continue
		for y in H:
			var base: String = out[y]
			var top: String = layer[y]
			var merged := ""
			for x in W:
				var tc := top.substr(x, 1)
				merged += tc if tc != "." else base.substr(x, 1)
			out[y] = merged
	return out


static func _outline(grid: Array) -> Array:
	var out: Array = grid.duplicate(true)
	for y in H:
		for x in W:
			if grid[y].substr(x, 1) != ".":
				continue
			var adj := false
			for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
				var ny: int = y + d[0]
				var nx: int = x + d[1]
				if ny >= 0 and ny < H and nx >= 0 and nx < W and grid[ny].substr(nx, 1) != ".":
					adj = true
					break
			if adj:
				out[y] = _set_char(out[y], x, "L")
	return out


static func _set_char(row: String, x: int, c: String) -> String:
	return row.substr(0, x) + c + row.substr(x + 1)


static func _place(grid: Array, top: int, left: int, block: Array) -> void:
	for by in block.size():
		var gy := top + by
		if gy < 0 or gy >= H:
			continue
		var brow: String = block[by]
		var row: String = grid[gy]
		var merged := ""
		for x in W:
			var bx := x - left
			var bc := "."
			if bx >= 0 and bx < brow.length():
				bc = brow.substr(bx, 1)
			merged += bc if bc != "." else row.substr(x, 1)
		grid[gy] = merged


static func _slice(block: Array, from: int, n: int) -> Array:
	return block.slice(from, from + n)
