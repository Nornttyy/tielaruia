# Chunk 流式无限地图 — Design

- **日期**: 2026-05-20
- **状态**: v1 草案, 等用户复审
- **作者**: AI 与用户协作

## 1. 背景

当前世界固定 `1024 × 256`,启动时一次性生成全部 tile,装入一个内存数组。玩家走到边就停下。要"真正无限"需要把世界生成做成按需 (on-demand)。

本 spec 把世界改造成 **按列 (chunk) 流式生成**:
- 每个 chunk = `64 宽 × 256 高` 一柱
- 玩家左右 ±2 chunk 常驻 (共 5 chunk = 80k tiles)
- 走远了卸载老 chunk,新 chunk 现算
- 修改的方块按 chunk 缓存 (delta),本局内 chunk 卸载再加载能恢复
- 不持久化跨 session (刷新页面 = 新世界)

## 2. 范围

### 2.1 In Scope

- ✅ 横向无限世界 (chunk_x 可正可负)
- ✅ 每 chunk 独立从 seed + chunk_x 决定性生成
- ✅ ChunkManager 跟踪 loaded chunks + 玩家修改 delta
- ✅ World 每帧检测玩家所在 chunk,触发 load/unload
- ✅ TileMapLayer 通过 ChunkManager 间接更新,unload 时 set_cell(-1)
- ✅ SkyLightGrid 改成按列懒填 Dict
- ✅ 卸载的 chunk 内 slime/drop 自动 queue_free
- ✅ 出生点在中心 chunk (chunk_x=0) 内找
- ✅ 启动每次随机 seed (`world_seed = randi()`)
- ✅ 单测 + 集成测试不破

### 2.2 Out of Scope

- ❌ localStorage 跨 session 持久化
- ❌ 异步生成 / 后台线程 (同步即可,实测 5-10ms 一 chunk)
- ❌ 垂直 chunking (高度仍 256 固定)
- ❌ 卸载 chunk 内的玩家修改能在远处显示 (不显示, 走回去再说)
- ❌ chunk LOD / 远处简化渲染
- ❌ 树跨 chunk 边界的完美无缝 (有 ±4 buffer 减少穿帮)

## 3. 架构

### 3.1 组件图

```
World (.gd)
  ├ ChunkManager (持有)
  │   ├ _loaded: Dictionary[int chunk_x → Chunk]
  │   ├ _deltas: Dictionary[int chunk_x → Dictionary[Vector2i local_xy → int tid]]
  │   ├ ensure_loaded(player_chunk_x)
  │   ├ get_tile(world_x, world_y) -> int
  │   ├ set_tile(world_x, world_y, tid)
  │   └ unload(chunk_x)
  │
  ├ TerrainLayer (TileMapLayer) — 实际渲染
  ├ SkyLightGrid (autoload) — 懒填 light_top dict
  └ Entities (slimes, drops, player)

WorldGenerator (RefCounted, static)
  ├ generate_chunk(seed, chunk_x, height=256) -> Chunk
  └ generate(seed, w, h) — 向后兼容包装器

Chunk (RefCounted)
  ├ chunk_x: int
  ├ tiles: Array[Array[int]]  # 64×256
  └ apply_delta(delta_dict)
```

### 3.2 关键常量

```gdscript
const CHUNK_WIDTH := 64
const WORLD_HEIGHT := 256
const VIEW_RADIUS := 2   # 左右各 N chunk
const CHUNK_REGEN_BORDER := 4   # 树冠 buffer 列数 (避免 chunk 边界树冠裁切)
```

## 4. 关键数据流

### 4.1 初始加载

```
World._ready:
  1. world_seed = randi() (随机种子)
  2. chunk_manager = ChunkManager.new()
  3. chunk_manager.ensure_loaded(0)   # 加载 chunks -2..+2
  4. spawn_point = chunk_manager.find_spawn_in_chunk(0)
  5. player.position = spawn_point world coords
  6. SkyLightGrid 自动按需查 (玩家附近列)
```

### 4.2 玩家走 → 触发 load/unload

```
World._physics_process(delta):
  var pcx = player.x // CHUNK_WIDTH // TILE_SIZE
  if pcx != _last_player_chunk_x:
    _last_player_chunk_x = pcx
    chunk_manager.ensure_loaded(pcx)
    chunk_manager.unload_far_from(pcx, VIEW_RADIUS + 1)
```

