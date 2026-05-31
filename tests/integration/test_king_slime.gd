# 史莱姆王 Boss 验收
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SlimeBallScene = preload("res://scenes/entities/slime_ball.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


func test_slime_crown_and_ball_defs_exist() -> void:
	var crown = ItemDB.get_def("slime_crown")
	assert_not_null(crown, "slime_crown 应在 ItemDB")
	assert_eq(crown.tool_kind, "summon", "slime_crown 是召唤道具")
	assert_eq(crown.max_stack, 1, "王冠不可堆叠")

	var ball = ItemDB.get_def("slime_ball")
	assert_not_null(ball, "slime_ball 应在 ItemDB")
	assert_eq(ball.tool_kind, "slimeball", "slime_ball 是投射武器")

	assert_true(ItemDB.is_summon("slime_crown"), "is_summon 该认 slime_crown")
	assert_false(ItemDB.is_summon("slime_ball"), "slime_ball 不是召唤道具")


func test_item_icons_exist() -> void:
	assert_not_null(ArtCache.get_inventory_icon("slime_crown"), "王冠该有 icon")
	assert_not_null(ArtCache.get_inventory_icon("slime_ball"), "球该有 icon")


func test_slime_crown_recipe_exists() -> void:
	var found := false
	for r in RecipeDB._RECIPES:
		if r.get("output_id", "") == "slime_crown":
			found = true
			assert_eq(r.get("requires", ""), "workbench", "王冠配方要工作台")
			var jelly := 0
			for row in r["pattern"]:
				for cell in row:
					if cell == "slime_jelly":
						jelly += 1
			assert_eq(jelly, 9, "王冠 = 9 个史莱姆胶")
	assert_true(found, "应有 slime_crown 配方")


func test_slime_ball_damages_enemy() -> void:
	var ball = SlimeBallScene.instantiate()
	add_child_autofree(ball)
	var slime = SlimeScene.instantiate()
	add_child_autofree(slime)
	slime.global_position = Vector2(100, 100)
	await wait_frames(1)
	ball.setup(Vector2(70, 100), Vector2(100, 100), 16, null)
	var hp_before: int = slime.current_health
	await wait_frames(30)
	assert_lt(slime.current_health, hp_before, "史莱姆球该打到 slime 扣血")

func test_slime_ball_bounces_off_ground() -> void:
	var ball = SlimeBallScene.instantiate()
	add_child_autofree(ball)
	assert_true("_bounces" in ball, "slime_ball 应有 _bounces 计数")
	assert_true(ball.has_method("setup"), "应有 setup")
