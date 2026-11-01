extends GutTest
const Water = preload("res://scripts/art/original_water_art.gd")
const Samples = preload("res://scripts/world/original_structure_samples.gd")

func test_submerged_water_has_no_surface_stripes_and_partial_levels_keep_top_clear():
	var full := Water.atlas().get_image()
	assert_eq(full.get_size(), Vector2i(256, 32))
	for frame in 16:
		for y in 16:
			assert_eq(full.get_pixel(frame * 16 + 8, y + 16), full.get_pixel(8, 28), "深水不应逐格闪烁或重复亮边")
	assert_ne(full.get_pixel(8, 0), full.get_pixel(8, 28))
	var thin := Water.atlas(2).get_image()
	for y in 12: assert_eq(thin.get_pixel(8, y).a, 0.0)
	assert_gt(thin.get_pixel(8, 12).a, 0.0)

func test_original_furniture_frames_are_discarded_when_player_edits_tile():
	var c := Chunk.new(0)
	c.init_empty()
	Samples.stamp(c, "sky_house", Vector2i(30, 60))
	var chest: Vector2i = c.original_visuals.keys()[0]
	var original_tile: int = c.tiles[chest.x][chest.y]
	assert_gte(Samples.display_id(c, chest, original_tile), Samples.VISUAL_BASE)
	c.apply_delta({chest: Tiles.AIR})
	assert_eq(Samples.display_id(c, chest, original_tile), original_tile, "旧建筑帧不能覆盖玩家重建的物品")

func test_source_sample_crown_is_not_the_previous_elliptical_approximation():
	var cells: Array = Samples.sample("living_tree").cells
	var leaves := 0
	var min_y := 0
	for cell in cells:
		if int(cell[2]) == Tiles.LIVING_LEAF:
			leaves += 1
			min_y = mini(min_y, int(cell[1]))
	assert_eq(leaves, 2933, "与公开地图样本的叶块数量一致")
	assert_eq(min_y, -77, "与原始样本树冠顶点一致")

class BoundaryCM:
	extends RefCounted
	var right_loaded := false
	func get_chunk(cx: int):
		return self if cx == 0 or right_loaded else null
	func get_tile(x: int, y: int) -> int:
		if y == 20 and x == 63: return Tiles.WATER
		if y == 21 or x == 62: return Tiles.STONE
		return Tiles.AIR
class BoundaryWorld:
	extends Node2D
	var writes: Array = []
	func _set_water_tile_fast(x, y, tid): writes.append([x, y, tid])

func test_unloaded_chunk_is_not_a_drain_for_the_ocean():
	var sim = preload("res://scripts/world/water_sim.gd").new()
	var world := BoundaryWorld.new()
	add_child_autofree(world)
	add_child_autofree(sim)
	sim.world = world
	sim._in_settle = true
	var cm := BoundaryCM.new()
	sim._step_water_lateral(cm, 63, 20, 8, 8)
	assert_eq(world.writes.size(), 0, "尚未加载的海面不能吞掉水量")
	cm.right_loaded = true
	sim._step_water_lateral(cm, 63, 20, 8, 8)
	assert_eq(world.writes.size(), 2, "加载后仍能正常向低处流动")
