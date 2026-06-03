# 骷髅王 (Skeleton King) Boss 设计

- 日期：2026-06-03
- 状态：设计已与用户(10岁)讨论通过，待实现
- 来源：用户「我要加一个 boss 叫骷髅王」+ 逐项选择

## 目标

加一个新 Boss「骷髅王」。**骷髅骑士造型**，体型 ≈ 玩家身高再高一点点（不是巨型大块头，是同体型单挑对手；靠破王冠+红眼+斗篷+顶部 Boss 血条体现 Boss 身份）。用骨头合成召唤物召唤，4 招混合战斗，掉骨头+骨剑（必）+骷髅盔甲/法杖（几率）。

照搬现有**史莱姆王**(`king_slime.gd`)模式：CharacterBody2D + group `boss`/`slimes`(改 `skeletons`) + `boss_display_name()` + 召唤道具(`tool_kind:"summon"`) + `world.spawn_*` 单例 + Boss 血条自动显示 + 不与玩家物理碰撞 + 远离/玩家死亡 despawn。

## 现状摸排（可复用）

- **Boss 模式**：`scripts/entities/king_slime.gd` —— HP、缩放、跳/走、阶段召唤小兵、`take_damage`、`_die` 掉落、despawn、`melee_hit_radius()`、`boss_display_name()`。
- **召唤链**：`item_db` `tool_kind:"summon"` → `player_action.gd:1599 try_use_summon_item()` → `world.spawn_king_slime(pos)`（**目前硬编码召唤史莱姆王，需泛化**）。`world.gd:88 _active_king_slime` 单例守卫。
- **Boss 血条**：`scripts/ui/boss_bar.gd` —— 自动找 group `boss`，读 `current_health/max_health/boss_display_name()`。**无需改**。
- **小兵复用**：`scenes/entities/skeleton.tscn` + `skeleton.gd` 已存在（地狱骷髅，掉 1-2 bone）。骷髅王 `_spawn_minions` 直接 instantiate 它。
- **骨头 item**：`bone`（"骨头", max_stack 99）已存在，骷髅会掉 → 召唤头骨可合成。
- **盔甲格式**：`item_db` `armor_slot:"helmet"/"chest"/"pants"` + `defense:N`。
- **难度缩放**：`GameSettings.enemy_hp_multiplier()`（HP 用）。攻击伤害是否有 multiplier 实现期确认；没有就用固定值。
- **art 路子**：`scripts/art/skeleton_art.gd`（程序画骷髅帧）可参考；骷髅王单独画 `skeleton_king_art.gd`。

## 设计

### A. Boss 实体 `scripts/entities/skeleton_king.gd` + `scenes/entities/skeleton_king.tscn`

- extends CharacterBody2D；group：`boss` + `skeletons` + `skeleton_king`。
- HP `BASE_MAX_HEALTH := 1200`，× `enemy_hp_multiplier()`。
- 体型：≈ 玩家(2.5 格高)再高一点 → 目标 **~3 格高**（scale 让骷髅 sprite 约 36px 高）。**非巨型**，`melee_hit_radius()` 给个小值（如 8-10）或不给（玩家正常能打中）。
- 移动：受重力，`is_on_floor` 时朝玩家**慢走**（move_toward x，速度 ~40px/s），不蹦。
- 接触伤害 `CONTACT_DAMAGE := 15`（玩家碰到身子）。
- `_add_player_exception()` 不与玩家物理碰撞（CLAUDE.md 规矩）。
- `take_damage`/`_hit_flash`/`_iframe`/`Effects.spawn_damage_number` 照搬 king_slime。
- despawn：玩家死/远离 `DESPAWN_DISTANCE_PX`(960) 超 `DESPAWN_AFTER_SEC`(5) → queue_free（不掉落）。
- `has_meta("is_remote")` 分支照搬（联机：远程王仍能打本地玩家，不跑 AI）。
- `boss_display_name() -> "骷髅王"`。

