# 玩家交互：鼠标瞄准、距离检查、挖放进度。
extends Node2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const VillagerLines = preload("res://scripts/npc/villager_lines.gd")
const TILE_SIZE := 16
const REACH_TILES := 4
const INVALID_TILE := Vector2i(-1, -1)

# Tile 硬度（累计 tool_speed*delta 达此值挖完，单位"秒"）
const _HARDNESS := {
	Tiles.GRASS: 0.3,
	Tiles.DIRT: 0.3,
	Tiles.SAND: 0.3,
	Tiles.LEAVES: 0.2,
	Tiles.PLANKS: 0.3,
	Tiles.WORKBENCH: 0.5,
	Tiles.DOOR: 0.5,
	Tiles.LOG: 0.6,
	Tiles.STONE: 1.2,
	Tiles.LOG_TOP: 0.6,
	Tiles.LOG_ROOT_L: 0.4,
	Tiles.LOG_ROOT_R: 0.4,
	Tiles.BRANCH_L: 0.4,
	Tiles.BRANCH_R: 0.4,
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
const SWORD_RANGE_PX := 36.0
const SWORD_COOLDOWN := 0.3
const SWORD_ARC_LIFETIME := 0.18
var _attack_cooldown: float = 0.0

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


func _physics_process(delta: float) -> void:
	# E 一键合成: 工作台旁开 3x3, 否则 2x2; 已开则关
	if Input.is_action_just_pressed("interact"):
		_try_open_workbench_or_close()
	# 其余动作面板开则跳过
	if _crafting_open():
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	# 持剑 LMB → 攻击, 否则 LMB → 挖
	if _current_tool_kind() == "sword":
		_reset_mining()  # 切到剑时清挖进度
		var primary_pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed and _attack_cooldown <= 0.0:
			_swing_sword()
	else:
		_update_mining(delta)
	_update_eat_or_place(delta)


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
	if tile != _mining_target:
		_clear_crack(_mining_target)
		_mining_target = tile
		_mining_progress = 0.0
		_mining_swing_t = 0.0
	_mining_progress += _tool_speed(tool_kind, tid) * delta
	# 挥镐/挥斧动画: 每 0.35s 挥一次
	_mining_swing_t -= delta
	if _mining_swing_t <= 0.0:
		_mining_swing_t = 0.35
		var player_node: Node = get_parent()
		var held: Node = null if player_node == null else player_node.get_node_or_null("HeldItem")
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
	# axe 砍 LOG: wood ×3, stone ×4
	if tool_kind == "axe" and tid == Tiles.LOG:
		var tier := _current_tool_tier()
		return 4.0 if tier >= 2 else 3.0
	# pickaxe 挖 STONE: wood ×1, stone ×1.5
	if tool_kind == "pickaxe" and tid == Tiles.STONE:
		var tier := _current_tool_tier()
		return 1.5 if tier >= 2 else 1.0
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
	var mult: float = 1.0 if hunger == null else hunger.get_attack_multiplier()
	return max(1, int(round(float(base) * mult)))


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


func _swing_sword() -> void:
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
		if center.distance_to(sn.global_position) <= SWORD_RANGE_PX * 0.7:
			if target.has_method("take_damage"):
				target.take_damage(damage, player.global_position)
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
