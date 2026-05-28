# 玩家交互：鼠标瞄准、距离检查、挖放进度。
extends Node2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const VillagerLines = preload("res://scripts/npc/villager_lines.gd")
const TILE_SIZE := 12
const REACH_TILES := 4
const INVALID_TILE := Vector2i(-1, -1)

# Tile 硬度（累计 tool_speed*delta 达此值挖完，单位"秒"）
# 用户改: 矿石按 tier 递增 (3→8s), 石头/煤 3s base.
# 镐 _tool_speed 按 tier 1-7 加速 (wood ×1 → diamond ×5).
const _HARDNESS := {
	Tiles.GRASS: 0.3,
	Tiles.DIRT: 0.3,
	Tiles.SAND: 0.3,
	Tiles.LEAVES: 0.2,
	Tiles.PLANKS: 0.3,
	Tiles.WORKBENCH: 0.5,
	Tiles.DOOR: 0.5,
	Tiles.LOG: 0.6,
	Tiles.STONE: 3.0,         # base
	Tiles.DEEP_STONE: 3.0,
	Tiles.COAL_ORE: 3.0,      # 跟石头同
	Tiles.COPPER_ORE: 3.5,    # +0.5
	Tiles.TIN_ORE: 3.5,
	Tiles.IRON_ORE: 4.0,      # +1
	Tiles.SILVER_ORE: 5.0,    # +2
	Tiles.GOLD_ORE: 6.0,      # +3
	Tiles.DIAMOND_ORE: 7.0,   # +4
	Tiles.HELL_CRYSTAL: 8.0,  # +5
	Tiles.LOG_TOP: 0.6,
	Tiles.LOG_ROOT_L: 0.4,
	Tiles.LOG_ROOT_R: 0.4,
	Tiles.BRANCH_L: 0.4,
	Tiles.BRANCH_R: 0.4,
}

# 镐"石头类"目标 (拿 tier 加速): 石 + 深石 + 全部矿石.
# 草/泥/沙/木板等 pickaxe 用基础 ×1 速度, 不在表里.
const _PICKAXE_STONE_LIKE := {
	Tiles.STONE: true,
	Tiles.DEEP_STONE: true,
	Tiles.COAL_ORE: true,
	Tiles.COPPER_ORE: true,
	Tiles.TIN_ORE: true,
	Tiles.IRON_ORE: true,
	Tiles.SILVER_ORE: true,
	Tiles.GOLD_ORE: true,
	Tiles.DIAMOND_ORE: true,
	Tiles.HELL_CRYSTAL: true,
}

# 树的所有 tile 类型 (用于级联砍树)
const _TREE_PARTS := {
	Tiles.LOG: true,
	Tiles.LOG_TOP: true,
	Tiles.LOG_ROOT_L: true,
	Tiles.LOG_ROOT_R: true,
	Tiles.BRANCH_L: true,
	Tiles.BRANCH_R: true,
}

# 镐挖不了的"植物"类 tile (叶子 / 仙人掌 / 火把等小物). 镐只破坏"方块".
# 不挡 axe (砍 LOG) / sword (无挖矿). 也不挡徒手 / 别工具.
const _PICKAXE_BLACKLIST := {
	Tiles.LEAVES: true,
	Tiles.LEAVES_PINE: true,
	Tiles.LEAVES_AUTUMN: true,
	Tiles.JUNGLE_LEAVES: true,
	Tiles.CACTUS: true,
	Tiles.CACTUS_BODY: true,
	Tiles.TORCH: true,
	Tiles.SLIME_TORCH: true,
}

# 测试注入
var aim_override: Variant = null
var primary_override: Variant = null     # null = 真实输入；bool = 强制
var place_override: bool = false
var secondary_held_override: Variant = null  # null = 真实输入；bool = 强制（测试）

# Mining 状态
var _mining_target: Vector2i = INVALID_TILE
var _mining_progress: float = 0.0
var _mining_swing_t: float = 0.0  # 挖矿挥镐动画节流

# 战斗
const SWORD_RANGE_PX := 27.0
const SWORD_COOLDOWN := 0.3
const SWORD_ARC_LIFETIME := 0.18
var _attack_cooldown: float = 0.0
# 剑的戳/挥交替: 0 = 下一击戳, 1 = 下一击挥. 切工具时归零.
var _attack_combo_step: int = 0

# 镐旋转: 用户改 — 怪要碰到镐才扣血 (不是 AoE 圆心扣血).
# spin 期间每帧算 pickaxe tip 世界位置, 距离 ≤ HIT_RADIUS 的怪扣 1 次.
const PICKAXE_SPIN_DURATION := 0.7
const PICKAXE_TIP_LOCAL_Y := -16.0   # tip 相对 held.position 的 y 偏移 (sprite 16h × scale 1.0)
const PICKAXE_HIT_RADIUS := 10.0     # tip 到怪中心 ≤ 10px 算碰到 (TILE_SIZE 缩 0.75)
var _pickaxe_spin_active: bool = false
var _pickaxe_spin_t: float = 0.0
var _pickaxe_hit_this_spin: Dictionary = {}  # instance_id → true (1 spin 1 只怪 1 击)

# 测试用: 记录最近一次挥剑的命中中心点 (玩家中心 + 鼠标方向 * 半径)
var last_swing_center: Vector2 = Vector2.ZERO
# 测试用: 注入鼠标世界坐标 (null = 真实 get_global_mouse_position)
var mouse_world_override: Variant = null

