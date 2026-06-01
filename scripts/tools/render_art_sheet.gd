# 一次性美术预览渲染器 (headless). 把工具/方块放大拼成 PNG 大图, 供 AI 目视检查.
# 跑法: godot --headless --script res://scripts/tools/render_art_sheet.gd
# 产出: /tmp/art_preview/tools.png  /tmp/art_preview/blocks.png  + 控制台打印每格图例.
extends SceneTree

const PixelArt = preload("res://scripts/art/pixel_art.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")

const ZOOM := 8        # 放大倍数 (16px → 128px)
const CELL := 16       # 源格边长
const PAD := 6         # 格间距 (源像素)
const COLS := 8        # 每行几格
const BG := Color8(48, 52, 60)
const GRID := Color8(70, 76, 86)


func _init() -> void:
	var dir := DirAccess.open("/tmp")
	if dir and not dir.dir_exists("art_preview"):
		dir.make_dir("art_preview")

	# 工具: 8 级 × 剑/镐/斧 + 弓/钩/法杖
	var tools: Array = []
	for tier in ["wood", "copper", "stone", "iron", "silver", "gold", "diamond", "hell"]:
		for kind in ["sword", "pickaxe", "axe"]:
			var id := "%s_%s" % [tier, kind]
			if ItemsArt.has_icon(id):
				tools.append([id, ItemsArt.get_icon(id).get_image()])
	for id in ["wood_bow", "grappling_hook", "wood_staff", "iron_staff", "hell_staff", "mana_potion"]:
		if ItemsArt.has_icon(id):
			tools.append([id, ItemsArt.get_icon(id).get_image()])
	_render_sheet(tools, "/tmp/art_preview/tools.png", "工具")

	# 方块: 常见地表 + 矿 + 墙 + 地狱
	var block_ids := {
		"草": BlocksArt.GRASS, "泥土": BlocksArt.DIRT, "石头": BlocksArt.STONE,
		"深岩": BlocksArt.DEEP_STONE, "沙": BlocksArt.SAND, "砂岩": BlocksArt.SANDSTONE,
		"原木": BlocksArt.LOG, "树叶": BlocksArt.LEAVES, "松针": BlocksArt.LEAVES_PINE,
		"秋叶": BlocksArt.LEAVES_AUTUMN, "木板": BlocksArt.PLANKS, "工作台": BlocksArt.WORKBENCH,
		"熔炉": BlocksArt.FURNACE, "基岩": BlocksArt.BEDROCK, "雪": BlocksArt.SNOW,
		"冰": BlocksArt.ICE, "泥巴": BlocksArt.MUD, "煤矿": BlocksArt.COAL_ORE,
		"铁矿": BlocksArt.IRON_ORE, "铜矿": BlocksArt.COPPER_ORE, "锡矿": BlocksArt.TIN_ORE,
		"银矿": BlocksArt.SILVER_ORE, "草墙": BlocksArt.GRASS_WALL, "土墙": BlocksArt.DIRT_WALL,
		"石墙": BlocksArt.STONE_WALL, "木墙": BlocksArt.WOOD_WALL, "仙人掌": BlocksArt.CACTUS,
		"地狱石": BlocksArt.HELL_STONE, "黑曜石": BlocksArt.OBSIDIAN, "岩浆": BlocksArt.LAVA,
	}
	var blocks: Array = []
	for nm in block_ids.keys():
		var tex: ImageTexture = BlocksArt.get_texture(block_ids[nm])
		if tex:
			blocks.append([nm, tex.get_image()])
	_render_sheet(blocks, "/tmp/art_preview/blocks.png", "方块")

	quit()


func _render_sheet(items: Array, path: String, title: String) -> void:
	var n := items.size()
	var rows := int(ceil(float(n) / COLS))
	var cell_px := CELL * ZOOM
	var pad_px := PAD * ZOOM
	var sheet_w := COLS * cell_px + (COLS + 1) * pad_px
	var sheet_h := rows * cell_px + (rows + 1) * pad_px
	var sheet := Image.create(sheet_w, sheet_h, false, Image.FORMAT_RGBA8)
	sheet.fill(BG)

	var legend := PackedStringArray()
	for i in n:
		var col := i % COLS
		var row := i / COLS
		var x := pad_px + col * (cell_px + pad_px)
		var y := pad_px + row * (cell_px + pad_px)
		# 浅色格底框 (区分透明像素)
		var frame := Image.create(cell_px, cell_px, false, Image.FORMAT_RGBA8)
		frame.fill(GRID)
		sheet.blit_rect(frame, Rect2i(0, 0, cell_px, cell_px), Vector2i(x, y))
		# 放大源图 (最近邻) 并 alpha 混合到格上
		var src: Image = items[i][1]
		src.resize(cell_px, cell_px, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(src, Rect2i(0, 0, cell_px, cell_px), Vector2i(x, y))
		legend.append("[%d 行%d 列%d] %s" % [i, row, col, items[i][0]])

	sheet.save_png(path)
	print("=== %s 大图: %s (%d 个, %d×%d 格) ===" % [title, path, n, COLS, rows])
	print("\n".join(legend))
	print("")
