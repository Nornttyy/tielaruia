# 世界根：生成 tile 数据 → 应用到 TileMapLayer → 放置玩家 → 重算天光。
extends Node2D

const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")
const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const MAX_SLIMES := 4
const SLIME_SPAWN_INTERVAL := 6.0
const SLIME_SPAWN_RANGE_MIN := 12  # tiles
const SLIME_SPAWN_RANGE_MAX := 22

const WORLD_WIDTH := 1024
const WORLD_HEIGHT := 256
const TILE_SIZE := 16

@export var world_seed: int = 20260517

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entities_root: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D

var spawn_point: Vector2i
var _tiles: Array  # tiles[x][y] = Tiles const
var _slime_spawn_timer: float = 3.0  # 启动后 3s 开始刷


func _ready() -> void:
	terrain_layer.tile_set = TileSetBuilder.build()
	terrain_layer.add_to_group("terrain_layer")
	$EffectsRoot.add_to_group("effects_root")
	_generate_and_apply()
	_spawn_player()
	SkyLightGrid.recompute_from(_tiles)


func _process(delta: float) -> void:
	_slime_spawn_timer -= delta
	if _slime_spawn_timer <= 0.0:
		_slime_spawn_timer = SLIME_SPAWN_INTERVAL
		_try_spawn_slime()


func _try_spawn_slime() -> void:
	var slimes := get_tree().get_nodes_in_group("slimes")
	if slimes.size() >= MAX_SLIMES:
		return
	var player := get_player()
	if player == null:
		return
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	# 随机 10 次找一个站得住脚的地表位置
	for _i in 10:
		var sign_x: int = 1 if randf() < 0.5 else -1
		var dx: int = sign_x * randi_range(SLIME_SPAWN_RANGE_MIN, SLIME_SPAWN_RANGE_MAX)
		var cand_x: int = px + dx
		if cand_x < 1 or cand_x >= WORLD_WIDTH - 1:
			continue
		# 找该列地表 (从顶往下第一个非 AIR tile)
		var surf_y: int = -1
		for y in WORLD_HEIGHT:
			if _tiles[cand_x][y] != Tiles.AIR:
				surf_y = y
				break
		if surf_y <= 0:
			continue
		# 地表上方一格必须是空气 (有站位)
		if _tiles[cand_x][surf_y - 1] != Tiles.AIR:
			continue
		# 不长在沙漠正中: GRASS 优先
		if _tiles[cand_x][surf_y] == Tiles.BEDROCK:
			continue
		var slime := SlimeScene.instantiate()
		slime.global_position = Vector2(
			cand_x * TILE_SIZE + TILE_SIZE / 2.0,
			(surf_y - 1) * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(slime)
		return


func _generate_and_apply() -> void:
	var data := WorldGenerator.generate(world_seed, WORLD_WIDTH, WORLD_HEIGHT)
	_tiles = data.tiles
	spawn_point = data.spawn_point
	for x in WORLD_WIDTH:
		for y in WORLD_HEIGHT:
			var tile_id: int = _tiles[x][y]
			if tile_id == Tiles.AIR:
				continue
			terrain_layer.set_cell(Vector2i(x, y), tile_id, Vector2i.ZERO)


func _spawn_player() -> void:
	var player := PlayerScene.instantiate()
	player.position = _spawn_world_pos()
	entities_root.add_child(player)
	camera.reparent(player)
	camera.position = Vector2.ZERO
	# 连死亡信号
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("died"):
		hp.died.connect(_on_player_died)


func _spawn_world_pos() -> Vector2:
	return Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE + TILE_SIZE
	)


func _on_player_died() -> void:
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


func _set_tile(x: int, y: int, tile_id: int) -> void:
	if x < 0 or x >= WORLD_WIDTH or y < 0 or y >= WORLD_HEIGHT:
		return
	_tiles[x][y] = tile_id
