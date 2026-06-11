extends GutTest

const ScenicDirector = preload("res://scripts/world/scenic_director.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

const TILE_SIZE := 12  # 跟着 scenic_director.gd 走 (commit 6af9aa5: 16→12)


# === 静态 compute (用 depth_tiles 直接算) ===

func test_shallow_t_at_surface_is_zero():
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(0.0), 0.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(0.0), 0.0, 0.001)


func test_above_surface_both_zero():
	# 负深度 (玩家在地表之上) → 0
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(-5.0), 0.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(-5.0), 0.0, 0.001)


func test_within_10_tiles_both_zero():
	# 地表下 5 格 - 仍然 0 (起点是 10 格)
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(5.0), 0.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(5.0), 0.0, 0.001)
	# 地表下 10 格 - 刚到阈值 = 0 (>10 才开始)
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(10.0), 0.0, 0.001)


func test_shallow_transition():
	# 12 格深 = 10 + 2, transition 4 格, shallow_t = 2/4 = 0.5
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(12.0), 0.5, 0.01)
	# 14 格深 = 浅 transition 末端, shallow_t = 1
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(14.0), 1.0, 0.001)
	# 14 格深时 deep_t 仍 = 0 (deep 要 >30)
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(14.0), 0.0, 0.001)


func test_mid_zone_only_shallow():
	# 20 格深: shallow_t = 1, deep_t = 0 (只看远岩壁不看钟乳石/水晶)
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(20.0), 1.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(20.0), 0.0, 0.001)


func test_deep_transition():
	# 33 格深 = 30 + 3, transition 6 格, deep_t = 3/6 = 0.5
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(33.0), 0.5, 0.01)
	# 36 格深 = 深 transition 末端, deep_t = 1
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(36.0), 1.0, 0.001)


func test_deep_zone_both_one():
	# 50 格深: 两个都 = 1
	assert_almost_eq(ScenicDirector.compute_shallow_t_from_depth(50.0), 1.0, 0.001)
	assert_almost_eq(ScenicDirector.compute_deep_t_from_depth(50.0), 1.0, 0.001)


# === 兼容旧接口 (用 player_y_px) ===

func test_legacy_compute_shallow_t_uses_average_surface():
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	# 玩家正好在 (平均) 地表 → cave_t = 0
	assert_almost_eq(ScenicDirector.compute_shallow_t(surface_y_px), 0.0, 0.001)
	# 30 格深 (远超 10+4=14) → shallow_t = 1
	assert_almost_eq(
		ScenicDirector.compute_shallow_t(surface_y_px + 30 * TILE_SIZE),
		1.0, 0.001
	)


# === 集成: 用 mock player + world ===

class MockPlayer:
	extends Node2D


class MockChunk:
	extends RefCounted
	# SD 用 chunk.surfaces[lx] 取原始地表 y_tile.
	var surfaces: Array = []
	func _init(p_surf_y: int = 100) -> void:
		# 一列就够, SD 用 local_x=0
		surfaces.resize(64)
		surfaces.fill(p_surf_y)


class MockChunkManager:
	extends RefCounted
	var _chunk: MockChunk
	func _init(p_chunk: MockChunk) -> void:
		_chunk = p_chunk
	# 返回 Variant (不写 -> MockChunk 否则跟 SD 的 鸭子类型 调用对不上)
	func get_chunk(_cx: int):
		return _chunk


class MockWorld:
	extends Node
	var _player: MockPlayer
	var chunk_manager: MockChunkManager
	func _init(player: MockPlayer, cm: MockChunkManager) -> void:
		_player = player
		chunk_manager = cm
	func get_player() -> Node:
		return _player


