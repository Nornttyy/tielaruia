extends GutTest

const BuffsClass = preload("res://scripts/player/player_buffs.gd")

# mining buff 应把倍数从 1.0 提到 MINING_MUL
func test_mining_mul_changes_with_buff():
	var b = BuffsClass.new()
	add_child_autofree(b)
	assert_almost_eq(b.mining_mul(), 1.0, 0.001)
	b.apply("mining", 5.0)
	assert_almost_eq(b.mining_mul(), b.MINING_MUL, 0.001)

# controller 源码确实乘了 speed/jump buff (防回归: 接线被删)
func test_controller_multiplies_speed_buff():
	var src: String = FileAccess.get_file_as_string("res://scripts/player/player_controller.gd")
	assert_true(src.find("_buff_speed_mul()") != -1, "移动应乘 _buff_speed_mul()")
	assert_true(src.find("_buff_jump_mul()") != -1, "跳跃应乘 _buff_jump_mul()")

func test_action_multiplies_mining_buff():
	var src: String = FileAccess.get_file_as_string("res://scripts/player/player_action.gd")
	assert_true(src.find("_buff_mining_mul()") != -1, "挖矿应乘 _buff_mining_mul()")