# 进食状态
const EAT_DURATION_SEC := 2.0   # 进食 2 秒 (按住右键 / F 键持续)
var _eat_t: float = 0.0
var _eat_item_id: String = ""


func set_secondary_held_for_test(held: bool) -> void:
	secondary_held_override = held


func _ready() -> void:
	# 切 hotbar 时重置剑的戳/挥序列 (防玩家切镐再切回剑还接着上次的挥)
	# 用 call_deferred 等 PlayerInventory 也 _ready 完
	_connect_hotbar_signal.call_deferred()


func _connect_hotbar_signal() -> void:
	var inv: Node = _inventory_node()
	if inv != null and inv.has_signal("hotbar_selection_changed"):
		if not inv.hotbar_selection_changed.is_connected(_on_hotbar_changed):
			inv.hotbar_selection_changed.connect(_on_hotbar_changed)


# signal handler 同步: 不要加 await (CLAUDE.md feedback_no_async_signal)
func _on_hotbar_changed(_idx: int) -> void:
	_attack_combo_step = 0


func _physics_process(delta: float) -> void:
	# E 一键合成: 工作台旁开 3x3, 否则 2x2; 已开则关
	if Input.is_action_just_pressed("interact"):
		_try_open_workbench_or_close()
	# 其余动作面板开则跳过
	if _crafting_open():
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	# 持剑 LMB → 戳/挥交替; 持镐 → 鼠标对方块挖矿, 否则附近有怪就攻击; 其他 → 挖
	var kind: String = _current_tool_kind()
	if kind == "sword":
		_reset_mining()
		var primary_pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed and _attack_cooldown <= 0.0:
			# combo: 0 = 下一击戳, 1 = 下一击挥, 然后翻转
			if _attack_combo_step == 0:
				_thrust_sword()
				_attack_combo_step = 1
			else:
				_sweep_sword()
				_attack_combo_step = 0
	elif kind == "pickaxe":
		# 优先级: 鼠标对方块 → 挖矿; 否则 鼠标附近有怪 → 攻击
		if _mouse_on_mineable_tile():
			_update_mining(delta)
		else:
			_reset_mining()
			var primary_pressed_p: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
			if primary_pressed_p and _attack_cooldown <= 0.0 and _mouse_has_enemy_nearby():
				_pickaxe_attack()
	elif kind == "axe":
		# 用户改: 斧动作跟镐同款. 鼠标对 LOG → 砍 + spin; 否则 附近怪 → spin (0 伤害, 视觉)
		if _mouse_on_log():
			_update_mining(delta)
		else:
			_reset_mining()
			var primary_pressed_a: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
			if primary_pressed_a and _attack_cooldown <= 0.0 and _mouse_has_enemy_nearby():
				_axe_swing()
	else:
		_update_mining(delta)
	_update_eat_or_place(delta)
	# 工具 spin 中: 每帧检查 tip 跟怪的距离, 碰到就扣血 (镐 + 斧共用; 斧 damage_mult=0 自动跳过)
	if _pickaxe_spin_active:
		_pickaxe_spin_t += delta
		if _pickaxe_spin_t >= PICKAXE_SPIN_DURATION:
			_pickaxe_spin_active = false
			_pickaxe_hit_this_spin.clear()
		else:
			_check_pickaxe_spin_hits()


func _crafting_open() -> bool:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	return cp != null and cp.is_open()


func _toggle_crafting(n: int) -> void:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if cp == null:
		return
	if cp.is_open():
		cp.close()
	else:
		cp.open(n)


func _try_open_workbench_or_close() -> void:
	# 优先级: 附近村民 → 对话 (跳过合成面板)
	var villager = _find_villager_nearby()
	if villager != null:
		var db = get_tree().get_first_node_in_group("dialogue_box")
		if db != null and db.has_method("open"):
			db.open(VillagerLines.random_line())
		return
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if cp == null:
		return
	if cp.is_open():
		cp.close()
		return
	# 工作台 2 格内 → 3x3, 否则 → 2x2 (E 一键合成)
	if _has_workbench_nearby():
		cp.open(3)
	else:
		cp.open(2)


func _find_villager_nearby() -> Node2D:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return null
	var player_pos: Vector2 = parent.global_position
	for v in get_tree().get_nodes_in_group("villagers"):
		if v is Node2D and v.global_position.distance_to(player_pos) <= 2.0 * TILE_SIZE:
			return v
	return null


func _has_workbench_nearby() -> bool:
	var terrain := _terrain()
	if terrain == null:
		return false
	var pt: Vector2i = player_tile()
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.WORKBENCH:
				return true
	return false


