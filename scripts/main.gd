# 游戏根 + 状态机。
# 状态: "menu" (主菜单显示中) / "game" (世界 + HUD + 面板存在)。
# 启动进 menu。MainMenu 点新游戏 → game。暂停菜单点回主菜单 → menu。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")
const CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")
const ChestPanelScene = preload("res://scenes/ui/chest_panel.tscn")
const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")
const ChatBoxScript = preload("res://scripts/ui/chat_box.gd")   # 联机聊天框 (无 tscn, 纯代码 CanvasLayer)
const PvpScoreboardScript = preload("res://scripts/ui/pvp_scoreboard.gd")   # PvP 击杀榜 (只对战房显示)
const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")
const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")
const LoadPlanner = preload("res://scripts/world/load_planner.gd")
const _ChunkClass = preload("res://scripts/world/chunk.gd")   # 读档后算玩家落点 chunk_x 用

@onready var _main_menu: CanvasLayer = $MainMenu
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _death_screen: CanvasLayer = $DeathScreen

var _state: String = "menu"
var _game_nodes: Array[Node] = []
# 自动存档: 每 AUTO_SAVE_INTERVAL 秒保存一次. 玩游戏时启动 Timer.
const AUTO_SAVE_INTERVAL := 1.0   # 每秒自动存档 (用户要求实时, 不再 30s)
var _autosave_timer: Timer = null
# Continue 路径: _continue_game 把 SaveData 暂存这, 等 _run_async_load 全部加载完才应用.
# 老代码用 .call_deferred 在 _run_async_load 第一个 await 就触发,
# 那时 world.chunk_manager 还是 null, 应用就崩了 (玩家/背包/方块全没还原).
var _pending_save_data: Resource = null
var _want_starter: bool = false   # 本局是否该发起步包 (新游戏 true, 继续游戏 false). 一次性, 发完置 false.
var _last_attacker_pid: String = ""   # PvP: 最近把我打掉血的人 (死了算他击杀)

var world: Node2D:
	get:
		return get_node_or_null("World")


func _ready() -> void:
	# 启动即给全局 RNG 重新播种 (按系统时间). 桌面版会自动随机化, 但网页(HTML5)
	# 导出后不会 → 每次打开网页 randi() 从同一起点 → 新世界种子永远一样。
	# 显式 randomize() 让桌面 + 网页都每次不同。
	randomize()
	_main_menu.start_game.connect(_start_game)
	_main_menu.continue_game.connect(_continue_game)
	_pause_menu.return_to_menu.connect(_return_to_menu)
	_death_screen.respawn.connect(_on_respawn)
	# PvP: 被别人打 → 在自己这端扣自己的血 (各管各血)
	if NetworkManager != null and NetworkManager.has_signal("player_damaged"):
		NetworkManager.player_damaged.connect(_on_player_damaged)
	_show_menu_state()


func _show_menu_state() -> void:
	_state = "menu"
	# 主菜单永远放自己的音乐(day), 不被刚才游戏里的夜/洞穴音乐带跑.
	# (游戏里 player_controller 会按昼夜/洞穴切 context; 回菜单要复位, 否则菜单还放着洞穴 drone)
	MusicBank.set_context("day")
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.visible = true
		# 复位"新游戏"按钮的淡出 tween (不然回主菜单是黑屏 + 看不见按钮)
		if _main_menu.has_method("reset_visuals"):
			_main_menu.reset_visuals()
	_pause_menu.close()
	_death_screen.hide_death()


