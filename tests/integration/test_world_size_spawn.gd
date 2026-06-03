extends GutTest

# 复现"选世界大小进游戏后出问题": 三种大小各跑几个种子, 验证玩家出生点合理。
# 坏 spawn = 出生点埋在方块里 (不是空气) 或脚下悬空 (一直往下掉)。
# 代码里多处"大世界 spawn bug"救命 hack → 高度怀疑大世界 spawn 还有坑。

const MainScene = preload("res://scenes/main.tscn")


# 启一个指定大小+种子的世界, 返回出生点 + 那格/脚下 tile。
func _spawn_info(size: int, seed_val: int) -> Dictionary:
	GameSettings.current_world_size = size
	var main = MainScene.instantiate()
	add_child(main)
	main.boot_to_game(seed_val)
	await wait_frames(8)   # 等世界生成 + spawn (大世界 chunk 多, 多等几帧)
	var world = main.get_node("World")
	var sp: Vector2i = world.spawn_point
	var cm = world.chunk_manager
	var at: int = cm.get_tile(sp.x, sp.y)         # 出生点这格 — 玩家身体所在, 应可穿过
	var head: int = cm.get_tile(sp.x, sp.y - 1)   # 头顶 — 玩家 2.5 格高, 也得空
	var below: int = cm.get_tile(sp.x, sp.y + 1)  # 脚下 — 应实心地, 不然一直掉
	main.queue_free()
	await wait_frames(2)
	return {"sp": sp, "at": at, "head": head, "below": below}


# 好 spawn: 出生点空气(没埋方块) + 头顶空(玩家 2.5 格高) + 脚下实心(不悬空/不淹水)
func _assert_good_spawn(size_name: String, seed_val: int, info: Dictionary) -> void:
	var ctx: String = "%s世界 seed=%d 出生点 %s" % [size_name, seed_val, info["sp"]]
	assert_eq(info["at"], Tiles.AIR, "%s 该是空气, 实际 tile=%d (玩家埋方块里!)" % [ctx, info["at"]])
	assert_eq(info["head"], Tiles.AIR, "%s 头顶该是空气, 实际 tile=%d (玩家 2.5 格高顶进方块!)" % [ctx, info["head"]])
	# 脚下不能是空气/水 → 不然玩家一直往下掉 / 掉水里淹死
	assert_false(info["below"] == Tiles.AIR or Tiles.is_water(info["below"]),
		"%s 脚下该是实心地, 实际 tile=%d (悬空/落水!)" % [ctx, info["below"]])


func test_small_world_spawn_good() -> void:
	for seed_val in [1, 42, 777]:
		var info = await _spawn_info(0, seed_val)
		_assert_good_spawn("小", seed_val, info)


func test_medium_world_spawn_good() -> void:
	for seed_val in [1, 42, 777]:
		var info = await _spawn_info(1, seed_val)
		_assert_good_spawn("中", seed_val, info)


func test_big_world_spawn_good() -> void:
	# 重点怀疑对象: 大世界 (1.6x biome 拉远, chunk 0 容易落进非草地表 / 海洋)
	for seed_val in [1, 42, 100, 777, 2026, 5, 13, 88]:
		var info = await _spawn_info(2, seed_val)
		_assert_good_spawn("大", seed_val, info)
