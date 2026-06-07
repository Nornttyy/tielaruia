# 水下植物 (Submerged Plants) — 设计文档

- 日期: 2026-06-07
- 状态: 已与用户确认方案, 待写实现计划
- 一句话: 让水**穿过植物而不冲掉它们** —— 水流进植物格时把植物记进一层独立元数据(不占显示格)、显示水; 水退了把植物放回来。横竖都能穿, 进存档。

## 目标

- 水流(横向 / 下落 / 瀑布 / 淹没成潭)碰到植物 → 水照常流过去/填满, **植物不被销毁**, 只是"泡在水里"(那格显示水)。
- 水退走(挖渠排水 / 蒸发? 无) → 之前泡水的植物**重新露出来**。
- 存档退出再进来: 泡在水里的植物不丢。
- **不**碰水的流动行为 / 水位 / 找平 / 联机权威 —— 只加"进水记植物、退水复原"。

## 非目标 (YAGNI)

- **不做**水和植物同格的"水草"专用贴图(组合贴图会 tile id 爆炸)。泡水时那格就显示普通水, 植物存在元数据里。
- **不做**细水流穿植物的"防闪烁"平滑(见下"已知限制")。
- **不改**火把 / 史莱姆火把 / 绳子 —— 它们在 `is_plant` 清单里但属于玩家搭建/功能件, 不是植物, 水不淹它们(火把泡水灭灯也怪)。岩浆碰植物维持现状(岩浆本就不流进植物)。

## 背景 (现状)

- 水是格子 tile, `water_sim.gd` 模拟, 经 `world._set_water_tile_fast(x,y,tid)` 写进 chunk + 渲染 + 联机广播 + 通知 minimap。
- `_water_enterable(tid)` (water_sim.gd) 现在只认 `AIR` 和 `PLANT_GRASS` → 水只会流进空气和装饰小草, **小草被直接覆盖销毁**, 别的植物挡住水。
- `tile_data.gd` 有 `is_plant(tid)` + `_PLANT_TILES` 清单(树/叶/仙人掌/蘑菇/地狱果/火把/史莱姆火把/绳子/装饰草/小麦4阶/稻子4阶)。**所有植物都是非实心**(`solid:false`, 玩家能穿, 树干也能穿)。
- **背景墙系统是完美模板**: chunk_manager 用独立 `_wall_deltas` (chunk_x → Dict[Vector2i_local → wall_id]), `get_wall`/`set_wall`, `_load_chunk` 里 `apply_wall_delta`; 存档 `save_data.wall_deltas` + `save_manager._serialize_wall_deltas`/`apply_wall_deltas`。见 [[project-wall-system]]。

## 设计

水下植物**不是要渲染的图层**(那格显示水), 只是"这格水底下记着哪株植物"的**元数据**。所以比墙还简单: 存在 chunk_manager 里, **不动 chunk 的 tile 数组渲染**。

### A. 可淹没植物集合 (tile_data.gd)

`is_submersible_plant(tid) -> bool` = `is_plant(tid)` 且 **不是** `TORCH / SLIME_TORCH / ROPE`。
(即: PLANT_GRASS / MUSHROOM / HELL_FRUIT / 小麦4 / 稻子4 / CACTUS / CACTUS_BODY / LEAVES·LEAVES_PINE·LEAVES_AUTUMN·JUNGLE_LEAVES / LOG·LOG_TOP·LOG_ROOT_L/R·BRANCH_L/R。)

### B. 水模拟让水能流进植物 (water_sim.gd)

- `_water_enterable(tid)`: 从 `AIR or PLANT_GRASS` 改成 `tid == AIR or Tiles.is_submersible_plant(tid)`。横向流(`_step_water_lateral` 用 `_water_enterable`)自动覆盖。
- 重力下落分支: `if below_tid == AIR or (kind == "water" and below_tid == PLANT_GRASS)` → 改成 `if below_tid == AIR or (kind == "water" and Tiles.is_submersible_plant(below_tid))`。
- **water_sim 不碰植物存储** —— 它照常调 `world._set_water_tile_fast` 写水, 植物记/复原全在 C 的总闸里做。流动逻辑(水位/找平/反应)一行不动。

### C. 进水记植物 / 退水复原 (chunk_manager.gd + world.gd 总闸)

chunk_manager 加 `_submerged` 层 (照 `_wall_deltas` 结构: chunk_x → Dict[Vector2i_local → plant_tid]):
- `get_submerged(world_x, world_y) -> int` (没有返回 -1)
- `set_submerged(world_x, world_y, plant_tid)`
- `clear_submerged(world_x, world_y)`