func _start_game(seed_or_opts = 0) -> void:
	# 主菜单 "开始游戏" → 走 LoadingScreen 异步加载流程.
	# - opts (Dictionary): 主菜单新游戏面板传 {world_seed, world_name, difficulty}
	# - seed (int): 仅老 API 兼容 (boot_to_game 不走这里; 走 _start_game_sync)
	var world_seed: int = 0
	var world_name: String = ""
	var difficulty: int = 1
	var world_size: int = 1   # 0=小 1=中 2=大
	var creative_mode: bool = false
	if seed_or_opts is Dictionary:
		var opts: Dictionary = seed_or_opts
		world_seed = int(opts.get("world_seed", 0))
		world_name = String(opts.get("world_name", ""))
		difficulty = int(opts.get("difficulty", 1))
		world_size = int(opts.get("world_size", 1))
		creative_mode = bool(opts.get("creative_mode", false))
	else:
		world_seed = int(seed_or_opts)
	if "current_difficulty" in GameSettings:
		GameSettings.current_difficulty = difficulty
	if "current_world_name" in GameSettings:
		GameSettings.current_world_name = world_name
	if "current_world_size" in GameSettings:
		GameSettings.current_world_size = world_size
	GameSettings.creative_mode = creative_mode   # 新建=按选择(默认生存); 读档=存档里的值
	# 角色系统: 保证有选中角色 (计划 3 的选角色 UI 上线前由 ensure_current 兜底),
	# 并用角色名当玩家名 (联机/UI/死亡画面显示)。
	# GUT 测试环境跳过 (照 autosave 同款 _running_under_gut 门控): current 是 autoload 跨测试残留,
	# 测试里若 ensure_current 设了 current 会污染"新游戏发起步包"等现有测试。真实游戏照常。
	if not _running_under_gut() and typeof(CharacterManager) != TYPE_NIL:
		CharacterManager.ensure_current()
		if CharacterManager.current != null:
			# 选角色 UI 还没上线 → 设置里的"玩家名"是唯一改名入口, 让它说了算。
			# 把它写进当前角色存档; 否则下次进游戏角色里的旧名字会把它盖回去 (= 改名不生效 bug)。
			var chosen: String = GameSettings.player_name
			if chosen != "" and CharacterManager.current.character_name != chosen:
				CharacterManager.current.character_name = chosen
				CharacterManager.save_character(CharacterManager.current)
	# 是否新游戏 (非继续): 决定发不发起步包 (此刻判, 因为 _pending_save_data 稍后会被清).
	_want_starter = (_pending_save_data == null)
	# 新游戏重置昼夜到早晨; 继续游戏稍后由 _apply_save_data 还原存档时间.
	# TimeOfDay 是全局 autoload, 不重置的话新世界会沿用上一个世界的时间 → 不同存档时间串.
	if _pending_save_data == null and TimeOfDay != null and "time" in TimeOfDay:
		TimeOfDay.time = 0.35
	_state = "game"
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.visible = false
	_run_async_load(world_seed)


# 异步加载: instantiate LoadingScreen → 一步步推进 7 个阶段 → 淡出.
# 每步之间 await process_frame 让 UI 渲染 + 进度条 tween + 小人跑动 + 贴士切换
func _run_async_load(world_seed: int) -> void:
	var loading: CanvasLayer = LoadingScreenScene.instantiate()
	loading.name = "LoadingScreen"
	add_child(loading)
	await get_tree().process_frame  # 让 LoadingScreen 渲染一帧

	# Step A (5%): World instantiate (defer_init=true, _ready 不跑初始化)
	loading.set_progress(0.05, "正在准备世界...")
	var w = WorldScene.instantiate()
	w.name = "World"
	w.defer_init = true
	if world_seed != 0:
		w.world_seed = world_seed
	add_child(w)
	_game_nodes.append(w)
	await get_tree().process_frame

	# Step B-E (20% / 40% / 60% / 75%): world.run_init_step(0..3)
	var step_count: int = w.get_init_step_count()
	var step_pcts: PackedFloat32Array = [0.20, 0.40, 0.60, 0.75]
	for i in step_count:
		loading.set_progress(step_pcts[i], w.get_init_step_label(i))
		w.run_init_step(i)
		await get_tree().process_frame

	# Step F (90%): HUD + 其他 UI 面板
	loading.set_progress(0.90, "正在准备界面...")
	var hud = HudScene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	_game_nodes.append(hud)
	_add_touch_controls_if_mobile()
	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)
	var chat_box = ChatBoxScript.new()
	chat_box.name = "ChatBox"
	add_child(chat_box)
	_game_nodes.append(chat_box)
	var scoreboard = PvpScoreboardScript.new()
	scoreboard.name = "PvpScoreboard"
	add_child(scoreboard)
	_game_nodes.append(scoreboard)
	var chest = ChestPanelScene.instantiate()
	chest.name = "ChestPanel"
	add_child(chest)
	_game_nodes.append(chest)
	var floating = FloatingPromptScene.instantiate()
	floating.add_to_group("floating_prompt")
	add_child(floating)
	_game_nodes.append(floating)
	var debug = DebugHudScene.instantiate()
	add_child(debug)
	_game_nodes.append(debug)
	var dialogue = DialogueBoxScene.instantiate()
	add_child(dialogue)
	_game_nodes.append(dialogue)
	_wire_player.call_deferred()
	_grant_starter_on_new_game.call_deferred()
	await get_tree().process_frame

	# 自适应预载 (仅新游戏): 测设备速度 → 按速度/平台/核数定半径 → 分帧把出生点一大片先生成好.
	# continue (读档) 不动: 保持默认半径, 不碰延迟敏感的读档路径 (玩家稍后瞬移到存档位置).
	if _pending_save_data == null:
		var cm = w.chunk_manager
		loading.set_progress(0.90, "正在测速...")
		var t0: int = Time.get_ticks_msec()
		# 基准: 生成出生点两侧 8 个新 chunk (这些也是真要预载的, 不浪费)
		for bcx in [3, 4, 5, 6, -3, -4, -5, -6]:
			cm.load_one(bcx)
		var per: float = float(Time.get_ticks_msec() - t0) / 8.0
		cm.view_radius = LoadPlanner.plan_view_radius(per, OS.has_feature("web"), OS.get_processor_count())
		# 分帧预载 ±view_radius (跳过已载的), 进度 0.90 → 0.98
		var r: int = cm.view_radius
		var total: int = 2 * r + 1
		var done: int = 0
		for cx in range(-r, r + 1):
			cm.load_one(cx)
			done += 1
			if done % 3 == 0:
				loading.set_progress(0.90 + 0.08 * float(done) / float(total), "正在预生成世界 (%d/%d)..." % [done, total])
				await get_tree().process_frame

	# 100%: 完成 + 0.5s 淡出 → queue_free LoadingScreen
	loading.set_progress(1.0, "进入世界!")
	loading.finish_and_fade()
	await loading.finished
	loading.queue_free()
	# Continue 路径: 世界全部初始化完才应用存档 (chunk_manager / player 都就绪).
	# 必须在这, 不能在 _continue_game 里 call_deferred — 那会在第一个 await 就触发.
	if _pending_save_data != null:
		_apply_save_data(_pending_save_data)
		_pending_save_data = null
	# autosave 推迟到这里才启动 (不在前面 Step F): 否则 continue 路径 autosave 可能赶在
	# _apply_save_data 恢复背包之前 fire, 把"空背包"写盘覆盖好档 → 下次读档丢三件套.
	# 现在玩家 + 背包都就绪了再开自动存档.
	_start_autosave()