func _update_mining(delta: float) -> void:
	var pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
	if not pressed:
		_reset_mining()
		return
	# 斧只能砍 LOG, 别的 tile 早 return 不播挖矿摆动 (防 "斧对空气挥" 的视觉 bug)
	if _current_tool_kind() == "axe":
		var ax_tile: Vector2i = aim_tile_coord()
		var ax_terrain := _terrain()
		if ax_terrain == null:
			_reset_mining()
			return
		var ax_tid: int = ax_terrain.get_cell_source_id(ax_tile)
		if ax_tid != Tiles.LOG:
			_reset_mining()
			return
	# 镐不能挖植物 (叶 / 仙人掌 / 火把). 用户改: "镐只破坏方块"
	if _current_tool_kind() == "pickaxe":
		var pk_tile: Vector2i = aim_tile_coord()
		var pk_terrain := _terrain()
		if pk_terrain != null:
			var pk_tid: int = pk_terrain.get_cell_source_id(pk_tile)
			if _PICKAXE_BLACKLIST.has(pk_tid):
				_reset_mining()
				return
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		_reset_mining()
		return
	var terrain := _terrain()
	if terrain == null:
		return
	var tid: int = terrain.get_cell_source_id(tile)
	if tid == -1 or not Tiles.is_mineable(tid):
		_reset_mining()
		return
	# 树部件特殊规则: 只有树底 LOG 能直接挖. LOG_TOP/BRANCH/ROOT 不能直接挖,
	# 中段 LOG 也不能 — 必须从最底下砍, 整棵爆.
	if _TREE_PARTS.has(tid):
		var world_node: Node = terrain.get_parent()
		if tid != Tiles.LOG or not _is_tree_base(world_node, tile.x, tile.y):
			_reset_mining()
			return
	var inv: Node = _inventory_node()
	var tool_kind: String = "" if inv == null else inv.current_tool_kind()
	var required: int = Tiles.required_tool_tier(tid, tool_kind)
	if required == -1:
		# 工具不对 → 永远挖不完，进度归零
		_reset_mining()
		_mining_target = tile
		return
	# 工具 tier 不够 → 也不行 (例如木镐挖铁矿)
	if _current_tool_tier() < required:
		_reset_mining()
		_mining_target = tile
		return
	if tile != _mining_target:
		_clear_crack(_mining_target)
		_mining_target = tile
		_mining_progress = 0.0
		_mining_swing_t = 0.0
	_mining_progress += _tool_speed(tool_kind, tid) * delta
	# 镐 + 斧 (用户改: 斧跟镐同款): 360° 旋转动画 — 每 0.7s 重启一次
	# 其他 (徒手等): ±75° 来回挥 — 每 0.35s 挥一次
	_mining_swing_t -= delta
	if _mining_swing_t <= 0.0:
		var player_node: Node = get_parent()
		var held: Node = null if player_node == null else player_node.get_node_or_null("HeldItem")
		if tool_kind == "pickaxe" or tool_kind == "axe":
			_mining_swing_t = 0.7
			if held != null and held.has_method("play_pickaxe_attack"):
				_start_pickaxe_spin()
		else:
			_mining_swing_t = 0.35
			if held != null and held.has_method("play_swing"):
				held.play_swing()
	# 通知 CrackOverlay 当前进度
	var ratio: float = clamp(_mining_progress / _hardness(tid), 0.0, 1.0)
	_set_crack(tile, ratio)
	if _mining_progress >= _hardness(tid):
		_finish_mine(tile, tid, tool_kind, terrain)
		_clear_crack(tile)
		_mining_target = INVALID_TILE
		_mining_progress = 0.0


func _reset_mining() -> void:
	if _mining_target != INVALID_TILE:
		_clear_crack(_mining_target)
	_mining_target = INVALID_TILE
	_mining_progress = 0.0


func _set_crack(tile: Vector2i, ratio: float) -> void:
	var co: Node = _crack_overlay()
	if co != null:
		co.set_progress(tile, ratio)


func _clear_crack(tile: Vector2i) -> void:
	if tile == INVALID_TILE:
		return
	var co: Node = _crack_overlay()
	if co != null:
		co.clear(tile)


func _crack_overlay() -> Node:
	var terrain := _terrain()
	if terrain == null:
		return null
	var world: Node = terrain.get_parent()
	return world.get_node_or_null("CrackOverlay")


func _finish_mine(tile: Vector2i, tid: int, tool_kind: String, terrain: TileMapLayer) -> void:
	var world: Node = terrain.get_parent()
	# 砍 LOG 时若是树底 (下方是地面而不是树) → 整棵爆掉
	if tid == Tiles.LOG and _is_tree_base(world, tile.x, tile.y):
		_cascade_chop_tree(world, tile, tool_kind)
		return
	# 砍门: 联动消除另一半 (DOOR↔DOOR_TOP)
	if tid == Tiles.DOOR:
		if world.has_method("_set_tile"):
			world._set_tile(tile.x, tile.y - 1, Tiles.AIR)   # 同时消顶部
	elif tid == Tiles.DOOR_TOP:
		if world.has_method("_set_tile"):
			world._set_tile(tile.x, tile.y + 1, Tiles.AIR)   # 同时消底部
			# 由底部 (Tiles.DOOR) 的 drops 出 door item, 这里改 tid 让正常流程走底的掉落
			tid = Tiles.DOOR
	# 砍 chest: 内容物先撒出来 (不丢)
	if tid == Tiles.CHEST:
		var contents: Array = ChestStorage.clear(tile)
		for s in contents:
			if s != null:
				for _i in s.count:
					_spawn_drop(s.item_id, tile)
	# 普通破: 单格
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	SkyLightGrid.invalidate_column(tile.x)
	Effects.spawn_block_break(tile, tid)
	SfxBank.play("break", 0.15)
	var drops: Dictionary = Tiles.drops_for(tid, tool_kind)
	for item_id in drops:
		for _i in drops[item_id]:
			_spawn_drop(item_id, tile)


# 树底 = 下面那格不属于树自身的部件. 其他都算 (grass/dirt/AIR/stone/glass 等).
# AIR 也允许 (玩家挖掉了树下方的地基 → 树悬空, 仍是树底可整棵砍).
func _is_tree_base(world: Node, x: int, y: int) -> bool:
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	var below: int = cm.get_tile(x, y + 1)
	if _TREE_PARTS.has(below):
		return false
	if below == Tiles.LEAVES:
		return false   # 叶子在底下太怪 (玩家自建除外), 暂不视为底
	return true


