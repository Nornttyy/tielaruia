extends GutTest

const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")
var db


func before_each():
	db = RecipeDBClass.new()
	add_child_autofree(db)


func test_has_32_recipes():
	# 29 + silver sword/pickaxe/axe = 32
	assert_eq(db.all_recipes().size(), 32)


func test_planks_recipe():
	var r = db.get_recipe("planks")
	assert_not_null(r)
	assert_eq(r.grid_size, Vector2i(2, 2))
	assert_eq(r.output_id, "planks")
	assert_eq(r.output_count, 4)


func test_workbench_recipe():
	var r = db.get_recipe("workbench")
	assert_eq(r.output_id, "workbench")
	assert_eq(r.output_count, 1)


func test_slime_torch_recipe():
	var r = db.get_recipe("slime_torch")
	assert_not_null(r)
	assert_eq(r.grid_size, Vector2i(2, 2))
	assert_eq(r.output_id, "slime_torch")
	assert_eq(r.output_count, 3)


func test_door_recipe():
	var r = db.get_recipe("door")
	assert_not_null(r)
	assert_eq(r.grid_size, Vector2i(2, 3))
	assert_eq(r.output_id, "door")


func test_wood_sword_recipe():
	var r = db.get_recipe("wood_sword")
	assert_not_null(r)
	assert_eq(r.grid_size, Vector2i(3, 3))


func test_wood_pickaxe_recipe_planks_only():
	# Terraria 风: 木镐配方只用 planks, 不用 stick
	var r = db.get_recipe("wood_pickaxe")
	assert_not_null(r)
	for row in r.pattern:
		for cell in row:
			assert_ne(cell, "stick", "wood_pickaxe 不应再包含 stick")


func test_wood_axe_recipe_planks_only():
	var r = db.get_recipe("wood_axe")
	assert_not_null(r)
	for row in r.pattern:
		for cell in row:
			assert_ne(cell, "stick", "wood_axe 不应再包含 stick")


func test_stone_sword_recipe():
	var r = db.get_recipe("stone_sword")
	assert_not_null(r)
	assert_eq(r.output_id, "stone_sword")


func test_stone_pickaxe_recipe():
	var r = db.get_recipe("stone_pickaxe")
	assert_not_null(r)
	assert_eq(r.output_id, "stone_pickaxe")


func test_stone_axe_recipe():
	var r = db.get_recipe("stone_axe")
	assert_not_null(r)
	assert_eq(r.output_id, "stone_axe")


func test_no_stick_recipe():
	assert_null(db.get_recipe("stick"), "stick 配方已删除")


# === RecipeMatcher 命中测 ===

func test_matcher_planks():
	var g = [["log", ""], ["", ""]]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "planks")


func test_matcher_workbench():
	var g = [["planks", "planks"], ["planks", "planks"]]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "workbench")


func test_matcher_slime_torch():
	var g = [["slime_jelly", ""], ["planks", ""]]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "slime_torch")


func test_matcher_door():
	var g = [
		["planks", "planks", ""],
		["planks", "planks", ""],
		["planks", "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "door")


func test_matcher_wood_sword():
	var g = [
		["", "planks", ""],
		["", "planks", ""],
		["", "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "wood_sword")


func test_matcher_wood_pickaxe():
	var g = [
		["planks", "planks", "planks"],
		["",       "planks", ""],
		["",       "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "wood_pickaxe")


func test_matcher_wood_axe():
	var g = [
		["planks", "planks", ""],
		["planks", "planks", ""],
		["",       "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "wood_axe")


func test_matcher_stone_sword():
	var g = [
		["", "stone",  ""],
		["", "stone",  ""],
		["", "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "stone_sword")


func test_matcher_stone_pickaxe():
	var g = [
		["stone", "stone",  "stone"],
		["",      "planks", ""],
		["",      "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "stone_pickaxe")


func test_matcher_stone_axe():
	var g = [
		["stone", "stone",  ""],
		["stone", "planks", ""],
		["",      "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "stone_axe")


func test_door_grid_size_is_2x3():
	# 防回归: door 是 2 宽 3 高, max(x,y)=3 → 需 3x3 模式 (工作台)
	var r = db.get_recipe("door")
	assert_eq(r.grid_size, Vector2i(2, 3))
	assert_eq(max(r.grid_size.x, r.grid_size.y), 3, "door 应被识别为需要 3x3 模式")


func test_torch_recipe_exists():
	var r = db.get_recipe("torch")
	assert_not_null(r, "torch 配方应存在")
	assert_eq(r.output_id, "torch")
	assert_eq(r.output_count, 4)
	# 1x2: coal 上, log 下
	assert_eq(r.grid_size, Vector2i(1, 2))
	assert_eq(r.pattern[0][0], "coal")
	assert_eq(r.pattern[1][0], "log")


func test_iron_pickaxe_recipe_exists():
	var r = db.get_recipe("iron_pickaxe")
	assert_not_null(r, "iron_pickaxe 配方应存在")
	assert_eq(r.output_id, "iron_pickaxe")
	assert_eq(r.output_count, 1)
	# 3x3: 顶三铁矿 + 中下双 planks
	assert_eq(r.grid_size, Vector2i(3, 3))
	assert_eq(r.pattern[0][0], "iron_ore")
	assert_eq(r.pattern[0][1], "iron_ore")
	assert_eq(r.pattern[0][2], "iron_ore")
	assert_eq(r.pattern[1][1], "planks")
	assert_eq(r.pattern[2][1], "planks")
