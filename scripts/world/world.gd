# 世界根：通过 ChunkManager 流式加载 64-宽列, 每次启动随机种子。
# 维护 TileMapLayer 视觉 (chunk_loaded/unloaded 信号驱动)。
extends Node2D

const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")
const WaterSimClass = preload("res://scripts/world/water_sim.gd")
const MinimapDataClass = preload("res://scripts/world/minimap_data.gd")
const WeatherClass = preload("res://scripts/world/weather.gd")
# RainLayer 已删 (用户要求, commit 后此行可全删)
# 萤火虫/流星/飘叶 fx 已删 (用户要求, perf)
const CursorManagerClass = preload("res://scripts/world/cursor_manager.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const VillagePrefab = preload("res://scripts/world/village_prefab.gd")
const VillagePlacer = preload("res://scripts/world/village_placer.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")
const ZombieScene = preload("res://scenes/entities/zombie.tscn")
const SpiderScene = preload("res://scenes/entities/spider.tscn")
const DemonEyeScene = preload("res://scenes/entities/demon_eye.tscn")
const MimicScene = preload("res://scenes/entities/mimic.tscn")
const SkeletonScene = preload("res://scenes/entities/skeleton.tscn")
const ImpScene = preload("res://scenes/entities/imp.tscn")
const HellWaspScene = preload("res://scenes/entities/hell_wasp.tscn")
const MummyScene = preload("res://scenes/entities/mummy.tscn")
const VillagerScene = preload("res://scenes/entities/villager.tscn")
const CowScene = preload("res://scenes/entities/cow.tscn")
const SheepScene = preload("res://scenes/entities/sheep.tscn")
const PigScene = preload("res://scenes/entities/pig.tscn")
const PenguinScene = preload("res://scenes/entities/penguin.tscn")
# const JaguarScene = preload("res://scenes/entities/jaguar.tscn")  # 删除 (用户要求)
const FrogScene = preload("res://scenes/entities/frog.tscn")
const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const RemotePlayerScene = preload("res://scenes/entities/remote_player.tscn")

const MAX_SLIMES := 4              # 白天上限 (slime)
# 夜间怪 (zombie + spider 共享) 上限按难度: 简单 8 / 普通 15 / 困难 25
const NIGHT_CAP_BY_DIFFICULTY := [8, 15, 25]
const MAX_ANIMALS := 3             # 动物上限 (牛+羊+猪+企鹅+豹+青蛙 总和)
const SPAWN_INTERVAL := 6.0
const ANIMAL_SPAWN_INTERVAL := 12.0  # 动物刷新更慢
const SPAWN_RANGE_MIN := 12  # tiles
const SPAWN_RANGE_MAX := 22

const TILE_SIZE := 12

const MINIMAP_VIEW_TILES_X := 18  # 玩家屏幕能看到的横向 tile (略大于实际视野)
const MINIMAP_VIEW_TILES_Y := 14  # 纵向
const MINIMAP_MARK_INTERVAL := 0.25  # 每 0.25s 标记一次玩家周围. 玩家 0.25s 走 ~1 tile,
                                     # minimap 也跟得上, 但循环 18x14 tile 的成本省 60%

@export var world_seed: int = 0   # 0 表示 _ready 内随机化
@export var defer_init: bool = false   # true 时 _ready 跳过自动初始化, 由外部调 run_init_step

const STEP_LABELS := [
	"正在构建方块...",
	"正在生成地形...",
	"正在召唤天气...",
	"正在召唤玩家...",
]

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var wall_layer: TileMapLayer = $WallLayer  # 背景墙 (在 TerrainLayer 之后, 渲染在前景方块后面)
@onready var entities_root: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D
@onready var world_lighting: Node = $WorldLighting
@onready var darkness_layer: Sprite2D = $DarknessLayer  # 平滑光照 (Sprite2D + bilinear), 不是 TileMapLayer

var spawn_point: Vector2i
var chunk_manager: ChunkManager
var water_sim: Node
var minimap_data: Node
var _remote_player: Node = null   # 联机时另一个玩家的 sprite (Phase C)
var _mp_time_sync_timer: float = 0.0   # host 广播时间+天气计时 (Phase F)
const _MP_TIME_SYNC_INTERVAL := 5.0
var _mp_entity_sync_timer: float = 0.0  # host 广播实体位置计时 (Phase E)
const _MP_ENTITY_SYNC_INTERVAL := 0.2
var weather: Node
# var rain_layer: CanvasLayer  # 已删
# fireflies/shooting_star/falling_leaves vars 已删
var village_villager_spawns: Array = []
var _slime_spawn_timer: float = 3.0  # 启动后 3s 开始刷
var _animal_spawn_timer: float = 5.0  # 启动后 5s 开始刷动物
var _last_player_chunk_x: int = 0
var _minimap_mark_timer: float = 0.0


func _ready() -> void:
	# 这些 group 注册 + EffectsRoot 早期就要好 (被其他系统在 _ready 阶段 find).
	add_to_group("world")
	terrain_layer.add_to_group("terrain_layer")
	$EffectsRoot.add_to_group("effects_root")
	# 火花对象池: 预分配 80 个 spark, 复用减 alloc
	var SparkPoolClass = preload("res://scripts/fx/spark_pool.gd")
	var sp = SparkPoolClass.new()
	sp.name = "SparkPool"
	$EffectsRoot.add_child(sp)
	if world_seed == 0:
		world_seed = randi()
	if defer_init:
		return
	# 默认: 顺序跑所有 step (兼容 boot_to_game / 直接 add_child World)
	for i in STEP_LABELS.size():
		run_init_step(i)


func get_init_step_count() -> int:
	return STEP_LABELS.size()


func get_init_step_label(idx: int) -> String:
	return STEP_LABELS[idx]


func run_init_step(idx: int) -> void:
	match idx:
		0: _step_build_tileset()
		1: _step_chunks()
		2: _step_fx_layers()
		3: _step_spawn_player()


func _step_build_tileset() -> void:
	var ts := TileSetBuilder.build()
	terrain_layer.tile_set = ts
	wall_layer.tile_set = ts  # 跟前景共享同一个 TileSet


func _step_chunks() -> void:
	chunk_manager = ChunkManagerClass.new()
	chunk_manager.name = "ChunkManager"
	add_child(chunk_manager)
	chunk_manager.setup(world_seed)
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	# 初始加载中心 ±VIEW_RADIUS
	chunk_manager.ensure_loaded(0)


func _step_fx_layers() -> void:
	# 流水模拟: dirty 列表驱动, 接 chunk_manager + _set_tile
	water_sim = WaterSimClass.new()
	water_sim.name = "WaterSim"
	water_sim.world = self
	add_child(water_sim)
	minimap_data = MinimapDataClass.new()
	minimap_data.name = "MinimapData"
	add_child(minimap_data)
	# 雨/天气已删 (用户要求). rain_layer 不再实例化, weather 仅作"晴天" stub
	# 保留 weather 节点 (其他系统通过它查 is_raining() 之类)
	weather = WeatherClass.new()
	weather.name = "Weather"
	add_child(weather)
	# 夜晚气氛 (萤火虫 / 流星 / 飘叶) 已删 (用户要求, perf)
	# 图形开关: 把 GameSettings 应用到所有装饰节点
	_apply_graphics_settings.call_deferred()  # 让所有 child 先 _ready
	if not GameSettings.settings_changed.is_connected(_apply_graphics_settings):
		GameSettings.settings_changed.connect(_apply_graphics_settings)


func _step_spawn_player() -> void:
	# 找出生点 (chunk 0 内)
	spawn_point = _find_spawn_in_loaded()
	SkyLightGrid.recompute_from([])
	_spawn_player()
	# 鼠标光标管理: 默认箭头, 鼠标在敌人/方块上切换样式
	var cursor_mgr := CursorManagerClass.new()
	cursor_mgr.name = "CursorManager"
	add_child(cursor_mgr)
	# 联机: _ready 时已连上立刻接; 否则订阅 status_changed, 后续 host (游戏内) 也能触发
	if NetworkManager != null:
		if not NetworkManager.status_changed.is_connected(_on_mp_status_changed):
			NetworkManager.status_changed.connect(_on_mp_status_changed)
		if NetworkManager.connected():
			_setup_multiplayer_callbacks()


# 进 connected 状态时调: 注册 remote_* 信号 + spawn RemotePlayer + host 广播 initial_state.
# 幂等: is_connected 检查保证多次调不重复 connect.
func _setup_multiplayer_callbacks() -> void:
	if NetworkManager == null or not NetworkManager.connected():
		return
	if _remote_player == null:
		_spawn_remote_player()
	if not NetworkManager.remote_pos_received.is_connected(_on_remote_pos):
		NetworkManager.remote_pos_received.connect(_on_remote_pos)
	if not NetworkManager.remote_tile_received.is_connected(_on_remote_tile):
		NetworkManager.remote_tile_received.connect(_on_remote_tile)
	if not NetworkManager.remote_time_weather_received.is_connected(_on_remote_time_weather):
		NetworkManager.remote_time_weather_received.connect(_on_remote_time_weather)
	if not NetworkManager.initial_state_received.is_connected(_on_initial_state):
		NetworkManager.initial_state_received.connect(_on_initial_state)
	if not NetworkManager.remote_entity_pos_received.is_connected(_on_remote_entity_pos):
		NetworkManager.remote_entity_pos_received.connect(_on_remote_entity_pos)
	if not NetworkManager.remote_entity_die_received.is_connected(_on_remote_entity_die):
		NetworkManager.remote_entity_die_received.connect(_on_remote_entity_die)
	if not NetworkManager.remote_drop_pos_received.is_connected(_on_remote_drop_pos):
		NetworkManager.remote_drop_pos_received.connect(_on_remote_drop_pos)
	if not NetworkManager.remote_drop_pickup_received.is_connected(_on_remote_drop_pickup):
		NetworkManager.remote_drop_pickup_received.connect(_on_remote_drop_pickup)
	if not NetworkManager.remote_tile_batch_received.is_connected(_on_remote_tile_batch):
		NetworkManager.remote_tile_batch_received.connect(_on_remote_tile_batch)
	# host: 立刻广播 chunk_deltas (新 join 的 client 拿到这份现状)
	if NetworkManager.is_host:
		_mp_broadcast_initial_state.call_deferred()
	# client: hello/init_state 若在 _ready 前到, 应用 pending
	elif not NetworkManager.pending_initial_deltas.is_empty():
		_apply_initial_state(NetworkManager.pending_initial_deltas)
		NetworkManager.pending_initial_deltas = {}


func _on_mp_status_changed(s: String) -> void:
	if s == "connected":
		_setup_multiplayer_callbacks()


func _mp_broadcast_initial_state() -> void:
	# host 进 world 后调. 拿 chunk_manager._deltas 序列化广播
	if chunk_manager == null:
		return
	NetworkManager.send_initial_state(chunk_manager._deltas)


func _on_initial_state(deltas: Dictionary) -> void:
	_apply_initial_state(deltas)


func _apply_initial_state(deltas: Dictionary) -> void:
	# deltas 是 String key (cx) → Array<int> (lx,y,tid,...). 应用到当前 chunk_manager
	for cx_str in deltas.keys():
		var cx: int = int(cx_str)
		var arr: Array = deltas[cx_str]
		# 写 _deltas (chunk 未加载时也保留, 加载时会自动应用)
		if not chunk_manager._deltas.has(cx):
			chunk_manager._deltas[cx] = {}
		var inner: Dictionary = chunk_manager._deltas[cx]
		var i: int = 0
		while i + 2 < arr.size():
			var lx: int = int(arr[i])
			var y: int = int(arr[i + 1])
			var tid: int = int(arr[i + 2])
			inner[Vector2i(lx, y)] = tid
			i += 3
		# 如果 chunk 已加载, 立刻应用 + 刷新视觉
		var ch = chunk_manager.get_chunk(cx)
		if ch != null:
			ch.apply_delta(inner)
			_on_chunk_loaded(ch)


# Phase E: 远程实体 (host 广播, client 接收). 用 dict ent_id → Node
var _remote_entities: Dictionary = {}
var _picked_up_drop_ids: Dictionary = {}   # client 已捡 ent_id (防 host 0.2s 广播复活)
var _tile_batch: PackedInt32Array = PackedInt32Array()  # 批量广播 buf
var _tile_batching: bool = false


# 取字典里的 remote 实体, 自动清理 freed 引用 (queue_free 后 Node 引用不变 null,
# 直接访问会报 "instance was previously freed" — 必须用 is_instance_valid)
func _get_valid_remote(ent_id: int) -> Node:
	var ent = _remote_entities.get(ent_id)
	if ent == null:
		return null
	if not is_instance_valid(ent):
		_remote_entities.erase(ent_id)
		return null
	return ent


func _on_remote_entity_pos(ent_id: int, kind: String, x: float, y: float, _hp: int) -> void:
	var ent: Node = _get_valid_remote(ent_id)
	if ent == null:
		# 第一次见这个实体 (或旧的已被释放): 生成视觉版本
		ent = _spawn_remote_entity(kind)
		if ent != null:
			_remote_entities[ent_id] = ent
	if ent != null:
		ent.global_position = Vector2(x, y)


func _on_remote_entity_die(ent_id: int) -> void:
	var ent: Node = _get_valid_remote(ent_id)
	if ent != null:
		ent.queue_free()
	_remote_entities.erase(ent_id)


func _spawn_remote_entity(kind: String) -> Node:
	# 用现成的 scene, 加入 entities_root, 但禁用 AI (slime 等会检测 is_remote 跳过逻辑)
	var scene: PackedScene = null
	match kind:
		"slime": scene = SlimeScene
		"zombie": scene = ZombieScene
		"spider": scene = SpiderScene
		"demon_eye": scene = DemonEyeScene
		"skeleton": scene = SkeletonScene
		"imp": scene = ImpScene
		"hell_wasp": scene = HellWaspScene
		"mummy": scene = MummyScene
		"cow": scene = CowScene
		"sheep": scene = SheepScene
		"pig": scene = PigScene
		"penguin": scene = PenguinScene
		# "jaguar": scene = JaguarScene  # 删除
		"frog": scene = FrogScene
		"villager": scene = VillagerScene
		_: return null
	if scene == null:
		return null
	var ent = scene.instantiate()
	# 标记为远程, 实体 AI 应跳过
	ent.set_meta("is_remote", true)
	entities_root.add_child(ent)
	return ent


# 掉落物同步: client 收到 drop_pos → 拿 id 找/建一个 ItemDrop
func _on_remote_drop_pos(ent_id: int, item_id: String, count: int, x: float, y: float) -> void:
	if _picked_up_drop_ids.has(ent_id):
		return   # 已捡过, 别复活
	var ent: Node = _get_valid_remote(ent_id)
	if ent == null:
		# 第一次 (或旧引用已失效): 生成 ItemDropScene + 设 item_id/count
		ent = ItemDropScene.instantiate()
		if "item_id" in ent:
			ent.item_id = item_id
		if "count" in ent:
			ent.count = count
		if "ent_id" in ent:
			ent.ent_id = ent_id   # client 端记 host 的 id, 捡时报回去
		ent.set_meta("is_remote", true)
		entities_root.add_child(ent)
		_remote_entities[ent_id] = ent
	if ent is Node2D:
		(ent as Node2D).global_position = Vector2(x, y)


# 对端 (client) 捡了一个 drop → 在本端找同 id 的 drop, queue_free
func _on_remote_drop_pickup(ent_id: int) -> void:
	_picked_up_drop_ids[ent_id] = true
	for d in get_tree().get_nodes_in_group("item_drops"):
		if d.has_meta("is_remote"):
			continue
		if NetworkManager.entity_id_for(d) == ent_id:
			d.queue_free()
			return


# client 自己捡了 is_remote drop, 也标记防 host 广播复活
func mark_drop_picked_up(ent_id: int) -> void:
	_picked_up_drop_ids[ent_id] = true


# 批量广播: host 水流/级联砍树时开 batching, 期间 _set_tile / _set_water_tile_fast
# 把变化记到 _tile_batch, end_tile_batch 一条消息发完 (防 PeerJS 一帧几百小消息丢)
func begin_tile_batch() -> void:
	_tile_batching = true
	_tile_batch.clear()


func end_tile_batch() -> void:
	if _tile_batching and not _tile_batch.is_empty() \
			and NetworkManager != null and NetworkManager.connected():
		NetworkManager.send_tile_batch(_tile_batch)
	_tile_batching = false
	_tile_batch.clear()


func _on_remote_tile_batch(changes: PackedInt32Array) -> void:
	var i: int = 0
	while i + 2 < changes.size():
		var x: int = changes[i]
		var y: int = changes[i + 1]
		var tid: int = changes[i + 2]
		if tid == Tiles.WATER or tid == Tiles.WATER_L1 \
				or tid == Tiles.WATER_L2 or tid == Tiles.WATER_L3:
			_set_water_tile_fast(x, y, tid, true)
		else:
			_set_tile(x, y, tid, true)
		i += 3


func _on_remote_tile(x: int, y: int, tile_id: int) -> void:
	# 对方挖/放方块 → 本地应用, 不再广播 (from_remote=true)
	# 水类 tile 走 fast path (跳过 darkness/lighting 防卡帧)
	if tile_id == Tiles.WATER or tile_id == Tiles.WATER_L1 \
			or tile_id == Tiles.WATER_L2 or tile_id == Tiles.WATER_L3:
		_set_water_tile_fast(x, y, tile_id, true)
		return
	_set_tile(x, y, tile_id, true)


func _on_remote_time_weather(time_val: float, weather_state: String) -> void:
	# client 收到 host 广播: 同步时间 + 天气
	TimeOfDay.time = time_val
	if weather != null and weather.state != weather_state:
		weather.force_state(weather_state)


func _spawn_remote_player() -> void:
	if _remote_player != null:
		return
	_remote_player = RemotePlayerScene.instantiate()
	_remote_player.name = "RemotePlayer"
	entities_root.add_child(_remote_player)
	# 初始放在 spawn 点附近 (收到第一条 pos 后 snap 到真实位置)
	_remote_player.global_position = Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE + TILE_SIZE
	)


