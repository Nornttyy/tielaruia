# 世界根：通过 ChunkManager 流式加载 64-宽列, 每次启动随机种子。
# 维护 TileMapLayer 视觉 (chunk_loaded/unloaded 信号驱动)。
extends Node2D

const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")
const MinimapDataClass = preload("res://scripts/world/minimap_data.gd")
const WeatherClass = preload("res://scripts/world/weather.gd")
const RainLayerClass = preload("res://scripts/fx/rain_layer.gd")
const FirefliesClass = preload("res://scripts/fx/fireflies.gd")
const ShootingStarClass = preload("res://scripts/fx/shooting_star.gd")
const FallingLeavesClass = preload("res://scripts/fx/falling_leaves.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const VillagePrefab = preload("res://scripts/world/village_prefab.gd")
const VillagePlacer = preload("res://scripts/world/village_placer.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")
const ZombieScene = preload("res://scenes/entities/zombie.tscn")
const VillagerScene = preload("res://scenes/entities/villager.tscn")
const CowScene = preload("res://scenes/entities/cow.tscn")
const SheepScene = preload("res://scenes/entities/sheep.tscn")
const PigScene = preload("res://scenes/entities/pig.tscn")
const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const MAX_SLIMES := 4              # 白天上限 (slime)
const MAX_ZOMBIES := 5             # 夜间上限 (zombie)
const MAX_ANIMALS := 6             # 动物上限 (牛+羊+猪 总和)
const SPAWN_INTERVAL := 6.0
const ANIMAL_SPAWN_INTERVAL := 12.0  # 动物刷新更慢
const SPAWN_RANGE_MIN := 12  # tiles
const SPAWN_RANGE_MAX := 22

const TILE_SIZE := 16

const MINIMAP_VIEW_TILES_X := 18  # 玩家屏幕能看到的横向 tile (略大于实际视野)
const MINIMAP_VIEW_TILES_Y := 14  # 纵向
const MINIMAP_MARK_INTERVAL := 0.1  # 每 0.1s 标记一次玩家周围 (减少开销)

@export var world_seed: int = 0   # 0 表示 _ready 内随机化

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var wall_layer: TileMapLayer = $WallLayer  # 背景墙 (在 TerrainLayer 之后, 渲染在前景方块后面)
@onready var entities_root: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var world_lighting: Node = $WorldLighting
@onready var darkness_layer: Sprite2D = $DarknessLayer  # 平滑光照 (Sprite2D + bilinear), 不是 TileMapLayer

var spawn_point: Vector2i
var chunk_manager: ChunkManager
var minimap_data: Node
var weather: Node
var rain_layer: CanvasLayer
var fireflies: Node2D
var shooting_star: Node2D
var falling_leaves: Node2D
var village_villager_spawns: Array = []
var _slime_spawn_timer: float = 3.0  # 启动后 3s 开始刷
var _animal_spawn_timer: float = 5.0  # 启动后 5s 开始刷动物
var _last_player_chunk_x: int = 0
var _minimap_mark_timer: float = 0.0


func _ready() -> void:
	var ts := TileSetBuilder.build()
	terrain_layer.tile_set = ts
	wall_layer.tile_set = ts  # 跟前景共享同一个 TileSet (墙 tile 也在里面注册过了)
	terrain_layer.add_to_group("terrain_layer")
	$EffectsRoot.add_to_group("effects_root")
	if world_seed == 0:
		world_seed = randi()
	chunk_manager = ChunkManagerClass.new()
	chunk_manager.name = "ChunkManager"
	add_child(chunk_manager)
	chunk_manager.setup(world_seed)
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	minimap_data = MinimapDataClass.new()
	minimap_data.name = "MinimapData"
	add_child(minimap_data)
	# 天气 + 雨视觉
	# 注意顺序: rain_layer 先 add_child + 信号先 connect, 再 add_child(weather)
	# 不然 weather._ready 触发 weather_changed 时 rain_layer 还没接信号, 初始状态丢失
	rain_layer = RainLayerClass.new()
	rain_layer.name = "RainLayer"
	add_child(rain_layer)
	weather = WeatherClass.new()
	weather.name = "Weather"
	weather.weather_changed.connect(_on_weather_changed)
	weather.lightning_flash.connect(_on_lightning_flash)
	add_child(weather)
	# 夜晚气氛: 萤火虫 / 流星 / 树下飘叶子
	fireflies = FirefliesClass.new()
	fireflies.name = "Fireflies"
	add_child(fireflies)
	shooting_star = ShootingStarClass.new()
	shooting_star.name = "ShootingStar"
	add_child(shooting_star)
	falling_leaves = FallingLeavesClass.new()
	falling_leaves.name = "FallingLeaves"
	add_child(falling_leaves)
	# 初始加载中心 ±VIEW_RADIUS
	chunk_manager.ensure_loaded(0)
	# 找出生点 (chunk 0 内)
	spawn_point = _find_spawn_in_loaded()
	# 村庄 + 村民已停用 (用户要求): 不再调用 _place_village() / _spawn_villagers()
	# 函数保留供未来重启用; 也避免破坏 SaveManager / dialogue 等引用
	SkyLightGrid.recompute_from([])
	_spawn_player()


func _place_village() -> void:
	var prefab = VillagePrefab.load_default()
	if prefab.is_empty():
		return
	village_villager_spawns = VillagePlacer.place(
		chunk_manager, terrain_layer, prefab, spawn_point
	)
	_spawn_villagers()


func _spawn_villagers() -> void:
	for tile_pos in village_villager_spawns:
		var v = VillagerScene.instantiate()
		v.global_position = Vector2(
			tile_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
			tile_pos.y * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(v)


func _process(delta: float) -> void:
	_slime_spawn_timer -= delta
	if _slime_spawn_timer <= 0.0:
		_slime_spawn_timer = SPAWN_INTERVAL
		# 夜间刷僵尸, 白天刷史莱姆
		if TimeOfDay.is_night():
			_try_spawn_zombie()
		else:
			_try_spawn_slime()
	# 动物只在白天刷新, 独立于怪物 timer
	_animal_spawn_timer -= delta
	if _animal_spawn_timer <= 0.0:
		_animal_spawn_timer = ANIMAL_SPAWN_INTERVAL
		if not TimeOfDay.is_night():
			_try_spawn_animal()
	# 玩家视野内 tile 标记为 minimap 可见
	_minimap_mark_timer -= delta
	if _minimap_mark_timer <= 0.0:
		_minimap_mark_timer = MINIMAP_MARK_INTERVAL
		_mark_explored_around_player()


func _mark_explored_around_player() -> void:
	var player := get_player()
	if player == null or minimap_data == null:
		return
	var ptx: int = int(floor(player.global_position.x / TILE_SIZE))
	var pty: int = int(floor(player.global_position.y / TILE_SIZE))
	var hx: int = MINIMAP_VIEW_TILES_X / 2
	var hy: int = MINIMAP_VIEW_TILES_Y / 2
	minimap_data.mark_rect(chunk_manager, ptx - hx, pty - hy, ptx + hx, pty + hy)


func _physics_process(_delta: float) -> void:
	_check_chunk_load()


func _on_weather_changed(state: String) -> void:
	if rain_layer != null:
		rain_layer.set_enabled(state == "rainy")


func _on_lightning_flash() -> void:
	if rain_layer != null:
		rain_layer.flash_lightning()
	# 雷声 (远距离低频 rumble) — 借用 SfxBank thunder, 没有的话就 skip
	if SfxBank != null and SfxBank.has_method("play"):
		SfxBank.play("thunder", 0.10)


func _check_chunk_load() -> void:
	var player := get_player()
	if player == null:
		return
	var pcx: int = Chunk.chunk_x_of(int(floor(player.global_position.x / TILE_SIZE)))
	if pcx != _last_player_chunk_x:
		_last_player_chunk_x = pcx
		chunk_manager.ensure_loaded(pcx)
		chunk_manager.unload_far_from(pcx, ChunkConstants.VIEW_RADIUS + 1)


func _on_chunk_loaded(c: Chunk) -> void:
	# 把 chunk 数据写到 TileMapLayer (前景方块 + 背景墙)
	var chunk_start: int = c.chunk_x * ChunkConstants.CHUNK_WIDTH
	for lx in c.tiles.size():
		var world_x: int = chunk_start + lx
		var col: Array = c.tiles[lx]
		var wall_col: Array = c.walls[lx]
		for y in col.size():
			var tid: int = col[y]
			if tid != Tiles.AIR:
				terrain_layer.set_cell(Vector2i(world_x, y), tid, Vector2i.ZERO)
			var wid: int = wall_col[y]
			if wid != Tiles.AIR:
				wall_layer.set_cell(Vector2i(world_x, y), wid, Vector2i.ZERO)
		SkyLightGrid.invalidate_column(world_x)
	# 火把光源: 扫描 chunk 内所有 TORCH tile, 在 TorchLights 下重建光
	world_lighting.on_chunk_loaded(c.chunk_x, ChunkConstants.CHUNK_WIDTH, c.tiles)
	# 黑暗层: chunk 加载时全列预算光值
	darkness_layer.recompute_chunk(c.chunk_x, ChunkConstants.CHUNK_WIDTH, ChunkConstants.WORLD_HEIGHT)


func _on_chunk_unloaded(cx: int) -> void:
	var chunk_start: int = cx * ChunkConstants.CHUNK_WIDTH
	var chunk_start_px: float = chunk_start * TILE_SIZE
	var chunk_end_px: float = chunk_start_px + ChunkConstants.CHUNK_WIDTH * TILE_SIZE
	# 清 TileMapLayer 这一柱 (前景 + 背景墙)
	for lx in ChunkConstants.CHUNK_WIDTH:
		var world_x: int = chunk_start + lx
		for y in ChunkConstants.WORLD_HEIGHT:
			terrain_layer.set_cell(Vector2i(world_x, y), -1)
			wall_layer.set_cell(Vector2i(world_x, y), -1)
		SkyLightGrid.invalidate_column(world_x)
	# 清该 chunk 像素范围内所有"短命"实体: 怪物 (slime/zombie) + 动物 (cow/sheep/pig) + 掉落物
	# 注意: villager 用专门 group, 由村庄系统管, 这里不清
	for group in ["slimes", "zombies", "animals", "item_drops"]:
		for ent in get_tree().get_nodes_in_group(group):
			if ent.global_position.x >= chunk_start_px and ent.global_position.x < chunk_end_px:
				ent.queue_free()
	# 清该 chunk 范围内所有火把光
	world_lighting.on_chunk_unloaded(cx, ChunkConstants.CHUNK_WIDTH)
	# 清该 chunk 范围内黑暗瓦片
	darkness_layer.clear_chunk(cx, ChunkConstants.CHUNK_WIDTH, ChunkConstants.WORLD_HEIGHT)


# 在 chunk 0 内找 GRASS 上方 3 格空气列, fallback 到 (0, 100)
func _find_spawn_in_loaded() -> Vector2i:
	var ch: Chunk = chunk_manager.get_chunk(0)
	if ch == null:
		return Vector2i(0, 100)
	for lx in ch.tiles.size():
		var col: Array = ch.tiles[lx]
		for y in range(3, col.size() - 1):
			if col[y] != Tiles.GRASS:
				continue
			if col[y - 1] != Tiles.AIR \
					or col[y - 2] != Tiles.AIR \
					or col[y - 3] != Tiles.AIR:
				continue
			# world_x = chunk_x*64 + lx = 0 + lx = lx
			return Vector2i(lx, y - 1)
	return Vector2i(0, 100)


func _try_spawn_slime() -> void:
	var slimes := get_tree().get_nodes_in_group("slimes")
	if slimes.size() >= MAX_SLIMES:
		return
	_spawn_surface_creature(SlimeScene)


func _try_spawn_zombie() -> void:
	# 夜间僵尸刷新. 上限独立于白天 slime.
	var zombies := get_tree().get_nodes_in_group("zombies")
	if zombies.size() >= MAX_ZOMBIES:
		return
	_spawn_surface_creature(ZombieScene)


func _try_spawn_animal() -> void:
	# 牛/羊/猪 共享上限. 随机挑一种刷.
	var animals := get_tree().get_nodes_in_group("animals")
	if animals.size() >= MAX_ANIMALS:
		return
	var r: float = randf()
	var scene: PackedScene
	if r < 0.33:
		scene = CowScene
	elif r < 0.66:
		scene = SheepScene
	else:
		scene = PigScene
	_spawn_surface_creature(scene)


# 在玩家附近地表随机刷一个 creature (slime/zombie 共用站位逻辑)
func _spawn_surface_creature(scene: PackedScene) -> void:
	var player := get_player()
	if player == null:
		return
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	for _i in 10:
		var sign_x: int = 1 if randf() < 0.5 else -1
		var dx: int = sign_x * randi_range(SPAWN_RANGE_MIN, SPAWN_RANGE_MAX)
		var cand_x: int = px + dx
		var surf_y: int = -1
		for y in ChunkConstants.WORLD_HEIGHT:
			if chunk_manager.get_tile(cand_x, y) != Tiles.AIR:
				surf_y = y
				break
		if surf_y <= 0:
			continue
		if chunk_manager.get_tile(cand_x, surf_y - 1) != Tiles.AIR:
			continue
		if chunk_manager.get_tile(cand_x, surf_y) == Tiles.BEDROCK:
			continue
		var creature := scene.instantiate()
		creature.global_position = Vector2(
			cand_x * TILE_SIZE + TILE_SIZE / 2.0,
			(surf_y - 1) * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(creature)
		return


func _spawn_player() -> void:
	var player := PlayerScene.instantiate()
	player.position = _spawn_world_pos()
	entities_root.add_child(player)
	camera.reparent(player)
	camera.position = Vector2.ZERO
	# 把 player 引用给气氛效果, 让它们知道在哪里生成
	if fireflies != null:
		fireflies.bind_player(player)
	if shooting_star != null:
		shooting_star.bind_player(player)
	if falling_leaves != null:
		falling_leaves.bind_player(player)


func _spawn_world_pos() -> Vector2:
	return Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE + TILE_SIZE
	)


func respawn_player() -> void:
	var player := get_player()
	if player == null:
		return
	# 把背包所有物品掉在死亡处
	var death_pos: Vector2 = player.global_position
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node != null and inv_node.inventory != null:
		var inv = inv_node.inventory
		for i in inv.slots.size():
			var s = inv.slots[i]
			if s == null:
				continue
			_spawn_death_drop(s.item_id, s.count, death_pos)
			inv.slots[i] = null
		if inv_node.has_signal("inventory_changed"):
			inv_node.inventory_changed.emit()
	# 清掉地图上所有 slime (防止复活时聚一堆)
	for s in get_tree().get_nodes_in_group("slimes"):
		s.queue_free()
	# 重置 spawn timer, 给玩家几秒缓冲再开始刷新
	_slime_spawn_timer = 5.0
	# 传送回出生点 + 满血
	player.global_position = _spawn_world_pos()
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_method("revive_full"):
		hp.revive_full()
	var hg: Node = player.get_node_or_null("PlayerHunger")
	if hg != null and hg.has_method("refill_full"):
		hg.refill_full()


func _spawn_death_drop(item_id: String, count: int, pos: Vector2) -> void:
	# 大量物品按 stack 分批掉, 每个堆叠一个 drop
	while count > 0:
		var n: int = min(count, ItemDB.max_stack(item_id))
		var drop = ItemDropScene.instantiate()
		drop.item_id = item_id
		drop.count = n
		drop.global_position = pos + Vector2(randf_range(-12.0, 12.0), -6.0)
		entities_root.add_child(drop)
		count -= n


func get_player() -> CharacterBody2D:
	for child in entities_root.get_children():
		if child is CharacterBody2D:
			return child
	return null


func get_crack_overlay() -> Node:
	return $CrackOverlay


func _set_tile(x: int, y: int, tile_id: int) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	var old_tid: int = chunk_manager.get_tile(x, y)
	chunk_manager.set_tile(x, y, tile_id)
	# 同步 TileMapLayer (chunk_manager 数据已写, 但视觉需另外刷)
	if tile_id == Tiles.AIR:
		terrain_layer.set_cell(Vector2i(x, y), -1)
	else:
		terrain_layer.set_cell(Vector2i(x, y), tile_id, Vector2i.ZERO)
	SkyLightGrid.invalidate_column(x)
	# 火把光源生命周期: 先 remove 旧, 再 place 新
	world_lighting.on_tile_removed(x, y, old_tid)
	world_lighting.on_tile_placed(x, y, tile_id)
	# 黑暗层: tile 改了 → 局部重算光值 (±8 涵盖火把半径 6)
	darkness_layer.recompute_around(x, y, 8)
