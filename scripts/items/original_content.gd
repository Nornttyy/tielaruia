# 原版内容对齐第一批。只控制新获得的内容，旧物品定义保留以兼容存档。
extends RefCounted

const STARTER_ITEMS := ["copper_dagger", "copper_pickaxe", "copper_axe"]
const RETIRED_ITEMS := [
	"wood_pickaxe", "wood_axe", "wood_dagger", "stone_sword", "stone_pickaxe",
	"stone_axe", "stone_dagger", "stone_hammer", "diamond_sword", "diamond_pickaxe",
	"diamond_axe", "diamond_dagger", "diamond_hammer", "diamond_helmet", "diamond_chest",
	"diamond_pants", "dual_blade", "warhammer", "gold_dual_blade", "diamond_dual_blade",
	"gold_flail", "diamond_flail", "gold_warhammer", "diamond_warhammer",
	"fire_god", "skyfall_blade", "starfall_blade", "soul_eater", "void_blade",
	"magnet_blade", "echo_blade", "crimson_blade", "thunder_flail", "inferno_flail",
	"abyss_flail", "titan_flail", "frost_flail", "flame_flail", "leaf_flail",
	"hell_crystal", "hell_crystal_ingot", "hell_alloy_ore", "hell_alloy_ingot",
	"hell_sword", "hell_pickaxe", "hell_axe", "hell_dagger", "hell_hammer", "hell_fruit",
	"wheat_seed", "wheat", "rice_seed", "rice", "cooked_rice", "fish_slice",
	"kitchen_knife", "cutting_board", "sushi", "onigiri", "shrimp_sushi", "uni_gunkan",
	"apple_jam", "jelly_pudding", "mushroom_soup", "mushroom_stew", "wool", "raw_meat",
	"spider_eye", "slime_ball", "slime_torch", "skull_summon",
]