func _on_remote_pos(x: float, y: float, facing: int, anim: String) -> void:
	if _remote_player == null:
		_spawn_remote_player()
	if _remote_player != null and _remote_player.has_method("apply_pos"):
		_remote_player.apply_pos(x, y, facing, anim)


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
	# 联机 client (不是 host) 跳过怪物/动物刷新 (host 权威, client 只接受 ent_pos 同步)
	var is_mp_client: bool = NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host
	if not is_mp_client:
		_slime_spawn_timer -= delta
		if _slime_spawn_timer <= 0.0:
			_slime_spawn_timer = SPAWN_INTERVAL
			if TimeOfDay.is_night():
				_try_spawn_zombie()
			else:
				_try_spawn_slime()
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
	# 联机 host: 每 5s 广播时间+天气 (Phase F) + 每 0.2s 广播实体位置 (Phase E)
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		_mp_time_sync_timer -= delta
		if _mp_time_sync_timer <= 0.0:
			_mp_time_sync_timer = _MP_TIME_SYNC_INTERVAL
			var ws: String = weather.state if weather != null else "clear"
			NetworkManager.send_time_weather(TimeOfDay.time, ws)
		_mp_entity_sync_timer -= delta
		if _mp_entity_sync_timer <= 0.0:
			_mp_entity_sync_timer = _MP_ENTITY_SYNC_INTERVAL
			_mp_broadcast_entities()


