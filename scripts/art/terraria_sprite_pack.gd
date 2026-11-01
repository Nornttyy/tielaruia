# 原始 PNG 保持不变；只在内存中切帧和组装，碰撞/存档继续使用原来的 12 格网。
# 素材来源与范围见 assets/terraria_1449/SOURCE.txt。
extends RefCounted

const B = preload("res://scripts/art/blocks_art.gd")
const Blob = preload("res://scripts/world/blob_lookup.gd")
const BASE := "res://assets/terraria_1449/"
const TERRAIN := {
	156: 44,
	131: 25, 132: 203, 133: 23, 134: 199, 135: 70, 136: 191, 137: 192, 138: 41, 139: 202, 140: 151, 141: 397, 142: 396, B.CLOUD: 189,
	127: 54, 128: 38, 129: 39, 130: 40,
	B.TIN_ORE: 166,
	B.GRASS: 2, B.DIRT: 0, B.STONE: 1, B.SAND: 53,
	B.DEEP_STONE: 1, B.BEDROCK: 1, B.COAL_ORE: 1,
	B.IRON_ORE: 6, B.COPPER_ORE: 7, B.GOLD_ORE: 8,
	B.SILVER_ORE: 9, B.SNOW: 147,
	B.PLANKS: 30, B.MUD: 59, B.JUNGLE_DIRT: 59,
	B.JUNGLE_GRASS: 60, B.SWAMP_GRASS: 60,
	B.ICE: 161, B.SNOW_DIRT: 0, B.HELL_STONE: 58,
	B.OBSIDIAN: 56, B.SANDSTONE: 151,
}
# 旧存档前四项保留原映射；后续追加所有原发型，不改变玩家已选的编号。
const HAIR_IDS := [1, 2, 4, 1, 18, 7, 19, 23, 30, 37, 51, 3, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 20, 21, 22, 24, 25, 26, 27, 28, 29, 31, 32, 33, 34, 35, 36, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50]

static func hair_count() -> int:
	return HAIR_IDS.size() + 114 # ID 52..165

static func hair_id(style: int) -> int:
	var index := posmod(style, hair_count())
	return HAIR_IDS[index] if index < HAIR_IDS.size() else index - HAIR_IDS.size() + 52

static func clothing_variant(ap: Dictionary) -> int:
	var style := int(ap.get("shirt_style", 0))
	if style not in [0, 1, 2, 3, 8]: style = 0
	if int(ap.get("gender", 0)) == 1:
		return 9 if style == 8 else style + 4
	return style

static var _images: Dictionary = {}
static var _players: Dictionary = {}
static var _actions: Dictionary = {}

static func clear_cache() -> void:
	_players.clear()
	_actions.clear()
	_images.clear()

static func source_image(filename: String) -> Image:
	if not _images.has(filename):
		var path := BASE + filename
		if not ResourceLoader.exists(path):
			return null
		var texture: Texture2D = load(path)
		var img := texture.get_image()
		img.convert(Image.FORMAT_RGBA8)
		_images[filename] = img
	return _images[filename]

static func texture(filename: String) -> ImageTexture:
	var img := source_image(filename)
	return ImageTexture.create_from_image(img) if img != null else null

static func _cell(sheet: Image, coord: Vector2i, stride := 18, size := 16) -> Image:
	return sheet.get_region(Rect2i(coord * stride, Vector2i(size, size)))

