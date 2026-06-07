# 流体流动验收: 岩浆流动 + 水/岩浆=石头
extends GutTest


func test_lava_level_tiles_defined() -> void:
	assert_eq(Tiles.LAVA_L1, 71, "LAVA_L1 = 71")
	assert_eq(Tiles.LAVA_L2, 72, "LAVA_L2 = 72")
	assert_eq(Tiles.LAVA_L3, 73, "LAVA_L3 = 73")
	assert_false(Tiles.is_solid(Tiles.LAVA_L1), "LAVA_L1 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L2), "LAVA_L2 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L3), "LAVA_L3 非实心")


func test_lava_level_textures_built() -> void:
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L1), "LAVA_L1 该有世界贴图")
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L2), "LAVA_L2 该有世界贴图")
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L3), "LAVA_L3 该有世界贴图")


# 假世界: 不启动整个游戏, 只提供 chunk_manager.get_tile + _set_water_tile_fast
# 注意: water_sim 的 world 是 @export var world: Node2D, 所以假世界必须是 Node2D
class FakeWorld:
	extends Node2D
	var tiles := {}
	var chunk_manager = null
	func _init():
		chunk_manager = FakeCM.new(tiles)
	func _set_water_tile_fast(x, y, tid):
		tiles[Vector2i(x, y)] = tid
class FakeCM:
	var tiles
	func _init(t): tiles = t
	func get_tile(x, y):
		return tiles.get(Vector2i(x, y), Tiles.AIR)

func _make_sim(fake) -> Node:
	var WaterSim = load("res://scripts/world/water_sim.gd")
	var sim = WaterSim.new()
	sim.world = fake
	add_child_autofree(sim)
	return sim

func _lk(fw, x, y) -> String:
	var t = fw.tiles.get(Vector2i(x,y), Tiles.AIR)
	if t == Tiles.LAVA or t == Tiles.LAVA_L1 or t == Tiles.LAVA_L2 or t == Tiles.LAVA_L3:
		return "lava"
	if Tiles.is_water(t):   # 含群系水色
		return "water"
	return ""

func test_lava_falls_down() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(0,2)] = Tiles.STONE
	# 用石墙把竖井两侧封住, 岩浆只能直落不会横向摊开 (验证纯重力下落)
	fw.tiles[Vector2i(-1,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0,1), Tiles.AIR), Tiles.LAVA, "岩浆该落到石头上方")
	assert_eq(fw.tiles.get(Vector2i(0,0), Tiles.AIR), Tiles.AIR, "原位该空")

func test_lava_spreads_sideways() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(0,1)] = Tiles.STONE
	fw.tiles[Vector2i(-1,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 10:
		sim._run_tick()
	assert_true(_lk(fw,-1,0) == "lava" or _lk(fw,1,0) == "lava", "岩浆该横向摊开")

func test_lava_slower_than_water() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0,0)] = Tiles.WATER
	fw.tiles[Vector2i(5,0)] = Tiles.LAVA
	var sim = _make_sim(fw)
	# mark_dirty 而非 notify_tile_changed: 避免把 (x,y+1) 也标 dirty
	# 否则同一 tick 内水会二次下落到 y+2, 导致 y+1 检查失败
	sim.mark_dirty(0, 0)
	sim.mark_dirty(5, 0)
	# 只跑 1 个 tick: 水该已下落, 岩浆还没动 (cadence)
	sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0,1), Tiles.AIR), Tiles.WATER, "水 1 tick 就下落")
	assert_eq(fw.tiles.get(Vector2i(5,1), Tiles.AIR), Tiles.AIR, "岩浆 1 tick 还没动 (慢)")
	assert_eq(fw.tiles.get(Vector2i(5,0), Tiles.AIR), Tiles.LAVA, "岩浆还在原位")

func test_is_liquid() -> void:
	var fw = FakeWorld.new()
	var sim = _make_sim(fw)
	assert_true(sim.is_liquid(Tiles.LAVA), "LAVA 是液体")
	assert_true(sim.is_liquid(Tiles.LAVA_L2), "LAVA_L2 是液体")
	assert_true(sim.is_liquid(Tiles.WATER), "WATER 是液体")
	assert_true(sim.is_liquid(Tiles.WATER_L1), "WATER_L1 是液体")
	assert_false(sim.is_liquid(Tiles.STONE), "石头不是液体")
	assert_false(sim.is_liquid(Tiles.AIR), "空气不是液体")