func _mp_broadcast_entities() -> void:
	# 怪物 / 动物 / 村民
	for grp in ["slimes", "zombies", "animals", "villagers"]:
		for ent in get_tree().get_nodes_in_group(grp):
			if not (ent is Node2D):
				continue
			var n2d: Node2D = ent
			var kind: String = "slime"
			match grp:
				"slimes":
					# spider / demon_eye 也在 slimes 组 (共享剑挥). 用 scene_path 区分.
					var scene_path_s: String = n2d.scene_file_path if n2d.scene_file_path != null else ""
					if "spider" in scene_path_s:
						kind = "spider"
					elif "demon_eye" in scene_path_s:
						kind = "demon_eye"
					elif "zombie" in scene_path_s:
						kind = "zombie"
					else:
						kind = "slime"
				"zombies": kind = "zombie"
				"villagers": kind = "villager"
				"animals":
					var scene_path: String = n2d.scene_file_path if n2d.scene_file_path != null else ""
					if "cow" in scene_path:
						kind = "cow"
					elif "sheep" in scene_path:
						kind = "sheep"
					elif "pig" in scene_path:
						kind = "pig"
					elif "penguin" in scene_path:
						kind = "penguin"
					elif "frog" in scene_path:
						kind = "frog"
			NetworkManager.send_entity_pos(
				NetworkManager.entity_id_for(n2d),
				kind,
				n2d.global_position.x, n2d.global_position.y, 0
			)
	# 掉落物: 走单独 drop_pos (带 item_id + count)
	for drop in get_tree().get_nodes_in_group("item_drops"):
		if not (drop is Node2D):
			continue
		var d: Node2D = drop
		var did: int = NetworkManager.entity_id_for(d)
		var item_id: String = String(d.get("item_id")) if "item_id" in d else ""
		var count: int = int(d.get("count")) if "count" in d else 1
		NetworkManager.send_drop_pos(did, item_id, count, d.global_position.x, d.global_position.y)


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


