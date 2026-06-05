# 小地图实时更新: 挖/放方块后, 已探索格的地图色立刻刷新 (不用等周期扫描).
extends GutTest

const MinimapDataClass = preload("res://scripts/world/minimap_data.gd")


func test_update_if_explored_refreshes_explored_tile() -> void:
	var md = MinimapDataClass.new()
	add_child_autofree(md)
	# 先探索一格为 STONE
	md.mark(5, 100, Tiles.STONE)
	assert_eq(md.get_tile_at(5, 100), Tiles.STONE, "探索后该是石头")
	# 挖掉 → update_if_explored(AIR) → 地图立刻变空 (实时)
	md.update_if_explored(5, 100, Tiles.AIR)
	assert_eq(md.get_tile_at(5, 100), Tiles.AIR, "挖空后地图该立刻变空 (不用等周期刷新)")
	# 放方块 → 立刻变回去
	md.update_if_explored(5, 100, Tiles.PLANKS)
	assert_eq(md.get_tile_at(5, 100), Tiles.PLANKS, "放木板后地图该立刻变木板")


func test_update_if_explored_keeps_fog_on_unexplored() -> void:
	var md = MinimapDataClass.new()
	add_child_autofree(md)
	# 没探索过的格子: update 不该把它揭开 (保持迷雾, 水流到没去过的地方不偷偷暴露)
	md.update_if_explored(9, 100, Tiles.STONE)
	assert_false(md.is_explored(9, 100), "没探索的格不该被偷偷揭开")
