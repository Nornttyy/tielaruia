extends GutTest

const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")


# 把 ASCII row 列表转 craft grid。"." 视作空，其他词视作 item_id。
func _g(rows: Array) -> Array:
	var grid := []
	for row_str in rows:
		var parts: Array = row_str.split(" ", false)
		var row := []
		for p in parts:
			row.append("" if p == "." else String(p))
		grid.append(row)
	return grid


func test_planks_2x2_basic():
	var grid = _g(["log .", ". ."])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m)
	assert_eq(m.recipe_id, "planks")


func test_planks_2x2_translated_to_topright():
	var grid = _g([". log", ". ."])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m, "log 在右上角应仍匹配 planks")
	assert_eq(m.recipe_id, "planks")


func test_planks_2x2_in_3x3_grid():
	# 2x2 配方应在 3x3 grid 里也能匹配（任何位置）
	var grid = _g([". . .", ". log .", ". . ."])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m)
	assert_eq(m.recipe_id, "planks")


func test_workbench_recipe():
	var grid = _g(["planks planks", "planks planks"])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m)
	assert_eq(m.recipe_id, "workbench")


func test_wood_pickaxe_3x3():
	var grid = _g([
		"planks planks planks",
		". planks .",
		". planks .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_pickaxe")


func test_wood_axe_3x3():
	var grid = _g([
		"planks planks .",
		"planks planks .",
		". planks .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_axe")


func test_wood_axe_mirrored():
	# axe 镜像：planks 在右
	var grid = _g([
		". planks planks",
		". planks planks",
		". planks .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_axe")


func test_wood_sword_3x3():
	var grid = _g([
		". planks .",
		". planks .",
		". planks .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_sword")


func test_empty_grid_no_match():
	var grid = _g([". . .", ". . .", ". . ."])
	assert_null(RecipeMatcher.find_match(grid))


func test_wrong_item_no_match():
	var grid = _g(["dirt .", ". ."])  # dirt 不在任何 recipe 里
	assert_null(RecipeMatcher.find_match(grid))


func test_partial_pattern_no_match():
	# pickaxe 缺一格 planks → 不应匹配
	var grid = _g([
		"planks planks planks",
		". planks .",
		". . .",
	])
	assert_null(RecipeMatcher.find_match(grid))


func test_extra_item_no_match():
	# planks recipe 是 1 个 log，多放一个 dirt → 不应匹配
	var grid = _g(["log dirt", ". ."])
	assert_null(RecipeMatcher.find_match(grid))
