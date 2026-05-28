# 蜘蛛怪 设计稿

**日期**：2026-05-28
**范围**：加 1 个新敌对怪「蜘蛛」(spider) + 1 个新掉落物 spider_eye + 出没逻辑
**所属里程碑**：地穴深处怪系列第 1 个（后面可能加蝙蝠 / 骷髅）

---

## 1. 目标

让地下探险有威胁。当前只有史莱姆（白天，温和）和僵尸（夜晚地表，慢）。蜘蛛是**第一个真正"深处怪"**：跑得快、伤害高、夜晚和地下都刷。

---

## 2. 数值

| 属性 | 值 | 备注 |
|---|---|---|
| HP | 18 | 木剑 5 击 / 石剑 4 击 / 铜剑 4 击 (比僵尸 15 略强) |
| 接触伤害 | 6 | 比僵尸 3 翻倍。蜘蛛是"重伤怪" |
| 移动速度 | 70 px/s | 比僵尸 28 快约 2.5×，玩家慢走逃不掉 |
| 跳跃力 | -240 (vy) | 撞墙自动跳，跳得比僵尸高一点 |
| 敌对范围 | 200 px | 看见 16 tile 内的玩家就追 |
| 碰撞框 | 12×8 | 小扁身，4 腿 sprite ~16 wide |
| i-frame | 0.2s | 跟 slime / zombie 一致 |

---

## 3. 出没规则

`world.gd` `_try_spawn_zombie()` 路径加蜘蛛分支：

- **触发**：跟僵尸同 spawn 频率（SPAWN_INTERVAL 6.0s），不增加额外 timer
- **位置判定**：在玩家 chunk 内随机找一个候选 spawn 位置 (cand_x, surf_y - 1)
- **替换概率**：原本要刷 zombie 时，50% 改刷蜘蛛
- **额外**：玩家在地下深处（player.y > 30 tiles）时，**白天也刷蜘蛛**（黑暗本身就够吓人）

MAX_SLIMES 上限把蜘蛛也算进去（共用 zombie 上限）。

---

## 4. 掉落物

新 item `spider_eye`：

```gdscript
"spider_eye": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 99},
```

- 中文名：「蜘蛛眼」
- 掉落数：1-2 个（100%）
- 用途：M3 酿造系统材料（**现在没用，纯收集**）
- 图标：紫红色小球 + 黑色十字（蜘蛛眼）

---

## 5. 文件清单

| 新建 | 用途 |
|---|---|
| `scripts/entities/spider.gd` | 蜘蛛实体脚本 (extends CharacterBody2D, 跟 zombie 同接口 take_damage 等) |
| `scenes/entities/spider.tscn` | 场景, CollisionShape 12×8, sprite 节点 |
| `scripts/art/spider_art.gd` | 8 帧 idle + 4 帧 walk 像素画 (16×12, 4 腿黑棕) |
| `tests/integration/test_spider.gd` | spawn + take_damage + drops 验收测试 |

| 修改 | 改什么 |
|---|---|
| `scripts/items/item_db.gd` | 加 spider_eye 条目 |
| `scripts/ui/crafting_panel.gd` | `_ZH_NAMES` 加 "spider_eye": "蜘蛛眼" |
| `scripts/art/items_art.gd` | 加 _SPIDER_EYE 像素画 + `_ICONS` 注册 |
| `scripts/autoload/art_cache.gd` | `_build_items` 加 "spider_eye"; `_build_entities` 加 `spider_frames = SpiderArt.build_sprite_frames()` |
| `scripts/world/world.gd` | 加 `SpiderScene` preload + `_try_spawn_spider()` (跟 zombie 同模式) + remote spawn `kind == "spider"` |

---

## 6. spider.gd 实现要点

继承 zombie.gd 的 _physics_process 结构（很多类似），但参数不同：

```gdscript
extends CharacterBody2D

const GRAVITY := 675.0
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12

const MAX_HEALTH := 18
const CONTACT_DAMAGE := 6
const WALK_SPEED := 70.0
const AGGRO_RANGE_PX := 200.0
const JUMP_VY := -240.0
const ENEMY_IFRAME_SEC := 0.2

var current_health: int = MAX_HEALTH
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
    sprite.sprite_frames = ArtCache.spider_frames
    sprite.play("idle")
    add_to_group("spiders")
    add_to_group("slimes")  # 共享剑挥范围 + 出生点死亡清除


func _physics_process(delta):
    # 跟 zombie 模式: 性能 skip / hit_flash / iframe / 重力 / 追玩家 / move_and_slide /
    # 撞墙自动跳 / _check_player_contact
    # 数值不同 (WALK_SPEED=70, JUMP_VY=-240, CONTACT_DAMAGE=6, knockback=130 给玩家)
    ...


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
    # 跟 slime/zombie 同接口 (iframe check + knockback + 受击 flash)
    ...
    if current_health == 0:
        _die()


func _die():
    # 掉 1-2 个 spider_eye
    var n: int = randi_range(1, 2)
    for i in n:
        _spawn_drop("spider_eye")
    queue_free()
```

---

## 7. spider_art.gd 像素画方案

身体 16×12，4 腿向两侧伸：

```
....bBBb....
...BBBBBB...
..BBmBBmBB..
.BB.BB.BB.BB    <- 4 腿
..BBBBBBBB..
..BB....BB..
.B........B.
```

调色板：
- B = Color8(45, 25, 18)  # 深棕主色
- b = Color8(80, 50, 35)  # 棕亮 (背部高光)
- m = Color8(220, 200, 90)  # 眼睛黄

动画：
- idle (4 帧, 1.5 fps): 腿轻微上下抖
- walk (4 帧, 6 fps): 4 腿循环错开
- hop / 跳: idle 凝固 (用 1 帧)

---

## 8. 测试

`tests/integration/test_spider.gd`：

| 测试 | 期望 |
|---|---|
| `test_spider_take_damage` | 拿木剑挥 5 下 → spider HP 0, 死亡 |
| `test_spider_drops_eye` | spider 死后地上有 1-2 个 spider_eye drop |
| `test_spider_contact_damages_player` | spider 贴脸玩家 → 玩家受 6 伤 |
| `test_spider_walks_toward_player` | spider 距玩家 100 px (< AGGRO) → velocity.x 朝玩家方向 |
| `test_spider_idle_when_player_far` | spider 距玩家 300 px (> AGGRO) → velocity.x ≈ 0 |

---

## 9. 实现顺序（写 plan 时参考）

1. T1: spider_eye item + 中文名 + ItemDB 注册 + ItemsArt _SPIDER_EYE pattern
2. T2: spider_art.gd + ArtCache.spider_frames 加载
3. T3: spider.gd + spider.tscn (基于 zombie 模板)
4. T4: world.gd spawn 逻辑 (替换 50% 僵尸为蜘蛛 + 地下深处也刷)
5. T5: test_spider.gd 5 个测试
6. T6: 全套测试 + smoke 不破

---

## 10. 风险

| 风险 | 缓解 |
|---|---|
| spawn 太密集, 蜘蛛淹没玩家 | 共享 MAX_ZOMBIES=5 上限, 50% 替换不增量 |
| 速度 70 + 跳 -240 太可怕, 卡死玩家进度 | HP 18 也允许玩家被打几下扛过去; 真不行降到 walk=50 |
| 地下深处刷蜘蛛跟玩家挖矿干扰 | 测试通过后玩家反馈再调; 可加"距玩家 > 8 tile 才 spawn" |
| spider 跟僵尸视觉混淆 | 用棕色 + 4 腿明显, 区别于绿色僵尸 |
