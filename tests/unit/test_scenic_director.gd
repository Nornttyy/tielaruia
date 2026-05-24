extends GutTest

const ScenicDirector = preload("res://scripts/world/scenic_director.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

const TILE_SIZE := 16


func test_compute_cave_t_at_surface_is_zero():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 玩家正好在地表 → cave_t = 0
	var t: float = ScenicDirector.compute_cave_t(surface_y_px)
	assert_eq(t, 0.0, "地表 cave_t = 0")


func test_compute_cave_t_above_surface_is_zero():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 玩家在地表之上 (Y 更小) → 仍 0
	var t: float = ScenicDirector.compute_cave_t(surface_y_px - 100.0)
	assert_eq(t, 0.0, "地表上方 cave_t = 0")


func test_compute_cave_t_in_dirt_layer_is_zero():
	# 泥土层 (地表下 1-6 格) cave_t 应仍 = 0, 矿洞背景不该露脸
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var t_3tile: float = ScenicDirector.compute_cave_t(surface_y_px + 3 * TILE_SIZE)
	assert_eq(t_3tile, 0.0, "泥土层中部 cave_t = 0")
	var t_6tile: float = ScenicDirector.compute_cave_t(surface_y_px + 6 * TILE_SIZE)
	assert_eq(t_6tile, 0.0, "刚刚到石头层边界 cave_t = 0")


func test_compute_cave_t_deep_stone_is_one():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 地表下 20 tile (远超 6+8=14) → 完全进入矿洞
	var t: float = ScenicDirector.compute_cave_t(surface_y_px + 20 * TILE_SIZE)
	assert_eq(t, 1.0, "深处 cave_t = 1")


func test_compute_cave_t_mid_transition_is_half():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 地表下 10 tile = 进入石头层 4 tile (一半深, transition=8 tile) → cave_t = 0.5
	var t: float = ScenicDirector.compute_cave_t(surface_y_px + 10 * TILE_SIZE)
	assert_almost_eq(t, 0.5, 0.05, "石头层中部 cave_t ~ 0.5")


# Mock world with set player position
class MockPlayer:
	extends Node2D
	# 直接通过 global_position 暴露


class MockWorld:
	extends Node
	var _player: MockPlayer
	func _init(player: MockPlayer) -> void:
		_player = player
	func get_player() -> Node:
		return _player


func test_apply_cave_t_changes_layer_alpha():
	# 准备 fake layer (Node2D 有 modulate) 测试 alpha 被改
	var fake_mtn := Node2D.new()
	add_child_autofree(fake_mtn)
	var fake_cave := Node2D.new()
	add_child_autofree(fake_cave)
	var player := MockPlayer.new()
	add_child_autofree(player)
	var world := MockWorld.new(player)
	add_child_autofree(world)
	var sd: ScenicDirector = ScenicDirector.new()
	add_child_autofree(sd)
	sd.setup({
		"world": world,
		"mountains": fake_mtn,
		"cave_bg": fake_cave,
	})
	# 把玩家挪到地下深处 (穿透泥土层 + 全部 transition)
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	player.global_position = Vector2(0, surface_y_px + 25 * TILE_SIZE)
	await wait_frames(2)
	# 山 alpha 应变小, 矿洞 alpha 应变大
	assert_lt(fake_mtn.modulate.a, 0.2, "深矿洞时山几乎隐形")
	assert_almost_eq(fake_cave.modulate.a, 1.0, 0.05, "深矿洞时矿洞背景全显")
