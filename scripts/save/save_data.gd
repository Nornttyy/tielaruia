# 单存档槽数据。ResourceSaver.save 到 user://save.tres.
# M1 范围: 玩家 + 背包 + 种子 + 出生点 + chunk delta + 实体快照.
class_name SaveData extends Resource

# 存档格式版本. 旧存档 (没这字段) 加载时 = 0.
# v0 → v1: PlayerHealth.MAX_HEALTH 从 20 改 100 + 删饱食度. 旧 player_hp ×5 缩放.
# v1 → v2: 加生命水晶, player_max_hp 字段记录吃了几个 crystal 后的上限.
const CURRENT_VERSION := 2

@export var version: int = CURRENT_VERSION
@export var world_seed: int = 0
@export var world_name: String = ""
@export var difficulty: int = 1   # 0=简单 1=普通 2=困难
@export var spawn_point: Vector2i = Vector2i.ZERO
# 世界时间 [0, 1) — 0=午夜, 0.35=早晨默认, 0.5=正午, 0.75=傍晚
@export var world_time: float = 0.35
@export var player_position: Vector2 = Vector2.ZERO
@export var player_hp: float = 100.0       # 当前血量
@export var player_max_hp: int = 100        # 永久上限 (吃水晶能涨到 400)
# 生命水晶世界上限: 单人 15, 联机 玩家数×15. 跨 chunk 不重复刷.
# spawned = 累计已放出的水晶数 (含被吃掉的); processed_chunks = 已查过的 chunk_x 列表.
@export var life_crystals_spawned: int = 0
@export var processed_chunks: PackedInt32Array = []
# 9 hotbar + 27 主背包 = 36 槽。每个: null 或 {"item_id": String, "count": int}
@export var inventory_slots: Array = []
@export var hotbar_selection: int = 0
# chunk_x → Dictionary<Vector2i, tid>。Vector2i 是 (local_x, world_y)。
@export var chunk_deltas: Dictionary = {}
# 实体快照: [{"type": "slime"|"villager"|"item_drop", "position": Vector2, ...}]
@export var entities: Array = []
# 箱子内容: "x,y" (tile world coord) → Array<24>{item_id, count} or null
@export var chest_contents: Dictionary = {}
