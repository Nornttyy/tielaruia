# 单存档槽数据。ResourceSaver.save 到 user://save.tres.
# M1 范围: 玩家 + 背包 + 种子 + 出生点 + chunk delta + 实体快照.
class_name SaveData extends Resource

# 存档格式版本. 旧存档 (没这字段) 加载时 = 0.
# v0 → v1: PlayerHealth.MAX_HEALTH 从 20 改 100 + 删饱食度.
#         旧 player_hp 需要 ×5 缩放到新刻度.
const CURRENT_VERSION := 1

@export var version: int = CURRENT_VERSION
@export var world_seed: int = 0
@export var world_name: String = ""
@export var difficulty: int = 1   # 0=简单 1=普通 2=困难
@export var spawn_point: Vector2i = Vector2i.ZERO
# 世界时间 [0, 1) — 0=午夜, 0.35=早晨默认, 0.5=正午, 0.75=傍晚
@export var world_time: float = 0.35
@export var player_position: Vector2 = Vector2.ZERO
@export var player_hp: float = 100.0  # 跟 PlayerHealth.MAX_HEALTH 同步
# 9 hotbar + 27 主背包 = 36 槽。每个: null 或 {"item_id": String, "count": int}
@export var inventory_slots: Array = []
@export var hotbar_selection: int = 0
# chunk_x → Dictionary<Vector2i, tid>。Vector2i 是 (local_x, world_y)。
@export var chunk_deltas: Dictionary = {}
# 实体快照: [{"type": "slime"|"villager"|"item_drop", "position": Vector2, ...}]
@export var entities: Array = []
# 箱子内容: "x,y" (tile world coord) → Array<24>{item_id, count} or null
@export var chest_contents: Dictionary = {}
