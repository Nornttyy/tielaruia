# 世界根：生成 tile 数据 → 应用到 TileMapLayer → 放置玩家 → 重算天光。
extends Node2D

const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")

const WORLD_WIDTH := 1024
const WORLD_HEIGHT := 256
const TILE_SIZE := 16

@export var world_seed: int = 20260517

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entities_root: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D

var spawn_point: Vector2i
var _tiles: Array  # tiles[x][y] = Tiles const


func _ready() -> void:
	terrain_layer.tile_set = TileSetBuilder.build()
	terrain_layer.add_to_group("terrain_layer")
	$EffectsRoot.add_to_group("effects_root")
	_generate_and_apply()
	_spawn_player()
	SkyLightGrid.recompute_from(_tiles)


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
	player.position = Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE + TILE_SIZE
	)
	entities_root.add_child(player)
	camera.reparent(player)
	camera.position = Vector2.ZERO


func get_player() -> CharacterBody2D:
	for child in entities_root.get_children():
		if child is CharacterBody2D:
			return child
	return null


func get_crack_overlay() -> Node:
	return $CrackOverlay
