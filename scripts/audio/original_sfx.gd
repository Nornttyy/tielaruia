# 原版短音效文件与游戏事件。下载地址及哈希记录在 sounds/source-manifest.json。
extends RefCounted

const BASE := "res://assets/terraria_1449/sounds/"
const EVENTS := {
	"break": ["Dig_0", "Dig_1", "Dig_2"],
	"place": ["Dig_0", "Dig_1", "Dig_2"],
	"dig": ["Dig_0", "Dig_1", "Dig_2"],
	"tink": ["Tink_0", "Tink_1", "Tink_2"],
	"grass": ["Grass"],
	"swing": ["Item_1", "Item_18", "Item_19"],
	"bow": ["Item_5"],
	"pickup": ["Grab"],
	"eat": ["Item_2"],
	"drink": ["Item_3"],
	"hurt": ["Player_Hit_0", "Player_Hit_1", "Player_Hit_2"],
	"hit": ["NPC_Hit_1"],
	"menu_open": ["Menu_Open"],
	"menu_close": ["Menu_Close"],
	"menu_tick": ["Menu_Tick"],
	"door_open": ["Door_Opened"],
	"door_close": ["Door_Closed"],
	"splash": ["Splash_0"],
	"boss_roar": ["Roar_0"],
	"player_die": ["Player_Killed"],
	"npc_die": ["NPC_Killed_1"],
	"undead_die": ["NPC_Killed_2"],
	"magic_die": ["NPC_Killed_6"],
	"bone_hit": ["NPC_Hit_2"],
	"metal_hit": ["NPC_Hit_4"],
	"zombie_idle": ["Zombie_0", "Zombie_1", "Zombie_2"],
	"bird": ["Zombie_14", "Zombie_16", "Zombie_17", "Zombie_18", "Zombie_19"],
	"drip": ["Drip_0", "Drip_1", "Drip_2"],
	"thunder": ["Thunder_0", "Thunder_1", "Thunder_2", "Thunder_3", "Thunder_4", "Thunder_5", "Thunder_6"],
	"waterfall": ["Liquid_0"],
	"lavafall": ["Liquid_1"],
	"double_jump": ["Double_Jump"],
	"fish_bite": ["Fish_splash"],
	"liquid_use": ["Splash_1"],
	"crystal_use": ["Item_4"],
	"boomerang": ["Item_7"],
	"explosion": ["Item_14"],
	"gunshot": ["Item_11"],
	"gunshot_heavy": ["Item_36"],
	"gunshot_laser": ["Item_12"],
	"gunshot_ice": ["Item_20"],
	"gunshot_magic": ["Item_9"],
	"gunshot_rapid": ["Item_41"],
	"gunshot_flame": ["Item_34"],
	"cast": ["Item_43"],
	"cast_fire": ["Item_20"],
	"cast_water": ["Item_21"],
	"cast_shadow": ["Item_8"],
}
# tModLoader SoundStyle 的 PitchVariance 是总宽度；XNA 音高单位是八度。
const PITCH_SPREAD := {"dig": 0.2, "break": 0.2, "place": 0.2, "grass": 0.6,
	"pickup": 0.2, "swing": 0.2, "bow": 0.2, "eat": 0.2, "drink": 0.2,
	"door_open": 0.4, "door_close": 0.4, "splash": 0.2, "liquid_use": 0.2,
	"thunder": 0.2, "drip": 0.4, "zombie_idle": 0.2, "double_jump": 0.2,
	"cast": 0.2, "cast_fire": 0.2, "cast_water": 0.2, "cast_shadow": 0.2,
	"gunshot": 0.2, "gunshot_heavy": 0.2, "gunshot_laser": 0.2, "gunshot_ice": 0.2,
	"gunshot_magic": 0.2, "gunshot_rapid": 0.2, "gunshot_flame": 0.2}

static func tile_sound(tile_id: int) -> String:
	if tile_id in [Tiles.COPPER_ORE, Tiles.TIN_ORE, Tiles.IRON_ORE, Tiles.SILVER_ORE, Tiles.GOLD_ORE, Tiles.IRON_ANVIL, Tiles.IRON_ANVIL_RIGHT]:
		return "tink"
	if tile_id in [Tiles.PLANT_GRASS, Tiles.LEAVES, Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN, Tiles.JUNGLE_LEAVES, Tiles.MUSHROOM]:
		return "grass"
	return "dig"

static func streams(event: String) -> Array[AudioStreamWAV]:
	var result: Array[AudioStreamWAV] = []
	for file in EVENTS.get(event, []):
		var path: String = BASE + file + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStreamWAV
			if stream != null: result.append(stream)
	return result

# 环境音维持用户选定的低音量；独立于主音量总线。
const VOLUME_DB := {"bird": -30.0, "drip": -30.0, "thunder": -30.0, "zombie_idle": -8.0}
const MIN_INTERVAL := {"drip": 0.2, "bird": 6.0, "thunder": 1.0, "zombie_idle": 0.6}

static func creature_event(kind: String, died: bool) -> String:
	if died:
		if kind in ["zombie", "skeleton", "skeleton_king"]: return "undead_die"
		if kind in ["mimic", "mummy"]: return "magic_die"
		return "npc_die"
	if kind in ["skeleton", "skeleton_king"]: return "bone_hit"
	if kind == "mimic": return "metal_hit"
	return "hit"