# 把当前 GameSettings 应用到所有视觉节点. _ready 末尾 + settings_changed 信号都会调.
func _apply_graphics_settings() -> void:
	# 雨已删 (用户要求), 这里跳过
	# 视差远景: ParallaxBackground + ScenicDirector 一起切
	for child in get_children():
		if child is ParallaxBackground:
			child.visible = GameSettings.show_parallax
	var scenic := get_node_or_null("ScenicDirector")
	if scenic != null:
		scenic.set_layers_visible(GameSettings.show_parallax)
	# 鸟/蝠群
	var bird := get_node_or_null("BirdLayer")
	if bird != null:
		bird.visible = GameSettings.show_flocks
		bird.set_process(GameSettings.show_flocks)
	var bat := get_node_or_null("BatLayer")
	if bat != null:
		bat.visible = GameSettings.show_flocks
		bat.set_process(GameSettings.show_flocks)
	# 流水模拟: 关掉 _process 就够了 (水方块还在, 但不流)
	if water_sim != null:
		water_sim.set_process(GameSettings.water_sim_enabled)
	# 摄像机大小: GameSettings.camera_zoom 直接同步到 Camera2D.zoom
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.zoom = Vector2(GameSettings.camera_zoom, GameSettings.camera_zoom)


# _on_lightning_flash 已删 (跟雨一起)


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
	const Autotile = preload("res://scripts/world/autotile.gd")
	const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	# 把 chunk 数据写到 TileMapLayer (前景方块 + 背景墙)
	# (撤回拆帧 — async _on_chunk_loaded 跟 worldgen 流程冲突 卡住)
	var chunk_start: int = c.chunk_x * ChunkConstants.CHUNK_WIDTH
	for lx in c.tiles.size():
		var world_x: int = chunk_start + lx
		var col: Array = c.tiles[lx]
		var wall_col: Array = c.walls[lx]
		for y in col.size():
			var tid: int = col[y]
			var pos := Vector2i(world_x, y)
			if tid == Tiles.AIR:
				# 修存档 bug: 挖空 tile 必须 erase_cell, 不能 skip — 不然 reload 时
				# terrain_layer 还留着老地形, 玩家卡块.
				terrain_layer.erase_cell(pos)
			elif (tid == Tiles.LIFE_CRYSTAL or tid == Tiles.MANA_CRYSTAL) and not chunk_manager.is_my_crystal(pos):
				# 联机: 别人家的水晶, 本地渲染成 AIR (看不到 + 走得过 + 挖不动).
				# chunk.tiles[] 仍然是 LIFE_CRYSTAL — owner 那边能挖能吃.
				terrain_layer.erase_cell(pos)
			elif EdgeTemplates.FAMILY_OF.has(tid):
				var q := Autotile.make_terrain_query(tid, chunk_manager)
				Autotile.refresh_tile(terrain_layer, pos, tid, q)
			else:
				terrain_layer.set_cell(pos, tid, Vector2i.ZERO)
			var wid: int = wall_col[y]
			var wpos := Vector2i(world_x, y)
			if wid == Tiles.AIR:
				wall_layer.erase_cell(wpos)
			elif EdgeTemplates.FAMILY_OF.has(wid):
				var wq := Autotile.make_wall_query(wid, chunk_manager)
				Autotile.refresh_tile(wall_layer, wpos, wid, wq)
			else:
				wall_layer.set_cell(wpos, wid, Vector2i.ZERO)
		SkyLightGrid.invalidate_column(world_x)
	# 流水: 只标"边界水" dirty (相邻有 AIR 或低水位才可能流) — 避免 worldgen
	# 大海/大水池整片几千格全 dirty 卡帧.
	if water_sim != null:
		var w: int = c.tiles.size()
		var h: int = c.tiles[0].size() if w > 0 else 0
		for lx in w:
			var col: Array = c.tiles[lx]
			for y in col.size():
				var t: int = col[y]
				if t != Tiles.WATER and t != Tiles.WATER_L1 \
						and t != Tiles.WATER_L2 and t != Tiles.WATER_L3:
					continue
				# 检 4 个邻居, 全是水(同 level)/实心 -> 内部水, 跳过
				var has_flow: bool = false
				for nb in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx_local: int = lx + nb.x
					var ny: int = y + nb.y
					if nx_local < 0 or nx_local >= w or ny < 0 or ny >= h:
						has_flow = true
						break
					var nt: int = col[ny] if nb.x == 0 else c.tiles[nx_local][ny]
					if nt == Tiles.AIR:
						has_flow = true
						break
					# 邻居是更低水位 -> 可流
					if nt == Tiles.WATER_L1 or nt == Tiles.WATER_L2 or nt == Tiles.WATER_L3:
						if t == Tiles.WATER:
							has_flow = true
							break
				if has_flow:
					water_sim.mark_dirty(chunk_start + lx, y)
	# 火把光源: 扫描 chunk 内所有 TORCH tile, 在 TorchLights 下重建光
	world_lighting.on_chunk_loaded(c.chunk_x, ChunkConstants.CHUNK_WIDTH, c.tiles)
	# 黑暗层: chunk 加载时全列预算光值
	darkness_layer.recompute_chunk(c.chunk_x, ChunkConstants.CHUNK_WIDTH, ChunkConstants.WORLD_HEIGHT)
	# 跨 chunk 边界修正: 刷邻接 chunk 朝向本 chunk 的 1 列 atlas_coord
	# (边界列之前按"无邻居"画, 现在本 chunk 加载后邻居关系改变, 需重算)
	for neighbor_cx in [c.chunk_x - 1, c.chunk_x + 1]:
		if not chunk_manager.is_chunk_loaded(neighbor_cx):
			continue
		var col_x: int
		if neighbor_cx < c.chunk_x:
			# 左邻接 chunk: 刷它的最右列
			col_x = c.chunk_x * ChunkConstants.CHUNK_WIDTH - 1
		else:
			# 右邻接 chunk: 刷它的最左列
			col_x = (c.chunk_x + 1) * ChunkConstants.CHUNK_WIDTH
		for y in ChunkConstants.WORLD_HEIGHT:
			var sid: int = terrain_layer.get_cell_source_id(Vector2i(col_x, y))
			if sid != -1 and EdgeTemplates.FAMILY_OF.has(sid):
				var q := Autotile.make_terrain_query(sid, chunk_manager)
				Autotile.refresh_tile(terrain_layer, Vector2i(col_x, y), sid, q)
			var wsid: int = wall_layer.get_cell_source_id(Vector2i(col_x, y))
			if wsid != -1 and EdgeTemplates.FAMILY_OF.has(wsid):
				var wq := Autotile.make_wall_query(wsid, chunk_manager)
				Autotile.refresh_tile(wall_layer, Vector2i(col_x, y), wsid, wq)


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
	# spawn 接受 GRASS 或 SAND 地表 (沙漠生态也能 spawn)
	for lx in ch.tiles.size():
		var col: Array = ch.tiles[lx]
		for y in range(3, col.size() - 1):
			if col[y] != Tiles.GRASS and col[y] != Tiles.SAND:
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
	# 夜间僵尸/蜘蛛/恶魔眼共享上限 (按难度: 简单 8 / 普通 15 / 困难 25).
	var diff: int = clampi(GameSettings.current_difficulty, 0, 2) if GameSettings != null else 1
	var cap: int = NIGHT_CAP_BY_DIFFICULTY[diff]
	var zombies := get_tree().get_nodes_in_group("zombies")
	var spiders := get_tree().get_nodes_in_group("spiders")
	var demon_eyes := get_tree().get_nodes_in_group("demon_eyes")
	if zombies.size() + spiders.size() + demon_eyes.size() >= cap:
		return
	# 概率分配: 玩家地表 (y<30): 40 zombie / 40 spider / 20 demon_eye
	# 中地下 (30-220): 20 zombie / 50 spider / 30 demon_eye
	# 地狱 (>=220): 40 skeleton / 35 imp / 25 hell_wasp
	# 注: 阈值 220 跟 world_generator HELL_DEPTH=220 对齐. 老阈值 110 不对, 让深矿洞也刷地狱怪 bug.
	var player := get_player()
	var py_tile: int = 0
	if player != null:
		py_tile = int(floor(player.global_position.y / TILE_SIZE))
	var r: float = randf()
	var scene: PackedScene
	if py_tile >= 220:
		# 地狱: 40 skeleton / 35 imp / 25 hell_wasp
		if r < 0.40:
			scene = SkeletonScene
		elif r < 0.75:
			scene = ImpScene
		else:
			scene = HellWaspScene
		_spawn_hell_creature(scene)
		return
	elif py_tile >= 30:
		if r < 0.2:
			scene = ZombieScene
		elif r < 0.7:
			scene = SpiderScene
		else:
			scene = DemonEyeScene
	else:
		if r < 0.4:
			scene = ZombieScene
		elif r < 0.8:
			scene = SpiderScene
		else:
			scene = DemonEyeScene
	_spawn_surface_creature(scene)


