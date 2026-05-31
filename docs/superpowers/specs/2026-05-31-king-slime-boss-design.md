# Boss 设计：史莱姆王（King Slime）

日期：2026-05-31
里程碑：M3（Boss，"更像泰拉瑞亚"系列之一）

## 目标

加入游戏第一个真正的 Boss——史莱姆王。可用召唤道具主动开战，有多段攻击/阶段，掉专属武器奖励。

当前怪物都是独立 `CharacterBody2D` 脚本（HP、接触伤害、aggro、受击闪白、掉落、`GameSettings.enemy_hp_multiplier()` 难度缩放、加入 group），由 `world.gd` 按计时器刷出。现有"Boss"只有 Mimic（机制等同普通怪）。

## 已定需求（来自用户）

1. **选型**：史莱姆王——复用 `slime.gd` 行为 + `SlimeArt` 美术，放大约 4 倍 + 王者染色 + 皇冠。
2. **召唤**：合成「史莱姆王冠」道具，手持使用 → 在玩家附近召唤 Boss。
3. **三招/阶段**：大跳砸玩家；血量 < 50% 时定期召唤小史莱姆；血越少体型越小、跳得越快越频繁。
4. **血量**：1000（随 `enemy_hp_multiplier` 缩放）。
5. **奖励**：专属武器「史莱姆球」（丢出会弹跳的投射物，伤害高于同期铁剑）+ 一堆史莱姆胶。

## 实现细节

### 1. 新物品（`scripts/items/item_db.gd` 的 `_DEFS`）

```gdscript
"slime_crown": {"placeable_tile_id": -1, "tool_kind": "summon", "tool_tier": 0, "max_stack": 1},
"slime_ball":  {"placeable_tile_id": -1, "tool_kind": "slimeball", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0},
```

- `slime_crown`：消耗型召唤道具。`tool_kind = "summon"` 是新类别。
- `slime_ball`：投射武器，`tool_kind = "slimeball"`（新类别，区别于 bow/staff 走自己的发射逻辑）。`tool_tier = 5` 使其伤害高于铁剑（tier 4）。
- **必须**同步在 `scripts/ui/crafting_panel.gd` 的 `_ZH_NAMES` 加：`"slime_crown": "史莱姆王冠"`、`"slime_ball": "史莱姆球"`（漏了显示英文 id，见项目规矩）。

### 2. 召唤道具配方（`scripts/crafting/recipe_db.gd`）

九宫格摆放式（每格 1 个材料）。史莱姆胶 `slime_jelly` 已存在。

```gdscript
{
    "id": "slime_crown",
    "grid_size": Vector2i(3, 3),
    "pattern": [
        ["slime_jelly", "slime_jelly", "slime_jelly"],
        ["slime_jelly", "slime_jelly", "slime_jelly"],
        ["slime_jelly", "slime_jelly", "slime_jelly"],
    ],
    "output_id": "slime_crown",
    "output_count": 1,
    "requires": "workbench",
    "mirror_ok": true,
}
```

（注：配方是形状匹配，每格消耗 1 个，所以王冠 = 9 个史莱姆胶，不是 30——受网格系统限制。）

### 3. 使用王冠召唤（`scripts/player/player_action.gd`）

现有 use 路径：食物吃、bow/staff 发射、方块放置。新增"召唤"分支：
- 当前手持 slot 的 item 是 `tool_kind == "summon"` 且玩家按使用键 → 调 `world.spawn_king_slime(near_player_pos)`，成功则消耗 1 个王冠。
- 若已有存活的史莱姆王 → 不召唤（给个提示/音效，避免双开）。

### 4. Boss 本体（新 `scripts/entities/king_slime.gd` + `scenes/entities/king_slime.tscn`）

以 `slime.gd` 为模板：
- **血量**：`BASE_MAX_HEALTH = 1000`，`_ready` 里乘 `GameSettings.enemy_hp_multiplier()`（同其它怪）。
- **接触伤害**：`CONTACT_DAMAGE = 20`。
- **不跟玩家/彼此物理碰撞**（项目规矩：怪物穿过玩家。检查 .tscn `collision_layer/mask` + 加 player exception，同其它怪）。
- **加入 group**：`king_slime` + `slimes`（复用剑挥范围 + 出生点死亡清除逻辑）。但注意：出生点死亡清除不要误删 Boss（见收尾规则）——用独立 group `boss` 标记，清除逻辑跳过 `boss`。
- **大小**：sprite scale ≈ 4×，加皇冠（小三角黄色像素覆盖在史莱姆顶部，程序绘制）。碰撞框按比例放大。
- **三招/阶段**：
  1. **大跳**：朝玩家方向跳，跳跃初速 + 水平速度都比小史莱姆大得多；落地砸（接触伤害即可，不必单独地震判定）。
  2. **召唤小兵**：`current_health < max_health * 0.5` 后，每 `MINION_INTERVAL`（如 4s）召唤 2-3 只普通 `SlimeScene` 在自身周围（计入场上怪数，避免无限刷——设上限如 6 只）。
  3. **缩小提速**：每帧按 `hp_ratio = current_health / max_health` 算：sprite scale 从 4× 线性降到 ~2×；跳跃频率/速度随 hp 下降而上升（`hp_ratio` 越低，跳跃间隔越短）。