# 从树底沿树干向上集齐所有 LOG/LOG_TOP/BRANCH/ROOT 和上方的叶子, 一并破掉 + 集中掉物
func _cascade_chop_tree(world: Node, base: Vector2i, tool_kind: String) -> void:
	var cm = world.get("chunk_manager")
	if cm == null:
		return
	# 联机: 把 30+ tile 变化打包一条消息 (防小消息冲爆 PeerJS buffer)
	if world.has_method("begin_tile_batch"):
		world.begin_tile_batch()
	_do_cascade_chop(world, cm, base, tool_kind)
	if world.has_method("end_tile_batch"):
		world.end_tile_batch()


func _do_cascade_chop(world: Node, cm, base: Vector2i, tool_kind: String) -> void:
	# 沿 x 列向上走树干 (LOG → LOG_TOP)
	var trunk_top_y: int = base.y
	var ty: int = base.y
	while ty >= 0:
		var t: int = cm.get_tile(base.x, ty)
		if t == Tiles.LOG:
			trunk_top_y = ty
			ty -= 1
			continue
		if t == Tiles.LOG_TOP:
			trunk_top_y = ty
			break
		break
	# 收集要破的 tile: trunk + ROOT/BRANCH 在每个 y 的左右 + canopy 叶子
	var to_break: Array = []
	for cy in range(trunk_top_y, base.y + 1):
		var t: int = cm.get_tile(base.x, cy)
		if _TREE_PARTS.has(t):
			to_break.append([Vector2i(base.x, cy), t])
		for dx in [-1, 1]:
			var ts: int = cm.get_tile(base.x + dx, cy)
			if _TREE_PARTS.has(ts):
				to_break.append([Vector2i(base.x + dx, cy), ts])
	# canopy 叶子: LOG_TOP 上方 ±3 x, [trunk_top - 6, trunk_top + 1] y 内的 LEAVES
	for cy in range(trunk_top_y - 6, trunk_top_y + 2):
		for dx in range(-3, 4):
			var tx: int = base.x + dx
			var t: int = cm.get_tile(tx, cy)
			if t == Tiles.LEAVES:
				to_break.append([Vector2i(tx, cy), t])
	# 破并掉物
	for entry in to_break:
		var p: Vector2i = entry[0]
		var t: int = entry[1]
		world._set_tile(p.x, p.y, Tiles.AIR)
		Effects.spawn_block_break(p, t)
		var drops: Dictionary = Tiles.drops_for(t, tool_kind)
		for item_id in drops:
			for _i in drops[item_id]:
				_spawn_drop(item_id, p)
	SkyLightGrid.invalidate_column(base.x)
	SfxBank.play("break", 0.25)


func _spawn_drop(item_id: String, tile: Vector2i) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = Vector2(
		tile.x * TILE_SIZE + TILE_SIZE / 2.0 + randf_range(-3.0, 3.0),
		tile.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent().get_parent()
	entities.add_child(drop)


# 返回 true 表示成功放置 (用于测试断言)
func try_place() -> bool:
	var terrain := _terrain()
	var inv: Node = _inventory_node()
	if terrain == null or inv == null:
		return false
	var slot: Variant = inv.current_hotbar_slot()
	if slot == null:
		return false
	if not ItemDB.is_placeable(slot.item_id):
		return false
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		return false
	# === 墙 (wall item): 放进 wall_layer, 不挡走路. 跟方块独立放置规则 ===
	if ItemDB.is_wall(slot.item_id):
		var w_node: Node = terrain.get_parent()
		var wall_layer: TileMapLayer = w_node.get_node_or_null("WallLayer") if w_node != null else null
		if wall_layer == null:
			return false
		# 已经有墙 → 不重叠放
		if wall_layer.get_cell_source_id(tile) != -1:
			return false
		var w_def = ItemDB.get_def(slot.item_id)
		var wid: int = w_def.placeable_tile_id
		# autotile 接邻居: 让墙跟相邻墙连接边缘
		const Autotile = preload("res://scripts/world/autotile.gd")
		const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
		var w_node2: Node = terrain.get_parent()
		var cm = w_node2.get("chunk_manager") if w_node2 != null else null
		if EdgeTemplates.FAMILY_OF.has(wid) and cm != null:
			var wq := Autotile.make_wall_query(wid, cm)
			Autotile.refresh_tile(wall_layer, tile, wid, wq)
			# 刷邻居 8 个 (它们 mask 变了)
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var npos: Vector2i = tile + Vector2i(dx, dy)
					var nsid: int = wall_layer.get_cell_source_id(npos)
					if nsid == -1:
						continue
					if EdgeTemplates.FAMILY_OF.has(nsid):
						var nq := Autotile.make_wall_query(nsid, cm)
						Autotile.refresh_tile(wall_layer, npos, nsid, nq)
		else:
			wall_layer.set_cell(tile, wid, Vector2i.ZERO)
		inv.consume_current(1)
		Effects.spawn_place_bounce(tile, wid)
		SfxBank.play("place", 0.10)
		return true
	# 目标必须为空气 (或水, 水可以被填掉 — 玩家用方块塞水)
	var target_src: int = terrain.get_cell_source_id(tile)
	var is_water: bool = target_src == Tiles.WATER or target_src == Tiles.WATER_L1 \
			or target_src == Tiles.WATER_L2 or target_src == Tiles.WATER_L3
	if target_src != -1 and not is_water:
		return false
	# 不与玩家碰撞框重叠（玩家占 2 tile 高：脚底 tile 和上方 tile）
	var pt: Vector2i = player_tile()
	if tile == pt or tile == pt - Vector2i(0, 1):
		return false
	# 支撑判定: 上下左右至少有 1 个相邻方块 OR 当前格背景有墙 (允许靠墙挂方块).
	var has_support: bool = false
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if terrain.get_cell_source_id(tile + offset) != -1:
			has_support = true
			break
	if not has_support:
		# 检查这格背后有没有墙 (wall_layer 跟 terrain 同父 World)
		var w_node: Node = terrain.get_parent()
		var wall_layer = w_node.get_node_or_null("WallLayer") if w_node != null else null
		if wall_layer != null and wall_layer.get_cell_source_id(tile) != -1:
			has_support = true
	if not has_support:
		return false
	var def = ItemDB.get_def(slot.item_id)
	var world: Node = terrain.get_parent()
	# 门: 2 格高, 占当前 tile + 上一格. 上面必须空气, 否则放不了.
	if def.placeable_tile_id == Tiles.DOOR:
		var above: Vector2i = tile + Vector2i(0, -1)
		if terrain.get_cell_source_id(above) != -1:
			return false
		if world.has_method("_set_tile"):
			world._set_tile(tile.x, tile.y, Tiles.DOOR)
			world._set_tile(above.x, above.y, Tiles.DOOR_TOP)
		inv.consume_current(1)
		SkyLightGrid.invalidate_column(tile.x)
		Effects.spawn_place_bounce(tile, Tiles.DOOR)
		SfxBank.play("place", 0.10)
		return true
	# (移除 terrain.set_cell; world._set_tile 内部刷视觉 + 邻居)
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, def.placeable_tile_id)
	inv.consume_current(1)
	SkyLightGrid.invalidate_column(tile.x)
	# P1.5 hook: 放下弹动
	Effects.spawn_place_bounce(tile, def.placeable_tile_id)
	SfxBank.play("place", 0.10)
	return true


