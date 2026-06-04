# 回归测试: "进世界偶发 bug" 三症状的修复验证.
# 症状: (1) 丢三件套 (2) 背景显示成地底 (3) 小地图显示地底 — 根因都在"玩家/chunk 就绪前的窗口期".
# 修复: ScenicDirector 未加载 chunk 当地表 / minimap 跳过未加载 chunk / save 玩家没就绪不写 / autosave 推迟.
extends GutTest

const ScenicDirector = preload("res://scripts/world/scenic_director.gd")
const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const MinimapData = preload("res://scripts/world/minimap_data.gd")
const MainScene = preload("res://scenes/main.tscn")
const TILE := 12


# 假 ChunkManager: 鸭子类型. is_chunk_loaded 报告某 chunk 是否在 loaded 里 (修复 B 靠它).
class FakeChunkManager:
	extends Node
	var loaded: Dictionary = {}
	func get_chunk(cx: int):
		return loaded.get(cx, null)
	func is_chunk_loaded(cx: int) -> bool:
		return loaded.has(cx)
	func get_tile(world_x: int, world_y: int) -> int:
		var cx: int = Chunk.chunk_x_of(world_x)
		if not loaded.has(cx):
			return Tiles.AIR
		var lx: int = Chunk.local_x_of(world_x)
		return loaded[cx].get_tile(lx, world_y)


class FakeWorld:
	extends Node2D
	var chunk_manager: Node = null
	var world_seed: int = 0
	var _player: Node2D = null
	func get_player() -> Node2D:
		return _player


func _make_chunk_with_surface(cx: int, surf_y: int) -> Chunk:
	var c := Chunk.new(cx)
	c.init_empty(ChunkConstants.WORLD_HEIGHT)
	for lx in ChunkConstants.CHUNK_WIDTH:
		c.surfaces[lx] = surf_y
	return c


# ===== 症状 2 (背景地底) 修复: chunk 未加载 → 当地表 (depth 0), 不显矿洞 =====

func test_unloaded_chunk_surface_player_stays_sky() -> void:
	var fcm := FakeChunkManager.new(); add_child_autofree(fcm)
	var fw := FakeWorld.new(); add_child_autofree(fw)
	fw.chunk_manager = fcm
	var player := Node2D.new(); add_child_autofree(player)
	player.global_position = Vector2(600 * TILE + 6, 126 * TILE)   # 谷地地表, chunk 9 未加载
	fw._player = player
	var sd := ScenicDirector.new(); add_child_autofree(sd)
	sd.setup({"world": fw})
	var depth: float = sd._player_depth_below_surface_tiles()
	var shallow_t: float = ScenicDirector.compute_shallow_t_from_depth(depth)
	gut.p("[fix-A] unloaded chunk surface player: depth=%.1f shallow_t=%.2f" % [depth, shallow_t])
	assert_almost_eq(depth, 0.0, 0.001, "chunk 未加载 → 当地表 depth=0 (不再用假地表115算大深度)")
	assert_almost_eq(shallow_t, 0.0, 0.001, "→ 不显矿洞背景 (保持天空)")


func test_unloaded_chunk_deep_player_no_full_cave() -> void:
	var fcm := FakeChunkManager.new(); add_child_autofree(fcm)
	var fw := FakeWorld.new(); add_child_autofree(fw)
	fw.chunk_manager = fcm
	var player := Node2D.new(); add_child_autofree(player)
	player.global_position = Vector2(600 * TILE + 6, 160 * TILE)
	fw._player = player
	var sd := ScenicDirector.new(); add_child_autofree(sd)
	sd.setup({"world": fw})
	var depth: float = sd._player_depth_below_surface_tiles()
	assert_almost_eq(depth, 0.0, 0.001, "chunk 未加载 → depth=0, 不显钟乳石/水晶")


