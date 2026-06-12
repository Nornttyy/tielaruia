# 云靴二段跳: 持云靴时空中能再跳一次 → 跳更高. 没云靴不行.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")

func _boot_and_land():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)
	var player = main.get_node("World").get_player()
	for _i in 120:
		if player.is_on_floor():
			break
		await wait_frames(1)
	return player

func test_can_double_jump_reflects_boots():
	var player = await _boot_and_land()
	assert_true(player.is_on_floor(), "玩家已落地")
	# 起跳进入空中
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(4)
	assert_false(player.is_on_floor(), "已在空中")
	assert_false(player.can_double_jump(), "没云靴不能二段跳")
	player.get_node("PlayerInventory").inventory.add("cloud_boots", 1)
	assert_true(player.can_double_jump(), "有云靴能二段跳")

func test_double_jump_goes_higher_with_boots():
	var player = await _boot_and_land()
	player.get_node("PlayerInventory").inventory.add("cloud_boots", 1)
	var floor_y: float = player.global_position.y
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(8)
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")  # 二段跳
	var min_y: float = floor_y
	for _i in 50:
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
	var height: float = floor_y - min_y
	assert_gt(height, 55.0, "穿云靴二段跳应明显跳更高 (>55px, 单跳约42), 实际 %.1f" % height)

func test_no_double_jump_without_boots():
	var player = await _boot_and_land()
	var floor_y: float = player.global_position.y
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(8)
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")  # 没靴子, 空中跳无效
	var min_y: float = floor_y
	for _i in 50:
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
	var height: float = floor_y - min_y
	assert_lt(height, 52.0, "没云靴跳不了二段, 高度≈单跳 (<52px), 实际 %.1f" % height)


# 恶魔之翼: 跟云靴一样解锁二段跳
func test_demon_wings_grants_double_jump():
	var player = await _boot_and_land()
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(4)
	assert_false(player.is_on_floor(), "已在空中")
	assert_false(player.can_double_jump(), "没翼不能二段跳")
	player.get_node("PlayerInventory").inventory.add("demon_wings", 1)
	assert_true(player.can_double_jump(), "有恶魔之翼能二段跳")


# 恶魔之翼: 下落时按住跳 → 滑翔缓降 (限速, 远低于自由落体 200+)
func test_demon_wings_glide_caps_fall_speed():
	var player = await _boot_and_land()
	player.get_node("PlayerInventory").inventory.add("demon_wings", 1)
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	# 等到开始下落
	for _i in 60:
		await wait_frames(1)
		if player.velocity.y > 10.0:
			break
	Input.action_press("jump")   # 下落中按住跳 → 滑翔
	await wait_frames(6)
	var vy: float = player.velocity.y
	Input.action_release("jump")
	assert_lt(vy, 90.0, "恶魔之翼滑翔: 下落限速 (<90, 自由落体会到 200+), 实际 vy=%.1f" % vy)