`ensure_loaded(center_cx)`:
- for cx in [center_cx-VIEW_RADIUS .. center_cx+VIEW_RADIUS]:
  - if not _loaded.has(cx):
    - chunk = WorldGenerator.generate_chunk(seed, cx)
    - chunk.apply_delta(_deltas.get(cx, {}))
    - _apply_to_tilemap(chunk)
    - _loaded[cx] = chunk

`unload_far_from(center_cx, max_dist)`:
- for cx in _loaded.keys().filter(|c| abs(c-center_cx) > max_dist):
  - _clear_from_tilemap(_loaded[cx])
  - 移除该 chunk 范围内的 slime/drop (group 查询 + 距离过滤)
  - _loaded.erase(cx)
  - (delta 保留, 走回来时恢复)

### 4.3 玩家挖/放

```
World._set_tile(world_x, world_y, tid):
  chunk_x = world_x // CHUNK_WIDTH
  local_x = world_x % CHUNK_WIDTH
  if _loaded.has(chunk_x):
    _loaded[chunk_x].tiles[local_x][world_y] = tid
  # 记入 delta 即便 chunk 未来 unload 也能恢复
  _deltas[chunk_x] = _deltas.get(chunk_x, {})
  _deltas[chunk_x][Vector2i(local_x, world_y)] = tid
  TerrainLayer.set_cell(Vector2i(world_x, world_y), tid)
  SkyLightGrid.invalidate_column(world_x)
```

### 4.4 SkyLightGrid 懒填

```
SkyLightGrid:
  _light_top: Dictionary[int x → int top_y]

  is_sky_exposed(x, y) -> bool:
    if not _light_top.has(x):
      _light_top[x] = _compute_light_top(x)
    return y <= _light_top[x]

  _compute_light_top(x) -> int:
    # 从顶向下找第一个 solid tile
    for y in WORLD_HEIGHT:
      var tid = ChunkManager.get_tile(x, y)
      if Tiles.is_solid(tid):
        return y - 1
    return WORLD_HEIGHT - 1

  invalidate_column(x):
    _light_top.erase(x)
```

ChunkManager.get_tile 会按需 load chunk 吗? **否** — get_tile 对 unloaded chunk 返回 AIR。`SkyLightGrid.is_sky_exposed` 调用方应只在加载范围内查询。在卸载列上查询返回"全暴露" (无误,因为 chunk 不可见时光照状态不重要)。

## 5. WorldGenerator 重构

### 5.1 新 API: `generate_chunk(seed, chunk_x)`

```gdscript
static func generate_chunk(world_seed: int, chunk_x: int,
		height: int = 256, chunk_width: int = 64) -> Chunk:
	var c := Chunk.new()
	c.chunk_x = chunk_x
	c.tiles.resize(chunk_width)
	# 噪声: seed 控制全局, x 是世界坐标 (chunk_x * chunk_width + local_x)
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	# ... 同既有逻辑, 但 x 是世界坐标
	for local_x in chunk_width:
		var world_x: int = chunk_x * chunk_width + local_x
		var n: float = noise.get_noise_1d(float(world_x))
		var surf_y: int = clampi(int(height * (SURFACE_BASE + n * SURFACE_AMP)), 4, height - BEDROCK_ROWS - 1)
		# ... 填这一列
		c.tiles[local_x] = _generate_column(world_seed, world_x, surf_y, height)
	# 树木: 扩展 chunk_x ±1 列扫描, 但只写本 chunk 范围
	_place_trees_in_chunk(c, world_seed, chunk_x, chunk_width, height)
	return c
```

### 5.2 既有 generate() 改包装

```gdscript
static func generate(world_seed: int, width: int = 1024, height: int = 256) -> Dictionary:
	var tiles := []
	tiles.resize(width)
	var num_chunks: int = ceili(float(width) / 64.0)
	for cx in num_chunks:
		var chunk := generate_chunk(world_seed, cx, height)
		for local_x in chunk.tiles.size():
			var world_x: int = cx * 64 + local_x
			if world_x < width:
				tiles[world_x] = chunk.tiles[local_x]
	# 出生点: 在 chunk 0 内找
	var spawn_point: Vector2i = _find_spawn_in_chunk_0(tiles, height)
	return {"tiles": tiles, "spawn_point": spawn_point, "seed": world_seed, "width": width, "height": height}
```

