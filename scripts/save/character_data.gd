# 角色卡: 一个角色的全部状态 (外观 + 跟人走的背包/血量/魔力/盔甲)。
# 存 user://characters/{name}.tres, 由 CharacterManager 管。跨世界: 同一角色进任何世界。
# 外观字段款式数量见 spec docs/superpowers/specs/2026-06-07-character-creator-design.md。
class_name CharacterData extends Resource

const CURRENT_VERSION := 1
@export var version: int = CURRENT_VERSION
@export var character_name: String = ""

# ---- 外观 (捏人结果; 渲染在计划 2, 这里只存) ----
@export var gender: int = 0            # 0=男 1=女
@export var hair_style: int = 0        # 0..3
@export var shirt_style: int = 0       # 0..18 (见 spec 完整目录)
@export var pants_style: int = 0       # 0..19
@export var cape_style: int = 0        # 0=无 1=短披风 2=长披风 3=蝴蝶翅膀 4=恐龙尾 5=狗尾 6=兔尾
@export var chest_size: int = 1        # 仅 gender=1(女): 0..5
@export var skin_color: Color = Color8(255, 218, 185)
@export var hair_color: Color = Color8(121, 85, 72)
@export var shirt_color: Color = Color8(229, 57, 53)
@export var pants_color: Color = Color8(38, 70, 130)
@export var cape_color: Color = Color8(150, 40, 50)
@export var eye_color: Color = Color8(60, 110, 70)
@export var shoe_color: Color = Color8(74, 47, 26)

# ---- 跟着角色走的玩家状态 (从 SaveData 搬过来) ----
@export var player_hp: float = 100.0
@export var player_max_hp: int = 100
@export var player_mana: int = 100
@export var player_max_mana: int = 100
@export var armor_helmet_id: String = ""
@export var armor_chest_id: String = ""
@export var armor_pants_id: String = ""
@export var inventory_slots: Array = []     # 36 槽: null 或 {"item_id": String, "count": int}
@export var hotbar_selection: int = 0


# 给渲染层 (计划 2 的 PlayerArt.build_sprite_frames) 用的外观快照。
# 单独抽出避免渲染层依赖整个 CharacterData。
func appearance_dict() -> Dictionary:
	return {
		"gender": gender,
		"hair_style": hair_style,
		"shirt_style": shirt_style,
		"pants_style": pants_style,
		"cape_style": cape_style,
		"chest_size": chest_size,
		"skin_color": skin_color,
		"hair_color": hair_color,
		"shirt_color": shirt_color,
		"pants_color": pants_color,
		"cape_color": cape_color,
		"eye_color": eye_color,
		"shoe_color": shoe_color,
	}