# 地狱怪 spawn: 在玩家附近 (12-40 tile X 范围, ±10 Y 范围) 找一个 AIR 上有 HELL_STONE/OBSIDIAN 底的位置.
func _spawn_hell_creature(scene: PackedScene) -> void:
	var player := get_player()
	if player == null:
		return
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	for _i in 12:
		var sign_x: int = 1 if randf() < 0.5 else -1
		var dx: int = sign_x * randi_range(SPAWN_RANGE_MIN, SPAWN_RANGE_MAX)
		var cand_x: int = px + dx
		var cand_y: int = py + randi_range(-6, 6)
		if cand_y < 220 or cand_y >= ChunkConstants.WORLD_HEIGHT - 2:
			continue
		if chunk_manager.get_tile(cand_x, cand_y) != Tiles.AIR:
			continue
		# 脚下必须实心 (地狱石/黑曜石/最底基岩)
		var below: int = chunk_manager.get_tile(cand_x, cand_y + 1)
		if below == Tiles.AIR or below == Tiles.LAVA:
			continue
		# 头顶不能挤
		if chunk_manager.get_tile(cand_x, cand_y - 1) != Tiles.AIR:
			continue
		var creature := scene.instantiate()
		creature.global_position = Vector2(
			cand_x * TILE_SIZE + TILE_SIZE / 2.0,
			(cand_y + 1) * TILE_SIZE
		)
		entities_root.add_child(creature)
		return


