extends GutTest

const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
var db


func before_each():
	db = RecipeDBClass.new()
	add_child_autofree(db)


func test_has_6_recipes():
	assert_eq(db.all_recipes().size(), 6)


func test_planks_recipe():
	var r = db.get_recipe("planks")
	assert_not_null(r)
	assert_eq(r.grid_size, Vector2i(2, 2))
	assert_eq(r.output_id, "planks")
	assert_eq(r.output_count, 4)
	var has_log := false
	for row in r.pattern:
		for cell in row:
			if cell == "log":
				has_log = true
	assert_true(has_log)


func test_wood_pickaxe_recipe():
	var r = db.get_recipe("wood_pickaxe")
	assert_eq(r.grid_size, Vector2i(3, 3))
	assert_eq(r.output_id, "wood_pickaxe")
	assert_eq(r.output_count, 1)
	# 顶行 3 planks
	assert_eq(r.pattern[0], ["planks", "planks", "planks"])
	# 中柱 stick
	assert_eq(r.pattern[1][1], "stick")
	assert_eq(r.pattern[2][1], "stick")


func test_workbench_recipe():
	var r = db.get_recipe("workbench")
	assert_eq(r.grid_size, Vector2i(2, 2))
	assert_eq(r.output_id, "workbench")
	for row in r.pattern:
		for cell in row:
			assert_eq(cell, "planks")


func test_unknown_recipe_returns_null():
	assert_null(db.get_recipe("nonexistent"))


func test_all_recipes_have_mirror_flag():
	for r in db.all_recipes():
		assert_true(r.has("mirror_ok"))
