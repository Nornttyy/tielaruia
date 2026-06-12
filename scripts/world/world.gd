# 世界根：通过 ChunkManager 流式加载 64-宽列, 每次启动随机种子。
# 维护 TileMapLayer 视觉 (chunk_loaded/unloaded 信号驱动)。
extends Node2D

const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")
const WaterSimClass = preload("res://scripts/world/water_sim.gd")
const MinimapDataClass = preload("res://scripts/world/minimap_data.gd")
const WeatherClass = preload("res://scripts/world/weather.gd")
const CursorManagerClass = preload("res://scripts/world/cursor_manager.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")  # 静态 _biome_at / _biome_water_tile (画水按列染色用)
const VillagePrefab = preload("res://scripts/world/village_prefab.gd")
const VillagePlacer = preload("res://scripts/world/village_placer.gd")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")   # 对战房随机出生点
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")
const PlayersUtil = preload("res://scripts/entities/players_util.gd")
const SlimeClass = preload("res://scripts/entities/slime.gd")  # 用静态 color_for_depth / random_spawn_size
const ZombieScene = preload("res://scenes/entities/zombie.tscn")
const SpiderScene = preload("res://scenes/entities/spider.tscn")
const DemonEyeScene = preload("res://scenes/entities/demon_eye.tscn")
const MimicScene = preload("res://scenes/entities/mimic.tscn")
const SkeletonScene = preload("res://scenes/entities/skeleton.tscn")
const ImpScene = preload("res://scenes/entities/imp.tscn")
const HellWaspScene = preload("res://scenes/entities/hell_wasp.tscn")
const HarpyScene = preload("res://scenes/entities/harpy.tscn")
const MummyScene = preload("res://scenes/entities/mummy.tscn")
const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")
const SkeletonKingScene = preload("res://scenes/entities/skeleton_king.tscn")
const DemonLordScene = preload("res://scenes/entities/demon_lord.tscn")
const CowScene = preload("res://scenes/entities/cow.tscn")
const SheepScene = preload("res://scenes/entities/sheep.tscn")
const PigScene = preload("res://scenes/entities/pig.tscn")
const PenguinScene = preload("res://scenes/entities/penguin.tscn")
const FrogScene = preload("res://scenes/entities/frog.tscn")
const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const FireballScene = preload("res://scenes/entities/fireball.tscn")
const ArrowScene = preload("res://scenes/entities/arrow.tscn")
const BulletScene = preload("res://scenes/entities/bullet.tscn")
const BoneProjClass = preload("res://scripts/entities/bone_projectile.gd")   # 骷髅王飞骨头 (脚本直接 new, 无 .tscn)
const RemotePlayerScene = preload("res://scenes/entities/remote_player.tscn")
const HealthBarScript = preload("res://scripts/entities/health_bar.gd")

const MAX_SLIMES := 4              # 白天上限 (slime)
const UNDERGROUND_SLIME_MAX := 6  # 地下史莱姆额外上限 (跟地表分开算)
# 夜间怪 (zombie + spider 共享) 上限按难度: 简单 8 / 普通 15 / 困难 25
const NIGHT_CAP_BY_DIFFICULTY := [8, 15, 25]
const MAX_ANIMALS := 3             # 动物上限 (牛+羊+猪+企鹅+豹+青蛙 总和)
const SPAWN_INTERVAL := 6.0
const ANIMAL_SPAWN_INTERVAL := 12.0  # 动物刷新更慢
const SPAWN_RANGE_MIN := 12  # tiles
const SPAWN_RANGE_MAX := 22

const TILE_SIZE := 12

const MINIMAP_VIEW_TILES_X := 60  # 屏幕能看到的横向 tile (1280px / 0.8 zoom / 12 ≈ 133, 用 60 覆盖近视野)
const MINIMAP_VIEW_TILES_Y := 40  # 纵向 (覆盖屏幕高度)
const MINIMAP_REVEAL_ADJ := 4     # 玩家旁边 ±这么多格永远露 (黑暗里也看得到脚下一圈); 其余要被天光照到才露
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
# 床复活点: 玩家睡过床后从这里复活. (-99999, -99999) = 没设过, 用默认 spawn_point.
var bed_spawn_point: Vector2i = Vector2i(-99999, -99999)
# 睡觉状态: true = 时间 10x 加速中 (玩家躺床上, 不动). 醒条件: 天亮 / 按任意键.
var _sleeping: bool = false
var _sleep_anchor_x: float = 0.0     # 睡时玩家 x, 移动超过 8px 醒
var _sleep_armed: bool = false       # 触发睡觉那次点击松开后才"武装"按键唤醒 (防同一下立刻醒)
var _sleep_zzz: Node = null          # 头顶 "Zzz" 提示
var chunk_manager: ChunkManager
var water_sim: Node
var minimap_data: Node
var _remote_players: Dictionary = {}   # peer_id(String) → RemotePlayer 节点 (多人公共房)
var _mp_time_sync_timer: float = 0.0   # host 广播时间+天气计时 (Phase F)
const _MP_TIME_SYNC_INTERVAL := 5.0
var _mp_entity_sync_timer: float = 0.0  # host 广播实体位置计时 (Phase E)
const _MP_ENTITY_SYNC_INTERVAL := 0.2
var weather: Node
var _active_king_slime: Node = null  # 当前存活的史莱姆王 Boss (一次只准一个)
var _active_skeleton_king: Node = null  # 当前存活的骷髅王 Boss (一次只准一个)
var _active_demon_lord: Node = null  # 当前存活的地狱恶魔领主 Boss (一次只准一个)
var _slime_spawn_timer: float = 3.0  # 启动后 3s 开始刷
var _animal_spawn_timer: float = 5.0  # 启动后 5s 开始刷动物
var _crop_grow_timer: float = 60.0   # 作物生长 tick: 每 60s 一次, 每个 WHEAT_0/1/2 升一阶概率
const CROP_GROW_INTERVAL := 60.0
const CROP_GROW_CHANCE := 0.6        # 每次 tick 升级概率 (60% → 平均成熟 ~5 分钟)
# 自动门: 玩家靠近 → 整扇换 DOOR_OPEN (可穿), 离开 → 换回. host/单机 跑, swap 自动同步联机.
const DOOR_TICK_INTERVAL := 0.15     # 开关检测频率 (s)
const DOOR_CLOSE_RANGE_X := 2.6      # 玩家水平离门 > 这么多格才关 (开范围是 ±2 格扫描盒, 滞回防抖)
const DOOR_RANGE_Y := 3.5            # 垂直重叠范围 (门 3 格 + 玩家高)
var _door_tick_timer: float = 0.0
var _open_doors: Dictionary = {}     # Vector2i(门底坐标) → true: 当前开着的门
var _last_player_chunk_x: int = 0
var _minimap_mark_timer: float = 0.0
# 下落水视觉: cell → 剩余秒数. 水流过空格就刷新, 不再被流过就淡出 → 连续瀑布连成水帘.
const _FALLING_VIS_SEC := 0.3
var _falling_layer: TileMapLayer
var _falling: Dictionary = {}


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
	# 灰尘对象池: 跳/落/走 dust 共用. 跳一下 4 颗 / 落一下 6 颗, 无池就卡帧
	var DustPoolClass = preload("res://scripts/fx/dust_pool.gd")
	var dp = DustPoolClass.new()
	dp.name = "DustPool"
	$EffectsRoot.add_child(dp)
	# 水珠对象池: 预分配 120 颗 water grain, 复用减 alloc (瀑布密集处每秒几十颗)
	var WaterGrainPoolClass = preload("res://scripts/fx/water_grain_pool.gd")
	var wgp = WaterGrainPoolClass.new()
	wgp.name = "WaterGrainPool"
	$EffectsRoot.add_child(wgp)
	# 网格辅助: 按 Ctrl 开关, 整屏画 tile 网格线 + 高亮鼠标那格 (搭建对齐用). 挂 World 下 = 世界坐标.
	var GridOverlayClass = preload("res://scripts/world/grid_overlay.gd")
	var grid_overlay = GridOverlayClass.new()
	grid_overlay.name = "GridOverlay"
	add_child(grid_overlay)
	# 怪物血条: 任何进 entities_root 且有 current_health 的非玩家实体自动挂血条.
	# 一处集中 — 不用每个 entity.gd 单独加.
	entities_root.child_entered_tree.connect(_on_entity_added_for_bar)
	if world_seed == 0:
		world_seed = randi()
	if defer_init:
		return
	# 默认: 顺序跑所有 step (兼容 boot_to_game / 直接 add_child World)
	for i in STEP_LABELS.size():
		run_init_step(i)