### B. 攻击 AI（按距离+血量选招）

`_attack_timer` 冷却（满血 ~2.0s，血<50% ~1.2s 更频）。冷却到 0 时 `_pick_attack()`：

| 玩家距离(px) | 招 | 伤害 | 行为 |
|---|---|---|---|
| 远 > 7*TILE | 🦴 throw_bones | 12 | 甩 1-3 个**飞骨头投射物**朝玩家（见 C），略带抛物线 |
| 中 3-7*TILE | 💨 dash | 18 | 朝玩家方向**冲刺**一段（短时高速 vx，撞到玩家 = dash 伤害）。冲刺中 sprite 微倾/拖影 |
| 近 < 3*TILE | 🗡️ sweep | 22 | 抡大骨刀**半圆扫**（复用 player sweep 思路：一段时间内扫 grip→tip 线段判定，命中玩家扣血）|

- **召唤小兵**（独立计时，非上表）：血 < 50% 时每 `MINION_INTERVAL`(~5s) `_spawn_minions()` 出 2-3 个 `skeleton`，受 `MINION_CAP`(~6) 限。
- 每招有短"前摇/动画"窗口（telegraphed），让玩家有反应时间。实现期用计时态(state machine)：`idle/throw/dash/sweep` + `_attack_t`。
- 招的伤害走玩家 `PlayerHealth.take_damage(dmg, source_pos, knockback)`。

### C. 飞骨头投射物 `scripts/entities/bone_projectile.gd`（+ 简单 scene 或纯脚本生成）

- 小骨头 sprite，沿初速度飞（朝玩家 + 轻重力），碰到玩家 → `take_damage(12)` + queue_free；超 `LIFETIME`(~3s) 或落地 → queue_free。
- 不与地形精细碰撞也行（简单：到寿命/到玩家就消失）。联机：host 权威生成，广播（实现期参考现有 projectile 同步，若复杂则 P1 先本地，联机投射物留后续）。

### D. 召唤链泛化

- **新 item `skull_summon`**（"骷髅头骨"，`tool_kind:"summon"`, max_stack 1）。
- `player_action.try_use_summon_item()`：现在硬编码 `spawn_king_slime`。改为按手持 summon item 派发：
  - `slime_crown` → `world.spawn_king_slime`
  - `skull_summon` → `world.spawn_skeleton_king`
  - 用映射 or item def 上加字段 `"summon_boss":"skeleton_king"`，player_action 读它选 `world.spawn_<x>`。**推荐 def 字段**（开放扩展，不写死 if-else）。
- `world.gd` 加 `spawn_skeleton_king(pos)` + `_active_skeleton_king` 单例守卫（仿 `spawn_king_slime`）。
- 召唤头骨配方：`bone` ×N（如 8-10 个）合成 1 个 `skull_summon`（普通合成台）。

### E. 掉落（`_die()`）

- **必掉**：`bone` ×15-25；`bone_sword` ×1。
- **几率**：`skeleton_helmet`/`skeleton_chest`/`skeleton_pants` 各 ~40%；`skull_staff` ~25%。
- 用 `_spawn_drop(item_id, count)`（仿 king_slime，支持 count）。

### F. 新 item（每个**4 处注册** + 适配）

1. `skull_summon`（召唤头骨）：`tool_kind:"summon"` + `"summon_boss":"skeleton_king"`；配方 bone×N；art（骷髅头像素）。
2. `bone_sword`（骨剑 = **阔剑**）：`tool_kind:"sword"`, `tool_tier` ~7（强，钻石档附近）, `"sword_style":"sweep"`, `damage_mult` ~1.3（boss 武器略强）, max_stack 1；art（骨白剑身 + 骨刺）。**无配方**（只 boss 掉）。
3. `skeleton_helmet/chest/pants`（骷髅盔甲）：`armor_slot` + `defense`（helmet 7 / chest 10 / pants 7，银/铁档之上）；art（骨白盔甲）。boss 掉为主，可选加配方（bone+骨头材料）。
4. `skull_staff`（骷髅法杖，**P3**）：召唤友方小骷髅帮玩家打（新机制：友方实体），或退化为发骨头投射物。P3 再细化。

