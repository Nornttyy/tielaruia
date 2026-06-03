extends GutTest

const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")
var db


func before_each():
	db = RecipeDBClass.new()
	add_child_autofree(db)


func test_has_recipes():
	# 用户持续加 recipe (furnace/ingot/cooked_meat 等), 不卡死定数. 至少 30 个.
	assert_gt(db.all_recipes().size(), 30)


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
	# 3x3: 顶三铁锭 (金属工具改用冶炼的锭, 非生矿) + 中下双 planks
	assert_eq(r.grid_size, Vector2i(3, 3))
	assert_eq(r.pattern[0][0], "iron_ingot")
	assert_eq(r.pattern[0][1], "iron_ingot")
	assert_eq(r.pattern[0][2], "iron_ingot")
	assert_eq(r.pattern[1][1], "planks")
	assert_eq(r.pattern[2][1], "planks")


# === 短剑(dagger)配方: 8 把都要能合成, 否则合成栏看不到 ===
func test_all_8_daggers_have_recipe():
	for mat in ["wood", "stone", "copper", "iron", "silver", "gold", "diamond", "hell"]:
		var did: String = mat + "_dagger"
		var r = db.get_recipe(did)
		assert_not_null(r, "短剑配方应存在: %s (没配方就不显示在合成栏)" % did)
		if r != null:
			assert_eq(r.output_id, did, "%s 产出应是自己" % did)


func test_matcher_wood_dagger_not_broadsword():
	# 2 planks 竖排 = 木短剑; 3 planks 才是木阔剑. 不能错配
	var g = [["", "planks", ""], ["", "planks", ""], ["", "", ""]]
	var hit = RecipeMatcher.find_match(g)
	assert_not_null(hit, "2 planks 竖排应能合成木短剑")
	if hit != null:
		assert_eq(hit.output_id, "wood_dagger", "2 planks = 木短剑 (不是 3 planks 的木阔剑)")


func test_matcher_iron_dagger():
	# 1 铁锭 + 1 planks = 铁短剑 (阔剑要 2 铁锭)
	var g = [["", "iron_ingot", ""], ["", "planks", ""], ["", "", ""]]
	var hit = RecipeMatcher.find_match(g)
	assert_not_null(hit, "铁锭+planks 应能合成铁短剑")
	if hit != null:
		assert_eq(hit.output_id, "iron_dagger")


func test_skull_summon_recipe():
	# 8 骨头围成头骨 (空心) = 召唤骷髅王的头骨
	var r = db.get_recipe("skull_summon")
	assert_not_null(r, "骷髅头骨配方应存在")
	if r != null:
		assert_eq(r.output_id, "skull_summon")
	var g = [["bone", "bone", "bone"], ["bone", "", "bone"], ["bone", "bone", "bone"]]
	var hit = RecipeMatcher.find_match(g)
	assert_not_null(hit, "8 骨头围圈应能合成骷髅头骨")
	if hit != null:
		assert_eq(hit.output_id, "skull_summon")
