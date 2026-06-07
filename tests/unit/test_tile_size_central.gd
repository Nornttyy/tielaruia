# TILE_SIZE 集中到 ChunkConstants, 值 = 6, 各文件引用同一来源。
extends GutTest


func test_chunk_constants_tile_size_is_6() -> void:
	assert_eq(ChunkConstants.TILE_SIZE, 6, "ChunkConstants.TILE_SIZE 应 = 6")


func test_representative_files_reference_central() -> void:
	# 抽查几个文件的 TILE_SIZE 都 = 6 (引用到同一来源)
	assert_eq(load("res://scripts/world/world.gd").TILE_SIZE, 6)
	assert_eq(load("res://scripts/world/water_sim.gd").TILE_SIZE, 6)
	assert_eq(load("res://scripts/entities/slime.gd").TILE_SIZE, 6)
	assert_eq(load("res://scripts/player/player_controller.gd").TILE_SIZE, 6)
