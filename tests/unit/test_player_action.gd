extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_in_reach_with_aim_override():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var pt: Vector2i = action.player_tile()
	# 玩家自身所在 tile 必在范围
	action.aim_override = pt
	assert_true(action.in_reach(pt))
	# 4 格远 - 仍在
	action.aim_override = pt + Vector2i(4, 0)
	assert_true(action.in_reach(pt + Vector2i(4, 0)))
	# 5 格远 - 超出
	action.aim_override = pt + Vector2i(5, 0)
	assert_false(action.in_reach(pt + Vector2i(5, 0)))


func test_aim_override_returns_set_value():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	action.aim_override = Vector2i(42, 100)
	assert_eq(action.aim_tile_coord(), Vector2i(42, 100))


func test_invalid_tile_not_in_reach():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	assert_false(action.in_reach(Vector2i(-1, -1)))
