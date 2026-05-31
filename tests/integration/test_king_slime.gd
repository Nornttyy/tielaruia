# 史莱姆王 Boss 验收
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


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