func _try_spawn_animal() -> void:
	# 按 spawn 列的 biome 选怪.
	# forest(GRASS): 牛/羊/猪
	# snow(SNOW): 企鹅 + 牛 (混)
	# jungle(JUNGLE_GRASS): 美洲豹 (敌对快) + 猪
	# swamp(SWAMP_GRASS): 青蛙 (跳)
	# desert(SAND): 不刷动物 (现在还没沙漠动物)
	var animals := get_tree().get_nodes_in_group("animals")
	if animals.size() >= MAX_ANIMALS:
		return
	# 探测玩家附近一列的 biome (按地表 tile 决定)
	var player := get_player()
	if player == null:
		return
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var sign_x: int = 1 if randf() < 0.5 else -1
	var dx: int = sign_x * randi_range(SPAWN_RANGE_MIN, SPAWN_RANGE_MAX)
	var cand_x: int = px + dx
	# 找该列地表 tile
	var surf_tile: int = Tiles.AIR
	for y in ChunkConstants.WORLD_HEIGHT:
		var t: int = chunk_manager.get_tile(cand_x, y)
		if t != Tiles.AIR:
			surf_tile = t
			break
	var scene: PackedScene
	var r: float = randf()
	match surf_tile:
		Tiles.SNOW:
			scene = PenguinScene if r < 0.7 else CowScene
		Tiles.JUNGLE_GRASS:
			# 丛林只刷猪 (豹子已删)
			scene = PigScene
		Tiles.SWAMP_GRASS, Tiles.MUD:
			scene = FrogScene
		Tiles.SAND:
			return  # 沙漠不刷
		_:  # GRASS or fallback
			if r < 0.33:
				scene = CowScene
			elif r < 0.66:
				scene = SheepScene
			else:
				scene = PigScene
	_spawn_at_column(scene, cand_x)