# ---- Helpers ----

func _hardness(tid: int) -> float:
	return _HARDNESS.get(tid, 0.5)


func _tool_speed(tool_kind: String, tid: int) -> float:
	# 斧砍 LOG: 7 tier 进阶 (用户改: 整体慢 1.5×, wood 9s, diamond 0.9s)
	# 实际时间 = 硬度 0.6s / speed.
	if tool_kind == "axe" and tid == Tiles.LOG:
		var tier := _current_tool_tier()
		match tier:
			1: return 0.0667  # wood   - 9.0s
			2: return 0.10    # stone  - 6.0s
			3: return 0.133   # copper - 4.5s
			4: return 0.20    # iron   - 3.0s
			5: return 0.267   # silver - 2.25s
			6: return 0.40    # gold   - 1.5s
			_: return 0.667   # diamond+ - 0.9s
	# 镐挖 石/深石/矿石: 7 tier 进阶 (用户调: wood 3s 不变, 顶级慢下来到 0.6s)
	# 硬度 3.0s base. 速度 = 3.0 / 想要时间.
	if tool_kind == "pickaxe" and _PICKAXE_STONE_LIKE.has(tid):
		var tier := _current_tool_tier()
		match tier:
			1: return 1.0   # wood    - 3.0s
			2: return 1.2   # stone   - 2.5s
			3: return 1.5   # copper  - 2.0s
			4: return 2.0   # iron    - 1.5s
			5: return 2.5   # silver  - 1.2s
			6: return 3.33  # gold    - 0.9s
			_: return 5.0   # diamond+ - 0.6s
	return 1.0


func aim_tile_coord() -> Vector2i:
	if aim_override != null:
		return aim_override as Vector2i
	var terrain := _terrain()
	if terrain == null:
		return INVALID_TILE
	var mouse_world: Vector2 = terrain.get_global_mouse_position()
	return terrain.local_to_map(terrain.to_local(mouse_world))


func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer


func _current_tool_kind() -> String:
	var inv: Node = _inventory_node()
	return "" if inv == null else inv.current_tool_kind()


func _current_tool_def() -> Variant:
	var inv: Node = _inventory_node()
	if inv == null:
		return null
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return null
	return ItemDB.get_def(slot.item_id)


# 工具的攻击倍率 (剑=1.0, 镐=0.5, 斧=0.0, 其他=0.0). 用 dict get 兜底防旧档.
func _tool_damage_mult() -> float:
	var def = _current_tool_def()
	if def == null:
		return 0.0
	return def.get("damage_mult", 0.0)


# 击退强度 (阶段 2): 按工具 + tier 缩放
const KB_THRUST_BASE := 45.0
const KB_THRUST_TIER := 11.0
const KB_SWEEP_BASE := 60.0
const KB_SWEEP_TIER := 15.0
const KB_PICKAXE_BASE := 22.0
const KB_PICKAXE_TIER := 6.0


func _thrust_knockback() -> float:
	return KB_THRUST_BASE + KB_THRUST_TIER * float(_current_tool_tier())


func _sweep_knockback() -> float:
	return KB_SWEEP_BASE + KB_SWEEP_TIER * float(_current_tool_tier())


func _pickaxe_knockback() -> float:
	return KB_PICKAXE_BASE + KB_PICKAXE_TIER * float(_current_tool_tier())


