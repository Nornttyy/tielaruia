# 背景墙铺满 + 锤子破墙 — 2026-06-06

用户要: ① 所有方块后面都有背景墙 (植物除外) ② 加锤子 (全 tier, 速度不同) 破墙, 砸墙掉对应墙料.

## 现状 (地基已有)
- `wall_layer` (TileMapLayer, 渲染在 terrain 后) + `chunk.walls[lx][y]` 数据 + 4 种墙
  (GRASS_WALL/DIRT_WALL/STONE_WALL/WOOD_WALL) + 墙 autotile.
- 缺: ① 墙只从 surf+3 往下铺 (地表/浅层无墙); ② 墙改不了 (chunk_manager 无 set_wall)、
  不存档、放墙只改视觉不持久; ③ 没锤子、墙挖不掉.

## 第1步: 墙铺到地表 (植物除外)
- `tile_data.is_plant(tid)`: 非实心装饰 (叶/草/仙人掌/蘑菇/火把/火果/PLANT_GRASS 等).
- `world_generator._fill_walls_chunk`: wall_start 从 `surf+3` 改 `surf` (铺到地表块背后);
  跳过前景是植物的格 (`if is_plant(c.tiles[lx][y]): continue`). 天上 (y<surf) 仍无墙.

## 第2步: 墙数据层 + 存档 + 锤子
**数据/存档:**
- `chunk.apply_wall_delta(d)`.
- `chunk_manager`: `_wall_deltas` (独立于 tile `_deltas`, 防 Vector2i key 冲突);
  `set_wall(wx,wy,wid)` 写 chunk + _wall_deltas; `_load_chunk` 应用 _wall_deltas.
- `save_manager`: 序列化/还原 _wall_deltas (PackedInt32Array, str(cx) key, 同 tile delta).
- `world._set_wall(x,y,wid)`: chunk_manager.set_wall + wall_layer 视觉 (autotile + 刷邻居).
  统一入口; chunk 加载渲染 / 放墙 / 砸墙都走它附近逻辑.
- player_action 放墙改走 `world._set_wall` → 持久化.

**锤子 (8 tier, 速度递进):**
- item_db: wood/stone/copper/iron/silver/gold/diamond/hell `_hammer` (tool_kind "hammer",
  tool_tier 1-8, damage_mult 0, max_stack 1). + dirt_wall/grass_wall 墙物品 (is_wall, placeable).
- crafting_panel _ZH_NAMES: 8 锤子 + 土墙/草墙.
- recipe_db: 8 锤子配方. 形状 `XXX/XX./.X.` (区别于镐 `XXX/.X./.X.` 和斧 `XX./XX./.X.`),
  头=材质 (planks/stone/各 ingot/diamond), 柄=planks. 防 wood 全 planks 跟木镐撞.
- items_art: `_HAMMER_MATS` (item→[暗,主,亮]字母) + `_hammer_grid()` 模板批量生成, 不手画 8 个.
- player_action: 持锤 → `_update_wall_mining` 分支 (瞄空气格背后的墙; 前景非空不能砸).
  速度 `_hammer_speed(tier)` 递进; 砸完 world._set_wall(AIR) + 掉对应墙料 (wall_drop_item).
  创造模式秒砸. 锤子摆动复用镐子 spin.

## 掉落映射 (tile_data.wall_drop_item)
GRASS_WALL→grass_wall, DIRT_WALL→dirt_wall, STONE_WALL→stone_wall, WOOD_WALL→wood_wall.

## 验收 (GUT)
- is_plant 认对植物; 生成: 地表块背后有墙、植物格无墙、天空无墙.
- set_wall/_wall_deltas 改墙 + reload 恢复; save/load round-trip 墙 delta.
- 8 锤子存在 (tool_kind hammer, tier 1-8) + 图标渲染 + 8 配方; 土墙/草墙物品+中文名.
- 锤子砸墙: 前景空才砸, 砸完墙没了 + 掉墙料 + 持久 (chunk delta).
- smoke 6/6.

## 坑
- 墙物品加 ItemDB 必同步 _ZH_NAMES (漏=显示英文).
- _wall_deltas 必须独立于 _deltas (同 Vector2i key 会串).
- MP 墙同步暂不做 (现状放墙本就不同步; 标记 follow-up).