# 同步路径: 测试 + boot_to_game 用. 不走 LoadingScreen, World defer_init=false 自动跑完
func _start_game_sync(world_seed: int) -> void:
	GameSettings.creative_mode = false   # boot/测试默认生存 (测试要创造自己设)
	# 角色系统: 同 _start_game, 兜底选中角色。GUT 测试跳过 (防 current 跨测试污染)。
	if not _running_under_gut() and typeof(CharacterManager) != TYPE_NIL:
		CharacterManager.ensure_current()
	var w = WorldScene.instantiate()
	w.name = "World"
	if world_seed != 0:
		w.world_seed = world_seed
	add_child(w)
	_game_nodes.append(w)
	var hud = HudScene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	_game_nodes.append(hud)
	_add_touch_controls_if_mobile()
	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)
	var chat_box = ChatBoxScript.new()
	chat_box.name = "ChatBox"
	add_child(chat_box)
	_game_nodes.append(chat_box)
	var scoreboard = PvpScoreboardScript.new()
	scoreboard.name = "PvpScoreboard"
	add_child(scoreboard)
	_game_nodes.append(scoreboard)
	var chest = ChestPanelScene.instantiate()
	chest.name = "ChestPanel"
	add_child(chest)
	_game_nodes.append(chest)
	var floating = FloatingPromptScene.instantiate()
	floating.add_to_group("floating_prompt")
	add_child(floating)
	_game_nodes.append(floating)
	var debug = DebugHudScene.instantiate()
	add_child(debug)
	_game_nodes.append(debug)
	var dialogue = DialogueBoxScene.instantiate()
	add_child(dialogue)
	_game_nodes.append(dialogue)
	_wire_player.call_deferred()
	# 同步路径 (boot_to_game, 仅测试/dev 用) 不发起步包 — 让测试用空背包独立 setup
	# (之前在这发, 会让"空手挖矿"等测试的玩家拿到木镐而误挖, 测试挂). 真实新游戏走异步才发.
	_start_autosave()