func test_loaded_chunk_surface_player_zero_depth() -> void:
	var fcm := FakeChunkManager.new(); add_child_autofree(fcm)
	var fw := FakeWorld.new(); add_child_autofree(fw)
	fw.chunk_manager = fcm
	var player := Node2D.new(); add_child_autofree(player)
	player.global_position = Vector2(600 * TILE + 6, 135 * TILE)
	fw._player = player
	fcm.loaded[9] = _make_chunk_with_surface(9, 135)
	var sd := ScenicDirector.new(); add_child_autofree(sd)
	sd.setup({"world": fw})
	var depth: float = sd._player_depth_below_surface_tiles()
	assert_almost_eq(depth, 0.0, 0.001, "chunk 加载后地表玩家 depth=0")


# 修复不能误伤"真在地下"的正常体验: chunk 加载 + 玩家在地表下深处 → 正常显矿洞
func test_loaded_chunk_deep_player_shows_cave() -> void:
	var fcm := FakeChunkManager.new(); add_child_autofree(fcm)
	var fw := FakeWorld.new(); add_child_autofree(fw)
	fw.chunk_manager = fcm
	var player := Node2D.new(); add_child_autofree(player)
	player.global_position = Vector2(600 * TILE + 6, 175 * TILE)   # 地表135下40格
	fw._player = player
	fcm.loaded[9] = _make_chunk_with_surface(9, 135)
	var sd := ScenicDirector.new(); add_child_autofree(sd)
	sd.setup({"world": fw})
	var depth: float = sd._player_depth_below_surface_tiles()
	var shallow_t: float = ScenicDirector.compute_shallow_t_from_depth(depth)
	gut.p("[fix-A-ctrl] loaded deep player: depth=%.1f shallow_t=%.2f" % [depth, shallow_t])
	assert_almost_eq(depth, 40.0, 1.0, "加载的地下深处 depth 正常算")
	assert_almost_eq(shallow_t, 1.0, 0.001, "真在地下 → 正常显矿洞 (没误伤)")


func test_generate_chunk_fills_all_surfaces() -> void:
	var c: Chunk = WorldGenerator.generate_chunk(12345, 0, ChunkConstants.WORLD_HEIGHT)
	var zero_count := 0
	for lx in c.surfaces.size():
		if c.surfaces[lx] == 0:
			zero_count += 1
	assert_eq(zero_count, 0, "generate_chunk 填满 surfaces (无 0)")


# ===== 症状 3 (小地图地底) 修复: minimap 跳过未加载 chunk, 不缓存假 AIR =====

func test_minimap_skips_unloaded_chunk() -> void:
	var fcm := FakeChunkManager.new(); add_child_autofree(fcm)
	var md := MinimapData.new(); add_child_autofree(md)
	var ptx := 600; var pty := 120   # chunk 9 未加载
	md.mark_rect(fcm, ptx - 30, pty - 20, ptx + 30, pty + 20)
	assert_false(md.is_explored(ptx, pty + 10),
		"chunk 未加载 → 不标记 (保持未探索, 不把实心地面误存成洞穴 AIR)")


func test_minimap_marks_loaded_chunk_correctly() -> void:
	var fcm := FakeChunkManager.new(); add_child_autofree(fcm)
	var md := MinimapData.new(); add_child_autofree(md)
	var ptx := 600; var pty := 120
	md.mark_rect(fcm, ptx - 30, pty - 20, ptx + 30, pty + 20)   # 未加载, 应跳过不污染
	var c := _make_chunk_with_surface(9, pty)
	var lx := Chunk.local_x_of(ptx)
	for y in range(pty, pty + 20):
		c.tiles[lx][y] = Tiles.STONE
	fcm.loaded[9] = c
	md.mark_rect(fcm, ptx - 30, pty - 20, ptx + 30, pty + 20)   # 加载了, 正常标
	assert_eq(md.get_tile_at(ptx, pty + 10), Tiles.STONE,
		"chunk 加载后正确标 STONE (未加载时没被污染成 AIR, 所以这次能正确标)")


