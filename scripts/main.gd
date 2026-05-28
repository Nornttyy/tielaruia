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
const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")

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

var world: Node2D:
	get:
		return get_node_or_null("World")


func _ready() -> void:
	_main_menu.start_game.connect(_start_game)
	_main_menu.continue_game.connect(_continue_game)
	_pause_menu.return_to_menu.connect(_return_to_menu)
	_death_screen.respawn.connect(_on_respawn)
	_show_menu_state()


func _show_menu_state() -> void:
	_state = "menu"
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
	if seed_or_opts is Dictionary:
		var opts: Dictionary = seed_or_opts
		world_seed = int(opts.get("world_seed", 0))
		world_name = String(opts.get("world_name", ""))
		difficulty = int(opts.get("difficulty", 1))
	else:
		world_seed = int(seed_or_opts)
	if "current_difficulty" in GameSettings:
		GameSettings.current_difficulty = difficulty
	if "current_world_name" in GameSettings:
		GameSettings.current_world_name = world_name
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
	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)
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
	_start_autosave()
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


# 同步路径: 测试 + boot_to_game 用. 不走 LoadingScreen, World defer_init=false 自动跑完
func _start_game_sync(world_seed: int) -> void:
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
	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)
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
	_start_autosave()


# 实时存档: 每 AUTO_SAVE_INTERVAL 秒自动保存. 进游戏时启动 Timer.
func _start_autosave() -> void:
	if _autosave_timer != null:
		return
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTO_SAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(func():
		if _state == "game":
			SaveManager.save(self)
	)
	add_child(_autosave_timer)


func _stop_autosave() -> void:
	if _autosave_timer != null:
		_autosave_timer.queue_free()
		_autosave_timer = null


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
	})


func _apply_save_data(data: Resource) -> void:
	const SaveManager = preload("res://scripts/save/save_manager.gd")
	var w := world
	if w == null:
		return
	# 还原世界时间 (昼夜) - 不然 reload 总回早晨
	if "world_time" in data and TimeOfDay != null and "time" in TimeOfDay:
		TimeOfDay.time = float(data.world_time)
	# 恢复玩家挖/放的 chunk 改动 (写 _deltas, 之后 chunk 加载时会应用)
	SaveManager.apply_chunk_deltas(w.chunk_manager, data.chunk_deltas)
	# 恢复生命水晶世界限计数 + 已处理 chunk 列表 (防 chunk 重载又重新 cap)
	if data.version >= 2 and w.chunk_manager != null:
		w.chunk_manager.life_crystals_spawned = data.life_crystals_spawned
		for cx in data.processed_chunks:
			w.chunk_manager.processed_chunks[int(cx)] = true
	# 恢复箱子内容 (24 格 × 每个 chest tile)
	if "chest_contents" in data:
		ChestStorage.restore(data.chest_contents)
	# 把已经加载的 chunk 也重新刷一遍 tile 视觉 — 简单做法: 让 chunk_manager 重载
	# 否则玩家挖过的方块在 load 时不会显示
	for cx in data.chunk_deltas.keys():
		var ch = w.chunk_manager.get_chunk(cx)
		if ch != null:
			# 应用 delta 到 chunk.tiles
			var arr: PackedInt32Array = data.chunk_deltas[cx]
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
	player.global_position = data.player_position
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
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node != null and inv_node.inventory != null:
		inv_node.inventory.slots = data.inventory_slots.duplicate()
		if "hotbar_selected" in inv_node:
			inv_node.hotbar_selected = data.hotbar_selection
		if inv_node.has_signal("inventory_changed"):
			inv_node.inventory_changed.emit()
		if inv_node.has_signal("hotbar_selection_changed"):
			inv_node.hotbar_selection_changed.emit(data.hotbar_selection)


# 测试用 helper: 同步切到 game 状态, 不走 LoadingScreen.
# 顺便 queue_free MainMenu. 默认固定 seed=42 让测试可重复.
# 生产路径走 _main_menu.start_game 信号 → _start_game() async 流程.
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


# 真实新游戏 + continue 路径 (_run_async_load) 会调用这个;
# 测试 helper boot_to_game / _start_game_sync 跳过, 让测试用空背包独立 setup.
# continue 路径靠 _apply_save_data.call_deferred 在更后一帧覆盖背包, 不会留下重复.
func _grant_starter_on_new_game() -> void:
	var w := world
	if w == null:
		return
	var player: Node2D = w.get_player()
	if player == null:
		return
	_grant_starter_inventory(player)


func _grant_starter_inventory(player: Node) -> void:
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node == null or inv_node.inventory == null:
		return
	# 任一槽已有东西就跳过 (防 _wire_player 因 deferred 跑两次叠 buff)
	for s in inv_node.inventory.slots:
		if s != null:
			return
	inv_node.pickup("wood_pickaxe", 1)
	inv_node.pickup("wood_axe", 1)
	inv_node.pickup("wood_sword", 1)


func _return_to_menu() -> void:
	# 退出前最后存一次档
	if _state == "game":
		SaveManager.save(self)
	_stop_autosave()
	_pause_menu.close()
	for n in _game_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_game_nodes.clear()
	get_tree().paused = false
	_show_menu_state()


func _on_respawn() -> void:
	var w := world
	if w != null:
		w.respawn_player()
	_death_screen.hide_death()


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
		SaveManager.save(self)
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