func test_tile_can_still_flow_wakes_lava() -> void:
	# 这是修复核心: chunk 加载唤醒判断之前只认水, 岩浆瀑布冻在空中.
	var fw = FakeWorld.new()
	var sim = _make_sim(fw)
	# 下方空气的岩浆 → 该被唤醒 (能往下流, 形成瀑布)
	assert_true(sim.tile_can_still_flow(Tiles.LAVA, [Tiles.AIR, Tiles.STONE, Tiles.STONE, Tiles.STONE]),
		"下方空气的岩浆该被唤醒")
	# 四周封死的岩浆 → 不唤醒 (省 CPU)
	assert_false(sim.tile_can_still_flow(Tiles.LAVA, [Tiles.STONE, Tiles.STONE, Tiles.STONE, Tiles.STONE]),
		"封死的岩浆不唤醒")
	# chunk 边界 (越界邻居 -1) → 保守唤醒
	assert_true(sim.tile_can_still_flow(Tiles.LAVA, [-1, Tiles.STONE, Tiles.STONE, Tiles.STONE]),
		"chunk 边界的岩浆保守唤醒")
	# 满水旁边是低水位 → 唤醒 (要横向均衡)
	assert_true(sim.tile_can_still_flow(Tiles.WATER, [Tiles.STONE, Tiles.STONE, Tiles.WATER_L1, Tiles.STONE]),
		"旁边低水位的满水该唤醒")
	# 非液体 → 不唤醒
	assert_false(sim.tile_can_still_flow(Tiles.STONE, [Tiles.AIR, Tiles.AIR, Tiles.AIR, Tiles.AIR]),
		"石头不是液体, 不唤醒")


func test_lava_falls_when_woken_like_a_waterfall() -> void:
	# 还原世界生成的"岩浆瀑布": 顶部悬空岩浆源, 下面是空气竖井, 被唤醒后该一路流下.
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.LAVA      # 悬空源
	fw.tiles[Vector2i(0, 4)] = Tiles.STONE     # 竖井底
	for yy in [1, 2, 3]:                        # 两侧封墙, 只能直落
		fw.tiles[Vector2i(-1, yy)] = Tiles.STONE
		fw.tiles[Vector2i(1, yy)] = Tiles.STONE
	var sim = _make_sim(fw)
	# 模拟 chunk 加载: 用唤醒判断决定标不标 dirty
	if sim.tile_can_still_flow(Tiles.LAVA, [Tiles.AIR, Tiles.AIR, Tiles.STONE, Tiles.STONE]):
		sim.mark_dirty(0, 0)
	for i in 20:
		sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0, 3), Tiles.AIR), Tiles.LAVA, "岩浆该流到竖井底")
	assert_eq(fw.tiles.get(Vector2i(0, 0), Tiles.AIR), Tiles.AIR, "源处该流空")


