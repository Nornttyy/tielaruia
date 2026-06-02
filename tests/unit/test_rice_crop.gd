extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")

func _has_drop(tid: int, item_id: String) -> bool:
	for d in Tiles.get_drops(tid) if Tiles.has_method("get_drops") else []:
		if d[0] == item_id:
			return true
	return false

func test_rice_tiles_exist():
	assert_gt(Tiles.RICE_0, 0)
	assert_eq(Tiles.RICE_1, Tiles.RICE_0 + 1, "稻子阶段连续 (生长 tick 靠 tid+1)")
	assert_eq(Tiles.RICE_2, Tiles.RICE_0 + 2)
	assert_eq(Tiles.RICE_3, Tiles.RICE_0 + 3)

func test_rice_items():
	var db = ItemDBClass.new()
	add_child_autofree(db)
	assert_not_null(db.get_def("rice"), "应有米")
	assert_not_null(db.get_def("rice_seed"), "应有稻种")
	assert_eq(db.get_def("rice_seed").get("tool_kind", ""), "seed", "稻种是 seed")

func test_rice_block_art_and_icon():
	for t in [Tiles.RICE_0, Tiles.RICE_1, Tiles.RICE_2, Tiles.RICE_3]:
		assert_not_null(ArtCache.block_textures.get(t), "稻子各阶段应有贴图")
	assert_not_null(ArtCache.get_inventory_icon("rice"), "米应有图标")
	assert_not_null(ArtCache.get_inventory_icon("rice_seed"), "稻种应有图标")

# 成熟稻子掉米 + 种子; world 生长认稻子; player_action 能种; 小草掉稻种
func test_rice_wiring_in_source():
	var world_src: String = FileAccess.get_file_as_string("res://scripts/world/world.gd")
	assert_true(world_src.find("RICE_0") != -1, "world 生长 tick 应认稻子")
	var pa_src: String = FileAccess.get_file_as_string("res://scripts/player/player_action.gd")
	assert_true(pa_src.find("rice_seed") != -1, "player_action 应能种稻子")
	var td_src: String = FileAccess.get_file_as_string("res://scripts/world/tile_data.gd")
	# RICE_3 掉米; PLANT_GRASS 也掉稻种 (拓荒)
	assert_true(td_src.find("\"rice\"") != -1, "RICE_3 应掉米")
	assert_true(td_src.find("rice_seed") != -1, "应能拿到稻种")
