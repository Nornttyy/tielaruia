# 活水颗粒: 水珠贴图 + Effects 上限护栏的纯逻辑测试。
extends GutTest

const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const WaterGrainScene = preload("res://scenes/fx/water_grain_particle.tscn")


# 假 chunk_manager: get_tile 全返同一个 tile (测落地碰撞)
class FakeCM:
	var tile: int = Tiles.AIR
	func get_tile(_x, _y) -> int:
		return tile

# 假池: 只记录有没有被回收 (测落地回收)。
# 必须 extends Node — 水珠的 _pool 声明为 Node 类型 (真实里池是 Node2D / 兜底是 Effects 节点)。
class FakeGrainPool:
	extends Node
	var recycled: bool = false
	func recycle(_g) -> void:
		recycled = true


func test_water_drop_texture_built() -> void:
	var tex = ParticlesArt.get_water_drop()
	assert_not_null(tex, "get_water_drop 该返回贴图")
	assert_eq(tex.get_width(), 3, "水珠贴图 3px 宽")
	assert_eq(tex.get_height(), 3, "水珠贴图 3px 高")


func test_water_drop_texture_cached() -> void:
	# 缓存: 两次调用返回同一个对象 (不重复建图)
	var a = ParticlesArt.get_water_drop()
	var b = ParticlesArt.get_water_drop()
	assert_eq(a, b, "get_water_drop 该缓存复用同一张贴图")


func test_grain_setup_resets_state() -> void:
	var g = WaterGrainScene.instantiate()
	add_child_autofree(g)
	# 先弄脏状态, 再 setup, 验证被重置 (池复用必须归零)
	g.velocity = Vector2(999, 999)
	g.setup(Vector2(10, 20), Vector2(5, -30), Color(0.4, 0.7, 1.0, 0.9))
	assert_eq(g.global_position, Vector2(10, 20), "setup 该设位置")
	assert_eq(g.velocity, Vector2(5, -30), "setup 该重置速度")
	assert_almost_eq(g.modulate.a, 0.9, 0.01, "setup 该按传入颜色定 alpha")
	assert_not_null(g.texture, "setup 该有水珠贴图")


func test_budget_blocks_when_full() -> void:
	# 存活数到顶 → 不该再发 (返回 false / grains_emitted 不增)
	Effects._grain_count = Effects.MAX_WATER_GRAINS
	var before: int = Effects.grains_emitted
	var ok: bool = Effects.spawn_water_grains(Vector2(0, 0), Vector2(0, 10), Tiles.WATER, 1)
	assert_false(ok, "存活数到上限时该拒绝发射")
	assert_eq(Effects.grains_emitted, before, "拒绝时调试计数不该增")
	Effects._grain_count = 0   # 还原, 不污染别的测试


func test_budget_counts_emit() -> void:
	# 没到上限 → 该发, 调试计数 +1
	Effects._grain_count = 0
	var before: int = Effects.grains_emitted
	var ok: bool = Effects.spawn_water_grains(Vector2(0, 0), Vector2(0, 10), Tiles.WATER, 1)
	assert_true(ok, "没到上限该允许发射")
	assert_eq(Effects.grains_emitted, before + 1, "发射该让调试计数 +1")
	Effects._grain_count = 0


func test_grain_splashes_and_recycles_on_solid() -> void:
	# 落到实心方块: 该溅一小朵 (发射器被调) + 回收
	var g = WaterGrainScene.instantiate()
	add_child_autofree(g)
	var cm = FakeCM.new()
	cm.tile = Tiles.STONE              # 当前格是实心 → 落地
	g._cm = cm
	var fp = FakeGrainPool.new()
	add_child_autofree(fp)
	g._pool = fp
	g.setup(Vector2(60, 60), Vector2(0, 100), Color(0.4, 0.7, 1.0, 0.9), true)
	var before: int = Effects.grains_emitted
	g._process(0.05)
	assert_true(fp.recycled, "落到实心该回收水珠")
	assert_gt(Effects.grains_emitted, before, "落地该溅一小朵 (发射器被调)")
	Effects._grain_count = 0


func test_grain_no_splash_when_flag_false() -> void:
	# splashes=false (落地溅出来的小水珠): 落到实心也不再溅 (防无限套娃)
	var g = WaterGrainScene.instantiate()
	add_child_autofree(g)
	var cm = FakeCM.new()
	cm.tile = Tiles.STONE
	g._cm = cm
	g.setup(Vector2(60, 60), Vector2(0, 100), Color(0.4, 0.7, 1.0, 0.9), false)
	var before: int = Effects.grains_emitted
	g._process(0.05)
	assert_eq(Effects.grains_emitted, before, "splashes=false 落地不该再溅")
	Effects._grain_count = 0


func test_grain_no_land_over_air() -> void:
	# 当前格是空气: 不该落地回收, 继续飞
	var g = WaterGrainScene.instantiate()
	add_child_autofree(g)
	var cm = FakeCM.new()
	cm.tile = Tiles.AIR
	g._cm = cm
	var fp = FakeGrainPool.new()
	add_child_autofree(fp)
	g._pool = fp
	g.setup(Vector2(60, 60), Vector2(0, 100), Color(0.4, 0.7, 1.0, 0.9), true)
	g._process(0.05)
	assert_false(fp.recycled, "在空气里不该落地回收")