# spawn 在指定列地表上, 不再随机选 column
func _spawn_at_column(scene: PackedScene, cand_x: int) -> void:
	var surf_y: int = -1
	for y in ChunkConstants.WORLD_HEIGHT:
		if chunk_manager.get_tile(cand_x, y) != Tiles.AIR:
			surf_y = y
			break
	if surf_y <= 0:
		return
	if chunk_manager.get_tile(cand_x, surf_y - 1) != Tiles.AIR:
		return  # 头顶被堵 (树或方块)
	if chunk_manager.get_tile(cand_x, surf_y) == Tiles.BEDROCK:
		return
	var creature := scene.instantiate()
	creature.global_position = Vector2(
		cand_x * TILE_SIZE + TILE_SIZE / 2.0,
		(surf_y - 1) * TILE_SIZE + TILE_SIZE
	)
	entities_root.add_child(creature)


# 死人箱触发: 在指定 tile 坐标 spawn Mimic. 外部 (player_action) 调.
func spawn_mimic_at_tile(tile: Vector2i) -> void:
	var creature := MimicScene.instantiate()
	creature.global_position = Vector2(
		tile.x * TILE_SIZE + TILE_SIZE / 2.0,
		tile.y * TILE_SIZE + TILE_SIZE   # 脚踏 tile 底部
	)
	entities_root.add_child(creature)


