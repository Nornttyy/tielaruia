# 成就/目标系统设计

用户(10岁)选了"目标/成就系统"补足游戏最大缺口: 缺奔头/不知道该干嘛。

## 目标
进游戏做到里程碑 → 弹"🏆 成就达成: XXX" + 永久记录。给玩家方向感 + 收集炫耀。

## 架构 (低侵入: 尽量不改 gameplay 代码)
- `Achievements` autoload (`scripts/autoload/achievements.gd`):
  - `_DEFS`: 每个成就 {id, name(中文), desc, 以及 "item" 或 "event"}。
  - **物品类** (`item`): autoload 每 ~1s 轮询本地玩家 `PlayerInventory.has_item(id)`, 拿到过就解锁。
    **零 gameplay 改动** — 覆盖大部分进度成就。
  - **事件类** (`event`): 代码调 `Achievements.fire("event_id")` 解锁。只 Boss 死亡 2 处加钩子。
  - `unlock(id)` / `fire(event)` / `is_unlocked(id)` / `all_defs()`。
  - 持久化: 账号级 `user://achievements.cfg` (跨世界跨角色, 照 Terraria)。
  - 信号 `achievement_unlocked(id, name)`。
  - 自带 toast: autoload 在 `_ready` 建一个 CanvasLayer 子节点, 监听自己的信号, 顶部滑入弹窗 ~3s。

## 成就清单 (Step 1: 12 物品 + 2 Boss)
物品类: log(伐木工)/stone(石器时代)/iron_ore(见铁了)/diamond(闪闪发光)/wood_sword(武装自己)/
pistol(砰!)/wood_bow(百步穿杨)/bed(安个家)/fishing_rod(钓鱼佬)/bread(干饭人)/
slime_jelly(史莱姆猎人)/feather(云端漫步=上空岛)。
事件类: boss_king_slime(屠王者)/boss_skeleton_king(骨王克星)。

## 钩子 (就 2 处)
- `king_slime._die()` → `Achievements.fire("boss_king_slime")`
- `skeleton_king._die()` → `Achievements.fire("boss_skeleton_king")`

## 验收 (GUT)
- fire(event) → 对应成就解锁 + 发信号。
- has_item 轮询: 玩家有 item → 解锁。
- 重复 unlock 不重复发信号。
- 存读: 解锁写盘, 重读还在。

## Step 2 (下批)
- 成就查看面板 (看全部 + 灰色未解锁) , 入口暂停菜单或主菜单。
- 更多事件钩子: 第一次死亡 / 下地狱 / 第一次合成 / 钓到鱼。