# 原图前 5 行包含左右边、上下边和角，后面的区域是混合地形/发光掩码，不能随机切。
static func terrain_cell(sheet: Image, key: String, variant := 0) -> Image:
	var n := key[0] == "C"
	var e := key[1] == "C"
	var s := key[2] == "C"
	var w := key[3] == "C"
	var coord := Vector2i(1 + variant % 3, 1)
	if not n and e and s and w: coord = Vector2i(1 + variant % 3, 0)
	elif n and e and not s and w: coord = Vector2i(1 + variant % 3, 2)
	elif n and e and s and not w: coord = Vector2i(0, variant % 3)
	elif n and not e and s and w: coord = Vector2i(4, variant % 3)
	elif not n and e and s and not w: coord = Vector2i(2 * (variant % 3), 3)
	elif not n and not e and s and w: coord = Vector2i(1 + 2 * (variant % 3), 3)
	elif n and e and not s and not w: coord = Vector2i(2 * (variant % 3), 4)
	elif n and not e and not s and w: coord = Vector2i(1 + 2 * (variant % 3), 4)
	elif n and not e and s and not w: coord = Vector2i(5, variant % 3)
	elif not n and e and not s and w: coord = Vector2i(6 + variant % 3, 4)
	elif not n and not e and s and not w: coord = Vector2i(6 + variant % 3, 0)
	elif n and not e and not s and not w: coord = Vector2i(6 + variant % 3, 3)
	elif not n and e and not s and not w: coord = Vector2i(9, variant % 3)
	elif not n and not e and not s and w: coord = Vector2i(12, variant % 3)
	elif not n and not e and not s and not w: coord = Vector2i(9 + variant % 3, 3)
	# 用原图完整凹边帧。原来的四分之一外角会在连续地面里挖出错误小洞。
	if n and e and s and w:
		if key[5] == "X" and key[6] == "X": coord = Vector2i(6 + variant % 3, 2)
		elif key[7] == "X" and key[4] == "X": coord = Vector2i(6 + variant % 3, 1)
		elif key[4] == "X" and key[5] == "X": coord = Vector2i(11, variant % 3)
		elif key[7] == "X" and key[6] == "X": coord = Vector2i(10, variant % 3)
	return _cell(sheet, coord)

# 每页保留原来的 8×8 排列；后 15 页只补实心异材质接触边，空气边仍透明。
const CONTACT_PAGE_ROWS := 8
const CONTACT_PAGES := 16
static func contact_atlas_coord(base: Vector2i, contact_mask: int) -> Vector2i:
	return base + Vector2i(0, (contact_mask & 15) * CONTACT_PAGE_ROWS)

static func _contact_cell(cell: Image, interior: Image, contact: int) -> Image:
	var result := cell.duplicate() as Image
	for y in 16:
		for x in 16:
			var touching := ((contact & 1) != 0 and y < 4) or ((contact & 2) != 0 and x >= 12) or ((contact & 4) != 0 and y >= 12) or ((contact & 8) != 0 and x < 4)
			if touching and result.get_pixel(x, y).a == 0.0:
				result.set_pixel(x, y, interior.get_pixel(x, y))
	return result

static func block_atlas(tile_id: int) -> ImageTexture:
	if not TERRAIN.has(tile_id): return null
	var sheet := source_image("Tiles_%d.png" % TERRAIN[tile_id])
	if sheet == null: return null
	var img := Image.create(128, 128 * CONTACT_PAGES, false, Image.FORMAT_RGBA8)
	for i in Blob.VARIANT_KEYS.size():
		img.blit_rect(terrain_cell(sheet, Blob.VARIANT_KEYS[i]), Rect2i(0, 0, 16, 16), Vector2i(i % 8, i / 8) * 16)
	for i in B.INTERIOR_VARIANT_COORDS.size():
		img.blit_rect(terrain_cell(sheet, "CCCCIIII", i), Rect2i(0, 0, 16, 16), B.INTERIOR_VARIANT_COORDS[i] * 16)
	var groups := [
		[B.FLAT_TOP_KEY, B.ROUGH_TOP_VARIANT_COORDS],
		[B.FLAT_LEFT_KEY, B.ROUGH_LEFT_VARIANT_COORDS],
		[B.FLAT_RIGHT_KEY, B.ROUGH_RIGHT_VARIANT_COORDS],
		[B.FLAT_BOTTOM_KEY, B.ROUGH_BOTTOM_VARIANT_COORDS],
	]
	for group in groups:
		for i in 3:
			img.blit_rect(terrain_cell(sheet, group[0], i), Rect2i(0, 0, 16, 16), group[1][i] * 16)
	var interior := terrain_cell(sheet, "CCCCIIII")
	for contact in range(1, CONTACT_PAGES):
		for y in 8:
			for x in 8:
				var cell := img.get_region(Rect2i(x * 16, y * 16, 16, 16))
				if cell.is_invisible(): continue
				img.blit_rect(_contact_cell(cell, interior, contact), Rect2i(0, 0, 16, 16), Vector2i(x, y + contact * 8) * 16)
	return ImageTexture.create_from_image(img)