# 金字塔守卫: 给一组 spawn 点 (世界坐标) 召 mummy. chunk_manager 在
# chunk 加载时调. 用 _pyramid_chunks_spawned 防同 chunk 重 spawn.
var _pyramid_chunks_spawned: Dictionary = {}   # chunk_x int → true
func spawn_mummies_for_chunk(chunk_x: int, spots: Array) -> void:
	if spots.is_empty():
		return
	if _pyramid_chunks_spawned.has(chunk_x):
		return   # 已 spawn 过, chunk 重载不再生 (杀完就清空)
	_pyramid_chunks_spawned[chunk_x] = true
	for spot in spots:
		var creature := MummyScene.instantiate()
		creature.global_position = Vector2(
			spot.x * TILE_SIZE + TILE_SIZE / 2.0,
			spot.y * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(creature)


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
	# 气氛效果 (萤火虫/流星/飘叶) 已删


func _spawn_world_pos() -> Vector2:
	# 玩家从地表上方 1 格出生 (而不是脚切线贴草顶), 防止物理引擎边缘情况
	# 下 is_on_floor() 不稳定. 落地只需 1 帧 (重力 900 → 0.5s 内稳).
	return Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE
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
		# 盔甲也跟着掉 (Terraria 风, 玩家死了脱光). 装备槽清空.
		if inv_node.has_method("get_armor") and inv_node.has_method("set_armor"):
			for slot_kind in ["helmet", "chest", "pants"]:
				var armor = inv_node.get_armor(slot_kind)
				if armor != null:
					_spawn_death_drop(armor.item_id, 1, death_pos)
					inv_node.set_armor(slot_kind, null)
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


func _set_tile(x: int, y: int, tile_id: int, from_remote: bool = false, skip_sand: bool = false) -> void:
	# skip_sand=true 防止沙子物理递归 (沙下落时不再触发它自己)
	# from_remote=true 时不再广播 (避免循环). 本地玩家挖/放 → 广播给联机对方
	if not from_remote and NetworkManager != null and NetworkManager.connected():
		if _tile_batching:
			_tile_batch.append(x); _tile_batch.append(y); _tile_batch.append(tile_id)
		else:
			NetworkManager.send_tile_change(x, y, tile_id)
	const Autotile = preload("res://scripts/world/autotile.gd")
	const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	var old_tid: int = chunk_manager.get_tile(x, y)
	chunk_manager.set_tile(x, y, tile_id)
	var pos := Vector2i(x, y)
	# 同步 TileMapLayer (chunk_manager 数据已写, 但视觉需另外刷)
	if tile_id == Tiles.AIR:
		terrain_layer.set_cell(pos, -1)
	elif (tile_id == Tiles.LIFE_CRYSTAL or tile_id == Tiles.MANA_CRYSTAL) and not chunk_manager.is_my_crystal(pos):
		# 联机: 别人家的水晶, 本地不显示
		terrain_layer.set_cell(pos, -1)
	elif EdgeTemplates.FAMILY_OF.has(tile_id):
		var q := Autotile.make_terrain_query(tile_id, chunk_manager)
		Autotile.refresh_tile(terrain_layer, pos, tile_id, q)
	else:
		terrain_layer.set_cell(pos, tile_id, Vector2i.ZERO)
	# 重算 8 邻居 (它们 mask 变了)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var npos := pos + Vector2i(dx, dy)
			var nsid: int = terrain_layer.get_cell_source_id(npos)
			if nsid == -1:
				continue
			if EdgeTemplates.FAMILY_OF.has(nsid):
				var nq := Autotile.make_terrain_query(nsid, chunk_manager)
				Autotile.refresh_tile(terrain_layer, npos, nsid, nq)
	# 仙人掌连接: 调用方一律传 CACTUS, 但如果当前格上方已有仙人掌, 应是 BODY
	# 反之如果当前格被挖掉 (变 AIR), 下面那个 BODY 应升级为 TOP
	_fix_cactus_at(x, y)
	_fix_cactus_at(x, y + 1)
	SkyLightGrid.invalidate_column(x)
	# 火把光源生命周期: 先 remove 旧, 再 place 新
	world_lighting.on_tile_removed(x, y, old_tid)
	world_lighting.on_tile_placed(x, y, tile_id)
	# 黑暗层: tile 改了 → 局部重算光值 (±8 涵盖火把半径 6)
	darkness_layer.recompute_around(x, y, 8)
	# 流水: 通知 water_sim, 让它评估 (x,y) 和 4 邻居是否要流
	if water_sim != null:
		water_sim.notify_tile_changed(x, y)
	# 沙子物理: 这格变 AIR → 上方 SAND 整柱下落
	if tile_id == Tiles.AIR and not skip_sand:
		_apply_sand_fall(x, y)


# 沙子物理: (x, y_air) 这格变 AIR 后, 上方第一格如果是 SAND 就下落 1 格,
# 然后新空出来的格继续找 SAND, 链式直到上方没沙了.
# 每次落, 生成一个 0.15s 的下落动画 (沙色方块从原位 tween 到新位).
func _apply_sand_fall(x: int, y_air: int) -> void:
	var cur_y: int = y_air
	for _i in 100:
		var above_y: int = cur_y - 1
		if above_y < 0:
			return
		var above_tid: int = chunk_manager.get_tile(x, above_y)
		if above_tid != Tiles.SAND:
			return
		_spawn_sand_fall_anim(x, above_y, cur_y)
		_set_tile(x, cur_y, Tiles.SAND, false, true)
		_set_tile(x, above_y, Tiles.AIR, false, true)
		cur_y = above_y


# 沙下落动画: 在 from_y → to_y 之间 tween 一个沙色 sprite, 0.15s.
const _SAND_FALL_DURATION := 0.15
func _spawn_sand_fall_anim(x: int, from_y: int, to_y: int) -> void:
	var s := Sprite2D.new()
	# 用 ArtCache 里的沙子贴图 (跟方块一致)
	if "block_icons" in ArtCache and ArtCache.block_icons.has(Tiles.SAND):
		s.texture = ArtCache.block_icons[Tiles.SAND]
	s.centered = false
	s.global_position = Vector2(x * TILE_SIZE, from_y * TILE_SIZE)
	s.z_index = 5
	add_child(s)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(s, "global_position:y", to_y * TILE_SIZE, _SAND_FALL_DURATION)
	tw.tween_callback(s.queue_free)


# 仙人掌连接: 单格修正 — 上方是仙人掌 → 当前应 = BODY (无头), 否则 = TOP (有头).
# 调用在 _set_tile 末尾 + 对下面那格也调 (因为下面那格的 "上方" = 当前格变了).
func _fix_cactus_at(x: int, y: int) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	var tid: int = chunk_manager.get_tile(x, y)
	if tid != Tiles.CACTUS and tid != Tiles.CACTUS_BODY:
		return
	var above: int = chunk_manager.get_tile(x, y - 1)
	var is_top: bool = (above != Tiles.CACTUS and above != Tiles.CACTUS_BODY)
	var want_tid: int = Tiles.CACTUS if is_top else Tiles.CACTUS_BODY
	if want_tid == tid:
		return
	# 切换类型: 同步 chunk_manager + TileMapLayer (没 autotile family, 直接 set_cell)
	chunk_manager.set_tile(x, y, want_tid)
	terrain_layer.set_cell(Vector2i(x, y), want_tid, Vector2i.ZERO)


# 水专用 fast path: 跳过 autotile/darkness/lighting/cactus/sky 等水改不影响的子系统.
# water_sim 每 tick 调几百次, 走完整 _set_tile 会卡帧 (darkness recompute 17x17 × 数百次).
# 联机: host 改水时广播给 client; client 收到通过 _on_remote_tile 走完整 _set_tile.
func _set_water_tile_fast(x: int, y: int, tile_id: int, from_remote: bool = false) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	chunk_manager.set_tile(x, y, tile_id)
	var pos := Vector2i(x, y)
	if tile_id == Tiles.AIR:
		terrain_layer.set_cell(pos, -1)
	else:
		terrain_layer.set_cell(pos, tile_id, Vector2i.ZERO)
	# host 广播给 client (但不接收方再回播, 避免回声). 批量模式累积到 buf
	if not from_remote and NetworkManager != null and NetworkManager.connected():
		if _tile_batching:
			_tile_batch.append(x); _tile_batch.append(y); _tile_batch.append(tile_id)
		else:
			NetworkManager.send_tile_change(x, y, tile_id)
	if water_sim != null:
		water_sim.notify_tile_changed(x, y)
