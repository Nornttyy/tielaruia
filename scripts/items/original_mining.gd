# Terraria 1.4.4.9 tool power and toolTime (not useAnimation).
# References: terraria.wiki.gg/wiki/Tool_speed and /wiki/Pickaxe_power.
extends RefCounted

# power %, toolTime in 60 Hz ticks. Old save-only tools retain their legacy rules.
const TOOLS := {
	"copper_pickaxe": [35, 15], "iron_pickaxe": [40, 13],
	"silver_pickaxe": [45, 11], "gold_pickaxe": [55, 17],
	"copper_axe": [35, 21], "iron_axe": [45, 19],
	"silver_axe": [50, 18], "gold_axe": [55, 18],
	"wood_hammer": [25, 25], "copper_hammer": [35, 23],
	"iron_hammer": [40, 20], "silver_hammer": [45, 19], "gold_hammer": [55, 23],
}

static func interval(id: String, bonus := 0.0) -> float:
	var ticks: int = TOOLS[id][1]
	if id.ends_with("_pickaxe"):
		ticks = maxi(1, floori(ticks * (1.0 - clampf(bonus, 0.0, 0.7))))
	elif id.ends_with("_hammer"):
		ticks = maxi(1, floori(ticks / 2.0))
	return ticks / 60.0

static func power(id: String) -> int:
	return TOOLS[id][0]

static func required_power(tid: int, below_surface := true) -> int:
	if tid in [Tiles.EBONSTONE, Tiles.CRIMSTONE, Tiles.HELL_STONE]: return 65
	if tid == Tiles.OBSIDIAN: return 55
	# Dungeon brick protection in this finite classic world: underground perimeter.
	if tid in [Tiles.DUNGEON_BRICK, Tiles.GREEN_DUNGEON_BRICK]: return 100 if below_surface else 0
	return 0

static func grass_base(tid: int) -> int:
	if tid in [Tiles.GRASS, Tiles.CORRUPT_GRASS, Tiles.CRIMSON_GRASS]: return Tiles.DIRT
	if tid in [Tiles.JUNGLE_GRASS, Tiles.SWAMP_GRASS, Tiles.MUSHROOM_GRASS]: return Tiles.MUD
	return -1

static func hit_points(tid: int, kind: String) -> float:
	if kind == "axe": return 500.0 if tid == Tiles.LOG else 100.0
	if tid in [Tiles.DIRT, Tiles.SAND, Tiles.SNOW, Tiles.SNOW_DIRT, Tiles.MUD, Tiles.JUNGLE_DIRT, Tiles.HARDENED_SAND]: return 50.0
	if tid in [Tiles.EBONSTONE, Tiles.CRIMSTONE, Tiles.HELL_STONE, Tiles.DUNGEON_BRICK, Tiles.GREEN_DUNGEON_BRICK]: return 200.0
	return 100.0
