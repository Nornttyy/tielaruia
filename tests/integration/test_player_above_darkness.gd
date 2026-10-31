# 当前要求按原版照明：人物与武器必须一起受水和光场影响。
extends GutTest
func test_player_and_held_item_are_below_water_and_lighting() -> void:
	var player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	assert_lt(player.z_index, 8)
	assert_lt(player.z_index + player.get_node("HeldItem").z_index, 8)
