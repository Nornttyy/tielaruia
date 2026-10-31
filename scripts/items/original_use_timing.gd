# 1.4.4.9 无前缀、无攻速加成的基础使用动画；一游戏刻 = 1/60 秒。
# Wiki 的 Use time 对应 useAnimation，Tool speed 对应挖掘 useTime，不能混用。
# 来源与版本核对见 docs/terraria-use-timing.txt。
extends RefCounted

const TICKS_PER_SECOND := 60.0
const ANIMATION_TICKS := {
	"copper_pickaxe": 23, "iron_pickaxe": 20, "silver_pickaxe": 19, "gold_pickaxe": 20,
	"copper_axe": 30, "iron_axe": 27, "silver_axe": 26, "gold_axe": 26,
	"wood_hammer": 37, "copper_hammer": 33, "iron_hammer": 30, "silver_hammer": 29, "gold_hammer": 28,
	"wood_sword": 20, "copper_sword": 21, "iron_sword": 20, "silver_sword": 20, "gold_sword": 18,
	"copper_dagger": 13, "iron_dagger": 12, "silver_dagger": 12, "gold_dagger": 11,
	"bone_sword": 22, "wood_bow": 30,
}

static func seconds(item_id: String, fallback: float = 0.5) -> float:
	if ANIMATION_TICKS.has(item_id):
		return float(ANIMATION_TICKS[item_id]) / TICKS_PER_SECOND
	return fallback # 旧档中未迁移的物品仍可使用原有时长。