# ===== 症状 1 (丢三件套) 修复: 玩家没就绪 save abort, 不写空背包覆盖好档 =====
const SAVES_DIR := "user://saves/"
const TEST_SAVE := "_test_glitch_starter"

func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("_test_"):
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()

func before_each() -> void:
	_clean_saves()

func after_each() -> void:
	_clean_saves()
	GameSettings.creative_mode = false


class StubWorldNoPlayer:
	extends Node2D
	var world_seed: int = 0
	var spawn_point: Vector2i = Vector2i.ZERO
	var chunk_manager = null
	func get_player():
		return null   # 模拟"玩家还没 spawn"的加载窗口期

class StubMain:
	extends Node


func test_save_aborts_when_player_not_ready() -> void:
	var stub_main := StubMain.new(); add_child_autofree(stub_main)
	var stub_world := StubWorldNoPlayer.new()
	stub_world.name = "World"
	stub_world.world_seed = 13579
	const CM = preload("res://scripts/world/chunk_manager.gd")
	var cm = CM.new(); cm.name = "ChunkManager"
	stub_world.add_child(cm); cm.setup(13579)
	stub_world.chunk_manager = cm
	cm.set_tile(5, 5, Tiles.STONE)
	stub_main.add_child(stub_world)
	GameSettings.current_world_name = TEST_SAVE
	var ok := SaveManager.save(stub_main)
	gut.p("[fix-D] save with player=null → ok=%s" % ok)
	assert_false(ok, "玩家没就绪 → save abort 返 false (不写空背包覆盖好档)")
	var data = SaveManager.load_save_by_name(TEST_SAVE)
	assert_null(data, "没写档 → 读不到 (好档不被覆盖)")


func _count(inv_node: Node, item_id: String) -> int:
	var n := 0
	for s in inv_node.inventory.slots:
		if s != null and s.item_id == item_id:
			n += int(s.count)
	return n

func _has_three_kit(inv_node: Node) -> bool:
	return _count(inv_node, "wood_pickaxe") >= 1 \
		and _count(inv_node, "wood_axe") >= 1 \
		and _count(inv_node, "wood_sword") >= 1


func test_new_game_grants_three_kit() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main._start_game({"world_seed": 777, "world_name": "_test_glitch_starter", "difficulty": 1, "world_size": 0})
	await wait_frames(180)
	var player: Node2D = main.world.get_player()
	assert_not_null(player, "player 应就绪")
	var inv_node: Node = player.get_node("PlayerInventory")
	gut.p("[fix-1-new] kit: pick=%d axe=%d sword=%d" % [
		_count(inv_node, "wood_pickaxe"), _count(inv_node, "wood_axe"), _count(inv_node, "wood_sword")])
	assert_true(_has_three_kit(inv_node), "新游戏稳定拿到三件套")


func test_continue_restores_three_kit() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game(54321)
	await wait_frames(5)
	var inv_node: Node = main.world.get_player().get_node("PlayerInventory")
	inv_node.pickup("wood_pickaxe", 1)
	inv_node.pickup("wood_axe", 1)
	inv_node.pickup("wood_sword", 1)
	inv_node.pickup("dirt", 10)
	GameSettings.current_world_name = TEST_SAVE
	assert_true(SaveManager.save(main), "玩家就绪 → 正常存档")
	var data = SaveManager.load_save_by_name(TEST_SAVE)
	main._return_to_menu()
	await wait_frames(5)
	main._continue_game(data)
	await wait_frames(180)
	var new_inv: Node = main.world.get_player().get_node("PlayerInventory")
	gut.p("[fix-1-cont] after continue: pick=%d axe=%d sword=%d dirt=%d" % [
		_count(new_inv, "wood_pickaxe"), _count(new_inv, "wood_axe"),
		_count(new_inv, "wood_sword"), _count(new_inv, "dirt")])
	assert_true(_has_three_kit(new_inv), "continue 后三件套还在")
	assert_eq(_count(new_inv, "dirt"), 10, "其他物品也在")