func _sword_damage() -> int:
	var inv: Node = _inventory_node()
	if inv == null:
		return 0
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return 0
	var def = ItemDB.get_def(slot.item_id)
	if def == null or def.tool_kind != "sword":
		return 0
	# wood tier 1 → 3 (4 击杀史莱姆); stone tier 2 → 5 (2 击杀)
	return 5 if def.tool_tier >= 2 else 3


func _current_tool_tier() -> int:
	var inv: Node = _inventory_node()
	if inv == null:
		return 0
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return 0
	var def = ItemDB.get_def(slot.item_id)
	if def == null:
		return 0
	return def.tool_tier


func _effective_sword_damage() -> int:
	var base: int = _sword_damage()
	if base <= 0:
		return 0
	var hunger: Node = get_parent().get_node_or_null("PlayerHunger")
	var hunger_mult: float = 1.0 if hunger == null else hunger.get_attack_multiplier()
	var dmg_mult: float = _tool_damage_mult()
	if dmg_mult <= 0.0:
		return 0
	return max(1, int(round(float(base) * hunger_mult * dmg_mult)))


func _update_eat_or_place(delta: float) -> void:
	# 优先级: place_override (测试) → 进食 → 放置
	if place_override:
		try_place()
		place_override = false
		return

	# 右键或 F 键都能吃 (F 给 Mac 触摸板用户的备选)
	var held: bool
	var just: bool
	if secondary_held_override != null:
		held = (secondary_held_override == true)
		just = false
	else:
		held = Input.is_action_pressed("secondary") or Input.is_key_pressed(KEY_F)
		just = Input.is_action_just_pressed("secondary") or Input.is_key_pressed(KEY_F)

	var inv: Node = _inventory_node()
	var slot = null if inv == null else inv.current_hotbar_slot()
	var holding_food: bool = slot != null and ItemDB.is_food(slot.item_id)
	var hunger: Node = get_parent().get_node_or_null("PlayerHunger")

	# 持钩爪 + 右键刚按下 → 朝鼠标发射钩爪 (玩家拉过去)
	if slot != null and slot.item_id == "grappling_hook" and just:
		var player_node: Node = get_parent()
		if player_node != null and player_node.has_method("fire_grappling_hook"):
			player_node.fire_grappling_hook(player_node.get_global_mouse_position())
		return

	# 右键刚按下 + 鼠标对准的 tile 是 CHEST → 打开箱子面板 (优先级高于放置/吃)
	if just:
		var aim_tile: Vector2i = aim_tile_coord()
		if in_reach(aim_tile):
			var terrain := _terrain()
			if terrain != null and terrain.get_cell_source_id(aim_tile) == Tiles.CHEST:
				var cp: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
				if cp == null:
					cp = get_tree().root.find_child("ChestPanel", true, false)
				if cp != null and cp.has_method("open"):
					cp.open(aim_tile, inv)
				return

	# 持食物 + 按住 + 没吃饱 → 进入/保持 eating
	if holding_food and held and hunger != null and int(hunger.current) < hunger.MAX:
		if _eat_item_id != slot.item_id:
			_eat_item_id = slot.item_id
			_eat_t = 0.0
			_start_eat_anim()
		_eat_t += delta
		if _eat_t >= EAT_DURATION_SEC:
			_eat_t = 0.0
			hunger.consume(ItemDB.food_fill(slot.item_id))
			SfxBank.play("eat", 0.10)
			inv.consume_current(1)
			_stop_eat_anim()  # 吃完一口, 下次按住会重新开始
		return

	# 取消进食 (松开 / 没食物 / 满饱)
	if _eat_t > 0.0:
		_eat_t = 0.0
		_eat_item_id = ""
		_stop_eat_anim()

	# 退回放置逻辑（与原行为一致）
	if just:
		try_place()


# 进食动画: 食物在玩家手里 上下抖动 + 微微旋转, 像在啃咬
func _start_eat_anim() -> void:
	var held = _held_item_node()
	if held != null and held.has_method("start_eat"):
		held.start_eat()


func _stop_eat_anim() -> void:
	var held = _held_item_node()
	if held != null and held.has_method("stop_eat"):
		held.stop_eat()


func _held_item_node() -> Node:
	var player_node: Node = get_parent()
	if player_node == null:
		return null
	return player_node.get_node_or_null("HeldItem")


# 挥的弧度: 前方 ±45° = 总 90° 弧
const SWEEP_ARC_HALF_DEG := 45.0
# 镐攻击的常量
# cooldown = spin 时长 — 一次完整旋转后才能再攻击 (用户改: 转慢一点 → 攻击也慢一点)
const PICKAXE_ATTACK_COOLDOWN := 0.7
const PICKAXE_MOUSE_NEAR_RADIUS_MULT := 1.5  # 触发判定圆心 = 鼠标位置


# 鼠标对准的 tile 是否可挖 (用来决定镐走挖矿模式还是攻击模式)
func _mouse_on_mineable_tile() -> bool:
	var tile: Vector2i = aim_tile_coord()
	var terrain := _terrain()
	if terrain == null:
		return false
	var tid: int = terrain.get_cell_source_id(tile)
	return tid != -1 and Tiles.is_mineable(tid)


# 鼠标对的 tile 是不是 LOG (斧砍树的目标). 用来分发斧的"砍树" vs "空挥"
func _mouse_on_log() -> bool:
	var tile: Vector2i = aim_tile_coord()
	var terrain := _terrain()
	if terrain == null:
		return false
	return terrain.get_cell_source_id(tile) == Tiles.LOG