# 实时存档: 每 AUTO_SAVE_INTERVAL 秒自动保存. 进游戏时启动 Timer.
func _start_autosave() -> void:
	# GUT 测试环境不开自动存档: 全量回归里十几个 booting-game 测试各带一个 1s 定时存档,
	# 会跟 test_save_* 抢存档文件 → 偶发 chunk0 丢 / 存档计数对不上. 真实游戏+网页版照常.
	if _running_under_gut():
		return
	if _autosave_timer != null:
		return
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTO_SAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(func():
		if _state == "game":
			_save_all()
	)
	add_child(_autosave_timer)


func _stop_autosave() -> void:
	if _autosave_timer != null:
		_autosave_timer.queue_free()
		_autosave_timer = null


# 存世界 + 存当前角色卡 (玩家状态)。autosave / 退出 / F5 都走这。
# 复用 CharacterManager.save_current_from_player 的就绪护栏 (inventory 未就绪不写, 防丢三件套)。
func _save_all() -> void:
	SaveManager.save(self)
	# GUT 测试跳过角色存 (防 _return_to_menu 把物品灌进残留 current 污染后续测试)。
	if not _running_under_gut() and typeof(CharacterManager) != TYPE_NIL and CharacterManager.current != null:
		var w = world
		if w != null:
			var player = w.get_player()
			if player != null:
				CharacterManager.save_current_from_player(player)


# 是否在 GUT 测试里跑 (命令行带 gut_cmdln.gd). 测试里关掉抢文件的自动存档.
func _running_under_gut() -> bool:
	for a in OS.get_cmdline_args():
		if a.contains("gut_cmdln"):
			return true
	return false


# 走"继续" 路径: 用存档 seed 启 world + 还原玩家/背包/方块改动
func _continue_game(data: Resource) -> void:
	if data == null:
		return
	# 暂存存档 — _run_async_load 把世界全部初始化完才应用 (不能 call_deferred,
	# 那会在第一个 await 触发, 那时 chunk_manager 还没建).
	_pending_save_data = data
	# 走 opts 路径 → world_seed + 还原 world_name/difficulty 到 GameSettings
	_start_game({
		"world_seed": int(data.world_seed),
		"world_name": String(data.world_name) if "world_name" in data else "",
		"difficulty": int(data.difficulty) if "difficulty" in data else 1,
		"world_size": int(data.world_size) if "world_size" in data else 1,
		"creative_mode": bool(data.creative_mode) if "creative_mode" in data else false,
	})