> 4 处注册：`item_db._DEFS` / `crafting_panel._ZH_NAMES` / `items_art._ICONS` / `art_cache item_icons`。放置物才需 `_ITEM_TO_TILE`（这些都不是）。中文名：骷髅头骨/骨剑/骷髅头盔/骷髅胸甲/骷髅腿甲/骷髅法杖。

### G. 美术 `scripts/art/skeleton_king_art.gd`（程序画）

- 骷髅骑士：白骨身 + **破铁王冠**（灰铁+缺口）+ **红眼眶**（发红光）+ **破斗篷**（暗红/灰）+ **大骨刀**（手持，骨白）。
- 体型 ~3 格高，比普通骷髅大一档、armored 感。暖色基调（骨白偏暖、斗篷暗红、王冠暖灰铁）。
- 受击不染斗篷/王冠（独立层，仿 king_slime 王冠独立 sprite 不被染红）。
- 可做 idle + 攻击帧（throw/sweep/dash 各一两帧），或先静帧 + 程序位移动画（P1 够用即可）。

## 分阶段（每阶段独立可玩 + 测试）

- **Phase 1（核心 Boss，本次目标）**：实体 + 骑士 art + 移动 + 4 招(throw/dash/sweep/summon) + 飞骨头投射物 + 接触伤害 + despawn + Boss 血条 + `skull_summon`(+配方+泛化召唤) + `world.spawn_skeleton_king` + `bone_sword`(item+art) + `_die` 掉 bone + bone_sword。→ **召唤即可完整开打并拿到骨剑**。
- **Phase 2**：骷髅盔甲 3 件（item+art+几率掉，可选配方）。
- **Phase 3**：`skull_staff`（召唤友方小骷髅 / 或骨头投射）。最复杂，最后。

## 验收（GUT integration，无 GUI 全靠测试）

- `skull_summon` 是 summon item；手持右键 → `world.spawn_skeleton_king` 被调，场上出现 group `boss` + `skeleton_king` 实体，HP=1200×mult。
- 单例：已有骷髅王存活时再召唤被拒。
- `boss_display_name()=="骷髅王"`；boss_bar 能读到。
- 攻击：玩家放近/中/远，推进若干帧，`PlayerHealth` 掉血（各招都能造成伤害）；血<50% 出现 `skeleton` 小兵。
- 飞骨头投射物碰玩家扣 12。
- `take_damage` 打到 0 → `_die`：场上出现 `bone` 掉落 + `bone_sword` 掉落。
- `bone_sword`：ItemDB `sword_style=="sweep"`, tool_kind sword；`ArtCache.get_inventory_icon("bone_sword")` 非空。
- despawn：玩家移除/远离 → 超时 queue_free。
- 不与玩家物理碰撞（collision exception）。

## 不做（YAGNI / 留后续）

- P1 不做盔甲、不做法杖（Phase 2/3）。
- 不做复杂联机投射物同步（P1 本地优先；若简单顺手做 host 权威广播）。
- 不做多形态/坐骑/变身（用户要"同体型骑士"）。
- 不改史莱姆王。

## 风格/约束（CLAUDE.md）

- 全程中文、给用户的总结翻译成大白话。暖色可识别像素画。
- 加 item 必查 4 处注册 + 中文名。
- 信号 handler 不加 `await`。生物不与玩家+彼此物理碰撞（加 player exception）。
- 并发多 session：派活/提交只 `git add <具体路径>`，不用 `-am/-A/.`；不 `--amend`；提交前后看 `git log`。