func test_apply_depths_with_player_below_surface():
	# 模拟 surface_y_tile=100, 玩家在 y_tile=140 (40 格深, 深区)
	var fake_chunk := MockChunk.new(100)
	var fake_cm := MockChunkManager.new(fake_chunk)
	var player := MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, 140 * TILE_SIZE)
	var world := MockWorld.new(player, fake_cm)
	add_child_autofree(world)
	# 准备 fake layers (Node2D 有 modulate)
	var fake_mtn := Node2D.new()
	add_child_autofree(fake_mtn)
	var fake_cave := Node2D.new()
	add_child_autofree(fake_cave)
	# SD setup
	var sd: ScenicDirector = ScenicDirector.new()
	add_child_autofree(sd)
	sd.setup({
		"world": world,
		"mountains": fake_mtn,
		"cave_bg": fake_cave,
	})
	sd._process(0.016)  # 直接调, 不靠帧 (wait_frames 在 GUT inner class 场景下不可靠)
	# 玩家 40 格深 (远超 30+6=36), shallow_t=1, deep_t=1
	# 山 alpha = 1 - 1*0.85 = 0.15, cave_bg alpha = 1
	assert_almost_eq(fake_mtn.modulate.a, 0.15, 0.05, "深处山几乎不见")
	assert_almost_eq(fake_cave.modulate.a, 1.0, 0.05, "深处矿洞全显")


# 玩家 5 格深 (浅区还没到 10) → 两个 t 都 0, 矿洞 alpha=0 山 alpha=1
# 注: 不用 wait_frames (GUT 帧调度跟自动释放 inner class 配合时不稳).
# 直接调 sd._process(0.016) — 走相同 logic, 但同步, 测试可靠.
func test_apply_depths_player_in_shallow_zone_no_cave():
	var fake_chunk := MockChunk.new(100)
	var fake_cm := MockChunkManager.new(fake_chunk)
	var player := MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, 105 * TILE_SIZE)
	var world := MockWorld.new(player, fake_cm)
	add_child_autofree(world)
	var fake_mtn := Node2D.new()
	add_child_autofree(fake_mtn)
	var fake_cave := Node2D.new()
	add_child_autofree(fake_cave)
	var sd: ScenicDirector = ScenicDirector.new()
	add_child_autofree(sd)
	sd.setup({
		"world": world,
		"mountains": fake_mtn,
		"cave_bg": fake_cave,
	})
	sd._process(0.016)  # 直接调, 不靠帧
	assert_almost_eq(fake_mtn.modulate.a, 1.0, 0.05, "上 10 格山仍全显")
	assert_almost_eq(fake_cave.modulate.a, 0.0, 0.05, "上 10 格矿洞 0 不见")


# 战斗房: 世界空 (surfaces 全 0) 会误判玩家深埋地底 → 背景变地底. 对战房该强制天空背景。
func test_pvp_forces_surface_background():
	var prev_mode = NetworkManager.room_mode
	NetworkManager.room_mode = "pvp"
	# surface_y=100, 玩家 y=140 (正常算 40 格深 = 深区), 但对战房该当地表 (depth 0)
	var fake_chunk := MockChunk.new(100)
	var fake_cm := MockChunkManager.new(fake_chunk)
	var player := MockPlayer.new()
	add_child_autofree(player)
	player.global_position = Vector2(0, 140 * TILE_SIZE)
	var world := MockWorld.new(player, fake_cm)
	add_child_autofree(world)
	var fake_mtn := Node2D.new()
	add_child_autofree(fake_mtn)
	var fake_cave := Node2D.new()
	add_child_autofree(fake_cave)
	var sd: ScenicDirector = ScenicDirector.new()
	add_child_autofree(sd)
	sd.setup({"world": world, "mountains": fake_mtn, "cave_bg": fake_cave})
	sd._process(0.016)
	assert_almost_eq(fake_cave.modulate.a, 0.0, 0.05, "对战房矿洞背景该 0 (天空背景, 不显地底)")
	assert_almost_eq(fake_mtn.modulate.a, 1.0, 0.05, "对战房山/地表层全显")
	NetworkManager.room_mode = prev_mode