# 鼠标位置周围 SWORD_RANGE_PX * 1.5 半径内是否有可攻击目标
func _mouse_has_enemy_nearby() -> bool:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return false
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var radius: float = SWORD_RANGE_PX * PICKAXE_MOUSE_NEAR_RADIUS_MULT
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn != null and mouse_world.distance_to(sn.global_position) <= radius:
				return true
	return false


# 镐基础伤害: 跟 _sword_damage 同公式 (tier ≥ 2 → 5, else 3),
# 复制一份避免 _sword_damage 内的 tool_kind 检查 (它只对 sword 返回非 0)
func _pickaxe_base_damage() -> int:
	var def = _current_tool_def()
	if def == null:
		return 0
	if def.tool_kind != "pickaxe":
		return 0
	return 5 if def.tool_tier >= 2 else 3


# 镐攻击: 触发 360° spin. 伤害判定不再 AoE — 走 _check_pickaxe_spin_hits
# 每帧检查 pickaxe tip 是否碰到怪 (用户改: "怪要碰到镐子才扣血").
func _pickaxe_attack() -> void:
	_attack_cooldown = PICKAXE_ATTACK_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	_start_pickaxe_spin()
	SfxBank.play("swing", 0.10)
	if player.has_method("shake"):
		player.shake(2.0)


# 斧挥: 跟镐 _pickaxe_attack 同套路, 走 spin + collision. 但 damage_mult=0 自动
# 让 _check_pickaxe_spin_hits 跳过扣血 (return early). 纯视觉动作.
func _axe_swing() -> void:
	_attack_cooldown = PICKAXE_ATTACK_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	_start_pickaxe_spin()
	SfxBank.play("swing", 0.10)


# 开始一次 360° 旋转 (动画 + 标记 spin 期 + 清空已击中表).
# 挖矿循环和单次攻击都调这个. 期间 _physics_process 每帧检查 tip 跟怪的距离.
func _start_pickaxe_spin() -> void:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null and held.has_method("play_pickaxe_attack"):
		held.play_pickaxe_attack()
	elif held != null and held.has_method("play_swing"):
		held.play_swing()
	_pickaxe_spin_active = true
	_pickaxe_spin_t = 0.0
	_pickaxe_hit_this_spin.clear()


# spin 期间每帧调: 算 pickaxe tip 世界位置, 检查跟怪的距离.
# 怪距 ≤ HIT_RADIUS 且这次 spin 还没被打 → 扣血 + 记入 hit set 防重复.
func _check_pickaxe_spin_hits() -> void:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var held: Node2D = player.get_node_or_null("HeldItem") as Node2D
	if held == null or not held.visible:
		return
	# tip 旋转角度自己算 (跟 held_item Tween 的目标值一致 0→2π over 0.7s),
	# 不读 held.rotation — tween 在 _process 更新, _physics_process 这里读可能滞后.
	var rot: float = (_pickaxe_spin_t / PICKAXE_SPIN_DURATION) * TAU
	var tip_world: Vector2 = held.global_position + Vector2(0, PICKAXE_TIP_LOCAL_Y).rotated(rot)
	var base: int = _pickaxe_base_damage()
	if base <= 0:
		return
	var hunger: Node = player.get_node_or_null("PlayerHunger")
	var hunger_mult: float = 1.0 if hunger == null else hunger.get_attack_multiplier()
	var dmg_mult: float = _tool_damage_mult()
	if dmg_mult <= 0.0:
		return
	var damage: int = max(1, int(round(float(base) * hunger_mult * dmg_mult)))
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn == null:
				continue
			var id: int = sn.get_instance_id()
			if _pickaxe_hit_this_spin.has(id):
				continue
			if tip_world.distance_to(sn.global_position) > PICKAXE_HIT_RADIUS:
				continue
			_pickaxe_hit_this_spin[id] = true
			if sn.has_method("take_damage"):
				sn.take_damage(damage, tip_world, _pickaxe_knockback())


# 弧形判定: 目标在 origin → dir 弧内 (距 ≤ SWORD_RANGE_PX 且夹角 ≤ ±45°)
func _is_in_swing_arc(target_pos: Vector2, origin: Vector2, dir: Vector2) -> bool:
	var to_target := target_pos - origin
	var dist := to_target.length()
	if dist > SWORD_RANGE_PX:
		return false
	if dist < 4.0:
		return true   # 贴脸总命中
	var diff: float = wrapf(to_target.angle() - dir.angle(), -PI, PI)
	return abs(diff) <= deg_to_rad(SWEEP_ARC_HALF_DEG)


# 戳的常量
const THRUST_COOLDOWN := 0.18
const THRUST_LENGTH_MULT := 1.2      # 戳长 = SWORD_RANGE_PX * 1.2 ≈ 43px (比挥更远)
const THRUST_HALF_WIDTH := 4.5       # 戳带半宽 6px (总宽 12), 鼠标偏一点也命中
const THRUST_DAMAGE_MULT := 0.8