`world._set_water_tile_fast(x, y, tile_id, from_remote)` 加总闸 (在 `chunk_manager.set_tile` **之前**):
```
# 水下植物: 要写水 → 先记下这格的植物; 要写空气 → 若底下记着植物则复原植物
if Tiles.is_water(tile_id):
    var existing := chunk_manager.get_tile(x, y)
    if Tiles.is_submersible_plant(existing):
        chunk_manager.set_submerged(x, y, existing)
elif tile_id == Tiles.AIR:
    var plant := chunk_manager.get_submerged(x, y)
    if plant != -1:
        tile_id = plant                 # 退水: 写回植物而不是空气
        chunk_manager.clear_submerged(x, y)
```
然后照常 `set_tile(x, y, tile_id)` + 渲染 `tile_id` (可能已是植物) + 广播 + 通知。
- 只认 `is_water` (岩浆不记植物 → 岩浆碰植物维持现状)。
- 覆盖**所有**水写入路径(重力/横向/瀑布源/settle找平)与退水路径, 因为都过这一个闸。
- 联机: host 权威。host 复原植物后广播的就是植物 tile, client 直接渲染。client 端 from_remote 也走同逻辑(幂等, 无害)。

### D. 存档 (save_data.gd + save_manager.gd)

照 `wall_deltas` 平行加一份:
- `save_data.gd`: `@export var submerged_plants: Dictionary = {}` + `CURRENT_VERSION` +1 (旧档无此字段 → 默认空, 兼容)。
- `save_manager.gd`: `_serialize_submerged(cm)` + `apply_submerged(cm, serialized)` (结构/写法同 `_serialize_wall_deltas`/`apply_wall_deltas`, str(cx) key 防 0 号区块丢)。
- save 时 `data.submerged_plants = _serialize_submerged(world.chunk_manager)`; load 时 `apply_submerged`。

## 已知限制 (v1, 先说好)

- **细水流闪烁**: 一条很细的流(每 tick 一格水穿过植物)那格会 水→植物→水 快速交替(进水记植物、下一 tick 水走了复原植物、再下一 tick 又进水)。**水潭/淹没(静止水)不闪**(那格一直是水, 植物稳稳泡着)。绝大多数场景是后者, v1 接受这个闪烁。
- 泡水植物**不生长**(被水占格期间作物不进阶) —— 可接受(退水后继续)。

## 不变项 (回归保障)

- water_sim 流动逻辑 / 水位 / 找平 / 反应 / `Tiles.is_water` / 联机权威 —— 不动。
- 墙系统 / 现有 chunk_deltas / 存档其余字段 —— 不动。
- 旧存档(无 submerged_plants 字段)照常读(默认空)。

## 文件清单

修改:
- `scripts/world/tile_data.gd` — `is_submersible_plant()` + 集合
- `scripts/world/water_sim.gd` — `_water_enterable` + 重力分支认可淹没植物 (不碰流动逻辑)
- `scripts/world/chunk_manager.gd` — `_submerged` + get/set/clear (照 _wall_deltas)
- `scripts/world/world.gd` — `_set_water_tile_fast` 加进水记/退水复原总闸
- `scripts/save/save_data.gd` — `submerged_plants` 字段 + CURRENT_VERSION+1
- `scripts/save/save_manager.gd` — serialize/apply submerged

新增测试:
- `tests/unit/test_submerged_plants.gd` — is_submersible_plant 集合 / chunk_manager get-set-clear / 序列化往返
- `tests/integration/test_submerged_plants_flow.gd` — 水流进植物格(enterable) / 进水记植物退水复原(走 world 真路径或 FakeWorld+chunk_manager) / 旧档兼容

## 测试策略

- `is_submersible_plant`: 断言草/蘑菇/作物/树/叶 = true; 火把/绳子/石头/空气 = false。
- chunk_manager: set_submerged 后 get 拿到; clear 后 get 返 -1; 不同 chunk 不串。
- 总闸: 给一格放 PLANT_GRASS → 写 WATER → 该格变 WATER 且 get_submerged 拿到 PLANT_GRASS; 再写 AIR → 该格变回 PLANT_GRASS 且 get_submerged 返 -1。(需真 chunk_manager + world, 用 boot_to_game 或最小化构造。)
- 存档往返: set_submerged 几格 → serialize → apply 到新 cm → get 一致。
- 旧档兼容: 无 submerged_plants 的 SaveData 读出来 = 空 dict, 不崩。
- 回归: `test_liquid_flow` / `test_water_settles` / `test_smoke` 全过 (水行为不变)。

## 风险

- **并发**: `water_sim.gd` 别的 session 在动 —— 隔离 worktree, 只改 `_water_enterable` + 1 个重力分支条件, 别的不碰。`world.gd` 大文件 —— 只在 `_set_water_tile_fast` 加总闸。
- **存档兼容**: CURRENT_VERSION +1, 旧档无字段默认空 dict, 已测。
- **联机**: host 权威, client 走 from_remote 同逻辑幂等。MP 是次要里程碑, 单机为主。