- **专属大血条**：用现有 `HealthBarScript`（`scripts/entities/health_bar.gd`），放大尺寸 / 顶部居中显示（实现者参考现有怪血条挂法）。
- **掉落**：死亡时 spawn `slime_ball` ×1 + `slime_jelly` ×若干（如 20-40，用现有 `ItemDropScene`，同其它怪掉落写法）。

### 5. 收尾规则（防 Boss 永久追随）

- 玩家死亡 或 Boss 离玩家超过阈值（如 80 tile）持续若干秒 → Boss `queue_free()`（不掉落）。
- `world.gd` 持有 `var _active_king_slime: Node = null`，召唤时检查非空且 `is_instance_valid` → 拒绝二次召唤；Boss 死亡/消失时清空。

### 6. 史莱姆球投射武器（新 `scenes/entities/slime_ball.tscn` + 脚本）

以 `arrow.gd` 为模板，区别：
- **受重力**（arrow 是直线无重力）：飞行抛物线。
- **弹跳**：撞到实心方块/地面时反弹（反转对应速度分量 + 衰减，如 ×0.6），最多弹 `MAX_BOUNCES = 3` 次后销毁；命中怪即造成伤害 + 销毁。
- **伤害**：高于同期铁剑（iron tier 4 剑约 10 伤）——设 `BASE_DAMAGE` 让它明显更强（如 16）。
- 发射：`player_action.gd` 加 `tool_kind == "slimeball"` 分支（仿 `_try_fire_bow`），朝鼠标方向投出，无需弹药（Boss 武器，直接投）。

### 7. 美术（程序绘制占位，无 PNG）

- **史莱姆王**：复用 `SlimeArt.build_sprite_frames()` 放大 + 皇冠覆盖（可在 `art_cache` 里基于 slime_frames 合成，或 king_slime 场景里 sprite scale + 单独皇冠 Sprite2D 子节点）。
- **史莱姆球**：小圆黏球贴图（绿色半透明，参考 `arrow_proj_art` / `fireball` 弹射物美术写法），注册到 `ArtCache`。
- **史莱姆王冠 + 史莱姆球 物品 icon**：加到物品图标生成（`ArtCache.get_inventory_icon` 来源），王冠 = 黄色小皇冠，球 = 绿黏球。

### 8. world.gd 接线

- `const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")`。
- `func spawn_king_slime(pos) -> bool`：检查无存活 Boss → 实例化、放到 entities 容器、记 `_active_king_slime`、返回成功。
- 存档：Boss 是临时战斗实体，**不存档**（玩家退出存档时若 Boss 在场，重进不恢复——同泰拉瑞亚）。确认现有 entities 快照逻辑不会误存 Boss（用 group `boss` 排除，或不在存档实体白名单）。

## 验收（GUT 集成测试，无 GUI）

新建 `tests/integration/test_king_slime.gd`：

1. **基础属性**：King Slime `max_health == 1000 × 难度倍率`，接触伤害 20。
2. **召唤**：手持 slime_crown 使用 → `world` 出现 King Slime 且王冠 -1；已有 Boss 时再用 → 不召唤、王冠不减。
3. **召唤小兵阶段**：把 Boss 血降到 < 50% → 跑若干秒 → 场上多出普通史莱姆（且不超上限）。
4. **缩小提速**：Boss 满血 scale > 低血 scale；低血跳跃间隔 < 满血间隔。
5. **掉落**：Boss 死亡 → 掉 slime_ball ×1 + slime_jelly ×N。
6. **收尾**：玩家死亡 或 远离超阈值 → Boss 消失（不掉落）。
7. **史莱姆球**：投出受重力下坠、撞地反弹（bounce 计数增加），命中怪扣血。
8. **配方/中文名**：slime_crown 配方存在（9 jelly + workbench）；slime_crown / slime_ball 在 `_ZH_NAMES` 有中文。

## 范围之外（YAGNI）

- 召唤限制（白天/夜晚/地表）——任何时候都能用王冠。
- Boss 专属 BGM（可后续加）。
- 多个 Boss / 困难模式变体。
- 史莱姆球的弹药消耗（直接投，不耗材料）。
- 史莱姆王传送（瞬移）招式——本次只做经典三招。

## 涉及文件清单

- `scripts/items/item_db.gd`：加 slime_crown / slime_ball
- `scripts/ui/crafting_panel.gd`：`_ZH_NAMES` 加两个中文名
- `scripts/crafting/recipe_db.gd`：加 slime_crown 配方
- `scripts/player/player_action.gd`：summon 使用分支 + slimeball 发射分支
- `scripts/entities/king_slime.gd` + `scenes/entities/king_slime.tscn`：新建 Boss
- `scripts/entities/slime_ball.gd` + `scenes/entities/slime_ball.tscn`：新建投射物
- `scripts/world/world.gd`：spawn_king_slime + 活 Boss 追踪 + preload
- `scripts/art/*` + `scripts/autoload/art_cache.gd`：王冠/球/icon 美术注册
- `tests/integration/test_king_slime.gd`：新建测试