func _apply_save_data(data: Resource) -> void:
	const SaveManager = preload("res://scripts/save/save_manager.gd")
	var w := world
	if w == null:
		return
	# 还原世界时间 (昼夜) - 不然 reload 总回早晨
	if "world_time" in data and TimeOfDay != null and "time" in TimeOfDay:
		TimeOfDay.time = float(data.world_time)
	# 床复活点 (老存档没字段则保持默认 -99999 = 无床)
	if "bed_spawn_point" in data and "bed_spawn_point" in w:
		w.bed_spawn_point = data.bed_spawn_point
	# 恢复玩家挖/放的 chunk 改动 (写 _deltas, 之后 chunk 加载时会应用)
	SaveManager.apply_chunk_deltas(w.chunk_manager, data.chunk_deltas)
	# 恢复玩家砸/放的背景墙 (老存档没字段则跳过)
	if "wall_deltas" in data:
		SaveManager.apply_wall_deltas(w.chunk_manager, data.wall_deltas)
	# 恢复水下植物记录 (老存档没字段则跳过)
	if "submerged_plants" in data:
		SaveManager.apply_submerged(w.chunk_manager, data.submerged_plants)
	# 恢复生命水晶世界限计数 + 已处理 chunk 列表 + 位置 (防 chunk 重载又 cap)
	if data.version >= 2 and w.chunk_manager != null:
		w.chunk_manager.life_crystals_spawned = data.life_crystals_spawned
		for cx in data.processed_chunks:
			w.chunk_manager.processed_chunks[int(cx)] = true
		# positions 扁平存还原: [x0,y0, x1,y1, ...]
		# 先清: 首批 chunk 加载时 _cap 已 append 过, 不清会双填 → 列表过长 → 间距误判 → 水晶越刷越少
		w.chunk_manager.life_crystal_positions.clear()
		var pos_arr: PackedInt32Array = data.life_crystal_positions
		var i: int = 0
		while i + 1 < pos_arr.size():
			w.chunk_manager.life_crystal_positions.append(Vector2i(pos_arr[i], pos_arr[i + 1]))
			i += 2
		# 同款: 魔力水晶 (老存档没字段则跳过)
		if "mana_crystals_spawned" in data:
			w.chunk_manager.mana_crystals_spawned = data.mana_crystals_spawned
		if "mana_crystal_positions" in data:
			w.chunk_manager.mana_crystal_positions.clear()   # 同上, 先清防双填
			var mc_pos: PackedInt32Array = data.mana_crystal_positions
			var j: int = 0
			while j + 1 < mc_pos.size():
				w.chunk_manager.mana_crystal_positions.append(Vector2i(mc_pos[j], mc_pos[j + 1]))
				j += 2
		# 已 spawn 守卫木乃伊的金字塔 chunk_x: 防杀完木乃伊存档重读后复活
		if "pyramid_chunks_spawned" in data and "_pyramid_chunks_spawned" in w:
			for cx in data.pyramid_chunks_spawned:
				w._pyramid_chunks_spawned[int(cx)] = true
		# 世纪树已删 (用户要求), 老存档的 world_tree_chunks_spawned 字段忽略
		# 同款: 已 spawn 废弃矿井蜘蛛的 chunk_x
		if "mineshaft_chunks_spawned" in data and "_mineshaft_chunks_spawned" in w:
			for cx in data.mineshaft_chunks_spawned:
				w._mineshaft_chunks_spawned[int(cx)] = true
	# 恢复箱子内容 (24 格 × 每个 chest tile)
	if "chest_contents" in data:
		ChestStorage.restore(data.chest_contents)
	# 把已经加载的 chunk 也重新刷一遍 tile 视觉 — 简单做法: 让 chunk_manager 重载
	# 否则玩家挖过的方块在 load 时不会显示
	for cx_key in data.chunk_deltas.keys():
		# key 是 String (.tres 存档会丢整数 key 0 = 出生点区块, 故序列化用 str). get_chunk 要 int.
		var cx: int = int(cx_key)
		var ch = w.chunk_manager.get_chunk(cx)
		if ch != null:
			# 应用 delta 到 chunk.tiles
			var arr: PackedInt32Array = data.chunk_deltas[cx_key]
			var i: int = 0
			while i + 2 < arr.size():
				ch.set_tile(arr[i], arr[i + 1], arr[i + 2])
				i += 3
			# 触发 chunk_loaded 重画视觉 (不然 TileMapLayer 还是旧的)
			w._on_chunk_loaded(ch)
	# 移玩家 + 还原血量/背包
	var player: Node2D = w.get_player()
	if player == null:
		return
	# 验证保存的位置不是在石头里 (老坏存档救出: 大世界 bug 时玩家被埋深石里, 那时存的
	# player_position 还是 [0, 1200], reload 又卡进去). tile 实心 → fallback 用世界 spawn.
	var saved_pos: Vector2 = data.player_position
	var pos_tx: int = int(floor(saved_pos.x / 12.0))
	var pos_ty: int = int(floor(saved_pos.y / 12.0))
	var pos_tid: int = w.chunk_manager.get_tile(pos_tx, pos_ty) if w.chunk_manager != null else 0
	if pos_tid != 0 and Tiles.is_solid(pos_tid):
		push_warning("存档玩家位置在实心 tile 里, 用 spawn 救出")
		player.global_position = w._spawn_world_pos()
		# 也清个空气坑防再次卡
		if w.has_method("_ensure_air_pocket"):
			w._ensure_air_pocket(int(floor(player.global_position.x / 12.0)),
					int(floor(player.global_position.y / 12.0)))
	else:
		player.global_position = saved_pos
	# 玩家瞬移到存档位置后立刻同步加载落点 chunk: 否则这一帧 ScenicDirector 查不到地表(背景误显地底)
	# + minimap 把那片当 AIR(显地底). ensure_loaded 是同步的, 当帧就有 surfaces/tile 数据.
	if w.chunk_manager != null:
		w.chunk_manager.ensure_loaded(_ChunkClass.chunk_x_of(int(floor(player.global_position.x / 12.0))))
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and "current_health" in hp:
		# v0 → v1: 老存档 player_hp 0-20 刻度, ×5 缩放到 0-100.
		# v1 → v2: 加 player_max_hp 永久上限 (吃水晶涨过的). 老存档没该字段 = BASE.
		var loaded_hp: float = data.player_hp
		if data.version < 1:
			loaded_hp = loaded_hp * 5.0
		# 先还原永久上限 (才知道 clamp 边界)
		if data.version >= 2 and "MAX_HEALTH" in hp:
			hp.MAX_HEALTH = clamp(data.player_max_hp, hp.BASE_MAX_HEALTH, hp.MAX_HEALTH_CAP)
		hp.current_health = clamp(int(loaded_hp), 0, hp.MAX_HEALTH)
		if hp.has_signal("health_changed"):
			hp.health_changed.emit(hp.current_health, hp.MAX_HEALTH)
	# 魔力还原 (存档无字段则保持默认 100/100)
	var mn: Node = player.get_node_or_null("PlayerMana")
	if mn != null and "current_mana" in mn and "player_mana" in data:
		if "MAX_MANA" in mn and "player_max_mana" in data:
			mn.MAX_MANA = int(data.player_max_mana)
		mn.current_mana = clamp(int(data.player_mana), 0, mn.MAX_MANA)
		if mn.has_signal("mana_changed"):
			mn.mana_changed.emit(mn.current_mana, mn.MAX_MANA)
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node != null and inv_node.inventory != null:
		inv_node.inventory.slots = data.inventory_slots.duplicate()
		if "hotbar_selected" in inv_node:
			inv_node.hotbar_selected = data.hotbar_selection
		if inv_node.has_signal("inventory_changed"):
			inv_node.inventory_changed.emit()
		if inv_node.has_signal("hotbar_selection_changed"):
			inv_node.hotbar_selection_changed.emit(data.hotbar_selection)
		# 盔甲槽 (v3): 还原 3 件装备. 老存档没该字段 → 默认 "" 跳过.
		if data.version >= 3 and inv_node.has_method("set_armor"):
			for pair in [["helmet", data.armor_helmet_id], ["chest", data.armor_chest_id], ["pants", data.armor_pants_id]]:
				var slot_kind: String = pair[0]
				var item_id: String = pair[1]
				if item_id != "":
					inv_node.set_armor(slot_kind, {"item_id": item_id, "count": 1})
		# 救命: 加载完背包是空的 → 重新发起步包 (大世界 spawn bug 时存的空背包, 老坏存档救回来).
		# 也覆盖盔甲全空: 死亡时该掉的都掉了, 给点工具继续玩.
		var all_empty: bool = true
		for s in inv_node.inventory.slots:
			if s != null:
				all_empty = false
				break
		if all_empty:
			push_warning("加载后背包全空 → 重新发起步包")
			inv_node.pickup("wood_pickaxe", 1)
			inv_node.pickup("wood_axe", 1)
			inv_node.pickup("wood_sword", 1)
			if inv_node.has_signal("inventory_changed"):
				inv_node.inventory_changed.emit()
	# 角色系统: 玩家状态 (血量/魔力/背包/盔甲) 权威来源 = 当前角色卡, 覆盖上面从世界存档
	# 还原的那套 (跨世界带背包)。位置仍用世界存档/spawn (上面已处理), 不被覆盖。
	# GUT 测试跳过 (current 残留会覆盖 test_continue 期望的世界存档背包)。
	if not _running_under_gut() and typeof(CharacterManager) != TYPE_NIL and CharacterManager.current != null:
		CharacterManager.apply_to_player(player)
	# 还原死亡掉落 (老 bug: save_manager 写了但 load 没读, 导致死亡掉落 reload 后消失,
	# 违背 Minecraft 风设定 — 死亡处该有的箱子开锁箱必须在那里).
	if "entities" in data and w.has_method("restore_entities_from_save"):
		w.restore_entities_from_save(data.entities)