const ORIGINAL_ITEM_IDS := {
	"clay": 133, # Clay Block
	"dirt": 2, # Dirt Block
	"stone": 3, # Stone Block
	"sand": 169, # Sand Block
	"cactus": 276, # Cactus
	"planks": 9, # Wood
	"workbench": 36, # Work Bench
	"door": 25, # Wooden Door
	"wood_chair": 34, # Wooden Chair
	"wood_table": 32, # Wooden Table
	"glass": 170, # Glass
	"glass_wall": 392, # Glass Wall
	"gray_brick": 129, # Gray Brick
	"red_brick": 131, # Red Brick
	"wood_sword": 24, # Wooden Sword
	"wood_bow": 39, # Wooden Bow
	"wood_arrow": 40, # Wooden Arrow
	"wood_hammer": 196, # Wooden Hammer
	"boomerang": 284, # Wooden Boomerang
	"slime_jelly": 23, # Gel
	"slime_crown": 560, # Slime Crown
	"shuriken": 42, # Shuriken
	"bomb": 166, # Bomb
	"bone_sword": 1166, # Bone Sword
	"bone": 154, # Bone
	"lens": 38, # Lens
	"feather": 320, # Feather
	"diamond": 182, # Diamond
	"hook": 118, # Hook
	"chain": 85, # Chain
	"grappling_hook": 84, # Grappling Hook
	"fishing_rod": 2289, # Wood Fishing Pole
	"furnace": 33, # Furnace
	"iron_anvil": 35, # Iron Anvil
	"cooking_pot": 345, # Cooking Pot
	"chest": 48, # Chest
	"bed": 224, # Bed
	"wood_wall": 93, # Wood Wall
	"stone_wall": 26, # Stone Wall
	"dirt_wall": 30, # Dirt Wall
	"wood_platform": 94, # Wood Platform
	"rope": 965, # Rope
	"snow": 593, # Snow Block
	"ice": 664, # Ice Block
	"mud": 176, # Mud Block
	"hell_stone": 174, # Hellstone
	"obsidian": 173, # Obsidian
	"sandstone": 607, # Sandstone Brick
	"cloud": 751, # Cloud
	"torch": 8, # Torch
	"apple": 4009, # Apple
	"apple_pie": 4011, # Apple Pie
	"salmon": 2298, # Salmon
	"tuna": 2300, # Tuna
	"sashimi": 2427, # Sashimi
	"grilled_fish": 2425, # Cooked Fish
	"mushroom": 5, # Mushroom
	"health_potion": 28, # Lesser Healing Potion
	"mana_potion": 110, # Lesser Mana Potion
	"copper_ore": 12, # Copper Ore
	"copper_ingot": 20, # Copper Bar
	"tin_ore": 699, # Tin Ore
	"tin_ingot": 703, # Tin Bar
	"iron_ore": 11, # Iron Ore
	"iron_ingot": 22, # Iron Bar
	"silver_ore": 14, # Silver Ore
	"silver_ingot": 21, # Silver Bar
	"gold_ore": 13, # Gold Ore
	"gold_ingot": 19, # Gold Bar
	"copper_sword": 3508, # Copper Broadsword
	"copper_dagger": 3507, # Copper Shortsword
	"copper_pickaxe": 3509, # Copper Pickaxe
	"copper_axe": 3506, # Copper Axe
	"copper_hammer": 3505, # Copper Hammer
	"copper_helmet": 89, # Copper Helmet
	"copper_chest": 80, # Copper Chainmail
	"copper_pants": 76, # Copper Greaves
	"iron_sword": 4, # Iron Broadsword
	"iron_dagger": 6, # Iron Shortsword
	"iron_pickaxe": 1, # Iron Pickaxe
	"iron_axe": 10, # Iron Axe
	"iron_hammer": 7, # Iron Hammer
	"iron_helmet": 90, # Iron Helmet
	"iron_chest": 81, # Iron Chainmail
	"iron_pants": 77, # Iron Greaves
	"silver_sword": 3514, # Silver Broadsword
	"silver_dagger": 3513, # Silver Shortsword
	"silver_pickaxe": 3515, # Silver Pickaxe
	"silver_axe": 3512, # Silver Axe
	"silver_hammer": 3511, # Silver Hammer
	"silver_helmet": 91, # Silver Helmet
	"silver_chest": 82, # Silver Chainmail
	"silver_pants": 78, # Silver Greaves
	"gold_sword": 3520, # Gold Broadsword
	"gold_dagger": 3519, # Gold Shortsword
	"gold_pickaxe": 3521, # Gold Pickaxe
	"gold_axe": 3518, # Gold Axe
	"gold_hammer": 3517, # Gold Hammer
	"gold_helmet": 92, # Gold Helmet
	"gold_chest": 83, # Gold Chainmail
	"gold_pants": 79, # Gold Greaves
}

# 只开放已核对的条目；未登记的新 ID 不会自动混入原版流程。
static func is_available(item_id: String) -> bool:
	return ORIGINAL_ITEM_IDS.has(item_id) or preload("res://scripts/world/classic_materials.gd").ITEMS.has(item_id)


# 只转换程序生成的底图；ChunkManager 随后重放存档差量，保留玩家放置和挖掘。
static func generated_tile(tile_id: int) -> int:
	match tile_id:
		Tiles.COAL_ORE: return Tiles.STONE
		Tiles.HELL_ALLOY_ORE, Tiles.HELL_CRYSTAL: return Tiles.HELL_STONE
		Tiles.HELL_FRUIT, Tiles.MANA_CRYSTAL, Tiles.MIMIC_CHEST, Tiles.WHEAT_0, Tiles.WHEAT_1, Tiles.WHEAT_2, Tiles.WHEAT_3, Tiles.RICE_0, Tiles.RICE_1, Tiles.RICE_2, Tiles.RICE_3: return Tiles.AIR
		Tiles.SNOW_DIRT: return Tiles.DIRT
		Tiles.SWAMP_GRASS: return Tiles.JUNGLE_GRASS
		Tiles.DIAMOND_CHEST: return Tiles.GOLD_CHEST
		_: return tile_id