func test_deep_pool_pours_out_dug_wall() -> void:
	# 复现"挖开水池墙水不流": 2 格深的满水池, 挖穿右墙底, 水该流出去.
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 1)] = Tiles.WATER
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE   # 池底
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE  # 左墙
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 0)] = Tiles.STONE   # 右墙 (上)
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE   # 右墙 (下, 待挖)
	fw.tiles[Vector2i(1, 2)] = Tiles.STONE   # 墙外地板
	fw.tiles[Vector2i(2, 2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 1)
	for i in 5:
		sim._run_tick()                      # 先稳定: 没洞时不该漏
	assert_eq(_lk(fw, 1, 1), "", "没挖墙前水不该漏出去")
	# 挖掉右墙底 (1,1) → _set_tile 会这样通知
	fw.tiles[Vector2i(1, 1)] = Tiles.AIR
	sim.notify_tile_changed(1, 1)
	for i in 20:
		sim._run_tick()
	assert_eq(_lk(fw, 1, 1), "water", "挖开墙后水该流进洞口")


func test_thin_water_pours_out_toward_drop() -> void:
	# 薄水 (1 格) 旁边挖开一个有落差的洞 (洞口下面是空的) → 该流出去并落下.
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_L1
	fw.tiles[Vector2i(0, 1)] = Tiles.STONE   # 水脚下是地 (也是落点 1,1 的左墙)
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE  # 左墙
	fw.tiles[Vector2i(1, 0)] = Tiles.AIR     # 右边挖开 (1,1 是空的 → 能往下掉)
	fw.tiles[Vector2i(1, 2)] = Tiles.STONE   # 落点地板
	fw.tiles[Vector2i(2, 1)] = Tiles.STONE   # 落点右墙 (让水停在 1,1)
	var sim = _make_sim(fw)
	sim.notify_tile_changed(1, 0)
	for i in 10:
		sim._run_tick()
	assert_eq(_lk(fw, 0, 0), "", "薄水该流走 (原位空)")
	assert_eq(_lk(fw, 1, 1), "water", "薄水该流到洞口并落到落点")


func test_thin_water_no_oscillation_on_flat() -> void:
	# 防抖: 薄水在平地 (脚下全石头, 两边空, 无落差) → 原地不动, 不左右乱跑.
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_L1
	for xx in [-2, -1, 0, 1, 2]:
		fw.tiles[Vector2i(xx, 1)] = Tiles.STONE   # 平地板
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 10:
		sim._run_tick()
	assert_eq(_lk(fw, 0, 0), "water", "平地薄水原地不动 (无落差不流, 防抖)")


func test_settle_now_flows_everything_in_one_call() -> void:
	# 加载即定型: 标 dirty 后调一次 settle_now(), 液体该已流到最终状态 (不用手动跑 tick).
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER     # 顶部悬空水源
	fw.tiles[Vector2i(0, 4)] = Tiles.STONE     # 竖井底
	for yy in [1, 2, 3]:                        # 两侧封墙
		fw.tiles[Vector2i(-1, yy)] = Tiles.STONE
		fw.tiles[Vector2i(1, yy)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()                           # 一次调用流到底
	assert_eq(_lk(fw, 0, 3), "water", "settle_now 后水该已落到竖井底")
	assert_eq(_lk(fw, 0, 0), "", "源处该流空")
	assert_true(sim._dirty.is_empty(), "settle 后不该还剩待流的 dirty")


func test_settle_now_terminates_on_big_still_pool() -> void:
	# 已经平衡的大水池: settle_now 该很快收手 (不卡死), 且水保持不变.
	var fw = FakeWorld.new()
	for xx in range(0, 8):
		fw.tiles[Vector2i(xx, 0)] = Tiles.WATER
		fw.tiles[Vector2i(xx, 1)] = Tiles.STONE   # 池底
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE       # 左右墙
	fw.tiles[Vector2i(8, 0)] = Tiles.STONE
	var sim = _make_sim(fw)
	for xx in range(0, 8):
		sim.mark_dirty(xx, 0)
	sim.settle_now()
	assert_eq(_lk(fw, 0, 0), "water", "平衡水池 settle 后水还在")
	assert_eq(_lk(fw, 7, 0), "water", "平衡水池 settle 后水还在")
	assert_true(sim._dirty.is_empty(), "settle 后 dirty 清空")


func test_biome_water_flows_like_water() -> void:
	# 群系水 (沙漠绿洲色) 该跟普通水一样被模拟认出来、会流动.
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_DESERT
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_eq(_lk(fw, 0, 1), "water", "群系水该像普通水一样下落")
	assert_eq(_lk(fw, 0, 0), "", "源处该流空")


func test_water_lava_makes_stone() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(1,0)] = Tiles.WATER
	fw.tiles[Vector2i(0,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	sim.notify_tile_changed(1, 0)
	for i in 6:
		sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0,0)), Tiles.STONE, "岩浆碰水变石头")
	var w = fw.tiles.get(Vector2i(1,0), Tiles.AIR)
	assert_true(w != Tiles.WATER, "水该被消耗一级")


# 回归: 平地上 L2 紧挨 L1, 差 1 级以前会无限来回倒 (settle 永不收敛 + 耗CPU). 现在应收敛.
func test_no_lateral_oscillation_on_flat_ground() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_L2
	fw.tiles[Vector2i(1, 0)] = Tiles.WATER_L1
	fw.tiles[Vector2i(0, 1)] = Tiles.STONE   # 平地 (水落不下去)
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE  # 两侧封死, 只剩这两格之间能流
	fw.tiles[Vector2i(2, 0)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.mark_dirty(1, 0)
	sim.settle_now()
	assert_true(sim._dirty.is_empty(), "平地 L2/L1 应收敛 (差1级稳定, 不再无限震荡)")


# 活水颗粒: 水落进空气时该调发射器; settle 期间不该调。
func test_grains_emit_on_fall() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE     # 下落 1 格后下方是石头 → 砸到底
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim._in_settle = false
	var before: int = Effects.grains_emitted
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_gt(Effects.grains_emitted, before, "水落进空气该冒水珠 (发射器被调)")


func test_grains_silent_during_settle() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim._in_settle = true                       # 加载找平期间
	var before: int = Effects.grains_emitted
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_eq(Effects.grains_emitted, before, "settle 期间不该冒水珠")