(已有 test_world_generator.gd 走这条路径, 不需要改测试。)

### 5.3 树跨 chunk 边界

每 chunk 生成树时,**扫描自己 ±4 列范围** (chunk_width + 2*4 = 72 列),决定哪些 x 是 trunk_x。
- 但只在 trunk_x 落在自己范围 [chunk_x*64, chunk_x*64+63] 时实际放
- 树冠可以画到 buffer 区域 (即下一 chunk 范围)
  - 暂存到 chunk 的 "overflow" 字典: `Dictionary[int neighbor_chunk_x → Dictionary[Vector2i local_xy → int tid]]`
  - 当邻 chunk load 时,先应用本 chunk overflow 再画
- 这样保证树冠不会因 chunk 边界被裁

简化版 (v1 初始实现): 不管 overflow, 树冠超出自 chunk 直接丢弃 (画不到)。边界处偶尔出现"半棵树"。后续优化。

## 6. 文件改动清单

| 路径 | 类型 | 说明 |
|---|---|---|
| `scripts/world/chunk.gd` | 新 | RefCounted 数据类 (chunk_x + tiles 64×256) |
| `scripts/world/chunk_manager.gd` | 新 | 持有 _loaded + _deltas + 调度 |
| `scripts/world/world_generator.gd` | 改 | 加 generate_chunk(), generate() 改包装器 |
| `scripts/world/world.gd` | 改 | 用 ChunkManager 替代 _tiles 数组; 加 _physics_process chunk 检查 |
| `scripts/world/sky_light_grid.gd` | 改 | _light_top 改 Dictionary, 懒填 |
| `tests/unit/test_chunk_manager.gd` | 新 | ensure_loaded / unload / get_tile / set_tile / delta 持久 |
| `tests/unit/test_world_generator.gd` | 不改 | generate() 仍工作 |

## 7. 测试策略

### 7.1 单元
- `test_chunk_manager`:
  - `ensure_loaded(0)` 加载 chunks -2..2 (5 个)
  - `unload_far_from(5, 2)` 卸载 -2..3,留 4..7
  - `set_tile + unload + reload`: 走远后回来,修改还在
  - `get_tile`: 加载/卸载 chunk 行为
- `test_world_generator`: 加 `generate_chunk(seed, 0).tiles.size() == 64`

### 7.2 集成
- `test_full_loop.gd` 等仍跑通 (用既有 generate() 包装器)
- 新 `test_chunk_streaming.gd`: 模拟玩家从 chunk 0 走到 chunk 5,验证沿途 load/unload

### 7.3 手动验收
- 启动: 每次世界形状不同 (随机 seed)
- 朝一边狂奔: 不卡顿,世界一直延伸
- 挖个洞,走 5 chunk 远,回来,洞还在
- 走太远后没原地不动,slime/drop 数量正常

## 8. 风险

| 风险 | 缓解 |
|---|---|
| 半棵树穿帮 | v1 接受; 后续 overflow 字典优化 |
| chunk 边界处玩家走过去时短暂"没地"摔下 | _physics_process 在 chunk 切换瞬间 sync 加载 (同步生成 10ms 内 OK) |
| 测试集成耗时增长 (走远场景) | 限制测试中 chunk 数 |
| delta 内存无上限 (玩家持续挖) | 一局内可接受,未来加压缩或清理 |
| SkyLightGrid 远 x 列缓存膨胀 | 玩家离开 chunk 时同步 invalidate (清缓存) |

## 9. 验收

- [ ] 启动每次世界形状随机
- [ ] 玩家朝一边走 1 分钟不卡顿,地图持续延伸
- [ ] 挖坑 → 走 5 chunk → 回来坑还在
- [ ] 卸载 chunk 后 slime 不在 entity 树里 (group 查询)
- [ ] 既有 138 个 GUT 测试不破
- [ ] 新加的 test_chunk_manager 至少 5 个测试通过

## 10. 修订

- **v1 (2026-05-20)** — 草案, 64 宽柱 / ±2 半径 / 本局内 delta 持久