# 测试用 helper: 同步切到 game 状态, 不走 LoadingScreen.
# 顺便 queue_free MainMenu. 默认固定 seed=42 让测试可重复.
# 生产路径走 _main_menu.start_game 信号 → _start_game() async 流程.
# 触屏 UI: 仅手机/平板浏览器显示. main.tscn 加进游戏 nodes 列表方便 _return_to_menu 清理.
# 用 call_deferred 包裹: 即使 TouchControls _ready 抛错也不阻塞主 loading 流程 (用户反馈手机卡 loading).
func _add_touch_controls_if_mobile() -> void:
	if not TouchControlsScript.should_show():
		return
	_add_touch_controls_deferred.call_deferred()


func _add_touch_controls_deferred() -> void:
	# 容错: TouchControls 创建/初始化任何环节出错都不影响游戏主流程
	if TouchControlsScript == null:
		push_warning("TouchControls 脚本未加载, 跳过触屏 UI")
		return
	var touch: CanvasLayer = TouchControlsScript.new()
	if touch == null:
		push_warning("TouchControls.new() 返回 null, 跳过触屏 UI")
		return
	touch.name = "TouchControls"
	add_child(touch)
	_game_nodes.append(touch)


func boot_to_game(world_seed: int = 42) -> void:
	if _state == "game":
		return
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.queue_free()
		_main_menu = null
	_state = "game"
	_start_game_sync(world_seed)


