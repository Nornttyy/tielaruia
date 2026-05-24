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


func test_compute_cave_t_deep_is_one():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 地表下 15 tile → 完全进入矿洞 (transition 是 10 tile)
	var t: float = ScenicDirector.compute_cave_t(surface_y_px + 15 * TILE_SIZE)
	assert_eq(t, 1.0, "深处 cave_t = 1")


func test_compute_cave_t_mid_transition_is_half():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 地表下 5 tile (一半深) → cave_t = 0.5
	var t: float = ScenicDirector.compute_cave_t(surface_y_px + 5 * TILE_SIZE)
	assert_almost_eq(t, 0.5, 0.05, "中间深度 cave_t ~ 0.5")


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
	# 把玩家挪到地下深处
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	player.global_position = Vector2(0, surface_y_px + 20 * TILE_SIZE)
	await wait_frames(2)
	# 山 alpha 应变小, 矿洞 alpha 应变大
	assert_lt(fake_mtn.modulate.a, 0.2, "深矿洞时山几乎隐形")
	assert_almost_eq(fake_cave.modulate.a, 1.0, 0.05, "深矿洞时矿洞背景全显")
