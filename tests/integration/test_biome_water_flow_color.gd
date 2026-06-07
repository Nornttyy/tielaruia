# 集成: world_seed → 群系 → 画水颜色 链路. 验证 _display_water_tile 真按列染色。
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const World = preload("res://scripts/world/world.gd")

const SEED := 12345


# 扫出该 seed 下某 biome 的一列 x (扫不到返回 -999999).
# biome 槽位在 ±600 / ±1200, 故扫 ±1400 才覆盖。
func _find_col(biome_id: int) -> int:
	for x in range(-1400, 1400):
		if WorldGenerator._biome_at(x, SEED) == biome_id:
			return x
	return -999999


func test_display_colors_by_current_biome() -> void:
	# 不 add_child: 避免触发 World._ready (它要 $TerrainLayer 等场景节点).
	# _display_water_tile 只读 world_seed + 调静态函数, 不碰那些节点。
	var w = autofree(World.new())
	w.world_seed = SEED

	var dx := _find_col(WorldGenerator.BIOME_DESERT)
	assert_ne(dx, -999999, "该 seed 应有沙漠列")
	# 数据是普通薄水, 画到沙漠列 → 沙漠彩色
	assert_eq(w._display_water_tile(dx, Tiles.WATER_L3), Tiles.WATER_DESERT_L3)

	var fx := _find_col(WorldGenerator.BIOME_FOREST)
	assert_ne(fx, -999999, "该 seed 应有森林列")
	# 森林 (无特殊水) → 不染色, 还是普通蓝薄水
	assert_eq(w._display_water_tile(fx, Tiles.WATER_L3), Tiles.WATER_L3)
