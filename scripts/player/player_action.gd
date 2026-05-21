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
}

# 测试注入
var aim_override: Variant = null
var primary_override: Variant = null     # null = 真实输入；bool = 强制
var place_override: bool = false
var secondary_held_override: Variant = null  # null = 真实输入；bool = 强制（测试）

# Mining 状态
var _mining_target: Vector2i = INVALID_TILE
var _mining_progress: float = 0.0

# 战斗
const SWORD_RANGE_PX := 36.0
const SWORD_COOLDOWN := 0.3
const SWORD_ARC_LIFETIME := 0.18
var _attack_cooldown: float = 0.0

# 进食状态
const EAT_DURATION_SEC := 1.0
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
		if Input.is_action_pressed("primary") and _attack_cooldown <= 0.0:
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
	_mining_progress += _tool_speed(tool_kind, tid) * delta
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
	terrain.set_cell(tile, -1)
	var world: Node = terrain.get_parent()
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	SkyLightGrid.invalidate_column(tile.x)
	# P1.5 hook: 块破碎粒子
	Effects.spawn_block_break(tile, tid)
	var drops: Dictionary = Tiles.drops_for(tid, tool_kind)
	for item_id in drops:
		for _i in drops[item_id]:
			_spawn_drop(item_id, tile)


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
	# 目标必须为空气
	if terrain.get_cell_source_id(tile) != -1:
		return false
	# 不与玩家碰撞框重叠（玩家占 2 tile 高：脚底 tile 和上方 tile）
	var pt: Vector2i = player_tile()
	if tile == pt or tile == pt - Vector2i(0, 1):
		return false
	# 上下左右至少要有一个相邻方块（防空中漂浮）
	var has_neighbor: bool = false
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if terrain.get_cell_source_id(tile + offset) != -1:
			has_neighbor = true
			break
	if not has_neighbor:
		return false
	var def = ItemDB.get_def(slot.item_id)
	terrain.set_cell(tile, def.placeable_tile_id, Vector2i.ZERO)
	var world: Node = terrain.get_parent()
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, def.placeable_tile_id)
	inv.consume_current(1)
	SkyLightGrid.invalidate_column(tile.x)
	# P1.5 hook: 放下弹动
	Effects.spawn_place_bounce(tile, def.placeable_tile_id)
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
	# wood tier 1 → 4; stone tier 2 → 7
	return 7 if def.tool_tier >= 2 else 4


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

	var held: bool = (secondary_held_override == true) if secondary_held_override != null \
			else Input.is_action_pressed("secondary")
	var just: bool = secondary_held_override == null and Input.is_action_just_pressed("secondary")

	var inv: Node = _inventory_node()
	var slot = null if inv == null else inv.current_hotbar_slot()
	var holding_food: bool = slot != null and ItemDB.is_food(slot.item_id)
	var hunger: Node = get_parent().get_node_or_null("PlayerHunger")

	# 持食物 + 按住 + 没吃饱 → 进入/保持 eating
	if holding_food and held and hunger != null and int(hunger.current) < hunger.MAX:
		if _eat_item_id != slot.item_id:
			_eat_item_id = slot.item_id
			_eat_t = 0.0
		_eat_t += delta
		if _eat_t >= EAT_DURATION_SEC:
			_eat_t = 0.0
			hunger.consume(ItemDB.food_fill(slot.item_id))
			inv.consume_current(1)
		return

	# 取消进食
	if _eat_t > 0.0:
		_eat_t = 0.0
		_eat_item_id = ""

	# 退回放置逻辑（与原行为一致）
	if just:
		try_place()


func _swing_sword() -> void:
	_attack_cooldown = SWORD_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var damage: int = _effective_sword_damage()
	if damage <= 0:
		return
	var facing: int = 1
	if player.has_method("facing_dir"):
		facing = player.facing_dir()
	# 攻击中心点: 玩家身前 半个 SWORD_RANGE
	var center: Vector2 = player.global_position + Vector2(facing * SWORD_RANGE_PX * 0.5, -8.0)
	# 找范围内所有 slime
	for s in get_tree().get_nodes_in_group("slimes"):
		var sn := s as Node2D
		if sn == null:
			continue
		if center.distance_to(sn.global_position) <= SWORD_RANGE_PX * 0.7:
			if s.has_method("take_damage"):
				s.take_damage(damage, player.global_position)
	# 挥剑视觉: 一个白色弧线 sprite, 0.18s 淡出
	_spawn_swing_arc(player.global_position + Vector2(facing * 18.0, -10.0), facing)
	if player.has_method("shake"):
		player.shake(3.0)


func _spawn_swing_arc(pos: Vector2, facing: int) -> void:
	var arc := Line2D.new()
	arc.width = 3.0
	arc.default_color = Color(1, 1, 1, 0.9)
	arc.global_position = pos
	# 简单弧线: 3 个点构成 ⌒ 形, 朝向 facing
	if facing > 0:
		arc.add_point(Vector2(-6, 8))
		arc.add_point(Vector2(12, 0))
		arc.add_point(Vector2(-6, -10))
	else:
		arc.add_point(Vector2(6, 8))
		arc.add_point(Vector2(-12, 0))
		arc.add_point(Vector2(6, -10))
	var parent: Node = get_tree().get_first_node_in_group("effects_root")
	if parent == null:
		parent = get_parent()
	parent.add_child(arc)
	var tween := arc.create_tween()
	tween.tween_property(arc, "modulate:a", 0.0, SWORD_ARC_LIFETIME)
	tween.tween_callback(arc.queue_free)


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