# 树干原帧为 20×20，格距为 16；留出外伸部分，不能压成普通方块。
static func tree_piece(tile_id: int, joint: int, variant: int, style := 0) -> ImageTexture:
	var uv := Vector2i(0, variant % 3)
	if tile_id == B.LOG_ROOT_L: uv = Vector2i(2, 6 + variant % 3)
	elif tile_id == B.LOG_ROOT_R: uv = Vector2i(1, 6 + variant % 3)
	elif joint in [1, 2, 3]:
		uv = Vector2i([0, 2, 1, 3][joint], 3 + variant % 3)
	elif joint >= 4:
		uv = Vector2i([0, 4, 3, 0][joint - 4], 6 + variant % 3)
	var trunk: int = [-1, 3, 1, 0, 4][style]
	var img := _cell(source_image("Tiles_5.png" if trunk == -1 else "Tiles_5_%d.png" % trunk), uv, 22, 20)
	img.resize(15, 15, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# Torch cells are 20×20 with a 22 px stride, not the terrain's 16×16.
# Padding aligns the bottom of the upright handle with the 12 px floor and
# keeps the wall brackets outside the cell without squashing the flame.
static func torch_atlas(flame_only := false) -> ImageTexture:
	var sheet := source_image("Flame_0.png" if flame_only else "Tiles_4.png")
	var img := Image.create(72, 24, false, Image.FORMAT_RGBA8)
	for orientation in 3:
		img.blit_rect(sheet, Rect2i(orientation * 22, 0, 20, 20), Vector2i(orientation * 24 + 2, 0))
	img.resize(54, 18, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func block_single(tile_id: int) -> ImageTexture:
	var img: Image
	match tile_id:
		B.LOG, B.LOG_TOP:
			img = source_image("Tiles_5.png").get_region(Rect2i(2, 2, 16, 16))
		B.LOG_ROOT_L:
			# 左侧枝根的高端在右边，接树干；原图 x=44 才是左侧用片。
			img = source_image("Tiles_5.png").get_region(Rect2i(44, 132, 20, 20))
		B.LOG_ROOT_R:
			img = source_image("Tiles_5.png").get_region(Rect2i(22, 132, 20, 20))
		B.PLANT_GRASS:
			img = _cell(source_image("Tiles_3.png"), Vector2i.ZERO)
		B.TORCH:
			# Inventory/effect fallback; placed torches use the full torch atlas.
			img = source_image("Item_8.png").duplicate()
		B.CLOUD:
			img = _cell(source_image("Tiles_189.png"), Vector2i(1, 1))
		B.GRASS_SLOPE_R, B.GRASS_SLOPE_L:
			# 斜坡保持三角碰撞；切自土纹理，斜面从原草皮取色，不重复旧的块状草纹。
			img = _cell(source_image("Tiles_0.png"), Vector2i(1, 1))
			var grass := _cell(source_image("Tiles_2.png"), Vector2i(1, 0))
			for x in 16:
				var top := 15 - x if tile_id == B.GRASS_SLOPE_R else x
				for y in 16:
					if y < top: img.set_pixel(x, y, Color.TRANSPARENT)
					elif y < top + 3: img.set_pixel(x, y, grass.get_pixel(x, mini(3 + y - top, 15)))
		_:
			return null
	if img.get_size() != Vector2i(16, 16): img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# 同一套树冠/树枝/树干按根部群系取图。统一外框只补透明边，不拉伸树冠。
static func crown(variant: int, style := 0) -> ImageTexture:
	var sheet := source_image("Tree_Tops_%d.png" % [0, 4, 2, 1, 5][style])
	var width := sheet.get_width() / 3 - 2
	var height := sheet.get_height() - 2
	var img := sheet.get_region(Rect2i(posmod(variant, 3) * (width + 2), 0, width, height))
	img.resize(roundi(width * 0.75), roundi(height * 0.75), Image.INTERPOLATE_NEAREST)
	var padded := Image.create(86, 72, false, Image.FORMAT_RGBA8)
	padded.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((86 - img.get_width()) / 2, 72 - img.get_height()))
	return ImageTexture.create_from_image(padded)

static func branch(left: bool, variant := 0, style := 0) -> ImageTexture:
	var sheet := source_image("Tree_Branches_%d.png" % [0, 4, 2, 1, 5][style])
	var img := sheet.get_region(Rect2i(0 if left else 42, posmod(variant, 3) * 42, 40, 40))
	img.resize(30, 30, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func _tint(img: Image, color: Color) -> Image:
	var result := img.duplicate() as Image
	for y in result.get_height():
		for x in result.get_width():
			var pixel := result.get_pixel(x, y)
			if pixel.a > 0: result.set_pixel(x, y, pixel * color)
	return result

static func _part(dst: Image, layer: int, col: int, row: int, color: Color, offset := Vector2i.ZERO, variant := 0) -> void:
	var sheet := source_image("Player_%d_%d.png" % [variant, layer])
	# 各衣款只存差异层；女性共享 4 号身体，头眼共用 0 号。
	if sheet == null and variant in [4, 5, 6, 7, 9]: sheet = source_image("Player_4_%d.png" % layer)
	if sheet == null: sheet = source_image("Player_0_%d.png" % layer)
	var frame := _tint(sheet.get_region(Rect2i(col * 40, row * 56, 40, 56)), color)
	dst.blend_rect(frame, Rect2i(0, 0, 40, 56), offset)

static func _arm(dst: Image, skin: Color, shirt: Color, sleeve: Color, back: bool, angle: float, column := 2, variant := 0) -> void:
	var arm := Image.create(40, 56, false, Image.FORMAT_RGBA8)
	var row := 2 if back else 0
	var parts := [[7, skin], [5 if back else 9, skin], [8, sleeve], [13, shirt]]
	if not back: parts.append([6, shirt])
	for entry in parts: _part(arm, entry[0], column, row, entry[1], Vector2i.ZERO, variant)
	# 图集的列不是摆臂时间线。围绕肩膀摆动同一只手，避免切到抬手/伸手姿势。
	var pivot := Vector2(25, 31) if back else Vector2(15, 31)
	var rotated := Image.create(40, 56, false, Image.FORMAT_RGBA8)
	for y in 56:
		for x in 40:
			var uv := (Vector2(x, y) - pivot).rotated(-angle) + pivot
			var px := roundi(uv.x)
			var py := roundi(uv.y)
			if px >= 0 and py >= 0 and px < 40 and py < 56:
				rotated.set_pixel(x, y, arm.get_pixel(px, py))
	dst.blend_rect(rotated, Rect2i(0, 0, 40, 56), Vector2i.ZERO)

static func player_frame(ap: Dictionary, frame: int, front_column := 2, front_angle := INF, back_column := 2, back_angle := INF) -> ImageTexture:
	var img := Image.create(40, 56, false, Image.FORMAT_RGBA8)
	var skin: Color = ap.get("skin_color", Color8(255, 190, 150))
	var shirt: Color = ap.get("shirt_color", Color8(175, 165, 140))
	var sleeve: Color = ap.get("undershirt_color", shirt.darkened(0.12))
	var leg_frame := clampi(frame, 0, 19)
	var variant := clothing_variant(ap)
	var female_row := 2 if int(ap.get("gender", 0)) == 1 else 0
	# 腿使用整段行走序列；手臂是独立 9×4 图集，不按腿的行号切，避免断手/串帧。
	var swing := sin(float(frame - 6) / 14.0 * TAU) * 0.38 if frame >= 6 else 0.0
	if frame == 5: swing = -0.48
	_part(img, 3, 0, female_row, skin, Vector2i.ZERO, variant)
	_arm(img, skin, shirt, sleeve, true, -swing if is_inf(back_angle) else back_angle, back_column, variant)
	for entry in [[10, skin], [11, ap.get("pants_color", Color8(70, 90, 150))], [12, ap.get("shoe_color", Color8(160, 105, 60))]]:
		_part(img, entry[0], 0, leg_frame, entry[1], Vector2i.ZERO, variant)
	for entry in [[4, sleeve], [6, shirt]]:
		_part(img, entry[0], 1, 1 + female_row, entry[1], Vector2i.ZERO, variant)
		_part(img, entry[0], 0, female_row, entry[1], Vector2i.ZERO, variant)
	# 头部沿用原片格；头发仅 14 帧，走路按自己的帧数循环。
	for entry in [[0, skin], [1, Color.WHITE], [2, ap.get("eye_color", Color8(70, 110, 170))]]:
		_part(img, entry[0], 0, 0, entry[1])
	var selected_hair := hair_id(int(ap.get("hair_style", 0)))
	var hair_sheet := source_image("Player_Hair_%d.png" % selected_hair)
	if hair_sheet == null: hair_sheet = source_image("Player_Hair_1.png")
	var hair_frame := posmod(frame - 6, 14) if frame >= 6 else mini(frame, 5)
	var hair := hair_sheet.get_region(Rect2i(0, hair_frame * 56, 40, 56))
	img.blend_rect(_tint(hair, ap.get("hair_color", Color8(190, 110, 60))), Rect2i(0, 0, 40, 56), Vector2i.ZERO)
	_arm(img, skin, shirt, sleeve, false, swing if is_inf(front_angle) else front_angle, front_column, variant)
	for entry in [[7, skin], [8, sleeve], [13, shirt], [6, shirt]]:
		_part(img, entry[0], 0, 1 + female_row, entry[1], Vector2i.ZERO, variant)
	# 固定裁剪框，所有动作同尺寸/脚底基准，不逐帧裁透明导致角色跳动。
	return ImageTexture.create_from_image(img.get_region(Rect2i(4, 6, 32, 48)))

# 上身使用原始复合手臂帧，腿继续沿用走路/跳跃帧；角度量化让纹理缓存有界。
static func action_frame(ap: Dictionary, leg_frame: int, pose: String, phase: int, aim_step: int) -> ImageTexture:
	var key := str([ap, leg_frame, pose, phase, aim_step])
	if _actions.has(key): return _actions[key]
	var col := 7
	var angle := float(aim_step) * PI / 8.0 - PI / 2.0
	var back_col := 2
	var back_angle := INF
	if pose == "swing":
		col = [3, 4, 5][clampi(phase, 0, 2)]
		angle = 0.0
	elif pose == "eat":
		col = 4
		angle = 0.0
	elif pose == "bow":
		back_col = 7
		back_angle = angle + 0.15
	var result := player_frame(ap, leg_frame, col, angle, back_col, back_angle)
	if _actions.size() >= 384: _actions.erase(_actions.keys()[0])
	_actions[key] = result
	return result

# 握柄跟随当前原片手掌，坐标转换与 32×48 裁框/0.75 世界比例相同。
static func action_hand_position(pose: String, phase: int, aim_step: int) -> Vector2:
	var hand := Vector2(12.5, 39.1667)
	if pose == "swing":
		hand = [Vector2(10.5, 19.8333), Vector2(25, 20.2), Vector2(27.1667, 34.5)][clampi(phase, 0, 2)]
	elif pose == "eat":
		hand = Vector2(25, 20.2)
	else:
		hand = (hand - Vector2(15, 31)).rotated(float(aim_step) * PI / 8.0 - PI / 2.0) + Vector2(15, 31)
	return (hand - Vector2(20, 54)) * 0.75

static func player_frames(ap: Dictionary = {}) -> SpriteFrames:
	var cache_key := str(ap)
	if _players.has(cache_key): return _players[cache_key]
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var animations := {"idle": [0], "walk": [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19], "jump": [5], "fall": [5], "hurt": [5]}
	for name in animations:
		result.add_animation(name)
		result.set_animation_speed(name, 14.0 if name == "walk" else 1.0)
		result.set_animation_loop(name, name in ["walk", "idle"])
		for index in animations[name]: result.add_frame(name, player_frame(ap, index))
	# 捏人拖动色盘会产生很多临时外观；只保留最近 24 套，防止纹理缓存一直增长。
	if _players.size() >= 24: _players.erase(_players.keys()[0])
	_players[cache_key] = result
	return result

static func enemy_frames(filename: String, frame_size: Vector2i, output_size: Vector2i, animations: Dictionary) -> SpriteFrames:
	var sheet := source_image(filename)
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var bottom := 0
	var top := output_size.y
	for name in animations:
		result.add_animation(name)
		result.set_animation_speed(name, 8.0)
		result.set_animation_loop(name, name != "hop")
		for index in animations[name]:
			var img := sheet.get_region(Rect2i(Vector2i(0, index * frame_size.y), frame_size))
			if filename != "NPC_78.png": img.flip_x() # 木乃伊原图朝右；其他原图朝左。
			img.resize(output_size.x, output_size.y, Image.INTERPOLATE_NEAREST)
			var visible_rect := img.get_used_rect()
			bottom = maxi(bottom, visible_rect.end.y)
			top = mini(top, visible_rect.position.y)
			result.add_frame(name, ImageTexture.create_from_image(img))
	# 鸟翼扇下时会低于脚，不能拿翼尖当身体脚底，否则身体整体悬空。
	if filename == "NPC_48.png": bottom = roundi(58.0 * output_size.y / frame_size.y)
	result.set_meta("foot_anchor", output_size.y / 2.0 - bottom)
	result.set_meta("visible_height", bottom - top)
	return result
