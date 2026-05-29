# 程序绘制游戏图标 — 32x32 像素树, 缩 8x → 256x256 PNG.
# 跑法: godot --headless -s scripts/tools/build_icon.gd
# 输出: res://icon.png (覆盖)
extends SceneTree

const ICON_SIZE := 256
const BASE_SIZE := 32   # 32x32 像素艺术原图, 每像素 8x8 屏幕像素 (chunky)

const TRANSPARENT := Color(0, 0, 0, 0)
const LEAF_DARK := Color8(35, 80, 30)
const LEAF_MID := Color8(70, 145, 50)
const LEAF_LIGHT := Color8(120, 200, 75)
const LEAF_HIGHLIGHT := Color8(195, 240, 145)
const TRUNK_DARK := Color8(50, 30, 15)
const TRUNK_MID := Color8(110, 65, 30)
const TRUNK_LIGHT := Color8(160, 110, 60)


func _initialize() -> void:
	var img := Image.create(BASE_SIZE, BASE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	_draw_canopy(img)
	_draw_trunk(img)
	_draw_roots(img)
	# 缩 8x 到 256x256, NEAREST 保 chunky 像素感
	img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_NEAREST)
	var err: int = img.save_png("res://icon.png")
	if err != OK:
		push_error("save_png 失败 err=%d" % err)
	else:
		print("生成 icon.png 256×256 ✓")
	quit()


# 树冠: 圆形, 多层颜色环 (dark 外边 → mid → light → highlight 中央偏左上).
# 中心 (15.5, 9.5), 半径 ~ 9.
func _draw_canopy(img: Image) -> void:
	var cx: float = 15.5
	var cy: float = 9.5
	var r_outer: float = 9.0
	# 光源方向 (左上): 越靠近这个方向 → 颜色越亮
	var light_dir: Vector2 = Vector2(-1.0, -1.0).normalized()
	for y in BASE_SIZE:
		for x in BASE_SIZE:
			var px := Vector2(x - cx, y - cy)
			var d: float = px.length()
			if d > r_outer:
				continue
			var inner: float = r_outer - d   # 距外圈距离, 0=边 ~9=中
			# 光照分量: -1 ~ 1 (背光 ~ 朝光)
			var light_amt: float = light_dir.dot(px.normalized()) if d > 0.1 else 1.0
			var c: Color
			if inner < 1.0:
				c = LEAF_DARK
			elif inner < 2.5:
				c = LEAF_MID
			elif light_amt > 0.4 and inner > 3.5:
				c = LEAF_HIGHLIGHT   # 朝光面亮高光
			elif inner < 5.0 or light_amt < -0.2:
				c = LEAF_MID
			else:
				c = LEAF_LIGHT
			img.set_pixel(x, y, c)


# 树干: cx 14-17 (4 宽), 从树冠底 18 到根部 27. 左暗右亮.
func _draw_trunk(img: Image) -> void:
	var trunk_x0: int = 13
	var trunk_x1: int = 17   # inclusive (4 宽: 13,14,15,16)
	var trunk_y0: int = 17
	var trunk_y1: int = 27
	for y in range(trunk_y0, trunk_y1 + 1):
		for x in range(trunk_x0, trunk_x1):
			var c: Color
			if x == trunk_x0:
				c = TRUNK_DARK
			elif x == trunk_x1 - 1:
				c = TRUNK_LIGHT
			else:
				c = TRUNK_MID
			img.set_pixel(x, y, c)
	# 树皮纹理: 几个 dark 横线模拟节痕
	_dot(img, 14, 19, TRUNK_DARK)
	_dot(img, 15, 22, TRUNK_DARK)
	_dot(img, 14, 25, TRUNK_DARK)


# 根: 树干底向外扩 2 格
func _draw_roots(img: Image) -> void:
	# 左根
	_dot(img, 11, 28, TRUNK_DARK)
	_dot(img, 12, 28, TRUNK_MID)
	_dot(img, 12, 29, TRUNK_DARK)
	_dot(img, 13, 28, TRUNK_MID)
	_dot(img, 13, 29, TRUNK_MID)
	# 中根
	_dot(img, 14, 28, TRUNK_MID)
	_dot(img, 14, 29, TRUNK_DARK)
	_dot(img, 15, 28, TRUNK_MID)
	_dot(img, 15, 29, TRUNK_DARK)
	# 右根
	_dot(img, 16, 28, TRUNK_LIGHT)
	_dot(img, 17, 28, TRUNK_MID)
	_dot(img, 18, 28, TRUNK_DARK)
	_dot(img, 17, 29, TRUNK_DARK)


func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or x >= BASE_SIZE or y < 0 or y >= BASE_SIZE:
		return
	img.set_pixel(x, y, c)
