# scripts/art/edge_templates.gd
# 5 族 × 47 边缘模板. 每模板 16×16, 字符语义:
#   .  透明 (显示下面的内部纹理)
#   o  外描边 (outline, 最暗)
#   e  边缘暗影 (edge shadow)
#   h  边缘高光 (edge highlight)
#   H  强高光 (顶部/光照面)
# 调色时按方块自己的 _P_xxx 调色板的 _o/_e/_h/_H 槽位染色.
#
# T2: 全模板初始为全 "." (无装饰, 视觉等同现状).
# T10-T14: 逐族手画填充实际边缘.
extends RefCounted

const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


# tile_id → 边缘族名
const FAMILY_OF: Dictionary = {
	BlocksArt.GRASS: "soil",
	BlocksArt.DIRT: "soil",
	BlocksArt.SAND: "soil",
	BlocksArt.STONE: "rock",
	BlocksArt.DEEP_STONE: "rock",
	BlocksArt.BEDROCK: "rock",
	BlocksArt.COAL_ORE: "rock",
	BlocksArt.IRON_ORE: "rock",
	BlocksArt.PLANKS: "wood",
	BlocksArt.LEAVES: "leaf",
	BlocksArt.LEAVES_PINE: "leaf",
	BlocksArt.LEAVES_AUTUMN: "leaf",
	BlocksArt.GRASS_WALL: "wall",
	BlocksArt.DIRT_WALL: "wall",
	BlocksArt.STONE_WALL: "wall",
}


# 5 族模板字典. TEMPLATES[family][variant_key] = Array[String] 16 行 × 16 字符.
static var TEMPLATES: Dictionary = _build_empty_templates()


static func _build_empty_templates() -> Dictionary:
	var blank: Array = []
	for _i in 16:
		blank.append("................")
	var result: Dictionary = {}
	for fam in ["soil", "rock", "wood", "leaf", "wall"]:
		var fam_dict: Dictionary = {}
		for vk in BlobLookup.VARIANT_KEYS:
			fam_dict[vk] = blank.duplicate()
		result[fam] = fam_dict
	return result
