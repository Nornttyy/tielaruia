# 一次性: 把游戏里所有可建造方块的(字符/中文名/真颜色)导出成 JS, 贴进 building_designer.html.
# 颜色取 ArtCache.block_icons (最终贴图, 含群系染色) 的非透明像素平均色.
# 跑: godot --headless --script res://scripts/tools/gen_block_palette.gd
extends SceneTree

const BlocksArt = preload("res://scripts/art/blocks_art.gd")

func _init() -> void:
	# [tile_id, 中文名, 字符]  — 字符须唯一; '.'=空(橡皮)由 HTML 单独加
	var defs := [
		[BlocksArt.GRASS, "草", "g"], [BlocksArt.DIRT, "土", "d"], [BlocksArt.STONE, "石头", "W"],
		[BlocksArt.DEEP_STONE, "深岩", "e"], [BlocksArt.SAND, "沙", "s"], [BlocksArt.SANDSTONE, "砂岩", "a"],
		[BlocksArt.SNOW, "雪", "w"], [BlocksArt.SNOW_DIRT, "冻土", "N"], [BlocksArt.ICE, "冰", "I"],
		[BlocksArt.MUD, "泥巴", "u"], [BlocksArt.JUNGLE_GRASS, "丛林草", "j"], [BlocksArt.JUNGLE_DIRT, "丛林土", "J"],
		[BlocksArt.SWAMP_GRASS, "沼泽草", "m"], [BlocksArt.BEDROCK, "基岩", "k"], [BlocksArt.CLOUD, "云", "o"],
		[BlocksArt.PLANKS, "木板", "P"], [BlocksArt.LOG, "原木", "L"], [BlocksArt.WOOD_PLATFORM, "平台", "_"],
		[BlocksArt.ROPE, "绳子", "y"],
		[BlocksArt.WOOD_WALL, "木墙", "p"], [BlocksArt.GRASS_WALL, "草墙", "q"], [BlocksArt.DIRT_WALL, "土墙", "r"],
		[BlocksArt.STONE_WALL, "石墙", "h"],
		[BlocksArt.LEAVES, "树叶", "v"], [BlocksArt.LEAVES_PINE, "松针", "V"], [BlocksArt.LEAVES_AUTUMN, "秋叶", "z"],
		[BlocksArt.JUNGLE_LEAVES, "丛林叶", "Z"],
		[BlocksArt.DOOR, "门", "D"], [BlocksArt.CHEST, "箱子", "C"], [BlocksArt.GOLD_CHEST, "金宝箱", "G"],
		[BlocksArt.DIAMOND_CHEST, "钻石宝箱", "X"], [BlocksArt.SHADOW_CHEST, "阴影宝箱", "H"], [BlocksArt.MIMIC_CHEST, "死人箱", "x"],
		[BlocksArt.WORKBENCH, "工作台", "B"], [BlocksArt.FURNACE, "熔炉", "F"], [BlocksArt.COOKING_POT, "铁锅", "K"],
		[BlocksArt.CUTTING_BOARD, "菜板", "Y"], [BlocksArt.BED, "床", "b"],
		[BlocksArt.TORCH, "火把", "T"], [BlocksArt.SLIME_TORCH, "史莱姆灯", "t"],
		[BlocksArt.COAL_ORE, "煤矿", "0"], [BlocksArt.IRON_ORE, "铁矿", "1"], [BlocksArt.COPPER_ORE, "铜矿", "2"],
		[BlocksArt.TIN_ORE, "锡矿", "3"], [BlocksArt.SILVER_ORE, "银矿", "4"], [BlocksArt.GOLD_ORE, "金矿", "5"],
		[BlocksArt.DIAMOND_ORE, "钻石矿", "6"], [BlocksArt.HELL_ALLOY_ORE, "地狱合金矿", "7"], [BlocksArt.HELL_CRYSTAL, "地狱晶体", "8"],
		[BlocksArt.CACTUS, "仙人掌", "A"], [BlocksArt.MUSHROOM, "蘑菇", "U"], [BlocksArt.PLANT_GRASS, "小草", "c"],
		[BlocksArt.HELL_STONE, "地狱石", "9"], [BlocksArt.OBSIDIAN, "黑曜石", "O"], [BlocksArt.HELL_FRUIT, "火果", "R"],
		[BlocksArt.LIFE_CRYSTAL, "生命水晶", "E"], [BlocksArt.MANA_CRYSTAL, "魔力水晶", "M"], [BlocksArt.WHEAT_3, "小麦", "Q"],
		[BlocksArt.LAVA, "岩浆", "*"], [BlocksArt.WATER, "水", "~"],
	]
	# 字符唯一性检查
	var seen := {}
	for d in defs:
		assert(not seen.has(d[2]), "字符重复: %s" % d[2])
		seen[d[2]] = true

	var lines := PackedStringArray()
	for d in defs:
		var tid: int = d[0]
		var col: String = _avg_hex(tid)
		lines.append("  { ch: '%s', name: '%s', color: '%s' }," % [d[2], d[1], col])
	print("===PALETTE_JS_START===")
	print("\n".join(lines))
	print("===PALETTE_JS_END===  共 %d 个方块" % defs.size())
	quit()


# 群系染色 (复刻 art_cache._apply_biome_tint, 因 ArtCache autoload 在 --script 里取不到)
const _TINTS := {
	40: [Color(0.5, 1.1, 1.8), 0.6],     # ICE
	41: [Color(0.35, 1.4, 0.4), 0.5],    # JUNGLE_GRASS
	43: [Color(0.55, 0.85, 0.45), 0.5],  # SWAMP_GRASS
	42: [Color(0.6, 0.45, 0.3), 0.55],   # MUD
	46: [Color(0.65, 1.1, 0.5), 0.55],   # JUNGLE_DIRT
	47: [Color(0.7, 0.85, 1.3), 0.55],   # SNOW_DIRT
	48: [Color(0.4, 1.4, 0.55), 0.55],   # JUNGLE_LEAVES
}

func _avg_hex(tile_id: int) -> String:
	var tex: Texture2D = BlocksArt.get_texture(tile_id)
	if tex == null:
		return "#888888"
	var img: Image = tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var rr := 0.0; var gg := 0.0; var bb := 0.0; var n := 0
	for x in w:
		for y in h:
			var c := img.get_pixel(x, y)
			if c.a < 0.3:
				continue
			rr += c.r; gg += c.g; bb += c.b; n += 1
	if n == 0:
		return "#888888"
	var avg := Color(rr / n, gg / n, bb / n)
	if _TINTS.has(tile_id):
		var t: Color = _TINTS[tile_id][0]
		var st: float = _TINTS[tile_id][1]
		avg = avg.lerp(Color(avg.r * t.r, avg.g * t.g, avg.b * t.b), st)
	avg = avg.clamp()
	return "#%02x%02x%02x" % [int(avg.r * 255.0), int(avg.g * 255.0), int(avg.b * 255.0)]