func _wire_player() -> void:
	var w := world
	if w == null:
		return
	var player: Node2D = w.get_player()
	if player == null:
		return
	for child in _game_nodes:
		if child.has_method("bind_player"):
			child.bind_player(player)
		if child.has_method("bind_inventory"):
			child.bind_inventory(player.get_node("PlayerInventory"))
		if child.has_method("set_player"):
			child.set_player(player)
	# 死亡信号 → 死亡屏
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("died"):
		if not hp.died.is_connected(_death_screen.show_death):
			hp.died.connect(_death_screen.show_death)
		# 联机: 本地玩家死了 → 通知对方 (对方那边 remote_player 变半透明"死亡")
		if not hp.died.is_connected(_notify_remote_death):
			hp.died.connect(_notify_remote_death)
		# PvP: 死了 → 记击杀给凶手 + 几秒后自动满血复活
		if not hp.died.is_connected(_on_local_death_pvp):
			hp.died.connect(_on_local_death_pvp)


# 真实新游戏 + continue 路径 (_run_async_load) 会调用这个;
# 测试 helper boot_to_game / _start_game_sync 跳过, 让测试用空背包独立 setup.
# continue 路径靠 _apply_save_data.call_deferred 在更后一帧覆盖背包, 不会留下重复.
func _grant_starter_on_new_game() -> void:
	# 只在真实新游戏发起步包. 继续游戏 _want_starter=false (存档背包由 _apply_save_data 还原).
	# _want_starter 一次性, 防 deferred 跑两次重复发.
	if not _want_starter:
		return
	# PlayerInventory._ready 创建 inventory, 可能跟我们 call_deferred 时机错位.
	# 轮询等 player + inventory 就绪再发起步包. 找到就发 + 立即 return (正常 1-3 帧就成).
	# 老版只等 8 帧 → 异步加载(LoadingScreen 几秒) + 大世界 spawn 步骤靠后时, 8 帧内玩家
	# 还没 spawn → 静默丢三件套 (用户反馈"大/小世界没三件套"). 放宽到覆盖整个加载.
	# 每次循环重新 fetch world (await 后玩家可能 ESC 回主菜单, world freed).
	const STARTER_GRANT_MAX_FRAMES := 900   # ~15s @60fps, 兜底防慢加载丢包; 找到即提前 return
	for i in STARTER_GRANT_MAX_FRAMES:
		var w := world
		if w == null or not is_instance_valid(w):
			return  # world 没了 (回主菜单), 放弃
		var player: Node2D = w.get_player()
		if player != null:
			var inv_node: Node = player.get_node_or_null("PlayerInventory")
			if inv_node != null and inv_node.inventory != null:
				_want_starter = false   # 先置, 防同帧重入
				# 角色系统: 老角色 (已有背包) 进新世界 → 带着角色的东西, 不发起步包;
				# 全新角色 (背包空) → 照常发起步包 (随后 autosave 把它存进角色卡)。
				# GUT 测试跳过 → 永远走起步包分支, 不被 current 残留影响。
				if not _running_under_gut() and typeof(CharacterManager) != TYPE_NIL \
						and CharacterManager.current != null \
						and _character_has_items(CharacterManager.current):
					CharacterManager.apply_to_player(player)
				else:
					_grant_starter_inventory(player)
				return
		await get_tree().process_frame
	push_warning("starter 没发出去: player/inventory %d 帧内没就绪" % STARTER_GRANT_MAX_FRAMES)


# 角色背包是否有东西 (任一槽非空)。用来判断是否给新世界发起步包。
func _character_has_items(c) -> bool:
	if c == null:
		return false
	for s in c.inventory_slots:
		if s != null:
			return true
	return false