# entities_root 加新子节点时检查: 有 current_health 且不是玩家/远程玩家 → 挂血条.
# 用 call_deferred 是因为 child_entered_tree 时 child 可能还没 _ready (没 add_to_group),
# 等帧末再挂避免顺序问题.
func _on_entity_added_for_bar(child: Node) -> void:
	if child == null:
		return
	if not ("current_health" in child):
		return
	if child.has_meta("is_remote"):
		return  # 联机远程实体: 位置由网络同步, 血条让本端自己显
	if child.is_in_group("player"):
		return  # 玩家有 HUD, 不要头顶血条
	_attach_health_bar.call_deferred(child)


func _attach_health_bar(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	# boss 用屏幕顶部专属大血条 (HUD/BossBar), 不挂头顶小条. (此处 deferred, boss _ready 已跑完入组)
	if target.is_in_group("boss"):
		return
	var bar := HealthBarScript.new()
	bar.name = "HealthBar"
	target.add_child(bar)


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
	# 下落水视觉层: 纯画面, 在空气格里画"正在下落的水"连成连续水流 (瀑布不再一段段).
	# 复用同一 TileSet (有水 tile + 动画), 排在 TerrainLayer 之后同 z → 盖在地形水同层.
	_falling_layer = TileMapLayer.new()
	_falling_layer.name = "FallingWaterLayer"
	_falling_layer.tile_set = ts
	_falling_layer.modulate = Color(1, 1, 1, 0.85)   # 略透, 像流动的水帘
	add_child(_falling_layer)
	move_child(_falling_layer, terrain_layer.get_index() + 1)


func _step_chunks() -> void:
	chunk_manager = ChunkManagerClass.new()
	chunk_manager.name = "ChunkManager"
	add_child(chunk_manager)
	chunk_manager.setup(world_seed)
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	# 把 chunk_manager 下发给水珠池: 水珠落地溅花要查 get_tile (池在更早的 _ready 建好, 那时还没 chunk_manager)
	var _wgp: Node = $EffectsRoot.get_node_or_null("WaterGrainPool")
	if _wgp != null:
		_wgp.chunk_manager = chunk_manager
	# water_sim 必须在 ensure_loaded 之前建好: 否则初始区块加载触发的 _on_chunk_loaded 里
	# "if water_sim != null" 唤醒+settle 整块被跳过 → 出生点周围生成的悬空水永远没被叫醒不流
	# (修 test_water_settles). water_sim 只依赖 world=self, 提前建无副作用.
	water_sim = WaterSimClass.new()
	water_sim.name = "WaterSim"
	water_sim.world = self
	add_child(water_sim)
	# 初始加载中心 ±VIEW_RADIUS
	chunk_manager.ensure_loaded(0)


func _step_fx_layers() -> void:
	# 流水模拟 water_sim 已在 _step_chunks 里 (ensure_loaded 之前) 创建, 这里不再重复建.
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
	# 多人: 谁进/离房 → spawn/移除对应远程玩家 (不再开局就建单个)
	if not NetworkManager.peer_joined.is_connected(_on_peer_joined):
		NetworkManager.peer_joined.connect(_on_peer_joined)
	if not NetworkManager.peer_left.is_connected(_on_peer_left):
		NetworkManager.peer_left.connect(_on_peer_left)
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
	if not NetworkManager.remote_entity_damage_received.is_connected(_on_remote_entity_damage):
		NetworkManager.remote_entity_damage_received.connect(_on_remote_entity_damage)
	if not NetworkManager.remote_projectile_received.is_connected(_on_remote_projectile):
		NetworkManager.remote_projectile_received.connect(_on_remote_projectile)
	if not NetworkManager.remote_player_death_received.is_connected(_on_remote_player_death):
		NetworkManager.remote_player_death_received.connect(_on_remote_player_death)
	if not NetworkManager.remote_player_respawn_received.is_connected(_on_remote_player_respawn):
		NetworkManager.remote_player_respawn_received.connect(_on_remote_player_respawn)
	if not NetworkManager.remote_drop_request_received.is_connected(_on_remote_drop_request):
		NetworkManager.remote_drop_request_received.connect(_on_remote_drop_request)
	if not NetworkManager.remote_drop_pos_received.is_connected(_on_remote_drop_pos):
		NetworkManager.remote_drop_pos_received.connect(_on_remote_drop_pos)
	if not NetworkManager.remote_drop_pickup_received.is_connected(_on_remote_drop_pickup):
		NetworkManager.remote_drop_pickup_received.connect(_on_remote_drop_pickup)
	if not NetworkManager.remote_tile_batch_received.is_connected(_on_remote_tile_batch):
		NetworkManager.remote_tile_batch_received.connect(_on_remote_tile_batch)
	if not NetworkManager.remote_name_received.is_connected(_on_remote_name):
		NetworkManager.remote_name_received.connect(_on_remote_name)
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
	elif s == "disconnected" or s == "error":
		_cleanup_remote_on_disconnect()


# 对方掉线: 清掉对方角色 + 所有从对端同步来的怪/实体, 否则残留"幽灵"继续接触伤害本地玩家.
func _cleanup_remote_on_disconnect() -> void:
	for pid in _remote_players.keys():
		var rp = _remote_players[pid]
		if rp != null and is_instance_valid(rp):
			rp.queue_free()
	_remote_players.clear()
	for id in _remote_entities.keys():
		var ent = _remote_entities[id]
		if ent != null and is_instance_valid(ent):
			ent.queue_free()
	_remote_entities.clear()
	# client 已捡 drop 的 id 记录也清掉, 否则重连后 host 重新广播这些 drop 会被当"已捡"拒绝创建 → 隐身
	_picked_up_drop_ids.clear()


func _mp_broadcast_initial_state() -> void:
	# host 进 world 后调. 拿 chunk_manager._deltas 序列化广播
	if chunk_manager == null:
		return
	# 对战房: 各端本地生成同一座竞技场 + 方块独立, 不广播地形 delta (否则把 host 的改动同步过去)。
	if NetworkManager != null and NetworkManager.room_mode == "pvp":
		return
	NetworkManager.send_initial_state(chunk_manager._deltas)


func _on_initial_state(deltas: Dictionary) -> void:
	# 对战房: 不应用别人的地形 (各房独立, 自己本地已 build 竞技场)。
	if NetworkManager != null and NetworkManager.room_mode == "pvp":
		return
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
var _arena_building: bool = false   # PvpArena.build 期间 true: 地基铺设不广播 (各端本地铺, 防洪水)


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


func _on_remote_entity_pos(ent_id: int, kind: String, x: float, y: float, hp: int, facing: int, anim: String) -> void:
	var ent: Node = _get_valid_remote(ent_id)
	if ent == null:
		# 第一次见这个实体 (或旧的已被释放): 生成视觉版本
		ent = _spawn_remote_entity(kind)
		if ent != null:
			ent.set_meta("remote_id", ent_id)   # client 的剑命中时回传伤害给 host 认这只怪
			_remote_entities[ent_id] = ent
	if ent != null:
		ent.global_position = Vector2(x, y)
		# 同步血量 → health_bar 每帧从 current_health 读, 自动显示对端真实血量 (之前写死 0)
		if hp > 0 and "current_health" in ent:
			ent.current_health = hp
		# 同步朝向 + 动画 (之前只挪位置, 导致对方看到动物方向/动作不变在滑动)
		var spr: AnimatedSprite2D = ent.get_node_or_null("AnimatedSprite2D")
		if spr != null:
			spr.flip_h = facing < 0
			if anim != "" and spr.animation != anim:
				spr.play(anim)


func _on_remote_entity_die(ent_id: int) -> void:
	var ent: Node = _get_valid_remote(ent_id)
	if ent != null:
		ent.queue_free()
	_remote_entities.erase(ent_id)


# host 收到 client 发来的伤害 → 在自己那只真怪上扣血 (host 权威; 死亡/血量随后随广播同步回 client)
func _on_remote_entity_damage(ent_id: int, amount: int, knockback: float, sx: float, sy: float) -> void:
	if not NetworkManager.is_host:
		return
	var ent: Node = _find_local_entity_by_id(ent_id)
	if ent != null and ent.has_method("take_damage"):
		ent.take_damage(amount, Vector2(sx, sy), knockback)


# 按 entity_id_for 在本地真实实体里找 (host 用; 跟广播的 id 算法一致)
func _find_local_entity_by_id(ent_id: int) -> Node:
	for grp in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(grp):
			if e is Node2D and NetworkManager.entity_id_for(e) == ent_id:
				return e
	return null


# 对方发的投射物 → 本端生成纯视觉副本 (飞同样轨迹, is_remote 标记让它不造成伤害)
func _on_remote_projectile(kind: String, sx: float, sy: float, tx: float, ty: float) -> void:
	var start := Vector2(sx, sy)
	var target := Vector2(tx, ty)
	# 骨头是"怪打玩家"的弹, 跟 arrow/fireball (玩家打怪, host 算伤害, 副本 dmg=0) 相反:
	# 接触玩家伤害每端各管自己, 所以 client 这根 remote 骨头要真扣血, 且只命中本地玩家 (见 bone _find_player).
	if kind == "bone":
		var b = BoneProjClass.new()
		b.set_meta("is_remote", true)
		entities_root.add_child(b)
		b.setup(start, target, 12)   # 12 = SkeletonKing.THROW_DAMAGE
		return
	# 子弹: 跟箭一样是"玩家打怪"的视觉副本 (dmg=0, host 算伤害)
	if kind == "bullet":
		var b: Node2D = BulletScene.instantiate()
		b.set_meta("is_remote", true)
		entities_root.add_child(b)
		b.setup(start, target, 0, null)
		return
	var proj: Node2D = ArrowScene.instantiate() if kind == "arrow" else FireballScene.instantiate()
	proj.set_meta("is_remote", true)
	entities_root.add_child(proj)
	if kind == "arrow":
		proj.setup(start, target, 0, null)
	else:
		# fireball / fireball_nature / fireball_ice / fireball_fire → 取后缀当元素
		var element: String = "fire"
		if kind.begins_with("fireball_"):
			element = kind.substr("fireball_".length())
		proj.setup(start, target, 0, true, element)


func _on_remote_player_death(peer_id: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp != null and is_instance_valid(rp) and rp.has_method("set_dead"):
		rp.set_dead(true)


func _on_remote_player_respawn(peer_id: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp != null and is_instance_valid(rp) and rp.has_method("set_dead"):
		rp.set_dead(false)


# host 收到 client 挖矿掉落请求 → 权威生成 (随后 _mp_broadcast_entities 广播给两边)
func _on_remote_drop_request(item_id: String, count: int, x: float, y: float) -> void:
	if not NetworkManager.is_host:
		return
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = count
	drop.global_position = Vector2(x, y)
	entities_root.add_child(drop)


func _spawn_remote_entity(kind: String) -> Node:
	# 用现成的 scene, 加入 entities_root, 但禁用 AI (slime 等会检测 is_remote 跳过逻辑)
	var scene: PackedScene = null
	match kind:
		"king": scene = KingSlimeScene   # 史莱姆王 Boss: client 也用真 scene → 有王冠/大体型/进 group boss → 顶部血条显示
		"skeleton_king": scene = SkeletonKingScene   # 骷髅王 Boss: client 也用真 scene (王冠/大体型/boss 血条)
		"demon_lord": scene = DemonLordScene   # 恶魔领主 Boss: client 也用真 scene (飞行体型/boss 血条)
		"slime": scene = SlimeScene
		"zombie": scene = ZombieScene
		"spider": scene = SpiderScene
		"demon_eye": scene = DemonEyeScene
		"skeleton": scene = SkeletonScene
		"imp": scene = ImpScene
		"hell_wasp": scene = HellWaspScene
		"mummy": scene = MummyScene
		"harpy": scene = HarpyScene
		"mimic": scene = MimicScene
		"cow": scene = CowScene
		"sheep": scene = SheepScene
		"pig": scene = PigScene
		"penguin": scene = PenguinScene
		"frog": scene = FrogScene
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


func _spawn_remote_player(peer_id: String) -> Node:
	if _remote_players.has(peer_id) and is_instance_valid(_remote_players[peer_id]):
		return _remote_players[peer_id]
	var rp: Node = RemotePlayerScene.instantiate()
	rp.name = "RemotePlayer_" + peer_id
	entities_root.add_child(rp)
	if "peer_id" in rp:
		rp.peer_id = peer_id
	# 初始放在 spawn 点附近 (收到第一条 pos 后 snap 到真实位置)
	rp.global_position = Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE + TILE_SIZE
	)
	# name 消息可能先于 spawn 到达 → spawn 时补上已收到的对方名字
	if rp.has_method("set_player_name") and NetworkManager.remote_player_name != "":
		rp.set_player_name(NetworkManager.remote_player_name)
	_remote_players[peer_id] = rp
	return rp


func _on_peer_joined(peer_id: String) -> void:
	_spawn_remote_player(peer_id)


func _on_peer_left(peer_id: String) -> void:
	if _remote_players.has(peer_id):
		var rp = _remote_players[peer_id]
		if is_instance_valid(rp):
			rp.queue_free()
		_remote_players.erase(peer_id)


# 给 chat_box 按 peer 定位头顶气泡用
func get_remote_player(peer_id: String) -> Node:
	return _remote_players.get(peer_id, null)


# 踢人 UI 用: 当前所有远程玩家 [{id, name}]
func get_remote_player_list() -> Array:
	var out: Array = []
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if rp == null or not is_instance_valid(rp):
			continue
		var nm: String = ""
		if "peer_id" in rp:
			nm = String(rp.peer_id)
		var label = rp.get_node_or_null("NameLabel")
		if label != null and String(label.text) != "":
			nm = String(label.text)
		out.append({"id": String(pid), "name": nm})
	return out


func _on_remote_pos(peer_id: String, x: float, y: float, facing: int, anim: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp == null or not is_instance_valid(rp):
		rp = _spawn_remote_player(peer_id)   # 懒创建: pos 先于 join 到也不丢人
	if rp.has_method("apply_pos"):
		rp.apply_pos(x, y, facing, anim)


func _on_remote_name(peer_id: String, n: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp != null and is_instance_valid(rp) and rp.has_method("set_player_name"):
		rp.set_player_name(n)


func _place_village() -> void:
	var prefab = VillagePrefab.load_default()
	if prefab.is_empty():
		return
	# 只盖房子结构 (村民 NPC 已移除)
	VillagePlacer.place(chunk_manager, terrain_layer, prefab, spawn_point)


func _process(delta: float) -> void:
	_sweep_falling_water(delta)   # 下落水视觉淡出 (每帧)
	# 联机 client (不是 host) 跳过怪物/动物刷新 (host 权威, client 只接受 ent_pos 同步)
	var is_mp_client: bool = NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host
	# 对战房 (PvP/起床战争) 不刷怪/动物 — 纯玩家对战 (作物/门照常)
	var no_mobs: bool = _no_mob_room()
	if not is_mp_client and not no_mobs:
		_slime_spawn_timer -= delta
		if _slime_spawn_timer <= 0.0:
			_slime_spawn_timer = SPAWN_INTERVAL
			if TimeOfDay.is_night():
				_try_spawn_zombie()      # 夜间(含地下)走僵尸/蜘蛛/地狱怪那套
			elif _player_is_deep():
				_try_spawn_underground_slime()  # 白天地下: 按深度配色史莱姆刷在玩家旁
			else:
				_try_spawn_slime()
		_animal_spawn_timer -= delta
		if _animal_spawn_timer <= 0.0:
			_animal_spawn_timer = ANIMAL_SPAWN_INTERVAL
			if not TimeOfDay.is_night():
				_try_spawn_animal()
	if not is_mp_client:
		_crop_grow_timer -= delta
		if _crop_grow_timer <= 0.0:
			_crop_grow_timer = CROP_GROW_INTERVAL
			_tick_crop_growth()
		_door_tick_timer -= delta
		if _door_tick_timer <= 0.0:
			_door_tick_timer = DOOR_TICK_INTERVAL
			_tick_doors()
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
	# 怪物 / 动物
	# 注: 僵尸同时在 "slimes" 和 "zombies" 组, "slimes" 分支已按 scene_path 认出僵尸,
	# 故这里不再单列 "zombies", 否则每个僵尸每 tick 被广播两遍 (双倍带宽).
	for grp in ["slimes", "animals"]:
		for ent in get_tree().get_nodes_in_group(grp):
			if not (ent is Node2D):
				continue
			var n2d: Node2D = ent
			var kind: String = "slime"
			match grp:
				"slimes":
					# spider / demon_eye 也在 slimes 组 (共享剑挥). 用 scene_path 区分.
					var scene_path_s: String = n2d.scene_file_path if n2d.scene_file_path != null else ""
					if "king_slime" in scene_path_s:
						kind = "king"   # 史莱姆王 Boss (路径含 slime, 必须先认 king 否则当普通史莱姆)
					elif "skeleton_king" in scene_path_s:
						kind = "skeleton_king"   # 骷髅王 Boss (在 slimes 组, 路径区分, 否则当普通史莱姆广播)
					elif "spider" in scene_path_s:
						kind = "spider"
					elif "demon_eye" in scene_path_s:
						kind = "demon_eye"
					elif "zombie" in scene_path_s:
						kind = "zombie"
					elif "skeleton" in scene_path_s:
						kind = "skeleton"
					elif "hell_wasp" in scene_path_s:
						kind = "hell_wasp"
					elif "imp" in scene_path_s:
						kind = "imp"
					elif "mummy" in scene_path_s:
						kind = "mummy"
					elif "harpy" in scene_path_s:
						kind = "harpy"
					elif "mimic" in scene_path_s:
						kind = "mimic"
					elif "frog" in scene_path_s:
						continue   # 青蛙继承 slime 也在 slimes 组, 但由 "animals" 分支广播 → 这里跳过防双发
					else:
						kind = "slime"
				"zombies": kind = "zombie"
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
			var espr: AnimatedSprite2D = n2d.get_node_or_null("AnimatedSprite2D")
			var efacing: int = 1
			var eanim: String = ""
			if espr != null:
				efacing = -1 if espr.flip_h else 1
				eanim = String(espr.animation)
			var ehp: int = int(n2d.get("current_health")) if "current_health" in n2d else 0
			NetworkManager.send_entity_pos(
				NetworkManager.entity_id_for(n2d),
				kind,
				n2d.global_position.x, n2d.global_position.y, ehp,
				efacing, eanim
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
	if player == null or minimap_data == null or chunk_manager == null:
		return
	var ptx: int = int(floor(player.global_position.x / TILE_SIZE))
	var pty: int = int(floor(player.global_position.y / TILE_SIZE))
	var hx: int = MINIMAP_VIEW_TILES_X / 2
	var hy: int = MINIMAP_VIEW_TILES_Y / 2
	# 只露"被天光照到的方块" + "玩家旁边一圈" (像探照灯/迷雾; 黑暗深处没走近不露).
	for wx in range(ptx - hx, ptx + hx + 1):
		for wy in range(pty - hy, pty + hy + 1):
			if absi(wx - ptx) <= MINIMAP_REVEAL_ADJ and absi(wy - pty) <= MINIMAP_REVEAL_ADJ:
				minimap_data.mark_one(chunk_manager, wx, wy)        # 玩家旁边一圈
			elif SkyLightGrid.is_sky_exposed(wx, wy):
				minimap_data.mark_one(chunk_manager, wx, wy)        # 被天光照到


func _physics_process(_delta: float) -> void:
	_check_chunk_load()
	if _sleeping:
		_check_sleep_wake()


# 上床睡觉: 设复活点 + 躺下. tile 是床的世界坐标.
# 什么时间都能睡; 在床上时间永远 10x 加速; 按任意键下床。
func sleep_in_bed(tile: Vector2i) -> void:
	bed_spawn_point = tile
	_sleeping = true
	if TimeOfDay != null:
		TimeOfDay.time_multiplier = 10.0   # 在床上时间永远 10x (不分白天黑夜)
	var player := get_player()
	if player != null:
		# 把玩家挪到床中央 (2 格宽: tile 是左格, +1.0 = 左右两格接缝 = 床正中)
		player.global_position = Vector2((float(tile.x) + 1.0) * TILE_SIZE, (float(tile.y) + 1.0) * TILE_SIZE)
		_sleep_anchor_x = player.global_position.x
		_sleep_armed = false   # 等触发睡觉那次点击松开才允许按键唤醒
		# 睡觉期间禁止玩家移动 + 给一个安全 iframe (老 bug: 没锁, 怪打过来 = 任挨打死)
		player.set_physics_process(false)
		# 关键: PlayerAction 是子节点, player.set_physics_process(false) 不会停它 →
		# 不锁的话睡觉还能挖/放方块 (bug2), 而且对着床再点会重复 sleep_in_bed 重置 anchor → 永远醒不来 (bug1).
		# 把它的 _physics_process 也停掉, _wake_up 再开。
		var pa_sleep = player.get_node_or_null("PlayerAction")
		if pa_sleep != null:
			pa_sleep.set_physics_process(false)
		var hp = player.get_node_or_null("PlayerHealth")
		if hp != null:
			hp._iframe_timer = 999.0  # 睡觉期间无敌, _wake_up 时清
		# 睡觉动作: 人物躺下 + 头顶飘 Zzz
		var spr = player.get_node_or_null("AnimatedSprite2D")
		if spr != null:
			# centered=true 让旋转绕身体中心. 默认 centered=false 是绕角点转, 躺下后身体会甩到
			# 节点右上方 = "睡觉位置歪". 配合下面 position 把身体中心摆到床面正中.
			# 醒来 _wake_up 复位成 player.tscn 的站立配置 (centered/offset/position).
			spr.centered = true
			spr.offset = Vector2.ZERO
			spr.position = Vector2(0, -6)   # 身体中心落到床格竖直中部 (节点原点=脚底, 在床格下沿)
			spr.rotation = -PI / 2.0
		# 睡觉时藏起手里拿的东西 (躺着还举着剑/方块很怪)
		var held = player.get_node_or_null("HeldItem")
		if held != null:
			held.visible = false
		_spawn_zzz(player)


# 睡觉醒条件: 只看"按任意键". 时间永远 10x, 不会因天亮自动醒 (玩家自己按键下床)。
# 触发睡觉那次右键得先松开 (_sleep_armed) 才认按键, 否则同一下点击立刻把你叫醒。
func _check_sleep_wake() -> void:
	if get_player() == null:
		_wake_up()
		return
	if not _sleep_armed:
		# 等所有按键/鼠标都松开, 才"武装" (防睡觉那一下点击立刻醒)
		if not Input.is_anything_pressed():
			_sleep_armed = true
		return
	# 武装后: 按任意键/鼠标 → 下床
	if Input.is_anything_pressed():
		_wake_up()


func _wake_up() -> void:
	_sleeping = false
	if TimeOfDay != null:
		TimeOfDay.time_multiplier = 1.0
	# 恢复玩家移动 + 清掉 sleep 时的无敌 (跟 sleep_in_bed 对应)
	var player := get_player()
	if player != null:
		player.set_physics_process(true)
		# 恢复 PlayerAction (睡觉时停掉了, 见 sleep_in_bed) → 醒后又能挖/放/用了
		var pa_wake = player.get_node_or_null("PlayerAction")
		if pa_wake != null:
			pa_wake.set_physics_process(true)
		var hp = player.get_node_or_null("PlayerHealth")
		if hp != null and hp._iframe_timer > 100.0:
			hp._iframe_timer = 0.5  # 短 iframe 防醒了立刻被怪打
		# 起身: sprite 复位成 player.tscn 站立配置 (跟 sleep_in_bed 躺下动作一一对应)
		var spr = player.get_node_or_null("AnimatedSprite2D")
		if spr != null:
			spr.rotation = 0.0
			spr.centered = false
			spr.offset = Vector2(-6, 0)
			spr.position = Vector2(0, -30)
		# 恢复手持物显示 (按当前 hotbar 重新判定显不显示)
		var held = player.get_node_or_null("HeldItem")
		if held != null and held.has_method("_refresh"):
			held._refresh()
	_remove_zzz()


# 头顶 Zzz 提示 (睡觉时)
func _spawn_zzz(player: Node2D) -> void:
	_remove_zzz()
	var lbl := Label.new()
	lbl.text = "Zzz"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	lbl.position = Vector2(2, -36)   # 头顶上方
	lbl.z_index = 20
	player.add_child(lbl)
	_sleep_zzz = lbl


func _remove_zzz() -> void:
	if _sleep_zzz != null and is_instance_valid(_sleep_zzz):
		_sleep_zzz.queue_free()
	_sleep_zzz = null


# world 被 free 时 (回主菜单 / 切场景) 必须 reset autoload 的 time_multiplier,
# 不然睡觉中 ESC 退出 → TimeOfDay 卡 10x, 下局时间一直快进.
func _exit_tree() -> void:
	if TimeOfDay != null:
		TimeOfDay.time_multiplier = 1.0


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
	# 摄像机大小: GameSettings.camera_zoom 同步到 Camera2D.zoom.
	# 用 camera 成员引用, 不能用 get_node("Camera2D") — spawn 时 camera 已 reparent 到玩家下,
	# 路径查不到 → 缩放设置(滑块/滚轮)全失效. (修"滚轮不缩放"的真根因.)
	if camera != null:
		camera.zoom = Vector2(GameSettings.camera_zoom, GameSettings.camera_zoom)


# _on_lightning_flash 已删 (跟雨一起)


func _check_chunk_load() -> void:
	var player := get_player()
	if player == null:
		return
	var pcx: int = Chunk.chunk_x_of(int(floor(player.global_position.x / TILE_SIZE)))
	if pcx != _last_player_chunk_x:
		_last_player_chunk_x = pcx
		chunk_manager.ensure_loaded(pcx)
		chunk_manager.unload_far_from(pcx, chunk_manager.view_radius + 1)


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
				# 水 (普通 + 群系满水) 按列染成所在群系色; 非水 _display_water_tile 原样返回
				terrain_layer.set_cell(pos, _display_water_tile(world_x, tid), Vector2i.ZERO)
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
				# 水和岩浆都要唤醒 (以前只认水, 岩浆瀑布冻空中); 水源块也要 (不然冻崖顶不流).
				if not water_sim.wakes_on_chunk_load(t):
					continue
				# 收 4 邻居 tile (越界用 -1 = chunk 边界开口, 保守唤醒)
				var nbs: Array = []
				for nb in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx_local: int = lx + nb.x
					var ny: int = y + nb.y
					if nx_local < 0 or nx_local >= w or ny < 0 or ny >= h:
						nbs.append(-1)
					else:
						nbs.append(col[ny] if nb.x == 0 else c.tiles[nx_local][ny])
				# 还能流 (旁边空气/边界/同种更低液位) 才标 dirty, 内部封死的不动省 CPU
				if water_sim.tile_can_still_flow(t, nbs):
					water_sim.mark_dirty(chunk_start + lx, y)
		# 跨 chunk 边界: 也唤醒相邻"已加载" chunk 紧挨本 chunk 的那 1 列水. 本 chunk 一出现,
		# 这些边界水可能能流进来 — 一起放进本次 settle 流稳, 否则会在玩家眼前实时流那一下.
		for edge_wx in [chunk_start - 1, chunk_start + w]:
			var ncx: int = Chunk.chunk_x_of(edge_wx)
			if not chunk_manager.is_chunk_loaded(ncx):
				continue
			for y in h:
				var et: int = chunk_manager.get_tile(edge_wx, y)
				if not water_sim.wakes_on_chunk_load(et):
					continue
				var enbs: Array = [
					chunk_manager.get_tile(edge_wx, y + 1) if y + 1 < h else -1,
					chunk_manager.get_tile(edge_wx, y - 1) if y - 1 >= 0 else -1,
					chunk_manager.get_tile(edge_wx - 1, y),
					chunk_manager.get_tile(edge_wx + 1, y),
				]
				if water_sim.tile_can_still_flow(et, enbs):
					water_sim.mark_dirty(edge_wx, y)
		# 加载即定型: 一口气流到稳. 实时流动残留的"悬空孤儿水"由 water_sim 定期巡检兜底.
		water_sim.settle_now()
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
	for group in ["slimes", "zombies", "animals", "item_drops"]:
		for ent in get_tree().get_nodes_in_group(group):
			# Boss 在 "slimes" 组里, 但有自己的远离消失逻辑 — chunk 卸载别误删 (否则用钩爪/传送拉开距离让王那列卸载, 王凭空消失+血条空挂)
			# 结构守卫 (空岛哈比/金字塔木乃伊/矿井蜘蛛) 同理: 它们有 per-chunk "已召" 永久标志 (设计是杀完才清空),
			# chunk 卸载删活守卫但标志还在 → 玩家没杀就离开, 回来守卫凭空消失. 一并跳过 (只能被杀清除).
			if ent.is_in_group("boss") or ent.is_in_group("harpies") or ent.is_in_group("mummies") or ent.is_in_group("spiders"):
				continue
			if ent.global_position.x >= chunk_start_px and ent.global_position.x < chunk_end_px:
				ent.queue_free()
	# 清该 chunk 范围内所有火把光
	world_lighting.on_chunk_unloaded(cx, ChunkConstants.CHUNK_WIDTH)
	# 清该 chunk 范围内黑暗瓦片
	darkness_layer.clear_chunk(cx, ChunkConstants.CHUNK_WIDTH, ChunkConstants.WORLD_HEIGHT)


# 找任何地表 (草/沙/雪/丛林/沼泽) 上方 3 格空气. 先 chunk 0, 再扫 ±2 chunk.
# 大世界 (world_size=2) biome 拉远 1.6x, chunk 0 可能落进雪/丛林/沼泽, 之前只认
# GRASS/SAND → 找不到 → 玩家埋在 (0, 100) 石头里 → 拿不到 starter + 不能动 + 小地图不扩.
# 该列"真地表" y: 最顶上的实心 tile, 且它是地表类 (草/沙/雪/泥); 否则 -1.
# 关键: 只看"最顶实心" → 洞里的方块 (顶上还压着实心地) 永远不会被误选 →
# 修"出生在矿洞" bug: 老逻辑扫到第一个"地表类+上面3格空"就用, 会把洞里被挖空的深处沙/泥当地表.
static func _surface_y_of_column(col: Array) -> int:
	var surf := {
		Tiles.GRASS: true, Tiles.SAND: true, Tiles.SNOW: true,
		Tiles.JUNGLE_GRASS: true, Tiles.SWAMP_GRASS: true, Tiles.MUD: true,
	}
	for y in range(1, col.size()):
		if col[y] != Tiles.AIR:
			return y if surf.has(col[y]) else -1   # 最顶实心: 是地表类才出生, 否则跳过这列
	return -1


func _find_spawn_in_loaded() -> Vector2i:
	for cx in [0, -1, 1, -2, 2]:
		var ch: Chunk = chunk_manager.get_chunk(cx)
		if ch == null:
			continue
		for lx in ch.tiles.size():
			var sy: int = _surface_y_of_column(ch.tiles[lx])
			if sy < 0:
				continue
			var wx: int = cx * ChunkConstants.CHUNK_WIDTH + lx
			return Vector2i(wx, sy - 1)
	# 兜底: (0, 50) 比 (0, 100) 安全 — 至少在地表附近高空, 落下到地面
	return Vector2i(0, 50)


func _try_spawn_slime() -> void:
	var slimes := get_tree().get_nodes_in_group("slimes")
	if slimes.size() >= MAX_SLIMES:
		return
	var s = _spawn_surface_creature(SlimeScene)
	if s != null and s.has_method("setup"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		# 地表深度≈0 → color_for_depth 给 70绿/30蓝
		s.setup(SlimeClass.color_for_depth(0, rng), SlimeClass.random_spawn_size(rng))


# 玩家是否在地下 (地表往下 >=8 格). 地下白天刷史莱姆而不是地表那只.
func _player_is_deep() -> bool:
	var player := get_player()
	if player == null:
		return false
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	var surf: int = _surf_at_x(px)
	if surf < 0:
		return false  # 地表未知 (区块没加载, 如刚进世界) → 当作不深, 别刷地下紫史莱姆
	return py - surf >= 8


# 某列地表 y. 用区块生成时存好的 surfaces (不受挖动/加载影响), 比扫活 tile 稳.
# 区块没加载 (surfaces 取不到) → 返回 -1 表示"未知", 调用方按"不深/跳过"处理.
# (旧版扫不到实心就返回 0, 把没加载的列当成"地表在世界顶" → 深度算成上百格 →
#  地表被误判成地下, 刷出红/紫史莱姆. 这是"地面出现紫史莱姆"的根因.)
func _surf_at_x(x: int) -> int:
	var ch: Chunk = chunk_manager.get_chunk(Chunk.chunk_x_of(x))
	if ch == null:
		return -1
	var lx: int = Chunk.local_x_of(x)
	if lx < 0 or lx >= ch.surfaces.size():
		return -1
	return int(ch.surfaces[lx])


# 地下刷史莱姆: 玩家附近找 AIR(头顶空+脚下实心) 刷一只按深度配色的史莱姆.
# 越深越强 (深度决定颜色: 浅蓝→深红→极深紫). 仿 _spawn_hell_creature 的找坑逻辑.
func _try_spawn_underground_slime() -> void:
	# 联机: 随机挑个玩家身边刷 (含加入的人); 单机退化成本地玩家。
	var players: Array = PlayersUtil.all_players(get_tree())
	if players.is_empty():
		return
	var player: Node2D = players[randi() % players.size()]
	var slimes := get_tree().get_nodes_in_group("slimes")
	if slimes.size() >= MAX_SLIMES + UNDERGROUND_SLIME_MAX:
		return
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	for _i in 12:
		var sign_x: int = 1 if randf() < 0.5 else -1
		var dx: int = sign_x * randi_range(SPAWN_RANGE_MIN, SPAWN_RANGE_MAX)
		var cand_x: int = px + dx
		var cand_y: int = py + randi_range(-3, 3)
		# 地狱(>=220)留给地狱怪, 不在这刷
		if cand_y >= 220 or cand_y >= ChunkConstants.WORLD_HEIGHT - 2:
			continue
		var cand_surf: int = _surf_at_x(cand_x)
		if cand_surf < 0:
			continue  # 这列地表未知 (没加载) → 跳过, 别按错深度配出红/紫
		var depth: int = cand_y - cand_surf
		if depth < 8:
			continue  # 太浅算地表, 跳过
		if chunk_manager.get_tile(cand_x, cand_y) != Tiles.AIR:
			continue  # 站位要空
		if chunk_manager.get_tile(cand_x, cand_y - 1) != Tiles.AIR:
			continue  # 头顶要空
		var below: int = chunk_manager.get_tile(cand_x, cand_y + 1)
		if below == Tiles.AIR or below == Tiles.LAVA:
			continue  # 脚下要实心
		var s := SlimeScene.instantiate()
		s.global_position = Vector2(
			cand_x * TILE_SIZE + TILE_SIZE / 2.0,
			(cand_y + 1) * TILE_SIZE
		)
		# setup 在 add_child 前调: _ready 里按颜色/大小应用一次, 不重复
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		s.setup(SlimeClass.color_for_depth(depth, rng), SlimeClass.random_spawn_size(rng))
		entities_root.add_child(s)
		return


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


# 召唤史莱姆王到 pos 附近. 已有存活 Boss → 返回 false 拒绝 (一次只准一个).
# 注: queue_free 掉的旧 Boss 会变成 invalid, is_instance_valid 自动放行新召唤,
# 所以 Boss 死/消失不用主动通知 world.
func spawn_king_slime(pos: Vector2) -> bool:
	if _active_king_slime != null and is_instance_valid(_active_king_slime):
		return false
	var boss = KingSlimeScene.instantiate()
	entities_root.add_child(boss)
	boss.global_position = pos
	_active_king_slime = boss
	return true


# 召唤骷髅王到 pos 附近 (跟 spawn_king_slime 同款单例守卫).
func spawn_skeleton_king(pos: Vector2) -> bool:
	if _active_skeleton_king != null and is_instance_valid(_active_skeleton_king):
		return false
	var boss = SkeletonKingScene.instantiate()
	entities_root.add_child(boss)
	boss.global_position = pos
	_active_skeleton_king = boss
	return true


# Boss 召唤总入口: 召唤道具的 summon_boss 字段 → 派发到具体 spawn. 新 Boss 加 case 即可。
func spawn_boss(boss_id: String, pos: Vector2) -> bool:
	match boss_id:
		"skeleton_king":
			return spawn_skeleton_king(pos)
		"demon_lord":
			return spawn_demon_lord(pos)
		_:
			return spawn_king_slime(pos)


# 召唤地狱恶魔领主到 pos. 已有存活 → 拒绝 (一次只准一个)。生在 pos 上方一点 (飞行怪).
func spawn_demon_lord(pos: Vector2) -> bool:
	if _active_demon_lord != null and is_instance_valid(_active_demon_lord):
		return false
	var boss = DemonLordScene.instantiate()
	entities_root.add_child(boss)
	boss.global_position = pos + Vector2(0, -64)   # 头顶飞出
	_active_demon_lord = boss
	return true


# 金字塔守卫: 给一组 spawn 点 (世界坐标) 召 mummy. chunk_manager 在
# chunk 加载时调. 用 _pyramid_chunks_spawned 防同 chunk 重 spawn.
var _pyramid_chunks_spawned: Dictionary = {}   # chunk_x int → true
# 对战房 (PvP / 起床战争): 不刷任何怪 — 定时刷 + chunk 加载触发的 (木乃伊/矿井蜘蛛/哈比鸟) 都拦.
# 用 room_mode=="pvp" 而不只 combat_enabled(): 连接中 / 切模式转房断开期间 connected() 是 false,
# 但 room_mode 已置 pvp → 这段窗口也别刷怪 (修"对战房会刷生物")。
func _no_mob_room() -> bool:
	if NetworkManager == null:
		return false
	return NetworkManager.combat_enabled() or NetworkManager.room_mode == "pvp"


func spawn_mummies_for_chunk(chunk_x: int, spots: Array) -> void:
	if _no_mob_room():
		return   # 对战房不刷怪 (chunk 加载触发的也要拦)
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


# 世纪树已删 (用户要求)

# 菜园: 扫所有 loaded chunk 找 WHEAT_0/1/2, 70% 概率升一阶. 每 15s 调.
# 平均 ~45s 从苗到熟 (15s × 3 阶段 / 0.7 概率).
func _tick_crop_growth() -> void:
	if chunk_manager == null:
		return
	const CHUNK_WIDTH := 64
	const HEIGHT := 256   # ChunkConstants.WORLD_HEIGHT (用常量避免 import)
	for cx in chunk_manager._loaded.keys():
		var c = chunk_manager.get_chunk(cx)
		if c == null:
			continue
		var chunk_start: int = cx * CHUNK_WIDTH
		for lx in CHUNK_WIDTH:
			for y in HEIGHT:
				var tid: int = c.tiles[lx][y]
				# 小麦 + 稻子 都靠 tid+1 升阶 (各自 4 阶段连续编号)
				var is_wheat: bool = tid == Tiles.WHEAT_0 or tid == Tiles.WHEAT_1 or tid == Tiles.WHEAT_2
				var is_rice: bool = tid == Tiles.RICE_0 or tid == Tiles.RICE_1 or tid == Tiles.RICE_2
				if not is_wheat and not is_rice:
					continue
				if randf() > CROP_GROW_CHANCE:
					continue
				var next_id: int = tid + 1   # X_0→1→2→3 (顺序硬编码)
				_set_tile(chunk_start + lx, y, next_id)


# 自动门 tick: 玩家靠近 → 整扇门换成 DOOR_OPEN (可穿); 离开 → 换回关门.
# 只在 host/单机 跑 (调用处已 if not is_mp_client 门控); _set_tile 把开关 swap 同步给联机对方.
func _tick_doors() -> void:
	if chunk_manager == null:
		return
	var players: Array = _door_player_positions()
	if players.is_empty():
		for coord in _open_doors.keys():   # keys() 是快照, 边遍历边删安全
			_close_door_at(coord)
		return
	# 1) 开: 每个玩家附近扫关着的门底 (DOOR), 开它 (它 + 上 2 格 → DOOR_OPEN)
	for ppos in players:
		var ptx: int = int(floor(ppos.x / TILE_SIZE))
		var pfy: int = int(floor(ppos.y / TILE_SIZE))
		for dx in range(-2, 3):
			for dy in range(-3, 4):
				if chunk_manager.get_tile(ptx + dx, pfy + dy) == Tiles.DOOR:
					_open_door_at(Vector2i(ptx + dx, pfy + dy))
	# 2) 关: 已开的门, 没玩家在近处 (滞回 CLOSE_RANGE 比开范围大, 防抖) → 换回关门
	for coord in _open_doors.keys():
		var near: bool = false
		for ppos in players:
			var dxg: float = absf(ppos.x / TILE_SIZE - (float(coord.x) + 0.5))
			var dyg: float = absf(ppos.y / TILE_SIZE - float(coord.y))
			if dxg <= DOOR_CLOSE_RANGE_X and dyg <= DOOR_RANGE_Y:
				near = true
				break
		if not near:
			_close_door_at(coord)


func _door_player_positions() -> Array:
	var out: Array = []
	var lp = get_tree().get_first_node_in_group("player")
	if lp != null and is_instance_valid(lp):
		out.append(lp.global_position)
	for pid in _remote_players:
		var rp = _remote_players[pid]
		if rp != null and is_instance_valid(rp):
			out.append(rp.global_position)
	return out


# 开门: bottom 是门底 (DOOR) 坐标. 只在确实是完整关门 (底DOOR/中MID/顶TOP) 时开, 防开半截门.
func _open_door_at(bottom: Vector2i) -> void:
	if chunk_manager.get_tile(bottom.x, bottom.y) != Tiles.DOOR:
		return
	if chunk_manager.get_tile(bottom.x, bottom.y - 1) != Tiles.DOOR_MID:
		return
	if chunk_manager.get_tile(bottom.x, bottom.y - 2) != Tiles.DOOR_TOP:
		return
	_set_tile(bottom.x, bottom.y, Tiles.DOOR_OPEN)
	_set_tile(bottom.x, bottom.y - 1, Tiles.DOOR_OPEN)
	_set_tile(bottom.x, bottom.y - 2, Tiles.DOOR_OPEN)
	_open_doors[bottom] = true


# 关门: 换回 底DOOR/中MID/顶TOP. 只在 3 格还都是 DOOR_OPEN 时关 (被挖了就只清记录).
func _close_door_at(bottom: Vector2i) -> void:
	_open_doors.erase(bottom)
	if chunk_manager.get_tile(bottom.x, bottom.y) != Tiles.DOOR_OPEN:
		return
	_set_tile(bottom.x, bottom.y, Tiles.DOOR)
	_set_tile(bottom.x, bottom.y - 1, Tiles.DOOR_MID)
	_set_tile(bottom.x, bottom.y - 2, Tiles.DOOR_TOP)


# 废弃矿井守卫蜘蛛: 同款机制
var _mineshaft_chunks_spawned: Dictionary = {}   # chunk_x int → true
func spawn_mineshaft_spiders_for_chunk(chunk_x: int, spots: Array) -> void:
	if _no_mob_room():
		return   # 对战房不刷怪
	if spots.is_empty():
		return
	if _mineshaft_chunks_spawned.has(chunk_x):
		return
	_mineshaft_chunks_spawned[chunk_x] = true
	for spot in spots:
		var creature := SpiderScene.instantiate()
		creature.global_position = Vector2(
			spot.x * TILE_SIZE + TILE_SIZE / 2.0,
			spot.y * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(creature)


# 空岛哈比鸟: 同款 spot→spawn 机制 (dedup, chunk 重载不重生)
var _harpy_chunks_spawned: Dictionary = {}   # chunk_x int → true
func spawn_harpies_for_chunk(chunk_x: int, spots: Array) -> void:
	if _no_mob_room():
		return   # 对战房不刷怪
	if spots.is_empty():
		return
	if _harpy_chunks_spawned.has(chunk_x):
		return
	_harpy_chunks_spawned[chunk_x] = true
	for spot in spots:
		var creature := HarpyScene.instantiate()
		creature.global_position = Vector2(
			spot.x * TILE_SIZE + TILE_SIZE / 2.0,
			spot.y * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(creature)


# 在玩家附近地表随机刷一个 creature (slime/zombie 共用站位逻辑)
func _spawn_surface_creature(scene: PackedScene) -> Node:
	# 联机: 随机挑一个玩家(房主或加入的人)身边刷 → 怪对所有人公平, 不全挤在房主那。
	# 单机只有本地玩家, 退化成原行为。
	var players: Array = PlayersUtil.all_players(get_tree())
	if players.is_empty():
		return null
	var player: Node2D = players[randi() % players.size()]
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
		return creature
	return null


func _spawn_player() -> void:
	var player := PlayerScene.instantiate()
	var spawn_pos: Vector2 = _spawn_world_pos()
	# 保险: 大世界 spawn 找点可能落在不稳的位置, 强制清出 2 宽 × 3 高空气坑
	# 让玩家 (1×2 hitbox + 头顶 1 格余量) 永远落得下脚, 不会埋石头.
	var sp_tile_x: int = int(floor(spawn_pos.x / TILE_SIZE))
	var sp_tile_y: int = int(floor(spawn_pos.y / TILE_SIZE))
	_ensure_air_pocket(sp_tile_x, sp_tile_y)
	player.position = spawn_pos
	entities_root.add_child(player)
	camera.reparent(player)
	camera.position = Vector2.ZERO
	# 气氛效果 (萤火虫/流星/飘叶) 已删


# 清 (tx, ty) 周围 2 宽 × 3 高空气坑 (玩家 1×2 + 头顶余量). 防玩家 spawn 卡石头.
# 必须用 _set_tile (不是 chunk_manager.set_tile), 才会同时刷 terrain_layer 视觉 +
# 物理碰撞. 单调 chunk 数据会让玩家撞到看不见的"鬼石头".
func _ensure_air_pocket(tx: int, ty: int) -> void:
	if chunk_manager == null:
		return
	for dx in [-1, 0, 1]:
		for dy in [-3, -2, -1, 0]:   # 脚 ty, 头 ty-1, 余量 ty-2/-3
			var x: int = tx + dx
			var y: int = ty + dy
			if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
				continue
			var tid: int = chunk_manager.get_tile(x, y)
			if tid == Tiles.AIR or tid == Tiles.BEDROCK:
				continue
			_set_tile(x, y, Tiles.AIR)   # 同时更新 chunk + terrain_layer + 碰撞


func _spawn_world_pos() -> Vector2:
	# 玩家从地表上方 1 格出生 (而不是脚切线贴草顶), 防止物理引擎边缘情况
	# 下 is_on_floor() 不稳定. 落地只需 1 帧 (重力 900 → 0.5s 内稳).
	# 床睡过 → 用 bed_spawn_point. 没设过 (-99999 sentinel) → 用世界默认 spawn_point.
	var sp: Vector2i = bed_spawn_point if bed_spawn_point.x > -99000 else spawn_point
	return Vector2(
		sp.x * TILE_SIZE + TILE_SIZE / 2.0,
		sp.y * TILE_SIZE
	)


func respawn_player() -> void:
	var player := get_player()
	if player == null:
		return
	# 把背包所有物品掉在死亡处
	var death_pos: Vector2 = player.global_position
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	# 难度决定死亡掉落规则:
	#   0 简单: 啥都不掉 (新手友好, 死了爬起来继续)
	#   1 普通: 每堆掉 50% (向下取整), 盔甲每件 50% 几率掉
	#   2 困难: 全掉, 只留木剑/木镐/木斧 (重新做工具的成本省了)
	var difficulty: int = GameSettings.current_difficulty if GameSettings != null else 1
	var wood_kit := {"wood_sword": true, "wood_pickaxe": true, "wood_axe": true}
	# 对战房复活不掉东西 (装备留着继续打)
	var pvp: bool = NetworkManager != null and NetworkManager.combat_enabled()
	if inv_node != null and inv_node.inventory != null and difficulty > 0 and not pvp:
		var inv = inv_node.inventory
		for i in inv.slots.size():
			var s = inv.slots[i]
			if s == null:
				continue
			if difficulty == 2:
				# 困难: 木剑/木镐/木斧 保留, 其余全掉
				if wood_kit.has(s.item_id):
					continue
				_spawn_death_drop(s.item_id, s.count, death_pos)
				inv.slots[i] = null
			else:
				# 普通: 一堆掉一半 (向下取整, 5 件 → 掉 2 留 3, 1 件 → 全留)
				var drop_count: int = int(s.count) / 2
				if drop_count <= 0:
					continue
				_spawn_death_drop(s.item_id, drop_count, death_pos)
				s.count = int(s.count) - drop_count
				if s.count <= 0:
					inv.slots[i] = null
		# 盔甲掉落:
		#   普通: 每件 50% 几率掉
		#   困难: 全掉 (木头三件套是工具, 盔甲不算)
		if inv_node.has_method("get_armor") and inv_node.has_method("set_armor"):
			for slot_kind in ["helmet", "chest", "pants"]:
				var armor = inv_node.get_armor(slot_kind)
				if armor == null:
					continue
				var should_drop: bool = (difficulty == 2) or (difficulty == 1 and randf() < 0.5)
				if should_drop:
					_spawn_death_drop(armor.item_id, 1, death_pos)
					inv_node.set_armor(slot_kind, null)
		# 鼠标拖动中的 cursor_slot 也按难度掉 (老 bug: 不处理 → 物品永久卡在 cursor_slot 浮空中)
		if "cursor_slot" in inv_node and inv_node.cursor_slot != null:
			var cs = inv_node.cursor_slot
			if difficulty == 2:
				# 困难: 不在木套里就全掉
				if not wood_kit.has(cs.item_id):
					_spawn_death_drop(cs.item_id, cs.count, death_pos)
					inv_node.cursor_slot = null
			else:
				# 普通: 一半
				var cs_drop: int = int(cs.count) / 2
				if cs_drop > 0:
					_spawn_death_drop(cs.item_id, cs_drop, death_pos)
					cs.count = int(cs.count) - cs_drop
					if cs.count <= 0:
						inv_node.cursor_slot = null
		if inv_node.has_signal("inventory_changed"):
			inv_node.inventory_changed.emit()
	# 清掉地图上所有 slime (防止复活时聚一堆)
	for s in get_tree().get_nodes_in_group("slimes"):
		# Boss 在 "slimes" 组里, 但有自己的远离消失逻辑, 别在这儿误删 (会跳过掉落)
		if s.is_in_group("boss"):
			continue
		s.queue_free()
	# 重置 spawn timer, 给玩家几秒缓冲再开始刷新
	_slime_spawn_timer = 5.0
	# 传送回出生点 + 满血 + 满魔 (老 bug: mana 不回, 持法杖死了复活就发不出火球)
	# 对战房: 随机出生点 (各次不同, 防蹲点 + 出生不重叠); 否则回世界出生点。
	player.global_position = PvpArena.random_spawn() if pvp else _spawn_world_pos()
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_method("revive_full"):
		hp.revive_full()
	var mn: Node = player.get_node_or_null("PlayerMana")
	if mn != null and mn.has_method("refill_full"):
		mn.refill_full()
	# 床睡着死了 → 复活点就是床位置 → 8px 移动检测不到 → 卡 10x 时间循环.
	# 复活时强制 wake (无论是否在睡都安全, _sleeping=false 是幂等).
	_wake_up()


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


# 从存档还原 item_drop 节点 (load 路径). main.gd _apply_save_data 调用.
# 老 bug: save_manager 把死亡掉落写进 data.entities 但没人读 → 存档 reload 全消失.
func restore_entities_from_save(entities_arr: Array) -> void:
	# 清掉默认 worldgen 可能已经放的 drop (避免叠加)
	for d in get_tree().get_nodes_in_group("item_drops"):
		d.queue_free()
	for e in entities_arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if e.get("type", "") != "item_drop":
			continue
		var iid: String = String(e.get("item_id", ""))
		if iid == "":
			continue
		var drop = ItemDropScene.instantiate()
		drop.item_id = iid
		drop.count = int(e.get("count", 1))
		drop.global_position = e.get("pos", Vector2.ZERO)
		entities_root.add_child(drop)


var _cached_player: CharacterBody2D = null  # get_player() 每帧调, 缓存避免遍历 entities_root


func get_player() -> CharacterBody2D:
	# 缓存命中 + 还活着 → 直接返
	if _cached_player != null and is_instance_valid(_cached_player) and not _cached_player.is_queued_for_deletion():
		return _cached_player
	# 用 "player" group 一步定位, 不再遍历 entities_root (老 bug: 每帧 O(N))
	var p = get_tree().get_first_node_in_group("player")
	if p is CharacterBody2D:
		_cached_player = p
		return _cached_player
	# 兜底: 只认"真玩家"= 带 PlayerInventory 子节点的 CharacterBody2D (只有玩家有).
	# 不能抓任意 CharacterBody2D —— 哈比鸟/史莱姆等怪也是 CharacterBody2D, 且空岛 chunk 一加载
	# 就先于玩家刷进 entities_root. 加载窗口期玩家还没 add_to_group("player") 时, 旧兜底会把
	# 第一个怪当玩家缓存住 → HUD/小地图/背景/背包全绑到怪身上 (丢三件套 + 地图/背景显示地底).
	# 这是用户反复报"进世界 bug"的真根因. 怪没 PlayerInventory → 跳过, 找不到就返 null (调用方自会重试).
	for child in entities_root.get_children():
		if child is CharacterBody2D and child.has_node("PlayerInventory"):
			_cached_player = child
			return child
	return null


func get_crack_overlay() -> Node:
	return $CrackOverlay


func _set_tile(x: int, y: int, tile_id: int, from_remote: bool = false, skip_sand: bool = false) -> void:
	# skip_sand=true 防止沙子物理递归 (沙下落时不再触发它自己)
	# from_remote=true 时不再广播 (避免循环). 本地玩家挖/放 → 广播给联机对方
	# 玩家挖/放 → 广播给同房间的人 (对战房也广播 = 看得到彼此搭的方块, 用户改).
	# 但竞技场地基 (PvpArena.build 几万格) 不广播: _arena_building 期间跳过, 各端本地自己铺 (防洪水)。
	if not from_remote and NetworkManager != null and NetworkManager.connected() \
			and not _arena_building:
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
	# 小地图实时更新: 挖/放方块立刻刷新这格的地图色 (已探索的才刷, 不揭迷雾)
	if minimap_data != null:
		minimap_data.update_if_explored(x, y, tile_id)
	# 沙子物理: 这格变 AIR → 上方 SAND 整柱下落
	if tile_id == Tiles.AIR and not skip_sand:
		_apply_sand_fall(x, y)


# 改背景墙 (锤子砸墙 / 放墙). 更新 chunk_manager 墙数据 (含 wall delta 存档) +
# wall_layer 视觉 + 邻居 autotile. 墙无碰撞, 不动 terrain/光照/流水.
func _set_wall(x: int, y: int, wid: int) -> void:
	const Autotile = preload("res://scripts/world/autotile.gd")
	const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	chunk_manager.set_wall(x, y, wid)
	var pos := Vector2i(x, y)
	if wid == Tiles.AIR:
		wall_layer.erase_cell(pos)
	elif EdgeTemplates.FAMILY_OF.has(wid):
		var wq := Autotile.make_wall_query(wid, chunk_manager)
		Autotile.refresh_tile(wall_layer, pos, wid, wq)
	else:
		wall_layer.set_cell(pos, wid, Vector2i.ZERO)
	# 刷 8 邻居 (它们的 autotile 边缘 mask 可能因这格变化)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var npos: Vector2i = pos + Vector2i(dx, dy)
			var nsid: int = wall_layer.get_cell_source_id(npos)
			if nsid != -1 and EdgeTemplates.FAMILY_OF.has(nsid):
				var nq := Autotile.make_wall_query(nsid, chunk_manager)
				Autotile.refresh_tile(wall_layer, npos, nsid, nq)


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


# water_sim 调: 水正在重力下落穿过空格 (x,y). 画一道下落水视觉, 短时残留 → 连续瀑布连成水帘.
# 纯画面: 不进 chunk 数据 / 不动物理 / 不联机 (host 本地够用, client 看真实 tile).
func note_falling_water(x: int, y: int, tid: int) -> void:
	if _falling_layer == null:
		return
	var cell := Vector2i(x, y)
	if not _falling.has(cell):
		_falling_layer.set_cell(cell, _display_water_tile(x, tid), Vector2i.ZERO)
	_falling[cell] = _FALLING_VIS_SEC


# 每帧淡出下落水: 没再被流过 (超时) 或该格已被实体水/方块占了 → 清掉视觉.
func _sweep_falling_water(delta: float) -> void:
	if _falling.is_empty() or _falling_layer == null:
		return
	var done: Array = []
	for cell in _falling:
		_falling[cell] -= delta
		var occupied: bool = chunk_manager != null and chunk_manager.get_tile(cell.x, cell.y) != Tiles.AIR
		if _falling[cell] <= 0.0 or occupied:
			_falling_layer.set_cell(cell, -1)
			done.append(cell)
	for cell in done:
		_falling.erase(cell)


# 水专用 fast path: 跳过 autotile/darkness/lighting/cactus/sky 等水改不影响的子系统.
# water_sim 每 tick 调几百次, 走完整 _set_tile 会卡帧 (darkness recompute 17x17 × 数百次).
# 联机: host 改水时广播给 client; client 收到通过 _on_remote_tile 走完整 _set_tile.
# 数据里存普通水 stored_id; 画到屏幕前按列查群系换成彩色 visual id。
# 彩色 id 只进 terrain_layer (画面), 绝不回写 chunk_manager (数据保持普通水)。
func _display_water_tile(x: int, stored_id: int) -> int:
	if Tiles.water_level(stored_id) <= 0:
		return stored_id   # 不是水, 原样 (省一次 biome 查询)
	var full: int = WorldGenerator._biome_water_tile(WorldGenerator._biome_at(x, world_seed))
	return Tiles.display_water_tile(stored_id, full)


func _set_water_tile_fast(x: int, y: int, tile_id: int, from_remote: bool = false) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	# 水下植物总闸: 写水前若该格是可淹植物 → 记进 _submerged; 写空气前若底下记着植物 → 改写回植物。
	# 只认 is_water (岩浆不记 → 岩浆碰植物维持现状)。覆盖所有水写入/退水路径 (都过这一个闸)。
	if Tiles.is_water(tile_id):
		var existing: int = chunk_manager.get_tile(x, y)
		if Tiles.is_submersible_plant(existing):
			chunk_manager.set_submerged(x, y, existing)
	elif tile_id == Tiles.AIR:
		var plant: int = chunk_manager.get_submerged(x, y)
		if plant != -1:
			tile_id = plant
			chunk_manager.clear_submerged(x, y)
	chunk_manager.set_tile(x, y, tile_id)
	var pos := Vector2i(x, y)
	if tile_id == Tiles.AIR:
		terrain_layer.set_cell(pos, -1)
	else:
		terrain_layer.set_cell(pos, _display_water_tile(x, tile_id), Vector2i.ZERO)
	# host 广播给 client (但不接收方再回播, 避免回声). 批量模式累积到 buf
	# 对战房也广播 (看得到彼此); 但竞技场地基期间 (_arena_building) 不广播 (防洪水)。
	if not from_remote and NetworkManager != null and NetworkManager.connected() \
			and not _arena_building:
		if _tile_batching:
			_tile_batch.append(x); _tile_batch.append(y); _tile_batch.append(tile_id)
		else:
			NetworkManager.send_tile_change(x, y, tile_id)
	if water_sim != null:
		water_sim.notify_tile_changed(x, y)
	# 小地图实时更新: 水流改了这格也立刻刷新地图色 (已探索的才刷)
	if minimap_data != null:
		minimap_data.update_if_explored(x, y, tile_id)