# 戳: 直线突刺, 范围远 / 伤害 0.8x / 只命中最近 1 个目标
func _thrust_sword() -> void:
	_attack_cooldown = THRUST_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - player.global_position
	if to_mouse.length() < 0.001:
		to_mouse = Vector2(1.0 if player.has_method("facing_dir") and player.facing_dir() > 0 else -1.0, 0)
	var swing_dir: Vector2 = to_mouse.normalized()
	var max_len: float = SWORD_RANGE_PX * THRUST_LENGTH_MULT
	last_swing_center = player.global_position + swing_dir * max_len * 0.5
	# 动画: 工具沿 swing_dir 突刺再收回
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null and held.has_method("play_thrust"):
		held.play_thrust(swing_dir.angle())
	elif held != null and held.has_method("play_swing"):
		held.play_swing()
	SfxBank.play("swing", 0.10)
	# 伤害 = sword_damage * hunger_mult * damage_mult * 0.8
	var base: int = _sword_damage()
	if base <= 0:
		return
	var hunger: Node = get_parent().get_node_or_null("PlayerHunger")
	var hunger_mult: float = 1.0 if hunger == null else hunger.get_attack_multiplier()
	var dmg_mult: float = _tool_damage_mult()
	if dmg_mult <= 0.0:
		return
	var damage: int = max(1, int(round(float(base) * hunger_mult * dmg_mult * THRUST_DAMAGE_MULT)))
	# 矩形判定: 沿 swing_dir 长 max_len, 半宽 THRUST_HALF_WIDTH; 找最近的目标
	var best: Node2D = null
	var best_dist: float = INF
	var perp_axis: Vector2 = Vector2(-swing_dir.y, swing_dir.x)
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn == null:
				continue
			var local: Vector2 = sn.global_position - player.global_position
			var along: float = local.dot(swing_dir)
			if along < 0.0 or along > max_len:
				continue
			var perp: float = abs(local.dot(perp_axis))
			if perp > THRUST_HALF_WIDTH:
				continue
			if along < best_dist:
				best_dist = along
				best = sn
	if best != null and best.has_method("take_damage"):
		best.take_damage(damage, player.global_position, _thrust_knockback())
	if player.has_method("shake"):
		player.shake(2.0)


func _sweep_sword() -> void:
	_attack_cooldown = SWORD_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	# 鼠标方向 (测试用 override > 真实输入)
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var to_mouse: Vector2 = (mouse_world - player.global_position)
	if to_mouse.length() < 0.001:
		to_mouse = Vector2(1.0 if player.has_method("facing_dir") and player.facing_dir() > 0 else -1.0, 0)
	var swing_dir: Vector2 = to_mouse.normalized()
	# 命中中心点 = 玩家中心 + 方向 × 半个射程
	var center: Vector2 = player.global_position + swing_dir * SWORD_RANGE_PX * 0.5
	last_swing_center = center
	# 手持物品挥摆动画 (角度跟随鼠标; Task 2 实现)
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null:
		if held.has_method("play_swing_directional"):
			held.play_swing_directional(swing_dir.angle())
		elif held.has_method("play_swing"):
			held.play_swing()
	SfxBank.play("swing", 0.10)
	var damage: int = _effective_sword_damage()
	if damage <= 0:
		return
	# 命中判定: 圆形范围, 半径 SWORD_RANGE_PX * 0.7
	# 目标: slimes (含 zombies, zombie 也 add_to_group("slimes")) + animals (牛/羊/猪)
	# dict 去重防同节点多组双击 (虽然现在 zombie 已 dedupe, 加 animals 后保险用 dict)
	var hit_targets: Dictionary = {}
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			hit_targets[s.get_instance_id()] = s
	for target in hit_targets.values():
		var sn := target as Node2D
		if sn == null:
			continue
		# T7: 弧形 90° 判定 (前方 ±45°) 替换原圆形, 避免身后误伤
		if _is_in_swing_arc(sn.global_position, player.global_position, swing_dir):
			if target.has_method("take_damage"):
				target.take_damage(damage, player.global_position, _sweep_knockback())
	# 月牙挥击拖尾 (Task 3 重写)
	_spawn_swing_arc(player.global_position, swing_dir)
	if player.has_method("shake"):
		player.shake(3.0)


func _spawn_swing_arc(origin: Vector2, dir: Vector2) -> void:
	# 月牙扇形拖尾 (细窄风格): 沿 dir 方向 ±35°, 外径 24px 内径 16px,
	# 整体偏小贴近剑刃, 不再遮挡玩家.
	var outer_r: float = 24.0
	var inner_r: float = 16.0
	var half_spread: float = deg_to_rad(35.0)
	var steps: int = 10
	var base_angle: float = dir.angle()
	var poly := Polygon2D.new()
	poly.global_position = origin
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var a: float = base_angle - half_spread + (half_spread * 2.0) * t
		pts.append(Vector2(cos(a), sin(a)) * outer_r)
	for i in range(steps + 1):
		var t2: float = float(steps - i) / float(steps)
		var a2: float = base_angle - half_spread + (half_spread * 2.0) * t2
		pts.append(Vector2(cos(a2), sin(a2)) * inner_r)
	poly.polygon = pts
	# 偏蓝白透明感, 像金属挥击残影
	poly.color = Color(0.92, 0.96, 1.0, 0.55)
	var parent: Node = get_tree().get_first_node_in_group("effects_root")
	if parent == null:
		parent = get_parent()
	parent.add_child(poly)
	var tween := poly.create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, SWORD_ARC_LIFETIME)
	tween.tween_callback(poly.queue_free)


func _inventory_node() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("PlayerInventory")


func player_tile() -> Vector2i:
	var parent: Node2D = get_parent() as Node2D
	var foot: Vector2 = parent.global_position
	return Vector2i(int(floor(foot.x / TILE_SIZE)), int(floor(foot.y / TILE_SIZE)))


func in_reach(tile: Vector2i) -> bool:
	if tile == INVALID_TILE:
		return false
	var pt: Vector2i = player_tile()
	return abs(tile.x - pt.x) <= REACH_TILES and abs(tile.y - pt.y) <= REACH_TILES