func _grant_starter_inventory(player: Node) -> void:
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node == null or inv_node.inventory == null:
		return
	# 双发由调用方 _want_starter 一次性标志保证; 这里直接发. 不再"任一槽非空就跳过" —
	# 那个会被新游戏时抢先进背包的物品 / 联机消息误触发 → 玩家丢三件套.
	# 对战房 (PvP): 改发战斗装备包, 不发生存起步包
	if NetworkManager != null and NetworkManager.is_pvp():
		_grant_pvp_loadout(inv_node)
		return
	inv_node.pickup("wood_pickaxe", 1)
	inv_node.pickup("wood_axe", 1)
	inv_node.pickup("wood_sword", 1)


# 对战房开局包: 剑 + 弓 + 一叠箭 + 方块 + 穿上一套铁甲
func _grant_pvp_loadout(inv_node: Node) -> void:
	inv_node.pickup("iron_sword", 1)
	inv_node.pickup("wood_bow", 1)
	inv_node.pickup("wood_arrow", 99)
	inv_node.pickup("stone", 64)
	inv_node.set_armor("helmet", {"item_id": "iron_helmet", "count": 1})
	inv_node.set_armor("chest", {"item_id": "iron_chest", "count": 1})
	inv_node.set_armor("pants", {"item_id": "iron_pants", "count": 1})


func _return_to_menu() -> void:
	# 退出前最后存一次档
	if _state == "game":
		_save_all()
	_stop_autosave()
	_pause_menu.close()
	for n in _game_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_game_nodes.clear()
	get_tree().paused = false
	_show_menu_state()


# PvP: 收到"你被某人打了 X 点" → 在自己这端扣自己的血 (带无敌帧防连击)。
func _on_player_damaged(to_pid: String, dmg: int, kb: float, sx: float, sy: float, by_pid: String) -> void:
	if NetworkManager == null or not NetworkManager.is_pvp():
		return
	if to_pid != NetworkManager.my_peer_id():
		return   # 不是打我的, 忽略 (转发途中经过)
	var w := world
	if w == null or not is_instance_valid(w):
		return
	var player: Node2D = w.get_player()
	if player == null:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_method("take_damage"):
		if hp.take_damage(dmg, Vector2(sx, sy), kb):
			_last_attacker_pid = by_pid   # 真扣到血了才记凶手 (iframe 内没扣不算)


# PvP: 本地玩家死 → 把击杀记给凶手 + 几秒后自动满血复活 (不掉东西)。
func _on_local_death_pvp() -> void:
	if NetworkManager == null or not NetworkManager.is_pvp():
		return
	if _last_attacker_pid != "":
		NetworkManager.send_kill(_last_attacker_pid, NetworkManager.my_peer_id())
		_last_attacker_pid = ""
	# 3 秒后自动复活 (死亡屏先显示, 到点自动 _on_respawn 收掉它)
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(func():
		if _state == "game":
			_on_respawn())


func _notify_remote_death() -> void:
	if NetworkManager != null and NetworkManager.connected():
		NetworkManager.send_player_death()


func _on_respawn() -> void:
	var w := world
	if w != null:
		w.respawn_player()
	_death_screen.hide_death()
	# 联机: 复活了 → 通知对方恢复显示
	if NetworkManager != null and NetworkManager.connected():
		NetworkManager.send_player_respawn()


func _unhandled_input(event: InputEvent) -> void:
	# DEBUG: 按 V 在鼠标光标处放水 (测试流水用)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V \
			and _state == "game":
		var world: Node = get_node_or_null("World")
		if world != null and world.water_sim != null:
			var terrain: TileMapLayer = world.get_node("TerrainLayer")
			var mp: Vector2 = terrain.get_global_mouse_position()
			var t: Vector2i = terrain.local_to_map(terrain.to_local(mp))
			world.water_sim.add_water(t.x, t.y)
			print("[DEBUG] placed water at ", t)
		get_viewport().set_input_as_handled()
		return
	# ui_save (默认 F5) 触发存档. 同时认 raw KEY_F5 让程序化测试用 InputEventKey 也能触发.
	var is_f5_save: bool = event.is_action_pressed("ui_save") \
			or (event is InputEventKey and event.pressed and not event.echo \
					and event.keycode == KEY_F5)
	if is_f5_save and _state == "game":
		_save_all()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_pause") and _state == "game":
		if _death_screen.visible:
			return
		# 对话框开着时 ESC 优先让对话框自己关 (它的 _unhandled_input 会消费)
		var db := get_tree().get_first_node_in_group("dialogue_box")
		if db != null and db.visible:
			return
		_pause_menu.toggle()
		get_viewport().set_input_as_handled()
