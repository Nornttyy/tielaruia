extends GutTest

const ScenicDirector = preload("res://scripts/world/scenic_director.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

const TILE_SIZE := 16


func test_shallow_t_at_surface_is_zero():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	assert_almost_eq(ScenicDirector.compute_shallow_t(surface_y_px), 0.0, 0.001, "地表 shallow_t = 0")
	assert_almost_eq(ScenicDirector.compute_deep_t(surface_y_px), 0.0, 0.001, "地表 deep_t = 0")


func test_above_surface_both_zero():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	assert_almost_eq(ScenicDirector.compute_shallow_t(surface_y_px - 100.0), 0.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t(surface_y_px - 100.0), 0.0, 0.001)


func test_dirt_layer_both_zero():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 地表下 3 格 (泥土层) — 两个 t 都应 = 0
	assert_almost_eq(ScenicDirector.compute_shallow_t(surface_y_px + 3 * TILE_SIZE), 0.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t(surface_y_px + 3 * TILE_SIZE), 0.0, 0.001)


func test_shallow_stone_only_rocks_visible():
	# 地表下 10 格 = 进石头 4 格. shallow_t = 4/8 = 0.5. deep_t 还没起步 = 0.
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var y: float = surface_y_px + 10 * TILE_SIZE
	assert_almost_eq(ScenicDirector.compute_shallow_t(y), 0.5, 0.02, "浅石头层 shallow_t = 0.5")
	assert_almost_eq(ScenicDirector.compute_deep_t(y), 0.0, 0.001, "浅石头层 deep_t 仍 = 0 (只看岩壁)")


func test_shallow_full_at_14_tiles():
	# 14 格深 = 浅 transition 末端, shallow_t = 1, deep_t 刚开始 = 0
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var y: float = surface_y_px + 14 * TILE_SIZE
	assert_almost_eq(ScenicDirector.compute_shallow_t(y), 1.0, 0.001, "14 格深 shallow_t = 1")
	assert_almost_eq(ScenicDirector.compute_deep_t(y), 0.0, 0.001, "14 格 deep_t 刚开始 = 0")


func test_deep_stone_both_one():
	# 30 格深 = 远超 14+10=24 → 两个都 = 1
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var y: float = surface_y_px + 30 * TILE_SIZE
	assert_almost_eq(ScenicDirector.compute_shallow_t(y), 1.0, 0.001, "深处 shallow_t = 1")
	assert_almost_eq(ScenicDirector.compute_deep_t(y), 1.0, 0.001, "深处 deep_t = 1")


func test_deep_t_mid_transition_is_half():
	# 19 格深 = 进 deep 5 格, deep_t = 5/10 = 0.5
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var y: float = surface_y_px + 19 * TILE_SIZE
	assert_almost_eq(ScenicDirector.compute_deep_t(y), 0.5, 0.02, "deep 中部 deep_t = 0.5")


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
	# 把玩家挪到地下深处 (穿透泥土层 + 全部两阶段 transition)
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	player.global_position = Vector2(0, surface_y_px + 30 * TILE_SIZE)
	await wait_frames(2)
	# 山 alpha 应变小, 矿洞 alpha 应变大
	assert_lt(fake_mtn.modulate.a, 0.2, "深矿洞时山几乎隐形")
	assert_almost_eq(fake_cave.modulate.a, 1.0, 0.05, "深矿洞时矿洞背景全显")
