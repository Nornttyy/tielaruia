# 单存档槽数据。ResourceSaver.save 到 user://save.tres.
# M1 范围: 玩家 + 背包 + 种子 + 出生点 + chunk delta + 实体快照.
class_name SaveData extends Resource

# 存档格式版本. 旧存档 (没这字段) 加载时 = 0.
# v0 → v1: PlayerHealth.MAX_HEALTH 从 20 改 100 + 删饱食度. 旧 player_hp ×5 缩放.
# v1 → v2: 加生命水晶, player_max_hp 字段记录吃了几个 crystal 后的上限.
# v2 → v3: 加 3 件盔甲槽持久化 (armor_helmet/chest/pants item_id). 老存档默认空.
# v3 → v4: 加魔力 (current+max) + 魔力水晶 spawned/positions.
const CURRENT_VERSION := 4

@export var version: int = CURRENT_VERSION
@export var world_seed: int = 0
@export var world_name: String = ""
@export var difficulty: int = 1   # 0=简单 1=普通 2=困难
@export var world_size: int = 1   # 0=小 1=中 2=大 (影响 biome 间距 + 金字塔数)
@export var spawn_point: Vector2i = Vector2i.ZERO
# 床复活点 (玩家睡过床后设的). (-99999, -99999) = 没设过, 用 spawn_point.
@export var bed_spawn_point: Vector2i = Vector2i(-99999, -99999)
# 世界时间 [0, 1) — 0=午夜, 0.35=早晨默认, 0.5=正午, 0.75=傍晚
@export var world_time: float = 0.35
@export var player_position: Vector2 = Vector2.ZERO
@export var player_hp: float = 100.0       # 当前血量
@export var player_max_hp: int = 100        # 永久上限 (吃水晶能涨到 400)
# 生命水晶世界上限: 单人 15, 联机 玩家数×15. 跨 chunk 不重复刷 + 间距 ≥ 40 tile.
# spawned = 已放出数 (含被吃的); processed_chunks = 已查过 cap 的 chunk_x;
# crystal_positions = 已放水晶世界坐标 (扁平 [x,y,x,y...] 给 PackedInt32Array 用).
@export var life_crystals_spawned: int = 0
@export var processed_chunks: PackedInt32Array = []
@export var life_crystal_positions: PackedInt32Array = []
# 魔力 (v4): 当前 mana + 永久上限 (吃魔力水晶能涨到 200)
@export var player_mana: int = 100
@export var player_max_mana: int = 100
# 魔力水晶世界上限: 单人 5, 联机 玩家数×5. 与 life_crystal 同套.
@export var mana_crystals_spawned: int = 0
@export var mana_crystal_positions: PackedInt32Array = []
# 已 spawn 守卫木乃伊的金字塔 chunk_x 列表 (防存档重读后木乃伊复活)
@export var pyramid_chunks_spawned: PackedInt32Array = []
# 已 spawn 守卫蜘蛛的世纪树 chunk_x 列表 (防存档重读后蜘蛛复活)
@export var world_tree_chunks_spawned: PackedInt32Array = []
# 已 spawn 守卫蜘蛛的废弃矿井 chunk_x 列表
@export var mineshaft_chunks_spawned: PackedInt32Array = []
# 盔甲槽 (v3): 存 item_id 字符串. 空 = 没装备. count 始终是 1.
@export var armor_helmet_id: String = ""
@export var armor_chest_id: String = ""
@export var armor_pants_id: String = ""
# 9 hotbar + 27 主背包 = 36 槽。每个: null 或 {"item_id": String, "count": int}
@export var inventory_slots: Array = []
@export var hotbar_selection: int = 0
# chunk_x → Dictionary<Vector2i, tid>。Vector2i 是 (local_x, world_y)。
@export var chunk_deltas: Dictionary = {}
# 实体快照: [{"type": "slime"|"villager"|"item_drop", "position": Vector2, ...}]
@export var entities: Array = []
# 箱子内容: "x,y" (tile world coord) → Array<24>{item_id, count} or null
@export var chest_contents: Dictionary = {}
